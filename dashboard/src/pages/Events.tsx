import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { apiFetch } from "@/lib/api";
import type { CampusEvent, EventsResponse } from "@/lib/types";

export function Events() {
  const [building, setBuilding] = useState("");
  const [severity, setSeverity] = useState("");
  const [eventType, setEventType] = useState("");

  const params = new URLSearchParams();
  params.set("limit", "100");
  if (building) params.set("building", building);
  if (severity) params.set("severity", severity);
  if (eventType) params.set("event_type", eventType);

  const query = useQuery({
    queryKey: ["events", building, severity, eventType],
    queryFn: () => apiFetch<EventsResponse>(`/events?${params}`),
    refetchInterval: 15_000,
  });

  const items: CampusEvent[] = query.data?.items ?? [];

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Events</h1>
        <p className="text-sm text-muted-foreground">
          Live feed of all campus events (last 100).
        </p>
      </header>

      <Card>
        <CardContent className="p-4 flex flex-wrap gap-3">
          <Input
            placeholder="Building (e.g. Library-A)"
            value={building}
            onChange={(e) => setBuilding(e.target.value)}
            className="max-w-xs"
          />
          <Input
            placeholder="Event type (e.g. occupancy)"
            value={eventType}
            onChange={(e) => setEventType(e.target.value)}
            className="max-w-xs"
          />
          <Input
            placeholder="Severity (normal|warning|critical)"
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
            className="max-w-xs"
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Recent events ({items.length})</CardTitle>
        </CardHeader>
        <CardContent>
          {query.isLoading ? (
            <div className="space-y-2">
              {[...Array(8)].map((_, i) => (
                <Skeleton key={i} className="h-9 w-full" />
              ))}
            </div>
          ) : items.length === 0 ? (
            <div className="text-sm text-muted-foreground text-center py-10">
              No events.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-24">Severity</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead className="text-right">Value</TableHead>
                  <TableHead className="text-right">When</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((e) => (
                  <TableRow key={e.event_id}>
                    <TableCell>
                      <Badge variant={e.severity}>{e.severity}</Badge>
                    </TableCell>
                    <TableCell className="font-mono text-xs">
                      {e.building}/{e.room}
                    </TableCell>
                    <TableCell>{e.event_type}</TableCell>
                    <TableCell className="text-right tabular-nums">
                      {e.value} {e.unit}
                    </TableCell>
                    <TableCell className="text-right text-xs text-muted-foreground">
                      {new Date(e.timestamp).toLocaleTimeString()}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

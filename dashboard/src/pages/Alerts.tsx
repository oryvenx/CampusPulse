import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, BellRing, ShieldAlert } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
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
import { useAuth } from "@/lib/auth";
import type { AlertsResponse } from "@/lib/types";

type Sev = "all" | "critical" | "warning";

export function Alerts() {
  const { hasRole, user } = useAuth();
  const [sev, setSev] = useState<Sev>("all");

  const query = useQuery({
    queryKey: ["alerts", sev, user?.username],
    queryFn: () =>
      apiFetch<AlertsResponse>(
        sev === "all" ? "/alerts" : `/alerts?severity=${sev}`
      ),
    refetchInterval: 15_000,
    enabled: hasRole("staff"),
  });

  if (!hasRole("staff")) {
    return (
      <div className="p-8 max-w-4xl mx-auto">
        <Card>
          <CardContent className="p-8 flex items-start gap-4">
            <ShieldAlert className="h-6 w-6 text-amber-400 mt-1" />
            <div>
              <h2 className="font-semibold">Access restricted</h2>
              <p className="text-sm text-muted-foreground mt-1">
                Alerts are visible to staff only. You are signed in as{" "}
                <span className="font-mono">
                  {useAuth().user?.groups.join(", ") || "unknown"}
                </span>
                .
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  const items = query.data?.items ?? [];

  return (
    <div className="p-8 space-y-6 max-w-6xl mx-auto">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Alerts</h1>
          <p className="text-sm text-muted-foreground">
            Threshold breaches and abnormal events (server-evaluated).
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant={sev === "all" ? "default" : "outline"}
            size="sm"
            onClick={() => setSev("all")}
          >
            All
          </Button>
          <Button
            variant={sev === "critical" ? "destructive" : "outline"}
            size="sm"
            onClick={() => setSev("critical")}
          >
            <AlertTriangle className="h-3.5 w-3.5" /> Critical
          </Button>
          <Button
            variant={sev === "warning" ? "secondary" : "outline"}
            size="sm"
            onClick={() => setSev("warning")}
          >
            <BellRing className="h-3.5 w-3.5" /> Warnings
          </Button>
        </div>
      </header>

      <div className="grid gap-4 sm:grid-cols-3">
        <Stat title="Total" value={query.data?.count} loading={query.isLoading} />
        <Stat
          title="Critical"
          value={query.data?.critical_count}
          loading={query.isLoading}
          accent="critical"
        />
        <Stat
          title="Warnings"
          value={query.data?.warning_count}
          loading={query.isLoading}
          accent="warning"
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Alert list</CardTitle>
        </CardHeader>
        <CardContent>
          {query.isLoading ? (
            <div className="space-y-2">
              {[...Array(6)].map((_, i) => (
                <Skeleton key={i} className="h-9 w-full" />
              ))}
            </div>
          ) : items.length === 0 ? (
            <div className="text-sm text-muted-foreground text-center py-10">
              No alerts matching this filter.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-24">Severity</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Reason</TableHead>
                  <TableHead className="text-right">Value</TableHead>
                  <TableHead className="text-right">When</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((a) => (
                  <TableRow key={a.event_id}>
                    <TableCell>
                      <Badge variant={a.alert_severity}>{a.alert_severity}</Badge>
                    </TableCell>
                    <TableCell className="font-mono text-xs">
                      {a.building}/{a.room}
                    </TableCell>
                    <TableCell>{a.event_type}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {a.alert_reason}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {a.value} {a.unit}
                    </TableCell>
                    <TableCell className="text-right text-xs text-muted-foreground">
                      {new Date(a.timestamp).toLocaleTimeString()}
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

function Stat({
  title,
  value,
  loading,
  accent,
}: {
  title: string;
  value?: number;
  loading?: boolean;
  accent?: "critical" | "warning";
}) {
  const cls =
    accent === "critical"
      ? "text-red-400"
      : accent === "warning"
      ? "text-amber-400"
      : "";
  return (
    <Card>
      <CardContent className="p-5">
        <div className="text-sm text-muted-foreground">{title}</div>
        <div className={`text-3xl font-semibold mt-1 ${cls}`}>
          {loading ? <Skeleton className="h-8 w-14" /> : value ?? 0}
        </div>
      </CardContent>
    </Card>
  );
}
import { useQuery } from "@tanstack/react-query";
import { Activity, AlertTriangle, BellRing, Building2 } from "lucide-react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  LineChart,
  Line,
  Legend,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
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
import type { AlertsResponse, AlertItem, StatsResponse } from "@/lib/types";

export function Overview() {
  const { hasRole, user } = useAuth();

  const stats = useQuery({
    queryKey: ["stats"],
    queryFn: () => apiFetch<StatsResponse>("/stats"),
    refetchInterval: 15_000,
  });

  const alerts = useQuery({
    queryKey: ["alerts", user?.username],
    queryFn: () => apiFetch<AlertsResponse>("/alerts"),
    refetchInterval: 15_000,
    enabled: hasRole("staff"),
  });

  const buildings = Object.keys(stats.data?.buildings ?? {});

  // Energy chart data
  const energyData = Object.entries(stats.data?.buildings ?? {}).map(([name, s]) => ({
    name,
    energy: Number(s.energy_total_kwh.toFixed(1)),
  }));

  // Alerts-over-time: bucket by minute
  const alertSeries = (() => {
    const items: AlertItem[] = alerts.data?.items ?? [];
    const buckets: Record<string, { time: string; warning: number; critical: number }> = {};
    for (const a of items) {
      const d = new Date(a.timestamp);
      const key = `${d.getHours()}:${String(d.getMinutes()).padStart(2, "0")}`;
      if (!buckets[key]) buckets[key] = { time: key, warning: 0, critical: 0 };
      buckets[key][a.alert_severity]++;
    }
    return Object.values(buckets).sort((a, b) => a.time.localeCompare(b.time));
  })();

  return (
    <div className="p-8 space-y-6 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Overview</h1>
        <p className="text-sm text-muted-foreground">
          Real-time operational state of the NorthBridge campus.
        </p>
      </header>

      {/* Metric cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <MetricCard
          title="Total events"
          icon={<Activity className="h-4 w-4" />}
          value={stats.data?.total_events}
          loading={stats.isLoading}
        />
        <MetricCard
          title="Buildings"
          icon={<Building2 className="h-4 w-4" />}
          value={buildings.length}
          loading={stats.isLoading}
        />
        <MetricCard
          title="Critical alerts"
          icon={<AlertTriangle className="h-4 w-4" />}
          value={alerts.data?.critical_count}
          loading={alerts.isLoading}
          accent="critical"
        />
        <MetricCard
          title="Warnings"
          icon={<BellRing className="h-4 w-4" />}
          value={alerts.data?.warning_count}
          loading={alerts.isLoading}
          accent="warning"
        />
      </div>

      {/* Charts */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Alerts over time</CardTitle>
          </CardHeader>
          <CardContent className="h-72">
            {!hasRole("staff") ? (
              <div className="h-full flex items-center justify-center text-sm text-muted-foreground">
                Alerts are visible to staff only.
              </div>
            ) : alertSeries.length === 0 ? (
              <div className="h-full flex items-center justify-center text-sm text-muted-foreground">
                No alerts yet.
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={alertSeries}>
                  <CartesianGrid strokeOpacity={0.1} />
                  <XAxis dataKey="time" stroke="#94a3b8" fontSize={12} />
                  <YAxis stroke="#94a3b8" fontSize={12} allowDecimals={false} />
                  <Tooltip
                    contentStyle={{
                      background: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: 8,
                      fontSize: 12,
                    }}
                  />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="critical"
                    stroke="#ef4444"
                    strokeWidth={2}
                    dot={{ r: 3 }}
                  />
                  <Line
                    type="monotone"
                    dataKey="warning"
                    stroke="#f59e0b"
                    strokeWidth={2}
                    dot={{ r: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Energy by building (kWh)</CardTitle>
          </CardHeader>
          <CardContent className="h-72">
            {energyData.length === 0 ? (
              <div className="h-full flex items-center justify-center text-sm text-muted-foreground">
                No energy data yet.
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={energyData}>
                  <CartesianGrid strokeOpacity={0.1} vertical={false} />
                  <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} />
                  <YAxis stroke="#94a3b8" fontSize={12} />
                  <Tooltip
                    contentStyle={{
                      background: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: 8,
                      fontSize: 12,
                    }}
                  />
                  <Bar dataKey="energy" fill="#38bdf8" radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Alerts table (staff only) */}
      {hasRole("staff") ? (
        <Card>
          <CardHeader>
            <CardTitle>Active alerts</CardTitle>
          </CardHeader>
          <CardContent>
            <AlertsTable loading={alerts.isLoading} items={alerts.data?.items ?? []} />
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="py-6 text-sm text-muted-foreground">
            Alerts are visible to staff only. You are signed in with role{" "}
            <span className="font-mono">{user?.groups.join(", ") || "unknown"}</span>.
          </CardContent>
        </Card>
      )}
    </div>
  );
}

function MetricCard({
  title,
  icon,
  value,
  loading,
  accent,
}: {
  title: string;
  icon: React.ReactNode;
  value?: number;
  loading?: boolean;
  accent?: "critical" | "warning";
}) {
  const accentClass =
    accent === "critical"
      ? "text-red-400"
      : accent === "warning"
        ? "text-amber-400"
        : "text-foreground";
  return (
    <Card>
      <CardContent className="p-6">
        <div className="flex items-center justify-between text-muted-foreground text-sm">
          <span>{title}</span>
          {icon}
        </div>
        <div className={`text-3xl font-semibold mt-2 ${accentClass}`}>
          {loading ? <Skeleton className="h-8 w-16" /> : (value ?? 0)}
        </div>
      </CardContent>
    </Card>
  );
}

function AlertsTable({ items, loading }: { items: AlertItem[]; loading: boolean }) {
  if (loading) {
    return (
      <div className="space-y-2">
        {[...Array(5)].map((_, i) => (
          <Skeleton key={i} className="h-8 w-full" />
        ))}
      </div>
    );
  }
  if (items.length === 0) {
    return (
      <div className="text-sm text-muted-foreground py-6 text-center">No active alerts. 🌿</div>
    );
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead className="w-24">Severity</TableHead>
          <TableHead>Location</TableHead>
          <TableHead>Type</TableHead>
          <TableHead>Reason</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {items.slice(0, 12).map((a) => (
          <TableRow key={a.event_id}>
            <TableCell>
              <Badge variant={a.alert_severity}>{a.alert_severity}</Badge>
            </TableCell>
            <TableCell className="font-mono text-xs">
              {a.building}/{a.room}
            </TableCell>
            <TableCell className="text-sm">{a.event_type}</TableCell>
            <TableCell className="text-sm text-muted-foreground">{a.alert_reason}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

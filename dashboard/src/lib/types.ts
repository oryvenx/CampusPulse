// Shared types matching the FastAPI responses

export type EventType =
  | "occupancy"
  | "temperature"
  | "humidity"
  | "energy"
  | "door"
  | "equipment_failure"
  | "service_request";

export type Severity = "normal" | "warning" | "critical";

export interface CampusEvent {
  event_id: string;
  building: string;
  room: string;
  event_type: EventType;
  value: number;
  unit: string;
  severity: Severity;
  timestamp: string;
}

export interface AlertItem extends CampusEvent {
  alert_severity: "warning" | "critical";
  alert_reason: string;
}

export interface AlertsResponse {
  count: number;
  critical_count: number;
  warning_count: number;
  by_building?: Record<string, { critical: number; warning: number }>;
  generated_at: string;
  items: AlertItem[];
}

export interface EventsResponse {
  count: number;
  items: CampusEvent[];
}

export interface BuildingStats {
  occupancy_total: number;
  occupancy_readings: number;
  occupancy_max: number;
  occupancy_avg: number;
  energy_total_kwh: number;
  energy_readings: number;
  alerts: number;
}

export interface StatsResponse {
  total_events: number;
  buildings: Record<string, BuildingStats>;
  generated_at: string;
}

export interface LoginResponse {
  access_token: string;
  id_token: string;
  refresh_token?: string;
  token_type: string;
  expires_in: number;
  role: string | null;
  groups: string[];
  name: string;
}

export interface MeResponse {
  username: string;
  email: string | null;
  name: string | null;
  groups: string[];
}
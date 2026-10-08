import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { apiFetch, getToken, setToken } from "@/lib/api";
import type { LoginResponse } from "@/lib/types";
import { useQueryClient } from "@tanstack/react-query";

const ID_TOKEN_KEY = "cp_id_token";

interface AuthUser {
  username: string;
  email: string | null;
  name: string | null;
  groups: string[];
}

interface AuthState {
  user: AuthUser | null;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  hasRole: (role: string) => boolean;
}

const AuthContext = createContext<AuthState | null>(null);

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const part = token.split(".")[1];
    return JSON.parse(atob(part));
  } catch {
    return null;
  }
}

function userFromIdToken(idToken: string): AuthUser {
  const p = decodeJwtPayload(idToken) || {};
  return {
    username:
      (p.email as string) ||
      (p["cognito:username"] as string) ||
      (p.sub as string) ||
      "user",
    email: (p.email as string) ?? null,
    name: (p.name as string) ?? null,
    groups: (p["cognito:groups"] as string[]) || [],
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  // Restore session on mount
  useEffect(() => {
    const idToken = sessionStorage.getItem(ID_TOKEN_KEY);
    if (idToken && getToken()) {
      setUser(userFromIdToken(idToken));
    }
    setLoading(false);
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    const data = await apiFetch<LoginResponse>("/auth/login", {
      method: "POST",
      body: JSON.stringify({ username, password }),
    });
    setToken(data.access_token);
    sessionStorage.setItem(ID_TOKEN_KEY, data.id_token);
    setUser(userFromIdToken(data.id_token));
  }, []);

  const queryClient = useQueryClient();
  const logout = useCallback(() => {
    setToken(null);
    sessionStorage.removeItem(ID_TOKEN_KEY);
    setUser(null);
    queryClient.clear();
  }, [queryClient]);

  const hasRole = useCallback(
    (role: string) => !!user?.groups.includes(role),
    [user]
  );

  const value = useMemo<AuthState>(
    () => ({ user, loading, login, logout, hasRole }),
    [user, loading, login, logout, hasRole]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
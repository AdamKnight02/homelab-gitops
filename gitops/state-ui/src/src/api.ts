// API client for state-api. All calls carry the user's bearer token.
// The UI NEVER requests or displays raw state — only sanitized metadata.

export interface StateSummary {
  identity: string;
  provider: string;
  customer: string;
  environment: string;
  component: string;
  backend_type: string;
  state_key: string;
  reachable: boolean | null;
  locked: boolean | null;
  last_modified: string | null;
  health: string;
}

export interface StateDetail {
  identity: string;
  provider: string;
  customer: string;
  environment: string;
  component: string;
  backend: { type: string; state_key: string; config: Record<string, string> };
  health: {
    reachable: boolean;
    exists: boolean;
    error: string | null;
    last_modified: string | null;
    size_bytes: number | null;
    version_id: string | null;
  };
  lock: {
    locked: boolean;
    holder: string | null;
    operation: string | null;
    created: string | null;
  };
  drift: {
    status: string;
    drift_detected: boolean | null;
    summary?: string;
    requested_by?: string;
    requested_at?: string;
    reported_at?: string;
  } | null;
  pipeline: {
    url: string | null;
    last_run_id: string | null;
    last_run_status: string | null;
    last_run_time: string | null;
  };
  correlation_id: string;
}

export interface StateMetadata {
  identity: string;
  version: number;
  terraform_version: string;
  serial: number;
  lineage: string;
  resources: {
    managed_count: number;
    data_count: number;
    total_count: number;
    by_type: Record<string, number>;
  };
  outputs: Record<string, { sensitive: boolean; value: unknown }>;
  correlation_id: string;
}

export interface StateVersion {
  version_id: string;
  last_modified: string;
  size_bytes: number | null;
  is_current: boolean;
}

class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function getToken(): string | null {
  // Token is supplied by the platform SSO proxy (e.g. oauth2-proxy) via a
  // header injection, or stored in sessionStorage after an OIDC code flow
  // handled outside this SPA. The UI never persists tokens to localStorage.
  return sessionStorage.getItem("state_ui_token");
}

export function setToken(token: string) {
  sessionStorage.setItem("state_ui_token", token);
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const resp = await fetch(`/api/v1${path}`, { ...options, headers });
  if (resp.status === 401) {
    window.dispatchEvent(new Event("state-ui:unauthorized"));
    throw new ApiError(401, "Authentication required");
  }
  if (!resp.ok) {
    const body = await resp.json().catch(() => ({}));
    throw new ApiError(resp.status, body.detail || `HTTP ${resp.status}`);
  }
  return resp.json();
}

export const api = {
  listStates: () => request<{ states: StateSummary[] }>("/states"),
  getState: (slug: string) => request<StateDetail>(`/states/${slug}`),
  getMetadata: (slug: string) => request<StateMetadata>(`/states/${slug}/metadata`),
  getVersions: (slug: string) =>
    request<{ identity: string; versions: StateVersion[] }>(`/states/${slug}/versions`),
  validate: (slug: string) =>
    request<{ valid: boolean; checks: Record<string, unknown> }>(`/states/${slug}/validate`, {
      method: "POST",
    }),
  driftCheck: (slug: string) =>
    request<{ drift: StateDetail["drift"] }>(`/states/${slug}/drift-check`, { method: "POST" }),
  backup: (slug: string) =>
    request<{ backup: { backup_key: string; bytes: number; timestamp: string } }>(
      `/states/${slug}/backup`,
      { method: "POST" }
    ),
  initiateMigration: (slug: string, target: { provider: string; component: string; environment?: string }) =>
    request<{ migration_request: { request_id: string; status: string } }>(
      `/states/${slug}/migrate`,
      { method: "POST", body: JSON.stringify({ target }) }
    ),
};

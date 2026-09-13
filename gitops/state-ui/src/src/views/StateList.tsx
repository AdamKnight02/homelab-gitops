import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api, StateSummary } from "../api";

type GroupBy = "customer" | "provider" | "environment" | "component";

const HEALTH_ORDER = ["unreachable", "locked", "missing", "unknown", "healthy"];

export default function StateList() {
  const [states, setStates] = useState<StateSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [groupBy, setGroupBy] = useState<GroupBy>("provider");
  const [filter, setFilter] = useState("");

  useEffect(() => {
    api
      .listStates()
      .then((r) => setStates(r.states))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  const filtered = useMemo(() => {
    const q = filter.toLowerCase();
    return states.filter(
      (s) =>
        !q ||
        s.identity.includes(q) ||
        s.customer.includes(q) ||
        s.environment.includes(q) ||
        s.component.includes(q)
    );
  }, [states, filter]);

  const groups = useMemo(() => {
    const map = new Map<string, StateSummary[]>();
    for (const s of filtered) {
      const key = s[groupBy];
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(s);
    }
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [filtered, groupBy]);

  const healthCounts = useMemo(() => {
    const c: Record<string, number> = {};
    for (const s of states) c[s.health] = (c[s.health] || 0) + 1;
    return c;
  }, [states]);

  if (loading) return <div className="loading">Loading state inventory…</div>;
  if (error) return <div className="error-banner">Failed to load states: {error}</div>;

  return (
    <div>
      <div className="toolbar">
        <input
          className="search"
          placeholder="Filter by customer, environment, component…"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        />
        <div className="groupby">
          <label>Group by:</label>
          {(["provider", "customer", "environment", "component"] as GroupBy[]).map((g) => (
            <button
              key={g}
              className={`chip ${groupBy === g ? "chip-active" : ""}`}
              onClick={() => setGroupBy(g)}
            >
              {g}
            </button>
          ))}
        </div>
      </div>

      <div className="health-strip">
        {HEALTH_ORDER.filter((h) => healthCounts[h]).map((h) => (
          <span key={h} className={`health-pill health-${h}`}>
            {h}: {healthCounts[h]}
          </span>
        ))}
      </div>

      {groups.map(([group, items]) => (
        <section key={group} className="state-group">
          <h3 className="group-title">
            {groupBy}: <span className="group-name">{group}</span>
            <span className="group-count">{items.length}</span>
          </h3>
          <div className="state-grid">
            {items.map((s) => (
              <Link to={`/states/${s.identity}`} key={s.identity} className="state-card">
                <div className="state-card-head">
                  <span className={`health-dot health-${s.health}`} />
                  <span className="state-identity">{s.identity}</span>
                </div>
                <dl className="state-card-meta">
                  <div>
                    <dt>Backend</dt>
                    <dd>{s.backend_type}</dd>
                  </div>
                  <div>
                    <dt>Locked</dt>
                    <dd>{s.locked === null ? "—" : s.locked ? "🔒 yes" : "no"}</dd>
                  </div>
                  <div>
                    <dt>Last update</dt>
                    <dd>{s.last_modified ? new Date(s.last_modified).toLocaleString() : "—"}</dd>
                  </div>
                </dl>
                <div className="state-key" title={s.state_key}>
                  {s.state_key}
                </div>
              </Link>
            ))}
          </div>
        </section>
      ))}
      {groups.length === 0 && <div className="empty">No states match the current filter.</div>}
    </div>
  );
}

import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  api,
  StateDetail as Detail,
  StateMetadata,
  StateVersion,
} from "../api";

type Tab = "overview" | "metadata" | "versions";

export default function StateDetail() {
  const { provider, customer, environment, component } = useParams();
  const slug = `${provider}/${customer}/${environment}/${component}`;

  const [detail, setDetail] = useState<Detail | null>(null);
  const [metadata, setMetadata] = useState<StateMetadata | null>(null);
  const [versions, setVersions] = useState<StateVersion[] | null>(null);
  const [tab, setTab] = useState<Tab>("overview");
  const [error, setError] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [showMigration, setShowMigration] = useState(false);

  const load = useCallback(() => {
    api
      .getState(slug)
      .then(setDetail)
      .catch((e) => setError(e.message));
  }, [slug]);

  useEffect(load, [load]);

  useEffect(() => {
    if (tab === "metadata" && !metadata) {
      api.getMetadata(slug).then(setMetadata).catch((e) => setError(e.message));
    }
    if (tab === "versions" && !versions) {
      api.getVersions(slug).then((r) => setVersions(r.versions)).catch((e) => setError(e.message));
    }
  }, [tab, slug, metadata, versions]);

  const runAction = async (name: string, fn: () => Promise<unknown>, describe: (r: any) => string) => {
    setBusy(name);
    setActionMsg(null);
    try {
      const result = await fn();
      setActionMsg(describe(result));
      load();
    } catch (e: any) {
      setActionMsg(`❌ ${name} failed: ${e.message}`);
    } finally {
      setBusy(null);
    }
  };

  if (error) return <div className="error-banner">{error}</div>;
  if (!detail) return <div className="loading">Loading {slug}…</div>;

  const health = detail.health.reachable
    ? detail.lock.locked
      ? "locked"
      : detail.health.exists
        ? "healthy"
        : "missing"
    : "unreachable";

  return (
    <div>
      <nav className="breadcrumb">
        <Link to="/">← All states</Link>
      </nav>

      <div className="detail-header">
        <div>
          <h2 className="detail-title">
            <span className={`health-dot health-${health}`} /> {slug}
          </h2>
          <p className="detail-sub">
            {detail.backend.type} backend · <code>{detail.backend.state_key}</code>
          </p>
        </div>
        <div className="actions">
          <button
            className="btn"
            disabled={busy !== null}
            onClick={() =>
              runAction("validate", () => api.validate(slug), (r) =>
                r.valid ? "✅ State validation passed" : "⚠️ State validation reported issues"
              )
            }
          >
            {busy === "validate" ? "Validating…" : "Validate State"}
          </button>
          <button
            className="btn"
            disabled={busy !== null}
            onClick={() =>
              runAction("drift", () => api.driftCheck(slug), () =>
                "🔍 Drift detection requested — runs in the deployment pipeline"
              )
            }
          >
            {busy === "drift" ? "Requesting…" : "Run Drift Detection"}
          </button>
          <button
            className="btn"
            disabled={busy !== null}
            onClick={() =>
              runAction("backup", () => api.backup(slug), (r) =>
                `💾 Backup created: ${r.backup.backup_key} (${r.backup.bytes} bytes)`
              )
            }
          >
            {busy === "backup" ? "Backing up…" : "Backup State"}
          </button>
          <button className="btn btn-caution" onClick={() => setShowMigration(true)}>
            Initiate Migration
          </button>
          {detail.pipeline.url && (
            <a className="btn btn-link" href={detail.pipeline.url} target="_blank" rel="noreferrer">
              View Pipeline ↗
            </a>
          )}
        </div>
      </div>

      {actionMsg && <div className="action-msg">{actionMsg}</div>}

      <div className="tabs">
        {(["overview", "metadata", "versions"] as Tab[]).map((t) => (
          <button key={t} className={`tab ${tab === t ? "tab-active" : ""}`} onClick={() => setTab(t)}>
            {t === "overview" ? "Overview" : t === "metadata" ? "View Metadata" : "Version History"}
          </button>
        ))}
      </div>

      {tab === "overview" && (
        <div className="panel-grid">
          <div className="panel">
            <h4>Backend</h4>
            <dl className="kv">
              <div><dt>Type</dt><dd>{detail.backend.type}</dd></div>
              <div><dt>State key</dt><dd><code>{detail.backend.state_key}</code></dd></div>
              {Object.entries(detail.backend.config).map(([k, v]) => (
                <div key={k}><dt>{k}</dt><dd>{String(v)}</dd></div>
              ))}
            </dl>
          </div>

          <div className="panel">
            <h4>Health</h4>
            <dl className="kv">
              <div>
                <dt>Reachable</dt>
                <dd>{detail.health.reachable ? "✅ yes" : "❌ no"}</dd>
              </div>
              <div>
                <dt>State exists</dt>
                <dd>{detail.health.exists ? "yes" : "no"}</dd>
              </div>
              <div>
                <dt>Last update</dt>
                <dd>{detail.health.last_modified ? new Date(detail.health.last_modified).toLocaleString() : "—"}</dd>
              </div>
              <div>
                <dt>Size</dt>
                <dd>{detail.health.size_bytes != null ? `${(detail.health.size_bytes / 1024).toFixed(1)} KiB` : "—"}</dd>
              </div>
              {detail.health.error && (
                <div><dt>Error</dt><dd className="error-text">{detail.health.error}</dd></div>
              )}
            </dl>
          </div>

          <div className="panel">
            <h4>Lock</h4>
            <dl className="kv">
              <div>
                <dt>Status</dt>
                <dd>{detail.lock.locked ? `🔒 locked` : "unlocked"}</dd>
              </div>
              {detail.lock.holder && <div><dt>Holder</dt><dd>{detail.lock.holder}</dd></div>}
              {detail.lock.operation && <div><dt>Operation</dt><dd>{detail.lock.operation}</dd></div>}
              {detail.lock.created && (
                <div><dt>Since</dt><dd>{new Date(detail.lock.created).toLocaleString()}</dd></div>
              )}
            </dl>
            {detail.lock.locked && (
              <p className="notice">
                Force-unlock is a privileged pipeline operation. Contact a platform
                operator — it cannot be performed from this UI.
              </p>
            )}
          </div>

          <div className="panel">
            <h4>Drift</h4>
            {detail.drift ? (
              <dl className="kv">
                <div><dt>Status</dt><dd>{detail.drift.status}</dd></div>
                {detail.drift.drift_detected !== null && detail.drift.drift_detected !== undefined && (
                  <div>
                    <dt>Drift detected</dt>
                    <dd>{detail.drift.drift_detected ? "⚠️ yes" : "✅ no"}</dd>
                  </div>
                )}
                {detail.drift.summary && <div><dt>Summary</dt><dd>{detail.drift.summary}</dd></div>}
                {detail.drift.reported_at && (
                  <div><dt>Reported</dt><dd>{new Date(detail.drift.reported_at).toLocaleString()}</dd></div>
                )}
              </dl>
            ) : (
              <p className="muted">No drift check has run for this state yet.</p>
            )}
          </div>

          <div className="panel">
            <h4>Pipeline</h4>
            <dl className="kv">
              <div><dt>Last run</dt><dd>{detail.pipeline.last_run_id ?? "—"}</dd></div>
              <div><dt>Status</dt><dd>{detail.pipeline.last_run_status ?? "—"}</dd></div>
              <div>
                <dt>Time</dt>
                <dd>{detail.pipeline.last_run_time ? new Date(detail.pipeline.last_run_time).toLocaleString() : "—"}</dd>
              </div>
            </dl>
          </div>
        </div>
      )}

      {tab === "metadata" && (
        <div className="panel">
          <h4>Sanitized metadata</h4>
          {!metadata ? (
            <div className="loading">Loading…</div>
          ) : (
            <>
              <dl className="kv">
                <div><dt>State version</dt><dd>{metadata.version}</dd></div>
                <div><dt>Terraform version</dt><dd>{metadata.terraform_version}</dd></div>
                <div><dt>Serial</dt><dd>{metadata.serial}</dd></div>
                <div><dt>Lineage</dt><dd><code>{metadata.lineage}</code></dd></div>
                <div>
                  <dt>Tracked resources</dt>
                  <dd>
                    {metadata.resources.managed_count} managed · {metadata.resources.data_count} data
                  </dd>
                </div>
              </dl>
              <h5>Resources by type</h5>
              <div className="tag-cloud">
                {Object.entries(metadata.resources.by_type).map(([t, n]) => (
                  <span key={t} className="tag">
                    {t} <b>{n}</b>
                  </span>
                ))}
              </div>
              <h5>Outputs</h5>
              <table className="table">
                <thead>
                  <tr><th>Name</th><th>Sensitive</th><th>Value</th></tr>
                </thead>
                <tbody>
                  {Object.entries(metadata.outputs).map(([name, out]) => (
                    <tr key={name}>
                      <td><code>{name}</code></td>
                      <td>{out.sensitive ? "🔒" : ""}</td>
                      <td className={out.sensitive ? "redacted" : ""}>
                        {typeof out.value === "string" ? out.value : JSON.stringify(out.value)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="notice">
                Sensitive outputs are redacted server-side. Raw state is never
                transmitted to this UI.
              </p>
            </>
          )}
        </div>
      )}

      {tab === "versions" && (
        <div className="panel">
          <h4>Previous versions</h4>
          {!versions ? (
            <div className="loading">Loading…</div>
          ) : versions.length === 0 ? (
            <p className="muted">Backend versioning is not enabled or no versions found.</p>
          ) : (
            <table className="table">
              <thead>
                <tr><th>Version ID</th><th>Last modified</th><th>Size</th><th></th></tr>
              </thead>
              <tbody>
                {versions.map((v) => (
                  <tr key={v.version_id} className={v.is_current ? "row-current" : ""}>
                    <td><code>{v.version_id.slice(0, 20)}…</code></td>
                    <td>{new Date(v.last_modified).toLocaleString()}</td>
                    <td>{v.size_bytes != null ? `${(v.size_bytes / 1024).toFixed(1)} KiB` : "—"}</td>
                    <td>{v.is_current && <span className="badge badge-safe">current</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p className="notice">
            Restoring a previous version is a privileged pipeline operation with an
            approval gate. It cannot be performed from this UI.
          </p>
        </div>
      )}

      {showMigration && (
        <MigrationDialog
          slug={slug}
          onClose={() => setShowMigration(false)}
          onSubmitted={(id) => {
            setShowMigration(false);
            setActionMsg(`📋 Migration request ${id} created — pending pipeline approval`);
          }}
        />
      )}
    </div>
  );
}

function MigrationDialog({
  slug,
  onClose,
  onSubmitted,
}: {
  slug: string;
  onClose: () => void;
  onSubmitted: (requestId: string) => void;
}) {
  const [targetProvider, setTargetProvider] = useState("azure");
  const [targetComponent, setTargetComponent] = useState("core");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    setSubmitting(true);
    setError(null);
    try {
      const r = await api.initiateMigration(slug, {
        provider: targetProvider,
        component: targetComponent,
      });
      onSubmitted(r.migration_request.request_id);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>Initiate migration</h3>
        <p className="notice">
          This creates an <b>approval request</b> only. The migration executes in the
          pipeline after human approval. Source state is backed up automatically first.
        </p>
        <p>
          Source: <code>{slug}</code>
        </p>
        <label>
          Target provider
          <select value={targetProvider} onChange={(e) => setTargetProvider(e.target.value)}>
            <option value="azure">azure</option>
            <option value="aws">aws</option>
            <option value="alibaba">alibaba</option>
          </select>
        </label>
        <label>
          Target component
          <select value={targetComponent} onChange={(e) => setTargetComponent(e.target.value)}>
            <option value="core">core</option>
            <option value="addons">addons</option>
            <option value="monitoring">monitoring</option>
          </select>
        </label>
        {error && <div className="error-banner">{error}</div>}
        <div className="modal-actions">
          <button className="btn" onClick={onClose}>Cancel</button>
          <button className="btn btn-caution" disabled={submitting} onClick={submit}>
            {submitting ? "Submitting…" : "Create approval request"}
          </button>
        </div>
      </div>
    </div>
  );
}

import { useState } from "react";
import { setToken } from "../api";

export default function Login({ onLogin }: { onLogin: () => void }) {
  const [token, setTokenInput] = useState("");

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!token.trim()) return;
    setToken(token.trim());
    onLogin();
  };

  return (
    <div className="login-card">
      <h2>Sign in</h2>
      <p>
        Authenticate with your platform identity token (OIDC). In cluster deployments
        this is normally injected by the SSO proxy; paste a token here for direct access.
      </p>
      <form onSubmit={submit}>
        <input
          type="password"
          placeholder="Bearer token"
          value={token}
          onChange={(e) => setTokenInput(e.target.value)}
          autoComplete="off"
        />
        <button type="submit" className="btn btn-primary">
          Continue
        </button>
      </form>
    </div>
  );
}

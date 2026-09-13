import { useEffect, useState } from "react";
import { Navigate, Route, Routes, useNavigate } from "react-router-dom";
import StateList from "./views/StateList";
import StateDetail from "./views/StateDetail";
import Login from "./views/Login";

export default function App() {
  const [authed, setAuthed] = useState<boolean>(!!sessionStorage.getItem("state_ui_token"));
  const navigate = useNavigate();

  useEffect(() => {
    const onUnauth = () => {
      setAuthed(false);
      navigate("/login");
    };
    window.addEventListener("state-ui:unauthorized", onUnauth);
    return () => window.removeEventListener("state-ui:unauthorized", onUnauth);
  }, [navigate]);

  return (
    <div className="app">
      <header className="app-header">
        <div className="brand">
          <span className="brand-mark">⬡</span>
          <div>
            <h1>State Management</h1>
            <p className="subtitle">PKI Platform — Terraform state metadata &amp; health</p>
          </div>
        </div>
        <div className="header-badges">
          <span className="badge badge-safe">Sanitized metadata only</span>
          <span className="badge badge-internal">Internal</span>
        </div>
      </header>
      <main>
        <Routes>
          <Route path="/login" element={<Login onLogin={() => setAuthed(true)} />} />
          <Route path="/" element={authed ? <StateList /> : <Navigate to="/login" />} />
          <Route
            path="/states/:provider/:customer/:environment/:component"
            element={authed ? <StateDetail /> : <Navigate to="/login" />}
          />
        </Routes>
      </main>
      <footer className="app-footer">
        Raw state is never exposed through this interface. Privileged operations
        (state rm / push / force-unlock) require pipeline approval and are fully audited.
      </footer>
    </div>
  );
}

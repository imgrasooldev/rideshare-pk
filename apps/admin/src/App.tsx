import { useCallback, useEffect, useState } from "react";
import {
  api,
  ApiError,
  clearSession,
  currentUser,
  saveSession,
  type AdminRide,
  type Metrics,
  type User,
  type Verification
} from "./api";

type Page = "dashboard" | "verifications" | "rides" | "users";

export default function App() {
  const [user, setUser] = useState<User | null>(currentUser());
  if (!user) return <Login onLoggedIn={setUser} />;
  return <Shell user={user} onLogout={() => (clearSession(), setUser(null))} />;
}

// ---------- Login ----------

function Login({ onLoggedIn }: { onLoggedIn: (u: User) => void }) {
  const [method, setMethod] = useState<"email" | "phone">("email");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [codeSent, setCodeSent] = useState(false);
  const [devCode, setDevCode] = useState<string | undefined>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(fn: () => Promise<{ accessToken: string; user: User }>) {
    setBusy(true);
    setError(null);
    try {
      const res = await fn();
      saveSession(res.accessToken, res.user);
      onLoggedIn(res.user);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Something went wrong");
    } finally {
      setBusy(false);
    }
  }

  async function sendCode() {
    setBusy(true);
    setError(null);
    try {
      const res = await api.requestOtp(phone);
      setDevCode(res.devCode);
      setCodeSent(true);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Something went wrong");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="brand">
          <div className="logo">🚗</div>
          <h1>Rideshare PK</h1>
          <p>Admin console</p>
        </div>

        <div className="field" style={{ display: "flex", gap: 8 }}>
          <button
            className={method === "email" ? "btn-primary" : "btn-ghost"}
            style={{ flex: 1 }}
            onClick={() => setMethod("email")}
          >
            Email
          </button>
          <button
            className={method === "phone" ? "btn-primary" : "btn-ghost"}
            style={{ flex: 1 }}
            onClick={() => setMethod("phone")}
          >
            Phone
          </button>
        </div>

        {method === "email" ? (
          <form
            onSubmit={(e) => (e.preventDefault(), run(() => api.loginEmail(email, password)))}
          >
            <div className="field">
              <input
                placeholder="Email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="field">
              <input
                placeholder="Password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {error && <div className="error">{error}</div>}
            <button className="btn-primary" style={{ width: "100%" }} disabled={busy}>
              {busy ? "Signing in…" : "Sign in"}
            </button>
          </form>
        ) : !codeSent ? (
          <form onSubmit={(e) => (e.preventDefault(), sendCode())}>
            <div className="field">
              <input
                placeholder="03XX XXXXXXX"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
            </div>
            {error && <div className="error">{error}</div>}
            <button className="btn-primary" style={{ width: "100%" }} disabled={busy}>
              {busy ? "Sending…" : "Send code"}
            </button>
          </form>
        ) : (
          <form
            onSubmit={(e) => (e.preventDefault(), run(() => api.verifyOtp(phone, code)))}
          >
            {devCode && <p className="hint">Dev code: {devCode}</p>}
            <div className="field">
              <input
                placeholder="6-digit code"
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
            </div>
            {error && <div className="error">{error}</div>}
            <button className="btn-primary" style={{ width: "100%" }} disabled={busy}>
              {busy ? "Verifying…" : "Verify"}
            </button>
          </form>
        )}
        <p className="hint" style={{ textAlign: "center", marginTop: 14 }}>
          Admin access only — regular accounts are rejected.
        </p>
      </div>
    </div>
  );
}

// ---------- Shell ----------

const NAV: Array<{ key: Page; label: string; icon: string }> = [
  { key: "dashboard", label: "Dashboard", icon: "📊" },
  { key: "verifications", label: "Verifications", icon: "🛡️" },
  { key: "rides", label: "Rides", icon: "🚗" },
  { key: "users", label: "Users", icon: "👥" }
];

function Shell({ user, onLogout }: { user: User; onLogout: () => void }) {
  const [page, setPage] = useState<Page>("dashboard");
  const [toast, setToast] = useState<string | null>(null);
  const [denied, setDenied] = useState(false);

  const notify = useCallback((message: string) => {
    setToast(message);
    setTimeout(() => setToast(null), 2600);
  }, []);

  const onApiError = useCallback(
    (e: unknown) => {
      if (e instanceof ApiError && e.status === 403) setDenied(true);
      else notify(e instanceof ApiError ? e.message : "Request failed");
    },
    [notify]
  );

  if (denied) {
    return (
      <div className="login-wrap">
        <div className="login-card" style={{ textAlign: "center" }}>
          <div className="brand">
            <div className="logo">⛔</div>
            <h1>Not an admin</h1>
            <p>
              This account ({user.email ?? user.phone}) has no admin access. Grant it with
              scripts/make-admin.mjs, then sign in again.
            </p>
          </div>
          <button className="btn-primary" onClick={onLogout}>
            Switch account
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand-row">
          <span className="dot">🚗</span> Rideshare PK
        </div>
        {NAV.map((n) => (
          <button
            key={n.key}
            className={`nav-item ${page === n.key ? "active" : ""}`}
            onClick={() => setPage(n.key)}
          >
            <span>{n.icon}</span> {n.label}
          </button>
        ))}
        <div className="spacer" />
        <div className="whoami">
          {user.name ?? user.email ?? user.phone}
          <br />
          <button className="btn-ghost" style={{ marginTop: 8 }} onClick={onLogout}>
            Log out
          </button>
        </div>
      </aside>
      <main className="main">
        {page === "dashboard" && <Dashboard onError={onApiError} />}
        {page === "verifications" && <Verifications onError={onApiError} notify={notify} />}
        {page === "rides" && <Rides onError={onApiError} />}
        {page === "users" && <Users onError={onApiError} />}
      </main>
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

// ---------- Pages ----------

function Dashboard({ onError }: { onError: (e: unknown) => void }) {
  const [metrics, setMetrics] = useState<Metrics | null>(null);

  useEffect(() => {
    api.metrics().then(setMetrics).catch(onError);
  }, [onError]);

  if (!metrics) return <div className="empty">Loading…</div>;

  const kpis: Array<{ label: string; value: string | number; accent?: boolean }> = [
    { label: "Total users", value: metrics.totalUsers },
    { label: "Verified users", value: metrics.verifiedUsers },
    { label: "Drivers", value: metrics.drivers },
    { label: "Open rides", value: metrics.openRides, accent: true },
    { label: "Total rides", value: metrics.totalRides },
    { label: "Active bookings", value: metrics.activeBookings, accent: true },
    { label: "Total bookings", value: metrics.totalBookings },
    { label: "Fill rate", value: `${Math.round(metrics.fillRate * 100)}%`, accent: true },
    { label: "Pending verifications", value: metrics.pendingVerifications },
    { label: "SOS events", value: metrics.sosEvents }
  ];

  return (
    <>
      <h2>Marketplace health</h2>
      <div className="kpis">
        {kpis.map((k) => (
          <div className="kpi" key={k.label}>
            <div className="label">{k.label}</div>
            <div className={`value ${k.accent ? "accent" : ""}`}>{k.value}</div>
          </div>
        ))}
      </div>
      <div className="card">
        <strong>Liquidity note</strong>
        <p className="hint" style={{ marginBottom: 0 }}>
          Fill rate = booked seats ÷ offered seats on open and full rides. This is the number
          that decides the marketplace — target one corridor until it stays above 40%.
        </p>
      </div>
    </>
  );
}

function Verifications({
  onError,
  notify
}: {
  onError: (e: unknown) => void;
  notify: (m: string) => void;
}) {
  const [items, setItems] = useState<Verification[] | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(() => {
    api
      .verificationQueue()
      .then((q) => setItems(q.items))
      .catch(onError);
  }, [onError]);

  useEffect(load, [load]);

  async function review(id: string, action: "approve" | "reject") {
    const notes =
      action === "reject" ? prompt("Reason shown to the user:") ?? undefined : undefined;
    if (action === "reject" && notes === undefined) return;
    setBusyId(id);
    try {
      await api.review(id, action, notes);
      notify(action === "approve" ? "Approved — user is now trusted" : "Rejected");
      load();
    } catch (e) {
      onError(e);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <h2>Verification queue</h2>
      <div className="card">
        {!items ? (
          <div className="empty">Loading…</div>
        ) : items.length === 0 ? (
          <div className="empty">Queue is clear — nothing pending. 🎉</div>
        ) : (
          items.map((v) => (
            <div className="queue-row" key={v.id}>
              <span className="pill amber">{v.type}</span>
              <div className="grow">
                <div className="title">User {v.userId.slice(0, 8)}…</div>
                <div className="sub">
                  Submitted {new Date(v.createdAt).toLocaleString()} ·{" "}
                  <a href={v.docUrl} target="_blank" rel="noreferrer">
                    View document
                  </a>
                </div>
              </div>
              <button
                className="btn-approve"
                disabled={busyId === v.id}
                onClick={() => review(v.id, "approve")}
              >
                Approve
              </button>
              <button
                className="btn-danger"
                disabled={busyId === v.id}
                onClick={() => review(v.id, "reject")}
              >
                Reject
              </button>
            </div>
          ))
        )}
      </div>
    </>
  );
}

function Rides({ onError }: { onError: (e: unknown) => void }) {
  const [rides, setRides] = useState<AdminRide[] | null>(null);

  useEffect(() => {
    api.rides().then(setRides).catch(onError);
  }, [onError]);

  return (
    <>
      <h2>Recent rides</h2>
      <div className="card" style={{ overflowX: "auto" }}>
        {!rides ? (
          <div className="empty">Loading…</div>
        ) : rides.length === 0 ? (
          <div className="empty">No rides yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Route</th>
                <th>Departs</th>
                <th>Vehicle</th>
                <th>Seats</th>
                <th>Price</th>
                <th>Driver</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {rides.map((r) => (
                <tr key={r.id}>
                  <td>
                    {r.originLabel} → {r.destLabel}
                  </td>
                  <td>{new Date(r.departAt).toLocaleString()}</td>
                  <td>{r.vehicleType}</td>
                  <td>
                    {r.seatsTotal - r.seatsAvailable}/{r.seatsTotal} booked
                  </td>
                  <td>Rs {r.pricePerSeat}</td>
                  <td>{r.driverName ?? r.driverPhone ?? "—"}</td>
                  <td>
                    <span
                      className={`pill ${
                        r.status === "open" ? "green" : r.status === "full" ? "amber" : "gray"
                      }`}
                    >
                      {r.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}

function Users({ onError }: { onError: (e: unknown) => void }) {
  const [users, setUsers] = useState<User[] | null>(null);

  useEffect(() => {
    api.users().then(setUsers).catch(onError);
  }, [onError]);

  return (
    <>
      <h2>Recent users</h2>
      <div className="card" style={{ overflowX: "auto" }}>
        {!users ? (
          <div className="empty">Loading…</div>
        ) : users.length === 0 ? (
          <div className="empty">No users yet.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Contact</th>
                <th>Role</th>
                <th>City</th>
                <th>Rating</th>
                <th>Trust</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td>{u.name ?? "—"}</td>
                  <td>{u.phone ?? u.email ?? "—"}</td>
                  <td>{u.role}</td>
                  <td>{u.city}</td>
                  <td>{u.ratingAvg ? `★ ${u.ratingAvg.toFixed(1)}` : "—"}</td>
                  <td>
                    <span className={`pill ${u.verified ? "green" : "gray"}`}>
                      {u.verified ? "verified" : "unverified"}
                    </span>
                  </td>
                  <td>{u.createdAt ? new Date(u.createdAt).toLocaleDateString() : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}

"use client";

import { useState } from "react";
import { Car, KeyRound, Mail, Phone } from "lucide-react";
import { api, ApiError, saveSession, type User } from "@/lib/api";

export default function LoginPage() {
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
      // Hard navigation: reliable regardless of static-export router quirks.
      window.location.assign("/admin/");
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

  const input =
    "w-full rounded-lg border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm outline-none transition focus:border-brand-500 focus:bg-white focus:ring-2 focus:ring-brand-500/20";
  const tab = (active: boolean) =>
    `flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition ${
      active ? "bg-white text-slate-800 shadow-sm" : "text-slate-500 hover:text-slate-700"
    }`;

  return (
    <div className="grid min-h-screen place-items-center bg-gradient-to-br from-[#09090b] via-[#151517] to-[#26160c] p-6">
      <div className="w-full max-w-105">
        <div className="mb-6 text-center text-white">
          <div className="mx-auto mb-3 grid h-14 w-14 place-items-center rounded-2xl bg-brand-500 text-white shadow-[0_0_44px_rgba(249,115,22,0.5)]">
            <Car size={26} />
          </div>
          <h1 className="text-2xl font-extrabold tracking-tight">Rideshare PK</h1>
          <p className="text-sm text-white/70">Operations console</p>
        </div>

        <div className="card-soft rounded-2xl bg-white p-7">
          <div className="mb-5 flex rounded-xl bg-slate-100 p-1">
            <button className={tab(method === "email")} onClick={() => setMethod("email")}>
              <Mail size={15} /> Email
            </button>
            <button className={tab(method === "phone")} onClick={() => setMethod("phone")}>
              <Phone size={15} /> Phone
            </button>
          </div>

          {method === "email" ? (
            <form
              className="space-y-3"
              onSubmit={(e) => {
                e.preventDefault();
                run(() => api.loginEmail(email, password));
              }}
            >
              <input
                className={input}
                type="email"
                placeholder="admin@rideshare.pk"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <input
                className={input}
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              {error && <p className="text-center text-sm text-red-600">{error}</p>}
              <button
                className="w-full rounded-lg bg-brand-600 py-2.5 text-sm font-bold text-white transition hover:bg-brand-700 disabled:opacity-50"
                disabled={busy}
              >
                {busy ? "Signing in…" : "Sign in"}
              </button>
            </form>
          ) : !codeSent ? (
            <form
              className="space-y-3"
              onSubmit={(e) => {
                e.preventDefault();
                sendCode();
              }}
            >
              <input
                className={input}
                placeholder="03XX XXXXXXX"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
              {error && <p className="text-center text-sm text-red-600">{error}</p>}
              <button
                className="w-full rounded-lg bg-brand-600 py-2.5 text-sm font-bold text-white transition hover:bg-brand-700 disabled:opacity-50"
                disabled={busy}
              >
                {busy ? "Sending…" : "Send code"}
              </button>
            </form>
          ) : (
            <form
              className="space-y-3"
              onSubmit={(e) => {
                e.preventDefault();
                run(() => api.verifyOtp(phone, code));
              }}
            >
              {devCode && (
                <p className="flex items-center justify-center gap-1.5 rounded-lg bg-amber-50 py-2 text-center text-xs font-semibold text-amber-700">
                  <KeyRound size={13} /> Dev code: {devCode}
                </p>
              )}
              <input
                className={`${input} text-center text-lg tracking-[0.5em]`}
                placeholder="••••••"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
              {error && <p className="text-center text-sm text-red-600">{error}</p>}
              <button
                className="w-full rounded-lg bg-brand-600 py-2.5 text-sm font-bold text-white transition hover:bg-brand-700 disabled:opacity-50"
                disabled={busy}
              >
                {busy ? "Verifying…" : "Verify"}
              </button>
            </form>
          )}

          <p className="mt-5 text-center text-xs text-slate-400">
            Admin access only — regular accounts are rejected.
          </p>
        </div>
      </div>
    </div>
  );
}


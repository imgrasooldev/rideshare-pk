"use client";

import { useState } from "react";
import { ArrowRight, Bug, Car, Mail, Phone } from "lucide-react";
import { api, ApiError, saveSession, type User } from "@/lib/api";
import { ThemeToggle } from "@/components/theme";

export default function LoginPage() {
  const [method, setMethod] = useState<"email" | "phone">("phone");
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
    "w-full rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-brand-500 focus:ring-4 focus:ring-brand-500/15 dark:border-white/10 dark:bg-white/[0.04] dark:text-white dark:placeholder:text-slate-500";
  const tab = (active: boolean) =>
    `flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition ${
      active
        ? "bg-white text-slate-900 shadow-sm dark:bg-white/[0.1] dark:text-white"
        : "text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200"
    }`;
  const btn =
    "flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-br from-brand-500 to-brand-600 py-3 text-sm font-bold text-white shadow-[0_16px_30px_-12px_rgba(232,30,45,0.6)] transition hover:brightness-110 disabled:opacity-50";

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.15fr_1fr]">
      {/* Command-center map panel (always dark) */}
      <div className="relative hidden overflow-hidden bg-[#0a0a10] p-8 lg:block">
        <div className="mapgrid absolute inset-0 opacity-60 [mask-image:radial-gradient(80%_80%_at_50%_40%,#000,transparent)]" />
        <div
          className="absolute inset-0"
          style={{
            backgroundImage:
              "radial-gradient(50% 40% at 20% 8%, rgba(255,59,48,0.14), transparent 60%), radial-gradient(45% 40% at 85% 90%, rgba(139,108,255,0.10), transparent 60%)"
          }}
        />
        <div className="relative flex items-center gap-3 text-white">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-brand-500 to-brand-600 shadow-[0_10px_24px_-6px_rgba(232,30,45,0.7)]">
            <Car size={20} />
          </div>
          <div className="text-[15px] font-bold tracking-tight">Rideshare PK</div>
        </div>

        <svg viewBox="0 0 520 420" className="absolute inset-0 h-full w-full">
          <defs>
            <linearGradient id="route" x1="0" x2="1">
              <stop offset="0" stopColor="#ff3b30" stopOpacity="0.15" />
              <stop offset="1" stopColor="#ff3b30" />
            </linearGradient>
          </defs>
          <path
            d="M120 320 C 220 250, 300 270, 380 160"
            fill="none"
            stroke="url(#route)"
            strokeWidth="2.5"
            strokeDasharray="6 8"
          >
            <animate attributeName="stroke-dashoffset" from="140" to="0" dur="3s" repeatCount="indefinite" />
          </path>
          <path
            d="M380 160 C 300 120, 250 130, 150 145"
            fill="none"
            stroke="url(#route)"
            strokeWidth="2"
            strokeDasharray="5 9"
            opacity="0.8"
          >
            <animate attributeName="stroke-dashoffset" from="0" to="120" dur="4s" repeatCount="indefinite" />
          </path>
          <g>
            <circle cx="120" cy="320" r="6" fill="#ff3b30" />
            <circle cx="120" cy="320" r="6" fill="#ff3b30" opacity="0.5">
              <animate attributeName="r" from="6" to="20" dur="2.4s" repeatCount="indefinite" />
              <animate attributeName="opacity" from="0.5" to="0" dur="2.4s" repeatCount="indefinite" />
            </circle>
            <circle cx="380" cy="160" r="6" fill="#ff3b30" />
            <circle cx="380" cy="160" r="6" fill="#ff3b30" opacity="0.5">
              <animate attributeName="r" from="6" to="18" dur="2.4s" begin="0.8s" repeatCount="indefinite" />
              <animate attributeName="opacity" from="0.5" to="0" dur="2.4s" begin="0.8s" repeatCount="indefinite" />
            </circle>
            <circle cx="150" cy="145" r="5" fill="#ff6a5e" />
          </g>
        </svg>

        <div className="absolute left-[28%] top-[36%] rounded-full border border-white/10 bg-black/40 px-3 py-1.5 font-mono text-[10.5px] text-white backdrop-blur">
          142 rides live
        </div>
        <div className="absolute left-[60%] top-[58%] rounded-full border border-white/10 bg-black/40 px-3 py-1.5 font-mono text-[10.5px] text-white backdrop-blur">
          3 cities
        </div>

        <div className="absolute inset-x-8 bottom-8">
          <h2 className="text-[26px] font-bold leading-tight tracking-tight text-white">
            Operations, in real time.
          </h2>
          <p className="mt-1.5 text-sm text-slate-400">
            Karachi · Lahore · Islamabad — every corridor, live.
          </p>
        </div>
      </div>

      {/* Form panel */}
      <div className="relative flex items-center justify-center bg-white px-6 py-12 dark:bg-[#0b0b0f]">
        <div className="absolute right-6 top-6">
          <ThemeToggle />
        </div>
        <div className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <div className="mb-3 grid h-11 w-11 place-items-center rounded-xl bg-gradient-to-br from-brand-500 to-brand-600 text-white">
              <Car size={22} />
            </div>
            <div className="text-lg font-bold dark:text-white">Rideshare PK</div>
          </div>

          <p className="font-mono text-[11px] uppercase tracking-[0.16em] text-slate-400 dark:text-slate-500">
            Admin access
          </p>
          <h1 className="mt-2 text-[26px] font-extrabold tracking-tight text-slate-900 dark:text-white">
            Welcome back
          </h1>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Sign in to the operations console
          </p>

          <div className="mt-6 mb-5 flex rounded-xl bg-slate-100 p-1 dark:bg-white/[0.05]">
            <button className={tab(method === "phone")} onClick={() => setMethod("phone")}>
              <Phone size={15} /> Phone
            </button>
            <button className={tab(method === "email")} onClick={() => setMethod("email")}>
              <Mail size={15} /> Email
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
              {error && <p className="text-center text-sm text-brand-600">{error}</p>}
              <button className={btn} disabled={busy}>
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
              {error && <p className="text-center text-sm text-brand-600">{error}</p>}
              <button className={btn} disabled={busy}>
                {busy ? "Sending…" : "Send code"}
                {!busy && <ArrowRight size={16} />}
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
                <p className="flex items-center justify-center gap-1.5 rounded-xl bg-amber-50 py-2 text-center text-xs font-semibold text-amber-700 dark:bg-amber-500/15 dark:text-amber-400">
                  <Bug size={13} /> Dev code: {devCode}
                </p>
              )}
              <input
                className={`${input} text-center text-lg tracking-[0.5em]`}
                placeholder="••••••"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
              {error && <p className="text-center text-sm text-brand-600">{error}</p>}
              <button className={btn} disabled={busy}>
                {busy ? "Verifying…" : "Verify"}
              </button>
            </form>
          )}

          <p className="mt-6 text-center text-xs text-slate-400 dark:text-slate-500">
            Admin access only — regular accounts are rejected.
          </p>
        </div>
      </div>
    </div>
  );
}

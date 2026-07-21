"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Car,
  LayoutDashboard,
  LogOut,
  ShieldCheck,
  Users as UsersIcon
} from "lucide-react";
import { ApiError, clearSession, currentUser, type User } from "@/lib/api";

const NAV = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/verifications/", label: "Verifications", icon: ShieldCheck },
  { href: "/rides/", label: "Rides", icon: Car },
  { href: "/users/", label: "Users", icon: UsersIcon }
];

export function initials(user: User): string {
  const source = user.name ?? user.email ?? user.phone ?? "A";
  return source
    .split(/[\s@]+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

/** Auth-guarded console shell: refined dark sidebar + glassy topbar. */
export default function Shell({
  title,
  subtitle,
  children
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);
  const [denied, setDenied] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const u = currentUser();
    if (!u) {
      window.location.assign("/admin/login/");
      return;
    }
    setUser(u);
    setReady(true);
  }, [router]);

  useEffect(() => {
    const onDenied = () => setDenied(true);
    window.addEventListener("admin-denied", onDenied);
    return () => window.removeEventListener("admin-denied", onDenied);
  }, []);

  if (!ready || !user) return null;

  if (denied) {
    return (
      <div className="grid min-h-screen place-items-center bg-page p-6">
        <div className="card-soft w-full max-w-md rounded-3xl border border-slate-100 bg-white p-8 text-center">
          <div className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-2xl bg-brand-50 text-brand-600">
            <ShieldCheck size={26} />
          </div>
          <h1 className="text-lg font-bold">Admin access required</h1>
          <p className="mt-2 text-sm text-slate-500">
            {user.email ?? user.phone} isn&apos;t an admin. Grant access with
            scripts/make-admin.mjs, then sign in again.
          </p>
          <button
            className="mt-6 rounded-xl bg-brand-600 px-5 py-2.5 text-sm font-bold text-white transition hover:bg-brand-700"
            onClick={() => {
              clearSession();
              window.location.assign("/admin/login/");
            }}
          >
            Switch account
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <aside className="fixed inset-y-0 z-20 flex w-64 flex-col border-r border-white/[0.06] bg-sidebar text-slate-300">
        <div className="flex items-center gap-3 px-5 py-6">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-brand-500 to-brand-600 text-white shadow-[0_8px_20px_-6px_rgba(232,30,45,0.7)]">
            <Car size={20} />
          </div>
          <div>
            <div className="text-[15px] font-bold tracking-tight text-white">Rideshare PK</div>
            <div className="text-[11px] font-medium text-slate-500">Operations console</div>
          </div>
        </div>

        <div className="px-6 pb-2 pt-4 text-[10px] font-bold uppercase tracking-[0.14em] text-slate-600">
          Menu
        </div>
        <nav className="flex-1 space-y-1 px-3">
          {NAV.map((item) => {
            const active =
              item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`group relative flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                  active
                    ? "bg-white/[0.06] text-white"
                    : "text-slate-400 hover:bg-white/[0.04] hover:text-white"
                }`}
              >
                {active && (
                  <span className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-brand-500" />
                )}
                <Icon
                  size={18}
                  className={active ? "text-brand-500" : "text-slate-500 group-hover:text-slate-300"}
                />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="m-3 rounded-2xl border border-white/[0.06] bg-white/[0.03] p-3">
          <div className="flex items-center gap-3">
            <div className="grid h-9 w-9 place-items-center rounded-lg bg-gradient-to-br from-brand-500 to-brand-600 text-sm font-bold text-white">
              {initials(user)}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold text-white">
                {user.name ?? "Admin"}
              </div>
              <div className="truncate text-[11px] text-slate-500">
                {user.email ?? user.phone}
              </div>
            </div>
            <button
              title="Log out"
              className="grid h-8 w-8 place-items-center rounded-lg text-slate-500 transition hover:bg-white/[0.06] hover:text-white"
              onClick={() => {
                clearSession();
                window.location.assign("/admin/login/");
              }}
            >
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>

      <div className="ml-64 flex-1">
        <header className="sticky top-0 z-10 flex items-center justify-between border-b border-slate-200/70 bg-page/80 px-8 py-4 backdrop-blur-xl">
          <div>
            <h1 className="text-[18px] font-bold tracking-tight text-slate-900">{title}</h1>
            {subtitle && <p className="mt-0.5 text-xs text-slate-400">{subtitle}</p>}
          </div>
          <div className="hidden items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-500 sm:flex">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            Live
          </div>
        </header>
        <main className="p-8">{children}</main>
      </div>
    </div>
  );
}

/** Route API failures: 403 → denied screen, 401 → login. */
export function routeApiError(e: unknown, _router?: unknown): string {
  if (e instanceof ApiError) {
    if (e.status === 403) {
      window.dispatchEvent(new Event("admin-denied"));
      return "";
    }
    if (e.status === 401) {
      window.location.assign("/admin/login/");
      return "";
    }
    return e.message;
  }
  return "Request failed — check your connection";
}

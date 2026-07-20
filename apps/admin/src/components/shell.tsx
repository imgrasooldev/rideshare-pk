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

/** Auth-guarded Metronic-style shell: dark sidebar + white topbar. */
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
        <div className="card-soft w-full max-w-md rounded-2xl bg-white p-8 text-center">
          <div className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-full bg-red-50 text-2xl">
            ⛔
          </div>
          <h1 className="text-lg font-bold">Not an admin</h1>
          <p className="mt-2 text-sm text-slate-500">
            {user.email ?? user.phone} has no admin access. Grant it with
            scripts/make-admin.mjs, then sign in again.
          </p>
          <button
            className="mt-6 rounded-lg bg-brand-400 px-5 py-2.5 text-sm font-bold text-slate-900 hover:bg-brand-300"
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
      <aside className="fixed inset-y-0 flex w-64 flex-col bg-sidebar text-slate-300">
        <div className="flex items-center gap-3 px-6 py-6">
          <div className="grid h-10 w-10 place-items-center rounded-xl bg-brand-400 text-slate-900">
            <Car size={20} />
          </div>
          <div>
            <div className="text-[15px] font-bold text-white">Rideshare PK</div>
            <div className="text-xs text-slate-500">Operations console</div>
          </div>
        </div>
        <nav className="mt-2 flex-1 space-y-1 px-3">
          {NAV.map((item) => {
            const active =
              item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                  active
                    ? "bg-brand-400/15 text-white"
                    : "hover:bg-sidebar-hover hover:text-white"
                }`}
              >
                <Icon size={18} className={active ? "text-brand-400" : ""} />
                {item.label}
                {active && <span className="ml-auto h-5 w-1 rounded-full bg-brand-400" />}
              </Link>
            );
          })}
        </nav>
        <div className="border-t border-white/5 p-4">
          <div className="flex items-center gap-3">
            <div className="grid h-9 w-9 place-items-center rounded-lg bg-brand-400/20 text-sm font-bold text-brand-400">
              {initials(user)}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-sm font-semibold text-white">
                {user.name ?? "Admin"}
              </div>
              <div className="truncate text-xs text-slate-500">
                {user.email ?? user.phone}
              </div>
            </div>
            <button
              title="Log out"
              className="text-slate-500 hover:text-white"
              onClick={() => {
                clearSession();
                window.location.assign("/admin/login/");
              }}
            >
              <LogOut size={17} />
            </button>
          </div>
        </div>
      </aside>

      <div className="ml-64 flex-1">
        <header className="sticky top-0 z-10 border-b border-slate-200/70 bg-white/80 px-8 py-4 backdrop-blur">
          <h1 className="text-lg font-bold text-slate-800">{title}</h1>
          {subtitle && <p className="text-xs text-slate-400">{subtitle}</p>}
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

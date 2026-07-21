"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  AlarmCheck,
  Car,
  CircleGauge,
  MapPin,
  ShieldCheck,
  Ticket,
  Users
} from "lucide-react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis
} from "recharts";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Card, Empty, StatCard } from "@/components/ui";
import { api, type AdminRide, type DayPoint, type Metrics } from "@/lib/api";

export default function DashboardPage() {
  const router = useRouter();
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [series, setSeries] = useState<DayPoint[] | null>(null);
  const [rides, setRides] = useState<AdminRide[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.metrics().then(setMetrics).catch((e) => setError(routeApiError(e, router)));
    api.timeseries(14).then(setSeries).catch((e) => setError(routeApiError(e, router)));
    api.rides().then(setRides).catch(() => {});
  }, [router]);

  const corridors = useMemo(() => {
    if (!rides) return [];
    const map = new Map<string, { key: string; total: number; booked: number }>();
    for (const r of rides) {
      const key = `${r.originLabel} → ${r.destLabel}`;
      const e = map.get(key) ?? { key, total: 0, booked: 0 };
      e.total += r.seatsTotal;
      e.booked += Math.max(0, r.seatsTotal - r.seatsAvailable);
      map.set(key, e);
    }
    return [...map.values()]
      .filter((e) => e.total > 0)
      .map((e) => ({ ...e, fill: e.booked / e.total }))
      .sort((a, b) => b.fill - a.fill)
      .slice(0, 5);
  }, [rides]);

  return (
    <Shell title="Dashboard" subtitle="Marketplace health at a glance">
      {error && <Empty message={error} />}
      {!metrics ? (
        !error && <Empty message="Loading metrics…" />
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
          {/* Hero chart — spans 2×2 */}
          <Card className="flex flex-col p-5 md:col-span-2 xl:row-span-2">
            <div className="mb-3 flex items-start justify-between">
              <div>
                <h2 className="text-[15px] font-bold text-slate-900 dark:text-white">Activity</h2>
                <p className="text-xs text-slate-400 dark:text-slate-500">
                  Signups, rides and bookings — last 14 days
                </p>
              </div>
              <div className="hidden items-center gap-3 text-[11px] font-medium text-slate-500 dark:text-slate-400 sm:flex">
                {[
                  { c: "#38bdf8", l: "Signups" },
                  { c: "#ff3b30", l: "Rides" },
                  { c: "#8b5cf6", l: "Bookings" }
                ].map((x) => (
                  <span key={x.l} className="flex items-center gap-1.5">
                    <span className="h-2 w-2 rounded-full" style={{ background: x.c }} /> {x.l}
                  </span>
                ))}
              </div>
            </div>
            <div className="min-h-[230px] flex-1">
              {!series || series.length === 0 ? (
                <Empty message="No activity data yet." />
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={series} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
                    <defs>
                      <linearGradient id="gS" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#38bdf8" stopOpacity={0.22} />
                        <stop offset="100%" stopColor="#38bdf8" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="gR" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#ff3b30" stopOpacity={0.28} />
                        <stop offset="100%" stopColor="#ff3b30" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="gB" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#8b5cf6" stopOpacity={0.22} />
                        <stop offset="100%" stopColor="#8b5cf6" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="rgba(148,163,184,0.18)"
                      vertical={false}
                    />
                    <XAxis
                      dataKey="day"
                      tickFormatter={(d: string) => d.slice(5)}
                      tick={{ fontSize: 11, fill: "#94a3b8" }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <YAxis
                      allowDecimals={false}
                      tick={{ fontSize: 11, fill: "#94a3b8" }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <Tooltip
                      contentStyle={{
                        borderRadius: 12,
                        border: "1px solid rgba(148,163,184,0.3)",
                        fontSize: 12,
                        background: "#0f0f16",
                        color: "#fff",
                        boxShadow: "0 12px 30px rgb(0 0 0 / 0.4)"
                      }}
                    />
                    <Area type="monotone" dataKey="signups" stroke="#38bdf8" strokeWidth={2} fill="url(#gS)" />
                    <Area type="monotone" dataKey="rides" stroke="#ff3b30" strokeWidth={2.5} fill="url(#gR)" />
                    <Area type="monotone" dataKey="bookings" stroke="#8b5cf6" strokeWidth={2} fill="url(#gB)" />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </Card>

          {/* KPI quadrant — auto-flows into the right 2×2 */}
          <StatCard icon={Users} label="Total users" value={metrics.totalUsers} tint="blue" />
          <StatCard icon={Car} label="Open rides" value={metrics.openRides} tint="brand" />
          <StatCard
            icon={CircleGauge}
            label="Fill rate"
            value={`${Math.round(metrics.fillRate * 100)}%`}
            hint={`${metrics.seatsBooked}/${metrics.seatsOffered} seats`}
            tint="violet"
          />
          <StatCard
            icon={Ticket}
            label="Active bookings"
            value={metrics.activeBookings}
            tint="emerald"
          />

          {/* Corridor leaderboard — real, computed from rides */}
          <Card className="p-5 md:col-span-2">
            <div className="mb-1 flex items-baseline justify-between">
              <h2 className="text-[15px] font-bold text-slate-900 dark:text-white">Top corridors</h2>
              <span className="text-xs text-slate-400 dark:text-slate-500">by fill rate</span>
            </div>
            {corridors.length === 0 ? (
              <Empty message="No ride data yet." />
            ) : (
              <div className="mt-3 space-y-3">
                {corridors.map((c) => (
                  <div key={c.key} className="flex items-center gap-3">
                    <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-slate-700 dark:text-slate-200">
                      {c.key}
                    </span>
                    <span className="h-1.5 w-24 overflow-hidden rounded-full bg-slate-100 dark:bg-white/[0.08]">
                      <span
                        className="block h-full rounded-full bg-gradient-to-r from-brand-500 to-brand-600"
                        style={{ width: `${Math.round(c.fill * 100)}%` }}
                      />
                    </span>
                    <span className="w-9 text-right font-mono text-[12px] font-bold text-slate-700 tabular-nums dark:text-slate-200">
                      {Math.round(c.fill * 100)}%
                    </span>
                  </div>
                ))}
              </div>
            )}
          </Card>

          {/* Live map — branded decorative panel */}
          <Card className="overflow-hidden p-5 md:col-span-2">
            <div className="mb-1 flex items-baseline justify-between">
              <h2 className="text-[15px] font-bold text-slate-900 dark:text-white">Live map</h2>
              <span className="flex items-center gap-1.5 text-xs font-medium text-emerald-600 dark:text-emerald-400">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" /> {metrics.openRides} open
              </span>
            </div>
            <div className="relative mt-3 h-[132px] overflow-hidden rounded-xl bg-[#0b0b12]">
              <div className="mapgrid absolute inset-0 opacity-70" />
              <svg viewBox="0 0 400 132" className="absolute inset-0 h-full w-full">
                <path
                  d="M60 96 C 150 62,230 74,330 44"
                  fill="none"
                  stroke="#ff3b30"
                  strokeWidth="2"
                  strokeDasharray="5 7"
                >
                  <animate attributeName="stroke-dashoffset" from="120" to="0" dur="3s" repeatCount="indefinite" />
                </path>
                <circle cx="60" cy="96" r="5" fill="#ff3b30" />
                <circle cx="330" cy="44" r="5" fill="#ff6a5e" />
                <circle cx="215" cy="70" r="4" fill="#34d399" />
              </svg>
              <div className="absolute bottom-3 left-3 flex items-center gap-1.5 rounded-full border border-white/10 bg-black/40 px-2.5 py-1 text-[10.5px] text-white backdrop-blur">
                <MapPin size={11} /> Karachi · Lahore · Islamabad
              </div>
            </div>
          </Card>

          {/* Secondary stats */}
          <StatCard icon={ShieldCheck} label="Verified users" value={metrics.verifiedUsers} tint="emerald" />
          <StatCard icon={Car} label="Drivers" value={metrics.drivers} tint="violet" />
          <StatCard
            icon={AlarmCheck}
            label="Pending KYC"
            value={metrics.pendingVerifications}
            tint="amber"
          />
          <StatCard icon={Ticket} label="Total bookings" value={metrics.totalBookings} tint="blue" />

          {/* Recent activity */}
          <Card className="p-5 md:col-span-2 xl:col-span-4">
            <h2 className="mb-3 text-[15px] font-bold text-slate-900 dark:text-white">Recent rides</h2>
            {!rides || rides.length === 0 ? (
              <Empty message="No rides yet." />
            ) : (
              <div className="divide-y divide-slate-100 dark:divide-white/[0.06]">
                {rides.slice(0, 6).map((r) => (
                  <div key={r.id} className="flex items-center gap-3 py-2.5">
                    <Avatar text={(r.driverName ?? "?").slice(0, 2).toUpperCase()} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[13px] font-semibold text-slate-800 dark:text-slate-100">
                        {r.originLabel} → {r.destLabel}
                      </div>
                      <div className="text-[11.5px] text-slate-400 dark:text-slate-500">
                        {r.driverName ?? "Driver"} · {r.vehicleType} · Rs {r.pricePerSeat}
                      </div>
                    </div>
                    <span className="font-mono text-[12px] font-bold text-slate-500 tabular-nums dark:text-slate-400">
                      {r.seatsAvailable}/{r.seatsTotal}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      )}
    </Shell>
  );
}

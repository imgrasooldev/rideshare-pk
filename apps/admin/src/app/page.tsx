"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Activity,
  AlarmCheck,
  Car,
  CircleGauge,
  ShieldCheck,
  Siren,
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
import { Card, Empty, StatCard } from "@/components/ui";
import { api, type DayPoint, type Metrics } from "@/lib/api";

export default function DashboardPage() {
  const router = useRouter();
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [series, setSeries] = useState<DayPoint[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.metrics().then(setMetrics).catch((e) => setError(routeApiError(e, router)));
    api.timeseries(14).then(setSeries).catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  return (
    <Shell title="Dashboard" subtitle="Marketplace health at a glance">
      {error && <Empty message={error} />}
      {!metrics ? (
        !error && <Empty message="Loading metrics…" />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-5 md:grid-cols-3 xl:grid-cols-4">
            <StatCard icon={Users} label="Total users" value={metrics.totalUsers} tint="blue" />
            <StatCard
              icon={ShieldCheck}
              label="Verified users"
              value={metrics.verifiedUsers}
              tint="brand"
            />
            <StatCard icon={Car} label="Open rides" value={metrics.openRides} tint="brand" />
            <StatCard
              icon={CircleGauge}
              label="Fill rate"
              value={`${Math.round(metrics.fillRate * 100)}%`}
              hint={`${metrics.seatsBooked}/${metrics.seatsOffered} seats booked`}
              tint="violet"
            />
            <StatCard
              icon={Ticket}
              label="Active bookings"
              value={metrics.activeBookings}
              tint="blue"
            />
            <StatCard icon={Activity} label="Drivers" value={metrics.drivers} tint="violet" />
            <StatCard
              icon={AlarmCheck}
              label="Pending verifications"
              value={metrics.pendingVerifications}
              tint="amber"
            />
            <StatCard icon={Siren} label="SOS events" value={metrics.sosEvents} tint="red" />
          </div>

          <Card className="mt-6 p-6">
            <div className="mb-1 flex items-baseline justify-between">
              <h2 className="text-[15px] font-bold text-slate-800">Activity — last 14 days</h2>
              <span className="text-xs text-slate-400">signups · rides · bookings</span>
            </div>
            {!series || series.length === 0 ? (
              <Empty message="No activity data yet." />
            ) : (
              <div className="h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={series} margin={{ top: 16, right: 8, left: -18, bottom: 0 }}>
                    <defs>
                      <linearGradient id="gSignups" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.25} />
                        <stop offset="100%" stopColor="#3b82f6" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="gRides" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#00a06b" stopOpacity={0.25} />
                        <stop offset="100%" stopColor="#00a06b" stopOpacity={0} />
                      </linearGradient>
                      <linearGradient id="gBookings" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#8b5cf6" stopOpacity={0.25} />
                        <stop offset="100%" stopColor="#8b5cf6" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#eef2f5" vertical={false} />
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
                        border: "1px solid #e2e8f0",
                        fontSize: 12,
                        boxShadow: "0 8px 24px rgb(76 87 125 / 0.12)"
                      }}
                    />
                    <Area
                      type="monotone"
                      dataKey="signups"
                      stroke="#3b82f6"
                      strokeWidth={2}
                      fill="url(#gSignups)"
                    />
                    <Area
                      type="monotone"
                      dataKey="rides"
                      stroke="#00a06b"
                      strokeWidth={2}
                      fill="url(#gRides)"
                    />
                    <Area
                      type="monotone"
                      dataKey="bookings"
                      stroke="#8b5cf6"
                      strokeWidth={2}
                      fill="url(#gBookings)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            )}
          </Card>

          <Card className="mt-6 border-l-4 border-l-brand-500 p-5">
            <div className="text-sm font-bold text-slate-800">Liquidity note</div>
            <p className="mt-1 text-[13px] leading-relaxed text-slate-500">
              Fill rate = booked seats ÷ offered seats on open and full rides. This is the
              number that decides the marketplace — focus on one corridor until it stays above
              40%.
            </p>
          </Card>
        </>
      )}
    </Shell>
  );
}

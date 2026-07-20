"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Badge, Card, Empty, statusColor, Td, Th } from "@/components/ui";
import { api, type AdminRide } from "@/lib/api";

const VEHICLE_EMOJI: Record<string, string> = {
  car: "🚗",
  bike: "🏍️",
  hiace: "🚐",
  minivan: "🚌"
};

export default function RidesPage() {
  const router = useRouter();
  const [rides, setRides] = useState<AdminRide[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.rides().then(setRides).catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  return (
    <Shell title="Rides" subtitle="Most recent rides across the marketplace">
      <Card className="overflow-x-auto">
        {error ? (
          <Empty message={error} />
        ) : !rides ? (
          <Empty message="Loading rides…" />
        ) : rides.length === 0 ? (
          <Empty message="No rides yet." />
        ) : (
          <table className="w-full min-w-4xl">
            <thead className="border-b border-slate-100">
              <tr>
                <Th>Route</Th>
                <Th>Departs</Th>
                <Th>Vehicle</Th>
                <Th>Seats</Th>
                <Th>Price</Th>
                <Th>Driver</Th>
                <Th>Status</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {rides.map((r) => {
                const booked = r.seatsTotal - r.seatsAvailable;
                const pct = r.seatsTotal > 0 ? (booked / r.seatsTotal) * 100 : 0;
                return (
                  <tr key={r.id} className="transition hover:bg-slate-50/60">
                    <Td className="font-semibold text-slate-800">
                      {r.originLabel} <span className="text-slate-300">→</span> {r.destLabel}
                    </Td>
                    <Td className="whitespace-nowrap text-slate-500">
                      {new Date(r.departAt).toLocaleString(undefined, {
                        weekday: "short",
                        day: "numeric",
                        month: "short",
                        hour: "numeric",
                        minute: "2-digit"
                      })}
                    </Td>
                    <Td>
                      <span className="mr-1">{VEHICLE_EMOJI[r.vehicleType] ?? "🚗"}</span>
                      <span className="capitalize">{r.vehicleType}</span>
                    </Td>
                    <Td>
                      <div className="flex items-center gap-2">
                        <div className="h-1.5 w-16 overflow-hidden rounded-full bg-slate-100">
                          <div
                            className="h-full rounded-full bg-brand-500"
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                        <span className="text-xs text-slate-500">
                          {booked}/{r.seatsTotal}
                        </span>
                      </div>
                    </Td>
                    <Td className="font-bold text-slate-800">Rs {r.pricePerSeat}</Td>
                    <Td className="text-slate-500">
                      {r.driverName ?? r.driverPhone ?? "—"}
                    </Td>
                    <Td>
                      <Badge color={statusColor(r.status)}>{r.status}</Badge>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>
    </Shell>
  );
}

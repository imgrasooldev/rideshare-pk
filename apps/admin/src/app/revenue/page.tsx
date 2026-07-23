"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { BadgeDollarSign, Coins, HandCoins, TrendingUp, Wallet } from "lucide-react";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Badge, Card, Empty, StatCard, Td, Th } from "@/components/ui";
import { api, type DriverSettlement, type RevenueSummary } from "@/lib/api";

const rs = (n: number) => `Rs ${n.toLocaleString("en-PK")}`;

export default function RevenuePage() {
  const router = useRouter();
  const [rev, setRev] = useState<RevenueSummary | null>(null);
  const [drivers, setDrivers] = useState<DriverSettlement[] | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    api.revenue().then(setRev).catch((e) => setError(routeApiError(e, router)));
    api.settlements().then(setDrivers).catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  useEffect(load, [load]);

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2800);
  };

  async function collect(d: DriverSettlement) {
    const raw = prompt(
      `Record a cash commission payment from ${d.name ?? "this driver"}.\nThey owe Rs ${d.owed}. Amount received:`,
      String(d.owed)
    );
    if (raw === null) return;
    const amount = Number(raw);
    if (!Number.isInteger(amount) || amount <= 0) {
      flash("Enter a whole number greater than zero.");
      return;
    }
    const reference = prompt("Reference (deposit slip / note) — optional:") ?? undefined;
    setBusyId(d.driverId);
    try {
      await api.collectCommission(d.driverId, amount, reference || undefined);
      flash(`Recorded ${rs(amount)} from ${d.name ?? "driver"}.`);
      load();
    } catch (e) {
      setError(routeApiError(e, router));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <Shell title="Revenue" subtitle="Commission accrued, collected and outstanding — cash settlements">
      {error && <Empty message={error} />}

      {!rev ? (
        !error && <Empty message="Loading revenue…" />
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard icon={TrendingUp} label="Gross fares" value={rs(rev.grossFares)} tint="blue" />
            <StatCard
              icon={Coins}
              label={`Commission accrued (${Math.round(rev.commissionRate * 100)}%)`}
              value={rs(rev.commissionAccrued)}
              tint="violet"
            />
            <StatCard
              icon={HandCoins}
              label="Collected"
              value={rs(rev.commissionCollected)}
              hint={`${rs(rev.collectedThisMonth)} this month`}
              tint="emerald"
            />
            <StatCard
              icon={Wallet}
              label="Outstanding"
              value={rs(rev.commissionOutstanding)}
              hint={`${rev.driversOwing} driver${rev.driversOwing === 1 ? "" : "s"} owing`}
              tint="brand"
            />
          </div>

          <Card className="mt-6 overflow-x-auto">
            <div className="flex items-center gap-2 border-b border-slate-100 px-6 py-4 dark:border-white/[0.06]">
              <BadgeDollarSign size={16} className="text-brand-600" />
              <h2 className="text-[15px] font-bold text-slate-800 dark:text-white">Driver settlements</h2>
              <span className="text-xs text-slate-400">largest balances first</span>
            </div>

            {!drivers ? (
              <Empty message="Loading drivers…" />
            ) : drivers.length === 0 ? (
              <Empty message="No commission has accrued yet." />
            ) : (
              <table className="w-full min-w-3xl">
                <thead className="border-b border-slate-100 dark:border-white/[0.06]">
                  <tr>
                    <Th>Driver</Th>
                    <Th>Gross fares</Th>
                    <Th>Commission</Th>
                    <Th>Collected</Th>
                    <Th>Owed</Th>
                    <Th>Last paid</Th>
                    <Th />
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50 dark:divide-white/[0.04]">
                  {drivers.map((d) => (
                    <tr key={d.driverId} className="transition hover:bg-slate-50/60 dark:hover:bg-white/[0.03]">
                      <Td>
                        <div className="flex items-center gap-3">
                          <Avatar text={(d.name ?? "?").slice(0, 2).toUpperCase()} />
                          <div className="min-w-0">
                            <div className="truncate text-[13px] font-bold text-slate-800 dark:text-slate-100">
                              {d.name ?? "Unnamed"}
                            </div>
                            <div className="truncate text-xs text-slate-400">{d.phone ?? "—"}</div>
                          </div>
                        </div>
                      </Td>
                      <Td className="font-mono tabular-nums text-slate-600 dark:text-slate-300">{rs(d.grossFares)}</Td>
                      <Td className="font-mono tabular-nums text-slate-600 dark:text-slate-300">{rs(d.commissionAccrued)}</Td>
                      <Td className="font-mono tabular-nums text-emerald-600 dark:text-emerald-400">{rs(d.collected)}</Td>
                      <Td>
                        {d.owed > 0 ? (
                          <Badge color={d.owed >= 500 ? "red" : "amber"}>{rs(d.owed)}</Badge>
                        ) : (
                          <Badge color="green">settled</Badge>
                        )}
                      </Td>
                      <Td className="whitespace-nowrap text-slate-500">
                        {d.lastSettledAt ? new Date(d.lastSettledAt).toLocaleDateString() : "—"}
                      </Td>
                      <Td>
                        <button
                          disabled={busyId === d.driverId || d.owed <= 0}
                          onClick={() => collect(d)}
                          className="inline-flex items-center gap-1.5 rounded-lg bg-brand-50 px-3 py-2 text-xs font-bold text-brand-700 transition hover:bg-brand-100 disabled:opacity-40 dark:bg-brand-500/10 dark:text-brand-300"
                        >
                          <HandCoins size={14} /> Record payment
                        </button>
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </Card>
        </>
      )}

      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 rounded-xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-2xl">
          {toast}
        </div>
      )}
    </Shell>
  );
}

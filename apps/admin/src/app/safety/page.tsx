"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Ban, Flag, ShieldCheck, ShieldOff } from "lucide-react";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Badge, Card, Empty, Td, Th } from "@/components/ui";
import { api, type Dispute, type ReportedUser } from "@/lib/api";

function initialsOf(u: ReportedUser): string {
  const source = u.name ?? u.phone ?? "?";
  return source
    .replace(/^\+92/, "")
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

/** More reports = more urgent. Colour carries the triage signal. */
function severity(count: number): "red" | "amber" | "gray" {
  if (count >= 3) return "red";
  if (count === 2) return "amber";
  return "gray";
}

export default function SafetyPage() {
  const router = useRouter();
  const [reported, setReported] = useState<ReportedUser[] | null>(null);
  const [disputes, setDisputes] = useState<Dispute[] | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    api.reportedUsers().then(setReported).catch((e) => setError(routeApiError(e, router)));
    api.openDisputes().then(setDisputes).catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  useEffect(load, [load]);

  const flash = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2800);
  };

  async function toggleSuspension(user: ReportedUser) {
    const suspending = !user.suspendedAt;
    const reason = suspending
      ? (prompt("Reason for suspension (shown in the audit trail):") ?? undefined)
      : undefined;
    if (suspending && reason === undefined) return;

    setBusyId(user.userId);
    try {
      await api.setSuspended(user.userId, suspending, reason);
      flash(suspending ? "Account suspended — they can no longer sign in." : "Account restored.");
      load();
    } catch (e) {
      setError(routeApiError(e, router));
    } finally {
      setBusyId(null);
    }
  }

  /** Complaints filed against a given person, newest first. */
  const reportsAbout = (userId: string) =>
    (disputes ?? []).filter((d) => d.reportedUserId === userId);

  return (
    <Shell title="Safety" subtitle="Reported people and account suspensions">
      {error && <Empty message={error} />}

      <Card className="overflow-x-auto">
        <div className="flex items-center gap-2 border-b border-slate-100 px-6 py-4">
          <Flag size={16} className="text-brand-600" />
          <h2 className="text-[15px] font-bold text-slate-800">Reported people</h2>
          <span className="text-xs text-slate-400">
            one complaint is noise — a pattern is the signal
          </span>
        </div>

        {!reported ? (
          <Empty message="Loading reports…" />
        ) : reported.length === 0 ? (
          <div className="py-16 text-center">
            <div className="mx-auto mb-3 grid h-12 w-12 place-items-center rounded-full bg-brand-50 text-brand-600">
              <ShieldCheck size={22} />
            </div>
            <div className="text-sm font-semibold text-slate-700">Nobody has been reported</div>
            <div className="text-xs text-slate-400">Your marketplace is behaving. 🎉</div>
          </div>
        ) : (
          <table className="w-full min-w-3xl">
            <thead className="border-b border-slate-100">
              <tr>
                <Th>Person</Th>
                <Th>Reports</Th>
                <Th>Most recent complaint</Th>
                <Th>Last reported</Th>
                <Th>Status</Th>
                <Th />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {reported.map((u) => {
                const latest = reportsAbout(u.userId)[0];
                return (
                  <tr key={u.userId} className="transition hover:bg-slate-50/60">
                    <Td>
                      <div className="flex items-center gap-3">
                        <Avatar text={initialsOf(u)} />
                        <div className="min-w-0">
                          <div className="truncate text-[13px] font-bold text-slate-800">
                            {u.name ?? "Unnamed"}
                          </div>
                          <div className="truncate text-xs text-slate-400">{u.phone ?? "—"}</div>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <Badge color={severity(u.reportCount)}>
                        {u.reportCount} {u.reportCount === 1 ? "report" : "reports"}
                      </Badge>
                    </Td>
                    <Td className="max-w-sm">
                      {latest ? (
                        <>
                          <div className="text-[13px] font-semibold text-slate-700">
                            {latest.category}
                          </div>
                          <div className="truncate text-xs text-slate-400">{latest.message}</div>
                        </>
                      ) : (
                        <span className="text-slate-300">—</span>
                      )}
                    </Td>
                    <Td className="whitespace-nowrap text-slate-500">
                      {new Date(u.lastReportedAt).toLocaleDateString()}
                    </Td>
                    <Td>
                      {u.suspendedAt ? (
                        <Badge color="red">suspended</Badge>
                      ) : (
                        <Badge color="green">active</Badge>
                      )}
                    </Td>
                    <Td>
                      <button
                        disabled={busyId === u.userId}
                        onClick={() => toggleSuspension(u)}
                        className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-bold transition disabled:opacity-50 ${
                          u.suspendedAt
                            ? "bg-brand-50 text-brand-700 hover:bg-brand-100"
                            : "bg-red-50 text-red-700 hover:bg-red-100"
                        }`}
                      >
                        {u.suspendedAt ? (
                          <>
                            <ShieldCheck size={14} /> Restore
                          </>
                        ) : (
                          <>
                            <Ban size={14} /> Suspend
                          </>
                        )}
                      </button>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      <Card className="mt-6">
        <div className="flex items-center gap-2 border-b border-slate-100 px-6 py-4">
          <ShieldOff size={16} className="text-amber-600" />
          <h2 className="text-[15px] font-bold text-slate-800">Open complaints</h2>
        </div>
        {!disputes ? (
          <Empty message="Loading complaints…" />
        ) : disputes.length === 0 ? (
          <Empty message="No open complaints." />
        ) : (
          <ul className="divide-y divide-slate-100">
            {disputes.map((d) => (
              <li key={d.id} className="flex items-start gap-4 px-6 py-4">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-bold text-slate-800">{d.category}</span>
                    {d.reportedUserId && <Badge color="amber">about a person</Badge>}
                  </div>
                  <p className="mt-1 text-[13px] text-slate-600">{d.message}</p>
                  <div className="mt-1 text-xs text-slate-400">
                    Filed {new Date(d.createdAt).toLocaleString()}
                  </div>
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    className="rounded-lg bg-brand-50 px-3 py-2 text-xs font-bold text-brand-700 hover:bg-brand-100"
                    onClick={async () => {
                      await api.resolveDispute(d.id, "resolved", prompt("Resolution note:") ?? undefined);
                      flash("Complaint resolved");
                      load();
                    }}
                  >
                    Resolve
                  </button>
                  <button
                    className="rounded-lg bg-slate-100 px-3 py-2 text-xs font-bold text-slate-600 hover:bg-slate-200"
                    onClick={async () => {
                      await api.resolveDispute(d.id, "dismissed");
                      flash("Complaint dismissed");
                      load();
                    }}
                  >
                    Dismiss
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>

      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 rounded-xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-2xl">
          {toast}
        </div>
      )}
    </Shell>
  );
}

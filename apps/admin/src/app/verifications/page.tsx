"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { BadgeCheck, ExternalLink, ShieldCheck, X } from "lucide-react";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Badge, Card, Empty } from "@/components/ui";
import { api, type Verification } from "@/lib/api";

export default function VerificationsPage() {
  const router = useRouter();
  const [items, setItems] = useState<Verification[] | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    api
      .verificationQueue()
      .then((q) => setItems(q.items))
      .catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  useEffect(load, [load]);

  async function review(id: string, action: "approve" | "reject") {
    const notes =
      action === "reject" ? (prompt("Reason shown to the user:") ?? undefined) : undefined;
    if (action === "reject" && notes === undefined) return;
    setBusyId(id);
    try {
      await api.review(id, action, notes);
      setToast(action === "approve" ? "Approved — user is now trusted" : "Rejected");
      setTimeout(() => setToast(null), 2500);
      load();
    } catch (e) {
      setError(routeApiError(e, router));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <Shell title="Verifications" subtitle="CNIC, license and vehicle document review">
      <Card>
        {error ? (
          <Empty message={error} />
        ) : !items ? (
          <Empty message="Loading queue…" />
        ) : items.length === 0 ? (
          <div className="py-16 text-center">
            <div className="mx-auto mb-3 grid h-12 w-12 place-items-center rounded-full bg-brand-50 text-brand-600">
              <ShieldCheck size={22} />
            </div>
            <div className="text-sm font-semibold text-slate-700">Queue is clear</div>
            <div className="text-xs text-slate-400">Nothing pending review. 🎉</div>
          </div>
        ) : (
          <ul className="divide-y divide-slate-100">
            {items.map((v) => (
              <li key={v.id} className="flex items-center gap-4 px-6 py-4">
                <Avatar text={v.type.slice(0, 2).toUpperCase()} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-bold text-slate-800 capitalize">
                      {v.type} verification
                    </span>
                    <Badge color="amber">pending</Badge>
                  </div>
                  <div className="mt-0.5 text-xs text-slate-400">
                    User {v.userId.slice(0, 8)}… · submitted{" "}
                    {new Date(v.createdAt).toLocaleString()} ·{" "}
                    <a
                      className="inline-flex items-center gap-0.5 font-semibold text-brand-600 hover:underline"
                      href={v.docUrl}
                      target="_blank"
                      rel="noreferrer"
                    >
                      View document <ExternalLink size={11} />
                    </a>
                  </div>
                </div>
                <button
                  className="inline-flex items-center gap-1.5 rounded-lg bg-brand-50 px-4 py-2 text-xs font-bold text-brand-700 transition hover:bg-brand-100 disabled:opacity-50"
                  disabled={busyId === v.id}
                  onClick={() => review(v.id, "approve")}
                >
                  <BadgeCheck size={14} /> Approve
                </button>
                <button
                  className="inline-flex items-center gap-1.5 rounded-lg bg-red-50 px-4 py-2 text-xs font-bold text-red-700 transition hover:bg-red-100 disabled:opacity-50"
                  disabled={busyId === v.id}
                  onClick={() => review(v.id, "reject")}
                >
                  <X size={14} /> Reject
                </button>
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

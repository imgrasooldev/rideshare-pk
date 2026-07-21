"use client";

import type { LucideIcon } from "lucide-react";
import { TrendingDown, TrendingUp } from "lucide-react";

export function Card({
  children,
  className = "",
  hover = false
}: {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}) {
  return (
    <div
      className={`card-soft rounded-2xl border border-slate-100 bg-white dark:border-white/[0.08] dark:bg-white/[0.04] ${hover ? "card-hover" : ""} ${className}`}
    >
      {children}
    </div>
  );
}

const TINTS: Record<string, { bg: string; text: string; ring: string }> = {
  brand: {
    bg: "bg-brand-50 dark:bg-brand-500/15",
    text: "text-brand-600 dark:text-brand-400",
    ring: "ring-brand-100 dark:ring-brand-500/20"
  },
  blue: {
    bg: "bg-blue-50 dark:bg-blue-500/15",
    text: "text-blue-600 dark:text-blue-400",
    ring: "ring-blue-100 dark:ring-blue-500/20"
  },
  violet: {
    bg: "bg-violet-50 dark:bg-violet-500/15",
    text: "text-violet-600 dark:text-violet-400",
    ring: "ring-violet-100 dark:ring-violet-500/20"
  },
  amber: {
    bg: "bg-amber-50 dark:bg-amber-500/15",
    text: "text-amber-600 dark:text-amber-400",
    ring: "ring-amber-100 dark:ring-amber-500/20"
  },
  emerald: {
    bg: "bg-emerald-50 dark:bg-emerald-500/15",
    text: "text-emerald-600 dark:text-emerald-400",
    ring: "ring-emerald-100 dark:ring-emerald-500/20"
  },
  red: {
    bg: "bg-red-50 dark:bg-red-500/15",
    text: "text-red-600 dark:text-red-400",
    ring: "ring-red-100 dark:ring-red-500/20"
  }
};

export function StatCard({
  icon: Icon,
  label,
  value,
  hint,
  tint = "brand",
  delta
}: {
  icon: LucideIcon;
  label: string;
  value: string | number;
  hint?: string;
  tint?: keyof typeof TINTS;
  delta?: { value: string; up: boolean };
}) {
  const t = TINTS[tint] ?? TINTS.brand;
  return (
    <Card hover className="p-5">
      <div className="mb-4 flex items-start justify-between">
        <div
          className={`grid h-11 w-11 place-items-center rounded-xl ring-1 ${t.bg} ${t.text} ${t.ring}`}
        >
          <Icon size={20} />
        </div>
        {delta && (
          <span
            className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-[11px] font-bold ${
              delta.up
                ? "bg-emerald-50 text-emerald-600 dark:bg-emerald-500/15 dark:text-emerald-400"
                : "bg-red-50 text-red-600 dark:bg-red-500/15 dark:text-red-400"
            }`}
          >
            {delta.up ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
            {delta.value}
          </span>
        )}
      </div>
      <div className="text-[26px] font-extrabold leading-none tracking-tight text-slate-900 dark:text-white">
        {value}
      </div>
      <div className="mt-1.5 text-[13px] font-medium text-slate-500 dark:text-slate-400">{label}</div>
      {hint && <div className="mt-1 text-xs text-slate-400 dark:text-slate-500">{hint}</div>}
    </Card>
  );
}

const BADGES: Record<string, string> = {
  green: "bg-emerald-50 text-emerald-700 ring-emerald-100 dark:bg-emerald-500/15 dark:text-emerald-400 dark:ring-emerald-500/20",
  amber: "bg-amber-50 text-amber-700 ring-amber-100 dark:bg-amber-500/15 dark:text-amber-400 dark:ring-amber-500/20",
  red: "bg-red-50 text-red-700 ring-red-100 dark:bg-red-500/15 dark:text-red-400 dark:ring-red-500/20",
  gray: "bg-slate-100 text-slate-500 ring-slate-200/70 dark:bg-white/[0.06] dark:text-slate-400 dark:ring-white/10",
  blue: "bg-blue-50 text-blue-700 ring-blue-100 dark:bg-blue-500/15 dark:text-blue-400 dark:ring-blue-500/20"
};

export function Badge({
  children,
  color = "gray"
}: {
  children: React.ReactNode;
  color?: keyof typeof BADGES;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-bold capitalize ring-1 ${BADGES[color] ?? BADGES.gray}`}
    >
      {children}
    </span>
  );
}

export function statusColor(status: string): keyof typeof BADGES {
  switch (status) {
    case "open":
    case "confirmed":
    case "approved":
    case "verified":
      return "green";
    case "full":
    case "pending":
      return "amber";
    case "cancelled":
    case "rejected":
      return "red";
    default:
      return "gray";
  }
}

export function Avatar({ text, className = "" }: { text: string; className?: string }) {
  return (
    <div
      className={`grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-brand-50 to-brand-100 text-xs font-bold text-brand-700 dark:from-brand-500/20 dark:to-brand-600/20 dark:text-brand-400 ${className}`}
    >
      {text}
    </div>
  );
}

export function Th({ children }: { children?: React.ReactNode }) {
  return (
    <th className="px-5 py-3.5 text-left text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500">
      {children}
    </th>
  );
}

export function Td({
  children,
  className = ""
}: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <td className={`px-5 py-4 text-[13px] text-slate-600 dark:text-slate-300 ${className}`}>
      {children}
    </td>
  );
}

export function Empty({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 py-16 text-center">
      <div className="h-1.5 w-8 rounded-full bg-slate-200 dark:bg-white/10" />
      <div className="text-sm text-slate-400 dark:text-slate-500">{message}</div>
    </div>
  );
}

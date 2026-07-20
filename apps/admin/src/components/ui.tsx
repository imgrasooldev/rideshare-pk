"use client";

import type { LucideIcon } from "lucide-react";

export function Card({
  children,
  className = ""
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`card-soft rounded-2xl border border-slate-100 bg-white ${className}`}>
      {children}
    </div>
  );
}

const TINTS: Record<string, { bg: string; text: string }> = {
  brand: { bg: "bg-brand-50", text: "text-brand-600" },
  blue: { bg: "bg-blue-50", text: "text-blue-600" },
  violet: { bg: "bg-violet-50", text: "text-violet-600" },
  amber: { bg: "bg-amber-50", text: "text-amber-600" },
  red: { bg: "bg-red-50", text: "text-red-600" }
};

export function StatCard({
  icon: Icon,
  label,
  value,
  hint,
  tint = "brand"
}: {
  icon: LucideIcon;
  label: string;
  value: string | number;
  hint?: string;
  tint?: keyof typeof TINTS;
}) {
  const t = TINTS[tint] ?? TINTS.brand;
  return (
    <Card className="p-5">
      <div className={`mb-4 grid h-11 w-11 place-items-center rounded-xl ${t.bg} ${t.text}`}>
        <Icon size={20} />
      </div>
      <div className="text-2xl font-extrabold tracking-tight">{value}</div>
      <div className="mt-0.5 text-[13px] font-medium text-slate-400">{label}</div>
      {hint && <div className="mt-1 text-xs text-slate-400">{hint}</div>}
    </Card>
  );
}

const BADGES: Record<string, string> = {
  green: "bg-brand-50 text-brand-700",
  amber: "bg-amber-50 text-amber-700",
  red: "bg-red-50 text-red-700",
  gray: "bg-slate-100 text-slate-500",
  blue: "bg-blue-50 text-blue-700"
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
      className={`inline-block rounded-md px-2.5 py-1 text-[11px] font-bold tracking-wide ${BADGES[color] ?? BADGES.gray}`}
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
      className={`grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-brand-50 text-xs font-bold text-brand-700 ${className}`}
    >
      {text}
    </div>
  );
}

export function Th({ children }: { children?: React.ReactNode }) {
  return (
    <th className="px-4 py-3 text-left text-[11px] font-bold tracking-wider text-slate-400 uppercase">
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
  return <td className={`px-4 py-3.5 text-[13px] ${className}`}>{children}</td>;
}

export function Empty({ message }: { message: string }) {
  return <div className="py-16 text-center text-sm text-slate-400">{message}</div>;
}

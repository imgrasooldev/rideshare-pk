"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Star } from "lucide-react";
import Shell, { routeApiError } from "@/components/shell";
import { Avatar, Badge, Card, Empty, Td, Th } from "@/components/ui";
import { api, type User } from "@/lib/api";

function initialsOf(u: User): string {
  const source = u.name ?? u.email ?? u.phone ?? "?";
  return source
    .split(/[\s@]+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

export default function UsersPage() {
  const router = useRouter();
  const [users, setUsers] = useState<User[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.users().then(setUsers).catch((e) => setError(routeApiError(e, router)));
  }, [router]);

  return (
    <Shell title="Users" subtitle="Most recent signups">
      <Card className="overflow-x-auto">
        {error ? (
          <Empty message={error} />
        ) : !users ? (
          <Empty message="Loading users…" />
        ) : users.length === 0 ? (
          <Empty message="No users yet." />
        ) : (
          <table className="w-full min-w-3xl">
            <thead className="border-b border-slate-100">
              <tr>
                <Th>User</Th>
                <Th>Role</Th>
                <Th>City</Th>
                <Th>Rating</Th>
                <Th>Trust</Th>
                <Th>Joined</Th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {users.map((u) => (
                <tr key={u.id} className="transition hover:bg-slate-50/60">
                  <Td>
                    <div className="flex items-center gap-3">
                      <Avatar text={initialsOf(u)} />
                      <div className="min-w-0">
                        <div className="truncate text-[13px] font-bold text-slate-800">
                          {u.name ?? "Unnamed"}
                        </div>
                        <div className="truncate text-xs text-slate-400">
                          {u.phone ?? u.email ?? "—"}
                        </div>
                      </div>
                    </div>
                  </Td>
                  <Td>
                    <Badge color={u.role === "rider" ? "blue" : "green"}>{u.role}</Badge>
                  </Td>
                  <Td className="text-slate-500 capitalize">{u.city}</Td>
                  <Td>
                    {u.ratingAvg ? (
                      <span className="inline-flex items-center gap-1 text-[13px] font-semibold text-slate-700">
                        <Star size={13} className="fill-amber-400 text-amber-400" />
                        {u.ratingAvg.toFixed(1)}
                      </span>
                    ) : (
                      <span className="text-slate-300">—</span>
                    )}
                  </Td>
                  <Td>
                    <Badge color={u.verified ? "green" : "gray"}>
                      {u.verified ? "verified" : "unverified"}
                    </Badge>
                  </Td>
                  <Td className="text-slate-500">
                    {u.createdAt ? new Date(u.createdAt).toLocaleDateString() : "—"}
                  </Td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </Shell>
  );
}

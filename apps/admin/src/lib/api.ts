// Typed client for the admin endpoints. Tokens live in localStorage; a 401
// clears the session (refresh rotation isn't worth it for an internal console).

const BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  (typeof location !== "undefined" ? location.origin : "");

export interface User {
  id: string;
  phone: string | null;
  email: string | null;
  name: string | null;
  role: string;
  verified: boolean;
  city: string;
  ratingAvg?: number;
  createdAt?: string;
}

export interface Metrics {
  totalUsers: number;
  verifiedUsers: number;
  drivers: number;
  totalRides: number;
  openRides: number;
  totalBookings: number;
  activeBookings: number;
  seatsOffered: number;
  seatsBooked: number;
  fillRate: number;
  pendingVerifications: number;
  sosEvents: number;
}

export interface DayPoint {
  day: string;
  signups: number;
  rides: number;
  bookings: number;
}

export interface Verification {
  id: string;
  userId: string;
  type: string;
  docUrl: string;
  vehicleId: string | null;
  status: string;
  createdAt: string;
}

export interface AdminRide {
  id: string;
  originLabel: string;
  destLabel: string;
  departAt: string;
  seatsTotal: number;
  seatsAvailable: number;
  pricePerSeat: number;
  vehicleType: string;
  status: string;
  driverPhone: string | null;
  driverName: string | null;
}

export interface ReportedUser {
  userId: string;
  name: string | null;
  phone: string | null;
  reportCount: number;
  suspendedAt: string | null;
  lastReportedAt: string;
}

export interface Dispute {
  id: string;
  bookingId: string | null;
  userId: string;
  reportedUserId: string | null;
  category: string;
  message: string;
  status: string;
  createdAt: string;
}

export interface RevenueSummary {
  commissionRate: number;
  grossFares: number;
  commissionAccrued: number;
  commissionCollected: number;
  commissionOutstanding: number;
  collectedThisMonth: number;
  driversOwing: number;
}

export interface DriverSettlement {
  driverId: string;
  name: string | null;
  phone: string | null;
  grossFares: number;
  commissionAccrued: number;
  collected: number;
  owed: number;
  lastSettledAt: string | null;
}

export class ApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

function token(): string | null {
  return typeof localStorage !== "undefined" ? localStorage.getItem("admin.accessToken") : null;
}

export function saveSession(accessToken: string, user: User): void {
  localStorage.setItem("admin.accessToken", accessToken);
  localStorage.setItem("admin.user", JSON.stringify(user));
}

export function currentUser(): User | null {
  if (typeof localStorage === "undefined") return null;
  const raw = localStorage.getItem("admin.user");
  return raw ? (JSON.parse(raw) as User) : null;
}

export function clearSession(): void {
  localStorage.removeItem("admin.accessToken");
  localStorage.removeItem("admin.user");
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}/api/v1${path}`, {
    method,
    headers: {
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
      ...(token() ? { authorization: `Bearer ${token()}` } : {})
    },
    body: body !== undefined ? JSON.stringify(body) : undefined
  });
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  if (!res.ok) {
    if (res.status === 401) clearSession();
    const message =
      typeof data.message === "string"
        ? data.message
        : Array.isArray(data.message)
          ? data.message.join(", ")
          : `Request failed (${res.status})`;
    throw new ApiError(message, res.status);
  }
  return data as T;
}

export const api = {
  requestOtp: (phone: string) =>
    request<{ devCode?: string }>("POST", "/auth/otp/request", { phone }),
  verifyOtp: (phone: string, code: string) =>
    request<{ accessToken: string; user: User }>("POST", "/auth/otp/verify", { phone, code }),
  loginEmail: (email: string, password: string) =>
    request<{ accessToken: string; user: User }>("POST", "/auth/login", { email, password }),

  metrics: () => request<Metrics>("GET", "/admin/metrics"),
  timeseries: (days = 14) => request<DayPoint[]>("GET", `/admin/timeseries?days=${days}`),
  users: () => request<User[]>("GET", "/admin/users?limit=100"),
  rides: () => request<AdminRide[]>("GET", "/admin/rides?limit=100"),
  verificationQueue: () =>
    request<{ items: Verification[]; nextCursor: string | null }>(
      "GET",
      "/admin/verifications?limit=50"
    ),
  review: (id: string, action: "approve" | "reject", notes?: string) =>
    request<Verification>("POST", `/admin/verifications/${id}`, { action, notes }),

  reportedUsers: () => request<ReportedUser[]>("GET", "/disputes/admin/reported-users?limit=100"),
  openDisputes: () => request<Dispute[]>("GET", "/disputes/admin?limit=100"),
  setSuspended: (userId: string, suspended: boolean, reason?: string) =>
    request<{ userId: string; suspendedAt: string | null }>(
      "POST",
      `/disputes/admin/users/${userId}/suspension`,
      { suspended, reason }
    ),
  resolveDispute: (id: string, status: "resolved" | "dismissed", resolution?: string) =>
    request<Dispute>("POST", `/disputes/${id}/resolve`, { status, resolution }),

  revenue: () => request<RevenueSummary>("GET", "/admin/revenue"),
  settlements: () => request<DriverSettlement[]>("GET", "/admin/settlements?limit=200"),
  collectCommission: (driverId: string, amount: number, reference?: string) =>
    request<{ collected: number; owed: number }>(
      "POST",
      `/admin/settlements/${driverId}/collect`,
      { amount, reference }
    )
};

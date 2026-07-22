import { Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

export interface City {
  slug: string;
  name: string;
  centerLat: number;
  centerLng: number;
}

export interface Hub {
  id: string;
  city: string;
  label: string;
  lat: number;
  lng: number;
}

export interface PlaceHit {
  label: string;
  lat: number;
  lng: number;
}

// Zero-infra dev fallback so the endpoints still return something without a DB.
const FALLBACK_CITIES: City[] = [
  { slug: "karachi", name: "Karachi", centerLat: 24.8607, centerLng: 67.0011 },
  { slug: "lahore", name: "Lahore", centerLat: 31.5204, centerLng: 74.3587 }
];

const FALLBACK_HUBS: Record<string, Hub[]> = {
  karachi: [
    { id: "k1", city: "karachi", label: "Saddar", lat: 24.86, lng: 67.03 },
    { id: "k2", city: "karachi", label: "Clifton", lat: 24.8138, lng: 67.03 },
    { id: "k3", city: "karachi", label: "DHA Phase 5", lat: 24.79, lng: 67.05 }
  ],
  lahore: [
    { id: "l1", city: "lahore", label: "Gulberg (Liberty Market)", lat: 31.5102, lng: 74.3441 },
    { id: "l2", city: "lahore", label: "DHA Phase 5", lat: 31.4622, lng: 74.4082 }
  ]
};

@Injectable()
export class PlacesRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  async cities(): Promise<City[]> {
    if (!this.pool) return FALLBACK_CITIES;
    const { rows } = await this.pool.query<City>(
      `SELECT slug, name, center_lat AS "centerLat", center_lng AS "centerLng"
         FROM cities ORDER BY sort, name`
    );
    return rows;
  }

  async hubs(city: string): Promise<Hub[]> {
    if (!this.pool) return FALLBACK_HUBS[city] ?? FALLBACK_HUBS.lahore ?? [];
    const { rows } = await this.pool.query<Hub>(
      `SELECT id, city, label, lat, lng FROM hubs WHERE city = $1 ORDER BY sort, label`,
      [city]
    );
    return rows;
  }

  /**
   * Free-text address search via OpenStreetMap Nominatim (no API key). Biased
   * to Pakistan and the given city. Best-effort — returns [] on any failure so
   * the app degrades to the curated hubs instead of erroring.
   */
  async search(q: string, city?: string): Promise<PlaceHit[]> {
    const term = q.trim();
    if (term.length < 3) return [];
    const query = city ? `${term}, ${city}, Pakistan` : `${term}, Pakistan`;
    const url =
      "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&countrycodes=pk&q=" +
      encodeURIComponent(query);
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": "RidesharePK/1.0 (support@rideshare.pk)" },
        signal: AbortSignal.timeout(8000)
      });
      if (!res.ok) return [];
      const data = (await res.json()) as Array<{
        display_name?: string;
        lat?: string;
        lon?: string;
      }>;
      return data
        .filter((d) => d.lat && d.lon)
        .map((d) => ({
          label: shortenLabel(d.display_name ?? ""),
          lat: Number(d.lat),
          lng: Number(d.lon)
        }));
    } catch {
      return [];
    }
  }
}

/** Nominatim display names are long; keep the first few meaningful parts. */
function shortenLabel(displayName: string): string {
  const parts = displayName.split(",").map((p) => p.trim());
  return parts.slice(0, 3).join(", ");
}

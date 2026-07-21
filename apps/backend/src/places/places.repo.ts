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
}

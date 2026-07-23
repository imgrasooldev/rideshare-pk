import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import type { Pool } from "pg";
import { PG_POOL } from "../shared/tokens.js";

export interface SavedRoute {
  id: string;
  label: string | null;
  originLabel: string;
  originLat: number | null;
  originLng: number | null;
  destLabel: string;
  destLat: number | null;
  destLng: number | null;
  createdAt: string;
}

export interface FavouriteDriver {
  driverId: string;
  name: string | null;
  gender: string | null;
  ratingAvg: number | null;
  ratingCount: number | null;
  createdAt: string;
}

export interface NewSavedRoute {
  label?: string;
  originLabel: string;
  originLat?: number;
  originLng?: number;
  destLabel: string;
  destLat?: number;
  destLng?: number;
}

const ROUTE_COLS = `id, label,
  origin_label AS "originLabel", origin_lat AS "originLat", origin_lng AS "originLng",
  dest_label AS "destLabel", dest_lat AS "destLat", dest_lng AS "destLng",
  created_at AS "createdAt"`;

@Injectable()
export class FavouritesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool | null) {}

  // --- Saved routes ---

  async listRoutes(userId: string): Promise<SavedRoute[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query<SavedRoute>(
      `SELECT ${ROUTE_COLS} FROM saved_routes WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [userId]
    );
    return rows;
  }

  async saveRoute(userId: string, r: NewSavedRoute): Promise<SavedRoute> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    const { rows } = await this.pool.query<SavedRoute>(
      `INSERT INTO saved_routes
         (user_id, label, origin_label, origin_lat, origin_lng, dest_label, dest_lat, dest_lng)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING ${ROUTE_COLS}`,
      [
        userId,
        r.label ?? null,
        r.originLabel,
        r.originLat ?? null,
        r.originLng ?? null,
        r.destLabel,
        r.destLat ?? null,
        r.destLng ?? null
      ]
    );
    return rows[0]!;
  }

  async deleteRoute(userId: string, id: string): Promise<{ deleted: boolean }> {
    if (!this.pool) return { deleted: false };
    const { rowCount } = await this.pool.query(
      `DELETE FROM saved_routes WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );
    return { deleted: (rowCount ?? 0) > 0 };
  }

  // --- Favourite drivers ---

  async listFavourites(userId: string): Promise<FavouriteDriver[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query<FavouriteDriver>(
      `SELECT f.driver_id AS "driverId", u.name, u.gender,
              u.rating_avg AS "ratingAvg", u.rating_count AS "ratingCount",
              f.created_at AS "createdAt"
         FROM favourite_drivers f
         JOIN users u ON u.id = f.driver_id
        WHERE f.user_id = $1
        ORDER BY f.created_at DESC`,
      [userId]
    );
    return rows;
  }

  async addFavourite(userId: string, driverId: string): Promise<{ favourited: boolean }> {
    if (!this.pool) throw new BadRequestException("Unavailable");
    if (driverId === userId) throw new BadRequestException("You cannot favourite yourself");
    await this.pool.query(
      `INSERT INTO favourite_drivers (user_id, driver_id) VALUES ($1, $2)
       ON CONFLICT (user_id, driver_id) DO NOTHING`,
      [userId, driverId]
    );
    return { favourited: true };
  }

  async removeFavourite(userId: string, driverId: string): Promise<{ favourited: boolean }> {
    if (!this.pool) return { favourited: false };
    await this.pool.query(
      `DELETE FROM favourite_drivers WHERE user_id = $1 AND driver_id = $2`,
      [userId, driverId]
    );
    return { favourited: false };
  }

  /** Set of the rider's favourite driver ids — used to flag/bias search. */
  async favouriteIds(userId: string): Promise<string[]> {
    if (!this.pool) return [];
    const { rows } = await this.pool.query<{ driverId: string }>(
      `SELECT driver_id AS "driverId" FROM favourite_drivers WHERE user_id = $1`,
      [userId]
    );
    return rows.map((r) => r.driverId);
  }
}

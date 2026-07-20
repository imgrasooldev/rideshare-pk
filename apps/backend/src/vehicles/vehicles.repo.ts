import type { Pool } from "pg";

export interface VehicleRecord {
  id: string;
  ownerId: string;
  make: string;
  model: string;
  plate: string;
  seats: number;
  docUrls: string[];
  verified: boolean;
}

export interface NewVehicle {
  make: string;
  model: string;
  plate: string;
  seats: number;
  docUrls: string[];
}

export interface VehicleRepository {
  create(ownerId: string, v: NewVehicle): Promise<VehicleRecord>;
  listByOwner(ownerId: string): Promise<VehicleRecord[]>;
  findById(id: string): Promise<VehicleRecord | null>;
  setVerified(id: string, verified: boolean): Promise<void>;
}

const COLS = `id, owner_id AS "ownerId", make, model, plate, seats, doc_urls AS "docUrls", verified`;

export class PgVehicleRepository implements VehicleRepository {
  constructor(private readonly pool: Pool) {}

  async create(ownerId: string, v: NewVehicle): Promise<VehicleRecord> {
    const { rows } = await this.pool.query(
      `INSERT INTO vehicles (owner_id, make, model, plate, seats, doc_urls)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING ${COLS}`,
      [ownerId, v.make, v.model, v.plate, v.seats, v.docUrls]
    );
    return rows[0];
  }

  async listByOwner(ownerId: string): Promise<VehicleRecord[]> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM vehicles WHERE owner_id = $1 AND deleted_at IS NULL ORDER BY created_at`,
      [ownerId]
    );
    return rows;
  }

  async findById(id: string): Promise<VehicleRecord | null> {
    const { rows } = await this.pool.query(
      `SELECT ${COLS} FROM vehicles WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return rows[0] ?? null;
  }

  async setVerified(id: string, verified: boolean): Promise<void> {
    await this.pool.query(`UPDATE vehicles SET verified = $2, updated_at = now() WHERE id = $1`, [
      id,
      verified
    ]);
  }
}

export class InMemoryVehicleRepository implements VehicleRepository {
  private readonly items = new Map<string, VehicleRecord>();
  private seq = 0;

  async create(ownerId: string, v: NewVehicle): Promise<VehicleRecord> {
    const rec: VehicleRecord = { id: `veh-${++this.seq}`, ownerId, verified: false, ...v };
    this.items.set(rec.id, rec);
    return rec;
  }

  async listByOwner(ownerId: string): Promise<VehicleRecord[]> {
    return [...this.items.values()].filter((v) => v.ownerId === ownerId);
  }

  async findById(id: string): Promise<VehicleRecord | null> {
    return this.items.get(id) ?? null;
  }

  async setVerified(id: string, verified: boolean): Promise<void> {
    const v = this.items.get(id);
    if (v) v.verified = verified;
  }
}

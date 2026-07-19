// Key-value store abstraction: Redis in real deployments (works across N
// instances), in-memory for local dev and unit tests.
export interface KeyValueStore {
  get(key: string): Promise<string | null>;
  /** Set a value with optional TTL in seconds. */
  set(key: string, value: string, ttlSeconds?: number): Promise<void>;
  /** Atomic increment; TTL is applied only when the counter is created. */
  incr(key: string, ttlSeconds?: number): Promise<number>;
  del(key: string): Promise<void>;
}

interface Entry {
  value: string;
  expiresAt: number | null;
}

export class InMemoryKvStore implements KeyValueStore {
  private readonly data = new Map<string, Entry>();

  private live(key: string): Entry | undefined {
    const e = this.data.get(key);
    if (!e) return undefined;
    if (e.expiresAt !== null && e.expiresAt <= Date.now()) {
      this.data.delete(key);
      return undefined;
    }
    return e;
  }

  async get(key: string): Promise<string | null> {
    return this.live(key)?.value ?? null;
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    this.data.set(key, {
      value,
      expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null
    });
  }

  async incr(key: string, ttlSeconds?: number): Promise<number> {
    const current = this.live(key);
    if (!current) {
      this.data.set(key, {
        value: "1",
        expiresAt: ttlSeconds ? Date.now() + ttlSeconds * 1000 : null
      });
      return 1;
    }
    const next = Number(current.value) + 1;
    current.value = String(next);
    return next;
  }

  async del(key: string): Promise<void> {
    this.data.delete(key);
  }
}

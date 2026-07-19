import Redis from "ioredis";
import type { KeyValueStore } from "./kv.js";

export class RedisKvStore implements KeyValueStore {
  private readonly redis: Redis;

  constructor(url: string) {
    // lazyConnect so booting the app doesn't block on Redis (health stays up;
    // first auth call surfaces the connection error instead).
    this.redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 2 });
  }

  async get(key: string): Promise<string | null> {
    return this.redis.get(key);
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) {
      await this.redis.set(key, value, "EX", ttlSeconds);
    } else {
      await this.redis.set(key, value);
    }
  }

  async incr(key: string, ttlSeconds?: number): Promise<number> {
    const n = await this.redis.incr(key);
    if (n === 1 && ttlSeconds) {
      await this.redis.expire(key, ttlSeconds);
    }
    return n;
  }

  async del(key: string): Promise<void> {
    await this.redis.del(key);
  }

  async close(): Promise<void> {
    this.redis.disconnect();
  }
}

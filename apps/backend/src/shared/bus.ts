import { EventEmitter } from "node:events";
import Redis from "ioredis";

/**
 * Pub/sub backplane (rule 4): live-tracking fan-out must work across N API
 * instances. Redis in real deployments; an in-process emitter for dev/tests.
 */
export interface MessageBus {
  publish(channel: string, message: string): Promise<void>;
  subscribe(channel: string, handler: (message: string) => void): Promise<() => Promise<void>>;
}

export class InMemoryBus implements MessageBus {
  private readonly emitter = new EventEmitter().setMaxListeners(0);

  async publish(channel: string, message: string): Promise<void> {
    this.emitter.emit(channel, message);
  }

  async subscribe(channel: string, handler: (message: string) => void): Promise<() => Promise<void>> {
    this.emitter.on(channel, handler);
    return async () => {
      this.emitter.off(channel, handler);
    };
  }
}

export class RedisBus implements MessageBus {
  // Separate connections: a Redis connection in subscriber mode cannot publish.
  private readonly pub: Redis;
  private readonly sub: Redis;
  private readonly handlers = new Map<string, Set<(message: string) => void>>();

  constructor(url: string) {
    this.pub = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 2 });
    this.sub = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 2 });
    this.sub.on("message", (channel: string, message: string) => {
      for (const handler of this.handlers.get(channel) ?? []) handler(message);
    });
  }

  async publish(channel: string, message: string): Promise<void> {
    await this.pub.publish(channel, message);
  }

  async subscribe(channel: string, handler: (message: string) => void): Promise<() => Promise<void>> {
    let set = this.handlers.get(channel);
    if (!set) {
      set = new Set();
      this.handlers.set(channel, set);
      await this.sub.subscribe(channel);
    }
    set.add(handler);
    return async () => {
      set.delete(handler);
      if (set.size === 0) {
        this.handlers.delete(channel);
        await this.sub.unsubscribe(channel);
      }
    };
  }
}

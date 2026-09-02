import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, RedisClientType } from 'redis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private client: RedisClientType;

  constructor(private readonly config: ConfigService) {
    this.client = createClient({ url: this.config.get('redis.url') });
    this.client.on('error', (err) => console.error('Redis error:', err));
  }

  async onModuleInit() {
    await this.client.connect();
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async setex(key: string, seconds: number, value: string): Promise<void> {
    await this.client.setEx(key, seconds, value);
  }

  async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  // Fixed-window counter for rate limiting. Returns the current count.
  // INCR and EXPIRE run in one Lua script so a counter can never be left
  // without a TTL (which would rate-limit that key forever); the TTL check also
  // re-arms keys that predate this script.
  private static readonly INCR_WINDOW_SCRIPT = `
    local count = redis.call('INCR', KEYS[1])
    if redis.call('TTL', KEYS[1]) < 0 then
      redis.call('EXPIRE', KEYS[1], ARGV[1])
    end
    return count
  `;

  async incrWindow(key: string, windowSeconds: number): Promise<number> {
    const count = await this.client.eval(RedisService.INCR_WINDOW_SCRIPT, {
      keys: [key],
      arguments: [String(windowSeconds)],
    });
    return Number(count);
  }

  async ping(): Promise<boolean> {
    try {
      const res = await this.client.ping();
      return res === 'PONG';
    } catch {
      return false;
    }
  }
}

import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
} from '@nestjs/common';
import { RedisService } from '../cache/redis.service';

const WINDOW_SECONDS = 60;
const MAX_REQUESTS = 100;

// Fixed-window per-IP rate limit for public endpoints.
@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly logger = new Logger(RateLimitGuard.name);

  constructor(private readonly redis: RedisService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    // Correct per-client keying behind a proxy requires TRUST_PROXY_HOPS to be
    // set, which makes Express derive req.ip from X-Forwarded-For (see main.ts).
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';

    let count: number;
    try {
      count = await this.redis.incrWindow(`ratelimit:${ip}`, WINDOW_SECONDS);
    } catch (error) {
      // Fail open: a cache outage must not take down public update checks.
      this.logger.warn(`rate limit check failed, allowing request: ${error}`);
      return true;
    }

    if (count > MAX_REQUESTS) {
      throw new HttpException('Too many requests', HttpStatus.TOO_MANY_REQUESTS);
    }
    return true;
  }
}

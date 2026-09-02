import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

// Guards project creation. There is no per-project key yet at creation time, so
// this uses a single ADMIN_TOKEN env secret. ponytail: single shared admin
// token, upgrade to per-user auth in Phase 5 dashboard.
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const admin = this.config.get<string>('adminToken');
    if (!admin) {
      throw new UnauthorizedException('ADMIN_TOKEN not configured');
    }
    const req = context.switchToHttp().getRequest();
    const header: string = req.headers['authorization'] ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : header;
    if (token !== admin) throw new UnauthorizedException('Invalid admin token');
    return true;
  }
}

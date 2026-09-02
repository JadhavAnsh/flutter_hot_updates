import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../database/prisma.service';

// API key format: hu_{projectId}_{secret}
// projectId locates the row (bcrypt hashes aren't searchable); secret is compared.
@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const header: string = req.headers['authorization'] ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : header;

    const parsed = ApiKeyGuard.parse(token);
    if (!parsed) throw new UnauthorizedException('Invalid API key format');

    const project = await this.prisma.project.findUnique({
      where: { id: parsed.projectId },
    });
    if (!project) throw new UnauthorizedException('Invalid API key');

    const ok = await bcrypt.compare(parsed.secret, project.apiKeyHash);
    if (!ok) throw new UnauthorizedException('Invalid API key');

    // If the route targets a specific project, it must match the key's project.
    if (req.params?.projectId && req.params.projectId !== project.id) {
      throw new UnauthorizedException('API key does not match project');
    }

    req.project = project;
    return true;
  }

  static parse(token: string): { projectId: string; secret: string } | null {
    const m = /^hu_([^_]+)_(.+)$/.exec(token ?? '');
    return m ? { projectId: m[1], secret: m[2] } : null;
  }
}

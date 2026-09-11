import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../database/prisma.service';
import { RedisService } from '../cache/redis.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Liveness/readiness check',
    description: 'Reports DB and Redis connectivity. `status` is `degraded` if either is down.',
  })
  @ApiResponse({
    status: 200,
    description: 'Health snapshot.',
    schema: { example: { status: 'ok', version: '0.3.0', db: true, redis: true } },
  })
  async check() {
    const [db, redis] = await Promise.all([
      this.prisma
        .$queryRaw`SELECT 1`.then(() => true).catch(() => false),
      this.redis.ping(),
    ]);
    const status = db && redis ? 'ok' : 'degraded';
    return { status, version: '0.3.0', db, redis };
  }
}

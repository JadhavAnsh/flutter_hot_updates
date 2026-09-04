import type { AddressInfo } from 'net';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/database/prisma.service';

export interface E2EResponse {
  status: number;
  body: any;
}

export interface E2EApp {
  baseUrl: string;
  prisma: PrismaService;
  close(): Promise<void>;
  req(
    method: string,
    path: string,
    opts?: { token?: string; body?: unknown },
  ): Promise<E2EResponse>;
}

// Boots the full Nest application on an ephemeral port, replicating the request
// pipeline from main.ts (global `v1` prefix + strict ValidationPipe) so e2e
// requests hit the same guards and validation production does. No supertest
// dependency: the app listens on 127.0.0.1 and tests use the native fetch.
export async function bootE2EApp(): Promise<E2EApp> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app: INestApplication = moduleRef.createNestApplication();
  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  await app.listen(0);

  const { port } = app.getHttpServer().address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}/v1`;
  const prisma = app.get(PrismaService);

  return {
    baseUrl,
    prisma,
    close: () => app.close(),
    async req(method, path, opts = {}) {
      const headers: Record<string, string> = {};
      if (opts.body !== undefined) headers['content-type'] = 'application/json';
      if (opts.token) headers['authorization'] = `Bearer ${opts.token}`;
      const res = await fetch(`${baseUrl}${path}`, {
        method,
        headers,
        body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      });
      const text = await res.text();
      return { status: res.status, body: text ? JSON.parse(text) : null };
    },
  };
}

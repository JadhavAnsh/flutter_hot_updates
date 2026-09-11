import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

// Prisma BigInt fields would otherwise throw in JSON.stringify.
(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Without this, req.ip is the proxy's address and the per-IP rate limiter
  // buckets every client together. The value is the number of trusted hops in
  // front of the app, so X-Forwarded-For cannot be spoofed to evade the limit.
  const trustProxyHops = parseInt(process.env.TRUST_PROXY_HOPS, 10) || 0;
  if (trustProxyHops > 0) {
    app.set('trust proxy', trustProxyHops);
  }

  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.enableCors();

  const config = new DocumentBuilder()
    .setTitle('Flutter Hot Updates API')
    .setDescription(
      [
        'Backend API for publishing and serving Flutter hot updates.',
        '',
        '**Auth**',
        '- `admin-token` — the `ADMIN_TOKEN`; guards project create/list/delete.',
        '- `api-key` — a per-project key (`hu_{projectId}_{secret}`) returned once at project creation; guards releases and patches.',
        '- Manifest and telemetry endpoints are public and rate-limited (100 req/min per IP).',
      ].join('\n'),
    )
    .setVersion('0.3.0')
    // Routes are mounted under the global prefix; the spec paths omit it, so
    // declare it as the server base or "Try it out" would hit `/projects`
    // instead of `/v1/projects`.
    .addServer('/v1', 'Global API prefix')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        description: 'Admin token (ADMIN_TOKEN). Guards project create/list/delete.',
      },
      'admin-token',
    )
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        description:
          'Per-project API key (`hu_{projectId}_{secret}`), shown once at project creation. Guards releases and patches.',
      },
      'api-key',
    )
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Server running on http://localhost:${port}`);
}

bootstrap();

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
    .setDescription('Backend API for managing hot updates')
    .setVersion('0.3.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Server running on http://localhost:${port}`);
}

bootstrap();

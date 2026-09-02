import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './config/configuration';
import { DatabaseModule } from './database/database.module';
import { CacheModule } from './cache/cache.module';
import { StorageModule } from './storage/storage.module';
import { ProjectsModule } from './projects/projects.module';
import { ReleasesModule } from './releases/releases.module';
import { PatchesModule } from './patches/patches.module';
import { ManifestsModule } from './manifests/manifests.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    DatabaseModule,
    CacheModule,
    StorageModule,
    ProjectsModule,
    ReleasesModule,
    PatchesModule,
    ManifestsModule,
    HealthModule,
  ],
})
export class AppModule {}

import { Module } from '@nestjs/common';
import { PatchesController } from './patches.controller';
import { PatchesService } from './patches.service';
import { ReleasesModule } from '../releases/releases.module';

@Module({
  imports: [ReleasesModule],
  controllers: [PatchesController],
  providers: [PatchesService],
})
export class PatchesModule {}

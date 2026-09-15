import { Global, Module } from '@nestjs/common';
import { OBJECT_STORAGE } from './storage.interface';
import { S3CompatibleStorageProvider } from './s3-compatible-storage.provider';

@Global()
@Module({
  providers: [
    S3CompatibleStorageProvider,
    { provide: OBJECT_STORAGE, useExisting: S3CompatibleStorageProvider },
  ],
  exports: [OBJECT_STORAGE],
})
export class StorageModule {}

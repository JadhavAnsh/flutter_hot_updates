import { Global, Module } from '@nestjs/common';
import { OBJECT_STORAGE } from './storage.interface';
import { BackblazeB2Provider } from './backblaze-b2.provider';

@Global()
@Module({
  providers: [
    BackblazeB2Provider,
    { provide: OBJECT_STORAGE, useExisting: BackblazeB2Provider },
  ],
  exports: [OBJECT_STORAGE],
})
export class StorageModule {}

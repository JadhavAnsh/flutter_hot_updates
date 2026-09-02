import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {
  ObjectStorageProvider,
  PutObjectInput,
  SignedUploadInput,
} from './storage.interface';

// Backblaze B2 via its S3-compatible API. Same provider for local dev and prod;
// only the bucket/credentials differ per environment.
@Injectable()
export class BackblazeB2Provider implements ObjectStorageProvider {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;

  constructor(private readonly config: ConfigService) {
    const storage = this.config.get('storage');
    // configuration.ts already fails boot on missing S3_* env vars; this keeps
    // the provider from silently building an unusable client if that changes.
    const missing = [
      'endpoint',
      'accessKeyId',
      'secretAccessKey',
      'bucket',
      'publicBaseUrl',
    ].filter((field) => !storage?.[field]);
    if (missing.length > 0) {
      throw new Error(`incomplete storage config: ${missing.join(', ')}`);
    }

    this.bucket = storage.bucket;
    this.publicBaseUrl = storage.publicBaseUrl;
    this.client = new S3Client({
      endpoint: storage.endpoint,
      region: storage.region,
      credentials: {
        accessKeyId: storage.accessKeyId,
        secretAccessKey: storage.secretAccessKey,
      },
      forcePathStyle: true,
    });
  }

  async putObject(input: PutObjectInput): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        Body: input.body,
        ContentType: input.contentType,
      }),
    );
  }

  async getSignedUploadUrl(input: SignedUploadInput): Promise<string> {
    return getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        ContentType: input.contentType ?? 'application/zip',
      }),
      { expiresIn: input.expiresInSeconds ?? 900 },
    );
  }

  getPublicUrl(key: string): string {
    return `${this.publicBaseUrl.replace(/\/$/, '')}/${key}`;
  }

  async deleteObject(key: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
}

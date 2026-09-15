import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  DeleteObjectsCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {
  ObjectStorageProvider,
  PutObjectInput,
  SignedUploadInput,
  SignedDownloadInput,
} from './storage.interface';

/** S3-compatible object storage (MinIO, Backblaze B2, AWS S3, etc.). */
@Injectable()
export class S3CompatibleStorageProvider implements ObjectStorageProvider {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;
  private readonly downloadUrlTtlSeconds: number;

  constructor(private readonly config: ConfigService) {
    const storage = this.config.get('storage');
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
    this.downloadUrlTtlSeconds = storage.downloadUrlTtlSeconds ?? 900;
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

  async getSignedDownloadUrl(input: SignedDownloadInput): Promise<string> {
    return getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: input.key }),
      { expiresIn: input.expiresInSeconds ?? this.downloadUrlTtlSeconds },
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

  async deletePrefix(prefix: string): Promise<void> {
    let continuationToken: string | undefined;
    do {
      const listed = await this.client.send(
        new ListObjectsV2Command({
          Bucket: this.bucket,
          Prefix: prefix,
          ContinuationToken: continuationToken,
        }),
      );

      const keys = (listed.Contents ?? [])
        .map((object) => object.Key)
        .filter((key): key is string => Boolean(key));

      if (keys.length > 0) {
        await this.client.send(
          new DeleteObjectsCommand({
            Bucket: this.bucket,
            Delete: { Objects: keys.map((Key) => ({ Key })) },
          }),
        );
      }

      continuationToken = listed.IsTruncated
        ? listed.NextContinuationToken
        : undefined;
    } while (continuationToken);
  }
}

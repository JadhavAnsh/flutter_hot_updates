export interface PutObjectInput {
  key: string;
  body: Buffer | Uint8Array;
  contentType?: string;
}

export interface SignedUploadInput {
  key: string;
  contentType?: string;
  expiresInSeconds?: number;
}

export interface SignedDownloadInput {
  key: string;
  expiresInSeconds?: number;
}

export interface ObjectStorageProvider {
  putObject(input: PutObjectInput): Promise<void>;
  getSignedUploadUrl(input: SignedUploadInput): Promise<string>;
  getSignedDownloadUrl(input: SignedDownloadInput): Promise<string>;
  getPublicUrl(key: string): string;
  deleteObject(key: string): Promise<void>;
  // Bulk delete every object under a key prefix (cascade + orphan cleanup).
  deletePrefix(prefix: string): Promise<void>;
}

export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

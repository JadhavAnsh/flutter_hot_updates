import {
  GetObjectCommand,
  ListObjectsV2Command,
  DeleteObjectsCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { S3CompatibleStorageProvider } from './s3-compatible-storage.provider';

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(),
}));

const storageConfig = {
  endpoint: 'http://minio:9000',
  region: 'us-east-1',
  accessKeyId: 'minioadmin',
  secretAccessKey: 'minioadmin',
  bucket: 'hot-updates-dev',
  publicBaseUrl: 'http://minio:9000/hot-updates-dev',
  downloadUrlTtlSeconds: 900,
};

const buildProvider = () =>
  new S3CompatibleStorageProvider({ get: () => storageConfig } as any);

describe('S3CompatibleStorageProvider', () => {
  beforeEach(() => jest.clearAllMocks());

  it('getSignedDownloadUrl presigns a GetObjectCommand with the configured TTL', async () => {
    (getSignedUrl as jest.Mock).mockResolvedValue('http://signed/download');
    const provider = buildProvider();

    const url = await provider.getSignedDownloadUrl({ key: 'a/b.zip' });

    expect(url).toBe('http://signed/download');
    const [, command, opts] = (getSignedUrl as jest.Mock).mock.calls[0];
    expect(command).toBeInstanceOf(GetObjectCommand);
    expect(command.input).toEqual({ Bucket: 'hot-updates-dev', Key: 'a/b.zip' });
    expect(opts).toEqual({ expiresIn: 900 });
  });

  it('deletePrefix paginates the listing and batch-deletes until exhausted', async () => {
    const provider = buildProvider();
    const send = jest
      .spyOn(S3Client.prototype, 'send')
      .mockImplementationOnce((async () => ({
        Contents: [{ Key: 'p/1.zip' }, { Key: 'p/2.zip' }],
        IsTruncated: true,
        NextContinuationToken: 'tok',
      })) as any)
      .mockImplementationOnce((async () => ({})) as any)
      .mockImplementationOnce((async () => ({
        Contents: [{ Key: 'p/3.zip' }],
        IsTruncated: false,
      })) as any)
      .mockImplementationOnce((async () => ({})) as any);

    await provider.deletePrefix('p/');

    const commands = send.mock.calls.map((c) => c[0]);
    expect(commands[0]).toBeInstanceOf(ListObjectsV2Command);
    expect((commands[0] as any).input).toMatchObject({
      Bucket: 'hot-updates-dev',
      Prefix: 'p/',
      ContinuationToken: undefined,
    });
    expect(commands[1]).toBeInstanceOf(DeleteObjectsCommand);
    expect((commands[1] as any).input.Delete.Objects).toEqual([
      { Key: 'p/1.zip' },
      { Key: 'p/2.zip' },
    ]);
    expect((commands[2] as any).input.ContinuationToken).toBe('tok');
    expect(commands[3]).toBeInstanceOf(DeleteObjectsCommand);
    expect(send).toHaveBeenCalledTimes(4);

    send.mockRestore();
  });

  it('deletePrefix issues no delete when the prefix is empty', async () => {
    const provider = buildProvider();
    const send = jest
      .spyOn(S3Client.prototype, 'send')
      .mockImplementation((async () => ({ Contents: [], IsTruncated: false })) as any);

    await provider.deletePrefix('empty/');

    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0]).toBeInstanceOf(ListObjectsV2Command);
    send.mockRestore();
  });
});

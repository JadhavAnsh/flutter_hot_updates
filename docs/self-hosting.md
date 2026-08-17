# Self-Hosting

The planned self-hosted stack is:

- NestJS API
- PostgreSQL database
- S3-compatible object storage
- Backblaze B2 for production storage
- Cloudflare CDN in front of public update assets
- Next.js dashboard

Local development should support MinIO so contributors can run the storage layer without a paid cloud account.

Planned storage environment variables:

```text
S3_ENDPOINT=
S3_REGION=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_BUCKET=
S3_PUBLIC_BASE_URL=
```

The client package should also support static manifest hosting so developers can try the MVP without running the full backend.

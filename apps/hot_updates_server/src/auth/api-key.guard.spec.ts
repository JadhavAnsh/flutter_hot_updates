import { ApiKeyGuard } from './api-key.guard';

describe('ApiKeyGuard.parse', () => {
  it('parses a valid hu_ key', () => {
    const r = ApiKeyGuard.parse('hu_abc-123_deadbeefsecret');
    expect(r).toEqual({ projectId: 'abc-123', secret: 'deadbeefsecret' });
  });

  it('keeps underscores in the secret portion', () => {
    const r = ApiKeyGuard.parse('hu_pid_sec_with_underscores');
    expect(r).toEqual({ projectId: 'pid', secret: 'sec_with_underscores' });
  });

  it('rejects malformed keys', () => {
    expect(ApiKeyGuard.parse('')).toBeNull();
    expect(ApiKeyGuard.parse('nope')).toBeNull();
    expect(ApiKeyGuard.parse('hu_onlyid')).toBeNull();
  });
});

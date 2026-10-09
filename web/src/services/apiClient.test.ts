import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  acceptSessionTokens,
  apiRequest,
  clearSessionTokens,
  getRefreshToken,
  refreshSession,
} from './apiClient';

const oldTokens = {
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresAt: '2026-10-09T20:00:00Z',
};
const newTokens = { ...oldTokens, accessToken: 'new-access', refreshToken: 'new-refresh' };
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const fetchMock = vi.fn<typeof fetch>();

beforeEach(() => {
  clearSessionTokens();
  fetchMock.mockReset();
  vi.stubGlobal('fetch', fetchMock);
});
afterEach(() => vi.unstubAllGlobals());

describe('API oturum akışı', () => {
  it('bearer token gönderir, 401 sonrası tokenı yeniler ve isteği tekrarlar', async () => {
    acceptSessionTokens(oldTokens);
    fetchMock
      .mockResolvedValueOnce(response({ title: 'Unauthorized' }, 401))
      .mockResolvedValueOnce(response(newTokens))
      .mockResolvedValueOnce(response({ ok: true }));
    await expect(apiRequest('/api/trainers/me/clients')).resolves.toEqual({ ok: true });
    expect(new Headers(fetchMock.mock.calls[0][1]?.headers).get('Authorization')).toBe(
      'Bearer old-access',
    );
    expect(fetchMock.mock.calls[1][0]).toBe('/api/auth/refresh');
    expect(JSON.parse(String(fetchMock.mock.calls[1][1]?.body))).toEqual({
      refreshToken: 'old-refresh',
    });
    expect(new Headers(fetchMock.mock.calls[2][1]?.headers).get('Authorization')).toBe(
      'Bearer new-access',
    );
    expect(getRefreshToken()).toBe('new-refresh');
  });

  it('eşzamanlı 401 yanıtları için yalnızca bir refresh gönderir', async () => {
    acceptSessionTokens(oldTokens);
    fetchMock.mockImplementation(async (url, options) => {
      if (url === '/api/auth/refresh') return response(newTokens);
      return new Headers(options?.headers).get('Authorization') === 'Bearer new-access'
        ? response({ ok: true })
        : response({ title: 'Unauthorized' }, 401);
    });
    await Promise.all([apiRequest('/api/first'), apiRequest('/api/second')]);
    expect(fetchMock.mock.calls.filter(([url]) => url === '/api/auth/refresh')).toHaveLength(1);
  });

  it('başarısız refresh oturumu siler ve kullanıcıyı haberdar eder', async () => {
    acceptSessionTokens(oldTokens);
    const expired = vi.fn();
    window.addEventListener('session-expired', expired);
    fetchMock
      .mockResolvedValueOnce(response({}, 401))
      .mockResolvedValueOnce(response({ detail: 'Refresh expired' }, 401));
    await expect(apiRequest('/api/clients')).rejects.toMatchObject({ status: 401 });
    expect(getRefreshToken()).toBeNull();
    expect(expired).toHaveBeenCalledOnce();
    window.removeEventListener('session-expired', expired);
  });

  it('yenilenen token da 401 alırsa sonsuz tekrar yapmaz', async () => {
    acceptSessionTokens(oldTokens);
    fetchMock
      .mockResolvedValueOnce(response({}, 401))
      .mockResolvedValueOnce(response(newTokens))
      .mockResolvedValueOnce(response({}, 401));
    await expect(apiRequest('/api/clients')).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(getRefreshToken()).toBeNull();
  });

  it('403 ve doğrulama hatasında refresh yapmaz; ProblemDetails alanlarını korur', async () => {
    acceptSessionTokens(oldTokens);
    const problem = {
      detail: 'Bu danışana erişiminiz yok.',
      errors: { userId: ['Yetkisiz ilişki'] },
    };
    fetchMock.mockResolvedValueOnce(response(problem, 403));
    await expect(apiRequest('/api/clients')).rejects.toMatchObject({
      status: 403,
      message: problem.detail,
      problem: { errors: problem.errors },
    });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('public login 401 alırsa refresh denemez', async () => {
    fetchMock.mockResolvedValueOnce(response({ detail: 'E-posta veya şifre hatalı.' }, 401));
    await expect(apiRequest('/api/auth/login', { method: 'POST' }, false)).rejects.toMatchObject({
      status: 401,
    });
    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('ağ hatasını anlaşılır bir hata olarak sunar', async () => {
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));
    await expect(apiRequest('/api/clients')).rejects.toMatchObject({
      status: 0,
      message: expect.stringContaining('Sunucuya ulaşılamıyor'),
    });
  });

  it('çıkış sırasında devam eden refresh oturumu geri açamaz', async () => {
    acceptSessionTokens(oldTokens);
    let resolveRefresh!: (value: Response) => void;
    fetchMock.mockReturnValueOnce(
      new Promise<Response>((resolve) => {
        resolveRefresh = resolve;
      }),
    );
    const pending = refreshSession();
    clearSessionTokens();
    resolveRefresh(response(newTokens));
    await expect(pending).rejects.toMatchObject({ status: 401 });
    expect(getRefreshToken()).toBeNull();
  });
});

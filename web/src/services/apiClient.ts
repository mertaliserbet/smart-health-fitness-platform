import type { ProblemDetails, TokenResponse } from '../types/api';

const baseUrl = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '');
const refreshKey = 'smart-health-fitness.refresh-token';
let tokens: TokenResponse | null = null;
let sessionVersion = 0;
let refreshPromise: Promise<void> | null = null;

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly problem: ProblemDetails,
  ) {
    super(problem.detail || problem.title || 'İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    this.name = 'ApiError';
  }
}

export function readRefreshToken(): string | null {
  try {
    return sessionStorage.getItem(refreshKey);
  } catch {
    return null;
  }
}

export function setSessionTokens(value: TokenResponse) {
  tokens = value;
  try {
    sessionStorage.setItem(refreshKey, value.refreshToken);
  } catch {
    /* Oturum bellekte sürer. */
  }
}

export function clearSessionTokens() {
  sessionVersion += 1;
  tokens = null;
  refreshPromise = null;
  try {
    sessionStorage.removeItem(refreshKey);
  } catch {
    /* Depolama kapalı olabilir. */
  }
}

export function getRefreshToken(): string | null {
  return tokens?.refreshToken ?? readRefreshToken();
}

function validTokens(value: unknown): value is TokenResponse {
  if (!value || typeof value !== 'object') return false;
  const candidate = value as Partial<TokenResponse>;
  return (
    typeof candidate.accessToken === 'string' &&
    !!candidate.accessToken &&
    typeof candidate.refreshToken === 'string' &&
    !!candidate.refreshToken &&
    typeof candidate.expiresAt === 'string' &&
    Number.isFinite(Date.parse(candidate.expiresAt))
  );
}

export function acceptSessionTokens(value: unknown) {
  if (!validTokens(value))
    throw new ApiError(502, { detail: 'Sunucudan geçerli bir oturum yanıtı alınamadı.' });
  sessionVersion += 1;
  setSessionTokens(value);
}

async function send<T>(path: string, options: RequestInit, allowEmptyResponse = false): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${baseUrl}${path}`, options);
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') throw error;
    throw new ApiError(0, {
      detail: 'Sunucuya ulaşılamıyor. Bağlantınızı kontrol edip tekrar deneyin.',
    });
  }
  if (response.status === 204) return undefined as T;
  const rawBody = await response.text();
  let body: unknown = null;
  try {
    body = JSON.parse(rawBody);
  } catch {
    /* Hatalı veya boş yanıt aşağıda değerlendirilir. */
  }
  if (!response.ok) {
    const problem = body && typeof body === 'object' ? (body as ProblemDetails) : {};
    throw new ApiError(response.status, { ...problem, status: response.status });
  }
  if (allowEmptyResponse && !rawBody.trim()) return undefined as T;
  if (body === null) throw new ApiError(502, { detail: 'Sunucunun yanıtı okunamadı.' });
  return body as T;
}

export async function refreshSession(): Promise<void> {
  if (refreshPromise) return refreshPromise;
  const refreshToken = getRefreshToken();
  if (!refreshToken)
    throw new ApiError(401, { detail: 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.' });
  const version = sessionVersion;
  const currentRefresh = (async () => {
    const result = await send<TokenResponse>('/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (version !== sessionVersion)
      throw new ApiError(401, { detail: 'Oturumunuz değişti. Lütfen tekrar giriş yapın.' });
    if (!validTokens(result))
      throw new ApiError(502, { detail: 'Oturum yenileme yanıtı geçersiz.' });
    setSessionTokens(result);
  })();
  refreshPromise = currentRefresh;
  try {
    await currentRefresh;
  } catch (error) {
    if (version === sessionVersion) {
      clearSessionTokens();
      window.dispatchEvent(new Event('session-expired'));
    }
    throw error;
  } finally {
    if (refreshPromise === currentRefresh) refreshPromise = null;
  }
}

export async function apiRequest<T>(
  path: string,
  options: RequestInit & { allowEmptyResponse?: boolean } = {},
  authenticated = true,
): Promise<T> {
  const version = sessionVersion;
  const accessToken = tokens?.accessToken;
  const { allowEmptyResponse = false, ...requestOptions } = options;
  const buildOptions = (): RequestInit => {
    const headers = new Headers(requestOptions.headers);
    if (requestOptions.body) headers.set('Content-Type', 'application/json');
    if (authenticated && tokens) headers.set('Authorization', `Bearer ${tokens.accessToken}`);
    return { ...requestOptions, headers };
  };
  try {
    return await send<T>(path, buildOptions(), allowEmptyResponse);
  } catch (error) {
    if (
      !authenticated ||
      !(error instanceof ApiError) ||
      error.status !== 401 ||
      !getRefreshToken()
    )
      throw error;
    if (version !== sessionVersion) throw error;
    if (tokens?.accessToken === accessToken) await refreshSession();
    try {
      return await send<T>(path, buildOptions(), allowEmptyResponse);
    } catch (retryError) {
      if (
        retryError instanceof ApiError &&
        retryError.status === 401 &&
        version === sessionVersion
      ) {
        clearSessionTokens();
        window.dispatchEvent(new Event('session-expired'));
      }
      throw retryError;
    }
  }
}

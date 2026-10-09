import type { LoginRequest, LoginResponse, UserProfile } from '../types/api';
import {
  acceptSessionTokens,
  apiRequest,
  ApiError,
  clearSessionTokens,
  getRefreshToken,
  refreshSession,
} from './apiClient';

export async function login(request: LoginRequest) {
  clearSessionTokens();
  const result = await apiRequest<LoginResponse>(
    '/api/auth/login',
    {
      method: 'POST',
      body: JSON.stringify(request),
    },
    false,
  );
  const user = result.user;
  if (
    !user ||
    !Array.isArray(user.roles) ||
    typeof user.id !== 'string' ||
    typeof user.firstName !== 'string' ||
    typeof user.lastName !== 'string' ||
    typeof user.email !== 'string'
  ) {
    throw new ApiError(502, { detail: 'Sunucudan geçerli bir hesap yanıtı alınamadı.' });
  }
  acceptSessionTokens(result);
  return user;
}

export async function restoreSession(): Promise<UserProfile> {
  await refreshSession();
  return apiRequest<UserProfile>('/api/users/me');
}

export async function logout() {
  const refreshToken = getRefreshToken();
  try {
    if (refreshToken)
      await apiRequest<void>('/api/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refreshToken }),
      });
  } finally {
    clearSessionTokens();
  }
}

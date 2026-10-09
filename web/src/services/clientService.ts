import type { ClientSummary, PagedResponse, UserProfile, UserSummary, WebRole } from '../types/api';
import { apiRequest } from './apiClient';

export async function getClients(
  role: Exclude<WebRole, 'Admin'>,
  demo: boolean,
  signal?: AbortSignal,
) {
  if (demo && import.meta.env.DEV) {
    const { demoClients } = await import('../demo/demoData');
    return demoClients[role];
  }
  const path = role === 'Trainer' ? '/api/trainers/me/clients' : '/api/dietitians/me/clients';
  return apiRequest<ClientSummary[]>(path, { signal });
}

export async function getUsers(
  demo: boolean,
  page = 1,
  signal?: AbortSignal,
): Promise<PagedResponse<UserSummary>> {
  if (demo && import.meta.env.DEV) {
    const { demoUsers } = await import('../demo/demoData');
    return {
      items: demoUsers.slice((page - 1) * 20, page * 20),
      page,
      pageSize: 20,
      totalCount: demoUsers.length,
      totalPages: Math.ceil(demoUsers.length / 20),
    };
  }
  return apiRequest<PagedResponse<UserSummary>>(`/api/users?page=${page}&pageSize=20`, { signal });
}

export async function requireClient(
  userId: string,
  role: Exclude<WebRole, 'Admin'>,
  demo: boolean,
  signal?: AbortSignal,
) {
  const clients = await getClients(role, demo, signal);
  const client = clients.find(
    (value) => value.id === userId && value.relationshipStatus === 'Active',
  );
  if (!client) throw new Error('Bu danışana erişiminiz bulunmuyor.');
  return client;
}

export async function getUserProfile(id: string | undefined, demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV) {
    const { demoProfiles } = await import('../demo/demoData');
    const profile = demoProfiles.find((user) => user.id === id);
    if (!profile) throw new Error('Kullanıcı bulunamadı.');
    return profile;
  }
  return apiRequest<UserProfile>(id ? `/api/users/${encodeURIComponent(id)}` : '/api/users/me', {
    signal,
  });
}

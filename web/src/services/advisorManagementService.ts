import type { AdvisorType, UserAdvisorManagementResponse } from '../types/api';
import { apiRequest } from './apiClient';

export const getUserAdvisors = (userId: string, signal?: AbortSignal) =>
  apiRequest<UserAdvisorManagementResponse[]>(
    `/api/user-advisors?${new URLSearchParams({ userId })}`,
    { signal },
  );

export const createUserAdvisor = (
  request: { userId: string; advisorId: string; advisorType: AdvisorType; startDate: string },
  signal?: AbortSignal,
) =>
  apiRequest<UserAdvisorManagementResponse>('/api/user-advisors', {
    method: 'POST',
    body: JSON.stringify(request),
    signal,
  });

export const endUserAdvisor = (
  userAdvisorId: string,
  request: { status: 'Ended' | 'Cancelled'; endDate: string },
  signal?: AbortSignal,
) =>
  apiRequest<UserAdvisorManagementResponse>(
    `/api/user-advisors/${encodeURIComponent(userAdvisorId)}`,
    {
      method: 'PATCH',
      body: JSON.stringify(request),
      signal,
    },
  );

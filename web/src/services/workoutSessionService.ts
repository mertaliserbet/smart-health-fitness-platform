import type {
  PagedWorkoutSessionsResponse,
  WorkoutSessionResponse,
  WorkoutSessionStatus,
} from '../types/workoutSession';
import { apiRequest, ApiError } from './apiClient';

export async function getWorkoutSessions(
  userId: string,
  page: number,
  status: WorkoutSessionStatus | '',
  signal?: AbortSignal,
) {
  const query = new URLSearchParams({ page: String(page), pageSize: '20' });
  if (status) query.set('status', status);
  const result = await apiRequest<PagedWorkoutSessionsResponse>(
    `/api/users/${encodeURIComponent(userId)}/workout-sessions?${query}`,
    { signal },
  );
  if (
    !result ||
    !Array.isArray(result.items) ||
    result.items.some((item) => item.userId !== userId)
  )
    throw new ApiError(502, { detail: 'Antrenman geçmişi yanıtı doğrulanamadı.' });
  return result;
}

export async function getWorkoutSession(sessionId: string, userId: string, signal?: AbortSignal) {
  const result = await apiRequest<WorkoutSessionResponse>(
    `/api/workout-sessions/${encodeURIComponent(sessionId)}`,
    { signal },
  );
  if (
    !result ||
    result.id !== sessionId ||
    result.userId !== userId ||
    !Array.isArray(result.day?.exercises) ||
    !Array.isArray(result.logs)
  )
    throw new ApiError(502, { detail: 'Bu antrenman seçili danışana ait değil veya yanıt eksik.' });
  return result;
}

import type { CreateExerciseRequest, ExerciseDetailResponse } from '../types/exercise';
import { ApiError, apiRequest } from './apiClient';
import { getExercises } from './workoutService';

function validExercise(value: unknown): value is ExerciseDetailResponse {
  if (!value || typeof value !== 'object') return false;
  const exercise = value as Partial<ExerciseDetailResponse>;
  return (
    typeof exercise.id === 'string' &&
    !!exercise.id &&
    typeof exercise.name === 'string' &&
    !!exercise.name.trim() &&
    typeof exercise.isActive === 'boolean' &&
    (['description', 'instructions', 'videoUrl', 'imageUrl'] as const).every(
      (key) => exercise[key] === null || typeof exercise[key] === 'string',
    )
  );
}

function invalidResponse() {
  return new ApiError(502, { detail: 'Sunucudan geçerli bir egzersiz yanıtı alınamadı.' });
}

export async function getManagedExercises(demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV)
    return (await getExercises(true, signal)).map((exercise) => ({
      ...exercise,
      instructions: null,
      isActive: true,
    }));
  const result = await apiRequest<unknown>('/api/exercises?includeInactive=true', { signal });
  if (!Array.isArray(result) || !result.every(validExercise)) throw invalidResponse();
  return result as ExerciseDetailResponse[];
}

export async function getExercise(id: string, signal?: AbortSignal) {
  const result = await apiRequest<unknown>(`/api/exercises/${encodeURIComponent(id)}`, { signal });
  if (!validExercise(result) || result.id !== id) throw invalidResponse();
  return result;
}

export async function saveExercise(
  id: string | undefined,
  request: CreateExerciseRequest,
  signal?: AbortSignal,
) {
  const result = await apiRequest<unknown>(
    id ? `/api/exercises/${encodeURIComponent(id)}` : '/api/exercises',
    { method: id ? 'PUT' : 'POST', body: JSON.stringify(request), signal },
  );
  if (!validExercise(result) || (id && result.id !== id)) throw invalidResponse();
  return result;
}

import type {
  CreateWorkoutPlanRequest,
  ExerciseResponse,
  WorkoutPlanResponse,
  WorkoutPlanSummaryResponse,
} from '../types/workout';
import { apiRequest } from './apiClient';

export async function getExercises(demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV) {
    const { demoExercises } = await import('../demo/demoWorkoutData');
    return demoExercises;
  }
  return apiRequest<ExerciseResponse[]>('/api/exercises', { signal });
}

export async function getWorkoutPlans(userId: string, demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV) {
    const { getDemoWorkoutPlans } = await import('../demo/demoWorkoutData');
    return getDemoWorkoutPlans(userId);
  }
  return apiRequest<WorkoutPlanSummaryResponse[]>(
    `/api/users/${encodeURIComponent(userId)}/workout-plans`,
    { signal },
  );
}

export async function getWorkoutPlan(id: string, demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV) {
    const { getDemoWorkoutPlan } = await import('../demo/demoWorkoutData');
    return getDemoWorkoutPlan(id);
  }
  return apiRequest<WorkoutPlanResponse>(`/api/workout-plans/${encodeURIComponent(id)}`, {
    signal,
  });
}

export async function createWorkoutPlan(
  userId: string,
  request: CreateWorkoutPlanRequest,
  demo: boolean,
  signal?: AbortSignal,
) {
  if (demo && import.meta.env.DEV) {
    const { createDemoWorkoutPlan } = await import('../demo/demoWorkoutData');
    if (signal?.aborted) throw new DOMException('İşlem iptal edildi.', 'AbortError');
    createDemoWorkoutPlan(userId, request);
    return;
  }
  await apiRequest<void>(`/api/users/${encodeURIComponent(userId)}/workout-plans`, {
    method: 'POST',
    body: JSON.stringify(request),
    signal,
    allowEmptyResponse: true,
  });
}

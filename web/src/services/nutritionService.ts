import type { CreateNutritionGoalRequest, NutritionGoalResponse } from '../types/nutrition';
import { isValidDate } from '../utils/date';
import { nutritionFields } from '../utils/nutritionGoal';
import { ApiError, apiRequest } from './apiClient';

function isNutritionGoal(value: unknown): value is NutritionGoalResponse {
  if (!value || typeof value !== 'object') return false;
  const goal = value as Partial<NutritionGoalResponse>;
  return (
    typeof goal.id === 'string' &&
    !!goal.id &&
    typeof goal.isActive === 'boolean' &&
    nutritionFields.every(
      ({ key }) => typeof goal[key] === 'number' && Number.isFinite(goal[key]) && goal[key]! >= 0,
    ) &&
    typeof goal.startDate === 'string' &&
    isValidDate(goal.startDate) &&
    (goal.endDate === null ||
      (typeof goal.endDate === 'string' &&
        isValidDate(goal.endDate) &&
        goal.endDate >= goal.startDate))
  );
}

export async function getNutritionGoals(userId: string, demo: boolean, signal?: AbortSignal) {
  if (demo && import.meta.env.DEV) {
    const { getDemoNutritionGoals } = await import('../demo/demoNutritionData');
    return getDemoNutritionGoals(userId);
  }
  const goals = await apiRequest<unknown>(
    `/api/users/${encodeURIComponent(userId)}/nutrition-goals`,
    { signal },
  );
  if (!Array.isArray(goals) || !goals.every(isNutritionGoal))
    throw new ApiError(502, { detail: 'Sunucudan geçerli bir beslenme hedefi listesi alınamadı.' });
  return goals as NutritionGoalResponse[];
}

export async function createNutritionGoal(
  userId: string,
  request: CreateNutritionGoalRequest,
  demo: boolean,
  signal?: AbortSignal,
) {
  if (demo && import.meta.env.DEV) {
    const { createDemoNutritionGoal } = await import('../demo/demoNutritionData');
    if (signal?.aborted) throw new DOMException('İşlem iptal edildi.', 'AbortError');
    return createDemoNutritionGoal(userId, request);
  }
  const goal = await apiRequest<unknown>(
    `/api/users/${encodeURIComponent(userId)}/nutrition-goals`,
    { method: 'POST', body: JSON.stringify(request), signal },
  );
  if (!isNutritionGoal(goal) || !goal.isActive)
    throw new ApiError(502, {
      detail: 'Sunucudan oluşturulan beslenme hedefinin yanıtı alınamadı.',
    });
  return goal;
}

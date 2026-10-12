import type { NutritionRecordResponse } from '../types/nutritionProgress';
import { nutritionMetrics, mealLabels } from '../utils/nutritionProgress';
import { ApiError, apiRequest } from './apiClient';

export async function getClientNutritionRecords(userId: string, signal?: AbortSignal) {
  const result = await apiRequest<unknown>(
    `/api/users/${encodeURIComponent(userId)}/nutrition-records`,
    { signal },
  );
  const text = (value: unknown): value is string => typeof value === 'string' && value.length > 0;
  const nullableText = (value: unknown) => value === null || typeof value === 'string';
  const timestamp = (value: unknown) => text(value) && Number.isFinite(Date.parse(value));
  if (
    !Array.isArray(result) ||
    result.some((value: unknown) => {
      if (!value || typeof value !== 'object') return true;
      const item = value as Record<string, unknown>;
      return (
        !text(item.id) ||
        item.userId !== userId ||
        !text(item.name) ||
        typeof item.mealType !== 'string' ||
        !Object.hasOwn(mealLabels, item.mealType) ||
        !nutritionMetrics.every(
          ({ key }) =>
            typeof item[key] === 'number' &&
            Number.isFinite(item[key]) &&
            item[key] >= 0 &&
            item[key] <= 9999999999.99,
        ) ||
        !nullableText(item.portionDescription) ||
        !nullableText(item.foodRecognitionLogId) ||
        (item.sourceType !== 'Manual' && item.sourceType !== 'AI') ||
        !timestamp(item.consumedAt) ||
        !timestamp(item.createdAt)
      );
    })
  )
    throw new ApiError(502, { detail: 'Beslenme kayıtları yanıtı doğrulanamadı. Tekrar deneyin.' });
  return result as NutritionRecordResponse[];
}

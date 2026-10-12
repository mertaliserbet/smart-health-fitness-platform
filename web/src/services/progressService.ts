import type { BodyMeasurementResponse, WeightRecordResponse } from '../types/progress';
import { apiRequest, ApiError } from './apiClient';

function record(value: unknown): value is Record<string, unknown> {
  if (!value || typeof value !== 'object') return false;
  const item = value as Record<string, unknown>;
  return (
    typeof item.id === 'string' &&
    item.id.length > 0 &&
    typeof item.recordedAt === 'string' &&
    Number.isFinite(Date.parse(item.recordedAt))
  );
}
function number(value: unknown, min: number, max: number) {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}

export async function getClientWeightRecords(userId: string, signal?: AbortSignal) {
  const result = await apiRequest<unknown>(
    `/api/users/${encodeURIComponent(userId)}/weight-records`,
    { signal },
  );
  if (
    !Array.isArray(result) ||
    result.some((item) => !record(item) || !number(item.weightKg, 0.01, 1000))
  )
    throw new ApiError(502, { detail: 'Kilo kayıtları yanıtı doğrulanamadı. Tekrar deneyin.' });
  return result as WeightRecordResponse[];
}

export async function getClientBodyMeasurements(userId: string, signal?: AbortSignal) {
  const result = await apiRequest<unknown>(
    `/api/users/${encodeURIComponent(userId)}/body-measurements`,
    { signal },
  );
  if (
    !Array.isArray(result) ||
    result.some(
      (item) =>
        !record(item) ||
        ['chestCm', 'waistCm', 'hipCm', 'armCm', 'thighCm'].some(
          (field) => item[field] !== null && !number(item[field], 0.01, 1000),
        ) ||
        (item.bodyFatPercentage !== null && !number(item.bodyFatPercentage, 0, 100)),
    )
  )
    throw new ApiError(502, { detail: 'Vücut ölçümleri yanıtı doğrulanamadı. Tekrar deneyin.' });
  return result as BodyMeasurementResponse[];
}

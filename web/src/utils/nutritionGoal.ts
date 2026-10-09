import type { CreateNutritionGoalRequest, NutritionGoalResponse } from '../types/nutrition';
import { isValidDate, localDate } from './date';

export const nutritionFields = [
  { key: 'dailyCalories', label: 'Günlük kalori', unit: 'kcal' },
  { key: 'proteinGrams', label: 'Protein', unit: 'g' },
  { key: 'carbohydrateGrams', label: 'Karbonhidrat', unit: 'g' },
  { key: 'fatGrams', label: 'Yağ', unit: 'g' },
  { key: 'waterMl', label: 'Su hedefi', unit: 'ml' },
] as const;

export type NutritionGoalDraft = Record<keyof CreateNutritionGoalRequest, string>;

export function prepareNutritionGoal(draft: NutritionGoalDraft) {
  const errors: Record<string, string> = {};
  const request: CreateNutritionGoalRequest = {
    dailyCalories: Number(draft.dailyCalories),
    proteinGrams: Number(draft.proteinGrams),
    carbohydrateGrams: Number(draft.carbohydrateGrams),
    fatGrams: Number(draft.fatGrams),
    waterMl: Number(draft.waterMl),
    startDate: draft.startDate,
    endDate: draft.endDate || null,
  };
  for (const { key } of nutritionFields) {
    if (!draft[key].trim()) errors[key.toLowerCase()] = 'Bu alan gerekli.';
    else if (!Number.isFinite(request[key]) || request[key] < 0)
      errors[key.toLowerCase()] = 'Sıfır veya daha büyük bir sayı gir.';
  }
  if (!isValidDate(draft.startDate)) errors.startdate = 'Geçerli bir başlangıç tarihi seç.';
  if (draft.endDate && !isValidDate(draft.endDate))
    errors.enddate = 'Geçerli bir bitiş tarihi seç.';
  else if (draft.endDate && draft.endDate < draft.startDate)
    errors.enddate = 'Bitiş tarihi başlangıçtan önce olamaz.';
  return { errors, request };
}

export function nutritionGoalStatus(goal: NutritionGoalResponse, today = localDate()) {
  if (!goal.isActive) return { label: 'Geçmiş hedef', kind: 'past' };
  if (today < goal.startDate) return { label: 'Aktif · henüz başlamadı', kind: 'scheduled' };
  if (goal.endDate && today > goal.endDate)
    return { label: 'Aktif · süresi doldu', kind: 'expired' };
  return { label: 'Aktif · bugün geçerli', kind: 'current' };
}

export const formatNutritionValue = (value: number) =>
  new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 2 }).format(value);

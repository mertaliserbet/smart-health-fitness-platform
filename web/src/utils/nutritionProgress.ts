import type { NutritionGoalResponse } from '../types/nutrition';
import type {
  MealType,
  NutritionMetric,
  NutritionPeriod,
  NutritionRecordResponse,
} from '../types/nutritionProgress';
import type { ProgressPoint } from '../types/progress';
import { isValidDate } from './date';

export const mealLabels: Record<MealType, string> = {
  Breakfast: 'Kahvaltı',
  Lunch: 'Öğle',
  Dinner: 'Akşam',
  Snack: 'Ara öğün',
};
export const nutritionMetrics: {
  key: NutritionMetric;
  goalKey: 'dailyCalories' | Exclude<NutritionMetric, 'calories'>;
  label: string;
  unit: string;
}[] = [
  { key: 'calories', goalKey: 'dailyCalories', label: 'Kalori', unit: 'kcal' },
  { key: 'proteinGrams', goalKey: 'proteinGrams', label: 'Protein', unit: 'g' },
  { key: 'carbohydrateGrams', goalKey: 'carbohydrateGrams', label: 'Karbonhidrat', unit: 'g' },
  { key: 'fatGrams', goalKey: 'fatGrams', label: 'Yağ', unit: 'g' },
];

// Set the calendar date separately: Date's numeric constructor treats years 0–99 as 1900–1999.
export function nutritionDay(date: string) {
  if (!isValidDate(date)) throw new Error('Geçerli bir gün seçin.');
  const [year, month, day] = date.split('-').map(Number);
  const start = new Date(0);
  start.setFullYear(year, month - 1, day);
  start.setHours(0, 0, 0, 0);
  return start;
}
export function nutritionDayRecords(records: NutritionRecordResponse[], date: string) {
  const start = nutritionDay(date);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return records.filter((record) => {
    const time = Date.parse(record.consumedAt);
    return time >= start.getTime() && time < end.getTime();
  });
}
export function nutritionTotals(records: NutritionRecordResponse[]) {
  return Object.fromEntries(
    nutritionMetrics.map(({ key }) => [
      key,
      records.reduce((total, record) => total + Math.round(record[key] * 100), 0) / 100,
    ]),
  ) as Record<NutritionMetric, number>;
}
export function nutritionGoalForDay(goals: NutritionGoalResponse[], date: string) {
  return (
    goals.find(
      (goal) => goal.isActive && goal.startDate <= date && (!goal.endDate || goal.endDate >= date),
    ) ?? null
  );
}
export function nutritionDailyPoints(
  records: NutritionRecordResponse[],
  date: string,
  period: NutritionPeriod,
  metric: NutritionMetric,
): ProgressPoint[] {
  const last = nutritionDay(date);
  const buckets = new Map<string, NutritionRecordResponse[]>();
  for (const record of records) {
    const at = new Date(record.consumedAt);
    const key = `${at.getFullYear()}-${at.getMonth()}-${at.getDate()}`;
    const bucket = buckets.get(key) ?? [];
    bucket.push(record);
    buckets.set(key, bucket);
  }
  return Array.from({ length: period }, (_, index) => {
    const day = new Date(last);
    day.setDate(day.getDate() - index);
    const values = buckets.get(`${day.getFullYear()}-${day.getMonth()}-${day.getDate()}`);
    return {
      id: day.toISOString(),
      recordedAt: day.toISOString(),
      value: values ? nutritionTotals(values)[metric] : null,
    };
  });
}

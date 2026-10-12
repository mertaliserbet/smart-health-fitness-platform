import { expect, it } from 'vitest';
import type { NutritionRecordResponse } from '../types/nutritionProgress';
import type { NutritionGoalResponse } from '../types/nutrition';
import {
  nutritionDailyPoints,
  nutritionDay,
  nutritionDayRecords,
  nutritionGoalForDay,
  nutritionTotals,
} from './nutritionProgress';

const record = (at: Date, calories = 0): NutritionRecordResponse => ({
  id: at.toISOString(),
  userId: 'client',
  name: 'Öğün',
  mealType: 'Lunch',
  calories,
  proteinGrams: 0.1,
  carbohydrateGrams: 0.2,
  fatGrams: 0,
  portionDescription: null,
  sourceType: 'Manual',
  foodRecognitionLogId: null,
  consumedAt: at.toISOString(),
  createdAt: at.toISOString(),
});
it('yerel gece yarısını dahil eder ve sonraki günün başlangıcını dışlar', () => {
  const day = nutritionDay('2026-10-12');
  const end = new Date(day);
  end.setDate(end.getDate() + 1);
  const before = new Date(day.getTime() - 1);
  const inside = new Date(end.getTime() - 1);
  const records = [record(day, 1), record(end, 2), record(before, 3), record(inside, 4)];
  expect(nutritionDayRecords(records, '2026-10-12').map((item) => item.calories)).toEqual([1, 4]);
});
it('günlük grafikte kayıtsız günleri null, girilmiş sıfırı sıfır tutar', () => {
  const records = [
    record(nutritionDay('2026-10-12')),
    record(nutritionDay('2026-10-10'), 0.1),
    record(nutritionDay('2026-10-10'), 0.2),
    record(nutritionDay('2026-10-13'), 100),
  ];
  const points = nutritionDailyPoints(records, '2026-10-12', 7, 'calories');
  expect(points).toHaveLength(7);
  expect(points.map((point) => point.value)).toEqual([0, null, 0.3, null, null, null, null]);
  expect(nutritionTotals(records).proteinGrams).toBe(0.4);
});
it('ay/yıl ve artık gün sınırlarında takvim günü kullanır', () => {
  const points = nutritionDailyPoints([], '2024-03-01', 7, 'calories');
  const at = new Date(points[1].recordedAt);
  expect([at.getFullYear(), at.getMonth(), at.getDate()]).toEqual([2024, 1, 29]);
  expect(nutritionDay('0099-01-01').getFullYear()).toBe(99);
  expect(() => nutritionDay('2026-02-30')).toThrow();
});
it('geçerli aktif hedefi seçer; eski pasif ve dönem dışı hedefi kullanmaz', () => {
  const goal: NutritionGoalResponse = {
    id: 'active',
    isActive: true,
    dailyCalories: 0,
    proteinGrams: 0,
    carbohydrateGrams: 0,
    fatGrams: 0,
    waterMl: 0,
    startDate: '2026-10-10',
    endDate: '2026-10-12',
  };
  const goals = [
    { ...goal, id: 'old', isActive: false, startDate: '2020-01-01', endDate: null },
    goal,
  ];
  expect(nutritionGoalForDay(goals, '2026-10-10')).toBe(goal);
  expect(nutritionGoalForDay(goals, '2026-10-12')).toBe(goal);
  expect(nutritionGoalForDay(goals, '2026-10-09')).toBeNull();
  expect(nutritionGoalForDay(goals, '2026-10-13')).toBeNull();
});

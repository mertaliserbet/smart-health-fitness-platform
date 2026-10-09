import { describe, expect, it } from 'vitest';
import type { NutritionGoalResponse } from '../types/nutrition';
import { nutritionGoalStatus, prepareNutritionGoal } from './nutritionGoal';

const draft = {
  dailyCalories: '0',
  proteinGrams: '150.5',
  carbohydrateGrams: '250',
  fatGrams: '70',
  waterMl: '2500',
  startDate: '2026-10-09',
  endDate: '',
};
describe('Beslenme hedefi tarih ve sayı sınırları', () => {
  it('takvimde olmayan tarihi ve sonsuz sayıyı reddeder; sıfır ve ondalık hedefe izin verir', () => {
    expect(prepareNutritionGoal(draft).errors).toEqual({});
    expect(
      prepareNutritionGoal({ ...draft, startDate: '2026-02-30', proteinGrams: 'Infinity' }).errors,
    ).toEqual({
      startdate: 'Geçerli bir başlangıç tarihi seç.',
      proteingrams: 'Sıfır veya daha büyük bir sayı gir.',
    });
  });
  it('aktif hedefi yalnız başlangıç ve bitiş dahil tarih aralığında geçerli sayar', () => {
    const goal: NutritionGoalResponse = {
      ...prepareNutritionGoal(draft).request,
      id: 'goal',
      isActive: true,
      startDate: '2026-10-09',
      endDate: '2026-10-10',
    };
    expect(nutritionGoalStatus(goal, '2026-10-08').kind).toBe('scheduled');
    expect(nutritionGoalStatus(goal, '2026-10-09').kind).toBe('current');
    expect(nutritionGoalStatus(goal, '2026-10-10').kind).toBe('current');
    expect(nutritionGoalStatus(goal, '2026-10-11').kind).toBe('expired');
    expect(nutritionGoalStatus({ ...goal, isActive: false }, '2026-10-09').kind).toBe('past');
    expect(nutritionGoalStatus({ ...goal, endDate: null }, '2027-01-01').kind).toBe('current');
  });
  it('örnek atama yalnız seçili danışanın önceki aktif hedefini pasifleştirir', async () => {
    const { createDemoNutritionGoal, getDemoNutritionGoals } =
      await import('../demo/demoNutritionData');
    const clientId = '9a97f2b9-2a82-45bd-b7f9-ae24fb73441d';
    const secondClient = '1ded8474-ebcb-4cb8-ab29-85c56dc53a57';
    const other = createDemoNutritionGoal(secondClient, prepareNutritionGoal(draft).request);
    const created = createDemoNutritionGoal(clientId, prepareNutritionGoal(draft).request);
    expect(
      getDemoNutritionGoals(clientId)
        .filter((goal) => goal.isActive)
        .map((goal) => goal.id),
    ).toEqual([created.id]);
    expect(
      getDemoNutritionGoals(secondClient)
        .filter((goal) => goal.isActive)
        .map((goal) => goal.id),
    ).toEqual([other.id]);
    expect(() =>
      createDemoNutritionGoal('unassigned', prepareNutritionGoal(draft).request),
    ).toThrow('erişiminiz');
  });
});

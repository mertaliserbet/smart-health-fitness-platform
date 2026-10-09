import type { CreateNutritionGoalRequest, NutritionGoalResponse } from '../types/nutrition';
import { demoClients } from './demoData';

const goals: Record<string, NutritionGoalResponse[]> = {
  [demoClients.Dietitian[0].id]: [
    {
      id: '69116652-f078-4a9f-b30e-3ddc37ac737e',
      dailyCalories: 2400,
      proteinGrams: 160,
      carbohydrateGrams: 270,
      fatGrams: 75,
      waterMl: 2500,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      isActive: true,
    },
    {
      id: '56bbfcfb-c97e-4f94-b11b-e45adb35c57e',
      dailyCalories: 2300,
      proteinGrams: 150,
      carbohydrateGrams: 260,
      fatGrams: 70,
      waterMl: 2400,
      startDate: '2026-09-01',
      endDate: '2026-09-30',
      isActive: false,
    },
  ],
};

export function getDemoNutritionGoals(userId: string) {
  return structuredClone(goals[userId] ?? []);
}

export function createDemoNutritionGoal(userId: string, request: CreateNutritionGoalRequest) {
  if (
    !demoClients.Dietitian.some(
      (client) => client.id === userId && client.relationshipStatus === 'Active',
    )
  )
    throw new Error('Bu danışana erişiminiz bulunmuyor.');
  const goal = { ...structuredClone(request), id: crypto.randomUUID(), isActive: true };
  goals[userId] = [goal, ...(goals[userId] ?? []).map((value) => ({ ...value, isActive: false }))];
  return structuredClone(goal);
}

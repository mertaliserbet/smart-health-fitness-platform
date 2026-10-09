export interface CreateNutritionGoalRequest {
  dailyCalories: number;
  proteinGrams: number;
  carbohydrateGrams: number;
  fatGrams: number;
  waterMl: number;
  startDate: string;
  endDate: string | null;
}

export interface NutritionGoalResponse extends CreateNutritionGoalRequest {
  id: string;
  isActive: boolean;
}

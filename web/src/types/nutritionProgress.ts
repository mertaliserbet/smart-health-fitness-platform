export type MealType = 'Breakfast' | 'Lunch' | 'Dinner' | 'Snack';
export interface NutritionRecordResponse {
  id: string;
  userId: string;
  mealType: MealType;
  name: string;
  calories: number;
  proteinGrams: number;
  carbohydrateGrams: number;
  fatGrams: number;
  portionDescription: string | null;
  sourceType: 'Manual' | 'AI';
  foodRecognitionLogId: string | null;
  consumedAt: string;
  createdAt: string;
}
export type NutritionMetric = 'calories' | 'proteinGrams' | 'carbohydrateGrams' | 'fatGrams';
export type NutritionPeriod = 7 | 30 | 90;

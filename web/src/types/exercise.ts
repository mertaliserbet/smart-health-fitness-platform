import type { ExerciseResponse } from './workout';

export interface ExerciseDetailResponse extends ExerciseResponse {
  instructions: string | null;
  isActive: boolean;
}

export interface CreateExerciseRequest {
  name: string;
  description: string | null;
  instructions: string | null;
  videoUrl: string | null;
  imageUrl: string | null;
  isActive: boolean;
}

export type Weekday =
  'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday' | 'Saturday' | 'Sunday';

export interface ExerciseResponse {
  id: string;
  name: string;
  description: string | null;
  videoUrl: string | null;
  imageUrl: string | null;
}

export interface CreateWorkoutPlanRequest {
  name: string;
  description: string | null;
  startDate: string;
  endDate: string | null;
  days: {
    name: string;
    dayNumber: number;
    weekday: Weekday;
    description: string | null;
    exercises: {
      exerciseId: string;
      order: number;
      sets: number | null;
      reps: number | null;
      durationSeconds: number | null;
      restSeconds: number | null;
      weightKg: number | null;
      notes: string | null;
    }[];
  }[];
}

export interface WorkoutPlanSummaryResponse {
  id: string;
  name: string;
  startDate: string;
  endDate: string | null;
  isActive: boolean;
}

export interface WorkoutPlanResponse extends WorkoutPlanSummaryResponse {
  userId: string;
  trainerId: string;
  description: string | null;
  days: {
    id: string;
    name: string;
    dayNumber: number;
    weekday: Weekday;
    description?: string | null;
    exercises: (Omit<
      CreateWorkoutPlanRequest['days'][number]['exercises'][number],
      'durationSeconds'
    > & {
      id: string;
      exerciseName: string;
      durationSeconds?: number | null;
    })[];
  }[];
}

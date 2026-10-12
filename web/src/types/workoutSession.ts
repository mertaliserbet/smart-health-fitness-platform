import type { WorkoutPlanResponse } from './workout';

export type WorkoutSessionStatus = 'InProgress' | 'Completed' | 'Cancelled';

export interface WorkoutSessionSummaryResponse {
  id: string;
  userId: string;
  workoutPlanId: string;
  workoutDayId: string;
  planName: string;
  dayName: string;
  startedAt: string;
  completedAt: string | null;
  status: WorkoutSessionStatus;
  completedExerciseCount: number;
  totalExerciseCount: number;
}

export interface PagedWorkoutSessionsResponse {
  items: WorkoutSessionSummaryResponse[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

export interface WorkoutLogResponse {
  id: string;
  workoutExerciseId: string;
  completedSets: number | null;
  completedReps: number | null;
  weightKg: number | null;
  durationSeconds: number | null;
  isCompleted: boolean;
  notes: string | null;
  createdAt: string;
}

export interface WorkoutSessionResponse extends Omit<
  WorkoutSessionSummaryResponse,
  'dayName' | 'completedExerciseCount' | 'totalExerciseCount'
> {
  day: WorkoutPlanResponse['days'][number];
  logs: WorkoutLogResponse[];
}

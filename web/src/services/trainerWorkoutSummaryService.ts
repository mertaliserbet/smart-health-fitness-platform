import type { WorkoutPlanSummaryResponse } from '../types/workout';
import type {
  PagedWorkoutSessionsResponse,
  WorkoutSessionSummaryResponse,
} from '../types/workoutSession';
import { isValidDate } from '../utils/date';
import { ApiError } from './apiClient';
import { getWorkoutPlans } from './workoutService';
import { getWorkoutSessions } from './workoutSessionService';

const invalid = () =>
  new ApiError(502, { detail: 'Danışanın antrenman özeti yanıtı doğrulanamadı. Tekrar deneyin.' });
const text = (value: unknown): value is string =>
  typeof value === 'string' && value.trim().length > 0;
const time = (value: unknown) => text(value) && Number.isFinite(Date.parse(value));
const count = (value: unknown): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;

function validPlan(value: unknown): value is WorkoutPlanSummaryResponse {
  if (!value || typeof value !== 'object') return false;
  const plan = value as Partial<WorkoutPlanSummaryResponse>;
  return (
    text(plan.id) &&
    text(plan.name) &&
    typeof plan.isActive === 'boolean' &&
    text(plan.startDate) &&
    isValidDate(plan.startDate) &&
    (plan.endDate === null ||
      (text(plan.endDate) && isValidDate(plan.endDate) && plan.endDate >= plan.startDate))
  );
}
function validSession(value: unknown, userId: string): value is WorkoutSessionSummaryResponse {
  if (!value || typeof value !== 'object') return false;
  const session = value as Partial<WorkoutSessionSummaryResponse>;
  return (
    text(session.id) &&
    session.userId === userId &&
    text(session.workoutPlanId) &&
    text(session.workoutDayId) &&
    text(session.planName) &&
    text(session.dayName) &&
    time(session.startedAt) &&
    ['InProgress', 'Completed', 'Cancelled'].includes(session.status ?? '') &&
    (session.status === 'Completed'
      ? time(session.completedAt) &&
        Date.parse(session.completedAt!) >= Date.parse(session.startedAt!)
      : session.completedAt === null) &&
    count(session.completedExerciseCount) &&
    count(session.totalExerciseCount) &&
    session.totalExerciseCount > 0 &&
    session.completedExerciseCount <= session.totalExerciseCount
  );
}

export async function getTrainerWorkoutSummary(userId: string, signal?: AbortSignal) {
  try {
    const [plans, history] = await Promise.all([
      getWorkoutPlans(userId, false, signal),
      getWorkoutSessions(userId, 1, '', signal),
    ]);
    if (
      !Array.isArray(plans) ||
      !plans.every(validPlan) ||
      plans.filter((plan) => plan.isActive).length > 1 ||
      !history ||
      !Array.isArray(history.items) ||
      !history.items.every((item) => validSession(item, userId)) ||
      history.page !== 1 ||
      history.pageSize !== 20 ||
      !count(history.totalCount) ||
      history.items.length > 20 ||
      history.items.length > history.totalCount ||
      history.totalPages !== Math.ceil(history.totalCount / 20)
    )
      throw invalid();
    return { userId, plans, history: history as PagedWorkoutSessionsResponse };
  } catch (reason) {
    // Existing API readers can throw TypeError on malformed JSON item shapes.
    if (reason instanceof TypeError) throw invalid();
    throw reason;
  }
}

export function workoutPlanAvailability(
  plan: WorkoutPlanSummaryResponse,
  today = new Date().toISOString().slice(0, 10),
) {
  if (plan.startDate > today) return 'Başlangıç bekleniyor';
  if (plan.endDate && plan.endDate < today) return 'Süresi doldu';
  return 'Tarih aralığında';
}

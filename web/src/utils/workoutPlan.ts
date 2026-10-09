import type { CreateWorkoutPlanRequest, Weekday } from '../types/workout';
import { isValidDate } from './date';
export { localDate } from './date';

export const weekdays: { value: Weekday; label: string }[] = [
  { value: 'Monday', label: 'Pazartesi' },
  { value: 'Tuesday', label: 'Salı' },
  { value: 'Wednesday', label: 'Çarşamba' },
  { value: 'Thursday', label: 'Perşembe' },
  { value: 'Friday', label: 'Cuma' },
  { value: 'Saturday', label: 'Cumartesi' },
  { value: 'Sunday', label: 'Pazar' },
];

export const weekdayLabel = (value: Weekday) =>
  weekdays.find((day) => day.value === value)?.label ?? value;

export interface WorkoutExerciseDraft {
  key: string;
  exerciseId: string;
  exerciseName: string;
  mode: 'reps' | 'duration';
  sets: string;
  reps: string;
  durationSeconds: string;
  restSeconds: string;
  weightKg: string;
  notes: string;
}

export interface WorkoutDayDraft {
  key: string;
  name: string;
  weekday: Weekday;
  description: string;
  exercises: WorkoutExerciseDraft[];
}

export interface WorkoutPlanDraft {
  name: string;
  description: string;
  startDate: string;
  endDate: string;
  days: WorkoutDayDraft[];
}

export function newWorkoutDay(weekday: Weekday, number: number): WorkoutDayDraft {
  return {
    key: crypto.randomUUID(),
    name: `${number}. gün`,
    weekday,
    description: '',
    exercises: [],
  };
}

export function moveItem<T>(items: T[], index: number, offset: number) {
  const next = [...items];
  const target = index + offset;
  if (target < 0 || target >= next.length) return items;
  [next[index], next[target]] = [next[target], next[index]];
  return next;
}

export function prepareWorkoutPlan(draft: WorkoutPlanDraft): {
  errors: Record<string, string>;
  request: CreateWorkoutPlanRequest;
} {
  const errors: Record<string, string> = {};
  if (!draft.name.trim()) errors.name = 'Program adı gerekli.';
  if (!isValidDate(draft.startDate)) errors.startdate = 'Geçerli bir başlangıç tarihi seç.';
  if (draft.endDate && !isValidDate(draft.endDate))
    errors.enddate = 'Geçerli bir bitiş tarihi seç.';
  else if (draft.endDate && draft.endDate < draft.startDate)
    errors.enddate = 'Bitiş tarihi başlangıçtan önce olamaz.';
  if (!draft.days.length) errors.days = 'En az bir antrenman günü ekle.';
  const seen = new Set<Weekday>();
  const optionalNumber = (value: string, path: string, integer: boolean, zero = false) => {
    if (!value.trim()) return null;
    const number = Number(value);
    if (
      !Number.isFinite(number) ||
      (integer && !Number.isSafeInteger(number)) ||
      (zero ? number < 0 : number <= 0)
    )
      errors[path.toLowerCase()] = zero
        ? 'Sıfır veya pozitif bir tam sayı gir.'
        : integer
          ? 'Pozitif bir tam sayı gir.'
          : 'Sıfırdan büyük bir değer gir.';
    return number;
  };
  const days = draft.days.map((day, dayIndex) => {
    const prefix = `days.${dayIndex}`;
    if (!day.name.trim()) errors[`${prefix}.name`] = 'Gün adı gerekli.';
    if (!weekdays.some(({ value }) => value === day.weekday) || seen.has(day.weekday))
      errors[`${prefix}.weekday`] = 'Haftanın her günü yalnız bir kez seçilebilir.';
    seen.add(day.weekday);
    if (!day.exercises.length) errors[`${prefix}.exercises`] = 'Bu güne en az bir egzersiz ekle.';
    return {
      name: day.name.trim(),
      dayNumber: dayIndex + 1,
      weekday: day.weekday,
      description: day.description.trim() || null,
      exercises: day.exercises.map((exercise, index) => {
        const path = `${prefix}.exercises.${index}`;
        const sets =
          exercise.mode === 'reps' ? optionalNumber(exercise.sets, `${path}.sets`, true) : null;
        const reps =
          exercise.mode === 'reps' ? optionalNumber(exercise.reps, `${path}.reps`, true) : null;
        const durationSeconds =
          exercise.mode === 'duration'
            ? optionalNumber(exercise.durationSeconds, `${path}.durationseconds`, true)
            : null;
        if (exercise.mode === 'reps') {
          if (sets === null) errors[`${path}.sets`] = 'Set sayısı gerekli.';
          if (reps === null) errors[`${path}.reps`] = 'Tekrar sayısı gerekli.';
        } else if (durationSeconds === null) errors[`${path}.durationseconds`] = 'Süre gerekli.';
        return {
          exerciseId: exercise.exerciseId,
          order: index + 1,
          sets,
          reps,
          durationSeconds,
          restSeconds: optionalNumber(exercise.restSeconds, `${path}.restseconds`, true, true),
          weightKg: optionalNumber(exercise.weightKg, `${path}.weightkg`, false),
          notes: exercise.notes.trim() || null,
        };
      }),
    };
  });
  return {
    errors,
    request: {
      name: draft.name.trim(),
      description: draft.description.trim() || null,
      startDate: draft.startDate,
      endDate: draft.endDate || null,
      days,
    },
  };
}

import type {
  CreateWorkoutPlanRequest,
  ExerciseResponse,
  WorkoutPlanResponse,
} from '../types/workout';
import { demoAdvisors, demoClients } from './demoData';

export const demoExercises: ExerciseResponse[] = [
  {
    id: '1dd55d43-ee46-4769-94e0-bad9fcf79df1',
    name: 'Bench Press',
    description: 'Göğüs bölgesine yönelik kuvvet egzersizi.',
    videoUrl: null,
    imageUrl: null,
  },
  {
    id: '81c2700a-4d8f-4f42-9ade-1c4c723a0082',
    name: 'Lat Pulldown',
    description: 'Sırt bölgesine yönelik çekiş egzersizi.',
    videoUrl: null,
    imageUrl: null,
  },
  {
    id: '6d8d2862-4f2d-423c-a3e7-98d8b8dfd0c7',
    name: 'Squat',
    description: 'Alt vücuda yönelik kuvvet egzersizi.',
    videoUrl: null,
    imageUrl: null,
  },
  {
    id: '1bcfd7dc-1184-4f46-8ad0-4e63649983d1',
    name: 'Plank',
    description: 'Süreyle planlanabilen merkez bölge egzersizi.',
    videoUrl: null,
    imageUrl: null,
  },
  {
    id: '95711161-471b-4dba-8217-cf3348cbca16',
    name: 'Yürüyüş',
    description: 'Süreyle planlanabilen kardiyo egzersizi.',
    videoUrl: null,
    imageUrl: null,
  },
];

let plans: WorkoutPlanResponse[] = [
  {
    id: '78ddeebe-f4db-427f-9bda-22777ca56585',
    userId: demoClients.Trainer[0].id,
    trainerId: demoAdvisors.Trainer.id,
    name: 'Temel Kuvvet Programı',
    description: 'Arayüz önizlemesi için örnek program.',
    startDate: '2026-10-01',
    endDate: '2026-11-01',
    isActive: true,
    days: [
      {
        id: '27635ace-c211-4cfb-a340-c356701e6e43',
        name: 'Üst vücut',
        dayNumber: 1,
        weekday: 'Monday',
        description: null,
        exercises: [
          {
            id: '435d9193-fb1e-493d-bd80-c0f30ce84449',
            exerciseId: demoExercises[0].id,
            exerciseName: demoExercises[0].name,
            order: 1,
            sets: 3,
            reps: 10,
            durationSeconds: null,
            restSeconds: 60,
            weightKg: null,
            notes: null,
          },
        ],
      },
    ],
  },
];

export function getDemoWorkoutPlans(userId: string) {
  return plans
    .filter((plan) => plan.userId === userId)
    .map(({ id, name, startDate, endDate, isActive }) => ({
      id,
      name,
      startDate,
      endDate,
      isActive,
    }));
}

export function getDemoWorkoutPlan(id: string) {
  const plan = plans.find((value) => value.id === id);
  if (!plan) throw new Error('Program bulunamadı.');
  return structuredClone(plan);
}

export function createDemoWorkoutPlan(userId: string, request: CreateWorkoutPlanRequest) {
  if (!demoClients.Trainer.some((client) => client.id === userId))
    throw new Error('Bu danışana erişiminiz bulunmuyor.');
  const next: WorkoutPlanResponse = {
    ...structuredClone(request),
    id: crypto.randomUUID(),
    userId,
    trainerId: demoAdvisors.Trainer.id,
    isActive: true,
    days: request.days.map((day) => ({
      ...day,
      id: crypto.randomUUID(),
      exercises: day.exercises.map((exercise) => {
        const catalog = demoExercises.find((value) => value.id === exercise.exerciseId);
        if (!catalog) throw new Error('Egzersiz katalogda bulunamadı.');
        return { ...exercise, id: crypto.randomUUID(), exerciseName: catalog.name };
      }),
    })),
  };
  plans = [
    ...plans.map((plan) => (plan.userId === userId ? { ...plan, isActive: false } : plan)),
    next,
  ];
}

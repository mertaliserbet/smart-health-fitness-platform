import { describe, expect, it } from 'vitest';
import { prepareWorkoutPlan, type WorkoutPlanDraft } from './workoutPlan';

describe('Program kuralları', () => {
  it('ağırlığın iki ondalık basamağını kaybetmeden API isteği oluşturur', () => {
    const draft: WorkoutPlanDraft = {
      name: 'Plan',
      description: '',
      startDate: '2026-10-11',
      endDate: '',
      days: [
        {
          key: 'day',
          name: 'Kuvvet',
          weekday: 'Monday',
          description: '',
          exercises: [
            {
              key: 'exercise',
              exerciseId: 'exercise-id',
              exerciseName: 'Squat',
              mode: 'reps',
              sets: '3',
              reps: '10',
              durationSeconds: '',
              restSeconds: '',
              weightKg: '20.29',
              notes: '',
            },
          ],
        },
      ],
    };
    expect(prepareWorkoutPlan(draft).errors).toEqual({});
    expect(prepareWorkoutPlan(draft).request.days[0].exercises[0].weightKg).toBe(20.29);
    draft.days[0].exercises[0].weightKg = '20.291';
    expect(prepareWorkoutPlan(draft).errors['days.0.exercises.0.weightkg']).toBeTruthy();
  });
  it('takvimde bulunmayan tarih, boş gün ve yinelenen weekday değerlerini reddeder', () => {
    const draft: WorkoutPlanDraft = {
      name: 'Plan',
      description: '',
      startDate: '2026-02-30',
      endDate: '',
      days: [
        { key: '1', name: 'Birinci gün', weekday: 'Monday', description: '', exercises: [] },
        { key: '2', name: 'İkinci gün', weekday: 'Monday', description: '', exercises: [] },
      ],
    };
    const { errors } = prepareWorkoutPlan(draft);
    expect(errors).toMatchObject({
      startdate: expect.any(String),
      'days.0.exercises': expect.any(String),
      'days.1.weekday': expect.any(String),
    });
  });
});

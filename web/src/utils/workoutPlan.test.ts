import { describe, expect, it } from 'vitest';
import { prepareWorkoutPlan, type WorkoutPlanDraft } from './workoutPlan';

describe('Program kuralları', () => {
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

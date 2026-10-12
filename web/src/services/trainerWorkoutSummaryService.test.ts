import { afterEach, expect, it, vi } from 'vitest';
import { getTrainerWorkoutSummary, workoutPlanAvailability } from './trainerWorkoutSummaryService';
const plan = {
  id: 'plan',
  name: 'Program',
  startDate: '2026-10-01',
  endDate: null,
  isActive: true,
};
const session = {
  id: 'session',
  userId: 'client/other',
  workoutPlanId: 'plan',
  workoutDayId: 'day',
  planName: 'Program',
  dayName: 'Üst vücut',
  startedAt: '2026-10-11T10:00:00Z',
  completedAt: '2026-10-11T11:00:00Z',
  status: 'Completed',
  completedExerciseCount: 1,
  totalExerciseCount: 3,
};
const history = { items: [session], page: 1, pageSize: 20, totalCount: 25, totalPages: 2 };
function mock(plans: unknown = [plan], sessions: unknown = history, status = 200) {
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(
    async (url) =>
      new Response(JSON.stringify(String(url).includes('workout-plans') ? plans : sessions), {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
  );
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}
afterEach(() => vi.unstubAllGlobals());
it('mevcut API okuyucularını, encode edilmiş GET ve ortak AbortSignal ile kullanır', async () => {
  const fetchMock = mock();
  const signal = new AbortController().signal;
  const result = await getTrainerWorkoutSummary('client/other', signal);
  expect(result.plans).toEqual([plan]);
  expect(result.history.totalCount).toBe(25);
  expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([
    '/api/users/client%2Fother/workout-plans',
    '/api/users/client%2Fother/workout-sessions?page=1&pageSize=20',
  ]);
  expect(
    fetchMock.mock.calls.every(
      ([, options]) => options?.signal === signal && (options?.method ?? 'GET') === 'GET',
    ),
  ).toBe(true);
});
it('boş geçmişi kabul eder; pasif programı aktif saymaz', async () => {
  mock([{ ...plan, isActive: false }], { ...history, items: [], totalCount: 0, totalPages: 0 });
  const result = await getTrainerWorkoutSummary('client/other');
  expect(result.plans.find((item) => item.isActive)).toBeUndefined();
  expect(result.history.totalCount).toBe(0);
});
it.each([
  { plans: [{ ...plan, startDate: 'invalid' }], sessions: history },
  { plans: [plan, { ...plan, id: 'second-active' }], sessions: history },
  { plans: [plan], sessions: { ...history, totalCount: '25' } },
  { plans: [plan], sessions: { ...history, totalPages: 1 } },
  { plans: [plan], sessions: { ...history, items: [null] } },
  { plans: [plan], sessions: { ...history, items: [{ ...session, userId: 'other' }] } },
  { plans: [plan], sessions: { ...history, items: [{ ...session, status: 'Unknown' }] } },
  { plans: [plan], sessions: { ...history, items: [{ ...session, startedAt: 'invalid' }] } },
  { plans: [plan], sessions: { ...history, items: [{ ...session, completedExerciseCount: 4 }] } },
])('bozuk/başka danışana ait özet sayılara dönüştürülmez: %j', async ({ plans, sessions }) => {
  mock(plans, sessions);
  await expect(getTrainerWorkoutSummary('client/other')).rejects.toMatchObject({ status: 502 });
});
it('API erişim hatasını değiştirmez veya örnek veriye dönmez', async () => {
  mock({ detail: 'İlişki sona erdi.' }, { detail: 'İlişki sona erdi.' }, 403);
  await expect(getTrainerWorkoutSummary('client/other')).rejects.toMatchObject({
    status: 403,
    message: 'İlişki sona erdi.',
  });
});
it('program tarih durumunda başlangıç ve bitiş günlerini dahil eder', () => {
  const dated = { ...plan, startDate: '2026-10-11', endDate: '2026-10-12' };
  expect(workoutPlanAvailability(dated, '2026-10-10')).toBe('Başlangıç bekleniyor');
  expect(workoutPlanAvailability(dated, '2026-10-11')).toBe('Tarih aralığında');
  expect(workoutPlanAvailability(dated, '2026-10-12')).toBe('Tarih aralığında');
  expect(workoutPlanAvailability(dated, '2026-10-13')).toBe('Süresi doldu');
});

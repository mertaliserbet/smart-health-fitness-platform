import { afterEach, expect, it, vi } from 'vitest';
import { getClientNutritionRecords } from './nutritionProgressService';
const record = {
  id: 'record',
  userId: 'client/other',
  mealType: 'Lunch',
  name: 'Öğün',
  calories: 0,
  proteinGrams: 12.25,
  carbohydrateGrams: 0,
  fatGrams: 0,
  portionDescription: null,
  sourceType: 'Manual',
  foodRecognitionLogId: null,
  consumedAt: '2026-10-12T00:00:00Z',
  createdAt: '2026-10-12T00:00:00Z',
};
function mock(body: unknown, status = 200) {
  const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    }),
  );
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}
afterEach(() => vi.unstubAllGlobals());
it('mevcut DTO, sıfır/null/ondalıkları korur ve yalnız encode edilmiş GET gönderir', async () => {
  const fetchMock = mock([record]);
  const signal = new AbortController().signal;
  expect(await getClientNutritionRecords('client/other', signal)).toEqual([record]);
  expect(fetchMock.mock.calls[0][0]).toBe('/api/users/client%2Fother/nutrition-records');
  expect(fetchMock.mock.calls[0][1]?.signal).toBe(signal);
  expect(fetchMock.mock.calls[0][1]?.method ?? 'GET').toBe('GET');
  mock([]);
  expect(await getClientNutritionRecords('client/other')).toEqual([]);
});
it.each([
  { userId: 'other' },
  { calories: '12' },
  { fatGrams: -1 },
  { mealType: 'Invalid' },
  { consumedAt: 'invalid' },
  { sourceType: 'Unknown' },
  { portionDescription: undefined },
])('bozuk/başka kullanıcıya ait yanıtı reddeder: %j', async (patch) => {
  mock([{ ...record, ...patch }]);
  await expect(getClientNutritionRecords('client/other')).rejects.toMatchObject({ status: 502 });
});
it('gerçek API hatasını korur; örnek veri döndürmez', async () => {
  mock({ detail: 'Erişim yok.' }, 403);
  await expect(getClientNutritionRecords('client/other')).rejects.toMatchObject({
    status: 403,
    message: 'Erişim yok.',
  });
});

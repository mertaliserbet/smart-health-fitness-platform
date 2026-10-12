import { afterEach, expect, it, vi } from 'vitest';
import { getClientBodyMeasurements, getClientWeightRecords } from './progressService';

const record = {
  id: 'record',
  recordedAt: '2026-10-01T00:00:00Z',
  chestCm: null,
  waistCm: 88,
  hipCm: null,
  armCm: null,
  thighCm: null,
  bodyFatPercentage: 0,
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
it('mevcut DTO değerlerini korur ve yolu encode ederek yalnız GET gönderir', async () => {
  const fetchMock = mock([record]);
  const signal = new AbortController().signal;
  expect(await getClientBodyMeasurements('client/other', signal)).toEqual([record]);
  expect(fetchMock.mock.calls[0][0]).toBe('/api/users/client%2Fother/body-measurements');
  expect(fetchMock.mock.calls[0][1]?.signal).toBe(signal);
  expect(fetchMock.mock.calls[0][1]?.method ?? 'GET').toBe('GET');
});
it('boş geçmişi kabul eder; sayı dizgesi/geçersiz tarih/aralık/dizi dışı yanıtı reddeder', async () => {
  mock([]);
  expect(await getClientWeightRecords('client')).toEqual([]);
  for (const value of [
    {},
    [{ id: 'a', recordedAt: 'invalid', weightKg: 80 }],
    [{ id: 'a', recordedAt: record.recordedAt, weightKg: '80' }],
    [{ id: 'a', recordedAt: record.recordedAt, weightKg: 0 }],
  ]) {
    mock(value);
    await expect(getClientWeightRecords('client')).rejects.toMatchObject({ status: 502 });
  }
});
it('eksik DTO alanını, sıfır cm ve yüzde 100 üzerini reddeder; API 403 hatasını korur', async () => {
  for (const value of [
    { ...record, hipCm: undefined },
    { ...record, waistCm: 0 },
    { ...record, bodyFatPercentage: 100.01 },
  ]) {
    mock([value]);
    await expect(getClientBodyMeasurements('client')).rejects.toMatchObject({ status: 502 });
  }
  mock({ detail: 'Aktif danışman ilişkisi gerekli.' }, 403);
  await expect(getClientBodyMeasurements('client')).rejects.toMatchObject({ status: 403 });
});

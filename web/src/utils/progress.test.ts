import { describe, expect, it } from 'vitest';
import { progressChart, progressRecords, progressSummary } from './progress';
import type { ProgressPoint } from '../types/progress';

const point = (id: string, date: string, value: number | null): ProgressPoint => ({
  id,
  recordedAt: date,
  value,
});
describe('danışan ilerleme hesapları', () => {
  it('bugün dahil yerel 30 gün sınırını uygular, yarını ve geçersiz tarihi dışlar', () => {
    const now = new Date(2026, 9, 11, 12);
    const rows = [
      point('today', new Date(2026, 9, 11, 23, 59).toISOString(), 80),
      point('tomorrow', new Date(2026, 9, 12).toISOString(), 80),
      point('start', new Date(2026, 8, 12).toISOString(), 81),
      point('before', new Date(2026, 8, 11, 23, 59).toISOString(), 82),
      point('invalid', 'invalid', 80),
    ];
    expect(progressRecords(rows, '30', now).map((p) => p.id)).toEqual(['today', 'start']);
    expect(progressRecords(rows, 'all', now).map((p) => p.id)).toEqual([
      'today',
      'start',
      'before',
    ]);
  });
  it('eksik son ölçüm yerine seçili alanın son dolu ölçümünü ve gerçek tarihini kullanır', () => {
    const rows = [
      point('null', '2026-10-11T00:00:00Z', null),
      point('last', '2026-10-10T00:00:00Z', 88),
      point('first', '2026-10-01T00:00:00Z', 90),
    ];
    expect(progressSummary(rows)).toMatchObject({
      count: 2,
      change: -2,
      last: { id: 'last', recordedAt: rows[1].recordedAt },
    });
  });
  it('aynı zamanlı kayıtların API önceliğini korur ve sıfırı dolu ölçüm sayar', () => {
    const rows = [
      point('newest', '2026-10-01T00:00:00Z', 0),
      point('older', '2026-10-01T00:00:00Z', 1),
    ];
    expect(progressSummary(rows)).toMatchObject({
      count: 2,
      change: -1,
      last: { id: 'newest', value: 0 },
    });
  });
  it('tek ölçümde değişim üretmez; boş/kısmi geçmişte veri uydurmaz', () => {
    expect(progressSummary([point('one', '2026-10-01T00:00:00Z', 80)])?.change).toBeNull();
    expect(progressSummary([])).toBeNull();
    expect(progressChart([point('empty', '2026-10-01T00:00:00Z', null)])).toBeNull();
  });
  it('eksik kayıtta çizgiyi keser; noktalar zaman aralığına göre yerleşir', () => {
    const rows = [
      point('last', '2026-10-11T00:00:00Z', 88),
      point('missing', '2026-10-06T00:00:00Z', null),
      point('early', '2026-10-02T00:00:00Z', 90),
      point('first', '2026-10-01T00:00:00Z', 91),
    ];
    const chart = progressChart(rows)!;
    expect(chart.segments.map((s) => s.map((p) => p.id))).toEqual([['first', 'early'], ['last']]);
    expect(chart.segments[0][1].x).toBeCloseTo(128);
    expect(chart.segments[1][0].x).toBe(704);
  });
  it('tek/sabit/sıfır/aynı zamanlı ölçümleri sonlu koordinatlarla çizer', () => {
    for (const value of [0, 80]) {
      const chart = progressChart([
        point('a', '2026-10-01T00:00:00Z', value),
        point('b', '2026-10-01T00:00:00Z', value),
      ])!;
      expect(chart.maxValue).toBeGreaterThan(chart.minValue);
      expect(chart.segments.flat().every((p) => Number.isFinite(p.y) && p.x === 384)).toBe(true);
    }
  });
});

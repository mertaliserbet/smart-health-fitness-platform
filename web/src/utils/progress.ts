import type { BodyMetric, ProgressPeriod, ProgressPoint } from '../types/progress';

export const bodyMetrics: { key: BodyMetric; label: string; unit: string }[] = [
  { key: 'waistCm', label: 'Bel', unit: 'cm' },
  { key: 'chestCm', label: 'Göğüs', unit: 'cm' },
  { key: 'hipCm', label: 'Kalça', unit: 'cm' },
  { key: 'armCm', label: 'Kol', unit: 'cm' },
  { key: 'thighCm', label: 'Uyluk', unit: 'cm' },
  { key: 'bodyFatPercentage', label: 'Vücut yağ oranı', unit: '%' },
];

export function progressRecords<T extends { recordedAt: string }>(
  records: T[],
  period: ProgressPeriod,
  now = new Date(),
) {
  const end = new Date(now);
  end.setHours(0, 0, 0, 0);
  end.setDate(end.getDate() + 1);
  const start = new Date(end);
  if (period !== 'all') start.setDate(start.getDate() - Number(period));
  return records.filter((item) => {
    const time = Date.parse(item.recordedAt);
    return (
      Number.isFinite(time) && time < end.getTime() && (period === 'all' || time >= start.getTime())
    );
  });
}

// Server lists are newest first, including creation-time/ID ties. Reversing preserves that precedence.
export function chronological(points: ProgressPoint[]) {
  return [...points].reverse().sort((a, b) => Date.parse(a.recordedAt) - Date.parse(b.recordedAt));
}

export function progressSummary(points: ProgressPoint[]) {
  const values = chronological(points).filter(
    (point): point is ProgressPoint & { value: number } => point.value !== null,
  );
  if (!values.length) return null;
  const first = values[0];
  const last = values[values.length - 1];
  return {
    first,
    last,
    count: values.length,
    change: values.length > 1 ? last.value - first.value : null,
  };
}

export function formatProgressValue(value: number) {
  return new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 2 }).format(value);
}

export function formatProgressTime(value: string) {
  return new Date(value).toLocaleString('tr-TR', { dateStyle: 'medium', timeStyle: 'short' });
}

export function progressChart(points: ProgressPoint[]) {
  const ordered = chronological(points);
  const values = ordered.filter(
    (point): point is ProgressPoint & { value: number } => point.value !== null,
  );
  if (!values.length) return null;
  const low = values.reduce((min, point) => Math.min(min, point.value), values[0].value);
  const high = values.reduce((max, point) => Math.max(max, point.value), values[0].value);
  const padding = Math.max((high - low) * 0.15, 0.5);
  const minValue = Math.max(0, Math.floor((low - padding) * 100) / 100);
  const maxValue = Math.ceil((high + padding) * 100) / 100;
  const minTime = Date.parse(ordered[0].recordedAt);
  const maxTime = Date.parse(ordered[ordered.length - 1].recordedAt);
  type PlotPoint = ProgressPoint & { value: number; x: number; y: number };
  const segments: PlotPoint[][] = [];
  let segment: PlotPoint[] = [];
  for (const point of ordered) {
    if (point.value === null) {
      if (segment.length) segments.push(segment);
      segment = [];
      continue;
    }
    segment.push({
      ...point,
      value: point.value,
      x:
        maxTime === minTime
          ? 384
          : 64 + ((Date.parse(point.recordedAt) - minTime) / (maxTime - minTime)) * 640,
      y: 190 - ((point.value - minValue) / (maxValue - minValue)) * 160,
    });
  }
  if (segment.length) segments.push(segment);
  return { minValue, maxValue, minTime, maxTime, segments, count: values.length };
}

import { useId } from 'react';
import type { ProgressPoint } from '../types/progress';
import { formatProgressTime, formatProgressValue, progressChart } from '../utils/progress';

export function ProgressChart({
  points,
  label,
  unit,
}: {
  points: ProgressPoint[];
  label: string;
  unit: string;
}) {
  const id = useId();
  const chart = progressChart(points);
  if (!chart)
    return <p className="muted">Bu dönem için {label.toLocaleLowerCase('tr-TR')} ölçümü yok.</p>;
  const ticks = [chart.maxValue, (chart.maxValue + chart.minValue) / 2, chart.minValue];
  const date = (value: number) =>
    new Date(value).toLocaleDateString('tr-TR', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  return (
    <figure className="progress-chart">
      <div
        className="progress-chart-scroll"
        role="region"
        aria-label={`${label} grafik alanı`}
        tabIndex={0}
      >
        <svg
          viewBox="0 0 720 235"
          role="img"
          aria-labelledby={`${id}-title`}
          aria-describedby={`${id}-description`}
        >
          <title id={`${id}-title`}>{label} geçmişi grafiği</title>
          <desc id={`${id}-description`}>
            {chart.count} ölçüm. Dikey eksen {unit}, yatay eksen kayıt tarihi. Eksik ölçümler
            çizgiyi keser. Tüm değerler aşağıdaki kayıt tablosunda bulunur.
          </desc>
          <text x="64" y="16" className="chart-label">
            {unit}
          </text>
          {ticks.map((value, index) => (
            <g key={index}>
              <line
                x1="64"
                x2="704"
                y1={30 + index * 80}
                y2={30 + index * 80}
                className="chart-grid"
              />
              <text x="54" y={34 + index * 80} textAnchor="end" className="chart-label">
                {formatProgressValue(value)}
              </text>
            </g>
          ))}
          {chart.segments.map((segment, index) => (
            <g key={index}>
              {segment.length > 1 && (
                <polyline
                  points={segment.map((point) => `${point.x},${point.y}`).join(' ')}
                  className="chart-line"
                />
              )}
              {segment.map((point) => (
                <circle key={point.id} cx={point.x} cy={point.y} r="4" className="chart-point">
                  <title>
                    {formatProgressTime(point.recordedAt)}: {formatProgressValue(point.value)}{' '}
                    {unit}
                  </title>
                </circle>
              ))}
            </g>
          ))}
          {chart.minTime === chart.maxTime ? (
            <text x="384" y="217" textAnchor="middle" className="chart-label">
              {date(chart.minTime)}
            </text>
          ) : (
            <>
              <text x="64" y="217" className="chart-label">
                {date(chart.minTime)}
              </text>
              <text x="704" y="217" textAnchor="end" className="chart-label">
                {date(chart.maxTime)}
              </text>
            </>
          )}
        </svg>
      </div>
      <figcaption>
        {chart.count} ölçüm ·{' '}
        {chart.count === 1
          ? 'Tek kayıt; değişim henüz hesaplanamaz.'
          : 'Noktaların ayrıntıları kayıt tablosunda.'}
        <span className="chart-scroll-hint"> Grafiği yatay kaydırabilirsin.</span>
      </figcaption>
    </figure>
  );
}

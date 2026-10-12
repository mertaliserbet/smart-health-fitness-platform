import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { PageState } from '../components/PageState';
import { ProgressChart } from '../components/ProgressChart';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getClientBodyMeasurements, getClientWeightRecords } from '../services/progressService';
import type { BodyMetric, ProgressPeriod, ProgressPoint } from '../types/progress';
import {
  bodyMetrics,
  formatProgressTime,
  formatProgressValue,
  progressRecords,
  progressSummary,
} from '../utils/progress';

export function ClientBodyProgress() {
  const { userId = '' } = useParams();
  const { role, demo } = useAuth();
  const [period, setPeriod] = useState<ProgressPeriod>('90');
  const [metricKey, setMetricKey] = useState<BodyMetric>('waistCm');
  const {
    data: loaded,
    loading,
    error,
    retry,
  } = useLoad(
    async (signal) => {
      if (demo)
        throw new Error('Kilo ve vücut ilerlemesi için gerçek danışman hesabıyla giriş yapın.');
      if (role !== 'Trainer' && role !== 'Dietitian') throw new Error('Danışman rolü gerekli.');
      const client = await requireClient(userId, role, false, signal);
      const [weights, measurements] = await Promise.all([
        getClientWeightRecords(userId, signal),
        getClientBodyMeasurements(userId, signal),
      ]);
      return { client, weights, measurements, role };
    },
    [userId, role, demo],
  );
  const data = loaded?.client.id === userId && loaded.role === role ? loaded : null;
  const metric = bodyMetrics.find((value) => value.key === metricKey)!;
  const weights: ProgressPoint[] = data
    ? progressRecords(data.weights, period).map((record) => ({ ...record, value: record.weightKg }))
    : [];
  const measurements: ProgressPoint[] = data
    ? progressRecords(data.measurements, period).map((record) => ({
        id: record.id,
        recordedAt: record.recordedAt,
        value: record[metricKey],
      }))
    : [];
  return (
    <>
      <Link className="back-link" to={`/danisanlar/${userId}`}>
        Danışana dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">DANIŞAN İLERLEMESİ</span>
          <h1>Kilo / Vücut ilerlemesi</h1>
          <p className="muted">
            Danışanının kaydettiği kilo ve vücut ölçümlerini zaman içinde karşılaştır.
          </p>
        </div>
      </div>
      {loading || error || !data ? (
        <section className="panel">
          <PageState loading={loading || (!data && !error)} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <>
            <section className="panel body-progress-toolbar">
              <div>
                <h2>
                  {data.client.firstName} {data.client.lastName}
                </h2>
                <p className="muted">Kaynak: danışanın kendi ölçüm kayıtları.</p>
              </div>
              <div>
                <label htmlFor="progress-period">Dönem</label>
                <select
                  id="progress-period"
                  value={period}
                  onChange={(event) => setPeriod(event.target.value as ProgressPeriod)}
                >
                  <option value="30">Son 30 gün</option>
                  <option value="90">Son 90 gün</option>
                  <option value="365">Son 1 yıl</option>
                  <option value="all">Tüm geçmiş</option>
                </select>
              </div>
            </section>
            <p className="progress-period-note muted">
              Dönem bugün dahil yerel takvim günlerine göre seçilir. Değişim, seçili dönemin ilk ve
              son dolu ölçümünü karşılaştırır.
            </p>
            <ProgressSection
              key={`weight-${userId}-${role}-${period}`}
              title="Kilo"
              unit="kg"
              points={weights}
            />
            <section className="panel body-progress-metric">
              <label htmlFor="body-metric">Vücut ölçümü</label>
              <select
                id="body-metric"
                value={metricKey}
                onChange={(event) => setMetricKey(event.target.value as BodyMetric)}
              >
                {bodyMetrics.map((value) => (
                  <option key={value.key} value={value.key}>
                    {value.label} ({value.unit})
                  </option>
                ))}
              </select>
            </section>
            <ProgressSection
              key={`body-${userId}-${role}-${period}-${metricKey}`}
              title={metric.label}
              unit={metric.unit}
              points={measurements}
              body
            />
          </>
        )
      )}
    </>
  );
}

function ProgressSection({
  title,
  unit,
  points,
  body = false,
}: {
  title: string;
  unit: string;
  points: ProgressPoint[];
  body?: boolean;
}) {
  const [page, setPage] = useState(1);
  const summary = progressSummary(points);
  const totalPages = Math.max(1, Math.ceil(points.length / 20));
  return (
    <section className="panel body-progress-section" aria-label={`${title} ilerlemesi`}>
      <div className="panel-heading">
        <div>
          <h2>{title}</h2>
          <p>
            {points.length} kayıt · {summary?.count ?? 0} dolu ölçüm
          </p>
        </div>
      </div>
      <div className="body-progress-content">
        {summary && (
          <dl className="progress-summary">
            <div>
              <dt>Son {title.toLocaleLowerCase('tr-TR')} ölçümü</dt>
              <dd>
                {formatProgressValue(summary.last.value)} <small>{unit}</small>
              </dd>
              <p className="muted">{formatProgressTime(summary.last.recordedAt)}</p>
            </div>
            <div>
              <dt>Dönemdeki değişim</dt>
              <dd>
                {summary.change === null
                  ? '—'
                  : `${summary.change > 0 ? '+' : ''}${formatProgressValue(summary.change)} ${unit}`}
              </dd>
              <p className="muted">
                {summary.change === null
                  ? 'En az iki dolu ölçüm gerekli.'
                  : `${formatProgressTime(summary.first.recordedAt)} tarihinden itibaren`}
              </p>
            </div>
          </dl>
        )}
        {points.length === 0 ? (
          <p className="muted">Bu dönem için {body ? 'vücut ölçümü' : 'kilo'} kaydı yok.</p>
        ) : (
          <>
            <ProgressChart points={points} label={title} unit={unit} />
            {body && (
              <p className="muted">Ölçüm girilmemiş alanlar “—” ile gösterilir; sıfır sayılmaz.</p>
            )}
            <div className="table-scroll">
              <table aria-label={`${title} kayıtları`}>
                <thead>
                  <tr>
                    <th scope="col">Kayıt zamanı</th>
                    <th scope="col">
                      {title} ({unit})
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {points.slice((page - 1) * 20, page * 20).map((point) => (
                    <tr key={point.id}>
                      <td>{formatProgressTime(point.recordedAt)}</td>
                      <td>{point.value === null ? '—' : formatProgressValue(point.value)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {points.length > 20 && (
              <nav className="progress-pagination" aria-label={`${title} kayıt sayfaları`}>
                <button
                  className="button secondary"
                  disabled={page <= 1}
                  onClick={() => setPage((value) => value - 1)}
                >
                  Önceki sayfa
                </button>
                <span>
                  Sayfa {page} / {totalPages}
                </span>
                <button
                  className="button secondary"
                  disabled={page >= totalPages}
                  onClick={() => setPage((value) => value + 1)}
                >
                  Sonraki sayfa
                </button>
              </nav>
            )}
          </>
        )}
      </div>
    </section>
  );
}

import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { PageState } from '../components/PageState';
import { ProgressChart } from '../components/ProgressChart';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getNutritionGoals } from '../services/nutritionService';
import { getClientNutritionRecords } from '../services/nutritionProgressService';
import type {
  MealType,
  NutritionMetric,
  NutritionPeriod,
  NutritionRecordResponse,
} from '../types/nutritionProgress';
import type { ProgressPoint } from '../types/progress';
import { isValidDate, localDate } from '../utils/date';
import {
  mealLabels,
  nutritionDailyPoints,
  nutritionDayRecords,
  nutritionGoalForDay,
  nutritionMetrics,
  nutritionTotals,
} from '../utils/nutritionProgress';
import { formatProgressTime, formatProgressValue } from '../utils/progress';
import './ClientNutritionProgress.css';

export function ClientNutritionProgress() {
  const { userId = '' } = useParams();
  const { role, demo } = useAuth();
  const [date, setDate] = useState(localDate);
  const [period, setPeriod] = useState<NutritionPeriod>(30);
  const [metricKey, setMetricKey] = useState<NutritionMetric>('calories');
  const [meal, setMeal] = useState<MealType | 'all'>('all');
  const {
    data: loaded,
    loading,
    error,
    retry,
  } = useLoad(
    async (signal) => {
      if (demo)
        throw new Error('Beslenme ilerlemesi için gerçek diyetisyen hesabıyla giriş yapın.');
      if (role !== 'Dietitian') throw new Error('Diyetisyen rolü gerekli.');
      const client = await requireClient(userId, 'Dietitian', false, signal);
      const [records, goals] = await Promise.all([
        getClientNutritionRecords(userId, signal),
        getNutritionGoals(userId, false, signal),
      ]);
      return { client, records, goals, role };
    },
    [userId, role, demo],
  );
  const data = loaded?.client.id === userId && loaded.role === role ? loaded : null;
  const dateValid = isValidDate(date) && date <= localDate() && date !== '9999-12-31';
  const records = data && dateValid ? nutritionDayRecords(data.records, date) : [];
  const totals = nutritionTotals(records);
  const goal = data && dateValid ? nutritionGoalForDay(data.goals, date) : null;
  const metric = nutritionMetrics.find((item) => item.key === metricKey)!;
  const points =
    data && dateValid ? nutritionDailyPoints(data.records, date, period, metricKey) : [];
  return (
    <>
      <Link className="back-link" to={`/danisanlar/${userId}`}>
        Danışana dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">DİYETİSYEN ÇALIŞMA ALANI</span>
          <h1>Beslenme ilerlemesi</h1>
          <p className="muted">
            Danışanın kaydettiği öğünleri ve günlük kalori/makro toplamlarını incele.
          </p>
        </div>
      </div>
      {loading || error || !data ? (
        <section className="panel">
          <PageState loading={loading || (!data && !error)} error={error} retry={retry} />
        </section>
      ) : (
        <>
          <section className="panel nutrition-progress-toolbar">
            <div>
              <h2>
                {data.client.firstName} {data.client.lastName}
              </h2>
              <p className="muted">Kaynak: danışanın kendi beslenme kayıtları.</p>
            </div>
            <div>
              <label htmlFor="nutrition-progress-date">Gün</label>
              <input
                id="nutrition-progress-date"
                type="date"
                value={date}
                max={localDate()}
                onChange={(event) => setDate(event.target.value)}
              />
            </div>
            <Link className="button secondary" to={`/beslenme-hedefleri/${userId}`}>
              Beslenme hedefleri
            </Link>
          </section>
          {!dateValid ? (
            <p role="alert" className="field-error">
              Bugün veya daha önceki geçerli bir gün seçin.
            </p>
          ) : (
            <>
              <section
                className="panel nutrition-progress-section"
                aria-label="Günlük beslenme özeti"
              >
                <div className="panel-heading">
                  <div>
                    <h2>Günlük beslenme özeti</h2>
                    <p>
                      {records.length} kayıt · {date}
                    </p>
                  </div>
                </div>
                <div className="nutrition-progress-content">
                  {!records.length && (
                    <p className="muted">
                      Bu gün için beslenme kaydı yok. Gerçek tüketim bilinmediği için hedef farkı
                      hesaplanmaz.
                    </p>
                  )}
                  {!goal && (
                    <p className="muted">Seçili gün için geçerli aktif beslenme hedefi yok.</p>
                  )}
                  <div className="nutrition-progress-totals">
                    {nutritionMetrics.map(({ key, goalKey, label, unit }) => {
                      const difference =
                        goal && records.length
                          ? Math.round((goal[goalKey] - totals[key]) * 100) / 100
                          : null;
                      return (
                        <article key={key} aria-label={`${label} karşılaştırması`}>
                          <h3>{label}</h3>
                          <dl>
                            <div>
                              <dt>Kaydedilen toplam</dt>
                              <dd>
                                {records.length
                                  ? `${formatProgressValue(totals[key])} ${unit}`
                                  : '—'}
                              </dd>
                            </div>
                            <div>
                              <dt>Günlük hedef</dt>
                              <dd>
                                {goal ? `${formatProgressValue(goal[goalKey])} ${unit}` : '—'}
                              </dd>
                            </div>
                            <div>
                              <dt>
                                {difference !== null && difference < 0
                                  ? 'Hedef aşımı'
                                  : 'Hedefe kalan'}
                              </dt>
                              <dd>
                                {difference === null
                                  ? '—'
                                  : `${formatProgressValue(Math.abs(difference))} ${unit}`}
                              </dd>
                            </div>
                          </dl>
                        </article>
                      );
                    })}
                  </div>
                  <p className="muted">
                    Toplamlar tüm öğünleri içerir. Karşılaştırma yalnız seçili günde geçerli mevcut
                    aktif hedefle yapılır; geçmiş pasif hedefler kullanılmaz. Su tüketim kaydı
                    bulunmaz.
                  </p>
                </div>
              </section>
              <section
                className="panel nutrition-progress-section"
                aria-label="Günlük toplam grafiği"
              >
                <div className="panel-heading">
                  <div>
                    <h2>Günlük toplam grafiği</h2>
                    <p>
                      Seçili gün dahil önceki {period} gün ·{' '}
                      {points.filter((point) => point.value !== null).length} kayıtlı gün
                    </p>
                  </div>
                </div>
                <div className="nutrition-progress-content">
                  <div className="nutrition-progress-filters">
                    <div>
                      <label htmlFor="nutrition-progress-period">Grafik dönemi</label>
                      <select
                        id="nutrition-progress-period"
                        value={period}
                        onChange={(event) =>
                          setPeriod(Number(event.target.value) as NutritionPeriod)
                        }
                      >
                        <option value={7}>Son 7 gün</option>
                        <option value={30}>Son 30 gün</option>
                        <option value={90}>Son 90 gün</option>
                      </select>
                    </div>
                    <div>
                      <label htmlFor="nutrition-progress-metric">Grafik değeri</label>
                      <select
                        id="nutrition-progress-metric"
                        value={metricKey}
                        onChange={(event) => setMetricKey(event.target.value as NutritionMetric)}
                      >
                        {nutritionMetrics.map((item) => (
                          <option key={item.key} value={item.key}>
                            {item.label} ({item.unit})
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                  {points.some((point) => point.value !== null) ? (
                    <ProgressChart points={points} label={metric.label} unit={metric.unit} />
                  ) : (
                    <p className="muted">Bu dönemde beslenme kaydı yok.</p>
                  )}
                  <p className="muted">
                    Günler tarayıcının yerel saat dilimine göre gruplanır. Kayıtsız günler “—”
                    olarak kalır ve grafiği keser; sıfır tüketim sayılmaz. Girilmiş sıfır değeri
                    korunur.
                  </p>
                  <DailyTotals
                    key={`${userId}-${date}-${period}-${metricKey}`}
                    points={points}
                    label={metric.label}
                    unit={metric.unit}
                  />
                </div>
              </section>
              <section className="panel nutrition-progress-section" aria-label="Öğün kayıtları">
                <div className="panel-heading">
                  <div>
                    <h2>Öğün kayıtları</h2>
                    <p>Seçili günün kayıtları. Öğün filtresi günlük toplamları değiştirmez.</p>
                  </div>
                </div>
                <div className="nutrition-progress-content">
                  <label htmlFor="nutrition-progress-meal">Öğün filtresi</label>
                  <select
                    id="nutrition-progress-meal"
                    value={meal}
                    onChange={(event) => setMeal(event.target.value as MealType | 'all')}
                  >
                    <option value="all">Tüm öğünler</option>
                    {Object.entries(mealLabels).map(([key, label]) => (
                      <option key={key} value={key}>
                        {label}
                      </option>
                    ))}
                  </select>
                  <MealRecords
                    key={`${userId}-${date}-${meal}`}
                    records={records.filter((record) => meal === 'all' || record.mealType === meal)}
                  />
                </div>
              </section>
            </>
          )}
        </>
      )}
    </>
  );
}

function MealRecords({ records }: { records: NutritionRecordResponse[] }) {
  const [page, setPage] = useState(1);
  if (!records.length) return <p className="muted">Seçili gün ve öğün için kayıt yok.</p>;
  return (
    <>
      <p className="nutrition-meal-hint muted">
        Tüm kalori ve makro alanları için tabloyu yatay kaydırabilirsin.
      </p>
      <div className="table-scroll" role="region" aria-label="Öğün tablosu alanı" tabIndex={0}>
        <table className="nutrition-meal-table" aria-label="Öğün kayıt tablosu">
          <thead>
            <tr>
              <th scope="col">Zaman / Öğün</th>
              <th scope="col">Besin / Porsiyon</th>
              <th scope="col">Kalori (kcal)</th>
              <th scope="col">Protein (g)</th>
              <th scope="col">Karbonhidrat (g)</th>
              <th scope="col">Yağ (g)</th>
              <th scope="col">Kaynak</th>
            </tr>
          </thead>
          <tbody>
            {records.slice((page - 1) * 20, page * 20).map((record) => (
              <tr key={record.id}>
                <td>
                  {formatProgressTime(record.consumedAt)}
                  <br />
                  {mealLabels[record.mealType]}
                </td>
                <td>
                  {record.name}
                  {record.portionDescription && (
                    <p className="muted">{record.portionDescription}</p>
                  )}
                </td>
                {nutritionMetrics.map(({ key }) => (
                  <td key={key}>{formatProgressValue(record[key])}</td>
                ))}
                <td>{record.sourceType === 'AI' ? 'AI sonrası kaydedilen' : 'Manuel'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Pagination
        page={page}
        count={records.length}
        setPage={setPage}
        label="Öğün kayıt sayfaları"
      />
    </>
  );
}
function DailyTotals({
  points,
  label,
  unit,
}: {
  points: ProgressPoint[];
  label: string;
  unit: string;
}) {
  const [page, setPage] = useState(1);
  return (
    <details className="nutrition-progress-daily-table">
      <summary>Günlük toplamları tablo olarak gör</summary>
      <div className="table-scroll">
        <table aria-label="Günlük toplam tablosu">
          <thead>
            <tr>
              <th scope="col">Gün</th>
              <th scope="col">
                {label} ({unit})
              </th>
            </tr>
          </thead>
          <tbody>
            {points.slice((page - 1) * 20, page * 20).map((point) => (
              <tr key={point.id}>
                <td>
                  {new Date(point.recordedAt).toLocaleDateString('tr-TR', { dateStyle: 'medium' })}
                </td>
                <td>{point.value === null ? '—' : formatProgressValue(point.value)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Pagination
        page={page}
        count={points.length}
        setPage={setPage}
        label="Günlük toplam sayfaları"
      />
    </details>
  );
}
function Pagination({
  page,
  count,
  setPage,
  label,
}: {
  page: number;
  count: number;
  setPage: (value: number) => void;
  label: string;
}) {
  const pages = Math.ceil(count / 20);
  if (pages <= 1) return null;
  return (
    <nav className="progress-pagination" aria-label={label}>
      <button className="button secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>
        Önceki sayfa
      </button>
      <span>
        Sayfa {page} / {pages}
      </span>
      <button
        className="button secondary"
        disabled={page >= pages}
        onClick={() => setPage(page + 1)}
      >
        Sonraki sayfa
      </button>
    </nav>
  );
}

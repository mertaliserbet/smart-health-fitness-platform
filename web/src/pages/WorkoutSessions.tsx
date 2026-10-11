import { Link, useParams, useSearchParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { PageState } from '../components/PageState';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getWorkoutSession, getWorkoutSessions } from '../services/workoutSessionService';
import type { WorkoutLogResponse, WorkoutSessionStatus } from '../types/workoutSession';

const statusLabels: Record<WorkoutSessionStatus, string> = {
  InProgress: 'Devam ediyor',
  Completed: 'Tamamlandı',
  Cancelled: 'İptal edildi',
};
const time = (value: string) =>
  new Date(value).toLocaleString('tr-TR', { dateStyle: 'medium', timeStyle: 'short' });

export function WorkoutSessions() {
  const { userId = '' } = useParams();
  const { demo } = useAuth();
  const [search, setSearch] = useSearchParams();
  const requestedPage = Number(search.get('page') ?? 1);
  const page =
    Number.isInteger(requestedPage) && requestedPage >= 1 && requestedPage <= 1000000
      ? requestedPage
      : 1;
  const requestedStatus = search.get('status') ?? '';
  const status = Object.hasOwn(statusLabels, requestedStatus)
    ? (requestedStatus as WorkoutSessionStatus)
    : '';
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      if (demo) throw new Error('Antrenman geçmişi için gerçek Trainer hesabıyla giriş yapın.');
      const client = await requireClient(userId, 'Trainer', false, signal);
      return { client, history: await getWorkoutSessions(userId, page, status, signal) };
    },
    [userId, demo, page, status],
  );
  const changePage = (next: number) =>
    setSearch({ page: String(next), ...(status ? { status } : {}) });
  return (
    <>
      <Link className="back-link" to={`/danisanlar/${userId}`}>
        Danışana dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ANTRENMAN TAKİBİ</span>
          <h1>Antrenman geçmişi</h1>
          <p className="muted">Danışanının kaydettiği antrenmanlar ve egzersiz ilerlemesi.</p>
        </div>
      </div>
      <section className="panel workout-session-panel">
        <label htmlFor="session-status">Antrenman durumu</label>
        <select
          id="session-status"
          value={status}
          onChange={(event) => setSearch(event.target.value ? { status: event.target.value } : {})}
        >
          <option value="">Tüm durumlar</option>
          {Object.entries(statusLabels).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </section>
      {loading || error ? (
        <section className="panel workout-session-panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <section className="panel workout-session-panel">
            <div className="panel-heading">
              <h2>
                {data.client.firstName} {data.client.lastName}
              </h2>
              <span className="count-pill">{data.history.totalCount} antrenman</span>
            </div>
            {data.history.items.length === 0 && (
              <p className="muted">Bu seçimde antrenman kaydı yok.</p>
            )}
            {data.history.items.map((session) => (
              <article className="nutrition-form-section" key={session.id}>
                <h3>
                  <Link to={`/danisanlar/${userId}/antrenmanlar/${session.id}`}>
                    {session.planName} · {session.dayName}
                  </Link>
                </h3>
                <p>
                  {statusLabels[session.status]} · {session.completedExerciseCount} /{' '}
                  {session.totalExerciseCount} egzersiz tamamlandı
                </p>
                <p className="muted">
                  Başlangıç: {time(session.startedAt)}
                  {session.completedAt && ` · Bitiş: ${time(session.completedAt)}`}
                </p>
              </article>
            ))}
            <div className="row-actions">
              <button
                className="button secondary"
                disabled={page <= 1}
                onClick={() => changePage(page - 1)}
              >
                Önceki sayfa
              </button>
              <span>
                Sayfa {page} / {Math.max(1, data.history.totalPages)}
              </span>
              <button
                className="button secondary"
                disabled={page >= data.history.totalPages}
                onClick={() => changePage(page + 1)}
              >
                Sonraki sayfa
              </button>
            </div>
          </section>
        )
      )}
    </>
  );
}

export function WorkoutSessionDetail() {
  const { userId = '', sessionId = '' } = useParams();
  const { demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      if (demo) throw new Error('Antrenman geçmişi için gerçek Trainer hesabıyla giriş yapın.');
      await requireClient(userId, 'Trainer', false, signal);
      return getWorkoutSession(sessionId, userId, signal);
    },
    [userId, sessionId, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/danisanlar/${userId}/antrenmanlar`}>
        Antrenman geçmişine dön
      </Link>
      {loading || error ? (
        <section className="panel workout-session-panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <>
            <div className="page-heading">
              <div>
                <span className="eyebrow">{data.planName}</span>
                <h1>{data.day.name}</h1>
                <p>
                  {statusLabels[data.status]} · {data.logs.filter((log) => log.isCompleted).length}{' '}
                  / {data.day.exercises.length} egzersiz tamamlandı
                </p>
              </div>
            </div>
            <section className="panel workout-session-panel">
              <p>Başlangıç: {time(data.startedAt)}</p>
              {data.completedAt && <p>Bitiş: {time(data.completedAt)}</p>}
              <p className="muted">
                Tamamlandı durumu oturumun bittiğini gösterir. Yapılmayan egzersizler aşağıda ayrıca
                belirtilir.
              </p>
            </section>
            {data.day.exercises.map((item) => {
              const log = data.logs.find((value) => value.workoutExerciseId === item.id);
              return (
                <section className="panel workout-session-panel" key={item.id}>
                  <h2>
                    {item.order}. {item.exerciseName}
                  </h2>
                  <p>
                    Hedef:{' '}
                    {item.durationSeconds != null
                      ? `${item.durationSeconds} saniye`
                      : `${item.sets} set × ${item.reps} tekrar`}
                    {item.weightKg != null && ` · ${item.weightKg} kg`}
                  </p>
                  <p>Gerçekleşen: {log ? actual(log) : 'Kaydedilmedi'}</p>
                  <p>
                    {!log
                      ? 'Kayıt yok'
                      : log.isCompleted
                        ? 'Egzersiz tamamlandı'
                        : 'Egzersiz tamamlanmadı'}
                  </p>
                  {item.notes && <p className="muted">Trainer notu: {item.notes}</p>}
                  {log?.notes && (
                    <p style={{ whiteSpace: 'pre-wrap' }}>Danışan notu: {log.notes}</p>
                  )}
                </section>
              );
            })}
          </>
        )
      )}
    </>
  );
}

function actual(log: WorkoutLogResponse) {
  const value =
    log.durationSeconds != null
      ? `${log.durationSeconds} saniye`
      : log.completedSets != null || log.completedReps != null
        ? `${log.completedSets ?? '—'} set × ${log.completedReps ?? '—'} tekrar`
        : 'Değer girilmedi';
  return value + (log.weightKg != null ? ` · ${log.weightKg} kg` : '');
}

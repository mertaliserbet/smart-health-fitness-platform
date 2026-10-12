import { useState } from 'react';
import { Link } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import {
  getTrainerWorkoutSummary,
  workoutPlanAvailability,
} from '../services/trainerWorkoutSummaryService';
import type { ClientSummary } from '../types/api';
import type { WorkoutSessionStatus } from '../types/workoutSession';
import { PageState } from './PageState';
import { formatDate } from './PeopleTable';
import './TrainerWorkoutSummary.css';

const statusLabels: Record<WorkoutSessionStatus, string> = {
  InProgress: 'Devam ediyor',
  Completed: 'Tamamlandı',
  Cancelled: 'İptal edildi',
};
const time = (value: string) =>
  new Date(value).toLocaleString('tr-TR', { dateStyle: 'medium', timeStyle: 'short' });

export function TrainerWorkoutSummary({ clients }: { clients: ClientSummary[] }) {
  const { role, demo } = useAuth();
  const [userId, setUserId] = useState('');
  if (role !== 'Trainer') return null;
  const eligible = clients.filter((client) => client.relationshipStatus === 'Active');
  const selected = eligible.find((client) => client.id === userId);
  return (
    <section className="panel trainer-workout-summary" aria-label="Danışanın antrenman özeti">
      <div className="panel-heading">
        <div>
          <h2>Danışanın antrenman özeti</h2>
          <p>Program ve son antrenmanlardan devam et.</p>
        </div>
      </div>
      <div className="trainer-workout-summary-content">
        {demo ? (
          <p className="muted">
            Antrenman özeti için gerçek Trainer hesabıyla giriş yapın. Örnek panelde gerçek
            antrenman sayıları gösterilmez.
          </p>
        ) : eligible.length === 0 ? (
          <p className="muted">Özet için aktif bağlı danışan gerekli.</p>
        ) : (
          <>
            <label htmlFor="trainer-summary-client">Antrenman özeti danışanı</label>
            <select
              id="trainer-summary-client"
              value={selected?.id ?? ''}
              onChange={(event) => setUserId(event.target.value)}
            >
              <option value="">Danışan seç</option>
              {eligible.map((client) => (
                <option key={client.id} value={client.id}>
                  {client.firstName} {client.lastName}
                </option>
              ))}
            </select>
            {selected ? (
              <SelectedWorkoutSummary key={selected.id} client={selected} />
            ) : (
              <p className="muted">Program ve antrenman kayıtlarını görmek için danışan seç.</p>
            )}
          </>
        )}
      </div>
    </section>
  );
}

function SelectedWorkoutSummary({ client }: { client: ClientSummary }) {
  const {
    data: loaded,
    loading,
    error,
    retry,
  } = useLoad((signal) => getTrainerWorkoutSummary(client.id, signal), [client.id]);
  const data = loaded?.userId === client.id ? loaded : null;
  if (loading || error || !data)
    return <PageState loading={loading || (!data && !error)} error={error} retry={retry} />;
  const clientPath = encodeURIComponent(client.id);
  const active = data.plans.find((plan) => plan.isActive);
  const recent = data.history.items.slice(0, 5);
  return (
    <>
      <div className="trainer-summary-actions">
        <Link className="button secondary" to={`/danisanlar/${clientPath}`}>
          Danışan profili
        </Link>
        <Link className="button secondary" to={`/programlar/${clientPath}`}>
          Programlar
        </Link>
        <Link className="button secondary" to={`/danisanlar/${clientPath}/antrenmanlar`}>
          Antrenman geçmişi
        </Link>
        <button className="button secondary" onClick={retry}>
          Özeti yenile
        </button>
      </div>
      <dl className="trainer-summary-metrics">
        <div>
          <dt>Program atamaları</dt>
          <dd>{data.plans.length}</dd>
          <p className="muted">Aktif ve geçmiş programlar.</p>
        </div>
        <div>
          <dt>Toplam antrenman oturumu</dt>
          <dd>{data.history.totalCount}</dd>
          <p className="muted">Danışanın tüm antrenman geçmişi.</p>
        </div>
      </dl>
      <article className="trainer-summary-plan" aria-label="Aktif program özeti">
        <h3>Aktif program</h3>
        {active ? (
          <>
            <Link
              className="trainer-summary-title"
              to={`/programlar/${clientPath}/${encodeURIComponent(active.id)}`}
            >
              {active.name}
            </Link>
            <p>
              {workoutPlanAvailability(active)} · {formatDate(active.startDate)} –{' '}
              {active.endDate ? formatDate(active.endDate) : 'Bitiş belirtilmedi'}
            </p>
            <p className="muted">Program tarih kontrolü UTC takvim gününü kullanır.</p>
          </>
        ) : (
          <>
            <p className="muted">Danışanın aktif programı yok.</p>
            <Link className="text-link" to={`/programlar/${clientPath}/yeni`}>
              Yeni program ata
            </Link>
          </>
        )}
      </article>
      <div className="trainer-summary-history">
        <h3>Son antrenmanlar</h3>
        <p className="muted">
          Son {recent.length} oturum gösteriliyor; tamamlanmış oturumda bazı egzersizler kayıtsız
          olabilir.
        </p>
        {recent.length === 0 ? (
          <p className="muted">Henüz antrenman oturumu kaydı yok.</p>
        ) : (
          <ul>
            {recent.map((session) => (
              <li key={session.id}>
                <div>
                  <Link
                    className="trainer-summary-title"
                    to={`/danisanlar/${clientPath}/antrenmanlar/${encodeURIComponent(session.id)}`}
                  >
                    {session.planName} / {session.dayName}
                  </Link>
                  <p className="muted">{time(session.startedAt)}</p>
                </div>
                <div>
                  <span className={`trainer-session-status ${session.status}`}>
                    {statusLabels[session.status]}
                  </span>
                  <p>
                    {session.completedExerciseCount} / {session.totalExerciseCount} egzersiz
                    tamamlandı
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </>
  );
}

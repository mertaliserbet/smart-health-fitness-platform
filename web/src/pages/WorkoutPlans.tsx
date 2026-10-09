import { CalendarDays, ChevronRight, Dumbbell, Plus, UserRound } from 'lucide-react';
import { Link, useLocation, useNavigate, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { getClients } from '../services/clientService';
import { getWorkoutPlans } from '../services/workoutService';
import { PageState } from '../components/PageState';
import { formatDate } from '../components/PeopleTable';

export function WorkoutPlans() {
  const { userId } = useParams();
  const { demo } = useAuth();
  const navigate = useNavigate();
  const { state } = useLocation();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const clients = (await getClients('Trainer', demo, signal)).filter(
        (client) => client.relationshipStatus === 'Active',
      );
      const client = clients.find((value) => value.id === userId);
      if (userId && !client) throw new Error('Bu danışana erişiminiz bulunmuyor.');
      const plans = client ? await getWorkoutPlans(client.id, demo, signal) : [];
      return { clients, client, plans };
    },
    [userId, demo],
  );
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ANTRENÖR ÇALIŞMA ALANI</span>
          <h1>Antrenman programları</h1>
          <p className="muted">Danışanını seç, haftasını planla ve programını ata.</p>
        </div>
        {data?.client && (
          <Link className="button primary" to={`/programlar/${userId}/yeni`}>
            <Plus size={17} aria-hidden="true" />
            Yeni program
          </Link>
        )}
      </div>
      {state?.programAssigned && (
        <div className="success-notice" role="status">
          {demo
            ? 'Örnek program atandı. Bu işlem sunucuya veya mobil uygulamaya veri kaydetmedi.'
            : 'Program danışana atandı.'}
        </div>
      )}
      <section className="panel client-picker-panel">
        {loading || error ? (
          <PageState loading={loading} error={error} retry={retry} />
        ) : data?.clients.length ? (
          <>
            <div className="section-intro">
              <UserRound size={23} aria-hidden="true" />
              <div>
                <h2>Kiminle çalışıyoruz?</h2>
                <p className="muted">
                  Yalnız aktif danışanlarının programlarını görüntüleyebilirsin.
                </p>
              </div>
            </div>
            <label htmlFor="plan-client">Danışan</label>
            <select
              id="plan-client"
              value={userId ?? ''}
              onChange={(event) =>
                void navigate(
                  event.target.value ? `/programlar/${event.target.value}` : '/programlar',
                )
              }
            >
              <option value="">Danışan seç</option>
              {data.clients.map((client) => (
                <option key={client.id} value={client.id}>
                  {client.firstName} {client.lastName}
                </option>
              ))}
            </select>
          </>
        ) : (
          <PageState empty="Bağlı danışan yok" />
        )}
      </section>
      {!loading && !error && data?.client && (
        <section className="panel workout-list-panel">
          <div className="panel-heading">
            <div>
              <h2>
                {data.client.firstName} {data.client.lastName}
              </h2>
              <p className="muted">Aktif program ve geçmiş atamalar.</p>
            </div>
            <span className="count-pill">{data.plans.length} program</span>
          </div>
          {data.plans.length ? (
            <div className="plan-list">
              {[...data.plans]
                .sort(
                  (a, b) =>
                    Number(b.isActive) - Number(a.isActive) ||
                    b.startDate.localeCompare(a.startDate),
                )
                .map((plan) => (
                  <Link className="plan-card" key={plan.id} to={`/programlar/${userId}/${plan.id}`}>
                    <span className="plan-icon">
                      <Dumbbell size={22} aria-hidden="true" />
                    </span>
                    <div>
                      <span className={`plan-status ${plan.isActive ? 'active' : ''}`}>
                        {plan.isActive ? 'Aktif program' : 'Geçmiş program'}
                      </span>
                      <h3>{plan.name}</h3>
                      <p className="muted">
                        <CalendarDays size={14} aria-hidden="true" />
                        {formatDate(plan.startDate)} –{' '}
                        {plan.endDate ? formatDate(plan.endDate) : 'Bitiş belirtilmedi'}
                      </p>
                    </div>
                    <ChevronRight size={19} aria-hidden="true" />
                  </Link>
                ))}
            </div>
          ) : (
            <div className="page-state">
              <Dumbbell size={30} aria-hidden="true" />
              <h3>Henüz program atanmadı</h3>
              <p>İlk programı gün ve egzersizleriyle birlikte hazırlayabilirsin.</p>
              <Link className="button primary" to={`/programlar/${userId}/yeni`}>
                İlk programı oluştur
              </Link>
            </div>
          )}
        </section>
      )}
      {!userId && !loading && !error && !!data?.clients.length && (
        <div className="workout-intro">
          <Dumbbell size={34} aria-hidden="true" />
          <h2>Her hafta için net bir plan.</h2>
          <p className="muted">
            Danışan seçtiğinde mevcut programları burada göreceksin. Yeni programda antrenman
            günlerini ve her egzersizin hedefini belirleyebilirsin.
          </p>
          <div className="workflow-steps">
            <span>01 · Danışanını seç</span>
            <span>02 · Günleri planla</span>
            <span>03 · Programı ata</span>
          </div>
        </div>
      )}
    </>
  );
}

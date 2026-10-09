import { CalendarDays, Droplets, Leaf, Plus, UserRound } from 'lucide-react';
import { Link, useLocation, useNavigate, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { PageState } from '../components/PageState';
import { formatDate } from '../components/PeopleTable';
import { useLoad } from '../hooks/useLoad';
import { getClients } from '../services/clientService';
import { getNutritionGoals } from '../services/nutritionService';
import { formatNutritionValue, nutritionFields, nutritionGoalStatus } from '../utils/nutritionGoal';

export function NutritionGoals() {
  const { userId } = useParams();
  const { demo } = useAuth();
  const navigate = useNavigate();
  const { state } = useLocation();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const clients = (await getClients('Dietitian', demo, signal)).filter(
        (client) => client.relationshipStatus === 'Active',
      );
      const client = clients.find((value) => value.id === userId);
      if (userId && !client) throw new Error('Bu danışana erişiminiz bulunmuyor.');
      const goals = client ? await getNutritionGoals(client.id, demo, signal) : [];
      return { clients, client, goals };
    },
    [userId, demo],
  );

  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">DİYETİSYEN ÇALIŞMA ALANI</span>
          <h1>Beslenme hedefleri</h1>
          <p className="muted">Danışanının günlük hedeflerini belirle, geçmiş atamalarını gör.</p>
        </div>
        {data?.client && !loading && !error && (
          <Link className="button primary" to={`/beslenme-hedefleri/${userId}/yeni`}>
            <Plus size={17} aria-hidden="true" /> Yeni hedef
          </Link>
        )}
      </div>
      {state?.goalAssigned && (
        <div className="success-notice" role="status">
          {demo
            ? 'Örnek hedef atandı. Bu işlem sunucuya veya mobil uygulamaya veri kaydetmedi.'
            : 'Beslenme hedefi danışana atandı.'}
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
                  Yalnız aktif danışanlarının beslenme hedeflerine erişebilirsin.
                </p>
              </div>
            </div>
            <label htmlFor="nutrition-client">Danışan</label>
            <select
              id="nutrition-client"
              value={userId ?? ''}
              onChange={(event) =>
                void navigate(
                  event.target.value
                    ? `/beslenme-hedefleri/${event.target.value}`
                    : '/beslenme-hedefleri',
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
        <section className="panel nutrition-list-panel">
          <div className="panel-heading">
            <div>
              <h2>
                {data.client.firstName} {data.client.lastName}
              </h2>
              <p className="muted">Günlük hedefler ve geçmiş atamalar.</p>
            </div>
            <span className="count-pill">{data.goals.length} hedef</span>
          </div>
          {data.goals.length ? (
            <div className="nutrition-goal-list">
              {[...data.goals]
                .sort(
                  (a, b) =>
                    Number(b.isActive) - Number(a.isActive) ||
                    b.startDate.localeCompare(a.startDate),
                )
                .map((goal) => {
                  const status = nutritionGoalStatus(goal);
                  return (
                    <article
                      key={goal.id}
                      className={`nutrition-goal-card ${goal.isActive ? 'is-active' : ''}`}
                    >
                      <div className="nutrition-goal-heading">
                        <span className="plan-icon">
                          <Leaf size={22} aria-hidden="true" />
                        </span>
                        <div>
                          <span className={`plan-status nutrition-status ${status.kind}`}>
                            {status.label}
                          </span>
                          <h3>
                            {formatNutritionValue(goal.dailyCalories)} <span>kcal / gün</span>
                          </h3>
                        </div>
                        <p className="nutrition-date muted">
                          <CalendarDays size={15} aria-hidden="true" />
                          {formatDate(goal.startDate)} –{' '}
                          {goal.endDate ? formatDate(goal.endDate) : 'Bitiş belirtilmedi'}
                        </p>
                      </div>
                      <dl className="nutrition-metrics">
                        {nutritionFields
                          .filter(({ key }) => key !== 'dailyCalories')
                          .map(({ key, label, unit }) => (
                            <div key={key}>
                              <dt>
                                {key === 'waterMl' && <Droplets size={13} aria-hidden="true" />}
                                {label}
                              </dt>
                              <dd>
                                {formatNutritionValue(goal[key])} <span>{unit}</span>
                              </dd>
                            </div>
                          ))}
                      </dl>
                      {status.kind === 'scheduled' && (
                        <p className="nutrition-validity">
                          Bu hedef başlangıç tarihinde geçerli olacak. Önceki hedef otomatik olarak
                          yeniden aktifleşmez.
                        </p>
                      )}
                      {status.kind === 'expired' && (
                        <p className="nutrition-validity">
                          Tarih aralığı sona erdi. Bugün için geçerli bir hedef atanması gerekiyor;
                          önceki hedef otomatik olarak yeniden aktifleşmez.
                        </p>
                      )}
                    </article>
                  );
                })}
              <p className="nutrition-water-note muted">
                Su miktarı günlük hedeftir. Su tüketim kaydı bu ekranda takip edilmez.
              </p>
            </div>
          ) : (
            <PageState empty="Henüz beslenme hedefi yok" />
          )}
          <div className="nutrition-profile-link">
            <Link to={`/danisanlar/${userId}`}>Danışan profiline dön</Link>
          </div>
        </section>
      )}
      {!loading && !error && data?.clients.length && !data.client ? (
        <section className="panel nutrition-intro">
          <Leaf size={36} aria-hidden="true" />
          <h2>Günlük hedeflere birlikte yön ver.</h2>
          <p className="muted">
            Yukarıdan danışanını seç. Kalori, makro ve su hedeflerini tarih aralığıyla atayabilir,
            önceki hedeflerini görüntüleyebilirsin.
          </p>
          <div className="workflow-steps">
            <span>01 · Danışanı seç</span>
            <span>02 · Hedefleri belirle</span>
            <span>03 · Danışanına ata</span>
          </div>
        </section>
      ) : null}
    </>
  );
}

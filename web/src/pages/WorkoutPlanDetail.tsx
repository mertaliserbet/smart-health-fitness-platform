import { ArrowLeft, CalendarDays, Dumbbell, Plus } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getWorkoutPlan } from '../services/workoutService';
import { PageState } from '../components/PageState';
import { formatDate } from '../components/PeopleTable';
import { weekdayLabel } from '../utils/workoutPlan';

export function WorkoutPlanDetail() {
  const { userId = '', workoutPlanId = '' } = useParams();
  const { demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const client = await requireClient(userId, 'Trainer', demo, signal);
      const plan = await getWorkoutPlan(workoutPlanId, demo, signal);
      if (plan.userId !== client.id) throw new Error('Bu program seçili danışana ait değil.');
      return { client, plan };
    },
    [userId, workoutPlanId, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/programlar/${userId}`}>
        <ArrowLeft size={17} aria-hidden="true" />
        Programlara dön
      </Link>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <>
            <div className="page-heading">
              <div>
                <span className="eyebrow">
                  {data.client.firstName} {data.client.lastName}
                </span>
                <h1>{data.plan.name}</h1>
                <p className="muted">Haftalık antrenman günleri ve egzersiz hedefleri.</p>
              </div>
              <Link className="button secondary" to={`/programlar/${userId}/yeni`}>
                <Plus size={17} aria-hidden="true" />
                Yeni program
              </Link>
            </div>
            <section className="panel plan-overview">
              <span className={`plan-status ${data.plan.isActive ? 'active' : ''}`}>
                {data.plan.isActive ? 'Aktif program' : 'Geçmiş program'}
              </span>
              <p>{data.plan.description || 'Program açıklaması eklenmemiş.'}</p>
              <p className="muted">
                <CalendarDays size={16} aria-hidden="true" />
                {formatDate(data.plan.startDate)} –{' '}
                {data.plan.endDate ? formatDate(data.plan.endDate) : 'Bitiş belirtilmedi'}
              </p>
            </section>
            <div className="workout-day-list">
              {[...data.plan.days]
                .sort((a, b) => a.dayNumber - b.dayNumber)
                .map((day) => (
                  <section className="panel workout-day-detail" key={day.id}>
                    <div className="panel-heading">
                      <div>
                        <span className="eyebrow">{weekdayLabel(day.weekday)}</span>
                        <h2>
                          {day.dayNumber}. gün · {day.name}
                        </h2>
                        {day.description && <p className="muted">{day.description}</p>}
                      </div>
                      <span className="count-pill">{day.exercises.length} egzersiz</span>
                    </div>
                    <ol className="prescription-list">
                      {[...day.exercises]
                        .sort((a, b) => a.order - b.order)
                        .map((exercise) => (
                          <li key={exercise.id}>
                            <span className="exercise-number">{exercise.order}</span>
                            <div>
                              <h3>{exercise.exerciseName}</h3>
                              <p className="muted">
                                {exercise.sets != null && exercise.reps != null
                                  ? `${exercise.sets} set × ${exercise.reps} tekrar`
                                  : exercise.durationSeconds != null
                                    ? `${exercise.durationSeconds} saniye`
                                    : 'Hedef belirtilmedi'}
                                {exercise.restSeconds != null &&
                                  ` · ${exercise.restSeconds} sn dinlenme`}
                                {exercise.weightKg != null && ` · ${exercise.weightKg} kg`}
                              </p>
                              {exercise.notes && <p className="exercise-note">{exercise.notes}</p>}
                            </div>
                            <Dumbbell size={19} aria-hidden="true" />
                          </li>
                        ))}
                    </ol>
                  </section>
                ))}
            </div>
          </>
        )
      )}
    </>
  );
}

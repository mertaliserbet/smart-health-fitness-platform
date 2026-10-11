import { ArrowLeft } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getExercises, getWorkoutPlan } from '../services/workoutService';
import { PageState } from '../components/PageState';
import { WorkoutPlanForm } from '../components/WorkoutPlanForm';

export function WorkoutPlanEdit() {
  const { userId = '', workoutPlanId = '' } = useParams();
  const { demo, user } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const client = await requireClient(userId, 'Trainer', demo, signal);
      const plan = await getWorkoutPlan(workoutPlanId, demo, signal);
      if (plan.userId !== client.id) throw new Error('Bu program seçili danışana ait değil.');
      if (!plan.isActive) throw new Error('Geçmiş program düzenlenemez. Yeni bir program ata.');
      if (plan.hasSessions)
        throw new Error(
          'Bu programla antrenman başlatılmış. Geçmişi korumak için yeni bir program ata.',
        );
      if (plan.trainerId !== user?.id)
        throw new Error('Yalnızca oluşturduğun programı düzenleyebilirsin.');
      if (
        !Object.hasOwn(plan, 'updatedAt') ||
        (plan.updatedAt !== null &&
          (typeof plan.updatedAt !== 'string' || !Number.isFinite(Date.parse(plan.updatedAt))))
      )
        throw new Error(
          'Programın güncel sürümü alınamadı. API güncellendikten sonra tekrar dene.',
        );
      const exercises = await getExercises(demo, signal);
      return { client, plan, exercises };
    },
    [userId, workoutPlanId, demo, user?.id],
  );
  return (
    <>
      <Link className="back-link" to={`/programlar/${userId}/${workoutPlanId}`}>
        <ArrowLeft size={17} aria-hidden="true" /> Programa dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">AKTİF PROGRAM</span>
          <h1>Antrenman programını düzenle</h1>
          <p className="muted">
            Günleri ve egzersiz hedeflerini danışanının ihtiyacına göre güncelle.
          </p>
        </div>
      </div>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
          {error && (
            <Link className="button secondary" to={`/programlar/${userId}/yeni`}>
              Yeni program ata
            </Link>
          )}
        </section>
      ) : (
        data && (
          <WorkoutPlanForm
            key={`${workoutPlanId}-${data.plan.updatedAt}-${demo}`}
            client={data.client}
            exercises={data.exercises}
            demo={demo}
            plan={data.plan}
          />
        )
      )}
    </>
  );
}

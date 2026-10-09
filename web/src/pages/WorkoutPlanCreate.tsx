import { ArrowLeft } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { requireTrainerClient } from '../services/clientService';
import { getExercises } from '../services/workoutService';
import { PageState } from '../components/PageState';
import { WorkoutPlanForm } from '../components/WorkoutPlanForm';

export function WorkoutPlanCreate() {
  const { userId = '' } = useParams();
  const { demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const client = await requireTrainerClient(userId, demo, signal);
      const exercises = await getExercises(demo, signal);
      return { client, exercises };
    },
    [userId, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/programlar/${userId}`}>
        <ArrowLeft size={17} aria-hidden="true" />
        Programlara dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">HAFTAYI BİRLİKTE PLANLAYALIM</span>
          <h1>Yeni antrenman programı</h1>
          <p className="muted">Günleri ve egzersiz hedeflerini hazırlayıp danışanına ata.</p>
        </div>
      </div>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data &&
        (data.exercises.length ? (
          <WorkoutPlanForm
            key={`${userId}-${demo}`}
            client={data.client}
            exercises={data.exercises}
            demo={demo}
          />
        ) : (
          <section className="panel">
            <PageState empty="Katalogda egzersiz yok" />
            <p className="catalog-help muted">
              Program atayabilmek için yönetici tarafından egzersiz eklenmesi gerekiyor.
            </p>
          </section>
        ))
      )}
    </>
  );
}

import { ArrowLeft } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { ExerciseForm } from '../components/ExerciseForm';
import { PageState } from '../components/PageState';
import { useLoad } from '../hooks/useLoad';
import { getExercise } from '../services/exerciseService';

export function ExerciseEdit() {
  const { exerciseId } = useParams();
  const { demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => ({
      exercise: !demo && exerciseId ? await getExercise(exerciseId, signal) : null,
    }),
    [exerciseId, demo],
  );
  return (
    <>
      <Link className="back-link" to="/egzersizler">
        <ArrowLeft size={17} aria-hidden="true" /> Kataloğa dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">EGZERSİZ YÖNETİMİ</span>
          <h1>{exerciseId ? 'Egzersizi düzenle' : 'Yeni egzersiz'}</h1>
          <p className="muted">Hareketin bilgilerini ve katalogda kullanılabilirliğini belirle.</p>
        </div>
      </div>
      {demo ? (
        <section className="panel exercise-form-panel">
          <p>Egzersiz yönetimi için yönetici hesabınla giriş yap.</p>
        </section>
      ) : loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data &&
        (!exerciseId || data.exercise?.id === exerciseId) && (
          <ExerciseForm key={exerciseId ?? 'new'} exercise={data.exercise ?? undefined} />
        )
      )}
    </>
  );
}

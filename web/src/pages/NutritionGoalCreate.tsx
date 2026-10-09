import { ArrowLeft } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { NutritionGoalForm } from '../components/NutritionGoalForm';
import { PageState } from '../components/PageState';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { getNutritionGoals } from '../services/nutritionService';

export function NutritionGoalCreate() {
  const { userId = '' } = useParams();
  const { demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const client = await requireClient(userId, 'Dietitian', demo, signal);
      const goals = await getNutritionGoals(userId, demo, signal);
      return { client, activeGoal: goals.find((goal) => goal.isActive) };
    },
    [userId, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/beslenme-hedefleri/${userId}`}>
        <ArrowLeft size={17} aria-hidden="true" /> Hedeflere dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">GÜNLÜK HEDEFLERİ BELİRLEYELİM</span>
          <h1>Yeni beslenme hedefi</h1>
          <p className="muted">Kalori, makro ve su hedeflerini geçerli olacağı tarihlerle ata.</p>
        </div>
      </div>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <NutritionGoalForm
            key={`${userId}-${demo}`}
            client={data.client}
            activeGoal={data.activeGoal}
            demo={demo}
          />
        )
      )}
    </>
  );
}

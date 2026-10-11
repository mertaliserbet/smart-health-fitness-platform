import { useState } from 'react';
import { Dumbbell, Pencil, Plus, Search } from 'lucide-react';
import { Link, useLocation } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { getExercises } from '../services/workoutService';
import { getManagedExercises } from '../services/exerciseService';
import { PageState } from '../components/PageState';

export function ExerciseCatalog() {
  const { demo, role } = useAuth();
  const admin = role === 'Admin';
  const { state } = useLocation();
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const { data, loading, error, retry } = useLoad(
    async (signal) =>
      admin
        ? getManagedExercises(demo, signal)
        : (await getExercises(demo, signal)).map((exercise) => ({ ...exercise, isActive: true })),
    [demo, admin],
  );
  const filtered =
    data?.filter(
      (exercise) =>
        exercise.name
          .toLocaleLowerCase('tr-TR')
          .includes(search.trim().toLocaleLowerCase('tr-TR')) &&
        (!admin || status === 'all' || exercise.isActive === (status === 'active')),
    ) ?? [];
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">EGZERSİZ KATALOĞU</span>
          <h1>Egzersizler</h1>
          <p className="muted">
            {admin
              ? 'Kataloğu düzenle, egzersiz ekle ve kullanım durumunu yönet.'
              : 'Programlarında kullanabileceğin egzersizleri incele.'}
          </p>
        </div>
        {admin ? (
          !demo && (
            <Link className="button primary" to="/egzersizler/yeni">
              <Plus size={17} aria-hidden="true" /> Yeni egzersiz
            </Link>
          )
        ) : (
          <Link className="button primary" to="/programlar">
            Programlara git
          </Link>
        )}
      </div>
      {admin && state?.exerciseSaved && (
        <div className="success-notice" role="status">
          Egzersiz kaydedildi.
        </div>
      )}
      {admin && demo && (
        <p className="success-notice">
          Önizlemede katalog yalnız görüntülenir. Egzersiz yönetimi için yönetici hesabınla giriş
          yap.
        </p>
      )}
      <section className="panel">
        <div className="list-toolbar exercise-toolbar">
          <h2>Katalog</h2>
          {admin && (
            <div className="exercise-status-filter">
              <label htmlFor="exercise-status">Durum</label>
              <select
                id="exercise-status"
                value={status}
                onChange={(event) => setStatus(event.target.value)}
              >
                <option value="all">Tümü</option>
                <option value="active">Aktif</option>
                <option value="inactive">Pasif</option>
              </select>
            </div>
          )}
          <div className="search-field">
            <Search size={17} aria-hidden="true" />
            <input
              aria-label="Egzersizleri isimle ara"
              placeholder="Egzersiz ara…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>
        </div>
        {loading || error ? (
          <PageState loading={loading} error={error} retry={retry} />
        ) : filtered.length ? (
          <div className="exercise-catalog">
            {filtered.map((exercise) => (
              <article className="catalog-card" key={exercise.id}>
                <div className="catalog-card-top">
                  <span className="plan-icon">
                    <Dumbbell size={23} aria-hidden="true" />
                  </span>
                  {admin && (
                    <span className={`plan-status ${exercise.isActive ? 'active' : ''}`}>
                      {exercise.isActive ? 'Aktif' : 'Pasif'}
                    </span>
                  )}
                </div>
                <h3>{exercise.name}</h3>
                <p className="muted">{exercise.description || 'Açıklama eklenmemiş.'}</p>
                {admin && !demo && (
                  <Link
                    className="button secondary"
                    aria-label={`${exercise.name} egzersizini düzenle`}
                    to={`/egzersizler/${exercise.id}/duzenle`}
                  >
                    <Pencil size={15} aria-hidden="true" /> Düzenle
                  </Link>
                )}
              </article>
            ))}
          </div>
        ) : (
          <PageState
            empty={
              search || status !== 'all'
                ? 'Filtrelerle eşleşen egzersiz yok'
                : 'Katalogda egzersiz yok'
            }
          />
        )}
      </section>
    </>
  );
}

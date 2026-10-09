import { useState } from 'react';
import { Dumbbell, Search } from 'lucide-react';
import { Link } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { getExercises } from '../services/workoutService';
import { PageState } from '../components/PageState';

export function ExerciseCatalog() {
  const { demo } = useAuth();
  const [search, setSearch] = useState('');
  const { data, loading, error, retry } = useLoad((signal) => getExercises(demo, signal), [demo]);
  const filtered =
    data?.filter((exercise) =>
      exercise.name.toLocaleLowerCase('tr-TR').includes(search.trim().toLocaleLowerCase('tr-TR')),
    ) ?? [];
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">EGZERSİZ KATALOĞU</span>
          <h1>Egzersizler</h1>
          <p className="muted">Programlarında kullanabileceğin egzersizleri incele.</p>
        </div>
        <Link className="button primary" to="/programlar">
          Programlara git
        </Link>
      </div>
      <section className="panel">
        <div className="list-toolbar">
          <h2>Katalog</h2>
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
                <span className="plan-icon">
                  <Dumbbell size={23} aria-hidden="true" />
                </span>
                <h3>{exercise.name}</h3>
                <p className="muted">{exercise.description || 'Açıklama eklenmemiş.'}</p>
              </article>
            ))}
          </div>
        ) : (
          <PageState empty={search ? 'Aramanla eşleşen egzersiz yok' : 'Katalogda egzersiz yok'} />
        )}
      </section>
    </>
  );
}

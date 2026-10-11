import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { PageState } from '../components/PageState';
import { formatDate } from '../components/PeopleTable';
import { useLoad } from '../hooks/useLoad';
import { requireClient } from '../services/clientService';
import { createNote, createTask, getNotes, getTasks, taskLabels } from '../services/advisorService';
import { ApiError } from '../services/apiClient';

export function ClientAssignments() {
  const { userId = '' } = useParams();
  const { role, demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      if (demo) throw new Error('Görev ve not atamak için gerçek danışman hesabıyla giriş yapın.');
      if (role !== 'Trainer' && role !== 'Dietitian') throw new Error('Danışman rolü gerekli.');
      const client = await requireClient(userId, role, false, signal);
      const [tasks, notes] = await Promise.all([
        getTasks(userId, signal),
        getNotes(userId, signal),
      ]);
      return { client, tasks, notes };
    },
    [userId, role, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/danisanlar/${userId}`}>
        Danışana dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">DANIŞAN PLANI</span>
          <h1>Görevler / Notlar</h1>
          <p className="muted">Görev ve notlar danışanın mobil Planım ekranında görünür.</p>
        </div>
      </div>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && (
          <>
            <section className="panel">
              <h2>
                {data.client.firstName} {data.client.lastName}
              </h2>
              <AssignmentForm key={`${userId}-${role}`} userId={userId} onSaved={retry} />
            </section>
            <section className="panel">
              <h2>Atanmış görevler</h2>
              {data.tasks.length === 0 && <p className="muted">Henüz görev atanmadı.</p>}
              {data.tasks.map((task) => (
                <article key={task.id} className="nutrition-form-section">
                  <h3>{task.title}</h3>
                  <p>{taskLabels[task.status]}</p>
                  {task.description && <p>{task.description}</p>}
                  {task.dueDate && <p className="muted">Son tarih: {formatDate(task.dueDate)}</p>}
                </article>
              ))}
            </section>
            <section className="panel">
              <h2>Danışman notları</h2>
              {data.notes.length === 0 && <p className="muted">Henüz danışman notu yok.</p>}
              {data.notes.map((note) => (
                <article key={note.id} className="nutrition-form-section">
                  <h3>{note.title}</h3>
                  <p style={{ whiteSpace: 'pre-wrap' }}>{note.content}</p>
                  <p className="muted">{formatDate(note.createdAt)}</p>
                </article>
              ))}
            </section>
          </>
        )
      )}
    </>
  );
}

function AssignmentForm({ userId, onSaved }: { userId: string; onSaved: () => void }) {
  const [kind, setKind] = useState<'task' | 'note'>('task');
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current) return;
    if (!title.trim() || title.trim().length > 200 || (kind === 'note' && !content.trim())) {
      setFailure('Başlık (en fazla 200 karakter) ve not için içerik gerekli.');
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    setFailure(null);
    try {
      if (kind === 'task')
        await createTask(
          userId,
          { title: title.trim(), description: content.trim() || null, dueDate: dueDate || null },
          controller.signal,
        );
      else
        await createNote(
          userId,
          { title: title.trim(), content: content.trim() },
          controller.signal,
        );
      if (!controller.signal.aborted) {
        setTitle('');
        setContent('');
        setDueDate('');
        onSaved();
      }
    } catch (error) {
      if (!controller.signal.aborted)
        setFailure(
          error instanceof ApiError && error.problem.errors
            ? Object.values(error.problem.errors).flat().join(' ')
            : error instanceof Error
              ? error.message
              : 'Atama kaydedilemedi.',
        );
    } finally {
      if (!controller.signal.aborted) {
        pending.current = null;
        setSubmitting(false);
      }
    }
  }
  return (
    <form onSubmit={submit} noValidate>
      <fieldset className="nutrition-editor" disabled={submitting}>
        <legend>Yeni görev veya not</legend>
        <div className="form-grid">
          <div>
            <label htmlFor="assignment-kind">Atama türü</label>
            <select
              id="assignment-kind"
              value={kind}
              onChange={(e) => {
                setKind(e.target.value as 'task' | 'note');
                setFailure(null);
              }}
            >
              <option value="task">Görev</option>
              <option value="note">Not</option>
            </select>
          </div>
          <div>
            <label htmlFor="assignment-title">Başlık</label>
            <input
              id="assignment-title"
              value={title}
              maxLength={200}
              required
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>
          <div>
            <label htmlFor="assignment-content">
              {kind === 'note' ? 'Not içeriği' : 'Görev açıklaması (isteğe bağlı)'}
            </label>
            <textarea
              id="assignment-content"
              value={content}
              required={kind === 'note'}
              onChange={(e) => setContent(e.target.value)}
            />
          </div>
          {kind === 'task' && (
            <div>
              <label htmlFor="assignment-date">Son tarih (isteğe bağlı)</label>
              <input
                id="assignment-date"
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
              />
            </div>
          )}
        </div>
      </fieldset>
      {failure && (
        <div className="form-failure" role="alert">
          {failure}
        </div>
      )}
      <button className="button primary" type="submit" disabled={submitting}>
        {submitting ? 'Kaydediliyor…' : kind === 'task' ? 'Görevi ata' : 'Notu kaydet'}
      </button>
    </form>
  );
}

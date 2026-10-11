import { useEffect, useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { Check, Dumbbell } from 'lucide-react';
import { Link, useNavigate } from 'react-router';
import { ApiError } from '../services/apiClient';
import { saveExercise } from '../services/exerciseService';
import type { CreateExerciseRequest, ExerciseDetailResponse } from '../types/exercise';

const fields = [
  { key: 'name', label: 'Egzersiz adı', limit: 200 },
  { key: 'description', label: 'Açıklama (isteğe bağlı)', limit: 10000 },
  { key: 'instructions', label: 'Uygulama talimatları (isteğe bağlı)', limit: 20000 },
  { key: 'videoUrl', label: 'Video bağlantısı (isteğe bağlı)', limit: 2048 },
  { key: 'imageUrl', label: 'Görsel bağlantısı (isteğe bağlı)', limit: 2048 },
] as const;
type TextField = (typeof fields)[number]['key'];

export function ExerciseForm({ exercise }: { exercise?: ExerciseDetailResponse }) {
  const navigate = useNavigate();
  const [draft, setDraft] = useState<Record<TextField, string>>(() => ({
    name: exercise?.name ?? '',
    description: exercise?.description ?? '',
    instructions: exercise?.instructions ?? '',
    videoUrl: exercise?.videoUrl ?? '',
    imageUrl: exercise?.imageUrl ?? '',
  }));
  const [isActive, setIsActive] = useState(exercise?.isActive ?? true);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);

  function focusError(nextErrors: Record<string, string>) {
    const first = fields.find(({ key }) => nextErrors[key.toLowerCase()]);
    if (first) document.getElementById(`exercise-${first.key}`)?.focus();
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current) return;
    const nextErrors: Record<string, string> = {};
    for (const { key, limit } of fields) {
      const value = draft[key].trim();
      if (key === 'name' && !value) nextErrors.name = 'Egzersiz adını gir.';
      else if (value.length > limit)
        nextErrors[key.toLowerCase()] = `En fazla ${limit} karakter girebilirsin.`;
      else if ((key === 'videoUrl' || key === 'imageUrl') && value) {
        try {
          const url = new URL(value);
          if (!['http:', 'https:'].includes(url.protocol)) throw new Error();
        } catch {
          nextErrors[key.toLowerCase()] =
            'http:// veya https:// ile başlayan geçerli bir bağlantı gir.';
        }
      }
    }
    setErrors(nextErrors);
    setFailure(null);
    if (Object.keys(nextErrors).length) {
      setFailure('Hatalı alanları kontrol et. Egzersiz henüz kaydedilmedi.');
      focusError(nextErrors);
      return;
    }
    const request: CreateExerciseRequest = {
      name: draft.name.trim(),
      description: draft.description.trim() || null,
      instructions: draft.instructions.trim() || null,
      videoUrl: draft.videoUrl.trim() || null,
      imageUrl: draft.imageUrl.trim() || null,
      isActive,
    };
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    try {
      await saveExercise(exercise?.id, request, controller.signal);
      if (!controller.signal.aborted)
        await navigate('/egzersizler', { replace: true, state: { exerciseSaved: true } });
    } catch (reason) {
      if (controller.signal.aborted) return;
      const fieldErrors: Record<string, string> = {};
      if (reason instanceof ApiError)
        for (const [key, messages] of Object.entries(reason.problem.errors ?? {}))
          fieldErrors[key.split('.').at(-1)!.toLowerCase()] = messages.join(' ');
      setErrors(fieldErrors);
      setFailure(reason instanceof Error ? reason.message : 'Egzersiz kaydedilemedi. Tekrar dene.');
    } finally {
      pending.current = null;
      if (!controller.signal.aborted) setSubmitting(false);
    }
  }

  return (
    <form onSubmit={submit} noValidate className="panel exercise-form-panel">
      <div className="section-intro">
        <Dumbbell size={24} aria-hidden="true" />
        <div>
          <h2>Egzersiz bilgileri</h2>
          <p className="muted">Yalnız egzersiz adı zorunludur.</p>
        </div>
      </div>
      <fieldset className="exercise-form-fields" disabled={submitting}>
        <legend className="sr-only">Katalog bilgileri</legend>
        {fields.map(({ key, label, limit }) => {
          const id = `exercise-${key}`;
          const error = errors[key.toLowerCase()];
          const props = {
            id,
            value: draft[key],
            maxLength: limit,
            required: key === 'name',
            'aria-invalid': !!error,
            'aria-describedby': error ? `${id}-error` : undefined,
            onChange: (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
              setDraft((value) => ({ ...value, [key]: event.target.value })),
          };
          return (
            <div className="workout-field" key={key}>
              <label htmlFor={id}>{label}</label>
              {key === 'description' || key === 'instructions' ? (
                <textarea {...props} rows={key === 'instructions' ? 5 : 3} />
              ) : (
                <input
                  {...props}
                  type={key === 'name' ? 'text' : 'url'}
                  placeholder={key === 'name' ? 'Örn. Romanian Deadlift' : 'https://…'}
                />
              )}
              {error && (
                <p className="field-error" id={`${id}-error`}>
                  {error}
                </p>
              )}
            </div>
          );
        })}
        <div className="exercise-availability">
          <label htmlFor="exercise-isActive">
            <input
              id="exercise-isActive"
              type="checkbox"
              checked={isActive}
              aria-describedby="exercise-availability-help"
              onChange={(event) => setIsActive(event.target.checked)}
            />
            Katalogda aktif
          </label>
          <p className="muted" id="exercise-availability-help">
            {isActive
              ? 'Antrenörler bu egzersizi yeni programlara ekleyebilir.'
              : 'Pasif egzersiz yeni programlarda seçilemez. Geçmiş programlarda korunur; buradan yeniden aktif edebilirsin.'}
          </p>
        </div>
      </fieldset>
      {failure && (
        <div className="form-failure" role="alert">
          {failure}
        </div>
      )}
      <div className="exercise-form-actions">
        <Link className="button secondary" to="/egzersizler">
          Vazgeç
        </Link>
        <button className="button primary" disabled={submitting} type="submit">
          <Check size={17} aria-hidden="true" />
          {submitting ? 'Kaydediliyor…' : 'Egzersizi kaydet'}
        </button>
      </div>
    </form>
  );
}

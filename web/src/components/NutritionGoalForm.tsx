import { useEffect, useRef, useState, type FormEvent } from 'react';
import { CalendarDays, Check, Leaf } from 'lucide-react';
import { Link, useNavigate } from 'react-router';
import type { ClientSummary } from '../types/api';
import type { NutritionGoalResponse } from '../types/nutrition';
import { ApiError } from '../services/apiClient';
import { requireClient } from '../services/clientService';
import { createNutritionGoal } from '../services/nutritionService';
import { localDate } from '../utils/date';
import {
  formatNutritionValue,
  nutritionFields,
  prepareNutritionGoal,
  type NutritionGoalDraft,
} from '../utils/nutritionGoal';
import { formatDate, initials } from './PeopleTable';

export function NutritionGoalForm({
  client,
  activeGoal,
  demo,
}: {
  client: ClientSummary;
  activeGoal?: NutritionGoalResponse;
  demo: boolean;
}) {
  const navigate = useNavigate();
  const [draft, setDraft] = useState<NutritionGoalDraft>(() => ({
    dailyCalories: '',
    proteinGrams: '',
    carbohydrateGrams: '',
    fatGrams: '',
    waterMl: '',
    startDate: localDate(),
    endDate: '',
  }));
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current) return;
    const prepared = prepareNutritionGoal(draft);
    setErrors(prepared.errors);
    setFailure(null);
    if (Object.keys(prepared.errors).length) {
      setFailure('Eksik veya hatalı alanları kontrol et. Hedef henüz atanmadı.');
      const key = Object.keys(draft).find((field) => prepared.errors[field.toLowerCase()]);
      document.getElementById(`nutrition-${key}`)?.focus();
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    try {
      await requireClient(client.id, 'Dietitian', demo, controller.signal);
      await createNutritionGoal(client.id, prepared.request, demo, controller.signal);
      if (!controller.signal.aborted)
        await navigate(`/beslenme-hedefleri/${client.id}`, {
          replace: true,
          state: { goalAssigned: true },
        });
    } catch (reason) {
      if (controller.signal.aborted) return;
      if (reason instanceof ApiError) {
        const fields: Record<string, string> = {};
        for (const [key, messages] of Object.entries(reason.problem.errors ?? {}))
          fields[key.split('.').at(-1)!.toLowerCase()] = messages.join(' ');
        setErrors(fields);
        setFailure(Object.values(fields).join(' ') || reason.message);
      } else setFailure(reason instanceof Error ? reason.message : 'Hedef atanamadı. Tekrar dene.');
    } finally {
      pending.current = null;
      if (!controller.signal.aborted) setSubmitting(false);
    }
  }

  function field(key: keyof NutritionGoalDraft, label: string, type: 'number' | 'date') {
    const error = errors[key.toLowerCase()];
    const id = `nutrition-${key}`;
    return (
      <div
        className={`nutrition-field ${key === 'dailyCalories' ? 'calorie-field' : ''}`}
        key={key}
      >
        <label htmlFor={id}>{label}</label>
        <input
          id={id}
          type={type}
          value={draft[key]}
          required={key !== 'endDate'}
          min={type === 'number' ? 0 : key === 'endDate' ? draft.startDate : undefined}
          step={type === 'number' ? 'any' : undefined}
          inputMode={type === 'number' ? 'decimal' : undefined}
          placeholder={type === 'number' ? 'Hedefi gir' : undefined}
          aria-invalid={!!error}
          aria-describedby={
            [error ? `${id}-error` : '', key === 'waterMl' ? 'nutrition-water-help' : '']
              .filter(Boolean)
              .join(' ') || undefined
          }
          onChange={(event) => setDraft((value) => ({ ...value, [key]: event.target.value }))}
        />
        {error && (
          <p className="field-error" id={`${id}-error`}>
            {error}
          </p>
        )}
      </div>
    );
  }

  return (
    <form className="nutrition-form" onSubmit={submit} noValidate>
      <fieldset className="nutrition-editor" disabled={submitting}>
        <legend className="sr-only">Beslenme hedefi bilgileri</legend>
        <section className="panel nutrition-form-section">
          <div className="section-intro">
            <Leaf size={24} aria-hidden="true" />
            <div>
              <h2>Günlük hedefler</h2>
              <p className="muted">
                Tüm değerler bir gün içindir. Hedefleri danışanına göre belirle.
              </p>
            </div>
          </div>
          <div className="form-grid">
            {nutritionFields.map(({ key, label, unit }) =>
              field(key, `${label} (${unit})`, 'number'),
            )}
          </div>
          <p className="nutrition-water-note muted" id="nutrition-water-help">
            Su miktarı günlük hedeftir; içilen suyu veya tüketim ilerlemesini göstermez.
          </p>
        </section>
        <section className="panel nutrition-form-section">
          <div className="section-intro">
            <CalendarDays size={24} aria-hidden="true" />
            <div>
              <h2>Geçerlilik tarihleri</h2>
              <p className="muted">Hedef yalnız bu tarih aralığında günlük plana yansır.</p>
            </div>
          </div>
          <div className="form-grid">
            {field('startDate', 'Başlangıç tarihi', 'date')}
            {field('endDate', 'Bitiş tarihi (isteğe bağlı)', 'date')}
          </div>
          <p className="nutrition-water-note muted">
            Bitiş tarihi boş bırakılırsa hedefin bitiş sınırı olmaz.
          </p>
        </section>
      </fieldset>
      <aside className="panel assignment-summary nutrition-summary">
        <span className="eyebrow">ATAMA ÖZETİ</span>
        <div className="nutrition-client-summary">
          <span className="avatar">{initials(client)}</span>
          <div>
            <h2>
              {client.firstName} {client.lastName}
            </h2>
            <p className="muted">Beslenme hedefi</p>
          </div>
        </div>
        <dl className="nutrition-summary-values">
          {nutritionFields.map(({ key, label, unit }) => (
            <div key={key}>
              <dt>{label}</dt>
              <dd>
                {draft[key].trim() && Number.isFinite(Number(draft[key])) && Number(draft[key]) >= 0
                  ? formatNutritionValue(Number(draft[key]))
                  : '—'}{' '}
                <span>{unit}</span>
              </dd>
            </div>
          ))}
        </dl>
        <p className="nutrition-summary-dates muted">
          {formatDate(draft.startDate)} –{' '}
          {draft.endDate ? formatDate(draft.endDate) : 'Bitiş belirtilmedi'}
        </p>
        <div className="assignment-warning">
          {activeGoal ? (
            <>
              Mevcut aktif hedef:{' '}
              <strong>{formatNutritionValue(activeGoal.dailyCalories)} kcal / gün.</strong>{' '}
            </>
          ) : null}
          Yeni hedef atandığında önceki aktif hedef hemen pasif olur. Başlangıç tarihi gelecekteyse
          o tarihe kadar günlük hedef gösterilmez.
        </div>
        {demo && (
          <p className="demo-save-note">
            Örnek atama yalnız bu önizlemede tutulur. Sayfa yenilendiğinde sıfırlanır; sunucuya veya
            mobil uygulamaya gönderilmez.
          </p>
        )}
        {failure && (
          <div className="form-failure" role="alert">
            {failure}
          </div>
        )}
        <button className="button primary" disabled={submitting} type="submit">
          <Check size={17} aria-hidden="true" />
          {submitting ? 'Atanıyor…' : demo ? 'Örnek hedef atamasını dene' : 'Hedefi ata'}
        </button>
        <Link className="button secondary" to={`/beslenme-hedefleri/${client.id}`}>
          Vazgeç
        </Link>
      </aside>
    </form>
  );
}

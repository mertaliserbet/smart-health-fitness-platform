import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { ArrowDown, ArrowUp, Check, Dumbbell, Plus, Trash2 } from 'lucide-react';
import { Link, useNavigate } from 'react-router';
import type { ClientSummary } from '../types/api';
import type { ExerciseResponse } from '../types/workout';
import { ApiError } from '../services/apiClient';
import { requireTrainerClient } from '../services/clientService';
import { createWorkoutPlan } from '../services/workoutService';
import {
  localDate,
  moveItem,
  newWorkoutDay,
  prepareWorkoutPlan,
  weekdayLabel,
  weekdays,
  type WorkoutDayDraft,
  type WorkoutExerciseDraft,
  type WorkoutPlanDraft,
} from '../utils/workoutPlan';

function Field({
  path,
  label,
  errors,
  children,
}: {
  path: string;
  label: string;
  errors: Record<string, string>;
  children: ReactNode;
}) {
  const error = errors[path.toLowerCase()];
  const [visibleLabel, context] = label.split(' — ');
  return (
    <div className="workout-field">
      <label htmlFor={`workout-${path}`}>
        {visibleLabel}
        {context && <span className="sr-only"> — {context}</span>}
      </label>
      {children}
      {error && (
        <p className="field-error" id={`workout-${path}-error`}>
          {error}
        </p>
      )}
    </div>
  );
}

function ExercisePicker({
  dayNumber,
  exercises,
  onAdd,
}: {
  dayNumber: number;
  exercises: ExerciseResponse[];
  onAdd: (exercise: ExerciseResponse) => void;
}) {
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState('');
  const filtered = exercises.filter((exercise) =>
    exercise.name.toLocaleLowerCase('tr-TR').includes(search.trim().toLocaleLowerCase('tr-TR')),
  );
  return (
    <div className="exercise-picker">
      <div className="workout-field">
        <label htmlFor={`exercise-search-${dayNumber}`}>Egzersiz ara — {dayNumber}. gün</label>
        <input
          id={`exercise-search-${dayNumber}`}
          placeholder="İsimle ara…"
          value={search}
          onChange={(event) => {
            setSearch(event.target.value);
            setSelected('');
          }}
        />
      </div>
      <div className="workout-field">
        <label htmlFor={`exercise-select-${dayNumber}`}>Egzersiz seç — {dayNumber}. gün</label>
        <select
          id={`exercise-select-${dayNumber}`}
          value={selected}
          onChange={(event) => setSelected(event.target.value)}
        >
          <option value="">{filtered.length ? 'Katalogdan seç' : 'Eşleşen egzersiz yok'}</option>
          {filtered.map((exercise) => (
            <option key={exercise.id} value={exercise.id}>
              {exercise.name}
            </option>
          ))}
        </select>
      </div>
      <button
        className="button secondary"
        type="button"
        disabled={!selected}
        aria-label={`Egzersizi ekle — ${dayNumber}. gün`}
        onClick={() => {
          const exercise = exercises.find((value) => value.id === selected);
          if (exercise) onAdd(exercise);
          setSelected('');
        }}
      >
        <Plus size={16} aria-hidden="true" />
        Egzersizi ekle
      </button>
    </div>
  );
}

export function WorkoutPlanForm({
  client,
  exercises,
  demo,
}: {
  client: ClientSummary;
  exercises: ExerciseResponse[];
  demo: boolean;
}) {
  const navigate = useNavigate();
  const [draft, setDraft] = useState<WorkoutPlanDraft>(() => ({
    name: '',
    description: '',
    startDate: localDate(),
    endDate: '',
    days: [newWorkoutDay('Monday', 1)],
  }));
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [failure, setFailure] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);

  const fieldProps = (path: string) => ({
    id: `workout-${path}`,
    'aria-invalid': !!errors[path.toLowerCase()],
    'aria-describedby': errors[path.toLowerCase()] ? `workout-${path}-error` : undefined,
  });
  const updatePlan = (key: 'name' | 'description' | 'startDate' | 'endDate', value: string) =>
    setDraft((current) => ({ ...current, [key]: value }));
  const updateDay = (index: number, values: Partial<WorkoutDayDraft>) =>
    setDraft((current) => ({
      ...current,
      days: current.days.map((day, i) => (i === index ? { ...day, ...values } : day)),
    }));
  const updateExercise = (dayIndex: number, index: number, values: Partial<WorkoutExerciseDraft>) =>
    setDraft((current) => ({
      ...current,
      days: current.days.map((day, i) =>
        i === dayIndex
          ? {
              ...day,
              exercises: day.exercises.map((exercise, j) =>
                j === index ? { ...exercise, ...values } : exercise,
              ),
            }
          : day,
      ),
    }));
  const addExercise = (dayIndex: number, exercise: ExerciseResponse) =>
    setDraft((current) => ({
      ...current,
      days: current.days.map((day, i) =>
        i === dayIndex
          ? {
              ...day,
              exercises: [
                ...day.exercises,
                {
                  key: crypto.randomUUID(),
                  exerciseId: exercise.id,
                  exerciseName: exercise.name,
                  mode: 'reps',
                  sets: '3',
                  reps: '10',
                  durationSeconds: '',
                  restSeconds: '60',
                  weightKg: '',
                  notes: '',
                },
              ],
            }
          : day,
      ),
    }));

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current) return;
    const prepared = prepareWorkoutPlan(draft);
    setErrors(prepared.errors);
    setFailure(null);
    if (Object.keys(prepared.errors).length) {
      setFailure('Eksik veya hatalı alanları kontrol et. Program henüz atanmadı.');
      document.getElementById(`workout-${Object.keys(prepared.errors)[0]}`)?.focus();
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    try {
      await requireTrainerClient(client.id, demo, controller.signal);
      await createWorkoutPlan(client.id, prepared.request, demo, controller.signal);
      if (!controller.signal.aborted)
        await navigate(`/programlar/${client.id}`, {
          replace: true,
          state: { programAssigned: true },
        });
    } catch (reason) {
      if (controller.signal.aborted) return;
      if (reason instanceof ApiError) {
        const fields: Record<string, string> = {};
        for (const [key, values] of Object.entries(reason.problem.errors ?? {})) {
          fields[
            key
              .replace(/^\$\.?/, '')
              .replace(/\[(\d+)\]/g, '.$1')
              .toLowerCase()
          ] = values.join(' ');
        }
        setErrors(fields);
        setFailure([reason.message, ...Object.values(fields)].join(' '));
      } else
        setFailure(
          reason instanceof Error ? reason.message : 'Program atanamadı. Tekrar deneyebilirsin.',
        );
    } finally {
      if (!controller.signal.aborted) setSubmitting(false);
      if (pending.current === controller) pending.current = null;
    }
  }

  return (
    <form className="workout-form" noValidate onSubmit={(event) => void submit(event)}>
      <div className="workout-editor">
        <fieldset disabled={submitting}>
          <section className="panel workout-form-section">
            <div className="section-intro">
              <span className="section-number">01</span>
              <div>
                <h2>Program bilgileri</h2>
                <p className="muted">
                  {client.firstName} {client.lastName} için bir başlangıç.
                </p>
              </div>
            </div>
            <Field path="name" label="Program adı" errors={errors}>
              <input
                {...fieldProps('name')}
                value={draft.name}
                placeholder="Örn. 4 haftalık kuvvet programı"
                onChange={(event) => updatePlan('name', event.target.value)}
                required
              />
            </Field>
            <Field path="description" label="Program açıklaması (isteğe bağlı)" errors={errors}>
              <textarea
                {...fieldProps('description')}
                rows={3}
                value={draft.description}
                placeholder="Programın amacı ve genel notların…"
                onChange={(event) => updatePlan('description', event.target.value)}
              />
            </Field>
            <div className="form-grid">
              <Field path="startdate" label="Başlangıç tarihi" errors={errors}>
                <input
                  {...fieldProps('startdate')}
                  type="date"
                  value={draft.startDate}
                  onChange={(event) => updatePlan('startDate', event.target.value)}
                  required
                />
              </Field>
              <Field path="enddate" label="Bitiş tarihi (isteğe bağlı)" errors={errors}>
                <input
                  {...fieldProps('enddate')}
                  type="date"
                  value={draft.endDate}
                  min={draft.startDate || undefined}
                  onChange={(event) => updatePlan('endDate', event.target.value)}
                />
              </Field>
            </div>
          </section>
          <section className="workout-days-editor">
            <div className="editor-heading">
              <div>
                <span className="eyebrow">02 · HAFTALIK DÜZEN</span>
                <h2>Antrenman günleri</h2>
                <p className="muted">
                  Her gün bir kez seçilir. Sıralama, haftanın gününden bağımsızdır.
                </p>
              </div>
              <button
                className="button secondary"
                type="button"
                disabled={draft.days.length >= 7}
                onClick={() =>
                  setDraft((current) => {
                    const available = weekdays.find(
                      ({ value }) => !current.days.some((day) => day.weekday === value),
                    );
                    return available
                      ? {
                          ...current,
                          days: [
                            ...current.days,
                            newWorkoutDay(available.value, current.days.length + 1),
                          ],
                        }
                      : current;
                  })
                }
              >
                <Plus size={16} aria-hidden="true" />
                Gün ekle
              </button>
            </div>
            {errors.days && (
              <p className="field-error" role="alert">
                {errors.days}
              </p>
            )}
            {draft.days.map((day, dayIndex) => {
              const prefix = `days.${dayIndex}`;
              return (
                <section className="panel workout-day-editor" key={day.key}>
                  <div className="day-editor-heading">
                    <span className="day-badge">{dayIndex + 1}</span>
                    <div>
                      <h3>{day.name || 'Antrenman günü'}</h3>
                      <span className="muted">{weekdayLabel(day.weekday)}</span>
                    </div>
                    <div className="row-actions">
                      <button
                        type="button"
                        className="icon-button"
                        aria-label={`${dayIndex + 1}. günü yukarı taşı`}
                        disabled={dayIndex === 0}
                        onClick={() =>
                          setDraft((current) => ({
                            ...current,
                            days: moveItem(current.days, dayIndex, -1),
                          }))
                        }
                      >
                        <ArrowUp size={17} aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        className="icon-button"
                        aria-label={`${dayIndex + 1}. günü aşağı taşı`}
                        disabled={dayIndex === draft.days.length - 1}
                        onClick={() =>
                          setDraft((current) => ({
                            ...current,
                            days: moveItem(current.days, dayIndex, 1),
                          }))
                        }
                      >
                        <ArrowDown size={17} aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        className="icon-button danger-text"
                        aria-label={`${dayIndex + 1}. günü sil`}
                        disabled={draft.days.length === 1}
                        onClick={() =>
                          setDraft((current) => ({
                            ...current,
                            days: current.days.filter((_, index) => index !== dayIndex),
                          }))
                        }
                      >
                        <Trash2 size={17} aria-hidden="true" />
                      </button>
                    </div>
                  </div>
                  <div className="form-grid">
                    <Field
                      path={`${prefix}.name`}
                      label={`Gün adı — ${dayIndex + 1}. gün`}
                      errors={errors}
                    >
                      <input
                        {...fieldProps(`${prefix}.name`)}
                        value={day.name}
                        onChange={(event) => updateDay(dayIndex, { name: event.target.value })}
                        required
                      />
                    </Field>
                    <Field
                      path={`${prefix}.weekday`}
                      label={`Haftanın günü — ${dayIndex + 1}. gün`}
                      errors={errors}
                    >
                      <select
                        {...fieldProps(`${prefix}.weekday`)}
                        value={day.weekday}
                        onChange={(event) =>
                          updateDay(dayIndex, {
                            weekday: event.target.value as WorkoutDayDraft['weekday'],
                          })
                        }
                      >
                        {weekdays.map(({ value, label }) => (
                          <option
                            value={value}
                            key={value}
                            disabled={draft.days.some(
                              (other, index) => index !== dayIndex && other.weekday === value,
                            )}
                          >
                            {label}
                          </option>
                        ))}
                      </select>
                    </Field>
                  </div>
                  <Field
                    path={`${prefix}.description`}
                    label={`Gün açıklaması — ${dayIndex + 1}. gün (isteğe bağlı)`}
                    errors={errors}
                  >
                    <textarea
                      {...fieldProps(`${prefix}.description`)}
                      rows={2}
                      value={day.description}
                      onChange={(event) => updateDay(dayIndex, { description: event.target.value })}
                    />
                  </Field>
                  <ExercisePicker
                    dayNumber={dayIndex + 1}
                    exercises={exercises}
                    onAdd={(exercise) => addExercise(dayIndex, exercise)}
                  />
                  {errors[`${prefix}.exercises`] && (
                    <p className="field-error" role="alert">
                      {errors[`${prefix}.exercises`]}
                    </p>
                  )}
                  {!day.exercises.length && (
                    <p className="no-exercises muted">
                      <Dumbbell size={18} aria-hidden="true" />
                      Katalogdan egzersiz seçerek bu günü hazırla.
                    </p>
                  )}
                  {day.exercises.map((exercise, index) => {
                    const path = `${prefix}.exercises.${index}`;
                    const targetLabel = `${dayIndex + 1}. gün, ${index + 1}. egzersiz`;
                    const numberField = (
                      property: 'sets' | 'reps' | 'durationSeconds' | 'restSeconds' | 'weightKg',
                      label: string,
                      min: number,
                      step = '1',
                    ) => (
                      <Field
                        path={`${path}.${property.toLowerCase()}`}
                        label={`${label} — ${targetLabel}`}
                        errors={errors}
                      >
                        <input
                          {...fieldProps(`${path}.${property.toLowerCase()}`)}
                          type="number"
                          min={min}
                          step={step}
                          value={exercise[property]}
                          onChange={(event) =>
                            updateExercise(dayIndex, index, { [property]: event.target.value })
                          }
                        />
                      </Field>
                    );
                    return (
                      <div className="exercise-editor" key={exercise.key}>
                        <div className="exercise-editor-heading">
                          <span className="exercise-number">{index + 1}</span>
                          <h3>{exercise.exerciseName}</h3>
                          <div className="row-actions">
                            <button
                              className="icon-button"
                              type="button"
                              disabled={index === 0}
                              aria-label={`${exercise.exerciseName}, ${targetLabel}, yukarı taşı`}
                              onClick={() =>
                                updateDay(dayIndex, {
                                  exercises: moveItem(day.exercises, index, -1),
                                })
                              }
                            >
                              <ArrowUp size={16} aria-hidden="true" />
                            </button>
                            <button
                              className="icon-button"
                              type="button"
                              disabled={index === day.exercises.length - 1}
                              aria-label={`${exercise.exerciseName}, ${targetLabel}, aşağı taşı`}
                              onClick={() =>
                                updateDay(dayIndex, {
                                  exercises: moveItem(day.exercises, index, 1),
                                })
                              }
                            >
                              <ArrowDown size={16} aria-hidden="true" />
                            </button>
                            <button
                              className="icon-button danger-text"
                              type="button"
                              aria-label={`${exercise.exerciseName}, ${targetLabel}, sil`}
                              onClick={() =>
                                updateDay(dayIndex, {
                                  exercises: day.exercises.filter(
                                    (_, position) => position !== index,
                                  ),
                                })
                              }
                            >
                              <Trash2 size={16} aria-hidden="true" />
                            </button>
                          </div>
                        </div>
                        <div className="exercise-inputs">
                          <Field
                            path={`${path}.mode`}
                            label={`Hedef türü — ${targetLabel}`}
                            errors={errors}
                          >
                            <select
                              {...fieldProps(`${path}.mode`)}
                              value={exercise.mode}
                              onChange={(event) =>
                                updateExercise(dayIndex, index, {
                                  mode: event.target.value as WorkoutExerciseDraft['mode'],
                                })
                              }
                            >
                              <option value="reps">Set ve tekrar</option>
                              <option value="duration">Süre</option>
                            </select>
                          </Field>
                          {exercise.mode === 'reps' ? (
                            <>
                              {numberField('sets', 'Set', 1)}
                              {numberField('reps', 'Tekrar', 1)}
                            </>
                          ) : (
                            numberField('durationSeconds', 'Süre (sn)', 1)
                          )}
                          {numberField('restSeconds', 'Dinlenme (sn, isteğe bağlı)', 0)}
                          {numberField('weightKg', 'Ağırlık (kg, isteğe bağlı)', 0.01, 'any')}
                        </div>
                        <Field
                          path={`${path}.notes`}
                          label={`Egzersiz notu — ${targetLabel} (isteğe bağlı)`}
                          errors={errors}
                        >
                          <textarea
                            {...fieldProps(`${path}.notes`)}
                            rows={2}
                            value={exercise.notes}
                            onChange={(event) =>
                              updateExercise(dayIndex, index, { notes: event.target.value })
                            }
                          />
                        </Field>
                      </div>
                    );
                  })}
                </section>
              );
            })}
          </section>
        </fieldset>
      </div>
      <aside className="panel assignment-summary">
        <span className="eyebrow">03 · ATAMA ÖZETİ</span>
        <h2>{draft.name.trim() || 'Yeni program'}</h2>
        <p className="muted">
          {client.firstName} {client.lastName}
        </p>
        <div className="summary-stat">
          <span>Antrenman günü</span>
          <strong>{draft.days.length}</strong>
        </div>
        <div className="summary-stat">
          <span>Egzersiz</span>
          <strong>{draft.days.reduce((count, day) => count + day.exercises.length, 0)}</strong>
        </div>
        <ul className="summary-days">
          {draft.days.map((day) => (
            <li key={day.key}>
              <Check size={14} aria-hidden="true" />
              <span>
                {weekdayLabel(day.weekday)}
                <small>
                  {day.name} · {day.exercises.length} egzersiz
                </small>
              </span>
            </li>
          ))}
        </ul>
        <p className="assignment-warning">
          Yeni program atandığında danışanın önceki aktif programı pasif hale gelir.
        </p>
        {demo && (
          <p className="demo-save-note">
            Önizleme ataması yalnız bu sayfa oturumunda tutulur. Sayfa yenilenince sıfırlanır;
            sunucuya ve mobil uygulamaya kaydedilmez.
          </p>
        )}
        {failure && (
          <p className="form-failure" role="alert">
            {failure}
          </p>
        )}
        <button type="submit" className="button primary" disabled={submitting}>
          {submitting ? 'Atanıyor…' : demo ? 'Örnek atamayı dene' : 'Programı ata'}
        </button>
        <Link
          className="button secondary"
          aria-disabled={submitting}
          to={`/programlar/${client.id}`}
          onClick={(event) => {
            if (submitting) event.preventDefault();
          }}
        >
          Vazgeç
        </Link>
      </aside>
    </form>
  );
}

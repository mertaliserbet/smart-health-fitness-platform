import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { PagedWorkoutSessionsResponse, WorkoutSessionResponse } from './types/workoutSession';

const clientId = 'client-one';
const sessionId = 'session-one';
const listPath = `/danisanlar/${clientId}/antrenmanlar`;
const client = {
  id: clientId,
  firstName: 'Mert',
  lastName: 'Şerbet',
  relationshipStatus: 'Active',
  startDate: '2026-10-01',
};
const history: PagedWorkoutSessionsResponse = {
  items: [
    {
      id: sessionId,
      userId: clientId,
      workoutPlanId: 'plan',
      workoutDayId: 'day',
      planName: 'Kuvvet programı',
      dayName: 'Üst vücut',
      startedAt: '2026-10-11T16:00:00Z',
      completedAt: '2026-10-11T17:00:00Z',
      status: 'Completed',
      completedExerciseCount: 1,
      totalExerciseCount: 3,
    },
  ],
  page: 1,
  pageSize: 20,
  totalCount: 21,
  totalPages: 2,
};
const detail: WorkoutSessionResponse = {
  id: sessionId,
  userId: clientId,
  workoutPlanId: 'plan',
  workoutDayId: 'day',
  planName: 'Kuvvet programı',
  startedAt: '2026-10-11T16:00:00Z',
  completedAt: '2026-10-11T17:00:00Z',
  status: 'Completed',
  day: {
    id: 'day',
    name: 'Üst vücut',
    dayNumber: 1,
    weekday: 'Monday',
    exercises: [
      {
        id: 'press',
        exerciseId: 'catalog-1',
        exerciseName: 'Bench Press',
        order: 1,
        sets: 3,
        reps: 10,
        durationSeconds: null,
        restSeconds: 60,
        weightKg: 0,
        notes: 'Kontrollü hareket',
      },
      {
        id: 'plank',
        exerciseId: 'catalog-2',
        exerciseName: 'Plank',
        order: 2,
        sets: null,
        reps: null,
        durationSeconds: 30,
        restSeconds: 0,
        weightKg: null,
        notes: null,
      },
      {
        id: 'row',
        exerciseId: 'catalog-3',
        exerciseName: 'Row',
        order: 3,
        sets: 3,
        reps: 10,
        durationSeconds: null,
        restSeconds: 60,
        weightKg: null,
        notes: null,
      },
    ],
  },
  logs: [
    {
      id: 'log-1',
      workoutExerciseId: 'press',
      completedSets: 2,
      completedReps: 8,
      weightKg: 0,
      durationSeconds: null,
      isCompleted: true,
      notes: 'İyi geçti',
      createdAt: '2026-10-11T16:10:00Z',
    },
    {
      id: 'log-2',
      workoutExerciseId: 'plank',
      completedSets: null,
      completedReps: null,
      weightKg: null,
      durationSeconds: 0,
      isCompleted: false,
      notes: null,
      createdAt: '2026-10-11T16:11:00Z',
    },
  ],
};
const response = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } });
function Navigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return <button onClick={() => void navigate(path)}>Test rotasını aç</button>;
}
function setup({
  path = listPath,
  roles = ['Trainer'],
  clients = [client],
  list = () => response(history),
  session = () => response(detail),
}: {
  path?: string;
  roles?: string[];
  clients?: (typeof client)[];
  list?: (url: string) => Response;
  session?: () => Response;
} = {}) {
  const mock = vi.fn<typeof fetch>().mockImplementation(async (url) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: '2026-12-01T00:00:00Z',
        user: {
          id: 'trainer',
          firstName: 'Uğur',
          lastName: 'Çetin',
          email: 'trainer@example.com',
          roles,
        },
      });
    if (url === '/api/trainers/me/clients') return response(clients);
    if (String(url).startsWith(`/api/users/${clientId}/workout-sessions?`))
      return list(String(url));
    if (url === `/api/workout-sessions/${sessionId}`) return session();
    return response({ detail: 'Bulunamadı' }, 404);
  });
  vi.stubGlobal('fetch', mock);
  render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
        <Navigation path={path} />
      </AuthProvider>
    </MemoryRouter>,
  );
  return mock;
}
async function login() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'trainer@example.com');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
afterEach(() => vi.unstubAllGlobals());
describe('Trainer antrenman geçmişi', () => {
  it('gerçek listeyi, kısmi tamamlanmayı ve hedef/gerçekleşen detayını gösterir; yazma yapmaz', async () => {
    const mock = setup();
    const user = await login();
    await screen.findByText('Tamamlandı · 1 / 3 egzersiz tamamlandı');
    await user.click(screen.getByRole('link', { name: 'Kuvvet programı · Üst vücut' }));
    await screen.findByRole('heading', { name: 'Üst vücut' });
    expect(screen.getByText('Hedef: 3 set × 10 tekrar · 0 kg')).toBeInTheDocument();
    expect(screen.getByText('Gerçekleşen: 2 set × 8 tekrar · 0 kg')).toBeInTheDocument();
    expect(screen.getByText('Gerçekleşen: 0 saniye')).toBeInTheDocument();
    expect(screen.getByText('Gerçekleşen: Kaydedilmedi')).toBeInTheDocument();
    expect(screen.getByText('Egzersiz tamamlanmadı')).toBeInTheDocument();
    expect(screen.getByText('Danışan notu: İyi geçti')).toBeInTheDocument();
    expect(
      mock.mock.calls.filter(
        ([url, options]) =>
          String(url).includes('workout-session') && options?.method && options.method !== 'GET',
      ),
    ).toHaveLength(0);
  });
  it('sayfa ve durum filtresini APIye gönderir; filtre değişince ilk sayfaya döner', async () => {
    const mock = setup();
    const user = await login();
    await screen.findByText('21 antrenman');
    await user.click(screen.getByRole('button', { name: 'Sonraki sayfa' }));
    await screen.findByText('Sayfa 2 / 2');
    expect(screen.getByRole('button', { name: 'Sonraki sayfa' })).toBeDisabled();
    await user.selectOptions(screen.getByLabelText('Antrenman durumu'), 'Cancelled');
    await screen.findByText('Sayfa 1 / 2');
    expect(
      mock.mock.calls.some(
        ([url]) => url === `/api/users/${clientId}/workout-sessions?page=2&pageSize=20`,
      ),
    ).toBe(true);
    expect(
      mock.mock.calls.some(
        ([url]) =>
          url === `/api/users/${clientId}/workout-sessions?page=1&pageSize=20&status=Cancelled`,
      ),
    ).toBe(true);
  });
  it('boş geçmişi gösterir', async () => {
    setup({ list: () => response({ ...history, items: [], totalCount: 0, totalPages: 0 }) });
    await login();
    await screen.findByText('Bu seçimde antrenman kaydı yok.');
    expect(screen.getByRole('button', { name: 'Sonraki sayfa' })).toBeDisabled();
  });
  it('sunucu hatasında yeniden deneyerek gerçek veriyi yükler', async () => {
    let failed = true;
    setup({
      list: () => (failed ? response({ detail: 'Geçmiş okunamadı' }, 503) : response(history)),
    });
    const user = await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçmiş okunamadı');
    failed = false;
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    await screen.findByText('21 antrenman');
  });
  it('bağlantısız danışanda geçmiş isteği yapmaz', async () => {
    const mock = setup({ clients: [] });
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('erişiminiz bulunmuyor');
    expect(mock.mock.calls.some(([url]) => String(url).includes('workout-sessions'))).toBe(false);
  });
  it.each(['Admin', 'Dietitian'])('%s geçmiş rotasına erişemez', async (role) => {
    const mock = setup({ roles: [role] });
    await login();
    await waitFor(() =>
      expect(screen.queryByRole('heading', { name: 'Antrenman geçmişi' })).not.toBeInTheDocument(),
    );
    expect(mock.mock.calls.some(([url]) => String(url).includes('workout-sessions'))).toBe(false);
  });
  it('yanıttaki başka danışan detayını göstermez', async () => {
    setup({
      path: `${listPath}/${sessionId}`,
      session: () => response({ ...detail, userId: 'other-client' }),
    });
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('seçili danışana ait değil');
    expect(screen.queryByText('Danışan notu: İyi geçti')).not.toBeInTheDocument();
  });
  it('yanlış kullanıcı içeren listeyi göstermez', async () => {
    setup({
      list: () =>
        response({ ...history, items: [{ ...history.items[0], userId: 'other-client' }] }),
    });
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('yanıtı doğrulanamadı');
  });
});

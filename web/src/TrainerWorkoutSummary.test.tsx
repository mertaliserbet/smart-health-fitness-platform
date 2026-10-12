import { afterEach, expect, it, vi } from 'vitest';
import { act, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { Role } from './types/api';
import type { WorkoutPlanSummaryResponse } from './types/workout';
import type { PagedWorkoutSessionsResponse } from './types/workoutSession';

const clientId = 'client-one';
const clients = [
  {
    id: clientId,
    firstName: 'Deniz',
    lastName: 'Test',
    relationshipStatus: 'Active',
    startDate: '2026-10-01',
  },
  {
    id: 'client-two',
    firstName: 'İkinci',
    lastName: 'Danışan',
    relationshipStatus: 'Active',
    startDate: '2026-10-02',
  },
];
const plans: WorkoutPlanSummaryResponse[] = [
  {
    id: 'past',
    name: 'Eski program',
    startDate: '2026-09-01',
    endDate: '2026-09-30',
    isActive: false,
  },
  { id: 'active', name: 'Kuvvet programı', startDate: '2026-10-01', endDate: null, isActive: true },
];
const history: PagedWorkoutSessionsResponse = {
  items: Array.from({ length: 6 }, (_, index) => ({
    id: `session-${index}`,
    userId: clientId,
    workoutPlanId: 'active',
    workoutDayId: 'day',
    planName: 'Kuvvet programı',
    dayName: `Gün ${index}`,
    startedAt: '2026-10-11T10:00:00Z',
    completedAt: index === 1 || index === 2 ? null : '2026-10-11T11:00:00Z',
    status: index === 1 ? 'Cancelled' : index === 2 ? 'InProgress' : 'Completed',
    completedExerciseCount: index === 2 ? 0 : 1,
    totalExerciseCount: 3,
  })),
  page: 1,
  pageSize: 20,
  totalCount: 25,
  totalPages: 2,
};
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
function setup({
  role = 'Trainer',
  relation = clients,
  planValues = plans,
  sessionValues = history,
  planResponse,
}: {
  role?: Role;
  relation?: typeof clients;
  planValues?: WorkoutPlanSummaryResponse[];
  sessionValues?: PagedWorkoutSessionsResponse;
  planResponse?: () => Response | Promise<Response>;
} = {}) {
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: new Date(Date.now() + 86400000).toISOString(),
        user: {
          id: 'advisor',
          firstName: 'Uğur',
          lastName: 'Test',
          email: 'advisor@example.test',
          roles: [role],
        },
      });
    if (url === '/api/trainers/me/clients' || url === '/api/dietitians/me/clients')
      return response(relation);
    if (url === `/api/users/${clientId}/workout-plans`)
      return planResponse ? planResponse() : response(planValues);
    if (url === `/api/users/${clientId}/workout-sessions?page=1&pageSize=20`)
      return response(sessionValues);
    if (url === '/api/users/client-two/workout-plans') return response([]);
    if (url === '/api/users/client-two/workout-sessions?page=1&pageSize=20')
      return response({ items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0 });
    if (url === '/api/users?page=1&pageSize=20')
      return response({ items: [], totalCount: 0, totalPages: 0, page: 1, pageSize: 20 });
    return response({ detail: 'Endpoint bulunamadı.' }, 404);
  });
  vi.stubGlobal('fetch', fetchMock);
  render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </MemoryRouter>,
  );
  return fetchMock;
}
async function login() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'advisor@example.test');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
  return user;
}
afterEach(() => vi.unstubAllGlobals());
it('danışan seçilmeden ek istek göndermez; seçimde toplamı ve yalnız son beş oturumu gösterir', async () => {
  const fetchMock = setup();
  const user = await login();
  const picker = await screen.findByLabelText('Antrenman özeti danışanı');
  expect(fetchMock.mock.calls.some(([url]) => String(url).includes('workout-'))).toBe(false);
  await user.selectOptions(picker, clientId);
  const summary = screen.getByRole('region', { name: 'Danışanın antrenman özeti' });
  await within(summary).findByText('25');
  expect(within(summary).getByRole('link', { name: 'Kuvvet programı' })).toHaveAttribute(
    'href',
    `/programlar/${clientId}/active`,
  );
  expect(within(summary).getAllByRole('link', { name: /Kuvvet programı \/ Gün/ })).toHaveLength(5);
  expect(within(summary).queryByText('Kuvvet programı / Gün 5')).not.toBeInTheDocument();
  expect(within(summary).getAllByText('1 / 3 egzersiz tamamlandı')).toHaveLength(4);
  expect(within(summary).getByText('0 / 3 egzersiz tamamlandı')).toBeInTheDocument();
  expect(within(summary).getByRole('link', { name: 'Antrenman geçmişi' })).toHaveAttribute(
    'href',
    `/danisanlar/${clientId}/antrenmanlar`,
  );
});
it('programı ve antrenmanı olmayan danışanda boş durumu ve yeni program yolunu gösterir', async () => {
  setup({
    planValues: [],
    sessionValues: { items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0 },
  });
  const user = await login();
  await user.selectOptions(await screen.findByLabelText('Antrenman özeti danışanı'), clientId);
  await screen.findByText('Danışanın aktif programı yok.');
  expect(screen.getByText('Henüz antrenman oturumu kaydı yok.')).toBeInTheDocument();
  expect(screen.getByRole('link', { name: 'Yeni program ata' })).toHaveAttribute(
    'href',
    `/programlar/${clientId}/yeni`,
  );
});
it('aktif danışan yoksa seçim veya program/oturum isteği açmaz', async () => {
  const fetchMock = setup({ relation: [] });
  await login();
  await screen.findByText('Özet için aktif bağlı danışan gerekli.');
  expect(screen.queryByLabelText('Antrenman özeti danışanı')).not.toBeInTheDocument();
  expect(fetchMock.mock.calls.some(([url]) => String(url).includes('workout-'))).toBe(false);
});
it.each(['Dietitian', 'Admin'] as const)(
  '%s dashboardunda antrenman özeti/istekleri yoktur',
  async (role) => {
    const fetchMock = setup({ role });
    await login();
    expect(
      screen.queryByRole('region', { name: 'Danışanın antrenman özeti' }),
    ).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => String(url).includes('workout-'))).toBe(false);
  },
);
it('hata halinde sayı veya örnek veri göstermez; yeniden deneme ve yenileme gerçek APIyi kullanır', async () => {
  let attempt = 0;
  const fetchMock = setup({
    planResponse: () =>
      ++attempt === 1
        ? response({ detail: 'İlişki erişimi kontrol edilemedi.' }, 503)
        : response(plans),
  });
  const user = await login();
  await user.selectOptions(await screen.findByLabelText('Antrenman özeti danışanı'), clientId);
  await screen.findByText('İlişki erişimi kontrol edilemedi.');
  expect(screen.queryByText('Toplam antrenman oturumu')).not.toBeInTheDocument();
  await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
  await screen.findByText('25');
  await user.click(screen.getByRole('button', { name: 'Özeti yenile' }));
  await screen.findByText('25');
  expect(
    fetchMock.mock.calls.filter(([url]) => String(url).endsWith('/workout-plans')),
  ).toHaveLength(3);
});
it('danışan değişiminde önceki yanıtı iptal eder ve diğer danışanda göstermez', async () => {
  let finish!: (value: Response) => void;
  const fetchMock = setup({
    planResponse: () =>
      new Promise<Response>((resolve) => {
        finish = resolve;
      }),
  });
  const user = await login();
  const picker = await screen.findByLabelText('Antrenman özeti danışanı');
  await user.selectOptions(picker, clientId);
  await user.selectOptions(picker, 'client-two');
  await screen.findByText('Danışanın aktif programı yok.');
  await act(async () => finish(response(plans)));
  expect(screen.queryByRole('link', { name: 'Kuvvet programı' })).not.toBeInTheDocument();
  expect(
    fetchMock.mock.calls.find(([url]) => String(url).endsWith(`${clientId}/workout-plans`))?.[1]
      ?.signal?.aborted,
  ).toBe(true);
});
it('demo paneli gerçek oturum sayısı veya API isteği üretmez', async () => {
  const fetchMock = setup();
  const user = userEvent.setup();
  await user.click(screen.getByRole('button', { name: 'Antrenör' }));
  await screen.findByText(/Antrenman özeti için gerçek Trainer hesabıyla giriş yapın/);
  expect(screen.queryByText('Toplam antrenman oturumu')).not.toBeInTheDocument();
  expect(fetchMock.mock.calls.some(([url]) => String(url).includes('workout-'))).toBe(false);
});

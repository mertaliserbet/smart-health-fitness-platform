import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { CreateWorkoutPlanRequest } from './types/workout';

const clientId = '9a97f2b9-2a82-45bd-b7f9-ae24fb73441d';
const otherClientId = '1ded8474-ebcb-4cb8-ab29-85c56dc53a57';
const planId = '78ddeebe-f4db-427f-9bda-22777ca56585';
const exerciseId = '1dd55d43-ee46-4769-94e0-bad9fcf79df1';
const clients = [
  {
    id: clientId,
    firstName: 'Mert',
    lastName: 'Şerbet',
    startDate: '2026-10-02',
    relationshipStatus: 'Active',
  },
  {
    id: otherClientId,
    firstName: 'Deniz',
    lastName: 'Yılmaz',
    startDate: '2026-09-21',
    relationshipStatus: 'Active',
  },
];
const exercises = [
  {
    id: exerciseId,
    name: 'Bench Press',
    description: 'Göğüs egzersizi',
    imageUrl: null,
    videoUrl: null,
  },
  {
    id: '81c2700a-4d8f-4f42-9ade-1c4c723a0082',
    name: 'Lat Pulldown',
    description: 'Sırt egzersizi',
    imageUrl: null,
    videoUrl: null,
  },
];
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function TestNavigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return <button onClick={() => void navigate(path)}>Test rotasını aç</button>;
}
function renderApp(path = `/programlar/${clientId}/yeni`) {
  render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
        <TestNavigation path={path} />
      </AuthProvider>
    </MemoryRouter>,
  );
}
function mockApi({
  post,
  roles = ['Trainer'],
  relation = clients,
  detail,
}: {
  post?: (request: CreateWorkoutPlanRequest) => Promise<Response> | Response;
  roles?: string[];
  relation?: typeof clients;
  detail?: unknown;
} = {}) {
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url, options) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: '2026-10-09T20:00:00Z',
        user: {
          id: 'trainer',
          firstName: 'Uğur',
          lastName: 'Çetin',
          email: 'trainer@example.com',
          roles,
        },
      });
    if (url === '/api/trainers/me/clients' || url === '/api/dietitians/me/clients')
      return response(relation);
    if (url === '/api/exercises') return response(exercises);
    if (url === `/api/users/${clientId}/workout-plans`)
      return options?.method === 'POST'
        ? post
          ? post(JSON.parse(String(options.body)))
          : new Response(null, { status: 201 })
        : response([]);
    if (url === `/api/workout-plans/${planId}`) return response(detail);
    return response({ detail: 'Endpoint bulunamadı.' }, 404);
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
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
async function fillForm() {
  const user = await login();
  await screen.findByLabelText('Program adı');
  await user.type(screen.getByLabelText('Program adı'), 'Yeni kuvvet programı');
  await user.clear(screen.getByLabelText('Başlangıç tarihi'));
  await user.type(screen.getByLabelText('Başlangıç tarihi'), '2026-10-12');
  await user.selectOptions(screen.getByLabelText('Egzersiz seç — 1. gün'), exerciseId);
  await user.click(screen.getByRole('button', { name: 'Egzersizi ekle — 1. gün' }));
  return user;
}
afterEach(() => vi.unstubAllGlobals());

describe('Trainer program atama akışı', () => {
  it('mevcut sözleşmeyle doğru danışana POST eder; gövdesiz 201 sonrası başarı gösterir', async () => {
    let sent: CreateWorkoutPlanRequest | undefined;
    const fetchMock = mockApi({
      post: (request) => {
        sent = request;
        return new Response(null, { status: 201 });
      },
    });
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    expect(await screen.findByText('Program danışana atandı.')).toBeInTheDocument();
    expect(sent).toEqual({
      name: 'Yeni kuvvet programı',
      description: null,
      startDate: '2026-10-12',
      endDate: null,
      days: [
        {
          name: '1. gün',
          dayNumber: 1,
          weekday: 'Monday',
          description: null,
          exercises: [
            {
              exerciseId,
              order: 1,
              sets: 3,
              reps: 10,
              durationSeconds: null,
              restSeconds: 60,
              weightKg: null,
              notes: null,
            },
          ],
        },
      ],
    });
    expect(
      fetchMock.mock.calls.filter(
        ([, options]) => options?.method === 'POST' && String(options.body).includes('Yeni kuvvet'),
      ),
    ).toHaveLength(1);
  });

  it('tarih ve set hatasında POST göndermez; alanlar korunur', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await fillForm();
    await user.type(screen.getByLabelText('Bitiş tarihi (isteğe bağlı)'), '2026-10-01');
    await user.clear(screen.getByLabelText('Set — 1. gün, 1. egzersiz'));
    await user.type(screen.getByLabelText('Set — 1. gün, 1. egzersiz'), '1.5');
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    expect(screen.getByText('Bitiş tarihi başlangıçtan önce olamaz.')).toBeInTheDocument();
    expect(screen.getByText('Pozitif bir tam sayı gir.')).toBeInTheDocument();
    expect(screen.getByLabelText('Program adı')).toHaveValue('Yeni kuvvet programı');
    expect(
      fetchMock.mock.calls.filter(
        ([url, options]) => String(url).endsWith('/workout-plans') && options?.method === 'POST',
      ),
    ).toHaveLength(0);
  });

  it('gün sırasını yeniden numaralar; süre hedefinde set/tekrar göndermez', async () => {
    let sent: CreateWorkoutPlanRequest | undefined;
    mockApi({
      post: (request) => {
        sent = request;
        return new Response(null, { status: 201 });
      },
    });
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Gün ekle' }));
    expect(
      screen.getByLabelText('Haftanın günü — 2. gün').querySelector('option[value="Monday"]'),
    ).toBeDisabled();
    await user.selectOptions(screen.getByLabelText('Egzersiz seç — 2. gün'), exerciseId);
    await user.click(screen.getByRole('button', { name: 'Egzersizi ekle — 2. gün' }));
    await user.selectOptions(screen.getByLabelText('Hedef türü — 2. gün, 1. egzersiz'), 'duration');
    await user.type(screen.getByLabelText('Süre (sn) — 2. gün, 1. egzersiz'), '120');
    await user.click(screen.getByRole('button', { name: '2. günü yukarı taşı' }));
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    await screen.findByText('Program danışana atandı.');
    expect(sent?.days.map((day) => ({ weekday: day.weekday, dayNumber: day.dayNumber }))).toEqual([
      { weekday: 'Tuesday', dayNumber: 1 },
      { weekday: 'Monday', dayNumber: 2 },
    ]);
    expect(sent?.days[0].exercises[0]).toMatchObject({
      order: 1,
      sets: null,
      reps: null,
      durationSeconds: 120,
    });
  });

  it('backend alan hatasını gösterir; başarısız atamada formu silmez ve örneğe geçmez', async () => {
    mockApi({
      post: () =>
        response(
          {
            detail: 'Tekrar sayısını kontrol edin.',
            errors: { 'Days[0].Exercises[0].Reps': ['Tekrar sayısı kabul edilmedi.'] },
          },
          400,
        ),
    });
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Tekrar sayısı kabul edilmedi.');
    expect(screen.getByLabelText('Tekrar — 1. gün, 1. egzersiz')).toHaveAttribute(
      'aria-invalid',
      'true',
    );
    expect(screen.getByLabelText('Program adı')).toHaveValue('Yeni kuvvet programı');
    expect(screen.queryByText('Program danışana atandı.')).not.toBeInTheDocument();
    expect(screen.queryByText('Örnek veri', { exact: true })).not.toBeInTheDocument();
  });

  it('egzersizleri taşırken sıra ve hedef değerlerini ilgili egzersizle birlikte gönderir', async () => {
    let sent: CreateWorkoutPlanRequest | undefined;
    mockApi({
      post: (request) => {
        sent = request;
        return new Response(null, { status: 201 });
      },
    });
    renderApp();
    const user = await fillForm();
    await user.selectOptions(screen.getByLabelText('Egzersiz seç — 1. gün'), exercises[1].id);
    await user.click(screen.getByRole('button', { name: 'Egzersizi ekle — 1. gün' }));
    await user.clear(screen.getByLabelText('Tekrar — 1. gün, 2. egzersiz'));
    await user.type(screen.getByLabelText('Tekrar — 1. gün, 2. egzersiz'), '12');
    await user.click(
      screen.getByRole('button', { name: 'Lat Pulldown, 1. gün, 2. egzersiz, yukarı taşı' }),
    );
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    await screen.findByText('Program danışana atandı.');
    expect(
      sent?.days[0].exercises.map(({ exerciseId, order, reps }) => ({ exerciseId, order, reps })),
    ).toEqual([
      { exerciseId: exercises[1].id, order: 1, reps: 12 },
      { exerciseId, order: 2, reps: 10 },
    ]);
  });

  it('form açıkken danışan ilişkisi sonlandırılmışsa atama isteğini göndermez', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await fillForm();
    const original = fetchMock.getMockImplementation()!;
    fetchMock.mockImplementation((url, options) =>
      url === '/api/trainers/me/clients' ? Promise.resolve(response([])) : original(url, options),
    );
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu danışana erişiminiz bulunmuyor.',
    );
    expect(
      fetchMock.mock.calls.some(
        ([url, options]) => String(url).endsWith('/workout-plans') && options?.method === 'POST',
      ),
    ).toBe(false);
    expect(screen.getByLabelText('Program adı')).toHaveValue('Yeni kuvvet programı');
  });

  it('atama sürerken ikinci gönderimi engeller; hata sonrası tekrar denenebilir', async () => {
    let finish!: (value: Response) => void;
    const post = vi.fn().mockImplementation(
      () =>
        new Promise<Response>((resolve) => {
          finish = resolve;
        }),
    );
    mockApi({ post });
    renderApp();
    const user = await fillForm();
    await user.dblClick(screen.getByRole('button', { name: 'Programı ata' }));
    await waitFor(() => expect(post).toHaveBeenCalledOnce());
    expect(screen.getByRole('button', { name: 'Atanıyor…' })).toBeDisabled();
    await act(async () => finish(response({ detail: 'Geçici sunucu hatası.' }, 500)));
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçici sunucu hatası.');
    expect(screen.getByRole('button', { name: 'Programı ata' })).toBeEnabled();
  });

  it('aktif ilişkisi olmayan danışanın formunu açmaz ve egzersiz API çağrısı yapmaz', async () => {
    const fetchMock = mockApi({ relation: [] });
    renderApp();
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu danışana erişiminiz bulunmuyor.',
    );
    expect(fetchMock.mock.calls.some(([url]) => url === '/api/exercises')).toBe(false);
    expect(screen.queryByLabelText('Program adı')).not.toBeInTheDocument();
  });

  it('başka danışanın programını URL değişikliğiyle göstermez', async () => {
    mockApi({ detail: { userId: otherClientId, name: 'Gizli program' } });
    renderApp(`/programlar/${clientId}/${planId}`);
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu program seçili danışana ait değil.',
    );
    expect(screen.queryByText('Gizli program')).not.toBeInTheDocument();
  });

  it('Dietitian rolü program sayfasını URL ile açamaz', async () => {
    mockApi({ roles: ['Dietitian'] });
    renderApp();
    await login();
    expect(screen.queryByLabelText('Program adı')).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Antrenman Programları' })).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Merhaba, Uğur.' })).toBeInTheDocument();
  });
});

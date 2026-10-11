import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type {
  CreateWorkoutPlanRequest,
  UpdateWorkoutPlanRequest,
  WorkoutPlanResponse,
} from './types/workout';

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
  put,
  roles = ['Trainer'],
  relation = clients,
  detail,
}: {
  post?: (request: CreateWorkoutPlanRequest) => Promise<Response> | Response;
  put?: (request: UpdateWorkoutPlanRequest) => Promise<Response> | Response;
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
    if (url === `/api/workout-plans/${planId}`)
      return options?.method === 'PUT'
        ? put
          ? put(JSON.parse(String(options.body)))
          : response({ detail: 'PUT unavailable' }, 500)
        : response(typeof detail === 'function' ? detail() : detail);
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

function editablePlan(): WorkoutPlanResponse {
  return {
    id: planId,
    userId: clientId,
    trainerId: 'trainer',
    updatedAt: null,
    name: 'Mevcut kuvvet programı',
    description: 'Program notu',
    startDate: '2026-10-01',
    endDate: null,
    isActive: true,
    days: [
      {
        id: 'day-one',
        name: 'Üst vücut',
        dayNumber: 1,
        weekday: 'Monday',
        description: null,
        exercises: [
          {
            id: 'item-one',
            exerciseId,
            exerciseName: 'Bench Press',
            order: 1,
            sets: 3,
            reps: 10,
            durationSeconds: null,
            restSeconds: 0,
            weightKg: 0,
            notes: null,
          },
        ],
      },
    ],
  };
}
const editPath = `/programlar/${clientId}/${planId}/duzenle`;

describe('Trainer program düzenleme akışı', () => {
  it('mevcut değerleri açar; plan/gün/egzersiz kimlikleri ve sürümle PUT gönderir, detayı yeniler', async () => {
    let plan = editablePlan();
    let sent: UpdateWorkoutPlanRequest | undefined;
    const fetchMock = mockApi({
      detail: () => plan,
      put: (request) => {
        sent = request;
        plan = {
          ...plan,
          ...request,
          updatedAt: '2026-10-11T12:00:00.123456Z',
          days: plan.days.map((day) => ({
            ...day,
            exercises: day.exercises.map((item) => ({ ...item, reps: 12 })),
          })),
        };
        return response(plan);
      },
    });
    renderApp(editPath);
    const user = await login();
    expect(await screen.findByLabelText('Program adı')).toHaveValue(plan.name);
    expect(screen.getByLabelText('Ağırlık (kg, isteğe bağlı) — 1. gün, 1. egzersiz')).toHaveValue(
      0,
    );
    expect(screen.getByLabelText('Bitiş tarihi (isteğe bağlı)')).toHaveValue('');
    await user.clear(screen.getByLabelText('Tekrar — 1. gün, 1. egzersiz'));
    await user.type(screen.getByLabelText('Tekrar — 1. gün, 1. egzersiz'), '12');
    await user.click(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
    await waitFor(() =>
      expect(screen.getByRole('status')).toHaveTextContent('Program güncellendi'),
    );
    expect(screen.getByText('3 set × 12 tekrar · 0 sn dinlenme · 0 kg')).toBeInTheDocument();
    expect(sent).toMatchObject({
      expectedUpdatedAt: null,
      days: [{ id: 'day-one', exercises: [{ id: 'item-one', exerciseId, reps: 12, weightKg: 0 }] }],
    });
    expect(sent).not.toHaveProperty('userId');
    expect(sent).not.toHaveProperty('trainerId');
    expect(
      fetchMock.mock.calls.some(
        ([, options]) =>
          options?.method === 'POST' && String(options.body).includes('Mevcut kuvvet'),
      ),
    ).toBe(false);
  });

  it('sıralamada kimliği korur; silinen satırı göndermez, yeni egzersize null kimlik verir', async () => {
    const plan = editablePlan();
    plan.updatedAt = '2026-10-11T10:00:00.654321Z';
    plan.days[0].exercises.push({
      ...plan.days[0].exercises[0],
      id: 'item-two',
      order: 2,
      exerciseName: 'Lat Pulldown',
      exerciseId: exercises[1].id,
    });
    let sent: UpdateWorkoutPlanRequest | undefined;
    mockApi({
      detail: plan,
      put: (request) => {
        sent = request;
        return response({ detail: 'Kontrol hatası' }, 500);
      },
    });
    renderApp(editPath);
    const user = await login();
    await screen.findByLabelText('Program adı');
    await user.click(
      screen.getByRole('button', { name: 'Lat Pulldown, 1. gün, 2. egzersiz, yukarı taşı' }),
    );
    await user.click(screen.getByRole('button', { name: 'Bench Press, 1. gün, 2. egzersiz, sil' }));
    await user.selectOptions(screen.getByLabelText('Egzersiz seç — 1. gün'), exerciseId);
    await user.click(screen.getByRole('button', { name: 'Egzersizi ekle — 1. gün' }));
    await user.click(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
    await screen.findByRole('alert');
    expect(sent).toMatchObject({
      expectedUpdatedAt: plan.updatedAt,
      days: [
        {
          id: 'day-one',
          exercises: [
            { id: 'item-two', exerciseId: exercises[1].id, order: 1 },
            { id: null, exerciseId, order: 2 },
          ],
        },
      ],
    });
    expect(JSON.stringify(sent)).not.toContain('item-one');
  });

  it('süre hedefi, not ve tarihleri mevcut programdan eksiksiz doldurur', async () => {
    const plan = editablePlan();
    plan.endDate = '2026-11-01';
    plan.days[0].description = 'Gün notu';
    Object.assign(plan.days[0].exercises[0], {
      sets: null,
      reps: null,
      durationSeconds: 45,
      weightKg: null,
      notes: 'Egzersiz notu',
    });
    mockApi({ detail: plan });
    renderApp(editPath);
    await login();
    await screen.findByLabelText('Program adı');
    expect(screen.getByLabelText('Süre (sn) — 1. gün, 1. egzersiz')).toHaveValue(45);
    expect(screen.getByLabelText('Gün açıklaması — 1. gün (isteğe bağlı)')).toHaveValue('Gün notu');
    expect(screen.getByLabelText('Egzersiz notu — 1. gün, 1. egzersiz (isteğe bağlı)')).toHaveValue(
      'Egzersiz notu',
    );
    expect(screen.getByLabelText('Bitiş tarihi (isteğe bağlı)')).toHaveValue('2026-11-01');
  });

  it('alan hatasında değerleri korur ve yeniden denemeye izin verir', async () => {
    mockApi({
      detail: editablePlan(),
      put: () =>
        response(
          {
            detail: 'Hedef geçersiz',
            errors: { 'days[0].exercises[0].reps': ['En fazla 20 tekrar.'] },
          },
          400,
        ),
    });
    renderApp(editPath);
    const user = await login();
    await screen.findByLabelText('Program adı');
    await user.type(screen.getByLabelText('Program adı'), ' güncel');
    await user.click(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('En fazla 20 tekrar');
    expect(screen.getByLabelText('Tekrar — 1. gün, 1. egzersiz')).toHaveAttribute(
      'aria-invalid',
      'true',
    );
    expect(screen.getByLabelText('Program adı')).toHaveValue('Mevcut kuvvet programı güncel');
    expect(screen.getByRole('button', { name: 'Değişiklikleri kaydet' })).toBeEnabled();
  });

  it('409 sonrası eski sürümle tekrar yazmaz; güncel programı açma yolu sunar', async () => {
    const fetchMock = mockApi({
      detail: editablePlan(),
      put: () => response({ detail: 'Program başka bir ekranda değişti.' }, 409),
    });
    renderApp(editPath);
    const user = await login();
    await screen.findByLabelText('Program adı');
    await user.click(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('başka bir ekranda değişti');
    expect(screen.getByRole('button', { name: 'Değişiklikleri kaydet' })).toBeDisabled();
    await user.click(screen.getByRole('link', { name: 'Güncel programı aç' }));
    await screen.findByRole('heading', { name: 'Mevcut kuvvet programı' });
    expect(fetchMock.mock.calls.filter(([, options]) => options?.method === 'PUT')).toHaveLength(1);
  });

  it.each([
    ['geçmiş', { isActive: false }, 'Geçmiş program'],
    ['başka oluşturan', { trainerId: 'other-trainer' }, 'Yalnızca oluşturduğun'],
    ['başka danışan', { userId: otherClientId }, 'seçili danışana ait değil'],
    ['eksik sürüm', { updatedAt: undefined }, 'güncel sürümü alınamadı'],
  ])('%s programın düzenleme formunu ve kataloğunu açmaz', async (_, changes, message) => {
    const fetchMock = mockApi({ detail: { ...editablePlan(), ...changes } });
    renderApp(editPath);
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent(message);
    expect(screen.queryByLabelText('Program adı')).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url === '/api/exercises')).toBe(false);
  });

  it.each([false, true])(
    'detayda yalnız aktif ve kendi programına düzenleme bağlantısı verir: %s',
    async (isActive) => {
      mockApi({ detail: { ...editablePlan(), isActive } });
      renderApp(`/programlar/${clientId}/${planId}`);
      await login();
      await screen.findByRole('heading', { name: 'Mevcut kuvvet programı' });
      expect(!!screen.queryByRole('link', { name: 'Programı düzenle' })).toBe(isActive);
    },
  );

  it.each(['Admin', 'Dietitian'])('%s düzenleme rotasına erişemez', async (role) => {
    const fetchMock = mockApi({ roles: [role], detail: editablePlan() });
    renderApp(editPath);
    await login();
    expect(screen.queryByLabelText('Program adı')).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => url === `/api/workout-plans/${planId}`)).toBe(
      false,
    );
  });

  it.each([new Response(null, { status: 204 }), response({ id: 'wrong' })])(
    'boş veya yanlış güncelleme yanıtını başarı saymaz',
    async (result) => {
      mockApi({ detail: editablePlan(), put: () => result });
      renderApp(editPath);
      const user = await login();
      await screen.findByLabelText('Program adı');
      await user.click(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
      expect(await screen.findByRole('alert')).toHaveTextContent('Güncelleme yanıtı doğrulanamadı');
      expect(screen.queryByRole('status')).not.toBeInTheDocument();
      expect(screen.getByLabelText('Program adı')).toHaveValue('Mevcut kuvvet programı');
    },
  );

  it('gönderim sırasında ikinci PUT isteğini engeller', async () => {
    let finish!: (result: Response) => void;
    const fetchMock = mockApi({
      detail: editablePlan(),
      put: () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    });
    renderApp(editPath);
    const user = await login();
    await screen.findByLabelText('Program adı');
    await user.dblClick(screen.getByRole('button', { name: 'Değişiklikleri kaydet' }));
    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'Kaydediliyor…' })).toBeDisabled(),
    );
    expect(fetchMock.mock.calls.filter(([, options]) => options?.method === 'PUT')).toHaveLength(1);
    await act(async () => finish(response({ detail: 'Geçici hata' }, 500)));
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçici hata');
  });
});

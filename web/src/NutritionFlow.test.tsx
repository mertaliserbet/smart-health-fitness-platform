import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { Role } from './types/api';
import type { CreateNutritionGoalRequest, NutritionGoalResponse } from './types/nutrition';

const clientId = '9a97f2b9-2a82-45bd-b7f9-ae24fb73441d';
const goal: NutritionGoalResponse = {
  id: '69116652-f078-4a9f-b30e-3ddc37ac737e',
  dailyCalories: 2400,
  proteinGrams: 160,
  carbohydrateGrams: 270,
  fatGrams: 75,
  waterMl: 2500,
  startDate: '2026-10-01',
  endDate: null,
  isActive: true,
};
const clients = [
  {
    id: clientId,
    firstName: 'Mert',
    lastName: 'Şerbet',
    relationshipStatus: 'Active',
    startDate: '2026-10-02',
  },
];
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

function TestNavigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return <button onClick={() => void navigate(path)}>Test rotasını aç</button>;
}
function renderApp(path = `/beslenme-hedefleri/${clientId}/yeni`) {
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
  roles = ['Dietitian'],
  relation = clients,
  list,
}: {
  post?: (request: CreateNutritionGoalRequest) => Promise<Response> | Response;
  roles?: Role[];
  relation?: typeof clients;
  list?: () => Response;
} = {}) {
  let goals = [goal];
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url, options) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: '2026-10-09T20:00:00Z',
        user: {
          id: 'dietitian',
          firstName: 'Uğur',
          lastName: 'Çetin',
          email: 'dietitian@example.com',
          roles,
        },
      });
    if (url === '/api/dietitians/me/clients' || url === '/api/trainers/me/clients')
      return response(relation);
    if (url === '/api/users?page=1&pageSize=20')
      return response({ items: [], totalCount: 0, totalPages: 0, page: 1, pageSize: 20 });
    if (url === `/api/users/${clientId}/nutrition-goals`) {
      if (options?.method !== 'POST') return list ? list() : response(goals);
      const request = JSON.parse(String(options.body)) as CreateNutritionGoalRequest;
      if (post) return post(request);
      const created = { ...request, id: 'created-goal', isActive: true };
      goals = [created, ...goals.map((value) => ({ ...value, isActive: false }))];
      return response(created, 201);
    }
    return response({ detail: 'Endpoint bulunamadı.' }, 404);
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}
async function login() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'dietitian@example.com');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
async function fillForm() {
  const user = await login();
  await screen.findByLabelText('Günlük kalori (kcal)');
  for (const [label, value] of [
    ['Günlük kalori (kcal)', '2300'],
    ['Protein (g)', '150.5'],
    ['Karbonhidrat (g)', '250'],
    ['Yağ (g)', '70'],
    ['Su hedefi (ml)', '2500'],
    ['Başlangıç tarihi', '2026-10-12'],
  ]) {
    await user.clear(screen.getByLabelText(label));
    await user.type(screen.getByLabelText(label), value);
  }
  return user;
}
const nutritionPosts = (mock: ReturnType<typeof mockApi>) =>
  mock.mock.calls.filter(
    ([url, options]) => String(url).endsWith('/nutrition-goals') && options?.method === 'POST',
  );
afterEach(() => vi.unstubAllGlobals());

describe('Dietitian beslenme hedefi akışı', () => {
  it('sözleşmedeki alanları doğru danışana gönderir; 201 sonrası geçmişi yeniden yükler', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(await screen.findByText('Beslenme hedefi danışana atandı.')).toBeInTheDocument();
    expect(JSON.parse(String(nutritionPosts(fetchMock)[0][1]?.body))).toEqual({
      dailyCalories: 2300,
      proteinGrams: 150.5,
      carbohydrateGrams: 250,
      fatGrams: 70,
      waterMl: 2500,
      startDate: '2026-10-12',
      endDate: null,
    });
    expect(await screen.findByText('2 hedef')).toBeInTheDocument();
    expect(screen.getByText('Geçmiş hedef')).toBeInTheDocument();
    expect(nutritionPosts(fetchMock)).toHaveLength(1);
    expect(
      fetchMock.mock.calls.filter(
        ([url, options]) => String(url).endsWith('/nutrition-goals') && options?.method !== 'POST',
      ),
    ).toHaveLength(2);
  });

  it('boş/negatif sayı ve ters tarih aralığında atamaz; girdiler korunur', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await fillForm();
    await user.clear(screen.getByLabelText('Günlük kalori (kcal)'));
    await user.clear(screen.getByLabelText('Protein (g)'));
    await user.type(screen.getByLabelText('Protein (g)'), '-1');
    await user.type(screen.getByLabelText('Bitiş tarihi (isteğe bağlı)'), '2026-10-01');
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(screen.getByText('Bu alan gerekli.')).toBeInTheDocument();
    expect(screen.getByText('Sıfır veya daha büyük bir sayı gir.')).toBeInTheDocument();
    expect(screen.getByText('Bitiş tarihi başlangıçtan önce olamaz.')).toBeInTheDocument();
    expect(screen.getByLabelText('Su hedefi (ml)')).toHaveValue(2500);
    expect(nutritionPosts(fetchMock)).toHaveLength(0);
  });

  it('API alan hatalarını gösterir; formu ve gerçek oturumu korur', async () => {
    mockApi({
      post: () => response({ errors: { DailyCalories: ['Kalori hedefi kabul edilmedi.'] } }, 400),
    });
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Kalori hedefi kabul edilmedi.');
    expect(screen.getByLabelText('Günlük kalori (kcal)')).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByLabelText('Günlük kalori (kcal)')).toHaveValue(2300);
    expect(screen.queryByText('Örnek veri', { exact: true })).not.toBeInTheDocument();
    expect(screen.queryByText('Beslenme hedefi danışana atandı.')).not.toBeInTheDocument();
  });

  it('form açıkken sonlanan danışan ilişkisi için POST yapmaz', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await fillForm();
    const original = fetchMock.getMockImplementation()!;
    fetchMock.mockImplementation((url, options) =>
      url === '/api/dietitians/me/clients' ? Promise.resolve(response([])) : original(url, options),
    );
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu danışana erişiminiz bulunmuyor.',
    );
    expect(nutritionPosts(fetchMock)).toHaveLength(0);
    expect(screen.getByLabelText('Günlük kalori (kcal)')).toHaveValue(2300);
  });

  it('aktif ilişkisi olmayan danışanın hedeflerini URL üzerinden okumaz', async () => {
    const fetchMock = mockApi({ relation: [{ ...clients[0], relationshipStatus: 'Ended' }] });
    renderApp(`/beslenme-hedefleri/${clientId}`);
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu danışana erişiminiz bulunmuyor.',
    );
    expect(fetchMock.mock.calls.some(([url]) => String(url).endsWith('/nutrition-goals'))).toBe(
      false,
    );
    expect(screen.queryByRole('link', { name: 'Yeni hedef' })).not.toBeInTheDocument();
  });

  it.each<Role>(['Trainer', 'Admin'])('%s rolü hedef ekranını açamaz', async (role) => {
    const fetchMock = mockApi({ roles: [role] });
    renderApp();
    await login();
    expect(screen.queryByLabelText('Günlük kalori (kcal)')).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Beslenme Hedefleri' })).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => String(url).endsWith('/nutrition-goals'))).toBe(
      false,
    );
  });

  it('bekleyen atamada ikinci gönderimi engeller; hata sonrası tekrar denenir', async () => {
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
    await user.dblClick(screen.getByRole('button', { name: 'Hedefi ata' }));
    await waitFor(() => expect(post).toHaveBeenCalledOnce());
    expect(screen.getByRole('button', { name: 'Atanıyor…' })).toBeDisabled();
    await act(async () => finish(response({ detail: 'Geçici sunucu hatası.' }, 500)));
    expect(await screen.findByRole('alert')).toHaveTextContent('Geçici sunucu hatası.');
    post.mockImplementationOnce((request: CreateNutritionGoalRequest) =>
      response({ ...request, id: 'retry-goal', isActive: true }, 201),
    );
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    await screen.findByText('Beslenme hedefi danışana atandı.');
    expect(post).toHaveBeenCalledTimes(2);
  });

  it.each([201, 204])('gerekli hedef yanıtı olmayan %s cevabını başarı saymaz', async (status) => {
    mockApi({ post: () => new Response(null, { status }) });
    renderApp();
    const user = await fillForm();
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(/yanıtı|okunamadı/);
    expect(screen.getByLabelText('Günlük kalori (kcal)')).toHaveValue(2300);
    expect(screen.queryByText('Beslenme hedefi danışana atandı.')).not.toBeInTheDocument();
  });

  it('hedef API hatasını örnek veriyle gizlemez; yükleme tekrar denenebilir', async () => {
    let failing = true;
    mockApi({
      list: () => (failing ? response({ detail: 'Hedefler yüklenemedi.' }, 503) : response([goal])),
    });
    renderApp(`/beslenme-hedefleri/${clientId}`);
    const user = await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('Hedefler yüklenemedi.');
    expect(screen.queryByText('Örnek veri', { exact: true })).not.toBeInTheDocument();
    failing = false;
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(await screen.findByText('1 hedef')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: '2.400 kcal / gün' })).toBeInTheDocument();
  });
});

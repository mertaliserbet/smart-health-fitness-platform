import { afterEach, expect, it, vi } from 'vitest';
import { act, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { Role } from './types/api';
import type { NutritionRecordResponse } from './types/nutritionProgress';
import type { NutritionGoalResponse } from './types/nutrition';
import { localDate } from './utils/date';

const clientId = 'client';
const clients = [
  {
    id: clientId,
    firstName: 'Deniz',
    lastName: 'Test',
    relationshipStatus: 'Active',
    startDate: '2026-10-01',
  },
];
const at = new Date();
at.setHours(0, 0, 0, 0);
const records: NutritionRecordResponse[] = [
  {
    id: 'lunch',
    userId: clientId,
    mealType: 'Lunch',
    name: 'Öğle yemeği',
    calories: 650.25,
    proteinGrams: 48.75,
    carbohydrateGrams: 72.1,
    fatGrams: 16,
    portionDescription: 'Bir porsiyon',
    sourceType: 'Manual',
    foodRecognitionLogId: null,
    consumedAt: at.toISOString(),
    createdAt: at.toISOString(),
  },
  {
    id: 'snack',
    userId: clientId,
    mealType: 'Snack',
    name: 'Sıfır kayıt',
    calories: 0,
    proteinGrams: 0,
    carbohydrateGrams: 0,
    fatGrams: 0,
    portionDescription: null,
    sourceType: 'Manual',
    foodRecognitionLogId: null,
    consumedAt: at.toISOString(),
    createdAt: at.toISOString(),
  },
];
const goal: NutritionGoalResponse = {
  id: 'goal',
  isActive: true,
  dailyCalories: 600,
  proteinGrams: 60,
  carbohydrateGrams: 100,
  fatGrams: 0,
  waterMl: 2000,
  startDate: localDate(),
  endDate: null,
};
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
function Navigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return (
    <>
      <button onClick={() => void navigate(path)}>Test rotasını aç</button>
      <button onClick={() => void navigate('/danisanlar/other/beslenme-ilerlemesi')}>
        Diğer danışana geç
      </button>
    </>
  );
}
function setup({
  role = 'Dietitian',
  relation = clients,
  values = records,
  goals = [goal],
  path = `/danisanlar/${clientId}/beslenme-ilerlemesi`,
  recordResponse,
}: {
  role?: Role;
  relation?: typeof clients;
  values?: NutritionRecordResponse[];
  goals?: NutritionGoalResponse[];
  path?: string;
  recordResponse?: () => Response | Promise<Response>;
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
    if (url === '/api/dietitians/me/clients' || url === '/api/trainers/me/clients')
      return response(relation);
    if (url === `/api/users/${clientId}/nutrition-records`)
      return recordResponse ? recordResponse() : response(values);
    if (url === `/api/users/${clientId}/nutrition-goals`) return response(goals);
    if (url === `/api/users/${clientId}`)
      return response({
        id: clientId,
        firstName: 'Deniz',
        lastName: 'Test',
        email: 'client@example.test',
        roles: ['User'],
        isActive: true,
      });
    if (url === '/api/users?page=1&pageSize=20')
      return response({ items: [], totalCount: 0, totalPages: 0, page: 1, pageSize: 20 });
    return response({ detail: 'Endpoint bulunamadı.' }, 404);
  });
  vi.stubGlobal('fetch', fetchMock);
  render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
        <Navigation path={path} />
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
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
afterEach(() => vi.unstubAllGlobals());
it('diyetisyen profilden günlük toplam, hedef aşımı ve öğünleri görür; filtre toplamı değiştirmez', async () => {
  const fetchMock = setup({ path: `/danisanlar/${clientId}` });
  const user = await login();
  await user.click(await screen.findByRole('link', { name: 'Beslenme ilerlemesi' }));
  const summary = await screen.findByRole('region', { name: 'Günlük beslenme özeti' });
  expect(within(summary).getByText('650,25 kcal')).toBeInTheDocument();
  expect(within(summary).getByText('50,25 kcal')).toBeInTheDocument();
  expect(within(summary).getAllByText('Hedef aşımı')).toHaveLength(2);
  await user.selectOptions(screen.getByLabelText('Öğün filtresi'), 'Snack');
  expect(screen.queryByText('Öğle yemeği')).not.toBeInTheDocument();
  expect(screen.getByText('Sıfır kayıt')).toBeInTheDocument();
  expect(within(summary).getByText('650,25 kcal')).toBeInTheDocument();
  expect(
    fetchMock.mock.calls.some(
      ([url, options]) =>
        String(url).includes('nutrition-records') && (options?.method ?? 'GET') !== 'GET',
    ),
  ).toBe(false);
});
it('grafik dönemini ve makroyu değiştirir; kayıtsız günler tabloda boş kalır', async () => {
  setup();
  const user = await login();
  await screen.findByRole('region', { name: 'Günlük beslenme özeti' });
  await user.selectOptions(screen.getByLabelText('Grafik dönemi'), '7');
  await user.selectOptions(screen.getByLabelText('Grafik değeri'), 'proteinGrams');
  expect(screen.getByRole('img', { name: 'Protein geçmişi grafiği' })).toBeInTheDocument();
  await user.click(screen.getByText('Günlük toplamları tablo olarak gör'));
  const table = screen.getByRole('table', { name: 'Günlük toplam tablosu' });
  expect(within(table).getAllByRole('row')).toHaveLength(8);
  expect(within(table).getAllByText('—')).toHaveLength(6);
});
it('boş kayıt ve hedef yokluğunda tüketim/fark uydurmaz', async () => {
  setup({ values: [], goals: [] });
  await login();
  await screen.findByText(/gerçek tüketim bilinmediği/i);
  expect(screen.getByText(/geçerli aktif beslenme hedefi yok/i)).toBeInTheDocument();
  expect(screen.getByText('Bu dönemde beslenme kaydı yok.')).toBeInTheDocument();
  expect(screen.queryByRole('img', { name: 'Kalori geçmişi grafiği' })).not.toBeInTheDocument();
});
it('geçmiş pasif hedefi ve seçili güne uymayan aktif hedefi karşılaştırmaz', async () => {
  setup({
    goals: [
      { ...goal, isActive: false },
      { ...goal, id: 'future', startDate: '9998-01-01' },
    ],
  });
  await login();
  await screen.findByText(/geçerli aktif beslenme hedefi yok/i);
  const calories = screen.getByRole('article', { name: 'Kalori karşılaştırması' });
  expect(within(calories).getAllByText('—')).toHaveLength(2);
});
it.each(['Trainer', 'Admin'] as const)('%s rotaya ve kayıtlara erişemez', async (role) => {
  const fetchMock = setup({ role });
  await login();
  expect(screen.queryByRole('heading', { name: 'Beslenme ilerlemesi' })).not.toBeInTheDocument();
  expect(fetchMock.mock.calls.some(([url]) => String(url).includes('/nutrition-records'))).toBe(
    false,
  );
});
it('atanmamış danışanda kayıt ve hedef isteğini başlatmaz', async () => {
  const fetchMock = setup({ relation: [] });
  await login();
  await screen.findByText('Bu danışana erişiminiz bulunmuyor.');
  expect(
    fetchMock.mock.calls.some(
      ([url]) =>
        String(url).includes('nutrition-records') || String(url).includes('nutrition-goals'),
    ),
  ).toBe(false);
});
it('API hatasını gösterir ve tekrar denemede gerçek kaydı yükler', async () => {
  let attempt = 0;
  setup({
    recordResponse: () =>
      ++attempt === 1 ? response({ detail: 'Beslenme okunamadı.' }, 503) : response(records),
  });
  const user = await login();
  await screen.findByText('Beslenme okunamadı.');
  expect(screen.queryByText('Öğle yemeği')).not.toBeInTheDocument();
  await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
  await screen.findByText('Öğle yemeği');
});
it('öğün sayfasını filtre değişiminde sıfırlar', async () => {
  setup({
    values: Array.from({ length: 21 }, (_, index) => ({
      ...records[0],
      id: `row-${index}`,
      name: `Öğün ${index}`,
      mealType: index === 20 ? 'Snack' : 'Lunch',
    })),
  });
  const user = await login();
  await screen.findByText('Öğün 0');
  const pager = screen.getByRole('navigation', { name: 'Öğün kayıt sayfaları' });
  await user.click(within(pager).getByRole('button', { name: 'Sonraki sayfa' }));
  expect(screen.getByText('Öğün 20')).toBeInTheDocument();
  await user.selectOptions(screen.getByLabelText('Öğün filtresi'), 'Lunch');
  expect(screen.getByText('Öğün 0')).toBeInTheDocument();
  expect(screen.queryByText('Öğün 20')).not.toBeInTheDocument();
});
it('danışan değişince geç gelen yanıtı iptal eder ve önceki veriyi göstermez', async () => {
  let finish!: (value: Response) => void;
  const fetchMock = setup({
    recordResponse: () =>
      new Promise<Response>((resolve) => {
        finish = resolve;
      }),
  });
  const user = await login();
  await user.click(screen.getByRole('button', { name: 'Diğer danışana geç' }));
  await screen.findByText('Bu danışana erişiminiz bulunmuyor.');
  await act(async () => finish(response(records)));
  expect(screen.queryByText('Öğle yemeği')).not.toBeInTheDocument();
  const signal = fetchMock.mock.calls.find(([url]) =>
    String(url).endsWith('/nutrition-records'),
  )?.[1]?.signal;
  expect(signal?.aborted).toBe(true);
});

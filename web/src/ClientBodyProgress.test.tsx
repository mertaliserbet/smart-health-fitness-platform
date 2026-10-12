import { afterEach, expect, it, vi } from 'vitest';
import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { Role } from './types/api';
import type { BodyMeasurementResponse, WeightRecordResponse } from './types/progress';

const clientId = 'client';
const clients = [
  {
    id: clientId,
    firstName: 'Danışan',
    lastName: 'Test',
    relationshipStatus: 'Active',
    startDate: '2026-10-01',
  },
];
const date = (days: number) => new Date(Date.now() - days * 86400000).toISOString();
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
function Navigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return (
    <>
      <button onClick={() => void navigate(path)}>Test rotasını aç</button>
      <button onClick={() => void navigate('/danisanlar/other/ilerleme')}>
        Diğer danışana geç
      </button>
    </>
  );
}
function setup({
  role = 'Trainer',
  relation = clients,
  weights = [
    { id: 'recent', weightKg: 80, recordedAt: date(1) },
    { id: 'old', weightKg: 85, recordedAt: date(120) },
  ],
  measurements = [],
  path = `/danisanlar/${clientId}/ilerleme`,
  weightResponse,
}: {
  role?: Role;
  relation?: typeof clients;
  weights?: WeightRecordResponse[];
  measurements?: BodyMeasurementResponse[];
  path?: string;
  weightResponse?: () => Response | Promise<Response>;
} = {}) {
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: date(-1),
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
    if (url === `/api/users/${clientId}/weight-records`)
      return weightResponse ? weightResponse() : response(weights);
    if (url === `/api/users/${clientId}/body-measurements`) return response(measurements);
    if (url === `/api/users/${clientId}`)
      return response({
        id: clientId,
        firstName: 'Danışan',
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
async function login(role = 'Trainer') {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'advisor@example.test');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  if (role === 'User') await screen.findByText(/mobil uygulama/i);
  else await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
afterEach(() => vi.unstubAllGlobals());
it.each(['Trainer', 'Dietitian'] as const)(
  '%s profil bağlantısından gerçek ölçümleri dönem seçerek görür',
  async (role) => {
    const fetchMock = setup({ role, path: `/danisanlar/${clientId}` });
    const user = await login(role);
    await user.click(await screen.findByRole('link', { name: 'Kilo / Vücut ilerlemesi' }));
    const table = await screen.findByRole('table', { name: 'Kilo kayıtları' });
    expect(within(table).getAllByRole('row')).toHaveLength(2);
    expect(screen.getByText('En az iki dolu ölçüm gerekli.')).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Dönem'), 'all');
    expect(
      within(screen.getByRole('table', { name: 'Kilo kayıtları' })).getAllByRole('row'),
    ).toHaveLength(3);
    expect(screen.getByText('-5 kg')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Kilo geçmişi grafiği' })).toBeInTheDocument();
    expect(
      fetchMock.mock.calls.filter(([url]) => String(url).includes('weight-records')),
    ).toHaveLength(1);
    expect(
      fetchMock.mock.calls.some(
        ([, options]) => options?.method === 'POST' && String(options.body).includes('weightKg'),
      ),
    ).toBe(false);
  },
);
it('eksik alanı sıfır saymaz, grafik çizgisini keser ve yüzde sıfırı gösterir', async () => {
  const base = {
    chestCm: null,
    waistCm: null,
    hipCm: null,
    armCm: null,
    thighCm: null,
    bodyFatPercentage: null,
  };
  setup({
    measurements: [
      { ...base, id: 'last', recordedAt: date(1), armCm: 30, bodyFatPercentage: 0 },
      { ...base, id: 'gap', recordedAt: date(2), chestCm: 100 },
      { ...base, id: 'first', recordedAt: date(3), armCm: 32, bodyFatPercentage: 2 },
    ],
  });
  const user = await login();
  await screen.findByLabelText('Vücut ölçümü');
  expect(screen.getByText('Bu dönem için bel ölçümü yok.')).toBeInTheDocument();
  await user.selectOptions(screen.getByLabelText('Vücut ölçümü'), 'armCm');
  const region = screen.getByRole('region', { name: 'Kol ilerlemesi' });
  expect(within(region).getByText('-2 cm')).toBeInTheDocument();
  expect(region.querySelectorAll('polyline')).toHaveLength(0);
  expect(region.querySelectorAll('circle')).toHaveLength(2);
  expect(within(region).getByRole('cell', { name: '—' })).toBeInTheDocument();
  await user.selectOptions(screen.getByLabelText('Vücut ölçümü'), 'bodyFatPercentage');
  expect(
    within(screen.getByRole('table', { name: 'Vücut yağ oranı kayıtları' })).getByRole('cell', {
      name: '0',
    }),
  ).toBeInTheDocument();
});
it('boş dönemde kayıt olmadığını söyler; örnek ölçüm oluşturmaz', async () => {
  setup({ weights: [] });
  await login();
  expect(await screen.findByText('Bu dönem için kilo kaydı yok.')).toBeInTheDocument();
  expect(screen.getByText('Bu dönem için vücut ölçümü kaydı yok.')).toBeInTheDocument();
  expect(screen.queryByRole('img')).not.toBeInTheDocument();
});
it('bağlantısı olmayan danışanın ölçüm API’sini çağırmaz', async () => {
  const fetchMock = setup({ relation: [] });
  await login();
  expect(await screen.findByRole('alert')).toHaveTextContent('Bu danışana erişiminiz bulunmuyor.');
  expect(
    fetchMock.mock.calls.some(
      ([url]) =>
        String(url).includes('weight-records') || String(url).includes('body-measurements'),
    ),
  ).toBe(false);
});
it('Admin doğrudan ilerleme rotasını açınca ölçüm isteği yapmaz', async () => {
  const fetchMock = setup({ role: 'Admin' });
  await login('Admin');
  expect(await screen.findByRole('heading', { name: 'Merhaba, Uğur.' })).toBeInTheDocument();
  expect(
    screen.queryByRole('heading', { name: 'Kilo / Vücut ilerlemesi' }),
  ).not.toBeInTheDocument();
  expect(
    fetchMock.mock.calls.some(
      ([url]) =>
        String(url).includes('weight-records') || String(url).includes('body-measurements'),
    ),
  ).toBe(false);
});
it('API hatasını gösterir ve tekrar denemede güncel kayıtları yükler', async () => {
  let failed = true;
  setup({
    weightResponse: () =>
      failed ? response({ detail: 'İlerleme yüklenemedi.' }, 500) : response([]),
  });
  const user = await login();
  expect(await screen.findByRole('alert')).toHaveTextContent('İlerleme yüklenemedi.');
  expect(screen.queryByRole('table')).not.toBeInTheDocument();
  failed = false;
  await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
  expect(await screen.findByText('Bu dönem için kilo kaydı yok.')).toBeInTheDocument();
});
it('danışan değişiminde eski isteği iptal eder ve geç gelen kayıtları göstermez', async () => {
  let finish!: (value: Response) => void;
  const pending = new Promise<Response>((resolve) => {
    finish = resolve;
  });
  const fetchMock = setup({ weightResponse: () => pending });
  const user = await login();
  await waitFor(() =>
    expect(fetchMock.mock.calls.some(([url]) => url === '/api/users/client/weight-records')).toBe(
      true,
    ),
  );
  const oldSignal = fetchMock.mock.calls.find(
    ([url]) => url === '/api/users/client/weight-records',
  )![1]!.signal;
  await user.click(screen.getByRole('button', { name: 'Diğer danışana geç' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Bu danışana erişiminiz bulunmuyor.');
  expect(oldSignal?.aborted).toBe(true);
  await act(async () => finish(response([{ id: 'late', recordedAt: date(1), weightKg: 80 }])));
  expect(screen.queryByRole('table', { name: 'Kilo kayıtları' })).not.toBeInTheDocument();
});
it('kayıt tablosunu sayfalar ve dönem değişiminde ilk sayfaya döner', async () => {
  setup({
    weights: Array.from({ length: 25 }, (_, i) => ({
      id: String(i),
      weightKg: 80 + i,
      recordedAt: date(i + 1),
    })),
  });
  const user = await login();
  const pagination = await screen.findByRole('navigation', { name: 'Kilo kayıt sayfaları' });
  await user.click(within(pagination).getByRole('button', { name: 'Sonraki sayfa' }));
  expect(
    within(screen.getByRole('table', { name: 'Kilo kayıtları' })).getAllByRole('row'),
  ).toHaveLength(6);
  await user.selectOptions(screen.getByLabelText('Dönem'), '30');
  expect(screen.getByText('Sayfa 1 / 2')).toBeInTheDocument();
});

import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import type { CreateExerciseRequest, ExerciseDetailResponse } from './types/exercise';

const exerciseId = '1dd55d43-ee46-4769-94e0-bad9fcf79df1';
const existingExercise: ExerciseDetailResponse = {
  id: exerciseId,
  name: 'Bench Press',
  description: 'Göğüs egzersizi',
  instructions: 'Sırtını sabit tut.',
  videoUrl: 'https://example.test/video',
  imageUrl: null,
  isActive: true,
};
const passiveExercise: ExerciseDetailResponse = {
  ...existingExercise,
  id: '81c2700a-4d8f-4f42-9ade-1c4c723a0082',
  name: 'Lat Pulldown',
  isActive: false,
};
const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function TestNavigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return <button onClick={() => void navigate(path)}>Test rotasını aç</button>;
}
function renderApp(path = '/egzersizler') {
  return render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
        <TestNavigation path={path} />
      </AuthProvider>
    </MemoryRouter>,
  );
}
function mockApi({
  role = 'Admin',
  save,
  detail,
  list,
}: {
  role?: string;
  save?: (request: CreateExerciseRequest, options: RequestInit) => Response | Promise<Response>;
  detail?: () => Response;
  list?: () => Response;
} = {}) {
  let exercises = [{ ...existingExercise }, { ...passiveExercise }];
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url, options) => {
    if (url === '/api/auth/login')
      return response({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: '2099-10-09T20:00:00Z',
        user: {
          id: 'staff',
          firstName: 'Uğur',
          lastName: 'Çetin',
          email: 'staff@example.test',
          roles: [role],
        },
      });
    if (String(url).startsWith('/api/users?page='))
      return response({ items: [], totalCount: 0, page: 1, pageSize: 20 });
    if (url === '/api/trainers/me/clients' || url === '/api/dietitians/me/clients')
      return response([]);
    if ((url === '/api/exercises' && options?.method === 'POST') || options?.method === 'PUT') {
      const request = JSON.parse(String(options.body)) as CreateExerciseRequest;
      if (save) return save(request, options);
      const saved = { ...request, id: exerciseId };
      exercises = [saved, ...exercises.filter((exercise) => exercise.id !== exerciseId)];
      return response(saved, options.method === 'POST' ? 201 : 200);
    }
    if (url === '/api/exercises?includeInactive=true') return list ? list() : response(exercises);
    if (url === '/api/exercises')
      return response(exercises.filter((exercise) => exercise.isActive));
    if (url === `/api/exercises/${exerciseId}`) return detail ? detail() : response(exercises[0]);
    return response({ detail: 'Endpoint bulunamadı.' }, 404);
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}
async function login() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'staff@example.test');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
const saveCalls = (fetchMock: ReturnType<typeof mockApi>) =>
  fetchMock.mock.calls.filter(
    ([url, options]) =>
      String(url).startsWith('/api/exercises') &&
      (options?.method === 'POST' || options?.method === 'PUT'),
  );

afterEach(() => vi.unstubAllGlobals());

describe('Admin egzersiz yönetimi', () => {
  it('aktif/pasif kataloğunu getirir; durum ve isim filtrelerini birlikte uygular', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await login();
    await screen.findByRole('heading', { name: 'Bench Press' });
    expect(screen.getByRole('heading', { name: 'Lat Pulldown' })).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Durum'), 'inactive');
    expect(screen.queryByRole('heading', { name: 'Bench Press' })).not.toBeInTheDocument();
    await user.type(screen.getByLabelText('Egzersizleri isimle ara'), 'bench');
    expect(screen.getByText('Filtrelerle eşleşen egzersiz yok')).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Durum'), 'active');
    expect(screen.getByRole('heading', { name: 'Bench Press' })).toBeInTheDocument();
    expect(
      fetchMock.mock.calls.some(([url]) => url === '/api/exercises?includeInactive=true'),
    ).toBe(true);
  });

  it('tam sözleşmeyle POST gönderir; alanları kırpar ve kayıttan sonra kataloğu yeniden okur', async () => {
    const fetchMock = mockApi();
    renderApp('/egzersizler/yeni');
    const user = await login();
    await screen.findByLabelText('Egzersiz adı');
    expect(screen.getByLabelText('Katalogda aktif')).toBeChecked();
    await user.type(screen.getByLabelText('Egzersiz adı'), '  Squat  ');
    await user.type(
      screen.getByLabelText('Uygulama talimatları (isteğe bağlı)'),
      '  Kontrollü hareket et.  ',
    );
    await user.click(screen.getByLabelText('Katalogda aktif'));
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    await screen.findByText('Egzersiz kaydedildi.');
    const calls = saveCalls(fetchMock);
    expect(calls).toHaveLength(1);
    expect(calls[0][0]).toBe('/api/exercises');
    expect(JSON.parse(String(calls[0][1]?.body))).toEqual({
      name: 'Squat',
      description: null,
      instructions: 'Kontrollü hareket et.',
      videoUrl: null,
      imageUrl: null,
      isActive: false,
    });
    const card = (await screen.findByRole('heading', { name: 'Squat' })).closest('article')!;
    expect(within(card).getByText('Pasif')).toBeInTheDocument();
  });

  it('PUT sırasında mevcut talimatları ve bağlantıları korur', async () => {
    const fetchMock = mockApi();
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    const user = await login();
    expect(await screen.findByLabelText('Egzersiz adı')).toHaveValue('Bench Press');
    expect(screen.getByLabelText('Uygulama talimatları (isteğe bağlı)')).toHaveValue(
      'Sırtını sabit tut.',
    );
    await user.clear(screen.getByLabelText('Egzersiz adı'));
    await user.type(screen.getByLabelText('Egzersiz adı'), 'Bench Press güncel');
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    await screen.findByText('Egzersiz kaydedildi.');
    const [url, options] = saveCalls(fetchMock)[0];
    expect(url).toBe(`/api/exercises/${exerciseId}`);
    expect(options?.method).toBe('PUT');
    const { id: _, ...original } = existingExercise;
    expect(JSON.parse(String(options?.body))).toEqual({ ...original, name: 'Bench Press güncel' });
  });

  it('egzersizi pasifleştirir ve pasif kaydı tekrar düzenleyip aktif eder', async () => {
    const fetchMock = mockApi();
    renderApp();
    const user = await login();
    await user.click(await screen.findByRole('link', { name: 'Bench Press egzersizini düzenle' }));
    await screen.findByLabelText('Katalogda aktif');
    await user.click(screen.getByLabelText('Katalogda aktif'));
    expect(screen.getByText(/Geçmiş programlarda korunur/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    const card = (await screen.findByRole('heading', { name: 'Bench Press' })).closest('article')!;
    expect(within(card).getByText('Pasif')).toBeInTheDocument();
    await user.click(within(card).getByRole('link', { name: /düzenle/ }));
    expect(await screen.findByLabelText('Katalogda aktif')).not.toBeChecked();
    await user.click(screen.getByLabelText('Katalogda aktif'));
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    const activeCard = (await screen.findByRole('heading', { name: 'Bench Press' })).closest(
      'article',
    )!;
    expect(within(activeCard).getByText('Aktif')).toBeInTheDocument();
    expect(
      saveCalls(fetchMock).map(([, options]) => JSON.parse(String(options?.body)).isActive),
    ).toEqual([false, true]);
  });

  it('boş ad ve geçersiz/tehlikeli bağlantı için istek göndermeden hata gösterir', async () => {
    const fetchMock = mockApi();
    renderApp('/egzersizler/yeni');
    const user = await login();
    await screen.findByLabelText('Egzersiz adı');
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    expect(screen.getByLabelText('Egzersiz adı')).toHaveFocus();
    expect(screen.getByText('Egzersiz adını gir.')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Egzersiz adı'), 'Squat');
    await user.type(
      screen.getByLabelText('Video bağlantısı (isteğe bağlı)'),
      'javascript:alert(1)',
    );
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    expect(screen.getByLabelText('Video bağlantısı (isteğe bağlı)')).toHaveAttribute(
      'aria-invalid',
      'true',
    );
    expect(saveCalls(fetchMock)).toHaveLength(0);
  });

  it('backend alan hatalarını gösterir; form ve aktiflik seçimini korur', async () => {
    const fetchMock = mockApi({
      save: () =>
        response(
          { detail: 'Alanları kontrol et.', errors: { 'request.Name': ['Bu ad kabul edilmedi.'] } },
          400,
        ),
    });
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    const user = await login();
    await screen.findByLabelText('Egzersiz adı');
    await user.click(screen.getByLabelText('Katalogda aktif'));
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    expect(await screen.findByText('Bu ad kabul edilmedi.')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('Alanları kontrol et.');
    expect(screen.getByLabelText('Egzersiz adı')).toHaveValue('Bench Press');
    expect(screen.getByLabelText('Katalogda aktif')).not.toBeChecked();
    expect(saveCalls(fetchMock)).toHaveLength(1);
  });

  it.each([403, 404, 500])(
    '%s kaydetme hatasında başarı göstermez ve formu korur',
    async (status) => {
      mockApi({ save: () => response({ detail: 'Kaydedilemedi.' }, status) });
      renderApp(`/egzersizler/${exerciseId}/duzenle`);
      const user = await login();
      await screen.findByLabelText('Egzersiz adı');
      await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
      expect(await screen.findByRole('alert')).toHaveTextContent('Kaydedilemedi.');
      expect(screen.getByLabelText('Uygulama talimatları (isteğe bağlı)')).toHaveValue(
        'Sırtını sabit tut.',
      );
      expect(screen.queryByText('Egzersiz kaydedildi.')).not.toBeInTheDocument();
    },
  );

  it.each(['empty', 'invalid'] as const)(
    '%s başarılı HTTP yanıtını kayıt başarısı saymaz',
    async (kind) => {
      mockApi({
        save: () =>
          kind === 'empty'
            ? new Response(null, { status: 201 })
            : response({ id: exerciseId }, 201),
      });
      renderApp('/egzersizler/yeni');
      const user = await login();
      await screen.findByLabelText('Egzersiz adı');
      await user.type(screen.getByLabelText('Egzersiz adı'), 'Squat');
      await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
      await screen.findByRole('alert');
      expect(screen.getByLabelText('Egzersiz adı')).toHaveValue('Squat');
      expect(screen.queryByText('Egzersiz kaydedildi.')).not.toBeInTheDocument();
    },
  );

  it('bekleyen kaydetme sırasında ikinci gönderimi engeller', async () => {
    let complete!: (result: Response) => void;
    const fetchMock = mockApi({
      save: () =>
        new Promise((resolve) => {
          complete = resolve;
        }),
    });
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    const user = await login();
    await screen.findByLabelText('Egzersiz adı');
    const button = screen.getByRole('button', { name: 'Egzersizi kaydet' });
    const form = button.closest('form')!;
    await user.click(button);
    fireEvent.submit(form);
    expect(screen.getByRole('button', { name: 'Kaydediliyor…' })).toBeDisabled();
    expect(saveCalls(fetchMock)).toHaveLength(1);
    await act(async () => complete(response(existingExercise)));
    await screen.findByText('Egzersiz kaydedildi.');
  });

  it('formdan çıkınca bekleyen isteği iptal eder; geç gelen yanıtla yönlendirme yapmaz', async () => {
    let complete!: (result: Response) => void;
    let signal: AbortSignal | undefined;
    mockApi({
      save: (_, options) => {
        signal = options.signal!;
        return new Promise((resolve) => {
          complete = resolve;
        });
      },
    });
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    const user = await login();
    await screen.findByLabelText('Egzersiz adı');
    await user.click(screen.getByRole('button', { name: 'Egzersizi kaydet' }));
    await user.click(screen.getByRole('link', { name: 'Vazgeç' }));
    await screen.findByRole('heading', { name: 'Katalog' });
    expect(signal?.aborted).toBe(true);
    await act(async () => complete(response(existingExercise)));
    expect(screen.queryByText('Egzersiz kaydedildi.')).not.toBeInTheDocument();
  });

  it('liste hatasında yeniden deneme güncel kataloğu yükler', async () => {
    let attempt = 0;
    mockApi({
      list: () =>
        ++attempt === 1
          ? response({ detail: 'Katalog okunamadı.' }, 500)
          : response([existingExercise]),
    });
    renderApp();
    const user = await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('Katalog okunamadı.');
    await user.click(screen.getByRole('button', { name: 'Tekrar dene' }));
    expect(await screen.findByRole('heading', { name: 'Bench Press' })).toBeInTheDocument();
    expect(attempt).toBe(2);
  });

  it('bulunamayan egzersiz için boş düzenleme formu açmaz', async () => {
    mockApi({ detail: () => response({ detail: 'Egzersiz bulunamadı.' }, 404) });
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    await login();
    expect(await screen.findByRole('alert')).toHaveTextContent('Egzersiz bulunamadı.');
    expect(screen.queryByRole('button', { name: 'Egzersizi kaydet' })).not.toBeInTheDocument();
  });

  it('Trainer kataloğu salt okunur kalır ve düzenleme URL erişimi engellenir', async () => {
    const fetchMock = mockApi({ role: 'Trainer' });
    renderApp(`/egzersizler/${exerciseId}/duzenle`);
    const user = await login();
    await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
    await user.click(screen.getByRole('link', { name: 'Egzersizler' }));
    await screen.findByRole('heading', { name: 'Bench Press' });
    expect(screen.queryByRole('heading', { name: 'Lat Pulldown' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Yeni egzersiz' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /egzersizini düzenle/ })).not.toBeInTheDocument();
    expect(
      fetchMock.mock.calls.some(
        ([url]) =>
          String(url).includes('includeInactive') || url === `/api/exercises/${exerciseId}`,
      ),
    ).toBe(false);
  });

  it('Dietitian egzersiz yönetimine URL üzerinden erişemez', async () => {
    const fetchMock = mockApi({ role: 'Dietitian' });
    renderApp('/egzersizler/yeni');
    await login();
    await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
    expect(screen.queryByRole('link', { name: 'Egzersizler' })).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Egzersiz adı')).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => String(url).startsWith('/api/exercises'))).toBe(
      false,
    );
  });

  it('Admin önizlemede yazma kontrolleri ve gerçek API istekleri yoktur', async () => {
    const fetchMock = vi.fn<typeof fetch>();
    vi.stubGlobal('fetch', fetchMock);
    renderApp('/egzersizler/yeni');
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Yönetici' }));
    await screen.findByText('Yönetici paneli');
    await user.click(screen.getByRole('link', { name: 'Egzersizler' }));
    await screen.findByRole('heading', { name: 'Bench Press' });
    expect(screen.queryByRole('link', { name: 'Yeni egzersiz' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
    expect(
      await screen.findByText('Egzersiz yönetimi için yönetici hesabınla giriş yap.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Egzersizi kaydet' })).not.toBeInTheDocument();
    await waitFor(() => expect(fetchMock).not.toHaveBeenCalled());
  });
});

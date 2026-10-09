import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import { getRefreshToken } from './services/apiClient';

function TestNavigation() {
  const navigate = useNavigate();
  return (
    <>
      <button onClick={() => void navigate('/kullanicilar')}>Admin sayfasına git</button>
      <button onClick={() => void navigate('/danisanlar/unlinked-user')}>
        Bağlı olmayan danışana git
      </button>
    </>
  );
}

function renderApp(path = '/giris') {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <AuthProvider>
        <App />
        <TestNavigation />
      </AuthProvider>
    </MemoryRouter>,
  );
}

const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const loginResult = (roles: string[]) => ({
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: '2026-10-09T20:00:00Z',
  user: {
    id: 'advisor',
    firstName: 'Uğur',
    lastName: 'Çetin',
    email: 'advisor@example.com',
    roles,
  },
});

async function submitLogin() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), 'advisor@example.com');
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'password');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  return user;
}

afterEach(() => vi.unstubAllGlobals());

describe('Web gezinme ve rol erişimi', () => {
  it('oturum olmadan korumalı sayfayı açmaz', async () => {
    renderApp('/danisanlar');
    expect(await screen.findByRole('heading', { name: 'Tekrar hoş geldin.' })).toBeInTheDocument();
  });

  it('User hesabını web paneline almaz ve tokenlarını siler', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response(loginResult(['User']))));
    renderApp();
    await submitLogin();
    expect(await screen.findByRole('alert')).toHaveTextContent('Bu hesap mobil uygulama içindir');
    expect(getRefreshToken()).toBeNull();
  });

  it('login doğrulama hatalarını gösterir ve form değerlerini korur', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          response(
            { detail: 'Giriş bilgilerini kontrol edin.', errors: { email: ['Hesap bulunamadı.'] } },
            400,
          ),
        ),
    );
    renderApp();
    await submitLogin();
    expect(await screen.findByText('Hesap bulunamadı.')).toBeInTheDocument();
    expect(screen.getByLabelText('E-posta adresi')).toHaveValue('advisor@example.com');
    expect(screen.getByLabelText('Şifre', { exact: true })).toHaveValue('password');
  });

  it('çok rollü hesap için yalnız atanmış panelleri seçtirir', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(response(loginResult(['Trainer', 'Dietitian'])))
      .mockResolvedValue(response([]));
    vi.stubGlobal('fetch', fetchMock);
    renderApp();
    const user = await submitLogin();
    expect(
      await screen.findByRole('heading', { name: 'Çalışma alanını seç.' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Yönetici/ })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Diyetisyen/ }));
    expect(await screen.findByText('Diyetisyen paneli')).toBeInTheDocument();
    await waitFor(() =>
      expect(fetchMock.mock.calls.some(([url]) => url === '/api/dietitians/me/clients')).toBe(true),
    );
  });

  it('örnek antrenör panelinde isimle arama ve profil geçişi çalışır', async () => {
    renderApp();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Antrenör' }));
    await screen.findByRole('heading', { name: 'Merhaba, Uğur.' });
    await user.click(screen.getByRole('link', { name: 'Danışanlar' }));
    await screen.findByText('Mert Şerbet');
    await user.type(screen.getByRole('textbox', { name: 'Danışanları isimle ara' }), 'mert');
    expect(screen.queryByText('Deniz Yılmaz')).not.toBeInTheDocument();
    await user.click(screen.getByRole('link', { name: 'Mert Şerbet detayını aç' }));
    expect(await screen.findByRole('heading', { name: 'Mert Şerbet' })).toBeInTheDocument();
    expect(screen.getByText('mert@example.com', { selector: 'dd' })).toBeInTheDocument();
  });

  it('diyetisyen admin sayfasına URL ile de erişemez', async () => {
    renderApp();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Diyetisyen' }));
    await screen.findByText('Diyetisyen paneli');
    await user.click(screen.getByRole('button', { name: 'Admin sayfasına git' }));
    expect(await screen.findByRole('heading', { name: 'Merhaba, Ayşe.' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Kullanıcılar' })).not.toBeInTheDocument();
  });

  it('bağlı olmayan danışanın profilini göstermeyi reddeder', async () => {
    renderApp();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Antrenör' }));
    await screen.findByText('Antrenör paneli');
    await user.click(screen.getByRole('button', { name: 'Bağlı olmayan danışana git' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Bu danışana erişiminiz bulunmuyor.',
    );
  });
});

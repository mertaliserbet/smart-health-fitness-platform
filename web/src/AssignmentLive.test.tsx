import { expect, it } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useNavigate } from 'react-router';
import { App } from './App';
import { AuthProvider } from './auth/AuthProvider';
import { clearSessionTokens } from './services/apiClient';

// This opt-in test uses the real React forms and real HTTP API, never mocked fetch.
// The runner supplies only a disposable PostgreSQL fixture; no production credentials.
const clientId = process.env.ASSIGNMENT_LIVE_USER_ID;
function Navigation({ path }: { path: string }) {
  const navigate = useNavigate();
  return <button onClick={() => void navigate(path)}>Test rotasını aç</button>;
}
async function login(account: 'trainer' | 'dietitian', path: string) {
  render(
    <MemoryRouter initialEntries={['/giris']}>
      <AuthProvider>
        <App />
        <Navigation path={path} />
      </AuthProvider>
    </MemoryRouter>,
  );
  const user = userEvent.setup();
  await user.type(screen.getByLabelText('E-posta adresi'), `assignment-${account}@example.test`);
  await user.type(screen.getByLabelText('Şifre', { exact: true }), 'Assignment-Test-Password123!');
  await user.click(screen.getByRole('button', { name: 'Giriş yap' }));
  try {
    await screen.findByRole(
      'heading',
      {
        name: account === 'trainer' ? 'Merhaba, Çağrı.' : 'Merhaba, İrem.',
      },
      { timeout: 5000 },
    );
  } catch {
    throw new Error(
      `Live login failed: ${screen.queryByRole('alert')?.textContent ?? 'No login response'}`,
    );
  }
  await user.click(screen.getByRole('button', { name: 'Test rotasını aç' }));
  return user;
}
it.skipIf(!clientId)(
  'real web forms → API → PostgreSQL: workout, task/note and nutrition assignments',
  async () => {
    expect(import.meta.env.VITE_API_BASE_URL).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
    const health = await fetch(`${import.meta.env.VITE_API_BASE_URL}/api/health`);
    expect(health.status).toBe(200);
    let user = await login('trainer', `/programlar/${clientId}/yeni`);
    await user.type(await screen.findByLabelText('Program adı'), 'Atanmış kuvvet programı');
    await user.clear(screen.getByLabelText('Gün adı — 1. gün'));
    await user.type(screen.getByLabelText('Gün adı — 1. gün'), 'Kuvvet');
    await user.selectOptions(
      screen.getByLabelText('Egzersiz seç — 1. gün'),
      '10000000-0000-0000-0000-000000000004',
    );
    await user.click(screen.getByRole('button', { name: 'Egzersizi ekle — 1. gün' }));
    const rest = screen.getByLabelText(/Dinlenme \(sn, isteğe bağlı\)/);
    await user.clear(rest);
    await user.type(rest, '90');
    await user.click(screen.getByRole('button', { name: 'Programı ata' }));
    try {
      expect(
        await screen.findByText('Program danışana atandı.', {}, { timeout: 5000 }),
      ).toBeInTheDocument();
    } catch {
      throw new Error(
        `Live workout assignment failed: ${screen.queryByRole('alert')?.textContent ?? document.body.textContent?.slice(-1500)}`,
      );
    }
    expect(await screen.findByText('Atanmış kuvvet programı')).toBeInTheDocument();
    cleanup();
    clearSessionTokens();

    user = await login('trainer', `/danisanlar/${clientId}/gorevler`);
    await user.type(await screen.findByLabelText('Başlık'), 'Esneme yap');
    await user.type(screen.getByLabelText('Görev açıklaması (isteğe bağlı)'), 'On dakika esneme.');
    await user.click(screen.getByRole('button', { name: 'Görevi ata' }));
    expect(await screen.findByRole('heading', { name: 'Esneme yap' })).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Atama türü'), 'note');
    await user.type(screen.getByLabelText('Başlık'), 'Koç notu');
    await user.type(screen.getByLabelText('Not içeriği'), 'Hareketleri kontrollü yap.');
    await user.click(screen.getByRole('button', { name: 'Notu kaydet' }));
    expect(await screen.findByRole('heading', { name: 'Koç notu' })).toBeInTheDocument();
    cleanup();
    clearSessionTokens();

    user = await login('dietitian', `/beslenme-hedefleri/${clientId}/yeni`);
    await screen.findByLabelText('Günlük kalori (kcal)');
    for (const [label, value] of [
      ['Günlük kalori (kcal)', '2300'],
      ['Protein (g)', '150'],
      ['Karbonhidrat (g)', '260'],
      ['Yağ (g)', '70'],
      ['Su hedefi (ml)', '2500'],
    ]) {
      await user.type(screen.getByLabelText(label), value);
    }
    await user.click(screen.getByRole('button', { name: 'Hedefi ata' }));
    expect(await screen.findByText('Beslenme hedefi danışana atandı.')).toBeInTheDocument();
  },
  60000,
);

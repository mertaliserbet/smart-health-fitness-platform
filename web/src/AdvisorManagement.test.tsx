import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { AdvisorManagement } from './pages/AdvisorManagement';
import { ProfilePage } from './pages/ProfilePage';
import type { UserAdvisorManagementResponse, UserSummary, WebRole } from './types/api';

const auth = vi.hoisted(() => ({ role: 'Admin' as WebRole, demo: false }));
vi.mock('./auth/AuthProvider', () => ({ useAuth: () => auth }));
const client: UserSummary = {
  id: 'client',
  firstName: 'Deniz',
  lastName: 'Yılmaz',
  email: 'deniz@example.test',
  roles: ['User'],
};
const trainer: UserSummary = {
  id: 'trainer',
  firstName: 'Uğur',
  lastName: 'Çetin',
  email: 'trainer@example.test',
  roles: ['Trainer'],
};
const dietitian: UserSummary = {
  id: 'dietitian',
  firstName: 'Ayşe',
  lastName: 'Demir',
  email: 'dietitian@example.test',
  roles: ['Dietitian'],
};
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const relation = (
  changes: Partial<UserAdvisorManagementResponse> = {},
): UserAdvisorManagementResponse => ({
  userAdvisorId: 'relation',
  userId: client.id,
  advisorId: trainer.id,
  advisorType: 'Trainer',
  status: 'Active',
  startDate: '2026-10-01',
  endDate: null,
  ...changes,
});

function open(
  options: {
    relations?: UserAdvisorManagementResponse[];
    clientRoles?: UserSummary['roles'];
    post?: (body: unknown) => Response | Promise<Response>;
    patch?: (body: unknown) => Response | Promise<Response>;
    candidates?: (url: URL) => UserSummary[];
    totalPages?: number;
    profile?: boolean;
  } = {},
) {
  let relations = options.relations ?? [];
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (input, init) => {
    const url = new URL(String(input), 'http://localhost');
    if (url.pathname === '/api/user-advisors' && init?.method === 'POST') {
      const body = JSON.parse(String(init.body));
      if (options.post) return options.post(body);
      const saved = relation({ ...body, userAdvisorId: `relation-${relations.length}` });
      relations = [saved, ...relations];
      return response(saved, 201);
    }
    if (init?.method === 'PATCH') {
      const body = JSON.parse(String(init.body));
      if (options.patch) return options.patch(body);
      const id = url.pathname.split('/').at(-1);
      relations = relations.map((value) =>
        value.userAdvisorId === id ? { ...value, ...body } : value,
      );
      return response(relations.find((value) => value.userAdvisorId === id));
    }
    if (url.pathname === '/api/user-advisors') return response(relations);
    if (url.pathname === '/api/users') {
      const items =
        options.candidates?.(url) ??
        (url.searchParams.get('role') === 'Dietitian' ? [dietitian] : [trainer]);
      return response({
        items,
        page: Number(url.searchParams.get('page')),
        pageSize: 20,
        totalCount: items.length,
        totalPages: options.totalPages ?? 1,
      });
    }
    const profile = [client, trainer, dietitian].find(
      (user) => url.pathname === `/api/users/${user.id}`,
    );
    if (profile)
      return response({
        ...profile,
        ...(profile.id === client.id && options.clientRoles ? { roles: options.clientRoles } : {}),
        birthDate: null,
        gender: null,
        heightCm: null,
        phoneNumber: null,
      });
    throw new Error(`Unexpected request: ${url}`);
  });
  vi.stubGlobal('fetch', fetchMock);
  const view = render(
    <MemoryRouter
      initialEntries={[
        options.profile ? '/kullanicilar/client' : '/kullanicilar/client/danismanlar',
      ]}
    >
      <Routes>
        <Route path="/kullanicilar/:userId/danismanlar" element={<AdvisorManagement />} />
        <Route path="/kullanicilar/:userId" element={<ProfilePage />} />
      </Routes>
    </MemoryRouter>,
  );
  return {
    fetchMock,
    view,
    setRelations: (value: UserAdvisorManagementResponse[]) => {
      relations = value;
    },
  };
}

beforeEach(() => {
  auth.role = 'Admin';
  auth.demo = false;
});
afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

it('opens management from the Admin user profile and hides health fields', async () => {
  open({ profile: true });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('link', { name: 'Danışmanları yönet' }));
  expect(await screen.findByRole('heading', { name: 'Yeni danışman ata' })).toBeInTheDocument();
  expect(screen.queryByText('Doğum tarihi')).not.toBeInTheDocument();
  expect(screen.queryByText('Boy')).not.toBeInTheDocument();
});

it('posts only the contract fields with the UTC day and reloads the saved relationship', async () => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-10-11T23:30:00-03:00'));
  const { fetchMock } = open();
  const user = userEvent.setup();
  await user.click(await screen.findByRole('radio', { name: /Uğur Çetin/ }));
  await user.click(screen.getByRole('button', { name: 'Danışmanı ata' }));
  expect(
    await screen.findByRole('article', { name: 'Uğur Çetin danışman ilişkisi' }),
  ).toHaveTextContent('Aktif');
  const [, init] = fetchMock.mock.calls.find(([, init]) => init?.method === 'POST')!;
  expect(JSON.parse(String(init?.body))).toEqual({
    userId: 'client',
    advisorId: 'trainer',
    advisorType: 'Trainer',
    startDate: '2026-10-12',
  });
  expect(screen.getByRole('radio', { name: /Aktif ilişki mevcut/ })).toBeDisabled();
});

it('uses server role/search/page filters and clears selection when the list changes', async () => {
  const { fetchMock } = open({ totalPages: 2 });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('radio', { name: /Uğur Çetin/ }));
  await user.click(screen.getByRole('button', { name: 'Sonraki' }));
  await waitFor(() => expect(screen.getByRole('radio')).not.toBeChecked());
  expect(
    fetchMock.mock.calls.some(([url]) => String(url).includes('page=2&pageSize=20&role=Trainer')),
  ).toBe(true);
  await user.selectOptions(screen.getByLabelText('Danışman türü'), 'Dietitian');
  await screen.findByRole('radio', { name: /Ayşe Demir/ });
  await user.type(screen.getByLabelText('İsim veya e-posta ile ara'), ' ayse+demo@example.test ');
  await user.click(screen.getByRole('button', { name: 'Ara' }));
  await waitFor(() =>
    expect(
      fetchMock.mock.calls.some(([input]) => {
        const query = new URL(String(input), 'http://localhost').searchParams;
        return (
          query.get('role') === 'Dietitian' &&
          query.get('page') === '1' &&
          query.get('search') === 'ayse+demo@example.test'
        );
      }),
    ).toBe(true),
  );
});

it('prevents self assignment and duplicate active pairs even across advisor types', async () => {
  open({
    relations: [relation({ advisorType: 'Dietitian' })],
    candidates: () => [{ ...client, roles: ['User', 'Trainer'] }, trainer],
  });
  expect(await screen.findByRole('radio', { name: /Kişi kendisine atanamaz/ })).toBeDisabled();
  expect(screen.getByRole('radio', { name: /Aktif ilişki mevcut/ })).toBeDisabled();
});

it('keeps the selected advisor after validation failure, permits retry and prevents double POST', async () => {
  let resolve: (value: Response) => void = () => {};
  const { fetchMock } = open({
    post: () =>
      new Promise<Response>((done) => {
        resolve = done;
      }),
  });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('radio', { name: /Uğur Çetin/ }));
  const form = screen.getByRole('button', { name: 'Danışmanı ata' }).closest('form')!;
  await user.click(screen.getByRole('button', { name: 'Danışmanı ata' }));
  fireEvent.submit(form);
  expect(fetchMock.mock.calls.filter(([, init]) => init?.method === 'POST')).toHaveLength(1);
  await act(async () =>
    resolve(response({ errors: { advisorId: ['Danışman hesabı aktif olmalıdır.'] } }, 400)),
  );
  expect(await screen.findByRole('alert')).toHaveTextContent('Danışman hesabı aktif olmalıdır.');
  expect(screen.getByRole('radio')).toBeChecked();
  await user.click(screen.getByRole('button', { name: 'Danışmanı ata' }));
  expect(fetchMock.mock.calls.filter(([, init]) => init?.method === 'POST')).toHaveLength(2);
});

it('reloads server history on a conflicting concurrent assignment', async () => {
  const { setRelations } = open({
    post: () => {
      setRelations([relation()]);
      return response({ detail: 'Aktif ilişki zaten mevcut.' }, 409);
    },
  });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('radio', { name: /Uğur Çetin/ }));
  await user.click(screen.getByRole('button', { name: 'Danışmanı ata' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Aktif ilişki zaten mevcut.');
  expect(await screen.findByRole('article')).toHaveTextContent('Aktif');
  await waitFor(() => expect(screen.getByRole('radio')).toBeDisabled());
});

it('reviews termination, rejects invalid dates and PATCHes Cancelled into read-only history', async () => {
  const { fetchMock } = open({ relations: [relation()] });
  const user = userEvent.setup();
  const card = await screen.findByRole('article');
  await user.click(within(card).getByRole('button', { name: 'İlişkiyi sonlandır' }));
  expect(within(card).getByText(/Geçmiş kayıtlar korunur/)).toBeInTheDocument();
  await user.selectOptions(within(card).getByLabelText('Son durum'), 'Cancelled');
  fireEvent.change(within(card).getByLabelText('Bitiş tarihi'), {
    target: { value: '2026-09-30' },
  });
  await user.click(within(card).getByRole('button', { name: 'Sonlandırmayı kaydet' }));
  expect(within(card).getByRole('alert')).toHaveTextContent('Bitiş tarihi başlangıçtan önce');
  expect(fetchMock.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(false);
  const today = new Date().toISOString().slice(0, 10);
  fireEvent.change(within(card).getByLabelText('Bitiş tarihi'), { target: { value: today } });
  await user.click(within(card).getByRole('button', { name: 'Sonlandırmayı kaydet' }));
  await screen.findByText('İptal edildi', { selector: '.advisor-status' });
  const saved = screen.getByRole('article');
  expect(saved).toHaveTextContent('İptal edildi');
  expect(within(saved).queryByRole('button')).not.toBeInTheDocument();
  expect(screen.getByRole('radio')).toBeEnabled();
  const [, init] = fetchMock.mock.calls.find(([, init]) => init?.method === 'PATCH')!;
  expect(JSON.parse(String(init?.body))).toEqual({ status: 'Cancelled', endDate: today });
});

it('cancels review without writing and preserves the end form after an API failure', async () => {
  const { fetchMock } = open({
    relations: [relation()],
    patch: () => response({ detail: 'Sunucuya ulaşılamıyor.' }, 503),
  });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('button', { name: 'İlişkiyi sonlandır' }));
  await user.click(screen.getByRole('button', { name: 'Vazgeç' }));
  expect(fetchMock.mock.calls.some(([, init]) => init?.method === 'PATCH')).toBe(false);
  await user.click(screen.getByRole('button', { name: 'İlişkiyi sonlandır' }));
  await user.click(screen.getByRole('button', { name: 'Sonlandırmayı kaydet' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Sunucuya ulaşılamıyor.');
  expect(screen.getByLabelText('Son durum')).toHaveValue('Ended');
  expect(screen.getByRole('button', { name: 'Sonlandırmayı kaydet' })).toBeEnabled();
});

it.each(['Trainer', 'Dietitian'] as const)(
  'blocks %s before making management API calls',
  async (role) => {
    auth.role = role;
    const { fetchMock } = open();
    expect(await screen.findByRole('alert')).toHaveTextContent('yönetici rolü gerekli');
    expect(fetchMock).not.toHaveBeenCalled();
  },
);

it('rejects accounts without User role and avoids real writes in demo mode', async () => {
  const { view, fetchMock } = open({ clientRoles: ['Admin'] });
  expect(await screen.findByRole('alert')).toHaveTextContent('Kullanıcı rolüne sahip');
  expect(fetchMock.mock.calls).toHaveLength(1);
  view.unmount();
  auth.demo = true;
  const demo = open();
  expect(await screen.findByRole('alert')).toHaveTextContent('gerçek yönetici hesabıyla');
  expect(demo.fetchMock).not.toHaveBeenCalled();
});

it('aborts a pending write when navigating away from the page', async () => {
  const { fetchMock, view } = open({ post: () => new Promise<Response>(() => {}) });
  const user = userEvent.setup();
  await user.click(await screen.findByRole('radio', { name: /Uğur Çetin/ }));
  await user.click(screen.getByRole('button', { name: 'Danışmanı ata' }));
  const [, init] = fetchMock.mock.calls.find(([, init]) => init?.method === 'POST')!;
  view.unmount();
  expect(init?.signal?.aborted).toBe(true);
});

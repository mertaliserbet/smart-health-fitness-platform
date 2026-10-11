import { afterEach, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { ClientAssignments } from './pages/ClientAssignments';

vi.mock('./auth/AuthProvider', () => ({ useAuth: () => ({ role: 'Trainer', demo: false }) }));
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
function openForm(post?: (body: unknown) => Promise<Response> | Response, assigned = true) {
  let tasks: unknown[] = [];
  const fetchMock = vi.fn<typeof fetch>().mockImplementation(async (url, options) => {
    if (String(url).endsWith('/clients'))
      return response(
        assigned
          ? [
              {
                id: 'client',
                firstName: 'Mert',
                lastName: 'Şerbet',
                relationshipStatus: 'Active',
                startDate: '2026-10-01',
              },
            ]
          : [],
      );
    if (options?.method === 'POST') {
      if (post) return post(JSON.parse(String(options.body)));
      const body = JSON.parse(String(options.body));
      const saved = { ...body, id: 'task', status: 'Pending', createdAt: '2026-10-11T12:00:00Z' };
      tasks = [saved];
      return response(saved, 201);
    }
    return response(String(url).endsWith('/tasks') ? tasks : []);
  });
  vi.stubGlobal('fetch', fetchMock);
  render(
    <MemoryRouter initialEntries={['/danisanlar/client/gorevler']}>
      <Routes>
        <Route path="/danisanlar/:userId/gorevler" element={<ClientAssignments />} />
      </Routes>
    </MemoryRouter>,
  );
  return fetchMock;
}
afterEach(() => vi.unstubAllGlobals());
it('writes a task with the contract fields and reloads the real list response', async () => {
  const fetchMock = openForm();
  const user = userEvent.setup();
  await user.type(await screen.findByLabelText('Başlık'), 'Esneme yap');
  await user.click(screen.getByRole('button', { name: 'Görevi ata' }));
  expect(await screen.findByRole('heading', { name: 'Esneme yap' })).toBeInTheDocument();
  const [, options] = fetchMock.mock.calls.find(([, options]) => options?.method === 'POST')!;
  expect(JSON.parse(String(options?.body))).toEqual({
    title: 'Esneme yap',
    description: null,
    dueDate: null,
  });
});
it('preserves input after backend denial, allows retry and prevents duplicate submission', async () => {
  let resolve: (response: Response) => void = () => {};
  const fetchMock = openForm(
    () =>
      new Promise<Response>((done) => {
        resolve = done;
      }),
  );
  const user = userEvent.setup();
  await user.type(await screen.findByLabelText('Başlık'), 'Görev');
  await user.click(screen.getByRole('button', { name: 'Görevi ata' }));
  fireEvent.submit(screen.getByLabelText('Başlık').closest('form')!);
  expect(fetchMock.mock.calls.filter(([, options]) => options?.method === 'POST')).toHaveLength(1);
  resolve(response({ detail: 'Danışan ilişkisi sona erdi.' }, 403));
  expect(await screen.findByRole('alert')).toHaveTextContent('Danışan ilişkisi sona erdi.');
  expect(screen.getByLabelText('Başlık')).toHaveValue('Görev');
  expect(screen.getByRole('button', { name: 'Görevi ata' })).toBeEnabled();
});
it('does not show a write form for an unassigned client', async () => {
  const fetchMock = openForm(undefined, false);
  expect(await screen.findByText('Bu danışana erişiminiz bulunmuyor.')).toBeInTheDocument();
  expect(screen.queryByLabelText('Başlık')).not.toBeInTheDocument();
  expect(fetchMock.mock.calls.some(([, options]) => options?.method === 'POST')).toBe(false);
});

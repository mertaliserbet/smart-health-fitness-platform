import { useState } from 'react';
import { Search, Users } from 'lucide-react';
import { useAuth } from '../auth/AuthProvider';
import { useLoad } from '../hooks/useLoad';
import { getClients, getUsers } from '../services/clientService';
import { PeopleTable } from '../components/PeopleTable';
import { PageState } from '../components/PageState';
import type { ClientSummary, UserSummary } from '../types/api';

export function PeopleList() {
  const { role, demo } = useAuth();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const admin = role === 'Admin';
  const { data, loading, error, retry } = useLoad<{
    people: (ClientSummary | UserSummary)[];
    total: number;
    pages: number;
  }>(
    async (signal) => {
      if (!role) throw new Error('Panel seçilmedi.');
      if (role === 'Admin') {
        const result = await getUsers(demo, page, signal);
        return { people: result.items, total: result.totalCount, pages: result.totalPages };
      }
      const people = await getClients(role, demo, signal);
      return { people, total: people.length, pages: 1 };
    },
    [role, demo, page],
  );
  const filtered =
    data?.people.filter((person) =>
      `${person.firstName} ${person.lastName}`
        .toLocaleLowerCase('tr-TR')
        .includes(search.trim().toLocaleLowerCase('tr-TR')),
    ) ?? [];
  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">{admin ? 'HESAP YÖNETİMİ' : 'BİRLİKTE İLERLİYORUZ'}</span>
          <h1>{admin ? 'Kullanıcılar' : 'Danışanlar'}</h1>
          <p className="muted">
            {admin
              ? 'Platform hesaplarını ve mevcut rollerini incele.'
              : 'Aktif olarak çalıştığın danışanlar, tek bir yerde.'}
          </p>
        </div>
        <div className="count-pill">
          <Users size={17} aria-hidden="true" />
          {data?.total ?? '—'} {admin ? 'kullanıcı' : 'danışan'}
        </div>
      </div>
      <section className="panel">
        <div className="list-toolbar">
          <h2>{admin ? 'Kullanıcı listesi' : 'Danışan listesi'}</h2>
          <div className="search-field">
            <Search size={17} aria-hidden="true" />
            <input
              aria-label={admin ? 'Bu sayfada isimle ara' : 'Danışanları isimle ara'}
              placeholder={admin ? 'Bu sayfada isimle ara…' : 'Danışanlarda ara…'}
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>
        </div>
        {loading || error ? (
          <PageState loading={loading} error={error} retry={retry} />
        ) : filtered.length ? (
          <PeopleTable people={filtered} admin={admin} />
        ) : (
          <PageState
            empty={
              search
                ? 'Aramanla eşleşen kayıt yok'
                : admin
                  ? 'Henüz kullanıcı yok'
                  : 'Bağlı danışan yok'
            }
          />
        )}
        {admin && data && data.pages > 1 && (
          <div className="pagination">
            <button
              className="button secondary"
              disabled={page <= 1 || loading}
              onClick={() => {
                setPage(page - 1);
                setSearch('');
              }}
            >
              Önceki
            </button>
            <span>
              Sayfa {page} / {data.pages}
            </span>
            <button
              className="button secondary"
              disabled={page >= data.pages || loading}
              onClick={() => {
                setPage(page + 1);
                setSearch('');
              }}
            >
              Sonraki
            </button>
          </div>
        )}
      </section>
    </>
  );
}

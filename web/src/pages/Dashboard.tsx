import { ArrowRight, ArrowUpRight, CalendarDays, Sparkles, UserPlus, Users } from 'lucide-react';
import { Link } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { roleLabels } from '../auth/roles';
import { useLoad } from '../hooks/useLoad';
import { getClients, getUsers } from '../services/clientService';
import { PageState } from '../components/PageState';
import { PeopleTable } from '../components/PeopleTable';
import type { ClientSummary, UserSummary } from '../types/api';

export function Dashboard() {
  const { user, role, demo } = useAuth();
  const admin = role === 'Admin';
  const { data, loading, error, retry } = useLoad<{
    people: (ClientSummary | UserSummary)[];
    count: number;
  }>(
    async (signal) => {
      if (!role) throw new Error('Panel seçilmedi.');
      if (role === 'Admin') {
        const result = await getUsers(demo, 1, signal);
        return { people: result.items, count: result.totalCount };
      }
      const clients = await getClients(role, demo, signal);
      return { people: clients, count: clients.length };
    },
    [role, demo],
  );
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const addedThisMonth = data?.people.filter(
    (person) =>
      'startDate' in person &&
      person.startDate.startsWith(currentMonth) &&
      person.startDate <= `${currentMonth}-${String(now.getDate()).padStart(2, '0')}`,
  ).length;
  const listPath = admin ? '/kullanicilar' : '/danisanlar';
  const recent = [...(data?.people ?? [])]
    .sort((a, b) =>
      'startDate' in a && 'startDate' in b ? b.startDate.localeCompare(a.startDate) : 0,
    )
    .slice(0, 4);

  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">GENEL GÖRÜNÜM</span>
          <h1>Merhaba, {user?.firstName}.</h1>
          <p className="muted">
            {admin
              ? 'Platformun yönetimine buradan devam et.'
              : 'Danışanlarınla yeni bir adım atmaya hazır mısın?'}
          </p>
        </div>
        <span className="date-pill">
          <CalendarDays size={16} aria-hidden="true" />
          {new Intl.DateTimeFormat('tr-TR', {
            day: 'numeric',
            month: 'long',
            year: 'numeric',
          }).format(now)}
        </span>
      </div>
      <section className="welcome-card">
        <div>
          <span className="welcome-tag">
            <Sparkles size={14} aria-hidden="true" />
            {role ? `${roleLabels[role]} çalışma alanı` : 'Çalışma alanı'}
          </span>
          <h2>
            {admin ? (
              <>
                Sağlam bir temel.
                <br />
                <span>Düzenli bir yönetim.</span>
              </>
            ) : (
              <>
                Her danışan, yeni bir yol.
                <br />
                <span>Birlikte daha ileri.</span>
              </>
            )}
          </h2>
          <p>
            {admin
              ? 'Platform kullanıcılarını ve hesap bilgilerini tek bir yerde incele.'
              : 'Bağlı danışanlarını gör, onları daha yakından tanı ve sürece birlikte başla.'}
          </p>
          <Link className="button primary" to={listPath}>
            {admin ? 'Kullanıcıları gör' : 'Danışanları gör'}
            <ArrowRight size={17} aria-hidden="true" />
          </Link>
        </div>
        <div className="hero-art" aria-hidden="true">
          <div className="art-grid" />
          <div className="hero-orbit outer" />
          <div className="hero-orbit inner" />
          <div className="hero-center">
            <Users size={42} />
          </div>
          <span className="hero-node node-a">MŞ</span>
          <span className="hero-node node-b">DY</span>
          <span className="hero-node node-c">EK</span>
        </div>
      </section>
      <div className="dashboard-grid">
        <div className="dashboard-main">
          <section className="metric-grid" aria-label="Panel özeti">
            <div className="metric-card">
              <div className="metric-top">
                <span>{admin ? 'Kayıtlı kullanıcılar' : 'Bağlı danışanlar'}</span>
                <Users size={19} aria-hidden="true" />
              </div>
              <strong>{loading ? '—' : error ? '—' : (data?.count ?? 0)}</strong>
              <p>
                {admin ? 'Kullanıcı listesindeki toplam hesap' : 'Aktif danışmanlık ilişkileri'}
              </p>
            </div>
            <div className="metric-card">
              <div className="metric-top">
                <span>{admin ? 'Listede gösterilen' : 'Bu ay başlayan'}</span>
                <UserPlus size={19} aria-hidden="true" />
              </div>
              <strong>
                {loading
                  ? '—'
                  : error
                    ? '—'
                    : admin
                      ? (data?.people.length ?? 0)
                      : (addedThisMonth ?? 0)}
                <small>{admin ? 'hesap' : 'danışan'}</small>
              </strong>
              <p>
                {admin ? 'İlk sayfadaki kullanıcılar' : 'Mevcut aktif ilişkilerin başlangıç tarihi'}
              </p>
            </div>
          </section>
          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>{admin ? 'Kullanıcılar' : 'Danışanların'}</h2>
                <p className="muted">
                  {admin ? 'Hesaplarına hızlı bir bakış.' : 'Son başlayan ilişkilerden devam et.'}
                </p>
              </div>
              <Link className="text-link" to={listPath}>
                Tümünü gör
                <ArrowUpRight size={16} aria-hidden="true" />
              </Link>
            </div>
            {loading || error ? (
              <PageState loading={loading} error={error} retry={retry} />
            ) : recent.length ? (
              <PeopleTable people={recent} admin={admin} />
            ) : (
              <PageState empty={admin ? 'Henüz kullanıcı yok' : 'Bağlı danışan yok'} />
            )}
          </section>
        </div>
        <aside className="focus-panel">
          <span className="eyebrow">İLK ADIM</span>
          <h2>{admin ? 'Hesaplara yakından bak.' : 'İyi bir ilişki, tanımakla başlar.'}</h2>
          <p className="muted">
            {admin
              ? 'Kullanıcı bilgilerine ve tanımlı rollerine göz at.'
              : 'Her danışanın yolculuğu farklı. İlk adım, kiminle çalıştığını tanımak.'}
          </p>
          <div className="focus-step">
            <span>01</span>
            <div>
              <h3>{admin ? 'Kullanıcıları incele' : 'Danışanını bul'}</h3>
              <p>Listeyi aç ve isimle ara.</p>
            </div>
          </div>
          <div className="focus-step">
            <span>02</span>
            <div>
              <h3>Profilini tanı</h3>
              <p>Hesap ve profil bilgilerine göz at.</p>
            </div>
          </div>
          <Link className="focus-link" to={listPath}>
            Listeden başla
            <ArrowRight size={17} aria-hidden="true" />
          </Link>
          <div className="focus-bottom">
            <span className="tiny-dot" />
            {demo ? 'Örnek kayıtlarla önizleme' : 'Veriler bağlı API üzerinden alınır'}
          </div>
        </aside>
      </div>
    </>
  );
}

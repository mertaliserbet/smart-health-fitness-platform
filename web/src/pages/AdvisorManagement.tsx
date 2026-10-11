import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ArrowLeft, UserRoundPlus } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { roleLabels } from '../auth/roles';
import { PageState } from '../components/PageState';
import { formatDate } from '../components/PeopleTable';
import { useLoad } from '../hooks/useLoad';
import { ApiError } from '../services/apiClient';
import { getUserProfile, getUsers } from '../services/clientService';
import {
  createUserAdvisor,
  endUserAdvisor,
  getUserAdvisors,
} from '../services/advisorManagementService';
import type { AdvisorType, UserAdvisorManagementResponse, UserSummary } from '../types/api';
import { isValidDate } from '../utils/date';

const todayUtc = () => new Date().toISOString().slice(0, 10);
const fullName = (user: UserSummary) => `${user.firstName} ${user.lastName}`;
const statusLabels = { Active: 'Aktif', Ended: 'Sonlandırıldı', Cancelled: 'İptal edildi' };
function failureMessage(error: unknown) {
  return error instanceof ApiError && error.problem.errors
    ? Object.values(error.problem.errors).flat().join(' ')
    : error instanceof Error
      ? error.message
      : 'İşlem kaydedilemedi. Lütfen tekrar deneyin.';
}
interface WriteCallbacks {
  onSaved: (message: string) => void;
  onConflict: (message: string) => void;
}

export function AdvisorManagement() {
  const { userId = '' } = useParams();
  const { role, demo } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      if (role !== 'Admin') throw new Error('Danışman yönetimi için yönetici rolü gerekli.');
      if (demo)
        throw new Error(
          'Danışman atamak ve ilişkileri yönetmek için gerçek yönetici hesabıyla giriş yapın.',
        );
      const profile = await getUserProfile(userId, false, signal);
      if (!profile.roles.includes('User'))
        throw new Error('Danışman yalnız Kullanıcı rolüne sahip hesaplara atanabilir.');
      return profile;
    },
    [userId, role, demo],
  );
  return (
    <>
      <Link className="back-link" to={`/kullanicilar/${userId}`}>
        <ArrowLeft size={17} aria-hidden="true" />
        Kullanıcıya dön
      </Link>
      <div className="page-heading">
        <div>
          <span className="eyebrow">DANIŞMAN YÖNETİMİ</span>
          <h1>{data ? fullName(data) : 'Kullanıcının danışmanları'}</h1>
          <p className="muted">
            Antrenör ve diyetisyen ata, aktif ilişkileri yönet ve geçmişi görüntüle.
          </p>
        </div>
      </div>
      {loading || error ? (
        <section className="panel">
          <PageState loading={loading} error={error} retry={retry} />
        </section>
      ) : (
        data && <Management key={data.id} user={data} />
      )}
    </>
  );
}

function Management({ user }: { user: UserSummary }) {
  const [notice, setNotice] = useState<{ message: string; error: boolean } | null>(null);
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      const relations = await getUserAdvisors(user.id, signal);
      const advisors = await Promise.all(
        [...new Set(relations.map((relation) => relation.advisorId))].map(async (id) => {
          try {
            return [id, fullName(await getUserProfile(id, false, signal))] as const;
          } catch (error) {
            if (error instanceof ApiError && error.status === 404)
              return [id, 'Danışman hesabı bulunamadı'] as const;
            throw error;
          }
        }),
      );
      return { relations, names: Object.fromEntries(advisors) as Record<string, string> };
    },
    [user.id],
  );
  const relations = data?.relations ?? [];
  const callbacks: WriteCallbacks = {
    onSaved: (message) => {
      setNotice({ message, error: false });
      retry();
    },
    onConflict: (message) => {
      setNotice({ message, error: true });
      retry();
    },
  };
  return (
    <>
      {notice && (
        <div
          className={notice.error ? 'form-failure advisor-notice' : 'success-notice'}
          role={notice.error ? 'alert' : 'status'}
        >
          {notice.message}
        </div>
      )}
      <div className="advisor-management">
        <section className="panel advisor-panel" aria-labelledby="new-advisor-heading">
          <div className="advisor-section-heading">
            <UserRoundPlus size={22} aria-hidden="true" />
            <h2 id="new-advisor-heading">Yeni danışman ata</h2>
          </div>
          <NewAdvisor
            userId={user.id}
            relations={relations}
            disabled={!data || loading || !!error}
            {...callbacks}
          />
        </section>
        <section className="panel advisor-panel" aria-labelledby="relations-heading">
          <div className="advisor-section-heading">
            <h2 id="relations-heading">Danışman ilişkileri</h2>
            <button className="button secondary" onClick={retry} disabled={loading}>
              Yenile
            </button>
          </div>
          {loading || error ? (
            <PageState loading={loading} error={error} retry={retry} />
          ) : (
            data && (
              <>
                <h3 className="advisor-list-title">
                  Aktif danışmanlar (
                  {relations.filter((relation) => relation.status === 'Active').length})
                </h3>
                {!relations.some((relation) => relation.status === 'Active') && (
                  <p className="muted advisor-empty">Henüz aktif danışman yok.</p>
                )}
                <div className="advisor-relations">
                  {relations
                    .filter((relation) => relation.status === 'Active')
                    .map((relation) => (
                      <Relation
                        key={relation.userAdvisorId}
                        relation={relation}
                        name={data.names[relation.advisorId]}
                        {...callbacks}
                      />
                    ))}
                </div>
                <h3 className="advisor-list-title">Geçmiş ilişkiler</h3>
                {!relations.some((relation) => relation.status !== 'Active') && (
                  <p className="muted advisor-empty">Sonlandırılmış ilişki yok.</p>
                )}
                <div className="advisor-relations">
                  {relations
                    .filter((relation) => relation.status !== 'Active')
                    .map((relation) => (
                      <Relation
                        key={relation.userAdvisorId}
                        relation={relation}
                        name={data.names[relation.advisorId]}
                        {...callbacks}
                      />
                    ))}
                </div>
              </>
            )
          )}
        </section>
      </div>
    </>
  );
}

function NewAdvisor({
  userId,
  relations,
  disabled,
  onSaved,
  onConflict,
}: {
  userId: string;
  relations: UserAdvisorManagementResponse[];
  disabled: boolean;
} & WriteCallbacks) {
  const [type, setType] = useState<AdvisorType>('Trainer');
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('');
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<UserSummary | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);
  const { data, loading, error, retry } = useLoad(
    (signal) => getUsers(false, page, signal, { role: type, search: filter }),
    [type, filter, page],
  );
  const isLinked = (id: string) =>
    relations.some((relation) => relation.advisorId === id && relation.status === 'Active');
  function changePage(page: number) {
    setPage(page);
    setSelected(null);
    setFailure(null);
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current || disabled || loading || error) return;
    if (
      !selected ||
      !data?.items.some((candidate) => candidate.id === selected.id) ||
      selected.id === userId ||
      isLinked(selected.id)
    ) {
      setFailure('Aktif ilişkisi olmayan bir danışman seçin.');
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    setFailure(null);
    try {
      await createUserAdvisor(
        { userId, advisorId: selected.id, advisorType: type, startDate: todayUtc() },
        controller.signal,
      );
      if (!controller.signal.aborted) {
        setSelected(null);
        onSaved(`${fullName(selected)} danışman olarak atandı.`);
      }
    } catch (error) {
      if (!controller.signal.aborted) {
        if (error instanceof ApiError && error.status === 409) onConflict(failureMessage(error));
        else setFailure(failureMessage(error));
      }
    } finally {
      if (!controller.signal.aborted) {
        pending.current = null;
        setSubmitting(false);
      }
    }
  }
  return (
    <fieldset className="advisor-editor" disabled={submitting}>
      <legend className="sr-only">Danışman seçimi</legend>
      <label htmlFor="advisor-type">Danışman türü</label>
      <select
        id="advisor-type"
        value={type}
        onChange={(event) => {
          setType(event.target.value as AdvisorType);
          setSearch('');
          setFilter('');
          changePage(1);
        }}
      >
        <option value="Trainer">Antrenör</option>
        <option value="Dietitian">Diyetisyen</option>
      </select>
      <form
        className="advisor-search"
        onSubmit={(event) => {
          event.preventDefault();
          setFilter(search.trim());
          changePage(1);
          retry();
        }}
      >
        <label htmlFor="advisor-search">İsim veya e-posta ile ara</label>
        <div className="advisor-search-row">
          <input
            id="advisor-search"
            type="search"
            value={search}
            maxLength={200}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Danışmanı bul…"
          />
          <button className="button secondary" type="submit">
            Ara
          </button>
        </div>
      </form>
      {loading || error ? (
        <PageState loading={loading} error={error} retry={retry} />
      ) : (
        data && (
          <>
            <form onSubmit={submit} noValidate>
              <fieldset className="advisor-editor" disabled={disabled}>
                <legend className="advisor-list-title">{roleLabels[type]} seç</legend>
                {!data.items.length && (
                  <p className="muted advisor-empty">Aramana uygun danışman bulunamadı.</p>
                )}
                <div className="advisor-candidates">
                  {data.items.map((candidate) => {
                    const linked = isLinked(candidate.id);
                    const self = candidate.id === userId;
                    return (
                      <label
                        key={candidate.id}
                        className={`advisor-candidate${selected?.id === candidate.id ? ' selected' : ''}${linked || self ? ' unavailable' : ''}`}
                      >
                        <input
                          type="radio"
                          name="advisor"
                          value={candidate.id}
                          checked={selected?.id === candidate.id}
                          disabled={linked || self}
                          onChange={() => {
                            setSelected(candidate);
                            setFailure(null);
                          }}
                        />
                        <span>
                          <strong>{fullName(candidate)}</strong>
                          <small>{candidate.email}</small>
                          {(linked || self) && (
                            <small>
                              {self ? 'Kişi kendisine atanamaz' : 'Aktif ilişki mevcut'}
                            </small>
                          )}
                        </span>
                      </label>
                    );
                  })}
                </div>
                <div className="advisor-pagination">
                  <button
                    className="button secondary"
                    type="button"
                    disabled={page <= 1}
                    onClick={() => changePage(page - 1)}
                  >
                    Önceki
                  </button>
                  <span>{data.totalPages ? `${page} / ${data.totalPages}` : '0 sonuç'}</span>
                  <button
                    className="button secondary"
                    type="button"
                    disabled={page >= data.totalPages}
                    onClick={() => changePage(page + 1)}
                  >
                    Sonraki
                  </button>
                </div>
                <p className="muted advisor-help">
                  İlişki atama tarihinde başlar. Bir kullanıcıya birden fazla danışman atanabilir.
                </p>
                {failure && (
                  <div className="form-failure" role="alert">
                    {failure}
                  </div>
                )}
                <button
                  className="button primary"
                  type="submit"
                  disabled={selected ? isLinked(selected.id) : false}
                >
                  {submitting ? 'Atanıyor…' : 'Danışmanı ata'}
                </button>
              </fieldset>
            </form>
          </>
        )
      )}
    </fieldset>
  );
}

function Relation({
  relation,
  name,
  onSaved,
  onConflict,
}: { relation: UserAdvisorManagementResponse; name: string } & WriteCallbacks) {
  const [editing, setEditing] = useState(false);
  const [status, setStatus] = useState<'Ended' | 'Cancelled'>('Ended');
  const [endDate, setEndDate] = useState(todayUtc);
  const [submitting, setSubmitting] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => pending.current?.abort(), []);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending.current || relation.status !== 'Active') return;
    if (!isValidDate(endDate) || endDate < relation.startDate || endDate > todayUtc()) {
      setFailure('Bitiş tarihi başlangıçtan önce veya bugünden sonra olamaz.');
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setSubmitting(true);
    setFailure(null);
    try {
      await endUserAdvisor(relation.userAdvisorId, { status, endDate }, controller.signal);
      if (!controller.signal.aborted)
        onSaved(`${name} ile ilişki ${status === 'Ended' ? 'sonlandırıldı' : 'iptal edildi'}.`);
    } catch (error) {
      if (!controller.signal.aborted) {
        if (error instanceof ApiError && error.status === 409) onConflict(failureMessage(error));
        else setFailure(failureMessage(error));
      }
    } finally {
      if (!controller.signal.aborted) {
        pending.current = null;
        setSubmitting(false);
      }
    }
  }
  return (
    <article className="advisor-relation" aria-label={`${name} danışman ilişkisi`}>
      <div className="advisor-relation-heading">
        <h3>{name}</h3>
        <span className={`advisor-status ${relation.status === 'Active' ? 'active' : ''}`}>
          {statusLabels[relation.status]}
        </span>
      </div>
      <p className="muted">{roleLabels[relation.advisorType]}</p>
      <p className="advisor-dates">
        Başlangıç: {formatDate(relation.startDate)}
        {relation.endDate && <> · Bitiş: {formatDate(relation.endDate)}</>}
      </p>
      {relation.status === 'Active' && !editing && (
        <button className="button secondary" onClick={() => setEditing(true)}>
          İlişkiyi sonlandır
        </button>
      )}
      {relation.status === 'Active' && editing && (
        <form onSubmit={submit} noValidate>
          <fieldset className="advisor-editor" disabled={submitting}>
            <legend className="sr-only">{name} ile ilişkiyi sonlandır</legend>
            <div className="advisor-end-fields">
              <div>
                <label htmlFor={`status-${relation.userAdvisorId}`}>Son durum</label>
                <select
                  id={`status-${relation.userAdvisorId}`}
                  value={status}
                  onChange={(event) => setStatus(event.target.value as 'Ended' | 'Cancelled')}
                >
                  <option value="Ended">Sonlandırıldı</option>
                  <option value="Cancelled">İptal edildi</option>
                </select>
              </div>
              <div>
                <label htmlFor={`date-${relation.userAdvisorId}`}>Bitiş tarihi</label>
                <input
                  id={`date-${relation.userAdvisorId}`}
                  type="date"
                  required
                  min={relation.startDate}
                  max={todayUtc()}
                  value={endDate}
                  onChange={(event) => setEndDate(event.target.value)}
                />
              </div>
            </div>
            <p className="assignment-warning">
              {name} bu kullanıcıya yeni program, hedef, görev veya not atayamayacak. Geçmiş
              kayıtlar korunur. Bu ilişki tekrar açılamaz; gerekirse yeni atama yapabilirsin.
            </p>
            {failure && (
              <div className="form-failure" role="alert">
                {failure}
              </div>
            )}
            <div className="advisor-end-actions">
              <button className="button primary" type="submit">
                {submitting ? 'Kaydediliyor…' : 'Sonlandırmayı kaydet'}
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={() => {
                  setEditing(false);
                  setFailure(null);
                }}
              >
                Vazgeç
              </button>
            </div>
          </fieldset>
        </form>
      )}
    </article>
  );
}

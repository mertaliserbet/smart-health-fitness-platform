import { ArrowLeft, Mail, ShieldCheck } from 'lucide-react';
import { Link, useParams } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { getClients, getUserProfile } from '../services/clientService';
import { useLoad } from '../hooks/useLoad';
import { formatDate, initials } from '../components/PeopleTable';
import { PageState } from '../components/PageState';
import { roleLabels } from '../auth/roles';

export function ProfilePage() {
  const { userId } = useParams();
  const { role, demo, user } = useAuth();
  const { data, loading, error, retry } = useLoad(
    async (signal) => {
      if (userId && role && role !== 'Admin') {
        const clients = await getClients(role, demo, signal);
        if (!clients.some((client) => client.id === userId))
          throw new Error('Bu danışana erişiminiz bulunmuyor.');
      }
      return getUserProfile(demo && !userId ? user?.id : userId, demo, signal);
    },
    [userId, role, demo, user?.id],
  );
  const back = role === 'Admin' ? '/kullanicilar' : '/danisanlar';
  return (
    <>
      {userId && (
        <Link className="back-link" to={back}>
          <ArrowLeft size={17} aria-hidden="true" />
          Listeye dön
        </Link>
      )}
      <div className="page-heading">
        <div>
          <span className="eyebrow">{userId ? 'HESAP BİLGİLERİ' : 'ÇALIŞMA ALANIN'}</span>
          <h1>{userId ? 'Profil bilgileri' : 'Profilim'}</h1>
          <p className="muted">
            {userId ? 'Seçili kişinin temel profil bilgileri.' : 'Hesabın ve tanımlı rollerin.'}
          </p>
        </div>
      </div>
      <section className="panel profile-panel">
        {loading || error ? (
          <PageState loading={loading} error={error} retry={retry} />
        ) : (
          data && (
            <>
              <div className="profile-intro">
                <span className="avatar profile-avatar">{initials(data)}</span>
                <div>
                  <h2>
                    {data.firstName} {data.lastName}
                  </h2>
                  <p className="muted">
                    <Mail size={15} aria-hidden="true" />
                    {data.email}
                  </p>
                  <span className="profile-roles">
                    <ShieldCheck size={14} aria-hidden="true" />
                    {data.roles
                      .map((value) => (value === 'User' ? 'Kullanıcı' : roleLabels[value]))
                      .join(', ')}
                  </span>
                </div>
              </div>
              <dl className="profile-details">
                <div>
                  <dt>Ad</dt>
                  <dd>{data.firstName}</dd>
                </div>
                <div>
                  <dt>Soyad</dt>
                  <dd>{data.lastName}</dd>
                </div>
                <div>
                  <dt>E-posta</dt>
                  <dd>{data.email}</dd>
                </div>
                <div>
                  <dt>Telefon</dt>
                  <dd>{data.phoneNumber || 'Belirtilmedi'}</dd>
                </div>
                {role !== 'Admin' && (
                  <>
                    <div>
                      <dt>Doğum tarihi</dt>
                      <dd>{formatDate(data.birthDate)}</dd>
                    </div>
                    <div>
                      <dt>Boy</dt>
                      <dd>{data.heightCm ? `${data.heightCm} cm` : 'Belirtilmedi'}</dd>
                    </div>
                  </>
                )}
              </dl>
            </>
          )
        )}
      </section>
    </>
  );
}

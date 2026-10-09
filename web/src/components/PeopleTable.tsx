import { ArrowUpRight } from 'lucide-react';
import { Link } from 'react-router';
import type { ClientSummary, UserSummary } from '../types/api';
import { roleLabels } from '../auth/roles';

export function initials(value: { firstName: string; lastName: string }) {
  return `${value.firstName[0] ?? ''}${value.lastName[0] ?? ''}`;
}
export function formatDate(value: string | null) {
  if (!value) return 'Belirtilmedi';
  return new Intl.DateTimeFormat('tr-TR', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${value.slice(0, 10)}T12:00:00`));
}

export function PeopleTable({
  people,
  admin = false,
}: {
  people: (ClientSummary | UserSummary)[];
  admin?: boolean;
}) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            <th scope="col">{admin ? 'Kullanıcı' : 'Danışan'}</th>
            <th scope="col">{admin ? 'Roller' : 'İlişki'}</th>
            <th scope="col">{admin ? 'E-posta' : 'Başlangıç'}</th>
            <th scope="col">
              <span className="sr-only">İşlem</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {people.map((person, index) => (
            <tr key={person.id}>
              <td>
                <Link
                  className="person"
                  to={`${admin ? '/kullanicilar' : '/danisanlar'}/${person.id}`}
                >
                  <span className={`avatar color-${index % 4}`} aria-hidden="true">
                    {initials(person)}
                  </span>
                  <span>
                    {person.firstName} {person.lastName}
                    <small>{admin ? 'Platform hesabı' : 'Bağlı danışan'}</small>
                  </span>
                </Link>
              </td>
              <td>
                {'roles' in person ? (
                  <span className="muted">
                    {person.roles
                      .map((role) => (role === 'User' ? 'Kullanıcı' : roleLabels[role]))
                      .join(', ')}
                  </span>
                ) : (
                  <span className="status-chip">
                    <span />
                    Aktif
                  </span>
                )}
              </td>
              <td className="muted">
                {'email' in person ? person.email : formatDate(person.startDate)}
              </td>
              <td>
                <Link
                  className="row-link"
                  to={`${admin ? '/kullanicilar' : '/danisanlar'}/${person.id}`}
                  aria-label={`${person.firstName} ${person.lastName} detayını aç`}
                >
                  <ArrowUpRight size={19} aria-hidden="true" />
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

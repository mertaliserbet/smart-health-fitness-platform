import { ArrowRight } from 'lucide-react';
import { Navigate, useNavigate } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { getWebRoles, roleLabels } from '../auth/roles';
import { Brand } from '../components/Brand';

export function PanelSelection() {
  const { user, selectRole, signOut } = useAuth();
  const navigate = useNavigate();
  if (!user) return <Navigate to="/giris" replace />;
  return (
    <div className="selection-page">
      <Brand />
      <h1>Çalışma alanını seç.</h1>
      <p className="muted">Hesabına tanımlanan paneller arasında geçiş yapabilirsin.</p>
      <div className="selection-options">
        {getWebRoles(user).map((role) => (
          <button
            className="panel-option"
            key={role}
            onClick={() => {
              selectRole(role);
              void navigate('/');
            }}
          >
            <span>
              {roleLabels[role]}
              <small>{role === 'Admin' ? 'Kullanıcı yönetimi' : 'Danışan çalışma alanı'}</small>
            </span>
            <ArrowRight size={22} />
          </button>
        ))}
      </div>
      <button className="text-button" onClick={() => void signOut()}>
        Çıkış yap
      </button>
    </div>
  );
}

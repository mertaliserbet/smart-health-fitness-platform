import { Link, Navigate, Outlet, Route, Routes } from 'react-router';
import { useAuth } from './auth/AuthProvider';
import { getWebRoles } from './auth/roles';
import { AppLayout } from './components/AppLayout';
import { PageState } from './components/PageState';
import { Dashboard } from './pages/Dashboard';
import { LoginPage } from './pages/LoginPage';
import { PanelSelection } from './pages/PanelSelection';
import { PeopleList } from './pages/PeopleList';
import { ProfilePage } from './pages/ProfilePage';
import type { WebRole } from './types/api';

function ProtectedRoute() {
  const { user, role, restoring } = useAuth();
  if (restoring) return <PageState loading />;
  if (!user) return <Navigate to="/giris" replace />;
  if (!role || !getWebRoles(user).includes(role)) return <Navigate to="/panel-secimi" replace />;
  return <Outlet />;
}

function RoleRoute({ allowed }: { allowed: WebRole[] }) {
  const { role } = useAuth();
  return role && allowed.includes(role) ? <Outlet /> : <Navigate to="/" replace />;
}

export function App() {
  return (
    <Routes>
      <Route path="/giris" element={<LoginPage />} />
      <Route path="/panel-secimi" element={<PanelSelection />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<AppLayout />}>
          <Route index element={<Dashboard />} />
          <Route element={<RoleRoute allowed={['Trainer', 'Dietitian']} />}>
            <Route path="/danisanlar" element={<PeopleList />} />
            <Route path="/danisanlar/:userId" element={<ProfilePage />} />
          </Route>
          <Route element={<RoleRoute allowed={['Admin']} />}>
            <Route path="/kullanicilar" element={<PeopleList />} />
            <Route path="/kullanicilar/:userId" element={<ProfilePage />} />
          </Route>
          <Route path="/profil" element={<ProfilePage />} />
          <Route
            path="*"
            element={
              <div className="page-state">
                <h1>Sayfa bulunamadı.</h1>
                <Link className="button primary" to="/">
                  Dashboard'a dön
                </Link>
              </div>
            }
          />
        </Route>
      </Route>
    </Routes>
  );
}

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
import { ExerciseCatalog } from './pages/ExerciseCatalog';
import { ExerciseEdit } from './pages/ExerciseEdit';
import { WorkoutPlans } from './pages/WorkoutPlans';
import { WorkoutPlanCreate } from './pages/WorkoutPlanCreate';
import { WorkoutPlanDetail } from './pages/WorkoutPlanDetail';
import { WorkoutPlanEdit } from './pages/WorkoutPlanEdit';
import { NutritionGoals } from './pages/NutritionGoals';
import { NutritionGoalCreate } from './pages/NutritionGoalCreate';
import type { WebRole } from './types/api';
import { ClientAssignments } from './pages/ClientAssignments';
import { AdvisorManagement } from './pages/AdvisorManagement';

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
            <Route path="/danisanlar/:userId/gorevler" element={<ClientAssignments />} />
          </Route>
          <Route element={<RoleRoute allowed={['Admin']} />}>
            <Route path="/egzersizler/yeni" element={<ExerciseEdit />} />
            <Route path="/egzersizler/:exerciseId/duzenle" element={<ExerciseEdit />} />
            <Route path="/kullanicilar" element={<PeopleList />} />
            <Route path="/kullanicilar/:userId" element={<ProfilePage />} />
            <Route path="/kullanicilar/:userId/danismanlar" element={<AdvisorManagement />} />
          </Route>
          <Route path="/profil" element={<ProfilePage />} />
          <Route element={<RoleRoute allowed={['Trainer']} />}>
            <Route path="/programlar" element={<WorkoutPlans />} />
            <Route path="/programlar/:userId" element={<WorkoutPlans />} />
            <Route path="/programlar/:userId/yeni" element={<WorkoutPlanCreate />} />
            <Route path="/programlar/:userId/:workoutPlanId" element={<WorkoutPlanDetail />} />
            <Route
              path="/programlar/:userId/:workoutPlanId/duzenle"
              element={<WorkoutPlanEdit />}
            />
          </Route>
          <Route element={<RoleRoute allowed={['Trainer', 'Admin']} />}>
            <Route path="/egzersizler" element={<ExerciseCatalog />} />
          </Route>
          <Route element={<RoleRoute allowed={['Dietitian']} />}>
            <Route path="/beslenme-hedefleri" element={<NutritionGoals />} />
            <Route path="/beslenme-hedefleri/:userId" element={<NutritionGoals />} />
            <Route path="/beslenme-hedefleri/:userId/yeni" element={<NutritionGoalCreate />} />
          </Route>
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

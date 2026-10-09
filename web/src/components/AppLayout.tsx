import { useState } from 'react';
import {
  ChevronRight,
  ClipboardList,
  Dumbbell,
  LayoutDashboard,
  Leaf,
  LogOut,
  Menu,
  UserRound,
  Users,
  X,
} from 'lucide-react';
import { Link, NavLink, Outlet, useLocation } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { getWebRoles, roleLabels } from '../auth/roles';
import { Brand } from './Brand';
import { initials } from './PeopleTable';

export function AppLayout() {
  const { user, role, demo, signOut } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const { pathname } = useLocation();
  if (!user || !role) return null;
  const admin = role === 'Admin';
  const section = pathname.startsWith('/danisanlar')
    ? 'Danışanlar'
    : pathname.startsWith('/kullanicilar')
      ? 'Kullanıcılar'
      : pathname.startsWith('/programlar')
        ? 'Antrenman Programları'
        : pathname.startsWith('/egzersizler')
          ? 'Egzersizler'
          : pathname.startsWith('/beslenme-hedefleri')
            ? 'Beslenme Hedefleri'
            : pathname === '/profil'
              ? 'Profil'
              : 'Dashboard';
  async function leave() {
    setLeaving(true);
    await signOut();
    setLeaving(false);
  }

  return (
    <div className="app-shell">
      <a className="skip-link" href="#main-content">
        İçeriğe geç
      </a>
      {menuOpen && (
        <button
          className="menu-backdrop"
          aria-label="Menüyü kapat"
          onClick={() => setMenuOpen(false)}
        />
      )}
      <aside className={`sidebar ${menuOpen ? 'is-open' : ''}`}>
        <div className="sidebar-brand">
          <Brand />
          <button
            className="icon-button mobile-only"
            onClick={() => setMenuOpen(false)}
            aria-label="Menüyü kapat"
          >
            <X size={20} />
          </button>
        </div>
        <div className="workspace-label">
          <span className="tiny-dot" />
          {roleLabels[role]} paneli
        </div>
        <p className="nav-label">ÇALIŞMA ALANI</p>
        <nav aria-label="Ana menü" onClick={() => setMenuOpen(false)}>
          <NavLink to="/" end>
            <LayoutDashboard size={19} aria-hidden="true" />
            Dashboard
            <ChevronRight className="nav-arrow" size={14} />
          </NavLink>
          <NavLink to={admin ? '/kullanicilar' : '/danisanlar'}>
            <Users size={19} aria-hidden="true" />
            {admin ? 'Kullanıcılar' : 'Danışanlar'}
          </NavLink>
          {role === 'Trainer' && (
            <>
              <NavLink to="/programlar">
                <ClipboardList size={19} aria-hidden="true" />
                Antrenman Programları
              </NavLink>
              <NavLink to="/egzersizler">
                <Dumbbell size={19} aria-hidden="true" />
                Egzersizler
              </NavLink>
            </>
          )}
          {role === 'Dietitian' && (
            <NavLink to="/beslenme-hedefleri">
              <Leaf size={19} aria-hidden="true" />
              Beslenme Hedefleri
            </NavLink>
          )}
        </nav>
        <div className="sidebar-note">
          <div className="note-mark" />
          <p>
            Her küçük adım,
            <br />
            <strong>daha iyi bir yarına.</strong>
          </p>
          <span>Birlikte ilerliyoruz.</span>
        </div>
        <div className="sidebar-bottom">
          <nav aria-label="Hesap menüsü" onClick={() => setMenuOpen(false)}>
            <NavLink to="/profil">
              <UserRound size={19} aria-hidden="true" />
              Profil
            </NavLink>
            {getWebRoles(user).length > 1 && <Link to="/panel-secimi">Panel değiştir</Link>}
          </nav>
          <button className="logout-button" onClick={leave} disabled={leaving}>
            <LogOut size={18} aria-hidden="true" />
            {leaving ? 'Çıkılıyor…' : 'Çıkış yap'}
          </button>
          <div className="sidebar-account">
            <span className="avatar small-avatar">{initials(user)}</span>
            <span>
              {user.firstName} {user.lastName}
              <small>{roleLabels[role]}</small>
            </span>
          </div>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <div className="breadcrumb">
            <button
              className="icon-button mobile-only"
              aria-label="Menüyü aç"
              aria-expanded={menuOpen}
              onClick={() => setMenuOpen(true)}
            >
              <Menu size={22} />
            </button>
            <span className="muted">Çalışma alanı</span>
            <ChevronRight size={14} aria-hidden="true" />
            <strong>{section}</strong>
          </div>
          <Link className="header-account" to="/profil">
            <span className="account-text">
              {user.firstName} {user.lastName}
              <small>{roleLabels[role]}</small>
            </span>
            <span className="avatar small-avatar">{initials(user)}</span>
          </Link>
        </header>
        {demo && (
          <div className="demo-banner">
            <span>
              <span className="tiny-dot" />
              <strong>Örnek veri</strong> · Bu panel geliştirme için hazırlanmış örnek kayıtlar
              gösteriyor.
            </span>
            <button onClick={leave}>
              Gerçek girişe dön <ChevronRight size={14} aria-hidden="true" />
            </button>
          </div>
        )}
        <main id="main-content" tabIndex={-1}>
          <Outlet />
        </main>
        <footer className="app-footer">
          <span>Yapay Zekâ Destekli Sağlık ve Fitness Platformu</span>
          <span>Danışman paneli · V1</span>
        </footer>
      </div>
    </div>
  );
}

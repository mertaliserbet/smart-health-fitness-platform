import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { LoginRequest, UserSummary, WebRole } from '../types/api';
import * as authService from '../services/authService';
import { clearSessionTokens, readRefreshToken } from '../services/apiClient';
import { getWebRoles } from './roles';

interface AuthState {
  user: UserSummary | null;
  role: WebRole | null;
  demo: boolean;
  restoring: boolean;
  notice: string | null;
  signIn(request: LoginRequest): Promise<void>;
  signOut(): Promise<void>;
  openDemo(role: WebRole): Promise<void>;
  selectRole(role: WebRole): void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserSummary | null>(null);
  const [role, setRole] = useState<WebRole | null>(null);
  const [demo, setDemo] = useState(false);
  const [restoring, setRestoring] = useState(!!readRefreshToken());
  const [notice, setNotice] = useState<string | null>(null);

  function acceptUser(value: UserSummary) {
    const roles = getWebRoles(value);
    if (!roles.length) {
      clearSessionTokens();
      throw new Error(
        'Bu hesap mobil uygulama içindir. Web paneli için bir danışman veya yönetici hesabı gerekir.',
      );
    }
    setUser(value);
    setRole(roles.length === 1 ? roles[0] : null);
  }

  useEffect(() => {
    let active = true;
    if (readRefreshToken()) {
      authService
        .restoreSession()
        .then((value) => {
          if (active) acceptUser(value);
        })
        .catch(() => {
          if (active) {
            clearSessionTokens();
            setNotice('Oturumunuz doğrulanamadı. Lütfen tekrar giriş yapın.');
          }
        })
        .finally(() => {
          if (active) setRestoring(false);
        });
    }
    const expire = () => {
      setUser(null);
      setRole(null);
      setDemo(false);
      setNotice('Oturumunuz sona erdi. Lütfen tekrar giriş yapın.');
    };
    window.addEventListener('session-expired', expire);
    return () => {
      active = false;
      window.removeEventListener('session-expired', expire);
    };
  }, []);

  async function signIn(request: LoginRequest) {
    const value = await authService.login(request);
    acceptUser(value);
    setDemo(false);
    setNotice(null);
  }

  async function signOut() {
    try {
      if (!demo) await authService.logout();
    } catch {
      setNotice(
        'Bu cihazdan çıkış yapıldı. Sunucudaki oturum kapatılamadı; tekrar giriş yapıp çıkışı yineleyin.',
      );
    } finally {
      clearSessionTokens();
      setUser(null);
      setRole(null);
      setDemo(false);
    }
  }

  async function openDemo(value: WebRole) {
    if (!import.meta.env.DEV) return;
    const { demoAdvisors } = await import('../demo/demoData');
    clearSessionTokens();
    setUser(demoAdvisors[value]);
    setRole(value);
    setDemo(true);
    setNotice(null);
  }

  function selectRole(value: WebRole) {
    if (user && getWebRoles(user).includes(value)) setRole(value);
  }

  return (
    <AuthContext.Provider
      value={{ user, role, demo, restoring, notice, signIn, signOut, openDemo, selectRole }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('AuthProvider is required.');
  return value;
}

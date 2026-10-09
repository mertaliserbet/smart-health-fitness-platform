import { useState, type FormEvent } from 'react';
import { ArrowRight, Eye, EyeOff, LockKeyhole, ShieldCheck, Users } from 'lucide-react';
import { Navigate } from 'react-router';
import { useAuth } from '../auth/AuthProvider';
import { roleLabels, webRoles } from '../auth/roles';
import { ApiError } from '../services/apiClient';
import { Brand } from '../components/Brand';
import { PageState } from '../components/PageState';

export function LoginPage() {
  const { user, role, restoring, notice, signIn, openDemo } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  if (restoring) return <PageState loading />;
  if (user) return <Navigate to={role ? '/' : '/panel-secimi'} replace />;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const validation: Record<string, string> = {};
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))
      validation.email = 'Geçerli bir e-posta adresi girin.';
    if (!password) validation.password = 'Şifrenizi girin.';
    setErrors(validation);
    setError(null);
    if (Object.keys(validation).length) return;
    setBusy(true);
    try {
      await signIn({ email: email.trim(), password });
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Giriş yapılamadı.');
      if (reason instanceof ApiError && reason.problem.errors) {
        setErrors(
          Object.fromEntries(
            Object.entries(reason.problem.errors).map(([key, messages]) => [
              key.toLowerCase(),
              messages.join(' '),
            ]),
          ),
        );
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-story">
        <Brand />
        <div className="story-content">
          <span className="eyebrow">DAHA İYİ BİR YAŞAM, BİRLİKTE.</span>
          <h1>
            Gelişimin
            <br />
            başladığı
            <br />
            <span>yerdesin.</span>
          </h1>
          <p>
            Danışanlarını tanı. Hedeflerine eşlik et.
            <br />
            Her adımda, birlikte ilerle.
          </p>
          <div className="story-visual" aria-hidden="true">
            <div className="orbit orbit-one" />
            <div className="orbit orbit-two" />
            <div className="orbit orbit-three" />
            <div className="orbit-center">
              <Users size={40} />
            </div>
            <span className="orbit-dot dot-one" />
            <span className="orbit-dot dot-two" />
            <span className="orbit-dot dot-three" />
            <div className="floating-note">
              <span className="tiny-dot" />
              İnsanı merkeze alan danışmanlık
            </div>
          </div>
        </div>
        <p className="story-footer">Yapay Zekâ Destekli Sağlık ve Fitness Platformu</p>
      </div>
      <div className="login-form-area">
        <div className="login-form-card">
          <div className="login-badge">
            <LockKeyhole size={22} aria-hidden="true" />
          </div>
          <span className="eyebrow">DANIŞMAN PANELİ</span>
          <h2>Tekrar hoş geldin.</h2>
          <p className="muted">Çalışma alanına giriş yaparak devam et.</p>
          {(error || notice) && (
            <div className="form-alert" role="alert">
              {error || notice}
            </div>
          )}
          <form noValidate onSubmit={submit}>
            <label htmlFor="email">E-posta adresi</label>
            <input
              id="email"
              type="email"
              autoComplete="username"
              placeholder="isim@ornek.com"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              aria-invalid={!!errors.email}
              aria-describedby={errors.email ? 'email-error' : undefined}
              disabled={busy}
            />
            {errors.email && (
              <p className="field-error" id="email-error">
                {errors.email}
              </p>
            )}
            <label htmlFor="password">Şifre</label>
            <div className="password-field">
              <input
                id="password"
                type={visible ? 'text' : 'password'}
                autoComplete="current-password"
                placeholder="Şifrenizi girin"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                aria-invalid={!!errors.password}
                aria-describedby={errors.password ? 'password-error' : undefined}
                disabled={busy}
              />
              <button
                type="button"
                className="icon-button"
                onClick={() => setVisible(!visible)}
                aria-label={visible ? 'Şifreyi gizle' : 'Şifreyi göster'}
              >
                {visible ? <EyeOff size={19} /> : <Eye size={19} />}
              </button>
            </div>
            {errors.password && (
              <p className="field-error" id="password-error">
                {errors.password}
              </p>
            )}
            <button className="button primary login-submit" disabled={busy} type="submit">
              {busy ? 'Giriş yapılıyor…' : 'Giriş yap'}
              <ArrowRight size={18} aria-hidden="true" />
            </button>
          </form>
          <p className="login-security">
            <ShieldCheck size={15} aria-hidden="true" />
            Antrenör, diyetisyen ve yönetici hesapları için.
          </p>
          {import.meta.env.DEV && (
            <div className="demo-entry">
              <span>Geliştirme önizlemesi</span>
              <p>Gerçek hesaba gerek olmadan örnek panelleri incele.</p>
              <div>
                {webRoles.map((value) => (
                  <button
                    key={value}
                    onClick={() => {
                      setBusy(true);
                      void openDemo(value)
                        .catch(() => setError('Örnek panel açılamadı.'))
                        .finally(() => setBusy(false));
                    }}
                    disabled={busy}
                  >
                    {roleLabels[value]}
                    <ArrowRight size={14} aria-hidden="true" />
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
        <p className="login-form-footer">İyi bir başlangıç, büyük bir değişim.</p>
      </div>
    </div>
  );
}

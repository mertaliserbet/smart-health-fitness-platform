import { AlertCircle, LoaderCircle, Users } from 'lucide-react';

export function PageState({
  loading,
  error,
  retry,
  empty,
}: {
  loading?: boolean;
  error?: string | null;
  retry?: () => void;
  empty?: string;
}) {
  if (loading)
    return (
      <div className="page-state" role="status">
        <LoaderCircle className="spinner" size={28} aria-hidden="true" />
        <p>Veriler yükleniyor…</p>
      </div>
    );
  if (error)
    return (
      <div className="page-state" role="alert">
        <AlertCircle size={28} aria-hidden="true" />
        <h3>Şu an yüklenemedi</h3>
        <p>{error}</p>
        {retry && (
          <button className="button secondary" onClick={retry}>
            Tekrar dene
          </button>
        )}
      </div>
    );
  return (
    <div className="page-state">
      <Users size={30} aria-hidden="true" />
      <h3>{empty ?? 'Henüz kayıt yok'}</h3>
      <p>Kayıtlar eklendiğinde burada görünecek.</p>
    </div>
  );
}

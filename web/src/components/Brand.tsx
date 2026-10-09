import { Activity } from 'lucide-react';

export function Brand() {
  return (
    <div className="brand">
      <span className="brand-symbol">
        <Activity size={24} aria-hidden="true" />
      </span>
      <span>
        Sağlık & Fitness<small>Danışman platformu</small>
      </span>
    </div>
  );
}

import type { UserSummary, WebRole } from '../types/api';

export const roleLabels: Record<WebRole, string> = {
  Trainer: 'Antrenör',
  Dietitian: 'Diyetisyen',
  Admin: 'Yönetici',
};
export const webRoles: WebRole[] = ['Trainer', 'Dietitian', 'Admin'];
export function getWebRoles(user: UserSummary): WebRole[] {
  return webRoles.filter((role) => user.roles.includes(role));
}

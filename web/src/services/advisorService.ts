import { apiRequest } from './apiClient';

export interface UserTaskResponse {
  id: string;
  userId: string;
  advisorId: string;
  title: string;
  description: string | null;
  dueDate: string | null;
  status: 'Pending' | 'InProgress' | 'Completed' | 'Cancelled';
  completedAt: string | null;
  createdAt: string;
  updatedAt: string | null;
}
export interface AdvisorNoteResponse {
  id: string;
  userId: string;
  advisorId: string;
  title: string;
  content: string;
  createdAt: string;
  updatedAt: string | null;
}
export const taskLabels: Record<UserTaskResponse['status'], string> = {
  Pending: 'Bekliyor',
  InProgress: 'Devam ediyor',
  Completed: 'Tamamlandı',
  Cancelled: 'İptal edildi',
};
const path = (userId: string, resource: string) =>
  `/api/users/${encodeURIComponent(userId)}/${resource}`;
export const getTasks = (userId: string, signal?: AbortSignal) =>
  apiRequest<UserTaskResponse[]>(path(userId, 'tasks'), { signal });
export const getNotes = (userId: string, signal?: AbortSignal) =>
  apiRequest<AdvisorNoteResponse[]>(path(userId, 'advisor-notes'), { signal });
export const createTask = (
  userId: string,
  request: { title: string; description: string | null; dueDate: string | null },
  signal?: AbortSignal,
) =>
  apiRequest<UserTaskResponse>(path(userId, 'tasks'), {
    method: 'POST',
    body: JSON.stringify(request),
    signal,
  });
export const createNote = (
  userId: string,
  request: { title: string; content: string },
  signal?: AbortSignal,
) =>
  apiRequest<AdvisorNoteResponse>(path(userId, 'advisor-notes'), {
    method: 'POST',
    body: JSON.stringify(request),
    signal,
  });

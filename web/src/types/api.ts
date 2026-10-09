export type Role = 'User' | 'Trainer' | 'Dietitian' | 'Admin';
export type WebRole = Exclude<Role, 'User'>;

export interface UserSummary {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  roles: Role[];
}

export interface UserProfile extends UserSummary {
  phoneNumber: string | null;
  birthDate: string | null;
  gender: string | null;
  heightCm: number | null;
}

export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}
export interface LoginResponse extends TokenResponse {
  user: UserSummary;
}

export interface ClientSummary {
  id: string;
  firstName: string;
  lastName: string;
  relationshipStatus: 'Active';
  startDate: string;
}

export interface PagedResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalCount: number;
  totalPages: number;
}

export interface ProblemDetails {
  title?: string;
  detail?: string;
  status?: number;
  errors?: Record<string, string[]>;
}

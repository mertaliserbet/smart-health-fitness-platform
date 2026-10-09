import type { ClientSummary, UserProfile, UserSummary, WebRole } from '../types/api';

export const demoAdvisors: Record<WebRole, UserSummary> = {
  Trainer: {
    id: '432d325b-f07d-42df-b175-012657c8be9c',
    firstName: 'Uğur',
    lastName: 'Çetin',
    email: 'ugur.trainer@example.com',
    roles: ['Trainer'],
  },
  Dietitian: {
    id: '65805970-f478-443e-8fa5-c27b68f4ea74',
    firstName: 'Ayşe',
    lastName: 'Demir',
    email: 'ayse.dietitian@example.com',
    roles: ['Dietitian'],
  },
  Admin: {
    id: 'd834da93-8eba-4d9c-873c-50b9ae0f4587',
    firstName: 'Uğur',
    lastName: 'Çetin',
    email: 'ugur.admin@example.com',
    roles: ['Admin'],
  },
};

const people = [
  {
    id: '9a97f2b9-2a82-45bd-b7f9-ae24fb73441d',
    firstName: 'Mert',
    lastName: 'Şerbet',
    email: 'mert@example.com',
    startDate: '2026-10-02',
  },
  {
    id: '1ded8474-ebcb-4cb8-ab29-85c56dc53a57',
    firstName: 'Deniz',
    lastName: 'Yılmaz',
    email: 'deniz@example.com',
    startDate: '2026-09-21',
  },
  {
    id: 'ff8536b8-c129-4ea3-a4ad-e1a1b7a24b2e',
    firstName: 'Ece',
    lastName: 'Kaya',
    email: 'ece@example.com',
    startDate: '2026-09-15',
  },
  {
    id: 'ec0d7212-c62d-4810-81a6-62cfd2ed3040',
    firstName: 'Can',
    lastName: 'Arslan',
    email: 'can@example.com',
    startDate: '2026-10-05',
  },
];

const clients: ClientSummary[] = people.map(({ id, firstName, lastName, startDate }) => ({
  id,
  firstName,
  lastName,
  startDate,
  relationshipStatus: 'Active',
}));
export const demoClients = { Trainer: clients, Dietitian: clients.slice(0, 3) };
export const demoUsers: UserSummary[] = [
  ...people.map(({ id, firstName, lastName, email }) => ({
    id,
    firstName,
    lastName,
    email,
    roles: ['User'] as UserSummary['roles'],
  })),
  ...Object.values(demoAdvisors),
];
export const demoProfiles: UserProfile[] = demoUsers.map((value) => ({
  ...value,
  phoneNumber: null,
  birthDate: null,
  gender: null,
  heightCm: null,
}));

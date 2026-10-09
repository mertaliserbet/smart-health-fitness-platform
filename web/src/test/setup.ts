import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';
import { clearSessionTokens } from '../services/apiClient';

afterEach(() => {
  cleanup();
  clearSessionTokens();
  sessionStorage.clear();
});

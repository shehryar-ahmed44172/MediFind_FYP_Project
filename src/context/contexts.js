import { createContext } from 'react';

// Context objects live in their own module so the provider files only export
// components (keeps React Fast Refresh working).
export const AuthContext  = createContext(null);
export const AlertContext = createContext(null);
export const ThemeContext = createContext({ theme: 'light', toggleTheme: () => {} });

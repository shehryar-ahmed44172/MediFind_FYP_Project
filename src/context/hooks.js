import { useContext } from 'react';
import { AuthContext, AlertContext, ThemeContext } from './contexts';

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};

export const useAlert = () => {
  const ctx = useContext(AlertContext);
  if (!ctx) throw new Error('useAlert must be used within AlertProvider');
  return ctx;
};

export const useTheme = () => useContext(ThemeContext);

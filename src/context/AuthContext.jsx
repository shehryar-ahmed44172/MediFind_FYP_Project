import React, { createContext, useContext, useState, useCallback } from 'react';
import api from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    try {
      const stored = localStorage.getItem('medifind_user');
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  });

  const login = useCallback(async (email, password) => {
    const response = await api.post('/api/auth/login', { email, password });
    const { token, refreshToken, ...userData } = response.data.data;

    if (userData.role !== 'ADMIN') {
      throw new Error('Access denied. Admin credentials required.');
    }

    localStorage.setItem('medifind_token', token);
    localStorage.setItem('medifind_refresh_token', refreshToken || '');
    localStorage.setItem('medifind_user', JSON.stringify(userData));
    setUser(userData);
    return userData;
  }, []);

  const logout = useCallback(async () => {
    try {
      const refreshToken = localStorage.getItem('medifind_refresh_token');
      if (refreshToken) {
        await api.post('/api/auth/logout', { refreshToken });
      }
    } catch {
      // Even if logout API fails, clear local state
    } finally {
      localStorage.removeItem('medifind_token');
      localStorage.removeItem('medifind_refresh_token');
      localStorage.removeItem('medifind_user');
      
      // Explicitly clear common headers to prevent persistence across logins
      if (api.defaults.headers.common['Authorization']) {
        delete api.defaults.headers.common['Authorization'];
      }
      
      setUser(null);
      
      // Nuclear option: Hard reload to /login to ensure all memory state is wiped
      window.location.href = '/login';
    }
  }, []);

  const isAuthenticated = !!user && !!localStorage.getItem('medifind_token');

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
};

import axios from 'axios';

// In local dev: VITE_API_URL is empty → baseURL is '' → Vite proxy forwards /api → localhost:3000
// In production or ngrok: set VITE_API_URL to the full base URL in .env
const BASE = import.meta.env.VITE_API_URL || '';

const api = axios.create({
  baseURL: BASE,
  headers: { 'Content-Type': 'application/json' },
});

// ── Request interceptor: attach current access token ──────────────────────
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('medifind_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ── Silent refresh on 401 ─────────────────────────────────────────────────
let _isRefreshing = false;
let _waitQueue    = [];

const processQueue = (error, token = null) => {
  _waitQueue.forEach((p) => (error ? p.reject(error) : p.resolve(token)));
  _waitQueue = [];
};

const clearSession = () => {
  localStorage.removeItem('medifind_token');
  localStorage.removeItem('medifind_refresh_token');
  localStorage.removeItem('medifind_user');
};

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config;

    // Only intercept 401s that haven't been retried yet
    if (error.response?.status !== 401 || original._retry) {
      return Promise.reject(error);
    }

    const refreshToken = localStorage.getItem('medifind_refresh_token');

    // No refresh token at all — go straight to login
    if (!refreshToken) {
      clearSession();
      window.location.href = '/login';
      return Promise.reject(error);
    }

    // Another refresh is already in flight — queue this request
    if (_isRefreshing) {
      return new Promise((resolve, reject) => {
        _waitQueue.push({ resolve, reject });
      }).then((newToken) => {
        original._retry = true; // prevent this queued retry from looping again
        original.headers.Authorization = `Bearer ${newToken}`;
        return api(original);
      }).catch((err) => Promise.reject(err));
    }

    // Start the refresh
    original._retry  = true;
    _isRefreshing    = true;

    try {
      const res = await api.post('/api/auth/refresh-token', { refreshToken });

      // Backend returns { token, refreshToken, ... }
      // "token" is the new access token (NOT "accessToken")
      const newToken = res.data.data?.token || res.data.data?.accessToken;

      if (!newToken) {
        // Refresh succeeded HTTP-wise but returned no usable token — treat as failure
        throw new Error('Refresh endpoint returned no access token');
      }

      localStorage.setItem('medifind_token', newToken);
      api.defaults.headers.common.Authorization = `Bearer ${newToken}`;

      // Resolve all waiting requests with the new token
      processQueue(null, newToken);

      // Retry the original request
      original.headers.Authorization = `Bearer ${newToken}`;
      return api(original);

    } catch (refreshErr) {
      // Refresh failed — reject all queued requests, clear session, redirect
      processQueue(refreshErr, null);
      clearSession();
      window.location.href = '/login';
      return Promise.reject(refreshErr);

    } finally {
      _isRefreshing = false;
    }
  }
);

export default api;

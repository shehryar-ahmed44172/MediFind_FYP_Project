import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { AlertProvider } from './context/AlertContext';
import { ThemeProvider } from './context/ThemeContext';
import { useAuth } from './context/hooks';
import LandingPage from './pages/LandingPage';
import {
  FeaturesPage, DeafUsersPage, HowItWorksPage, RespondersPage, AdminConsolePage, FaqPage, ContactPage,
} from './pages/SitePages';
import LoginPage from './pages/LoginPage';
import Dashboard from './pages/Dashboard';
import LegalPage from './pages/LegalPage';
import NotFound from './pages/NotFound';
import NavigationLoader from './components/NavigationLoader';
import api from './services/api';
import './index.css';

const DEFAULT_TIMEOUT_MS = 30 * 60 * 1000; // 30 min

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/admin/login" replace />;
};

const SessionTimeoutHandler = ({ children }) => {
  const { isAuthenticated, logout } = useAuth();
  const timeoutRef = React.useRef(null);
  const [timeoutMs, setTimeoutMs] = React.useState(DEFAULT_TIMEOUT_MS);

  // Fetch the admin-configured session timeout once on mount
  useEffect(() => {
    let cancelled = false;
    api.get('/api/admin/client-settings')
      .then(({ data }) => {
        const minutes = Number(data?.data?.sessionTimeoutMinutes);
        if (!cancelled && minutes) {
          setTimeoutMs(Math.max(5, Math.min(120, minutes)) * 60 * 1000);
        }
      })
      .catch(() => {}); // silently use default
    return () => { cancelled = true; };
  }, []);

  const resetTimer = React.useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (isAuthenticated) {
      timeoutRef.current = setTimeout(() => {
        console.info('Session timed out due to inactivity');
        logout();
      }, timeoutMs);
    }
  }, [isAuthenticated, logout, timeoutMs]);

  useEffect(() => {
    if (!isAuthenticated) return undefined;
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'];
    events.forEach(event => window.addEventListener(event, resetTimer, { passive: true }));
    resetTimer();
    return () => {
      events.forEach(event => window.removeEventListener(event, resetTimer));
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [isAuthenticated, resetTimer]);

  return children;
};

function AppRoutes() {
  return (
    <>
      <NavigationLoader />
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/features" element={<FeaturesPage />} />
        <Route path="/deaf-users" element={<DeafUsersPage />} />
        <Route path="/how-it-works" element={<HowItWorksPage />} />
        <Route path="/responders" element={<RespondersPage />} />
        <Route path="/admin-console" element={<AdminConsolePage />} />
        <Route path="/faq" element={<FaqPage />} />
        <Route path="/contact" element={<ContactPage />} />
        {/* The website is for awareness; only administrators sign in, at /admin/login */}
        <Route path="/admin/login" element={<LoginPage />} />
        <Route path="/login" element={<Navigate to="/admin/login" replace />} />
        <Route path="/terms" element={<LegalPage type="terms" />} />
        <Route path="/privacy" element={<LegalPage type="privacy" />} />
        <Route
          path="/admin/*"
          element={
            <ProtectedRoute>
              <SessionTimeoutHandler>
                <Dashboard />
              </SessionTimeoutHandler>
            </ProtectedRoute>
          }
        />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </>
  );
}

// The admin console is responsive (the sidebar collapses into a drawer on narrow
// screens), so there is no device-size gate here any more.
function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <AlertProvider>
          <Router>
            <AppRoutes />
          </Router>
        </AlertProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;

import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { AlertProvider } from './context/AlertContext';
import { ThemeProvider } from './context/ThemeContext';
import LandingPage from './pages/LandingPage';
import LoginPage from './pages/LoginPage';
import Dashboard from './pages/Dashboard';
import LegalPage from './pages/LegalPage';
import NotFound from './pages/NotFound';
import './App.css';
import './index.css';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
};

const SessionTimeoutHandler = ({ children }) => {
  const { isAuthenticated, logout } = useAuth();
  const timeoutRef = React.useRef(null);
  const TIMEOUT_DURATION = 30 * 60 * 1000; // 30 minutes

  const resetTimer = React.useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (isAuthenticated) {
      timeoutRef.current = setTimeout(() => {
        console.log('HIPAA: Session timed out due to inactivity');
        logout();
      }, TIMEOUT_DURATION);
    }
  }, [isAuthenticated, logout]);

  useEffect(() => {
    if (isAuthenticated) {
      const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'];
      events.forEach(event => window.addEventListener(event, resetTimer));
      resetTimer();

      return () => {
        events.forEach(event => window.removeEventListener(event, resetTimer));
        if (timeoutRef.current) clearTimeout(timeoutRef.current);
      };
    }
  }, [isAuthenticated, resetTimer]);

  return children;
};

function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />
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
  );
}

function App() {
  const [isLaptop, setIsLaptop] = useState(window.innerWidth >= 320);

  useEffect(() => {
    const handleResize = () => {
      setIsLaptop(window.innerWidth >= 320);
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  if (!isLaptop) {
    return (
      <div className="restriction-screen">
        <div className="restriction-content">
          <div className="restriction-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect>
              <line x1="2" y1="20" x2="22" y2="20"></line>
            </svg>
          </div>
          <h1>Laptop Only Access</h1>
          <p>
            The MediFind Web Portal is designed for administrative use on larger screens. 
            Please access this portal from a laptop or desktop computer to continue.
          </p>
          <div className="btn-primary" onClick={() => window.location.reload()}>
            Try Again
          </div>
          <div className="restriction-footer">
            MediFind Management Console
          </div>
        </div>
      </div>
    );
  }

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

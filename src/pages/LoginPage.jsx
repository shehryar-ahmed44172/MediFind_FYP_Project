import React, { useState } from 'react';
import { Lock, Mail, ArrowRight, ArrowLeft, Eye, EyeOff } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/hooks';
import { Avatar, Button, Notice } from '../components/ui';
import useAdminScope from '../components/useAdminScope';
import appMark from '../assets/medifind_mark.png';

/* Map API / network failures to clear, actionable messages */
function loginErrorMessage(err) {
  if (!err?.response) {
    if (err?.message?.startsWith('Access denied')) return 'This account is not an administrator. Use an admin account to sign in.';
    return 'Cannot reach the MediFind server. Check your connection and try again.';
  }
  const { status, data } = err.response;
  if (status === 401) return 'Incorrect email or password.';
  if (status === 403) return data?.message || 'This account is not allowed to access the admin console.';
  if (status === 423) return data?.message || 'This account is temporarily locked after too many failed attempts. Try again later.';
  if (status === 429) return 'Too many sign-in attempts. Please wait a moment and try again.';
  if (status >= 500) return 'The server had a problem signing you in. Please try again shortly.';
  return data?.message || 'Sign-in failed. Please check your details and try again.';
}

/* ─── Layout pieces ───────────────────────────────────────────────────────── */
function AuthShell({ children }) {
  return (
    <div style={{
      minHeight: '100vh', background: 'var(--admin-bg)', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', padding: '32px 16px',
    }}>
      <div className="mf-page" style={{ width: '100%', maxWidth: '400px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', marginBottom: '24px' }}>
          <span style={{ width: 32, height: 32, borderRadius: '8px', background: '#FFFFFF', border: '1px solid var(--border)', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
            <img src={appMark} alt="" style={{ width: 24, height: 24, objectFit: 'contain' }} />
          </span>
          <span style={{ fontSize: '15px', fontWeight: 600, color: 'var(--text-main)' }}>
            MediFind <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>Admin</span>
          </span>
        </div>

        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '12px', padding: '28px 28px 24px' }}>
          {children}
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', marginTop: '16px', fontSize: '12.5px', color: 'var(--text-muted)' }}>
          <Link to="/" className="mf-btn mf-btn--ghost mf-btn--sm" style={{ color: 'var(--text-muted)', paddingLeft: '6px' }}>
            <ArrowLeft size={14} aria-hidden="true" /> Back to MediFind
          </Link>
          <span>Restricted access</span>
        </div>
      </div>
    </div>
  );
}

const labelStyle = { display: 'block', fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', marginBottom: '6px' };
const inputIcon = { position: 'absolute', left: '11px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' };

/* ─── Component ───────────────────────────────────────────────────────────── */
const LoginPage = () => {
  useAdminScope();
  const { login, logout, isAuthenticated, user } = useAuth();
  const navigate = useNavigate();

  const [email,        setEmail]        = useState('');
  const [password,     setPassword]     = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading,      setLoading]      = useState(false);
  const [error,        setError]        = useState('');

  // ── Already signed in — show a choice screen instead of auto-redirecting ──
  if (isAuthenticated) {
    return (
      <AuthShell>
        <h1 style={{ fontSize: '20px', lineHeight: '28px', fontWeight: 600, margin: '0 0 4px' }}>You’re already signed in</h1>
        <p style={{ fontSize: '13.5px', color: 'var(--text-muted)', margin: '0 0 20px' }}>
          Your admin session is active. Where would you like to go?
        </p>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 12px', border: '1px solid var(--border)', borderRadius: '8px', marginBottom: '20px' }}>
          <Avatar name={user?.fullName ?? 'Administrator'} size={32} />
          <div style={{ minWidth: 0, flex: 1 }}>
            <p style={{ margin: 0, fontSize: '13px', fontWeight: 500, color: 'var(--text-main)' }}>{user?.fullName ?? 'Administrator'}</p>
            <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span aria-hidden="true" style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--success)' }} />
              Active session
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <Button variant="primary" size="lg" onClick={() => navigate('/admin', { replace: true })} style={{ width: '100%' }}>
            Continue to dashboard <ArrowRight size={15} aria-hidden="true" />
          </Button>
          <Button size="lg" onClick={async () => { await logout(); }} style={{ width: '100%' }}>
            Sign in as a different admin
          </Button>
        </div>
      </AuthShell>
    );
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (loading) return;
    const trimmedEmail = email.trim();
    if (!trimmedEmail || !password) { setError('Please enter your email and password.'); return; }
    setLoading(true);
    setError('');
    try {
      await login(trimmedEmail, password);
      navigate('/admin', { replace: true });
    } catch (err) {
      setError(loginErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell>
      <h1 style={{ fontSize: '20px', lineHeight: '28px', fontWeight: 600, margin: '0 0 4px' }}>Sign in to the admin console</h1>
      <p style={{ fontSize: '13.5px', color: 'var(--text-muted)', margin: '0 0 20px' }}>
        Use your MediFind administrator credentials.
      </p>

      {error && (
        <div id="login-error" style={{ marginBottom: '16px' }}>
          <Notice tone="danger" role="alert">{error}</Notice>
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        <div>
          <label style={labelStyle} htmlFor="admin-email">Email</label>
          <div style={{ position: 'relative' }}>
            <Mail size={15} aria-hidden="true" style={inputIcon} />
            <input
              id="admin-email"
              type="email"
              className="mf-input mf-input--with-icon"
              value={email}
              disabled={loading}
              aria-invalid={!!error}
              aria-describedby={error ? 'login-error' : undefined}
              onChange={e => { setEmail(e.target.value); if (error) setError(''); }}
              placeholder="admin@medifind.com"
              required
              autoComplete="email"
              style={{ height: '40px', paddingLeft: '34px' }}
            />
          </div>
        </div>

        <div>
          <label style={labelStyle} htmlFor="admin-password">Password</label>
          <div style={{ position: 'relative' }}>
            <Lock size={15} aria-hidden="true" style={inputIcon} />
            <input
              id="admin-password"
              type={showPassword ? 'text' : 'password'}
              className="mf-input mf-input--with-icon"
              value={password}
              disabled={loading}
              aria-invalid={!!error}
              aria-describedby={error ? 'login-error' : undefined}
              onChange={e => { setPassword(e.target.value); if (error) setError(''); }}
              placeholder="Enter your password"
              required
              autoComplete="current-password"
              style={{ height: '40px', paddingLeft: '34px', paddingRight: '42px' }}
            />
            <button
              type="button"
              className="mf-icon-btn"
              onClick={() => setShowPassword(v => !v)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
              aria-pressed={showPassword}
              title={showPassword ? 'Hide password' : 'Show password'}
              style={{ position: 'absolute', right: '5px', top: '50%', transform: 'translateY(-50%)' }}
            >
              {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
            </button>
          </div>
        </div>

        <Button type="submit" variant="primary" size="lg" disabled={loading} style={{ width: '100%', marginTop: '4px' }}>
          {loading ? (
            <>
              <span aria-hidden="true" style={{ width: '14px', height: '14px', borderRadius: '50%', border: '2px solid rgba(255,255,255,0.35)', borderTopColor: '#fff', animation: 'spin 0.8s linear infinite' }} />
              Signing in…
            </>
          ) : 'Sign in'}
        </Button>
      </form>

      <p style={{ margin: '20px 0 0', paddingTop: '16px', borderTop: '1px solid var(--border)', fontSize: '12.5px', lineHeight: '18px', color: 'var(--text-muted)' }}>
        This console is for authorized MediFind administrators only. All sessions are logged and monitored.
      </p>
    </AuthShell>
  );
};

export default LoginPage;

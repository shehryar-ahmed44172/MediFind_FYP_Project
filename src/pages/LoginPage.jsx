import React, { useState } from 'react';
import {
  Lock, Mail, ArrowRight, ArrowLeft, Eye, EyeOff, UserCheck, Siren, ScrollText, ShieldCheck, PhoneCall, LayoutDashboard,
} from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/hooks';
import { Avatar, Button, Notice } from '../components/ui';
import useAdminScope from '../components/useAdminScope';
import appMark from '../assets/medifind_mark.png';
import { HeroBackdrop } from '../components/landing/Backdrop';
import './login.css';

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
const ADMIN_FEATURES = [
  { Icon: UserCheck,  title: 'Verify responders',  text: 'Review CNIC, license and employee ID before anyone can accept an emergency.' },
  { Icon: Siren,      title: 'Live SOS logistics', text: 'See every active emergency and responder on one live map.' },
  { Icon: ScrollText, title: 'Full audit trail',   text: 'Alerts, calls and admin actions are logged and reviewable.' },
];

function AuthShell({ children }) {
  return (
    <div className="mf-auth">
      <aside className="mf-auth-brand" aria-label="MediFind admin console">
        <HeroBackdrop />
        <div>
          <Link to="/" className="mf-auth-logo" aria-label="MediFind home">
            <img src={appMark} alt="" width="34" height="34" /><span>Medi<b>Find</b></span>
          </Link>
          <div style={{ marginTop: 'clamp(28px, 7vh, 72px)' }}>
            <span className="mf-auth-eyebrow"><LayoutDashboard size={14} aria-hidden="true" /> Admin console</span>
            <p className="mf-auth-headline">Keep MediFind’s emergency network safe and moving.</p>
            <p className="mf-auth-lead">
              Verify responders, watch live SOS activity and keep every alert and call accountable.
            </p>
            <ul className="mf-auth-features">
              {ADMIN_FEATURES.map(({ Icon, title, text }) => (
                <li key={title}>
                  <span className="mf-auth-ico" aria-hidden="true"><Icon size={18} /></span>
                  <span><strong>{title}</strong><span className="mf-auth-desc">{text}</span></span>
                </li>
              ))}
            </ul>
          </div>
        </div>
        <div className="mf-auth-foot">
          <span>Deaf-first emergency response · Pakistan</span>
          <span className="mf-auth-1122"><PhoneCall size={14} aria-hidden="true" /> Emergency? Call Rescue 1122</span>
        </div>
      </aside>

      <main className="mf-auth-main">
        <HeroBackdrop />
        <div className="mf-page mf-auth-card">
          {children}
        </div>
        <div className="mf-auth-links">
          <Link to="/" className="mf-btn mf-btn--ghost mf-btn--sm" style={{ color: 'var(--text-muted)', paddingLeft: '6px' }}>
            <ArrowLeft size={14} aria-hidden="true" /> Back to MediFind
          </Link>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}><Lock size={13} aria-hidden="true" /> Restricted access</span>
        </div>
      </main>
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
        <span className="mf-auth-card-icon" aria-hidden="true"><ShieldCheck size={22} /></span>
        <h1>You’re already signed in</h1>
        <p className="mf-auth-sub">Your admin session is active. Where would you like to go?</p>

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
      <span className="mf-auth-card-icon" aria-hidden="true"><ShieldCheck size={22} /></span>
      <h1>Welcome back</h1>
      <p className="mf-auth-sub">Sign in to the MediFind admin console with your administrator account.</p>

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
              style={{ height: '44px', paddingLeft: '36px' }}
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
              style={{ height: '44px', paddingLeft: '36px', paddingRight: '44px' }}
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

      <p className="mf-auth-note">
        <ShieldCheck size={15} aria-hidden="true" />
        This console is for authorized MediFind administrators only. All sessions are logged and monitored.
      </p>
    </AuthShell>
  );
};

export default LoginPage;

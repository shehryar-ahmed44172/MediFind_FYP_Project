import React, { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { KeyRound, Mail, Eye, EyeOff, CheckCircle2, ArrowRight } from 'lucide-react';
import api from '../services/api';
import { Button, Notice } from '../components/ui';
import useAdminScope from '../components/useAdminScope';
import { AuthShell } from './LoginPage';
import './login.css';

const labelStyle = { display: 'block', fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', marginBottom: '6px' };
const inputIcon = { position: 'absolute', left: '11px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' };

// Mirrors the server rule in src/utils/password.ts.
const RULES = [
  { id: 'length', label: 'At least 10 characters', test: (v) => v.length >= 10 },
  { id: 'letter', label: 'Contains a letter', test: (v) => /[A-Za-z]/.test(v) },
  { id: 'number', label: 'Contains a number', test: (v) => /[0-9]/.test(v) },
];

const apiMessage = (err, fallback) =>
  err?.response?.data?.message || err?.response?.data?.error || (err?.response ? fallback : 'Cannot reach the MediFind server. Check your connection and try again.');

/**
 * Step 1 — ask for the reset email.
 *
 * The server answers the same way whether or not the address exists, so this
 * page must not say anything that would confirm an account.
 */
export const ForgotPasswordPage = () => {
  useAdminScope();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    if (loading || !email.trim()) return;
    setLoading(true);
    setError('');
    try {
      await api.post('/api/password/forgot-password', { email: email.trim() });
      setSent(true);
    } catch (err) {
      // 429 = too many requests; anything else is a server problem
      setError(apiMessage(err, 'Could not send the reset email. Please try again shortly.'));
    } finally {
      setLoading(false);
    }
  };

  if (sent) {
    return (
      <AuthShell>
        <span className="mf-auth-card-icon" aria-hidden="true"><CheckCircle2 size={22} /></span>
        <h1>Check your email</h1>
        <p className="mf-auth-sub">
          If an account exists for that address, a reset link is on its way. The link works once
          and expires in 30 minutes.
        </p>
        <Link to="/admin/login" className="mf-btn mf-btn--primary mf-btn--lg" style={{ width: '100%' }}>
          Back to sign in <ArrowRight size={15} aria-hidden="true" />
        </Link>
      </AuthShell>
    );
  }

  return (
    <AuthShell>
      <span className="mf-auth-card-icon" aria-hidden="true"><Mail size={22} /></span>
      <h1>Forgot your password?</h1>
      <p className="mf-auth-sub">Enter your admin email and we will send you a reset link.</p>

      <form onSubmit={submit} noValidate>
        <label htmlFor="reset-email" style={labelStyle}>Email address</label>
        <div style={{ position: 'relative', marginBottom: '16px' }}>
          <Mail size={15} style={inputIcon} aria-hidden="true" />
          <input
            id="reset-email"
            type="email"
            className="mf-input"
            style={{ paddingLeft: '34px' }}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="admin@medifind.pk"
            autoComplete="email"
          />
        </div>

        {error && <Notice tone="danger" role="alert" style={{ marginBottom: '14px' }}>{error}</Notice>}

        <Button type="submit" variant="primary" size="lg" style={{ width: '100%' }} disabled={loading}>
          {loading ? 'Sending…' : 'Send reset link'}
        </Button>
      </form>

      <p style={{ marginTop: '16px', fontSize: '13px', color: 'var(--text-muted)' }}>
        Remembered it? <Link to="/admin/login">Back to sign in</Link>
      </p>
    </AuthShell>
  );
};

/**
 * Step 2 — the page the emailed link opens: choose the new password.
 */
export const ResetPasswordPage = () => {
  useAdminScope();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const token = params.get('token') || '';

  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [visible, setVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  const passed = useMemo(() => RULES.map((r) => ({ ...r, ok: r.test(password) })), [password]);
  const mismatch = confirm.length > 0 && password !== confirm;
  const canSubmit = !loading && !!token && passed.every((r) => r.ok) && !mismatch && confirm.length > 0;

  const submit = async (e) => {
    e.preventDefault();
    if (!canSubmit) return;
    setLoading(true);
    setError('');
    try {
      await api.post('/api/password/reset', { token, newPassword: password });
      setDone(true);
      setTimeout(() => navigate('/admin/login', { replace: true }), 2500);
    } catch (err) {
      setError(apiMessage(err, 'This reset link is invalid or has expired. Request a new one.'));
    } finally {
      setLoading(false);
    }
  };

  if (!token) {
    return (
      <AuthShell>
        <span className="mf-auth-card-icon" aria-hidden="true"><KeyRound size={22} /></span>
        <h1>Reset link incomplete</h1>
        <p className="mf-auth-sub">
          This page needs the link from your email. Open the link again, or request a new one.
        </p>
        <Link to="/forgot-password" className="mf-btn mf-btn--primary mf-btn--lg" style={{ width: '100%' }}>
          Request a new link <ArrowRight size={15} aria-hidden="true" />
        </Link>
      </AuthShell>
    );
  }

  if (done) {
    return (
      <AuthShell>
        <span className="mf-auth-card-icon" aria-hidden="true"><CheckCircle2 size={22} /></span>
        <h1>Password updated</h1>
        <p className="mf-auth-sub">
          All sessions were signed out. Taking you to the sign-in page — use your new password.
        </p>
        <Link to="/admin/login" className="mf-btn mf-btn--primary mf-btn--lg" style={{ width: '100%' }}>
          Go to sign in <ArrowRight size={15} aria-hidden="true" />
        </Link>
      </AuthShell>
    );
  }

  return (
    <AuthShell>
      <span className="mf-auth-card-icon" aria-hidden="true"><KeyRound size={22} /></span>
      <h1>Choose a new password</h1>
      <p className="mf-auth-sub">This link can be used once. Signing in elsewhere will need the new password.</p>

      <form onSubmit={submit} noValidate>
        <label htmlFor="new-password" style={labelStyle}>New password</label>
        <div style={{ position: 'relative', marginBottom: '10px' }}>
          <KeyRound size={15} style={inputIcon} aria-hidden="true" />
          <input
            id="new-password"
            type={visible ? 'text' : 'password'}
            className="mf-input"
            style={{ paddingLeft: '34px', paddingRight: '40px' }}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="new-password"
            spellCheck={false}
          />
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? 'Hide password' : 'Show password'}
            className="mf-icon-btn"
            style={{ position: 'absolute', right: '4px', top: '50%', transform: 'translateY(-50%)' }}
          >
            {visible ? <EyeOff size={15} aria-hidden="true" /> : <Eye size={15} aria-hidden="true" />}
          </button>
        </div>

        <ul style={{ listStyle: 'none', margin: '0 0 16px', padding: 0, display: 'grid', gap: '4px' }}>
          {passed.map((rule) => (
            <li key={rule.id} style={{ fontSize: '12.5px', color: rule.ok ? 'var(--success-fg, #15803d)' : 'var(--text-muted)' }}>
              <span aria-hidden="true">{rule.ok ? '✓ ' : '• '}</span>{rule.label}
            </li>
          ))}
        </ul>

        <label htmlFor="confirm-password" style={labelStyle}>Confirm new password</label>
        <div style={{ position: 'relative', marginBottom: mismatch ? '6px' : '16px' }}>
          <KeyRound size={15} style={inputIcon} aria-hidden="true" />
          <input
            id="confirm-password"
            type={visible ? 'text' : 'password'}
            className="mf-input"
            style={{ paddingLeft: '34px' }}
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            autoComplete="new-password"
            spellCheck={false}
          />
        </div>
        {mismatch && (
          <p role="alert" style={{ fontSize: '12.5px', color: 'var(--error-fg)', margin: '0 0 14px' }}>
            The two passwords do not match.
          </p>
        )}

        {error && <Notice tone="danger" role="alert" style={{ marginBottom: '14px' }}>{error}</Notice>}

        <Button type="submit" variant="primary" size="lg" style={{ width: '100%' }} disabled={!canSubmit}>
          {loading ? 'Saving…' : 'Set new password'}
        </Button>
      </form>
    </AuthShell>
  );
};

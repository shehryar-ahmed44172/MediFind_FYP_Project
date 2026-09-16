import React, { useState } from 'react';
import {
  Lock, Mail, ArrowRight, AlertCircle, Eye, EyeOff,
  Shield, Activity, Users, Zap, CheckCircle,
} from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '../context/hooks';
import logo from '../assets/Medifind_New_Logo-removebg-preview.png';

/* ─── Brand tokens ────────────────────────────────────────────────────────── */
const PANEL_BG   = 'linear-gradient(160deg, var(--primary-dark) 0%, var(--primary) 70%, var(--primary-mid) 130%)';
const ACCENT     = 'var(--primary-light)';
const FORM_BG    = 'var(--background)';
const WHITE      = '#FFFFFF';
const TEXT_MAIN  = 'var(--text-main)';
const TEXT_MUTED = 'var(--text-muted)';
const BORDER     = 'var(--border)';
const ERROR_BG   = 'var(--tint-red)';
const ERROR_FG   = 'var(--error-fg)';
const ERROR_BORD = 'var(--error-border)';

/* ─── Left panel feature highlights ──────────────────────────────────────── */
const FEATURES = [
  { Icon: Activity, label: 'Live Emergency Monitoring',  desc: 'Real-time SOS dispatch & response tracking' },
  { Icon: Users,    label: 'Full User Management',       desc: 'Patients, responders, and caregivers' },
  { Icon: Shield,   label: 'Responder Verification',     desc: 'Credential review and approval queue' },
  { Icon: Zap,      label: 'Instant Push Notifications', desc: 'AI-drafted broadcasts to all users' },
];

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

/* ─── Component ───────────────────────────────────────────────────────────── */
const LoginPage = () => {
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
      <div className="mf-login-grid" style={{
        minHeight: '100vh',
        fontFamily: "'Montserrat', sans-serif",
      }}>
        {/* Left panel — same brand panel */}
        <div style={{
          background: PANEL_BG,
          display: 'flex', flexDirection: 'column',
          justifyContent: 'center', alignItems: 'center',
          padding: '48px 52px', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{
            position: 'absolute', top: '-80px', right: '-80px',
            width: '400px', height: '400px', borderRadius: '50%',
            border: '1px solid rgba(255,255,255,0.05)', pointerEvents: 'none',
          }} />
          <div style={{
            position: 'absolute', bottom: '-100px', left: '-80px',
            width: '500px', height: '500px', borderRadius: '50%',
            background: 'radial-gradient(circle, rgba(40,145,194,0.12) 0%, transparent 70%)',
            pointerEvents: 'none',
          }} />
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5 }}
            style={{ textAlign: 'center', position: 'relative', zIndex: 1 }}
          >
            <div style={{
              width: '80px', height: '80px', borderRadius: '50%',
              background: 'linear-gradient(135deg,rgba(255,255,255,0.15),rgba(255,255,255,0.05))',
              border: '2px solid rgba(255,255,255,0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 20px',
            }}>
              <Shield size={36} color="rgba(255,255,255,0.9)" />
            </div>
            <h2 style={{ fontSize: '1.75rem', fontWeight: 800, color: WHITE, marginBottom: '8px', letterSpacing: '-0.02em' }}>
              Access Granted
            </h2>
            <p style={{ color: 'rgba(255,255,255,0.5)', fontSize: '0.9rem', lineHeight: 1.6 }}>
              Your admin session is active and verified.
            </p>
          </motion.div>
        </div>

        {/* Right panel — already signed in state */}
        <motion.div
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5 }}
          style={{
            background: FORM_BG,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: '48px 64px',
          }}
        >
          <div style={{ width: '100%', maxWidth: '420px' }}>
            {/* Session active banner */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: '14px 18px', marginBottom: '32px',
              background: 'var(--tint-green)', border: '1px solid var(--success-border)',
              borderRadius: '14px',
            }}>
              <div style={{
                width: '10px', height: '10px', borderRadius: '50%',
                background: 'var(--success)', flexShrink: 0,
                boxShadow: '0 0 0 3px rgba(16,185,129,0.2)',
              }} />
              <div>
                <p style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--success-fg)' }}>
                  Active Session
                </p>
                <p style={{ fontSize: '0.75rem', color: 'var(--success-fg)', marginTop: '1px' }}>
                  Signed in as <strong>{user?.fullName ?? 'Administrator'}</strong>
                </p>
              </div>
            </div>

            <h2 style={{
              fontSize: '1.75rem', fontWeight: 800,
              color: TEXT_MAIN, letterSpacing: '-0.03em',
              marginBottom: '8px', lineHeight: 1.2,
            }}>
              Welcome back
            </h2>
            <p style={{ color: TEXT_MUTED, fontSize: '0.9rem', marginBottom: '36px', lineHeight: 1.6 }}>
              You're already signed in. Where would you like to go?
            </p>

            {/* Go to Dashboard */}
            <motion.button
              whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
              onClick={() => navigate('/admin', { replace: true })}
              style={{
                width: '100%', height: '54px', marginBottom: '14px',
                borderRadius: '14px', border: 'none',
                background: 'linear-gradient(135deg,var(--primary) 0%,var(--primary-light) 100%)',
                color: WHITE, fontWeight: 800, fontSize: '0.95rem',
                letterSpacing: '0.02em', cursor: 'pointer',
                fontFamily: 'inherit',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px',
                boxShadow: '0 8px 24px rgba(12,99,126,0.28)',
              }}
            >
              Continue to Dashboard <ArrowRight size={18} />
            </motion.button>

            {/* Sign in as different user */}
            <motion.button
              whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
              onClick={async () => {
                await logout();
              }}
              style={{
                width: '100%', height: '54px',
                borderRadius: '14px',
                border: `1.5px solid ${BORDER}`,
                background: 'var(--surface)',
                color: TEXT_MUTED, fontWeight: 700, fontSize: '0.9rem',
                cursor: 'pointer', fontFamily: 'inherit',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
              }}
            >
              Sign in as different admin
            </motion.button>

            <div style={{ marginTop: '28px', textAlign: 'center' }}>
              <Link
                to="/"
                style={{
                  fontSize: '0.82rem', fontWeight: 600, color: TEXT_MUTED,
                  textDecoration: 'none', display: 'inline-flex',
                  alignItems: 'center', gap: '5px',
                }}
                onMouseEnter={e => e.currentTarget.style.color = 'var(--primary)'}
                onMouseLeave={e => e.currentTarget.style.color = TEXT_MUTED}
              >
                ← Back to MediFind Hub
              </Link>
            </div>
          </div>
        </motion.div>
      </div>
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
    <div className="mf-login-grid" style={{
      minHeight: '100vh',
      fontFamily: "'Montserrat', sans-serif",
    }}>

      {/* ══════════════════════════════════════════════
          LEFT PANEL — Brand / Info
      ══════════════════════════════════════════════ */}
      <motion.div
        initial={{ opacity: 0, x: -30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.7, ease: [0.2, 0.8, 0.2, 1] }}
        className="mf-login-brand"
        style={{
          background: PANEL_BG,
          display: 'flex', flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '48px 52px',
          position: 'relative', overflow: 'hidden',
        }}
      >
        {/* Background decorative rings */}
        <div style={{
          position: 'absolute', top: '-80px', right: '-80px',
          width: '400px', height: '400px', borderRadius: '50%',
          border: '1px solid rgba(255,255,255,0.05)',
          pointerEvents: 'none',
        }} />
        <div style={{
          position: 'absolute', top: '-40px', right: '-40px',
          width: '300px', height: '300px', borderRadius: '50%',
          border: '1px solid rgba(255,255,255,0.07)',
          pointerEvents: 'none',
        }} />
        <div style={{
          position: 'absolute', bottom: '-100px', left: '-80px',
          width: '500px', height: '500px', borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(40,145,194,0.12) 0%, transparent 70%)',
          pointerEvents: 'none',
        }} />

        <div style={{ marginTop: '-25px' }}>
          <Link to="/" style={{ display: 'inline-block', textDecoration: 'none' }}>
            <img
              src={logo} alt="MediFind"
              style={{
                height: '130px', objectFit: 'contain',
                filter: 'brightness(1.2) drop-shadow(0 2px 12px rgba(0,0,0,0.4))',
                cursor: 'pointer',
              }}
            />
          </Link>
        </div>

        {/* ── Center content ── */}
        <div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: '7px',
            padding: '5px 14px', borderRadius: '100px',
            background: 'rgba(255,255,255,0.1)',
            border: '1px solid rgba(255,255,255,0.15)',
            marginBottom: '24px',
          }}>
            <Shield size={12} color="rgba(255,255,255,0.8)" />
            <span style={{ fontSize: '0.7rem', fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.8)' }}>
              Admin Management Console
            </span>
          </div>

          <h1 style={{
            fontSize: '2.4rem', fontWeight: 800, color: WHITE,
            letterSpacing: '-0.03em', lineHeight: 1.15,
            marginBottom: '16px',
          }}>
            Emergency Response<br />
            <span style={{ color: '#BFE3EC' }}>Command Center</span>
          </h1>
          <p style={{
            fontSize: '1rem', color: 'rgba(255,255,255,0.6)',
            lineHeight: 1.7, maxWidth: '380px',
          }}>
            Manage Pakistan's emergency response network — from responder verification to live SOS coordination.
          </p>

          {/* Feature list */}
          <div style={{ marginTop: '36px', display: 'flex', flexDirection: 'column', gap: '18px' }}>
            {FEATURES.map((feature, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, x: -16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.3 + i * 0.1, duration: 0.5 }}
                style={{ display: 'flex', alignItems: 'flex-start', gap: '14px' }}
              >
                <div style={{
                  width: '38px', height: '38px', borderRadius: '11px', flexShrink: 0,
                  background: 'rgba(255,255,255,0.1)',
                  border: '1px solid rgba(255,255,255,0.12)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <feature.Icon size={17} color={ACCENT} strokeWidth={2.5} />
                </div>
                <div>
                  <p style={{ fontSize: '0.875rem', fontWeight: 700, color: WHITE, marginBottom: '2px' }}>{feature.label}</p>
                  <p style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.68)', lineHeight: 1.5 }}>{feature.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>

        {/* ── Footer ── */}
        <div style={{
          borderTop: '1px solid rgba(255,255,255,0.08)',
          paddingTop: '20px',
          display: 'flex', alignItems: 'center', gap: '8px',
        }}>
          <div style={{
            width: '8px', height: '8px', borderRadius: '50%',
            background: 'var(--success)',
          }} />
          <span style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.45)', fontWeight: 600 }}>
            All systems operational · Restricted access only
          </span>
        </div>
      </motion.div>

      {/* ══════════════════════════════════════════════
          RIGHT PANEL — Login Form
      ══════════════════════════════════════════════ */}
      <motion.div
        initial={{ opacity: 0, x: 30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.7, ease: [0.2, 0.8, 0.2, 1] }}
        style={{
          background: FORM_BG,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 'clamp(24px, 5vw, 48px) clamp(16px, 6vw, 64px)',
          position: 'relative',
        }}
      >
        <div style={{ width: '100%', maxWidth: '420px' }}>

          {/* Header */}
          <div style={{ marginBottom: '40px' }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: '6px',
              padding: '4px 12px', borderRadius: '100px',
              background: 'var(--primary-pale)', border: '1px solid var(--border)',
              marginBottom: '16px',
            }}>
              <Shield size={11} color="var(--primary)" strokeWidth={2.5} />
              <span style={{ fontSize: '0.68rem', fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--primary)' }}>
                Secure Access
              </span>
            </div>

            <h2 style={{
              fontSize: '1.875rem', fontWeight: 800,
              color: TEXT_MAIN, letterSpacing: '-0.03em',
              marginBottom: '8px', lineHeight: 1.2,
            }}>
              Welcome back,<br />Administrator
            </h2>
            <p style={{ color: TEXT_MUTED, fontSize: '0.9rem', fontWeight: 500, lineHeight: 1.6 }}>
              Sign in with your admin credentials to access the MediFind management console.
            </p>
          </div>

          {/* Error banner */}
          {error && (
            <motion.div
              id="login-error"
              role="alert"
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              style={{
                display: 'flex', alignItems: 'center', gap: '10px',
                padding: '12px 16px', marginBottom: '24px',
                background: ERROR_BG, border: `1px solid ${ERROR_BORD}`,
                borderRadius: '12px', color: ERROR_FG,
                fontSize: '0.875rem', fontWeight: 600,
              }}
            >
              <AlertCircle size={16} style={{ flexShrink: 0 }} />
              {error}
            </motion.div>
          )}

          {/* Form */}
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

            {/* Email */}
            <div>
              <label style={{
                display: 'block', fontWeight: 700, fontSize: '0.75rem',
                textTransform: 'uppercase', letterSpacing: '0.07em',
                marginBottom: '8px', color: TEXT_MUTED,
              }} htmlFor="admin-email">
                Email Address
              </label>
              <div style={{ position: 'relative' }}>
                <Mail style={{
                  position: 'absolute', left: '16px', top: '50%',
                  transform: 'translateY(-50%)', color: TEXT_MUTED,
                  pointerEvents: 'none',
                }} size={16} />
                <input
                  id="admin-email"
                  type="email"
                  value={email}
                  disabled={loading}
                  aria-invalid={!!error}
                  aria-describedby={error ? 'login-error' : undefined}
                  onChange={e => { setEmail(e.target.value); if (error) setError(''); }}
                  placeholder="admin@medifind.com"
                  required
                  autoComplete="email"
                  style={{
                    width: '100%', height: '52px',
                    paddingLeft: '46px', paddingRight: '16px',
                    borderRadius: '14px',
                    border: `1.5px solid ${BORDER}`,
                    background: 'var(--input-bg)', color: TEXT_MAIN,
                    fontSize: '0.9rem', outline: 'none',
                    fontFamily: 'inherit',
                    transition: 'border-color 0.2s, box-shadow 0.2s',
                    boxSizing: 'border-box',
                  }}
                  onFocus={e => {
                    e.target.style.borderColor = ACCENT;
                    e.target.style.boxShadow = '0 0 0 3px rgba(40,145,194,0.12)';
                  }}
                  onBlur={e => {
                    e.target.style.borderColor = BORDER;
                    e.target.style.boxShadow = 'none';
                  }}
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <label style={{
                display: 'block', fontWeight: 700, fontSize: '0.75rem',
                textTransform: 'uppercase', letterSpacing: '0.07em',
                marginBottom: '8px', color: TEXT_MUTED,
              }} htmlFor="admin-password">
                Password
              </label>
              <div style={{ position: 'relative' }}>
                <Lock style={{
                  position: 'absolute', left: '16px', top: '50%',
                  transform: 'translateY(-50%)', color: TEXT_MUTED,
                  pointerEvents: 'none',
                }} size={16} />
                <input
                  id="admin-password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  disabled={loading}
                  aria-invalid={!!error}
                  aria-describedby={error ? 'login-error' : undefined}
                  onChange={e => { setPassword(e.target.value); if (error) setError(''); }}
                  placeholder="••••••••••••"
                  required
                  autoComplete="current-password"
                  style={{
                    width: '100%', height: '52px',
                    paddingLeft: '46px', paddingRight: '52px',
                    borderRadius: '14px',
                    border: `1.5px solid ${BORDER}`,
                    background: 'var(--input-bg)', color: TEXT_MAIN,
                    fontSize: '1rem', outline: 'none',
                    fontFamily: 'inherit',
                    transition: 'border-color 0.2s, box-shadow 0.2s',
                    boxSizing: 'border-box',
                  }}
                  onFocus={e => {
                    e.target.style.borderColor = ACCENT;
                    e.target.style.boxShadow = '0 0 0 3px rgba(40,145,194,0.12)';
                  }}
                  onBlur={e => {
                    e.target.style.borderColor = BORDER;
                    e.target.style.boxShadow = 'none';
                  }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  aria-pressed={showPassword}
                  title={showPassword ? 'Hide password' : 'Show password'}
                  style={{
                    position: 'absolute', right: '16px', top: '50%',
                    transform: 'translateY(-50%)',
                    background: 'none', border: 'none', cursor: 'pointer',
                    color: TEXT_MUTED, display: 'flex', alignItems: 'center',
                    padding: '4px',
                  }}
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Submit */}
            <motion.button
              whileHover={{ scale: loading ? 1 : 1.02 }}
              whileTap={{ scale: loading ? 1 : 0.97 }}
              type="submit"
              disabled={loading}
              style={{
                width: '100%', height: '54px', marginTop: '8px',
                borderRadius: '14px', border: 'none',
                background: loading
                  ? 'var(--primary-mid)'
                  : 'linear-gradient(135deg,var(--primary) 0%,var(--primary-light) 100%)',
                color: WHITE, fontWeight: 800, fontSize: '0.95rem',
                letterSpacing: '0.02em', cursor: loading ? 'not-allowed' : 'pointer',
                fontFamily: 'inherit',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px',
                boxShadow: loading ? 'none' : '0 8px 24px rgba(12,99,126,0.28)',
                transition: 'background 0.2s, box-shadow 0.2s',
              }}
            >
              {loading ? (
                <>
                  <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ repeat: Infinity, duration: 0.8, ease: 'linear' }}
                    style={{
                      width: '18px', height: '18px', borderRadius: '50%',
                      border: '2px solid rgba(255,255,255,0.3)',
                      borderTopColor: 'white',
                    }}
                  />
                  Authenticating…
                </>
              ) : (
                <>Access System <ArrowRight size={18} /></>
              )}
            </motion.button>
          </form>

          {/* Security note */}
          <div style={{
            marginTop: '32px', padding: '14px 16px',
            background: 'var(--tint-green)', borderRadius: '12px',
            border: '1px solid var(--success-border)',
            display: 'flex', alignItems: 'flex-start', gap: '10px',
          }}>
            <CheckCircle size={15} color="var(--success-fg)" style={{ flexShrink: 0, marginTop: '1px' }} />
            <div>
              <p style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--success-fg)', marginBottom: '2px' }}>
                Restricted Access
              </p>
              <p style={{ fontSize: '0.75rem', fontWeight: 600, lineHeight: 1.5, color: 'var(--success-fg)' }}>
                This console is for authorized MediFind administrators only. All sessions are logged and monitored.
              </p>
            </div>
          </div>

          {/* Back link */}
          <div style={{ marginTop: '24px', textAlign: 'center' }}>
            <Link
              to="/"
              style={{
                fontSize: '0.82rem', fontWeight: 600, color: TEXT_MUTED,
                textDecoration: 'none', display: 'inline-flex',
                alignItems: 'center', gap: '5px', transition: 'color 0.2s',
              }}
              onMouseEnter={e => e.currentTarget.style.color = 'var(--primary)'}
              onMouseLeave={e => e.currentTarget.style.color = TEXT_MUTED}
            >
              ← Back to MediFind Hub
            </Link>
          </div>
        </div>
      </motion.div>
    </div>
  );
};

export default LoginPage;

import React, { useState, useEffect } from 'react';
import {
  Settings, Mail, CreditCard, Shield, Bell,
  Save, RefreshCw, ChevronRight, AlertCircle,
  CheckCircle, Eye, EyeOff, Server, Lock,
  Zap, Wifi, WifiOff, FlaskConical,
  Plus, Trash2, Globe, ShieldCheck, ShieldOff,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import { useAlert } from '../../context/AlertContext';

/* ─── Toggle Switch ─────────────────────────────────────────────────────────── */
const Toggle = ({ value, onChange, disabled }) => (
  <button
    onClick={() => !disabled && onChange(!value)}
    style={{
      width: '48px', height: '26px', borderRadius: '13px',
      background: value ? 'var(--primary)' : '#CBD5E1',
      border: 'none', cursor: disabled ? 'not-allowed' : 'pointer',
      position: 'relative', transition: 'background 0.25s',
      flexShrink: 0, opacity: disabled ? 0.5 : 1,
    }}
  >
    <span style={{
      position: 'absolute', top: '3px',
      left: value ? '25px' : '3px',
      width: '20px', height: '20px', borderRadius: '50%',
      background: 'white', transition: 'left 0.25s',
      boxShadow: '0 1px 4px rgba(0,0,0,0.25)',
    }} />
  </button>
);

/* ─── Env-var read-only badge ────────────────────────────────────────────────── */
const EnvBadge = () => (
  <span style={{
    fontSize: '0.62rem', fontWeight: 800, padding: '2px 7px',
    borderRadius: '6px', background: '#F1F5F9', color: '#64748B',
    border: '1px solid #E2E8F0', letterSpacing: '0.04em',
  }}>
    ENV VAR · READ ONLY
  </span>
);

/* ─── Field label row ────────────────────────────────────────────────────────── */
const Label = ({ text, sub, readOnly }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '0.625rem' }}>
    <span style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
      {text}
    </span>
    {readOnly && <EnvBadge />}
    {sub && <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 400 }}>— {sub}</span>}
  </div>
);

/* ─── Input ──────────────────────────────────────────────────────────────────── */
const Field = ({ value, onChange, type = 'text', placeholder, readOnly, mono }) => (
  <input
    type={type}
    value={value}
    onChange={e => onChange(e.target.value)}
    placeholder={placeholder}
    readOnly={readOnly}
    style={{
      width: '100%', padding: '0.825rem 1.1rem',
      borderRadius: '10px',
      border: `1px solid ${readOnly ? 'var(--border)' : 'var(--border)'}`,
      background: readOnly ? 'var(--surface-raised)' : 'var(--surface)',
      fontSize: '0.9rem', outline: 'none',
      fontFamily: mono ? 'monospace' : 'inherit',
      color: readOnly ? 'var(--text-muted)' : 'var(--text-main)',
      cursor: readOnly ? 'not-allowed' : 'text',
      boxSizing: 'border-box',
    }}
  />
);

/* ─── Section heading ────────────────────────────────────────────────────────── */
const SectionTitle = ({ title, sub }) => (
  <div style={{ marginBottom: '1.75rem' }}>
    <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-sub)', margin: 0 }}>{title}</h2>
    {sub && <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginTop: '4px' }}>{sub}</p>}
  </div>
);

/* ─── Toggle row ─────────────────────────────────────────────────────────────── */
const ToggleRow = ({ label, desc, value, onChange, disabled }) => (
  <div style={{
    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    padding: '1rem 1.25rem', background: 'var(--surface-raised)',
    borderRadius: '12px', border: '1px solid var(--border)',
  }}>
    <div style={{ flex: 1, paddingRight: '1rem' }}>
      <h4 style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-sub)', marginBottom: '2px' }}>{label}</h4>
      <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>{desc}</p>
    </div>
    <Toggle value={value} onChange={onChange} disabled={disabled} />
  </div>
);

/* ══════════════════════════════════════════════════════════════════════════════ */

const PlatformSettings = () => {
  const { showAlert } = useAlert();
  const [activeTab, setActiveTab] = useState('GENERAL');
  const [loading, setLoading]     = useState(true);
  const [saving, setSaving]       = useState(false);
  const [testingEmail, setTestingEmail]   = useState(false);
  const [testingSmtp,  setTestingSmtp]    = useState(false);
  const [smtpStatus,   setSmtpStatus]     = useState(null); // null | 'ok' | 'fail'
  const [showEmailPass, setShowEmailPass] = useState(false);
  const [myIp,         setMyIp]           = useState('');
  const [newIp,        setNewIp]          = useState('');
  const [ipError,      setIpError]        = useState('');

  // ── Settings state ───────────────────────────────────────────────────────────
  const [settings, setSettings] = useState({
    orgName:              'MediFind Emergency Response Network',
    supportEmail:         'support@medifind.pk',
    maintenanceMode:      false,
    debugLogging:         false,
    alertEmail:           'ops@medifind.pk',
    alertWebhook:         '',
    twoFactorRequired:    false,
    sessionTimeoutMinutes: 30,
    ipWhitelisting:       false,
    allowedIps:           [],
    // Email gateway
    emailGateway:   'env',
    smtpHost:       '',
    smtpPort:       '587',
    smtpEncryption: 'tls',
    smtpUser:       '',
    smtpPass:       '',
    smtpFromName:   'MediFind Emergency Network',
  });

  // ── Gateway presets ──────────────────────────────────────────────────────────
  const GATEWAYS = [
    {
      id: 'env',
      label: 'Server .env',
      desc: 'Use SMTP_HOST / SMTP_USER / SMTP_PASS from the server environment file',
      icon: Server,
      color: '#64748B',
      pale:  '#F1F5F9',
      preset: null,
    },
    {
      id: 'gmail',
      label: 'Gmail SMTP',
      desc: 'Google Workspace or personal Gmail with App Password',
      icon: Mail,
      color: '#EA4335',
      pale:  '#FEF2F2',
      preset: { smtpHost: 'smtp.gmail.com', smtpPort: '587', smtpEncryption: 'tls' },
    },
    {
      id: 'mailtrap',
      label: 'Mailtrap Sandbox',
      desc: 'Email testing sandbox — catches all outbound mail without delivery',
      icon: FlaskConical,
      color: '#6366F1',
      pale:  '#EEF2FF',
      preset: { smtpHost: 'sandbox.smtp.mailtrap.io', smtpPort: '2525', smtpEncryption: 'tls' },
    },
    {
      id: 'outlook',
      label: 'Outlook / Office 365',
      desc: 'Microsoft 365 organizational email account',
      icon: Mail,
      color: '#0078D4',
      pale:  '#EFF6FF',
      preset: { smtpHost: 'smtp.office365.com', smtpPort: '587', smtpEncryption: 'tls' },
    },
    {
      id: 'custom',
      label: 'Custom SMTP',
      desc: 'Any SMTP server — enter host, port and credentials manually',
      icon: Zap,
      color: '#F59E0B',
      pale:  '#FFFBEB',
      preset: { smtpHost: '', smtpPort: '587', smtpEncryption: 'tls' },
    },
  ];

  // ── Read-only env info from backend ─────────────────────────────────────────
  const [envInfo, setEnvInfo] = useState({
    smtpHost: '—', smtpPort: '—', smtpUser: '—',
    stripeMode: '—', nodeEnv: '—',
  });

  const set = (key) => (val) => setSettings(s => ({ ...s, [key]: val }));

  // ── Load settings + admin IP on mount ───────────────────────────────────────
  useEffect(() => {
    api.get('/api/admin/platform-settings')
      .then(res => {
        if (res.data.success) {
          const { envInfo: ei, smtpPass: _masked, ...rest } = res.data.data;
          setSettings(s => ({ ...s, ...rest, smtpPass: '' })); // never pre-fill password
          if (ei) setEnvInfo(ei);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));

    // Fetch admin's current IP for easy whitelisting
    api.get('/api/admin/my-ip')
      .then(res => { if (res.data?.data?.ip) setMyIp(res.data.data.ip); })
      .catch(() => {});
  }, []);

  // ── Save ─────────────────────────────────────────────────────────────────────
  const handleSave = async () => {
    setSaving(true);
    try {
      const res = await api.put('/api/admin/platform-settings', settings);
      if (res.data.success) {
        showAlert('Settings saved successfully ✓', 'success');
      }
    } catch (err) {
      showAlert(err.response?.data?.message || 'Failed to save settings', 'error');
    } finally {
      setSaving(false);
    }
  };

  // ── Test existing (env) email ─────────────────────────────────────────────────
  const handleTestEmail = async () => {
    setTestingEmail(true);
    try {
      const res = await api.post('/api/admin/test-email');
      showAlert(res.data.message || 'Test email sent!', 'success');
    } catch (err) {
      showAlert(err.response?.data?.message || 'Failed — check SMTP config in server .env', 'error');
    } finally {
      setTestingEmail(false);
    }
  };

  // ── Test current form's SMTP config ──────────────────────────────────────────
  const handleTestSmtp = async () => {
    if (!settings.smtpHost || !settings.smtpUser || !settings.smtpPass) {
      showAlert('Fill in Host, Username and Password before testing', 'error');
      return;
    }
    setTestingSmtp(true);
    setSmtpStatus(null);
    try {
      const res = await api.post('/api/admin/test-smtp', {
        host:       settings.smtpHost,
        port:       settings.smtpPort,
        encryption: settings.smtpEncryption,
        user:       settings.smtpUser,
        pass:       settings.smtpPass,
        fromName:   settings.smtpFromName,
      });
      setSmtpStatus('ok');
      showAlert(res.data.message || 'Connection verified — test email sent!', 'success');
    } catch (err) {
      setSmtpStatus('fail');
      showAlert(err.response?.data?.message || 'Connection failed — check credentials', 'error');
    } finally {
      setTestingSmtp(false);
    }
  };

  // ── Select a gateway preset ───────────────────────────────────────────────────
  const selectGateway = (gw) => {
    setSmtpStatus(null);
    if (gw.preset) {
      setSettings(s => ({ ...s, emailGateway: gw.id, ...gw.preset }));
    } else {
      setSettings(s => ({ ...s, emailGateway: gw.id }));
    }
  };

  // ── IP whitelist helpers ──────────────────────────────────────────────────────
  const isValidIp = (ip) => /^(\d{1,3}\.){3}\d{1,3}$/.test(ip) && ip.split('.').every(n => Number(n) <= 255);

  const addIp = (ip) => {
    const trimmed = ip.trim();
    if (!isValidIp(trimmed)) { setIpError('Enter a valid IPv4 address (e.g. 192.168.1.1)'); return; }
    if (settings.allowedIps.includes(trimmed)) { setIpError('This IP is already in the list'); return; }
    setIpError('');
    setSettings(s => ({ ...s, allowedIps: [...s.allowedIps, trimmed] }));
    setNewIp('');
  };

  const removeIp = (ip) => setSettings(s => ({ ...s, allowedIps: s.allowedIps.filter(i => i !== ip) }));

  const TABS = [
    { id: 'GENERAL',  label: 'General',       icon: Settings  },
    { id: 'EMAILS',   label: 'Email Gateway',  icon: Mail      },
    { id: 'PAYMENTS', label: 'Gateways',       icon: CreditCard},
    { id: 'SECURITY', label: 'Security',       icon: Shield    },
    { id: 'NOTIFY',   label: 'Alerts',         icon: Bell      },
  ];

  return (
    <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.35 }}>

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.375rem' }}>
            Platform Settings
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Configure operational settings for the MediFind admin console.
          </p>
        </div>
        <motion.button
          whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }}
          onClick={handleSave}
          disabled={saving || loading}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.625rem',
            padding: '0.8rem 1.6rem', borderRadius: '12px',
            background: 'var(--primary)', color: 'white',
            fontWeight: 700, fontSize: '0.875rem', cursor: saving ? 'wait' : 'pointer',
            border: 'none', opacity: saving || loading ? 0.7 : 1,
            boxShadow: '0 4px 12px rgba(12,99,126,0.2)',
          }}
        >
          {saving
            ? <><RefreshCw size={16} style={{ animation: 'spin 1s linear infinite' }} /> Saving…</>
            : <><Save size={16} /> Save Changes</>
          }
        </motion.button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr', gap: '1.5rem', alignItems: 'start' }}>

        {/* Sidebar nav */}
        <div className="card" style={{ padding: '0.75rem', border: '1px solid var(--border)' }}>
          {TABS.map(tab => {
            const active = activeTab === tab.id;
            return (
              <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{
                width: '100%', display: 'flex', alignItems: 'center', gap: '0.875rem',
                padding: '0.875rem 1rem', borderRadius: '10px', border: 'none',
                background: active ? 'var(--primary-pale)' : 'transparent',
                color: active ? 'var(--primary)' : 'var(--text-muted)',
                fontWeight: active ? 700 : 500, fontSize: '0.875rem',
                cursor: 'pointer', transition: 'all 0.15s', textAlign: 'left',
                marginBottom: '2px',
              }}>
                <tab.icon size={17} />
                <span style={{ flex: 1 }}>{tab.label}</span>
                {active && <ChevronRight size={13} />}
              </button>
            );
          })}
        </div>

        {/* Content */}
        <div className="card" style={{ padding: '2rem', border: '1px solid var(--border)', minHeight: '520px' }}>
          <AnimatePresence mode="wait">
            <motion.div key={activeTab} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.2 }}>

              {/* ── GENERAL ───────────────────────────────────────────────── */}
              {activeTab === 'GENERAL' && (
                <div style={{ maxWidth: '600px' }}>
                  <SectionTitle title="General Configuration" sub="Operational identity of the platform" />

                  <div style={{ marginBottom: '1.5rem' }}>
                    <Label text="Organization Name" />
                    <Field value={settings.orgName} onChange={set('orgName')} placeholder="MediFind Network Pakistan" />
                  </div>

                  <div style={{ marginBottom: '2rem' }}>
                    <Label text="Support Email" sub="shown in outbound emails" />
                    <Field value={settings.supportEmail} onChange={set('supportEmail')} type="email" placeholder="support@medifind.pk" />
                  </div>

                  <div style={{ borderTop: '1px solid var(--border)', paddingTop: '1.75rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <ToggleRow
                      label="Maintenance Mode"
                      desc="Disables public access while performing server updates."
                      value={settings.maintenanceMode}
                      onChange={set('maintenanceMode')}
                    />
                    <ToggleRow
                      label="Verbose Debug Logging"
                      desc="Records detailed technical events in the system log (impacts performance)."
                      value={settings.debugLogging}
                      onChange={set('debugLogging')}
                    />
                  </div>

                  <div style={{ marginTop: '1.5rem', padding: '1rem 1.25rem', background: 'var(--info-bg)', border: '1px solid var(--info-border)', borderRadius: '10px', display: 'flex', gap: '10px', fontSize: '0.8rem', color: 'var(--info-fg)' }}>
                    <AlertCircle size={16} style={{ flexShrink: 0, marginTop: '1px' }} />
                    <span>Server environment (PORT, DATABASE_URL, JWT_SECRET) is managed via the <code style={{ background: 'rgba(0,0,0,0.06)', padding: '1px 5px', borderRadius: '4px' }}>.env</code> file and cannot be changed from this UI.</span>
                  </div>
                </div>
              )}

              {/* ── EMAIL GATEWAY ─────────────────────────────────────────── */}
              {activeTab === 'EMAILS' && (() => {
                const activeGw = GATEWAYS.find(g => g.id === settings.emailGateway) || GATEWAYS[0];
                const isEnv    = settings.emailGateway === 'env';
                return (
                  <div style={{ maxWidth: '640px' }}>
                    <SectionTitle title="Email Gateway" sub="Choose a provider and enter your credentials" />

                    {/* ── Gateway selector ── */}
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: '8px', marginBottom: '1.75rem' }}>
                      {GATEWAYS.map(gw => {
                        const isActive = settings.emailGateway === gw.id;
                        return (
                          <button
                            key={gw.id}
                            onClick={() => selectGateway(gw)}
                            title={gw.desc}
                            style={{
                              padding: '12px 6px',
                              borderRadius: '12px',
                              border: `2px solid ${isActive ? gw.color : 'var(--border)'}`,
                              background: isActive ? gw.pale : 'var(--surface)',
                              cursor: 'pointer',
                              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px',
                              transition: 'all 0.15s',
                            }}
                          >
                            <gw.icon size={18} color={isActive ? gw.color : 'var(--text-muted)'} />
                            <span style={{ fontSize: '0.65rem', fontWeight: 700, color: isActive ? gw.color : 'var(--text-muted)', textAlign: 'center', lineHeight: 1.2 }}>
                              {gw.label}
                            </span>
                          </button>
                        );
                      })}
                    </div>

                    {/* ── Active gateway info banner ── */}
                    <div style={{ background: activeGw.pale, border: `1px solid ${activeGw.color}30`, borderRadius: '12px', padding: '1rem 1.25rem', marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <activeGw.icon size={20} color={activeGw.color} style={{ flexShrink: 0 }} />
                      <div>
                        <p style={{ fontWeight: 700, fontSize: '0.875rem', color: 'var(--text-sub)', margin: 0 }}>{activeGw.label}</p>
                        <p style={{ fontSize: '0.76rem', color: 'var(--text-muted)', margin: '2px 0 0' }}>{activeGw.desc}</p>
                      </div>
                      {smtpStatus === 'ok'   && <CheckCircle size={18} color="#10B981" style={{ marginLeft: 'auto', flexShrink: 0 }} />}
                      {smtpStatus === 'fail' && <WifiOff     size={18} color="#EF4444" style={{ marginLeft: 'auto', flexShrink: 0 }} />}
                    </div>

                    {/* ── If .env mode: show read-only display ── */}
                    {isEnv ? (
                      <>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.25rem', marginBottom: '1.25rem' }}>
                          <div><Label text="SMTP Host" readOnly /><Field value={envInfo.smtpHost} onChange={() => {}} readOnly mono /></div>
                          <div><Label text="SMTP Port" readOnly /><Field value={envInfo.smtpPort} onChange={() => {}} readOnly mono /></div>
                        </div>
                        <div style={{ marginBottom: '1.5rem' }}>
                          <Label text="SMTP User" readOnly />
                          <Field value={envInfo.smtpUser} onChange={() => {}} readOnly mono />
                        </div>
                        <div style={{ marginBottom: '1.5rem', padding: '1rem 1.25rem', background: 'var(--info-bg)', border: '1px solid var(--info-border)', borderRadius: '10px', fontSize: '0.8rem', color: 'var(--info-fg)', display: 'flex', gap: '8px' }}>
                          <AlertCircle size={15} style={{ flexShrink: 0, marginTop: '1px' }} />
                          <span>To change these values, switch to a different gateway above or update <code style={{ background: 'rgba(0,0,0,0.06)', padding: '1px 5px', borderRadius: '4px' }}>.env</code> and restart the server.</span>
                        </div>
                        <motion.button whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }} onClick={handleTestEmail} disabled={testingEmail}
                          style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.75rem 1.375rem', borderRadius: '10px', background: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--secondary)', fontWeight: 700, fontSize: '0.85rem', cursor: testingEmail ? 'wait' : 'pointer', opacity: testingEmail ? 0.6 : 1 }}>
                          <RefreshCw size={14} style={{ animation: testingEmail ? 'spin 1.2s linear infinite' : 'none' }} />
                          {testingEmail ? 'Sending…' : 'Send Test Email to Admin'}
                        </motion.button>
                      </>
                    ) : (
                      /* ── Editable SMTP form ── */
                      <>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 120px', gap: '1rem', marginBottom: '1rem' }}>
                          <div>
                            <Label text="SMTP Host" />
                            <Field value={settings.smtpHost} onChange={set('smtpHost')} placeholder="smtp.gmail.com" mono />
                          </div>
                          <div>
                            <Label text="Port" />
                            <Field value={settings.smtpPort} onChange={set('smtpPort')} placeholder="587" mono />
                          </div>
                        </div>

                        <div style={{ marginBottom: '1rem' }}>
                          <Label text="Encryption" />
                          <div style={{ display: 'flex', gap: '8px' }}>
                            {['tls', 'ssl', 'none'].map(enc => (
                              <button
                                key={enc}
                                onClick={() => set('smtpEncryption')(enc)}
                                style={{
                                  padding: '8px 18px', borderRadius: '8px',
                                  border: `1.5px solid ${settings.smtpEncryption === enc ? 'var(--primary)' : 'var(--border)'}`,
                                  background: settings.smtpEncryption === enc ? 'var(--primary-pale)' : 'var(--surface)',
                                  color: settings.smtpEncryption === enc ? 'var(--primary)' : 'var(--text-muted)',
                                  fontWeight: 700, fontSize: '0.8rem', cursor: 'pointer',
                                  textTransform: 'uppercase', letterSpacing: '0.05em',
                                }}
                              >
                                {enc}
                              </button>
                            ))}
                          </div>
                        </div>

                        <div style={{ marginBottom: '1rem' }}>
                          <Label text="Username / From Address" />
                          <Field value={settings.smtpUser} onChange={set('smtpUser')} placeholder="you@gmail.com" mono />
                        </div>

                        <div style={{ marginBottom: '1rem' }}>
                          <Label text="Password / API Key" />
                          <div style={{ position: 'relative' }}>
                            <Field
                              value={settings.smtpPass}
                              onChange={val => { set('smtpPass')(val); setSmtpStatus(null); }}
                              type={showEmailPass ? 'text' : 'password'}
                              placeholder={activeGw.id === 'gmail' ? 'Gmail App Password (16 chars)' : activeGw.id === 'mailtrap' ? 'Mailtrap password' : 'SMTP password'}
                              mono
                            />
                            <button onClick={() => setShowEmailPass(v => !v)} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', display: 'flex' }}>
                              {showEmailPass ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                          </div>
                        </div>

                        <div style={{ marginBottom: '1.5rem' }}>
                          <Label text="From Name" sub="shown in recipients' inbox" />
                          <Field value={settings.smtpFromName} onChange={set('smtpFromName')} placeholder="MediFind Emergency Network" />
                        </div>

                        {/* Gmail App Password hint */}
                        {settings.emailGateway === 'gmail' && (
                          <div style={{ marginBottom: '1.25rem', padding: '0.875rem 1rem', background: '#FEF3C7', border: '1px solid #FDE68A', borderRadius: '10px', fontSize: '0.78rem', color: '#92400E', display: 'flex', gap: '8px' }}>
                            <AlertCircle size={14} style={{ flexShrink: 0, marginTop: '1px' }} />
                            <span>Gmail requires a 16-character <strong>App Password</strong>, not your regular password. Generate one at <strong>myaccount.google.com → Security → 2-Step Verification → App passwords</strong>.</span>
                          </div>
                        )}

                        {settings.emailGateway === 'mailtrap' && (
                          <div style={{ marginBottom: '1.25rem', padding: '0.875rem 1rem', background: '#EEF2FF', border: '1px solid #C7D2FE', borderRadius: '10px', fontSize: '0.78rem', color: '#3730A3', display: 'flex', gap: '8px' }}>
                            <AlertCircle size={14} style={{ flexShrink: 0, marginTop: '1px' }} />
                            <span>Copy your <strong>SMTP username and password</strong> from Mailtrap → your inbox → SMTP Settings. All emails are caught in the sandbox — nothing is delivered to real users.</span>
                          </div>
                        )}

                        {/* Action buttons */}
                        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                          <motion.button
                            whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
                            onClick={handleTestSmtp}
                            disabled={testingSmtp}
                            style={{
                              display: 'flex', alignItems: 'center', gap: '0.5rem',
                              padding: '0.75rem 1.375rem', borderRadius: '10px',
                              background: 'var(--surface)', border: '1px solid var(--border)',
                              color: 'var(--secondary)', fontWeight: 700, fontSize: '0.85rem',
                              cursor: testingSmtp ? 'wait' : 'pointer', opacity: testingSmtp ? 0.6 : 1,
                            }}
                          >
                            <Wifi size={14} style={{ animation: testingSmtp ? 'spin 1.2s linear infinite' : 'none' }} />
                            {testingSmtp ? 'Testing…' : 'Test Connection'}
                          </motion.button>

                          <motion.button
                            whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
                            onClick={handleSave}
                            disabled={saving}
                            style={{
                              display: 'flex', alignItems: 'center', gap: '0.5rem',
                              padding: '0.75rem 1.375rem', borderRadius: '10px',
                              background: 'var(--primary)', border: 'none',
                              color: 'white', fontWeight: 700, fontSize: '0.85rem',
                              cursor: saving ? 'wait' : 'pointer', opacity: saving ? 0.7 : 1,
                              boxShadow: '0 3px 10px rgba(12,99,126,0.2)',
                            }}
                          >
                            <Save size={14} />
                            {saving ? 'Saving…' : 'Save Gateway'}
                          </motion.button>
                        </div>
                      </>
                    )}
                  </div>
                );
              })()}

              {/* ── PAYMENTS ──────────────────────────────────────────────── */}
              {activeTab === 'PAYMENTS' && (
                <div style={{ maxWidth: '600px' }}>
                  <SectionTitle title="Payment Gateways" sub="Transaction processing configuration" />

                  {/* Stripe */}
                  <div style={{ border: '1px solid var(--border)', borderRadius: '16px', padding: '1.75rem', marginBottom: '1.5rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem' }}>
                        <div style={{ width: '36px', height: '36px', background: '#635bff', borderRadius: '9px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white' }}>
                          <Lock size={17} />
                        </div>
                        <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-sub)' }}>Stripe Integration</h3>
                      </div>
                      <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '3px 9px', borderRadius: '20px', background: envInfo.stripeMode === 'LIVE' ? 'var(--success-bg)' : 'var(--warning-bg)', color: envInfo.stripeMode === 'LIVE' ? 'var(--success-fg)' : 'var(--warning-fg)', border: `1px solid ${envInfo.stripeMode === 'LIVE' ? 'var(--success-border)' : 'var(--warning-border)'}` }}>
                        {envInfo.stripeMode === 'NOT CONFIGURED' ? 'NOT SET' : envInfo.stripeMode + ' MODE'}
                      </span>
                    </div>

                    <div style={{ padding: '1rem', background: 'var(--info-bg)', border: '1px solid var(--info-border)', borderRadius: '10px', display: 'flex', gap: '10px', fontSize: '0.8rem', color: 'var(--info-fg)' }}>
                      <AlertCircle size={15} style={{ flexShrink: 0, marginTop: '1px' }} />
                      <span>Stripe keys are configured via <code style={{ background: 'rgba(0,0,0,0.06)', padding: '1px 5px', borderRadius: '4px' }}>STRIPE_SECRET_KEY</code> in the server <code style={{ background: 'rgba(0,0,0,0.06)', padding: '1px 5px', borderRadius: '4px' }}>.env</code> file. Current mode: <strong>{envInfo.stripeMode}</strong>.</span>
                    </div>
                  </div>

                  {/* HIPAA summary */}
                  <div style={{ border: '1px solid var(--success-border)', borderRadius: '16px', padding: '1.5rem', background: '#f0fdf4', marginBottom: '1.5rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', marginBottom: '1.25rem' }}>
                      <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: '#10b981', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Shield size={20} />
                      </div>
                      <div>
                        <h3 style={{ fontSize: '1rem', fontWeight: 700, color: '#064e3b', margin: 0 }}>HIPAA Compliance Status</h3>
                        <p style={{ fontSize: '0.78rem', color: '#047857', margin: 0 }}>All data protection standards are active</p>
                      </div>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.75rem' }}>
                      {[
                        { key: 'PHI Audit Logs', val: 'Enabled' },
                        { key: 'Data Minimization', val: 'Active' },
                        { key: 'Auto Timeout', val: `${settings.sessionTimeoutMinutes}m` },
                      ].map(({ key, val }) => (
                        <div key={key} style={{ padding: '0.75rem', background: 'white', borderRadius: '9px', border: '1px solid var(--success-border)' }}>
                          <p style={{ fontSize: '0.65rem', fontWeight: 700, color: '#059669', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '3px' }}>{key}</p>
                          <p style={{ fontSize: '0.875rem', fontWeight: 700, color: '#064e3b' }}>{val}</p>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* JazzCash */}
                  <div style={{ border: '1px solid var(--border)', borderRadius: '16px', padding: '1.5rem', opacity: 0.55 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-sub)' }}>JazzCash / EasyPaisa</h3>
                      <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '3px 9px', borderRadius: '20px', background: 'var(--surface-raised)', color: 'var(--text-muted)', border: '1px solid var(--border)' }}>COMING SOON</span>
                    </div>
                    <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginTop: '6px' }}>Local Pakistani payment provider integration for direct bank transfers.</p>
                  </div>
                </div>
              )}

              {/* ── SECURITY ──────────────────────────────────────────────── */}
              {activeTab === 'SECURITY' && (
                <div style={{ maxWidth: '620px' }}>
                  <SectionTitle title="Security & Access Control" sub="Changes take effect immediately after saving" />

                  {/* ── 2FA ── */}
                  <div style={{ marginBottom: '1rem' }}>
                    <ToggleRow
                      label="Require 2FA for Admin Accounts"
                      desc="Admins must enter an email OTP after password login. Takes effect on next login."
                      value={settings.twoFactorRequired}
                      onChange={set('twoFactorRequired')}
                    />
                    {settings.twoFactorRequired && (
                      <div style={{ marginTop: '8px', padding: '10px 14px', background: '#EFF6FF', border: '1px solid #BFDBFE', borderRadius: '10px', fontSize: '0.78rem', color: '#1D4ED8', display: 'flex', gap: '8px', alignItems: 'flex-start' }}>
                        <ShieldCheck size={14} style={{ flexShrink: 0, marginTop: '1px' }} />
                        <span><strong>Email OTP enabled.</strong> After entering the correct password, a 6-digit one-time code will be sent to the admin's registered email address. The session only starts after the code is verified.</span>
                      </div>
                    )}
                  </div>

                  {/* ── Session Timeout ── */}
                  <div style={{ marginBottom: '1rem' }}>
                    <ToggleRow
                      label="Session Auto-Timeout"
                      desc={`Auto-logout after ${settings.sessionTimeoutMinutes} min of inactivity (HIPAA). Always on.`}
                      value={true}
                      onChange={() => {}}
                      disabled
                    />
                    <div style={{ marginTop: '10px', display: 'flex', alignItems: 'center', gap: '12px', paddingLeft: '4px' }}>
                      <Label text="Timeout (minutes)" sub="5 – 120" />
                      <input
                        type="number" min={5} max={120}
                        value={settings.sessionTimeoutMinutes}
                        onChange={e => set('sessionTimeoutMinutes')(Math.max(5, Math.min(120, Number(e.target.value))))}
                        style={{ width: '90px', padding: '0.6rem 0.875rem', borderRadius: '9px', border: '1px solid var(--border)', background: 'var(--surface)', fontSize: '0.9rem', outline: 'none', textAlign: 'center', fontWeight: 700 }}
                      />
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Applied to all active sessions after save</span>
                    </div>
                  </div>

                  {/* ── IP Whitelisting ── */}
                  <div style={{ marginBottom: '1.5rem' }}>
                    <ToggleRow
                      label="IP Whitelisting"
                      desc="Block admin console access from any IP not in the list below. Enforced server-side."
                      value={settings.ipWhitelisting}
                      onChange={val => {
                        set('ipWhitelisting')(val);
                        if (val && settings.allowedIps.length === 0 && myIp) {
                          // Auto-add their current IP so they don't lock themselves out
                          setSettings(s => ({ ...s, ipWhitelisting: val, allowedIps: [myIp] }));
                        }
                      }}
                    />

                    {settings.ipWhitelisting && (
                      <div style={{ marginTop: '12px', padding: '1.25rem', background: 'var(--surface-raised)', border: '1px solid var(--border)', borderRadius: '14px' }}>

                        {/* Current IP helper */}
                        {myIp && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '12px', padding: '8px 12px', background: '#EFF6FF', border: '1px solid #BFDBFE', borderRadius: '8px' }}>
                            <Globe size={14} color="#2563EB" />
                            <span style={{ fontSize: '0.78rem', color: '#1D4ED8', flex: 1 }}>
                              Your current IP: <strong style={{ fontFamily: 'monospace' }}>{myIp}</strong>
                            </span>
                            {!settings.allowedIps.includes(myIp) && (
                              <button
                                onClick={() => addIp(myIp)}
                                style={{ fontSize: '0.72rem', fontWeight: 700, padding: '3px 10px', borderRadius: '6px', background: '#2563EB', color: 'white', border: 'none', cursor: 'pointer' }}
                              >
                                + Add My IP
                              </button>
                            )}
                          </div>
                        )}

                        {/* Allowed IPs list */}
                        {settings.allowedIps.length === 0 ? (
                          <div style={{ padding: '12px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem', border: '1px dashed var(--border)', borderRadius: '8px', marginBottom: '12px' }}>
                            No IPs added — add at least one or whitelisting will block everyone including you
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '12px' }}>
                            {settings.allowedIps.map(ip => (
                              <div key={ip} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '8px 12px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '8px' }}>
                                <ShieldCheck size={14} color="var(--primary)" />
                                <code style={{ flex: 1, fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-sub)' }}>{ip}</code>
                                {ip === myIp && <span style={{ fontSize: '0.65rem', fontWeight: 700, padding: '2px 6px', background: 'var(--primary-pale)', color: 'var(--primary)', borderRadius: '4px' }}>YOU</span>}
                                <button onClick={() => removeIp(ip)} style={{ background: 'none', border: 'none', color: '#EF4444', cursor: 'pointer', display: 'flex', padding: '2px' }}>
                                  <Trash2 size={14} />
                                </button>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Add new IP */}
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <input
                            value={newIp}
                            onChange={e => { setNewIp(e.target.value); setIpError(''); }}
                            onKeyDown={e => e.key === 'Enter' && addIp(newIp)}
                            placeholder="192.168.1.100"
                            style={{ flex: 1, padding: '0.65rem 0.875rem', borderRadius: '9px', border: `1px solid ${ipError ? '#EF4444' : 'var(--border)'}`, background: 'var(--surface)', fontSize: '0.875rem', fontFamily: 'monospace', outline: 'none' }}
                          />
                          <button
                            onClick={() => addIp(newIp)}
                            style={{ display: 'flex', alignItems: 'center', gap: '5px', padding: '0.65rem 1rem', borderRadius: '9px', background: 'var(--primary)', color: 'white', border: 'none', fontWeight: 700, fontSize: '0.82rem', cursor: 'pointer' }}
                          >
                            <Plus size={14} /> Add
                          </button>
                        </div>
                        {ipError && <p style={{ fontSize: '0.75rem', color: '#EF4444', marginTop: '5px' }}>{ipError}</p>}

                        <div style={{ marginTop: '10px', padding: '8px 12px', background: '#FEF3C7', border: '1px solid #FDE68A', borderRadius: '8px', fontSize: '0.74rem', color: '#92400E', display: 'flex', gap: '6px' }}>
                          <AlertCircle size={13} style={{ flexShrink: 0, marginTop: '1px' }} />
                          <span>If you remove your own IP and save, you will be locked out of the admin panel immediately. Always keep your IP in the list.</span>
                        </div>
                      </div>
                    )}
                  </div>

                  {/* ── Save button ── */}
                  <motion.button
                    whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
                    onClick={handleSave} disabled={saving}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '7px',
                      padding: '0.8rem 1.6rem', borderRadius: '12px',
                      background: 'var(--primary)', color: 'white',
                      fontWeight: 700, fontSize: '0.875rem',
                      border: 'none', cursor: saving ? 'wait' : 'pointer',
                      opacity: saving ? 0.7 : 1,
                      boxShadow: '0 4px 12px rgba(12,99,126,0.2)',
                    }}
                  >
                    {saving ? <><RefreshCw size={15} style={{ animation: 'spin 1s linear infinite' }} /> Saving…</> : <><Save size={15} /> Save Security Settings</>}
                  </motion.button>
                </div>
              )}

              {/* ── ALERTS ────────────────────────────────────────────────── */}
              {activeTab === 'NOTIFY' && (
                <div style={{ maxWidth: '600px' }}>
                  <SectionTitle title="System Alert Destinations" sub="Where critical system events are dispatched" />

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                    {/* Email alert */}
                    <div style={{ padding: '1.5rem', background: 'var(--surface-raised)', border: '1px solid var(--border)', borderRadius: '14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.875rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                          <Mail size={17} color="var(--primary)" />
                          <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-sub)' }}>Alert Email Address</span>
                        </div>
                        <CheckCircle size={16} color="var(--s-resolved)" />
                      </div>
                      <Field value={settings.alertEmail} onChange={set('alertEmail')} type="email" placeholder="ops@medifind.pk" />
                      <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '6px' }}>Receives server errors, failed jobs, and critical system notifications.</p>
                    </div>

                    {/* Webhook */}
                    <div style={{ padding: '1.5rem', background: 'var(--surface-raised)', border: '1px solid var(--border)', borderRadius: '14px' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.875rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                          <Bell size={17} color="#8b5cf6" />
                          <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-sub)' }}>Webhook URL (Discord / Slack)</span>
                        </div>
                        {settings.alertWebhook ? <CheckCircle size={16} color="var(--s-resolved)" /> : <AlertCircle size={16} color="var(--text-muted)" />}
                      </div>
                      <Field value={settings.alertWebhook} onChange={set('alertWebhook')} placeholder="https://discord.com/api/webhooks/..." />
                      <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '6px' }}>Leave blank to disable webhook notifications.</p>
                    </div>
                  </div>
                </div>
              )}

            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  );
};

export default PlatformSettings;

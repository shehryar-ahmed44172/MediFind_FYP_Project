import React, { useState, useEffect } from 'react';
import { Eye, EyeOff, Plus, Trash2, Globe, ShieldCheck, Send, Wifi } from 'lucide-react';
import api from '../../services/api';
import { useAlert } from '../../context/hooks';
import {
  PageHeader, FormSection, FormField, Input, Switch, StickySaveBar, SegmentedControl, Button, IconButton,
  StatusBadge, Notice, DetailItem,
} from '../../components/ui';

/* Inline code token used inside help text / notices */
const Code = ({ children }) => (
  <code style={{
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace', fontSize: '12px',
    padding: '1px 5px', borderRadius: '4px', background: 'var(--surface)', border: '1px solid var(--border)', color: 'var(--text-main)',
  }}>{children}</code>
);

const MONO = { fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Consolas, monospace', fontSize: '13px' };
const READ_ONLY = <StatusBadge tone="neutral" dot={false} style={{ height: '18px', fontSize: '11px' }}>Env var · read only</StatusBadge>;

const DEFAULT_SETTINGS = {
  orgName:              'MediFind Emergency Response Network',
  supportEmail:         'support@medifind.pk',
  maintenanceMode:      false,
  debugLogging:         false,
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
};

// ── Gateway presets ──────────────────────────────────────────────────────────
const GATEWAYS = [
  { id: 'env',      label: 'Server .env',  name: 'Server .env',          desc: 'Use SMTP_HOST / SMTP_USER / SMTP_PASS from the server environment file', preset: null },
  { id: 'gmail',    label: 'Gmail',        name: 'Gmail SMTP',           desc: 'Google Workspace or personal Gmail with App Password', preset: { smtpHost: 'smtp.gmail.com', smtpPort: '587', smtpEncryption: 'tls' } },
  { id: 'mailtrap', label: 'Mailtrap',     name: 'Mailtrap Sandbox',     desc: 'Email testing sandbox — catches all outbound mail without delivery', preset: { smtpHost: 'sandbox.smtp.mailtrap.io', smtpPort: '2525', smtpEncryption: 'tls' } },
  { id: 'outlook',  label: 'Outlook / 365', name: 'Outlook / Office 365', desc: 'Microsoft 365 organizational email account', preset: { smtpHost: 'smtp.office365.com', smtpPort: '587', smtpEncryption: 'tls' } },
  { id: 'custom',   label: 'Custom',       name: 'Custom SMTP',          desc: 'Any SMTP server — enter host, port and credentials manually', preset: { smtpHost: '', smtpPort: '587', smtpEncryption: 'tls' } },
];

const SECTIONS = [
  { id: 'settings-general',  label: 'General' },
  { id: 'settings-email',    label: 'Email gateway' },
  { id: 'settings-payments', label: 'Payments' },
  { id: 'settings-security', label: 'Security' },
];

const PlatformSettings = () => {
  const { showAlert } = useAlert();
  const [loading, setLoading]     = useState(true);
  const [saving, setSaving]       = useState(false);
  const [testingEmail, setTestingEmail]   = useState(false);
  const [testingSmtp,  setTestingSmtp]    = useState(false);
  const [smtpStatus,   setSmtpStatus]     = useState(null); // null | 'ok' | 'fail'
  const [showEmailPass, setShowEmailPass] = useState(false);
  const [myIp,         setMyIp]           = useState('');
  const [newIp,        setNewIp]          = useState('');
  const [ipError,      setIpError]        = useState('');

  // ── Settings state (+ last loaded/saved snapshot for dirty tracking) ────────
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [savedSettings, setSavedSettings] = useState(DEFAULT_SETTINGS);

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
          setSavedSettings({ ...DEFAULT_SETTINGS, ...rest, smtpPass: '' });
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

  const dirty = !loading && JSON.stringify(settings) !== JSON.stringify(savedSettings);

  // ── Save ─────────────────────────────────────────────────────────────────────
  const handleSave = async () => {
    setSaving(true);
    const snapshot = settings;
    try {
      const res = await api.put('/api/admin/platform-settings', snapshot);
      if (res.data.success) {
        setSavedSettings(snapshot);
        showAlert('Settings saved successfully ✓', 'success');
      }
    } catch (err) {
      showAlert(err.response?.data?.message || 'Failed to save settings', 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleDiscard = () => {
    setSettings(savedSettings);
    setSmtpStatus(null);
    setIpError('');
    setNewIp('');
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

  const scrollTo = (id) => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });

  const activeGw = GATEWAYS.find(g => g.id === settings.emailGateway) || GATEWAYS[0];
  const isEnv    = settings.emailGateway === 'env';
  const stripeLive = envInfo.stripeMode === 'LIVE';

  return (
    <div>
      <PageHeader
        title="Platform Settings"
        description="Configure operational settings for the MediFind admin console."
        meta={(
          <nav aria-label="Settings sections" style={{ display: 'flex', gap: '4px 16px', flexWrap: 'wrap' }}>
            {SECTIONS.map(s => (
              <button key={s.id} type="button" className="mf-link" onClick={() => scrollTo(s.id)}
                style={{ background: 'none', border: 'none', padding: 0, fontSize: '13px', cursor: 'pointer', fontFamily: 'inherit' }}>
                {s.label}
              </button>
            ))}
          </nav>
        )}
      />

      <div className="mf-stack">
        {/* ── GENERAL ───────────────────────────────────────────────── */}
        <FormSection id="settings-general" title="General" description="Operational identity of the platform and system-wide switches.">
          <FormField label="Organization name" htmlFor="ps-org">
            <Input id="ps-org" value={settings.orgName} onChange={e => set('orgName')(e.target.value)} placeholder="MediFind Network Pakistan" />
          </FormField>
          <FormField label="Support email" htmlFor="ps-support" help="Shown in outbound emails.">
            <Input id="ps-support" type="email" value={settings.supportEmail} onChange={e => set('supportEmail')(e.target.value)} placeholder="support@medifind.pk" />
          </FormField>
          <FormField inline label="Maintenance mode" htmlFor="ps-maint" help="Disables public access while performing server updates.">
            <Switch id="ps-maint" label="Maintenance mode" checked={settings.maintenanceMode} onChange={set('maintenanceMode')} />
          </FormField>
          <FormField inline label="Verbose debug logging" htmlFor="ps-debug" help="Records detailed technical events in the system log (impacts performance).">
            <Switch id="ps-debug" label="Verbose debug logging" checked={settings.debugLogging} onChange={set('debugLogging')} />
          </FormField>
          <Notice tone="info">
            Server environment (PORT, DATABASE_URL, JWT_SECRET) is managed via the <Code>.env</Code> file and cannot be changed from this UI.
          </Notice>
        </FormSection>

        {/* ── EMAIL GATEWAY ─────────────────────────────────────────── */}
        <FormSection
          id="settings-email"
          title="Email gateway"
          description="Choose a provider and enter your credentials."
          actions={smtpStatus === 'ok'
            ? <StatusBadge tone="success">Connection verified</StatusBadge>
            : smtpStatus === 'fail' ? <StatusBadge tone="danger">Connection failed</StatusBadge> : null}
        >
          <FormField label="Provider" help={`${activeGw.name} — ${activeGw.desc}`}>
            <SegmentedControl
              ariaLabel="Email provider"
              value={settings.emailGateway}
              onChange={(v) => selectGateway(GATEWAYS.find(g => g.id === v) || GATEWAYS[0])}
              options={GATEWAYS.map(g => ({ value: g.id, label: g.label }))}
            />
          </FormField>

          {isEnv ? (
            <>
              <div className="mf-grid-2">
                <FormField label="SMTP host" htmlFor="ps-env-host" right={READ_ONLY}>
                  <Input id="ps-env-host" value={envInfo.smtpHost} readOnly style={MONO} />
                </FormField>
                <FormField label="SMTP port" htmlFor="ps-env-port">
                  <Input id="ps-env-port" value={envInfo.smtpPort} readOnly style={MONO} />
                </FormField>
              </div>
              <FormField label="SMTP user" htmlFor="ps-env-user" right={READ_ONLY}>
                <Input id="ps-env-user" value={envInfo.smtpUser} readOnly style={MONO} />
              </FormField>
              <Notice tone="info">
                To change these values, switch to a different gateway above or update <Code>.env</Code> and restart the server.
              </Notice>
              <div>
                <Button icon={Send} onClick={handleTestEmail} disabled={testingEmail}>
                  {testingEmail ? 'Sending…' : 'Send test email to admin'}
                </Button>
              </div>
            </>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 120px', gap: '16px' }}>
                <FormField label="SMTP host" htmlFor="ps-host">
                  <Input id="ps-host" value={settings.smtpHost} onChange={e => set('smtpHost')(e.target.value)} placeholder="smtp.gmail.com" style={MONO} />
                </FormField>
                <FormField label="Port" htmlFor="ps-port">
                  <Input id="ps-port" value={settings.smtpPort} onChange={e => set('smtpPort')(e.target.value)} placeholder="587" style={MONO} />
                </FormField>
              </div>

              <FormField label="Encryption">
                <SegmentedControl
                  ariaLabel="SMTP encryption"
                  value={settings.smtpEncryption}
                  onChange={set('smtpEncryption')}
                  options={[{ value: 'tls', label: 'TLS' }, { value: 'ssl', label: 'SSL' }, { value: 'none', label: 'None' }]}
                />
              </FormField>

              <FormField label="Username / from address" htmlFor="ps-user">
                <Input id="ps-user" value={settings.smtpUser} onChange={e => set('smtpUser')(e.target.value)} placeholder="you@gmail.com" style={MONO} />
              </FormField>

              <FormField label="Password / API key" htmlFor="ps-pass" help="Never pre-filled. Enter it again to test or change credentials.">
                <div style={{ position: 'relative' }}>
                  <Input
                    id="ps-pass"
                    value={settings.smtpPass}
                    onChange={e => { set('smtpPass')(e.target.value); setSmtpStatus(null); }}
                    type={showEmailPass ? 'text' : 'password'}
                    placeholder={activeGw.id === 'gmail' ? 'Gmail App Password (16 chars)' : activeGw.id === 'mailtrap' ? 'Mailtrap password' : 'SMTP password'}
                    style={{ ...MONO, paddingRight: '40px' }}
                  />
                  <div style={{ position: 'absolute', right: '3px', top: '3px' }}>
                    <IconButton label={showEmailPass ? 'Hide password' : 'Show password'} icon={showEmailPass ? EyeOff : Eye} onClick={() => setShowEmailPass(v => !v)} />
                  </div>
                </div>
              </FormField>

              <FormField label="From name" htmlFor="ps-from" help="Shown in recipients' inbox.">
                <Input id="ps-from" value={settings.smtpFromName} onChange={e => set('smtpFromName')(e.target.value)} placeholder="MediFind Emergency Network" />
              </FormField>

              {settings.emailGateway === 'gmail' && (
                <Notice tone="warning">
                  Gmail requires a 16-character <strong>App Password</strong>, not your regular password. Generate one at <strong>myaccount.google.com → Security → 2-Step Verification → App passwords</strong>.
                </Notice>
              )}
              {settings.emailGateway === 'mailtrap' && (
                <Notice tone="info">
                  Copy your <strong>SMTP username and password</strong> from Mailtrap → your inbox → SMTP Settings. All emails are caught in the sandbox — nothing is delivered to real users.
                </Notice>
              )}

              <div>
                <Button icon={Wifi} onClick={handleTestSmtp} disabled={testingSmtp}>
                  {testingSmtp ? 'Testing…' : 'Test connection'}
                </Button>
              </div>
            </>
          )}
        </FormSection>

        {/* ── PAYMENTS ──────────────────────────────────────────────── */}
        <FormSection id="settings-payments" title="Payments & compliance" description="Transaction processing configuration. Read-only; managed on the server.">
          <FormField
            label="Stripe integration"
            right={<StatusBadge tone={stripeLive ? 'success' : 'warning'}>{envInfo.stripeMode === 'NOT CONFIGURED' ? 'Not set' : `${envInfo.stripeMode} mode`}</StatusBadge>}
          >
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
              Stripe keys are configured via <Code>STRIPE_SECRET_KEY</Code> in the server <Code>.env</Code> file. Current mode: <strong style={{ color: 'var(--text-main)', fontWeight: 500 }}>{envInfo.stripeMode}</strong>.
            </p>
          </FormField>

          <FormField label="HIPAA compliance status" right={<StatusBadge tone="success">All data protection standards are active</StatusBadge>}>
            <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '12px', margin: 0, padding: '12px', border: '1px solid var(--border)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface-alt)' }}>
              <DetailItem label="PHI audit logs">Enabled</DetailItem>
              <DetailItem label="Data minimization">Active</DetailItem>
              <DetailItem label="Auto timeout"><span className="mf-num">{settings.sessionTimeoutMinutes}m</span></DetailItem>
            </dl>
          </FormField>

          <FormField label="JazzCash / EasyPaisa" right={<StatusBadge tone="neutral" dot={false}>Coming soon</StatusBadge>}>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>Local Pakistani payment provider integration for direct bank transfers.</p>
          </FormField>
        </FormSection>

        {/* ── SECURITY ──────────────────────────────────────────────── */}
        <FormSection id="settings-security" title="Security & access control" description="Changes take effect immediately after saving.">
          <FormField inline label="Require 2FA for admin accounts" htmlFor="ps-2fa" help="Admins must enter an email OTP after password login. Takes effect on next login.">
            <Switch id="ps-2fa" label="Require 2FA for admin accounts" checked={settings.twoFactorRequired} onChange={set('twoFactorRequired')} />
          </FormField>
          {settings.twoFactorRequired && (
            <Notice tone="info">
              <strong style={{ fontWeight: 600 }}>Email OTP enabled.</strong> After entering the correct password, a 6-digit one-time code will be sent to the admin's registered email address. The session only starts after the code is verified.
            </Notice>
          )}

          <FormField inline label="Session auto-timeout" htmlFor="ps-timeout-switch" help={`Auto-logout after ${settings.sessionTimeoutMinutes} min of inactivity (HIPAA). Always on.`}>
            <Switch id="ps-timeout-switch" label="Session auto-timeout" checked onChange={() => {}} disabled />
          </FormField>
          <FormField label="Timeout (minutes)" htmlFor="ps-timeout" help="Between 5 and 120. Applied to all active sessions after save.">
            <Input
              id="ps-timeout"
              type="number" min={5} max={120}
              className="mf-num"
              value={settings.sessionTimeoutMinutes}
              onChange={e => set('sessionTimeoutMinutes')(Math.max(5, Math.min(120, Number(e.target.value))))}
              style={{ width: '120px' }}
            />
          </FormField>

          <FormField inline label="IP whitelisting" htmlFor="ps-ipwl" help="Block admin console access from any IP not in the list below. Enforced server-side.">
            <Switch
              id="ps-ipwl"
              label="IP whitelisting"
              checked={settings.ipWhitelisting}
              onChange={val => {
                set('ipWhitelisting')(val);
                if (val && settings.allowedIps.length === 0 && myIp) {
                  // Auto-add their current IP so they don't lock themselves out
                  setSettings(s => ({ ...s, ipWhitelisting: val, allowedIps: [myIp] }));
                }
              }}
            />
          </FormField>

          {settings.ipWhitelisting && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '12px', border: '1px solid var(--border)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface-alt)' }}>
              {myIp && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: 'var(--admin-text-sub)' }}>
                  <Globe size={14} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />
                  <span style={{ flex: 1 }}>Your current IP: <span style={{ ...MONO, color: 'var(--text-main)' }}>{myIp}</span></span>
                  {!settings.allowedIps.includes(myIp) && (
                    <Button size="sm" icon={Plus} onClick={() => addIp(myIp)}>Add my IP</Button>
                  )}
                </div>
              )}

              {settings.allowedIps.length === 0 ? (
                <div style={{ padding: '12px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px', border: '1px dashed var(--border-strong)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface)' }}>
                  No IPs added — add at least one or whitelisting will block everyone including you
                </div>
              ) : (
                <ul style={{ listStyle: 'none', margin: 0, padding: 0, border: '1px solid var(--border)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface)', overflow: 'hidden' }}>
                  {settings.allowedIps.map((ip, i) => (
                    <li key={ip} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '4px 4px 4px 12px', minHeight: '38px', borderTop: i === 0 ? 'none' : '1px solid var(--border)' }}>
                      <ShieldCheck size={14} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />
                      <span style={{ ...MONO, flex: 1, color: 'var(--text-main)' }}>{ip}</span>
                      {ip === myIp && <StatusBadge tone="info" dot={false}>You</StatusBadge>}
                      <IconButton label={`Remove ${ip}`} icon={Trash2} tone="danger" onClick={() => removeIp(ip)} />
                    </li>
                  ))}
                </ul>
              )}

              <FormField label="Add IP address" htmlFor="ps-newip" error={ipError}>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <Input
                    id="ps-newip"
                    value={newIp}
                    onChange={e => { setNewIp(e.target.value); setIpError(''); }}
                    onKeyDown={e => e.key === 'Enter' && addIp(newIp)}
                    placeholder="192.168.1.100"
                    aria-invalid={!!ipError}
                    style={{ ...MONO, flex: 1, ...(ipError ? { borderColor: 'var(--error-fg)' } : null) }}
                  />
                  <Button icon={Plus} onClick={() => addIp(newIp)}>Add</Button>
                </div>
              </FormField>

              <Notice tone="warning">
                If you remove your own IP and save, you will be locked out of the admin panel immediately. Always keep your IP in the list.
              </Notice>
            </div>
          )}
        </FormSection>
      </div>

      <StickySaveBar visible={dirty} saving={saving} onSave={handleSave} onDiscard={handleDiscard} />
    </div>
  );
};

export default PlatformSettings;

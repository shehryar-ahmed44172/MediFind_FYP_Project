import React, { useMemo, useState } from 'react';
import { Eye, EyeOff, KeyRound, ShieldCheck, LogOut } from 'lucide-react';
import api from '../../services/api';
import { useAlert, useAuth } from '../../context/hooks';
import {
  PageHeader, FormSection, FormField, Input, Button, IconButton, Notice, Panel, DetailItem,
} from '../../components/ui';

// Must match the server rule in src/utils/password.ts — the server is what
// enforces it; these checks only tell the admin why a password is refused.
const RULES = [
  { id: 'length', label: 'At least 10 characters', test: (v) => v.length >= 10 },
  { id: 'letter', label: 'Contains a letter', test: (v) => /[A-Za-z]/.test(v) },
  { id: 'number', label: 'Contains a number', test: (v) => /[0-9]/.test(v) },
];

const WEAK = ['password', 'admin', 'adminpassword', 'medifind', 'qwerty123', '12345678'];

const PasswordInput = ({ id, value, onChange, autoComplete, placeholder }) => {
  const [visible, setVisible] = useState(false);
  return (
    <div style={{ position: 'relative' }}>
      <Input
        id={id}
        type={visible ? 'text' : 'password'}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete={autoComplete}
        placeholder={placeholder}
        spellCheck={false}
        style={{ paddingRight: '40px' }}
      />
      <div style={{ position: 'absolute', top: '50%', right: '4px', transform: 'translateY(-50%)' }}>
        <IconButton
          label={visible ? 'Hide password' : 'Show password'}
          onClick={() => setVisible((v) => !v)}
          icon={visible ? EyeOff : Eye}
        />
      </div>
    </div>
  );
};

/**
 * Admin account security — changing your own password.
 *
 * The server verifies the current password, applies the strength rules and
 * revokes every refresh token, so this page signs the admin out afterwards:
 * the new password must be used to get back in.
 */
const AccountSecurity = () => {
  const { showAlert } = useAlert();
  const { user, logout } = useAuth();

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  const passed = useMemo(() => RULES.map((r) => ({ ...r, ok: r.test(newPassword) })), [newPassword]);
  const looksWeak = useMemo(
    () => WEAK.some((w) => newPassword.toLowerCase().startsWith(w)),
    [newPassword],
  );
  const mismatch = confirmPassword.length > 0 && newPassword !== confirmPassword;
  const sameAsCurrent = newPassword.length > 0 && newPassword === currentPassword;
  const canSubmit =
    !saving &&
    currentPassword.length > 0 &&
    passed.every((r) => r.ok) &&
    !looksWeak &&
    !mismatch &&
    !sameAsCurrent &&
    confirmPassword.length > 0;

  const submit = async (e) => {
    e.preventDefault();
    if (!canSubmit) return;
    setSaving(true);
    setError('');
    try {
      await api.post('/api/password/change-password', { currentPassword, newPassword });
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setDone(true);
      showAlert('Password changed. Signing you out…', 'success');
      setTimeout(() => logout(), 2500);
    } catch (err) {
      const message =
        err?.response?.data?.message ||
        err?.response?.data?.error ||
        'Could not change the password. Please try again.';
      setError(message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Account security"
        subtitle="Your administrator sign-in"
        description="Change the password for your own admin account. Everyone else's accounts are managed in User Management."
      />

      {done ? (
        <Notice tone="success">
          Your password has been changed and all other sessions were signed out. You will be
          returned to the sign-in page in a moment — use the new password.
        </Notice>
      ) : (
        <div style={{ display: 'grid', gap: '20px', gridTemplateColumns: 'minmax(0, 560px) minmax(0, 340px)', alignItems: 'start' }}>
          <form onSubmit={submit} noValidate>
            <FormSection
              title="Change password"
              description="You need your current password. The new one takes effect immediately."
            >
              <FormField label="Current password" htmlFor="currentPassword">
                <PasswordInput
                  id="currentPassword"
                  value={currentPassword}
                  onChange={setCurrentPassword}
                  autoComplete="current-password"
                  placeholder="Your password today"
                />
              </FormField>

              <FormField
                label="New password"
                htmlFor="newPassword"
                error={looksWeak ? 'This password is too easy to guess.' : sameAsCurrent ? 'Choose a password different from the current one.' : undefined}
              >
                <PasswordInput
                  id="newPassword"
                  value={newPassword}
                  onChange={setNewPassword}
                  autoComplete="new-password"
                  placeholder="At least 10 characters"
                />
                <ul style={{ listStyle: 'none', margin: '10px 0 0', padding: 0, display: 'grid', gap: '4px' }}>
                  {passed.map((rule) => (
                    <li
                      key={rule.id}
                      style={{
                        fontSize: '12.5px',
                        color: rule.ok ? 'var(--success, #15803d)' : 'var(--text-muted)',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                      }}
                    >
                      <span aria-hidden="true">{rule.ok ? '✓' : '•'}</span>
                      {rule.label}
                    </li>
                  ))}
                </ul>
              </FormField>

              <FormField
                label="Confirm new password"
                htmlFor="confirmPassword"
                error={mismatch ? 'The two passwords do not match.' : undefined}
              >
                <PasswordInput
                  id="confirmPassword"
                  value={confirmPassword}
                  onChange={setConfirmPassword}
                  autoComplete="new-password"
                  placeholder="Type it again"
                />
              </FormField>

              {error && <Notice tone="danger" style={{ marginTop: '12px' }} role="alert">{error}</Notice>}

              <div style={{ marginTop: '16px' }}>
                <Button type="submit" variant="primary" icon={KeyRound} disabled={!canSubmit}>
                  {saving ? 'Changing…' : 'Change password'}
                </Button>
              </div>
            </FormSection>
          </form>

          <div style={{ display: 'grid', gap: '16px' }}>
            <Panel title="Signed in as" icon={ShieldCheck} padded>
              <dl style={{ display: 'grid', gap: '10px', margin: 0 }}>
                <DetailItem label="Name">{user?.fullName || '—'}</DetailItem>
                <DetailItem label="Email">{user?.email || '—'}</DetailItem>
                <DetailItem label="Role">System administrator</DetailItem>
              </dl>
            </Panel>

            <Notice tone="info" inline>
              <strong>What happens next.</strong> Changing the password signs out every other
              device and browser, including any session left open elsewhere. Five wrong attempts
              at the current password lock this form for 15 minutes.
            </Notice>

            <Notice tone="warning" inline>
              <LogOut size={14} aria-hidden="true" style={{ verticalAlign: '-2px', marginRight: '6px' }} />
              Never share this password, and change it immediately if the backend has been exposed
              publicly with the default one.
            </Notice>
          </div>
        </div>
      )}
    </>
  );
};

export default AccountSecurity;

import React, { useEffect, useState, useRef } from 'react';
import { Star } from 'lucide-react';
import api from '../services/api';
import { updateSubscriptionPlan, PLAN_OPTIONS, errorMessage } from '../services/adminApi';
import { resolveFileUrl } from '../utils/resolveFileUrl';
import { useAlert } from '../context/hooks';
import { Avatar, Button, DetailItem, Drawer, Notice, Select, Skeleton, StatusBadge } from './ui';
import { humanize, toneFor } from './uiStyles';

const fmtDate = (iso, withTime = false) => {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return withTime
    ? d.toLocaleString('en-PK', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
    : d.toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' });
};

const asList = (v) => (Array.isArray(v) ? v.filter(Boolean).map(x => (typeof x === 'object' ? (x.name || x.label || JSON.stringify(x)) : String(x))) : []);

function Section({ title, children }) {
  return (
    <section style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)' }}>
      <h3 style={{ fontSize: '13.5px', fontWeight: 600, color: 'var(--text-main)', margin: '0 0 12px' }}>{title}</h3>
      {children}
    </section>
  );
}

const DETAIL_GRID = { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '12px 20px', margin: 0 };

/**
 * Slide-over panel with a user's full profile.
 * Data: GET /api/admin/users/:id  (profile, patient emergency stats + last 20 emergencies,
 * responder last 20 requests, audit log count).
 */
export default function UserDetailDrawer({ userId, onClose, onUserUpdated }) {
  const { showAlert, showConfirm } = useAlert();
  const [state, setState] = useState({ loading: true, error: '', user: null });
  const [plan, setPlan] = useState('');
  const [savingPlan, setSavingPlan] = useState(false);
  const bodyRef = useRef(null);

  useEffect(() => {
    let alive = true;
    api.get(`/api/admin/users/${userId}`)
      .then(res => {
        if (!alive) return;
        if (res.data?.success) {
          setState({ loading: false, error: '', user: res.data.data });
          setPlan(res.data.data.subscriptionPlan || 'FREE');
        } else {
          setState({ loading: false, error: res.data?.message || 'Could not load this user.', user: null });
        }
      })
      .catch(err => { if (alive) setState({ loading: false, error: errorMessage(err, 'Could not load this user.'), user: null }); });
    return () => { alive = false; };
  }, [userId]);

  // Move focus into the drawer when it opens (Escape is handled by Drawer)
  useEffect(() => { bodyRef.current?.focus(); }, []);

  const { loading, error, user } = state;
  const currentPlan = user?.subscriptionPlan || 'FREE';

  const applyPlan = () => {
    const target = PLAN_OPTIONS.find(p => p.value === plan);
    showConfirm({
      title: 'Change subscription plan?',
      message: `${user.fullName} will move from ${PLAN_OPTIONS.find(p => p.value === currentPlan)?.label ?? currentPlan} to ${target?.label ?? plan}${target?.price ? ` (PKR ${target.price.toLocaleString()}/mo)` : ''}. This takes effect immediately.`,
      type: plan === 'FREE' ? 'warning' : 'info',
      confirmLabel: 'Change plan',
      onConfirm: async () => {
        setSavingPlan(true);
        try {
          const newPlan = await updateSubscriptionPlan(user.id, plan);
          setState(s => ({ ...s, user: { ...s.user, subscriptionPlan: newPlan } }));
          onUserUpdated?.({ id: user.id, subscriptionPlan: newPlan });
          showAlert(`Plan updated to ${PLAN_OPTIONS.find(p => p.value === newPlan)?.label ?? newPlan}.`, 'success');
        } catch (err) {
          setPlan(currentPlan);
          showAlert(err.message, 'error');
        } finally {
          setSavingPlan(false);
        }
      },
    });
  };

  const mp = user?.medicalProfile;
  const rp = user?.responder;
  const verification = rp ? (rp.verificationStatus || (rp.isVerified ? 'VERIFIED' : 'PENDING')) : null;

  const headerBadges = loading ? (
    <div style={{ marginTop: '8px', width: '200px' }}><Skeleton h={10} w="70%" /></div>
  ) : user ? (
    <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginTop: '8px' }}>
      <StatusBadge dot={false}>{humanize(user.role)}</StatusBadge>
      <StatusBadge tone={user.isActive ? 'success' : 'neutral'}>{user.isActive ? 'Active' : 'Inactive'}</StatusBadge>
      {user.isEmailVerified === false && <StatusBadge tone="warning">Email unverified</StatusBadge>}
    </div>
  ) : null;

  return (
    <Drawer
      onClose={onClose}
      centered
      width={680}
      title={user ? (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '10px', maxWidth: '100%' }}>
          <Avatar name={user.fullName} src={user.profileImageUrl ? resolveFileUrl(user.profileImageUrl) : undefined} size={32} />
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{user.fullName}</span>
        </span>
      ) : 'User details'}
      headerExtra={headerBadges}
    >
      <div ref={bodyRef} tabIndex={-1} aria-label="User details" style={{ outline: 'none' }}>
        {loading ? (
          <div style={{ padding: '20px' }}>
            {Array.from({ length: 6 }, (_, i) => <Skeleton key={i} h={12} w={`${90 - i * 8}%`} mb={14} />)}
          </div>
        ) : error ? (
          <div style={{ padding: '20px' }}><Notice tone="danger">{error}</Notice></div>
        ) : user && (
          <>
            {user.role === 'RESPONDER' && rp?.verificationStatus === 'PENDING' && (
              <div style={{ padding: '16px 20px 0' }}>
                <Notice tone="warning">Credentials are awaiting review in the Verification Queue.</Notice>
              </div>
            )}

            <Section title="Contact & account">
              <dl style={DETAIL_GRID}>
                <DetailItem label="Email">{user.email}</DetailItem>
                <DetailItem label="Phone"><span className="mf-num">{user.phoneNumber || '—'}</span></DetailItem>
                <DetailItem label="City">{user.city || '—'}</DetailItem>
                <DetailItem label="Date of birth"><span className="mf-num">{fmtDate(user.dateOfBirth)}</span></DetailItem>
                <DetailItem label="Joined"><span className="mf-num">{fmtDate(user.createdAt)}</span></DetailItem>
                <DetailItem label="Last login"><span className="mf-num">{fmtDate(user.lastLoginAt || user.lastLogin, true)}</span></DetailItem>
                {user.address && <DetailItem label="Address">{user.address}</DetailItem>}
                <DetailItem label="Audit log entries"><span className="mf-num">{user.auditCount ?? 0}</span></DetailItem>
              </dl>
            </Section>

            {user.role !== 'ADMIN' && (
              <Section title="Subscription">
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
                  <label htmlFor="mf-plan-select" className="sr-only">Plan</label>
                  <Select
                    id="mf-plan-select"
                    value={plan}
                    disabled={savingPlan}
                    onChange={e => setPlan(e.target.value)}
                    style={{ width: 'auto', minWidth: '220px' }}
                  >
                    {PLAN_OPTIONS.map(p => (
                      <option key={p.value} value={p.value}>{p.label}{p.price ? ` — PKR ${p.price.toLocaleString()}/mo` : ''}</option>
                    ))}
                  </Select>
                  <Button variant="primary" onClick={applyPlan} disabled={savingPlan || plan === currentPlan}>
                    {savingPlan ? 'Saving…' : 'Apply'}
                  </Button>
                </div>
                <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '8px 0 0' }}>
                  Prices are fixed server-side. Changing the plan here does not charge or refund the user.
                </p>
              </Section>
            )}

            {user.role === 'PATIENT' && (
              <>
                <Section title="Medical profile">
                  {mp ? (
                    <dl style={DETAIL_GRID}>
                      <DetailItem label="Patient type">{mp.patientType === 'DEAF' ? 'Deaf / mute' : (mp.patientType || '—')}</DetailItem>
                      <DetailItem label="Blood type">{mp.bloodType || '—'}</DetailItem>
                      <DetailItem label="Chronic diseases">{asList(mp.chronicDiseases).join(', ') || '—'}</DetailItem>
                      <DetailItem label="Allergies">{asList(mp.allergies).join(', ') || '—'}</DetailItem>
                      <DetailItem label="Medications">{asList(mp.medications).join(', ') || '—'}</DetailItem>
                      <DetailItem label="Emergency contacts"><span className="mf-num">{asList(mp.emergencyContacts).length || '0'}</span></DetailItem>
                    </dl>
                  ) : <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>No medical profile on file.</p>}
                </Section>

                <Section title="Emergencies">
                  {user.emergencyStats && (
                    <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', margin: '0 0 12px', border: '1px solid var(--border)', borderRadius: '8px' }}>
                      {[
                        ['Total', user.emergencyStats.total],
                        ['Resolved', (user.emergencyStats.resolved || 0) + (user.emergencyStats.completed || 0)],
                        ['Cancelled', user.emergencyStats.cancelled],
                        ['Active', user.emergencyStats.active],
                      ].map(([label, val], i) => (
                        <div key={label} style={{ padding: '8px 12px', borderLeft: i > 0 ? '1px solid var(--border)' : 'none', minWidth: 0 }}>
                          <dt style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{label}</dt>
                          <dd className="mf-num" style={{ margin: 0, fontSize: '15px', fontWeight: 600, color: label === 'Active' && val > 0 ? 'var(--error-fg)' : 'var(--text-main)' }}>{val ?? 0}</dd>
                        </div>
                      ))}
                    </dl>
                  )}
                  <HistoryList
                    empty="No emergencies recorded."
                    items={(user.emergencyHistory || []).map(e => ({
                      id: e.id,
                      title: `${e.emergencyType || 'Medical'} emergency`,
                      meta: e.emergencyRequests?.[0]?.responder?.user?.fullName
                        ? `Responder: ${e.emergencyRequests[0].responder.user.fullName}`
                        : 'No responder accepted',
                      date: e.createdAt,
                      status: e.status,
                    }))}
                  />
                </Section>
              </>
            )}

            {user.role === 'RESPONDER' && (
              <>
                <Section title="Responder profile">
                  {rp ? (
                    <dl style={DETAIL_GRID}>
                      <DetailItem label="Type">{(rp.responderType || '').replace(/_/g, ' ') || '—'}</DetailItem>
                      <DetailItem label="Organization">{rp.organization || 'Independent'}</DetailItem>
                      <DetailItem label="License #">{rp.licenseNumber || '—'}</DetailItem>
                      <DetailItem label="Verification"><StatusBadge tone={toneFor(verification)}>{humanize(verification)}</StatusBadge></DetailItem>
                      <DetailItem label="Rating">
                        <span className="mf-num" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                          <Star size={12} aria-hidden="true" style={{ color: 'var(--text-muted)' }} /> {Number(rp.rating ?? 0).toFixed(1)} ({rp.totalRatings ?? 0})
                        </span>
                      </DetailItem>
                      <DetailItem label="Responses handled"><span className="mf-num">{rp.totalResponsesHandled ?? 0}</span></DetailItem>
                      <DetailItem label="Availability">{rp.isAvailable ? 'Available' : 'Unavailable'}</DetailItem>
                      {rp.rejectionReason && <DetailItem label="Rejection reason">{rp.rejectionReason}</DetailItem>}
                    </dl>
                  ) : <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>No responder profile on file.</p>}
                </Section>

                <Section title="Recent dispatch requests">
                  <HistoryList
                    empty="No dispatch requests yet."
                    items={(user.responderHistory || []).map(r => ({
                      id: r.id,
                      title: `${r.emergency?.emergencyType || 'Medical'} — ${r.emergency?.patient?.fullName || 'Unknown patient'}`,
                      meta: r.distanceKm != null ? `${Number(r.distanceKm).toFixed(1)} km away` : null,
                      date: r.sentAt,
                      status: r.status,
                    }))}
                  />
                </Section>
              </>
            )}
          </>
        )}
      </div>
    </Drawer>
  );
}

function HistoryList({ items, empty }) {
  if (!items.length) return <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>{empty}</p>;
  return (
    <ul style={{ listStyle: 'none', margin: 0, border: '1px solid var(--border)', borderRadius: '8px', overflow: 'hidden' }}>
      {items.map((item, i) => (
        <li key={item.id} style={{ display: 'flex', alignItems: 'center', gap: '10px', minHeight: '46px', padding: '6px 12px', borderTop: i > 0 ? '1px solid var(--border)' : 'none' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ margin: 0, fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.title}</p>
            <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-muted)' }}>
              <span className="mf-num">{fmtDate(item.date, true)}</span>{item.meta ? ` · ${item.meta}` : ''}
            </p>
          </div>
          <StatusBadge tone={toneFor(item.status)}>{humanize(item.status)}</StatusBadge>
        </li>
      ))}
    </ul>
  );
}

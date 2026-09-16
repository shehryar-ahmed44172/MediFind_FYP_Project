import React, { useEffect, useState, useRef } from 'react';
import { motion } from 'framer-motion';
import {
  X, Mail, Phone, MapPin, Calendar, Clock, Shield, Activity, Star,
  CheckCircle, XCircle, AlertTriangle, CreditCard, FileText, User,
} from 'lucide-react';
import api from '../services/api';
import { updateSubscriptionPlan, PLAN_OPTIONS, errorMessage } from '../services/adminApi';
import { resolveFileUrl } from '../utils/resolveFileUrl';
import { useAlert } from '../context/hooks';
import { Skeleton } from './ui';

const fmtDate = (iso, withTime = false) => {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return withTime
    ? d.toLocaleString('en-PK', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
    : d.toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' });
};

const asList = (v) => (Array.isArray(v) ? v.filter(Boolean).map(x => (typeof x === 'object' ? (x.name || x.label || JSON.stringify(x)) : String(x))) : []);

const STATUS_COLORS = {
  ACTIVE: 'var(--sos)', ASSIGNED: 'var(--primary-light)', ARRIVED: 'var(--primary-light)', RESOLVED: 'var(--success)', COMPLETED: 'var(--success)',
  CANCELLED: 'var(--text-muted)', PENDING: 'var(--warning)', ACCEPTED: 'var(--success)', REJECTED: 'var(--sos)', EXPIRED: 'var(--text-muted)',
};

function Section({ title, icon, children, right }) {
  const Glyph = icon;
  return (
    <section style={{ padding: '18px 22px', borderBottom: '1px solid var(--admin-border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
        <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.78rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.07em', color: 'var(--admin-text-muted)' }}>
          {Glyph && <Glyph size={14} />} {title}
        </h3>
        {right}
      </div>
      {children}
    </section>
  );
}

function Field({ label, value }) {
  return (
    <div style={{ minWidth: 0 }}>
      <p style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--admin-text-muted)', marginBottom: '2px' }}>{label}</p>
      <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--admin-text-main)', wordBreak: 'break-word' }}>{value ?? '—'}</p>
    </div>
  );
}

function StatusChip({ status }) {
  const color = STATUS_COLORS[status] || 'var(--text-muted)';
  return (
    <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '6px', color, background: `color-mix(in srgb, ${color} 12%, transparent)`, whiteSpace: 'nowrap' }}>
      {status || '—'}
    </span>
  );
}

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
  const closeRef = useRef(null);

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

  useEffect(() => {
    closeRef.current?.focus();
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

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

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose}
        style={{ position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.45)', zIndex: 900 }}
      />
      <motion.aside
        role="dialog"
        aria-modal="true"
        aria-label="User details"
        initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }}
        transition={{ type: 'spring', stiffness: 320, damping: 34 }}
        style={{
          position: 'fixed', top: 0, right: 0, bottom: 0, width: 'min(520px, 100vw)', zIndex: 901,
          background: 'var(--surface)', borderLeft: '1px solid var(--admin-border)', boxShadow: 'var(--shadow-lg)',
          display: 'flex', flexDirection: 'column',
        }}
      >
        {/* Header */}
        <div style={{ padding: '18px 22px', borderBottom: '1px solid var(--admin-border)', display: 'flex', alignItems: 'center', gap: '14px' }}>
          {loading ? (
            <div style={{ flex: 1 }}><Skeleton h={18} w="50%" mb={8} /><Skeleton h={12} w="70%" /></div>
          ) : user ? (
            <>
              <div style={{ width: '52px', height: '52px', borderRadius: '14px', overflow: 'hidden', flexShrink: 0, background: 'linear-gradient(135deg,var(--primary),var(--primary-mid))', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '1.2rem' }}>
                {user.profileImageUrl
                  ? <img src={resolveFileUrl(user.profileImageUrl)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  : (user.fullName?.[0] || '?').toUpperCase()}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--admin-text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user.fullName}</h2>
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginTop: '4px' }}>
                  <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '6px', background: 'var(--tint-teal)', color: 'var(--admin-accent)' }}>{user.role}</span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '6px', background: user.isActive ? 'var(--tint-green)' : 'var(--tint-red)', color: user.isActive ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                    {user.isActive ? <CheckCircle size={10} /> : <XCircle size={10} />} {user.isActive ? 'Active' : 'Inactive'}
                  </span>
                  {user.isEmailVerified === false && (
                    <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '6px', background: 'var(--tint-amber)', color: 'var(--warning-fg)' }}>Email unverified</span>
                  )}
                </div>
              </div>
            </>
          ) : <div style={{ flex: 1, fontWeight: 700, color: 'var(--admin-text-main)' }}>User details</div>}
          <button
            ref={closeRef}
            type="button"
            onClick={onClose}
            aria-label="Close user details"
            style={{ width: '36px', height: '36px', borderRadius: '10px', border: '1px solid var(--admin-border)', background: 'var(--surface)', color: 'var(--admin-text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
          >
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {loading ? (
            <div style={{ padding: '22px' }}>
              {Array.from({ length: 6 }, (_, i) => <Skeleton key={i} h={14} w={`${90 - i * 8}%`} mb={14} />)}
            </div>
          ) : error ? (
            <div role="alert" style={{ margin: '22px', padding: '14px 16px', borderRadius: '12px', background: 'var(--error-bg)', border: '1px solid var(--error-border)', color: 'var(--error-fg)', fontWeight: 600, fontSize: '0.88rem' }}>
              {error}
            </div>
          ) : user && (
            <>
              <Section title="Contact & Account" icon={User}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '12px 18px' }}>
                  <Field label="Email" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><Mail size={12} /> {user.email}</span>} />
                  <Field label="Phone" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><Phone size={12} /> {user.phoneNumber || '—'}</span>} />
                  <Field label="City" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><MapPin size={12} /> {user.city || '—'}</span>} />
                  <Field label="Date of birth" value={fmtDate(user.dateOfBirth)} />
                  <Field label="Joined" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><Calendar size={12} /> {fmtDate(user.createdAt)}</span>} />
                  <Field label="Last login" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><Clock size={12} /> {fmtDate(user.lastLoginAt || user.lastLogin, true)}</span>} />
                  {user.address && <Field label="Address" value={user.address} />}
                  <Field label="Audit log entries" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}><FileText size={12} /> {user.auditCount ?? 0}</span>} />
                </div>
              </Section>

              {user.role !== 'ADMIN' && (
                <Section title="Subscription" icon={CreditCard}>
                  <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                    <label htmlFor="mf-plan-select" style={{ fontSize: '0.82rem', color: 'var(--admin-text-sub)', fontWeight: 600 }}>Plan</label>
                    <select
                      id="mf-plan-select"
                      value={plan}
                      disabled={savingPlan}
                      onChange={e => setPlan(e.target.value)}
                      style={{ height: '38px', padding: '0 12px', borderRadius: '10px', border: '1.5px solid var(--admin-border)', background: 'var(--input-bg)', color: 'var(--text-main)', fontWeight: 600, fontFamily: 'inherit', minWidth: '200px' }}
                    >
                      {PLAN_OPTIONS.map(p => (
                        <option key={p.value} value={p.value}>{p.label}{p.price ? ` — PKR ${p.price.toLocaleString()}/mo` : ''}</option>
                      ))}
                    </select>
                    <button
                      type="button"
                      onClick={applyPlan}
                      disabled={savingPlan || plan === currentPlan}
                      style={{
                        height: '38px', padding: '0 16px', borderRadius: '10px', border: 'none', fontWeight: 700, fontFamily: 'inherit',
                        background: plan === currentPlan ? 'var(--tint-slate)' : 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                        color: plan === currentPlan ? 'var(--admin-text-muted)' : 'white',
                        cursor: savingPlan || plan === currentPlan ? 'not-allowed' : 'pointer',
                      }}
                    >
                      {savingPlan ? 'Saving…' : 'Apply'}
                    </button>
                  </div>
                  <p style={{ fontSize: '0.74rem', color: 'var(--admin-text-muted)', marginTop: '8px' }}>
                    Prices are fixed server-side. Changing the plan here does not charge or refund the user.
                  </p>
                </Section>
              )}

              {user.role === 'PATIENT' && (
                <>
                  <Section title="Medical profile" icon={Shield}>
                    {mp ? (
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '12px 18px' }}>
                        <Field label="Patient type" value={mp.patientType === 'DEAF' ? 'Deaf / mute' : (mp.patientType || '—')} />
                        <Field label="Blood type" value={mp.bloodType || '—'} />
                        <Field label="Chronic diseases" value={asList(mp.chronicDiseases).join(', ') || '—'} />
                        <Field label="Allergies" value={asList(mp.allergies).join(', ') || '—'} />
                        <Field label="Medications" value={asList(mp.medications).join(', ') || '—'} />
                        <Field label="Emergency contacts" value={asList(mp.emergencyContacts).length || '0'} />
                      </div>
                    ) : <p style={{ fontSize: '0.85rem', color: 'var(--admin-text-muted)' }}>No medical profile on file.</p>}
                  </Section>

                  <Section title="Emergencies" icon={Activity}>
                    {user.emergencyStats && (
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: '8px', marginBottom: '14px' }}>
                        {[
                          ['Total', user.emergencyStats.total, 'var(--admin-accent)'],
                          ['Resolved', (user.emergencyStats.resolved || 0) + (user.emergencyStats.completed || 0), 'var(--success)'],
                          ['Cancelled', user.emergencyStats.cancelled, 'var(--text-muted)'],
                          ['Active', user.emergencyStats.active, 'var(--sos)'],
                        ].map(([label, val, color]) => (
                          <div key={label} style={{ padding: '10px', borderRadius: '10px', background: 'var(--table-head-bg)', border: '1px solid var(--admin-border)', textAlign: 'center' }}>
                            <p style={{ fontSize: '1.2rem', fontWeight: 800, color }}>{val ?? 0}</p>
                            <p style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--admin-text-muted)' }}>{label}</p>
                          </div>
                        ))}
                      </div>
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
                  <Section title="Responder profile" icon={Shield}>
                    {rp ? (
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '12px 18px' }}>
                        <Field label="Type" value={(rp.responderType || '').replace(/_/g, ' ') || '—'} />
                        <Field label="Organization" value={rp.organization || 'Independent'} />
                        <Field label="License #" value={rp.licenseNumber || '—'} />
                        <Field label="Verification" value={rp.verificationStatus || (rp.isVerified ? 'VERIFIED' : 'PENDING')} />
                        <Field label="Rating" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}><Star size={12} color="var(--warning)" /> {Number(rp.rating ?? 0).toFixed(1)} ({rp.totalRatings ?? 0})</span>} />
                        <Field label="Responses handled" value={rp.totalResponsesHandled ?? 0} />
                        <Field label="Availability" value={rp.isAvailable ? 'Available' : 'Unavailable'} />
                        {rp.rejectionReason && <Field label="Rejection reason" value={rp.rejectionReason} />}
                      </div>
                    ) : <p style={{ fontSize: '0.85rem', color: 'var(--admin-text-muted)' }}>No responder profile on file.</p>}
                  </Section>

                  <Section title="Recent dispatch requests" icon={Activity}>
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

              {user.role === 'RESPONDER' && rp?.verificationStatus === 'PENDING' && (
                <div style={{ margin: '16px 22px', padding: '12px 14px', borderRadius: '12px', background: 'var(--warning-bg)', border: '1px solid var(--warning-border)', color: 'var(--warning-fg)', fontSize: '0.84rem', fontWeight: 600, display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <AlertTriangle size={15} /> Credentials are awaiting review in the Verification Queue.
                </div>
              )}
            </>
          )}
        </div>
      </motion.aside>
    </>
  );
}

function HistoryList({ items, empty }) {
  if (!items.length) return <p style={{ fontSize: '0.85rem', color: 'var(--admin-text-muted)' }}>{empty}</p>;
  return (
    <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '6px' }}>
      {items.map(item => (
        <li key={item.id} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '9px 12px', borderRadius: '10px', border: '1px solid var(--admin-border)', background: 'var(--table-head-bg)' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ fontSize: '0.84rem', fontWeight: 700, color: 'var(--admin-text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.title}</p>
            <p style={{ fontSize: '0.72rem', color: 'var(--admin-text-muted)' }}>
              {fmtDate(item.date, true)}{item.meta ? ` · ${item.meta}` : ''}
            </p>
          </div>
          <StatusChip status={item.status} />
        </li>
      ))}
    </ul>
  );
}

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Search, Users, ShieldOff, ShieldCheck, Trash2,
  User, AlertTriangle, CheckCircle,
  XCircle, Clock, Crown, Zap, Star, EarOff,
  Calendar, Filter, ExternalLink, AlertCircle, Eye,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { errorMessage } from '../services/adminApi';
import { resolveFileUrl } from '../utils/resolveFileUrl';
import { useAlert } from '../context/hooks';
import { PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, FilterPill } from '../components/ui';
import { thStyle, paginate } from '../components/uiStyles';
import UserDetailDrawer from '../components/UserDetailDrawer';

/* ─── Theme (CSS tokens — adapt to light/dark automatically) ──────────────── */
const C = {
  accent:   'var(--admin-accent)',
  border:   'var(--admin-border)',
  bg:       'var(--admin-bg)',
  white:    'var(--surface)',
  textMain: 'var(--admin-text-main)',
  textSub:  'var(--admin-text-sub)',
  textMuted:'var(--admin-text-muted)',
};

/* ─── Tab config ─────────────────────────────────────────────────────────── */
const TABS = [
  { key: 'ALL',       label: 'All Users',  Icon: Users,       accent: 'var(--primary-light)', pale: 'var(--tint-teal)'  },
  { key: 'PATIENT',   label: 'Patients',   Icon: User,        accent: 'var(--primary-light)', pale: 'var(--tint-teal)'  },
  { key: 'RESPONDER', label: 'Responders', Icon: ShieldCheck, accent: 'var(--success)',       pale: 'var(--tint-green)' },
  { key: 'CAREGIVER', label: 'Caregivers', Icon: Users,       accent: 'var(--primary-mid)',   pale: 'var(--tint-blue)'  },
];
const VALID_TABS = TABS.map(t => t.key);

/* ─── Role badge config (used in ALL tab) ────────────────────────────────── */
const ROLE_BADGE = {
  PATIENT:   { label: 'Patient',   color: 'var(--primary-light)', bg: 'var(--tint-teal)'  },
  RESPONDER: { label: 'Responder', color: 'var(--success)',       bg: 'var(--tint-green)' },
  CAREGIVER: { label: 'Caregiver', color: 'var(--primary-mid)',   bg: 'var(--tint-blue)'  },
};

/* ─── Status helpers ─────────────────────────────────────────────────────── */
const PLAN_META = {
  FREE:         { label: 'Free',      color: 'var(--text-muted)',    bg: 'var(--tint-slate)', Icon: Zap   },
  PROFESSIONAL: { label: 'Pro',       color: 'var(--primary-light)', bg: 'var(--tint-teal)',  Icon: Star  },
  EXECUTIVE:    { label: 'Executive', color: 'var(--primary)',       bg: 'var(--tint-blue)',  Icon: Crown },
};

const VERIF_META = {
  PENDING:  { label: 'Pending Review', color: 'var(--warning-fg)', bg: 'var(--tint-amber)', Icon: Clock       },
  VERIFIED: { label: 'Verified',       color: 'var(--success-fg)', bg: 'var(--tint-green)', Icon: CheckCircle },
  REJECTED: { label: 'Rejected',       color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
};

/**
 * Derive the single "effective status" for a user row.
 * For RESPONDERS: verification state takes precedence over isActive.
 * For PATIENTS / CAREGIVERS: it's just isActive.
 */
function getEffectiveStatus(user, role) {
  if (role === 'RESPONDER' && user.responder) {
    const vs = user.responder.verificationStatus;
    if (vs === 'REJECTED') return 'REJECTED';
    if (vs === 'PENDING')  return 'PENDING';
    if (vs === 'VERIFIED') return user.isActive !== false ? 'ACTIVE' : 'INACTIVE';
  }
  return user.isActive !== false ? 'ACTIVE' : 'INACTIVE';
}

const EFF_STATUS_STYLE = {
  ACTIVE:   { label: 'Active',         color: 'var(--success-fg)', bg: 'var(--tint-green)', Icon: CheckCircle },
  INACTIVE: { label: 'Inactive',       color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
  PENDING:  { label: 'Pending Review', color: 'var(--warning-fg)', bg: 'var(--tint-amber)', Icon: Clock       },
  REJECTED: { label: 'Rejected',       color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
};

const FILTER_COLORS = { ACTIVE: 'var(--success-fg)', INACTIVE: 'var(--error-fg)', PENDING: 'var(--warning-fg)', REJECTED: 'var(--error-fg)' };

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

const PAGE_SIZE = 10;

const tabFromParams = (params) => {
  const role = params.get('role');
  if (VALID_TABS.includes(role)) return role;
  return params.get('search') ? 'ALL' : 'PATIENT';
};

/* ─── Main Component ─────────────────────────────────────────────────────── */
export default function UserManagement() {
  const { showAlert, showConfirm } = useAlert();
  const [searchParams] = useSearchParams();
  const paramsKey = searchParams.toString();

  const [activeTab,    setActiveTab]    = useState(() => tabFromParams(searchParams));
  const [users,        setUsers]        = useState([]);
  const [loading,      setLoading]      = useState(true);
  const [error,        setError]        = useState('');
  const [search,       setSearch]       = useState(() => searchParams.get('search') || '');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [page,         setPage]         = useState(1);
  const [detailUserId, setDetailUserId] = useState(null);
  const [syncedParams, setSyncedParams] = useState(paramsKey);
  const requestId = useRef(0);

  // The route is keyed by pathname, so a global search from the header
  // (/admin/users?search=…) does not remount this page. Adopt new URL params
  // during render (React's "adjust state when a prop changes" pattern).
  if (syncedParams !== paramsKey) {
    setSyncedParams(paramsKey);
    const nextTab = tabFromParams(searchParams);
    if (searchParams.get('search') !== null) setSearch(searchParams.get('search'));
    if (nextTab !== activeTab) { setActiveTab(nextTab); setLoading(true); setUsers([]); }
    setStatusFilter('ALL');
    setPage(1);
  }

  const loadUsers = useCallback((tab) => {
    const id = ++requestId.current;
    const url = tab === 'ALL' ? '/api/admin/users' : `/api/admin/users?role=${tab}`;
    return api.get(url)
      .then(res => {
        if (id !== requestId.current) return; // a newer request superseded this one
        // Administrator accounts are managed outside this screen
        setUsers(res.data?.success ? res.data.data.filter(u => u.role !== 'ADMIN') : []);
        setError('');
      })
      .catch(err => {
        if (id !== requestId.current) return;
        setError(errorMessage(err, 'Failed to load users.'));
        setUsers([]);
      })
      .finally(() => { if (id === requestId.current) setLoading(false); });
  }, []);

  useEffect(() => { loadUsers(activeTab); }, [activeTab, loadUsers]);

  const changeTab = (key) => {
    if (key === activeTab) return;
    setActiveTab(key);
    setLoading(true);
    setUsers([]);
    setStatusFilter('ALL');
    setPage(1);
  };

  const refresh = () => { setLoading(true); loadUsers(activeTab); };

  /* ── Actions ── */
  const patchUser = (userId, patch) => setUsers(prev => prev.map(u => (u.id === userId ? { ...u, ...patch } : u)));

  const handleDeactivate = (userId, name) => {
    showConfirm({
      title: 'Deactivate account?',
      message: `"${name}" will lose login access immediately. You can reactivate the account at any time.`,
      type: 'warning',
      confirmLabel: 'Deactivate',
      onConfirm: async () => {
        try {
          await api.patch(`/api/admin/users/${userId}/deactivate`);
          patchUser(userId, { isActive: false });
          showAlert(`${name} has been deactivated.`, 'success');
        } catch (err) {
          showAlert(errorMessage(err, 'Failed to deactivate user.'), 'error');
        }
      },
    });
  };

  const handleReactivate = (userId, name) => {
    showConfirm({
      title: 'Reactivate account?',
      message: `"${name}" will be able to sign in again.`,
      type: 'info',
      confirmLabel: 'Reactivate',
      onConfirm: async () => {
        try {
          await api.patch(`/api/admin/users/${userId}/activate`);
          patchUser(userId, { isActive: true });
          showAlert(`${name} has been reactivated.`, 'success');
        } catch (err) {
          showAlert(errorMessage(err, 'Failed to reactivate user.'), 'error');
        }
      },
    });
  };

  const handleDelete = (userId, name) => {
    showConfirm({
      title: 'Delete account?',
      message: `"${name}" will be signed out everywhere, deactivated and their email released. Payment and audit history is preserved. This cannot be undone from the portal.`,
      type: 'danger',
      confirmLabel: 'Delete account',
      onConfirm: async () => {
        try {
          await api.delete(`/api/admin/users/${userId}`);
          setUsers(prev => prev.filter(u => u.id !== userId));
          showAlert(`${name}'s account has been deleted.`, 'success');
        } catch (err) {
          showAlert(errorMessage(err, 'Failed to delete user.'), 'error');
        }
      },
    });
  };

  /* ── Filtering ── */
  const q = search.trim().toLowerCase();
  const filtered = users.filter(u => {
    const matchSearch = !q || (
      u.fullName?.toLowerCase().includes(q) ||
      u.email?.toLowerCase().includes(q) ||
      u.phoneNumber?.toLowerCase().includes(q)
    );
    const effStatus = getEffectiveStatus(u, activeTab === 'ALL' ? u.role : activeTab);
    const matchFilter = statusFilter === 'ALL' || effStatus === statusFilter;
    return matchSearch && matchFilter;
  });
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);

  const summaryChips = getSummaryChips(users, activeTab);
  const tab = TABS.find(t => t.key === activeTab);

  const filterOptions =
    activeTab === 'RESPONDER' || activeTab === 'ALL'
      ? ['ALL', 'ACTIVE', 'INACTIVE', 'PENDING', 'REJECTED']
      : ['ALL', 'ACTIVE', 'INACTIVE'];

  const COLS = 6;

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.3 }}
    >
      <PageHeader
        title="User Management"
        subtitle="Manage platform participants, account access and subscription plans. Click a user to see their full profile."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      {/* Summary chips */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '20px' }}>
        {summaryChips.map((s) => (
          <div key={s.label} style={{
            background: C.white, borderRadius: '12px', border: `1px solid ${C.border}`,
            padding: '14px 18px', display: 'flex', alignItems: 'center', gap: '12px',
            boxShadow: '0 1px 3px rgba(12,99,126,0.04)',
          }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: s.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <s.Icon size={18} color={s.color} />
            </div>
            <div>
              <p style={{ fontSize: '1.4rem', fontWeight: 800, color: s.color, lineHeight: 1 }}>{loading ? '—' : s.value}</p>
              <p style={{ fontSize: '0.78rem', fontWeight: 600, color: C.textMuted, marginTop: '3px' }}>{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Main card */}
      <div style={{
        background: C.white, borderRadius: '16px',
        border: `1px solid ${C.border}`,
        boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
        overflow: 'hidden',
      }}>
        {/* Tabs */}
        <div role="tablist" aria-label="User roles" style={{ display: 'flex', borderBottom: `1px solid ${C.border}`, background: 'var(--table-head-bg)', padding: '0 20px', overflowX: 'auto' }}>
          {TABS.map(t => {
            const on = t.key === activeTab;
            return (
              <button
                key={t.key}
                type="button"
                role="tab"
                aria-selected={on}
                onClick={() => changeTab(t.key)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '7px',
                  padding: '14px 4px', marginRight: '24px',
                  background: 'none', border: 'none', cursor: 'pointer',
                  fontFamily: 'inherit', fontWeight: on ? 700 : 600,
                  fontSize: '0.875rem', whiteSpace: 'nowrap',
                  color: on ? t.accent : C.textMuted,
                  borderBottom: on ? `2.5px solid ${t.accent}` : '2.5px solid transparent',
                  transition: 'all 0.15s',
                }}
              >
                <t.Icon size={15} strokeWidth={on ? 2.5 : 2} />
                {t.label}
                {on && !loading && (
                  <span style={{ fontSize: '0.7rem', fontWeight: 800, padding: '2px 7px', borderRadius: '20px', background: t.pale, color: t.accent }}>
                    {users.length}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* Filter row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap', padding: '14px 20px', borderBottom: `1px solid ${C.border}` }}>
          <div style={{ position: 'relative', width: '300px', maxWidth: '100%' }}>
            <Search style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.textMuted, pointerEvents: 'none' }} size={15} />
            <input
              type="search"
              placeholder={`Search ${tab?.label.toLowerCase()} by name, email or phone…`}
              aria-label="Search users"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
              style={{
                width: '100%', height: '38px', paddingLeft: '36px', paddingRight: '12px',
                border: `1.5px solid ${C.border}`, borderRadius: '10px',
                background: 'var(--input-bg)', outline: 'none', fontSize: '0.875rem',
                fontFamily: 'inherit', color: C.textMain, boxSizing: 'border-box',
              }}
            />
          </div>
          <div role="group" aria-label="Filter by status" style={{ display: 'flex', gap: '6px', alignItems: 'center', flexWrap: 'wrap' }}>
            <Filter size={14} color="var(--text-muted)" aria-hidden="true" />
            {filterOptions.map(f => (
              <FilterPill key={f} active={statusFilter === f} color={FILTER_COLORS[f]} onClick={() => { setStatusFilter(f); setPage(1); }}>
                {f === 'ALL' ? 'All' : EFF_STATUS_STYLE[f].label}
              </FilterPill>
            ))}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div role="alert" style={{ padding: '12px 20px', background: 'var(--error-bg)', borderBottom: '1px solid var(--error-border)', color: 'var(--error-fg)', fontSize: '0.875rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={16} /> {error}
            <button type="button" onClick={refresh} style={{ marginLeft: 'auto', background: 'none', border: '1px solid var(--error-border)', color: 'inherit', borderRadius: '8px', padding: '3px 10px', fontWeight: 700, fontFamily: 'inherit' }}>Retry</button>
          </div>
        )}

        {/* Responder notice banner */}
        {(activeTab === 'RESPONDER' || activeTab === 'ALL') && !loading && (
          <div style={{ padding: '10px 20px', background: 'var(--warning-bg)', borderBottom: '1px solid var(--warning-border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.8rem', color: 'var(--warning-fg)', fontWeight: 600 }}>
              <AlertCircle size={14} />
              Credential status (Verified / Pending / Rejected) is separate from login access. Approve or reject credentials in the Verification Queue.
            </div>
            <Link to="/admin/verify" style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.78rem', fontWeight: 700, color: 'var(--warning-fg)', textDecoration: 'none', whiteSpace: 'nowrap' }}>
              Verification Queue <ExternalLink size={12} />
            </Link>
          </div>
        )}

        {/* Table */}
        <div className="mf-table-scroll">
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '860px' }}>
            <thead>
              <tr>
                {['User', 'Phone', (activeTab === 'RESPONDER' || activeTab === 'ALL') ? 'Credentials / Plan' : 'Plan', 'Status', 'Joined', 'Actions'].map((h, i) => (
                  <th key={h} scope="col" style={{ ...thStyle, textAlign: i === 5 ? 'right' : 'left' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <TableSkeletonRows rows={5} cols={COLS} />
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={COLS}>
                    <EmptyState
                      icon={User}
                      title={`No ${tab?.label.toLowerCase()} found`}
                      message={search || statusFilter !== 'ALL' ? 'Try a different search term or filter.' : 'No accounts in this category yet.'}
                      action={(search || statusFilter !== 'ALL') && (
                        <button type="button" onClick={() => { setSearch(''); setStatusFilter('ALL'); setPage(1); }}
                          style={{ padding: '7px 14px', borderRadius: '8px', border: `1.5px solid ${C.border}`, background: C.white, color: C.textSub, fontWeight: 700, fontFamily: 'inherit' }}>
                          Clear filters
                        </button>
                      )}
                    />
                  </td>
                </tr>
              ) : (
                rows.map((user) => {
                  const role = activeTab === 'ALL' ? user.role : activeTab;
                  const effStatus = getEffectiveStatus(user, role);
                  const statusStyle = EFF_STATUS_STYLE[effStatus];
                  const isDeaf  = user.medicalProfile?.patientType === 'DEAF';
                  const plan    = PLAN_META[user.subscriptionPlan] || PLAN_META.FREE;
                  const verifSt = user.responder?.verificationStatus;
                  const verifMeta = verifSt ? VERIF_META[verifSt] : null;
                  return (
                    <tr
                      key={user.id}
                      className="mf-table-row"
                      onClick={() => setDetailUserId(user.id)}
                      style={{ borderBottom: `1px solid ${C.border}`, cursor: 'pointer' }}
                    >
                      {/* User */}
                      <td style={{ padding: '13px 20px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{
                            width: '40px', height: '40px', borderRadius: '11px', flexShrink: 0,
                            background: 'linear-gradient(135deg, var(--primary), var(--primary-mid))',
                            color: 'white', display: 'flex', alignItems: 'center',
                            justifyContent: 'center', fontWeight: 800, fontSize: '1rem',
                            overflow: 'hidden',
                          }}>
                            {user.profileImageUrl
                              ? <img src={resolveFileUrl(user.profileImageUrl)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              : (user.fullName?.[0] || '?').toUpperCase()
                            }
                          </div>
                          <div style={{ minWidth: 0 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                              <span style={{ fontWeight: 700, fontSize: '0.88rem', color: C.textMain }}>
                                {user.fullName || '—'}
                              </span>
                              {activeTab === 'ALL' && ROLE_BADGE[user.role] && (
                                <span style={{ fontSize: '0.66rem', fontWeight: 800, padding: '2px 6px', borderRadius: '4px', background: ROLE_BADGE[user.role].bg, color: ROLE_BADGE[user.role].color }}>
                                  {ROLE_BADGE[user.role].label}
                                </span>
                              )}
                              {isDeaf && (
                                <span style={{ fontSize: '0.66rem', fontWeight: 800, padding: '2px 6px', borderRadius: '4px', background: 'var(--tint-amber)', color: 'var(--warning-fg)', display: 'flex', alignItems: 'center', gap: '3px' }}>
                                  <EarOff size={9} /> DEAF
                                </span>
                              )}
                            </div>
                            <div style={{ fontSize: '0.78rem', color: C.textMuted, marginTop: '1px' }}>{user.email}</div>
                          </div>
                        </div>
                      </td>

                      {/* Phone */}
                      <td style={{ padding: '13px 20px', fontSize: '0.85rem', color: C.textSub, whiteSpace: 'nowrap' }}>
                        {user.phoneNumber || '—'}
                      </td>

                      {/* Credentials / Plan */}
                      <td style={{ padding: '13px 20px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 9px', borderRadius: '6px', background: plan.bg, color: plan.color, fontSize: '0.74rem', fontWeight: 700, width: 'fit-content' }}>
                            <plan.Icon size={11} /> {plan.label}
                          </div>
                          {verifMeta && (
                            <div style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 9px', borderRadius: '6px', background: verifMeta.bg, color: verifMeta.color, fontSize: '0.74rem', fontWeight: 700, width: 'fit-content' }}>
                              <verifMeta.Icon size={11} /> {verifMeta.label}
                            </div>
                          )}
                        </div>
                      </td>

                      {/* Effective Status */}
                      <td style={{ padding: '13px 20px' }}>
                        <span style={{
                          display: 'inline-flex', alignItems: 'center', gap: '5px',
                          padding: '4px 10px', borderRadius: '6px', whiteSpace: 'nowrap',
                          fontSize: '0.76rem', fontWeight: 700,
                          background: statusStyle.bg, color: statusStyle.color,
                        }}>
                          <statusStyle.Icon size={11} /> {statusStyle.label}
                        </span>
                      </td>

                      {/* Joined */}
                      <td style={{ padding: '13px 20px', fontSize: '0.82rem', color: C.textMuted, whiteSpace: 'nowrap' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Calendar size={12} /> {formatDate(user.createdAt)}
                        </div>
                      </td>

                      {/* Actions — context-aware */}
                      <td style={{ padding: '13px 20px' }}>
                        <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '6px' }}>
                          <ActionButtons
                            user={user}
                            role={role}
                            effStatus={effStatus}
                            onView={() => setDetailUserId(user.id)}
                            onDeactivate={handleDeactivate}
                            onReactivate={handleReactivate}
                            onDelete={handleDelete}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} />
      </div>

      <AnimatePresence>
        {detailUserId && (
          <UserDetailDrawer
            key={detailUserId}
            userId={detailUserId}
            onClose={() => setDetailUserId(null)}
            onUserUpdated={(patch) => patchUser(patch.id, patch)}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

/* ─── Context-aware action buttons ──────────────────────────────────────── */
const iconBtn = (bg, color) => ({
  width: '32px', height: '32px', borderRadius: '8px', border: 'none',
  background: bg, color, cursor: 'pointer',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
});

function ActionButtons({ user, role, effStatus, onView, onDeactivate, onReactivate, onDelete }) {
  const stop = (fn) => (e) => { e.stopPropagation(); fn(); };
  const name = user.fullName || user.email;
  const isAdmin = user.role === 'ADMIN';

  return (
    <>
      <button type="button" onClick={stop(onView)} title="View profile" aria-label={`View profile of ${name}`} style={iconBtn('var(--tint-teal)', 'var(--primary-light)')}>
        <Eye size={15} />
      </button>

      {role === 'RESPONDER' && (effStatus === 'PENDING' || effStatus === 'REJECTED') ? (
        // Credential flow lives in the Verification Queue, not here
        <Link
          to="/admin/verify"
          onClick={e => e.stopPropagation()}
          title="Open Verification Queue"
          style={{
            height: '32px', padding: '0 11px', borderRadius: '8px', textDecoration: 'none',
            display: 'flex', alignItems: 'center', gap: '5px',
            background: effStatus === 'REJECTED' ? 'var(--tint-red)' : 'var(--tint-amber)',
            color: effStatus === 'REJECTED' ? 'var(--error-fg)' : 'var(--warning-fg)',
            fontSize: '0.76rem', fontWeight: 700,
          }}
        >
          <ExternalLink size={13} />
          {effStatus === 'REJECTED' ? 'Review' : 'Verify'}
        </Link>
      ) : isAdmin ? null : effStatus === 'ACTIVE' ? (
        <button type="button" onClick={stop(() => onDeactivate(user.id, name))} title="Deactivate account" aria-label={`Deactivate ${name}`} style={iconBtn('var(--tint-amber)', 'var(--warning-fg)')}>
          <ShieldOff size={15} />
        </button>
      ) : (
        <button type="button" onClick={stop(() => onReactivate(user.id, name))} title="Reactivate account" aria-label={`Reactivate ${name}`} style={iconBtn('var(--tint-green)', 'var(--success-fg)')}>
          <ShieldCheck size={15} />
        </button>
      )}

      {!isAdmin && <button type="button" onClick={stop(() => onDelete(user.id, name))} title="Delete account" aria-label={`Delete ${name}`} style={iconBtn('var(--tint-red)', 'var(--error-fg)')}>
        <Trash2 size={15} />
      </button>}
    </>
  );
}

/* ─── Summary chips — tab-aware ─────────────────────────────────────────── */
function getSummaryChips(users, role) {
  if (role === 'ALL') {
    return [
      { label: 'Total Users',    value: users.length,                                                            color: 'var(--primary-light)', bg: 'var(--tint-teal)',  Icon: Users       },
      { label: 'Active',         value: users.filter(u => u.isActive !== false).length,                          color: 'var(--success-fg)',    bg: 'var(--tint-green)', Icon: CheckCircle },
      { label: 'Responders',     value: users.filter(u => u.role === 'RESPONDER').length,                        color: 'var(--success)',       bg: 'var(--tint-green)', Icon: ShieldCheck },
      { label: 'Pending Review', value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length, color: 'var(--warning-fg)',    bg: 'var(--tint-amber)', Icon: Clock       },
    ];
  }
  if (role === 'RESPONDER') {
    return [
      { label: 'Verified Responders', value: users.filter(u => u.responder?.verificationStatus === 'VERIFIED').length, color: 'var(--success-fg)', bg: 'var(--tint-green)', Icon: CheckCircle },
      { label: 'Pending Review',      value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length,  color: 'var(--warning-fg)', bg: 'var(--tint-amber)', Icon: Clock       },
      { label: 'Rejected',            value: users.filter(u => u.responder?.verificationStatus === 'REJECTED').length, color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
    ];
  }
  if (role === 'PATIENT') {
    return [
      { label: 'Active Patients', value: users.filter(u => u.isActive !== false).length,                     color: 'var(--success-fg)', bg: 'var(--tint-green)', Icon: CheckCircle },
      { label: 'Inactive',        value: users.filter(u => u.isActive === false).length,                     color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
      { label: 'Deaf / Mute',     value: users.filter(u => u.medicalProfile?.patientType === 'DEAF').length, color: 'var(--warning-fg)', bg: 'var(--tint-amber)', Icon: EarOff      },
    ];
  }
  // Caregivers
  return [
    { label: 'Active Caregivers', value: users.filter(u => u.isActive !== false).length, color: 'var(--success-fg)', bg: 'var(--tint-green)', Icon: CheckCircle },
    { label: 'Inactive',          value: users.filter(u => u.isActive === false).length, color: 'var(--error-fg)',   bg: 'var(--tint-red)',   Icon: XCircle     },
  ];
}

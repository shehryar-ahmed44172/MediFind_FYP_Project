import React, { useState, useEffect, useCallback } from 'react';
import {
  Search, RefreshCw, Users, ShieldOff, ShieldCheck, Trash2,
  User, AlertTriangle, CheckCircle,
  XCircle, Clock, Crown, Zap, Star, EarOff, Phone, Mail,
  Calendar, Filter, ExternalLink, AlertCircle,
  ChevronLeft, ChevronRight,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { Link, useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { resolveFileUrl } from '../utils/resolveFileUrl';
import { useAlert } from '../context/AlertContext';

/* ─── Theme ───────────────────────────────────────────────────────────────── */
const C = {
  accent:   '#2891C2',
  border:   '#E4EEF3',
  bg:       '#F3F7FA',
  white:    '#FFFFFF',
  textMain: '#0F1A22',
  textSub:  '#3D5360',
  textMuted:'#7A96A3',
};

/* ─── Tab config ─────────────────────────────────────────────────────────── */
const TABS = [
  { key: 'ALL',       label: 'All Users',  Icon: Users,       accent: '#0C637E', pale: '#E2F0F3' },
  { key: 'PATIENT',   label: 'Patients',   Icon: User,        accent: '#0C637E', pale: '#E2F0F3' },
  { key: 'RESPONDER', label: 'Responders', Icon: ShieldCheck, accent: '#10B981', pale: '#ECFDF5' },
  { key: 'CAREGIVER', label: 'Caregivers', Icon: Users,       accent: '#8B5CF6', pale: '#EDE9FE' },
];

/* ─── Role badge config (used in ALL tab) ────────────────────────────────── */
const ROLE_BADGE = {
  PATIENT:   { label: 'Patient',   color: '#0C637E', bg: '#E2F0F3' },
  RESPONDER: { label: 'Responder', color: '#10B981', bg: '#ECFDF5' },
  CAREGIVER: { label: 'Caregiver', color: '#8B5CF6', bg: '#EDE9FE' },
};

/* ─── Status helpers ─────────────────────────────────────────────────────── */
const PLAN_META = {
  FREE:         { label: 'Free',       color: '#64748B', bg: '#F1F5F9', Icon: Zap   },
  PROFESSIONAL: { label: 'Pro',        color: '#0C637E', bg: '#E2F0F3', Icon: Star  },
  EXECUTIVE:    { label: 'Enterprise', color: '#04364E', bg: '#C4DDE6', Icon: Crown },
};

const VERIF_META = {
  PENDING:  { label: 'Pending Review', color: '#D97706', bg: '#FEF3C7', Icon: Clock        },
  VERIFIED: { label: 'Verified',       color: '#059669', bg: '#D1FAE5', Icon: CheckCircle  },
  REJECTED: { label: 'Rejected',       color: '#DC2626', bg: '#FEE2E2', Icon: XCircle      },
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
  ACTIVE:   { label: 'Active',          color: '#059669', bg: '#D1FAE5', Icon: CheckCircle },
  INACTIVE: { label: 'Inactive',        color: '#DC2626', bg: '#FEE2E2', Icon: XCircle    },
  PENDING:  { label: 'Pending Review',  color: '#D97706', bg: '#FEF3C7', Icon: Clock      },
  REJECTED: { label: 'Rejected',        color: '#DC2626', bg: '#FEE2E2', Icon: XCircle    },
};

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

/* ─── Main Component ─────────────────────────────────────────────────────── */
export default function UserManagement() {
  const { showAlert, showConfirm } = useAlert();
  const [searchParams] = useSearchParams();

  const validKeys   = TABS.map(t => t.key);
  const initialRole = searchParams.get('role');
  const initialSearch = searchParams.get('search') || '';
  const initialTab  = validKeys.includes(initialRole) 
    ? initialRole 
    : (initialSearch ? 'ALL' : 'PATIENT');

  const [activeTab,    setActiveTab]    = useState(initialTab);
  const [users,        setUsers]        = useState([]);
  const [loading,      setLoading]      = useState(false);
  const [error,        setError]        = useState('');
  const [search,       setSearch]       = useState(initialSearch);
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Pagination state
  const [currentPage,  setCurrentPage]  = useState(1);
  const itemsPerPage = 10;

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      // ALL tab fetches every user regardless of role
      const url = activeTab === 'ALL'
        ? '/api/admin/users'
        : `/api/admin/users?role=${activeTab}`;
      const res = await api.get(url);
      if (res.data.success) setUsers(res.data.data);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load users.');
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, [activeTab]);

  // Sync Search & Role from URL searchParams
  useEffect(() => {
    const s = searchParams.get('search');
    if (s !== null) {
      setSearch(s);
    }
    const roleParam = searchParams.get('role');
    if (roleParam && validKeys.includes(roleParam)) {
      setActiveTab(roleParam);
    } else if (s) {
      setActiveTab('ALL');
    }
  }, [searchParams]);

  useEffect(() => {
    fetchUsers();
    if (!searchParams.get('search')) {
      setSearch('');
    }
    setStatusFilter('ALL');
    setCurrentPage(1);
  }, [fetchUsers]);

  // Reset pagination to page 1 on local filter/search/tab changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, activeTab, statusFilter]);

  /* ── Actions ── */
  const handleDeactivate = (userId, name) => {
    showConfirm({
      title: 'Deactivate Account?',
      message: `"${name}" will lose login access immediately. You can reactivate at any time.`,
      type: 'warning',
      onConfirm: async () => {
        try {
          await api.patch(`/api/admin/users/${userId}/deactivate`);
          setUsers(prev => prev.map(u => u.id === userId ? { ...u, isActive: false } : u));
          showAlert(`${name} has been deactivated.`, 'success');
        } catch {
          showAlert('Failed to deactivate user.', 'error');
        }
      },
    });
  };

  const handleReactivate = async (userId, name) => {
    try {
      await api.patch(`/api/admin/users/${userId}/activate`);
      setUsers(prev => prev.map(u => u.id === userId ? { ...u, isActive: true } : u));
      showAlert(`${name} has been reactivated.`, 'success');
    } catch {
      showAlert('Failed to reactivate user.', 'error');
    }
  };

  const handleDelete = (userId, name) => {
    showConfirm({
      title: 'Permanently Delete?',
      message: `This will delete "${name}" and ALL their data. This cannot be undone.`,
      type: 'danger',
      onConfirm: async () => {
        try {
          await api.delete(`/api/admin/users/${userId}`);
          setUsers(prev => prev.filter(u => u.id !== userId));
          showAlert(`${name} has been permanently deleted.`, 'success');
        } catch {
          showAlert('Failed to delete user.', 'error');
        }
      },
    });
  };

  /* ── Filtering ── */
  const filtered = users.filter(u => {
    const q = search.toLowerCase();
    const matchSearch = !search || (
      u.fullName?.toLowerCase().includes(q) ||
      u.email?.toLowerCase().includes(q) ||
      u.phoneNumber?.toLowerCase().includes(q)
    );
    const effStatus = getEffectiveStatus(u, activeTab === 'ALL' ? u.role : activeTab);
    const matchFilter =
      statusFilter === 'ALL'      ? true :
      statusFilter === 'ACTIVE'   ? effStatus === 'ACTIVE' :
      statusFilter === 'INACTIVE' ? effStatus === 'INACTIVE' :
      statusFilter === 'PENDING'  ? effStatus === 'PENDING' :
      statusFilter === 'REJECTED' ? effStatus === 'REJECTED' : true;
    return matchSearch && matchFilter;
  });

  /* ── Summary counts (per-tab aware) ── */
  const summaryChips = getSummaryChips(users, activeTab);
  const tab = TABS.find(t => t.key === activeTab);

  /* ── Filter pill options per tab ── */
  const filterOptions =
    activeTab === 'RESPONDER' || activeTab === 'ALL'
      ? ['ALL', 'ACTIVE', 'INACTIVE', 'PENDING', 'REJECTED']
      : ['ALL', 'ACTIVE', 'INACTIVE'];

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.35 }}
    >
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: C.textMain, letterSpacing: '-0.02em', marginBottom: '4px' }}>
            User Management
          </h1>
          <p style={{ color: C.textMuted, fontSize: '0.9rem' }}>
            Manage all platform participants, access levels, and account status.
          </p>
        </div>
        <motion.button
          whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }}
          onClick={fetchUsers}
          style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            padding: '10px 18px', borderRadius: '12px',
            border: `1.5px solid ${C.border}`, background: C.white,
            color: C.textSub, fontWeight: 700, cursor: 'pointer',
            fontSize: '0.875rem', fontFamily: 'inherit',
          }}
        >
          <RefreshCw size={15} /> Refresh
        </motion.button>
      </div>

      {/* Summary chips */}
      <div style={{ display: 'grid', gridTemplateColumns: `repeat(${summaryChips.length}, 1fr)`, gap: '12px', marginBottom: '20px' }}>
        {summaryChips.map((s, i) => (
          <div key={i} style={{
            background: C.white, borderRadius: '12px', border: `1px solid ${C.border}`,
            padding: '14px 18px', display: 'flex', alignItems: 'center', gap: '12px',
            boxShadow: '0 1px 3px rgba(12,99,126,0.04)',
          }}>
            <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: s.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <s.Icon size={18} color={s.color} />
            </div>
            <div>
              <p style={{ fontSize: '1.4rem', fontWeight: 800, color: s.color, lineHeight: 1 }}>{loading ? '—' : s.value}</p>
              <p style={{ fontSize: '0.75rem', fontWeight: 600, color: C.textMuted, marginTop: '2px' }}>{s.label}</p>
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
        <div style={{ display: 'flex', borderBottom: `1px solid ${C.border}`, background: '#F8FAFC', padding: '0 24px' }}>
          {TABS.map(t => {
            const on = t.key === activeTab;
            return (
              <button
                key={t.key}
                onClick={() => setActiveTab(t.key)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '7px',
                  padding: '14px 4px', marginRight: '28px',
                  background: 'none', border: 'none', cursor: 'pointer',
                  fontFamily: 'inherit', fontWeight: on ? 700 : 600,
                  fontSize: '0.875rem',
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
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 24px', borderBottom: `1px solid ${C.border}` }}>
          <div style={{ position: 'relative', width: '300px' }}>
            <Search style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.textMuted }} size={15} />
            <input
              type="text"
              placeholder={`Search ${tab?.label.toLowerCase()}…`}
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{
                width: '100%', height: '38px', paddingLeft: '36px', paddingRight: '12px',
                border: `1.5px solid ${C.border}`, borderRadius: '10px',
                background: C.bg, outline: 'none', fontSize: '0.875rem',
                fontFamily: 'inherit', color: C.textMain, transition: 'border 0.2s',
                boxSizing: 'border-box',
              }}
              onFocus={e => e.target.style.borderColor = C.accent}
              onBlur={e => e.target.style.borderColor = C.border}
            />
          </div>
          <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
            <Filter size={14} color={C.textMuted} />
            {filterOptions.map(f => {
              const active = statusFilter === f;
              const clr =
                f === 'INACTIVE' ? '#DC2626' :
                f === 'PENDING'  ? '#D97706' :
                f === 'REJECTED' ? '#DC2626' :
                f === 'ACTIVE'   ? '#059669' : null;
              return (
                <button key={f} onClick={() => setStatusFilter(f)} style={{
                  padding: '4px 12px', borderRadius: '20px', border: 'none',
                  fontFamily: 'inherit', fontSize: '0.75rem', fontWeight: 700,
                  cursor: 'pointer', transition: 'all 0.15s',
                  background: active ? (clr ? `${clr}18` : C.accent) : C.bg,
                  color: active ? (clr || C.white) : C.textMuted,
                  outline: active && !clr ? `2px solid ${C.accent}` : 'none',
                }}>
                  {f}
                </button>
              );
            })}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div style={{ padding: '12px 24px', background: '#FFF7ED', borderBottom: `1px solid #FED7AA`, color: '#C2410C', fontSize: '0.875rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={16} /> {error}
          </div>
        )}

        {/* Responder notice banner */}
        {(activeTab === 'RESPONDER' || activeTab === 'ALL') && !loading && (
          <div style={{ padding: '10px 24px', background: '#FFFBEB', borderBottom: `1px solid #FEF3C7`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.8rem', color: '#92400E', fontWeight: 600 }}>
              <AlertCircle size={14} color='#D97706' />
              Credential status (Verified / Pending / Rejected) is separate from account login access. Use the Verification Queue to approve or reject credentials.
            </div>
            <Link to="/admin/verify" style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.78rem', fontWeight: 700, color: '#D97706', textDecoration: 'none', whiteSpace: 'nowrap', marginLeft: '16px' }}>
              Verification Queue <ExternalLink size={12} />
            </Link>
          </div>
        )}

        {/* Table */}
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#F8FAFC', borderBottom: `1px solid ${C.border}` }}>
              {['User', 'Contact', (activeTab === 'RESPONDER' || activeTab === 'ALL') ? 'Credentials / Plan' : 'Plan', 'Status', 'Joined', 'Actions'].map((h, i) => (
                <th key={h} style={{ padding: '12px 20px', textAlign: i === 5 ? 'right' : 'left', fontSize: '0.72rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              Array(5).fill(null).map((_, i) => (
                <tr key={i} style={{ borderBottom: `1px solid ${C.border}` }}>
                  {Array(6).fill(null).map((__, j) => (
                    <td key={j} style={{ padding: '16px 20px' }}>
                      <div style={{ height: 14, background: '#EEF2F5', borderRadius: 6, width: j === 0 ? '70%' : j === 5 ? '40%' : '55%', animation: 'shimmer 1.4s ease infinite' }} />
                    </td>
                  ))}
                </tr>
              ))
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ padding: '60px 20px', textAlign: 'center', color: C.textMuted }}>
                  <User size={40} style={{ opacity: 0.18, display: 'block', margin: '0 auto 12px' }} />
                  <p style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: '4px' }}>
                    No {tab?.label.toLowerCase()} found
                  </p>
                  <p style={{ fontSize: '0.82rem' }}>
                    {search ? 'Try a different search term.' : 'No accounts match the current filter.'}
                  </p>
                </td>
              </tr>
            ) : (
              filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((user, idx) => {
                const effStatus = getEffectiveStatus(user, activeTab === 'ALL' ? user.role : activeTab);
                const statusStyle = EFF_STATUS_STYLE[effStatus];
                const isDeaf  = user.medicalProfile?.patientType === 'DEAF';
                const plan    = PLAN_META[user.subscriptionPlan] || PLAN_META.FREE;
                const verifSt = user.responder?.verificationStatus;
                const verifMeta = verifSt ? VERIF_META[verifSt] : null;
                return (
                  <React.Fragment key={user.id}>
                    <motion.tr
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: idx * 0.03 }}
                      style={{
                        borderBottom: `1px solid ${C.border}`,
                        background: C.white,
                      }}
                    >
                      {/* User */}
                      <td style={{ padding: '14px 20px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{
                            width: '40px', height: '40px', borderRadius: '11px', flexShrink: 0,
                            background: `linear-gradient(135deg,${tab?.accent || '#0C637E'},#2496A7)`,
                            color: 'white', display: 'flex', alignItems: 'center',
                            justifyContent: 'center', fontWeight: 800, fontSize: '1rem',
                            overflow: 'hidden',
                          }}>
                            {user.profileImageUrl
                              ? <img src={resolveFileUrl(user.profileImageUrl)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              : (user.fullName?.[0] || '?').toUpperCase()
                            }
                          </div>
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <span style={{ fontWeight: 700, fontSize: '0.875rem', color: C.textMain }}>
                                {user.fullName || '—'}
                              </span>
                              {activeTab === 'ALL' && ROLE_BADGE[user.role] && (
                                <span style={{
                                  fontSize: '0.65rem', fontWeight: 800, padding: '2px 6px',
                                  borderRadius: '4px',
                                  background: ROLE_BADGE[user.role].bg,
                                  color: ROLE_BADGE[user.role].color,
                                }}>
                                  {ROLE_BADGE[user.role].label}
                                </span>
                              )}
                              {isDeaf && (
                                <span style={{ fontSize: '0.65rem', fontWeight: 800, padding: '2px 6px', borderRadius: '4px', background: '#FEF3C7', color: '#B45309', display: 'flex', alignItems: 'center', gap: '3px' }}>
                                  <EarOff size={9} /> DEAF
                                </span>
                              )}
                            </div>
                            <div style={{ fontSize: '0.78rem', color: C.textMuted, marginTop: '1px' }}>{user.email}</div>
                          </div>
                        </div>
                      </td>

                      {/* Contact */}
                      <td style={{ padding: '14px 20px', fontSize: '0.85rem', color: C.textSub }}>
                        {user.phoneNumber || '—'}
                      </td>

                      {/* Credentials / Plan */}
                      <td style={{ padding: '14px 20px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 9px', borderRadius: '6px', background: plan.bg, color: plan.color, fontSize: '0.72rem', fontWeight: 700, width: 'fit-content' }}>
                            <plan.Icon size={11} /> {plan.label}
                          </div>
                          {verifMeta && (
                            <div style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '3px 9px', borderRadius: '6px', background: verifMeta.bg, color: verifMeta.color, fontSize: '0.72rem', fontWeight: 700, width: 'fit-content' }}>
                              <verifMeta.Icon size={11} /> {verifMeta.label}
                            </div>
                          )}
                        </div>
                      </td>

                      {/* Effective Status */}
                      <td style={{ padding: '14px 20px' }}>
                        <span style={{
                          display: 'inline-flex', alignItems: 'center', gap: '5px',
                          padding: '4px 10px', borderRadius: '6px',
                          fontSize: '0.75rem', fontWeight: 700,
                          background: statusStyle.bg, color: statusStyle.color,
                        }}>
                          <statusStyle.Icon size={11} /> {statusStyle.label}
                        </span>
                      </td>

                      {/* Joined */}
                      <td style={{ padding: '14px 20px', fontSize: '0.82rem', color: C.textMuted }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Calendar size={12} /> {formatDate(user.createdAt)}
                        </div>
                      </td>

                      {/* Actions — context-aware */}
                      <td style={{ padding: '14px 20px' }}>
                        <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '6px' }}>
                          {renderActions(user, activeTab === 'ALL' ? user.role : activeTab, effStatus, handleDeactivate, handleReactivate, handleDelete)}
                        </div>
                      </td>
                    </motion.tr>
                  </React.Fragment>
                );
              })
            )}
          </tbody>
        </table>

        {/* Footer & Pagination */}
        <div style={{ padding: '14px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#F8FAFC', borderTop: `1px solid ${C.border}`, flexWrap: 'wrap', gap: '12px' }}>
          <span style={{ fontSize: '0.82rem', color: C.textMuted }}>
            {loading 
              ? 'Loading…' 
              : filtered.length === 0 
                ? 'Showing 0 of 0 entries'
                : `Showing ${((currentPage - 1) * itemsPerPage) + 1}–${Math.min(currentPage * itemsPerPage, filtered.length)} of ${filtered.length} entries`
            }
          </span>

          {Math.ceil(filtered.length / itemsPerPage) > 1 && !loading && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
              {/* Previous Button */}
              <button
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                disabled={currentPage === 1}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  width: '32px', height: '32px', borderRadius: '8px',
                  border: `1.5px solid ${C.border}`, background: C.white,
                  color: currentPage === 1 ? C.textMuted : C.textSub,
                  cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
                  opacity: currentPage === 1 ? 0.5 : 1,
                  transition: 'all 0.2s ease',
                }}
                onMouseEnter={e => { if (currentPage !== 1) e.currentTarget.style.borderColor = C.accent; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = C.border; }}
              >
                <ChevronLeft size={16} />
              </button>

              {/* Page Numbers */}
              {Array.from({ length: Math.ceil(filtered.length / itemsPerPage) }, (_, i) => i + 1).map(page => {
                const isCurrent = page === currentPage;
                return (
                  <button
                    key={page}
                    onClick={() => setCurrentPage(page)}
                    style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      minWidth: '32px', height: '32px', padding: '0 6px', borderRadius: '8px',
                      border: isCurrent ? `1.5px solid ${C.accent}` : `1.5px solid ${C.border}`,
                      background: isCurrent ? C.accent : C.white,
                      color: isCurrent ? C.white : C.textSub,
                      fontWeight: isCurrent ? 700 : 600,
                      fontSize: '0.82rem', cursor: 'pointer',
                      transition: 'all 0.2s ease',
                    }}
                    onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.borderColor = C.accent; }}
                    onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.borderColor = C.border; }}
                  >
                    {page}
                  </button>
                );
              })}

              {/* Next Button */}
              <button
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, Math.ceil(filtered.length / itemsPerPage)))}
                disabled={currentPage === Math.ceil(filtered.length / itemsPerPage)}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  width: '32px', height: '32px', borderRadius: '8px',
                  border: `1.5px solid ${C.border}`, background: C.white,
                  color: currentPage === Math.ceil(filtered.length / itemsPerPage) ? C.textMuted : C.textSub,
                  cursor: currentPage === Math.ceil(filtered.length / itemsPerPage) ? 'not-allowed' : 'pointer',
                  opacity: currentPage === Math.ceil(filtered.length / itemsPerPage) ? 0.5 : 1,
                  transition: 'all 0.2s ease',
                }}
                onMouseEnter={e => { if (currentPage !== Math.ceil(filtered.length / itemsPerPage)) e.currentTarget.style.borderColor = C.accent; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = C.border; }}
              >
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>
      </div>

      <style>{`
        @keyframes shimmer {
          0%   { background-position: 200% 0; }
          100% { background-position: -200% 0; }
        }
      `}</style>
    </motion.div>
  );
}

/* ─── Context-aware action buttons ──────────────────────────────────────── */
function renderActions(user, role, effStatus, onDeactivate, onReactivate, onDelete) {
  const stopProp = (fn) => (e) => { e.stopPropagation(); fn(); };

  // Responders with credential issues: only show Delete (not activate/deactivate)
  // The credential flow is handled in the Verification Queue, not here
  if (role === 'RESPONDER' && (effStatus === 'PENDING' || effStatus === 'REJECTED')) {
    return (
      <>
        <Link
          to="/admin/verify"
          onClick={e => e.stopPropagation()}
          title="Go to Verification Queue"
          style={{
            padding: '7px 11px', borderRadius: '8px', textDecoration: 'none',
            display: 'flex', alignItems: 'center', gap: '5px',
            background: effStatus === 'REJECTED' ? '#FEE2E2' : '#FEF3C7',
            color: effStatus === 'REJECTED' ? '#DC2626' : '#D97706',
            fontSize: '0.75rem', fontWeight: 700,
          }}
        >
          <ExternalLink size={13} />
          {effStatus === 'REJECTED' ? 'Review' : 'Verify'}
        </Link>
        <motion.button
          whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
          onClick={stopProp(() => onDelete(user.id, user.fullName))}
          title="Delete user"
          style={{ padding: '7px', borderRadius: '8px', border: 'none', background: '#FEE2E2', color: '#DC2626', cursor: 'pointer' }}
        >
          <Trash2 size={15} />
        </motion.button>
      </>
    );
  }

  // Normal users (patients, caregivers, verified responders): activate/deactivate + delete
  return (
    <>
      {effStatus === 'ACTIVE' || effStatus === 'INACTIVE' ? (
        effStatus === 'ACTIVE' ? (
          <motion.button
            whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
            onClick={stopProp(() => onDeactivate(user.id, user.fullName))}
            title="Deactivate account"
            style={{ padding: '7px', borderRadius: '8px', border: 'none', background: '#FEF3C7', color: '#D97706', cursor: 'pointer' }}
          >
            <ShieldOff size={15} />
          </motion.button>
        ) : (
          <motion.button
            whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
            onClick={stopProp(() => onReactivate(user.id, user.fullName))}
            title="Reactivate account"
            style={{ padding: '7px', borderRadius: '8px', border: 'none', background: '#D1FAE5', color: '#059669', cursor: 'pointer' }}
          >
            <ShieldCheck size={15} />
          </motion.button>
        )
      ) : null}
      <motion.button
        whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }}
        onClick={stopProp(() => onDelete(user.id, user.fullName))}
        title="Permanently delete"
        style={{ padding: '7px', borderRadius: '8px', border: 'none', background: '#FEE2E2', color: '#DC2626', cursor: 'pointer' }}
      >
        <Trash2 size={15} />
      </motion.button>
    </>
  );
}

/* ─── Summary chips — tab-aware ─────────────────────────────────────────── */
function getSummaryChips(users, role) {
  if (role === 'ALL') {
    return [
      { label: 'Total Users',    value: users.length,                                                               color: '#0C637E', bg: '#E2F0F3', Icon: Users       },
      { label: 'Active',         value: users.filter(u => u.isActive !== false).length,                             color: '#059669', bg: '#D1FAE5', Icon: CheckCircle  },
      { label: 'Responders',     value: users.filter(u => u.role === 'RESPONDER').length,                           color: '#10B981', bg: '#ECFDF5', Icon: ShieldCheck  },
      { label: 'Pending Review', value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length,    color: '#D97706', bg: '#FEF3C7', Icon: Clock        },
    ];
  }
  if (role === 'RESPONDER') {
    return [
      { label: 'Verified Responders', value: users.filter(u => u.responder?.verificationStatus === 'VERIFIED').length,  color: '#059669', bg: '#D1FAE5', Icon: CheckCircle },
      { label: 'Pending Review',       value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length,   color: '#D97706', bg: '#FEF3C7', Icon: Clock       },
      { label: 'Rejected',             value: users.filter(u => u.responder?.verificationStatus === 'REJECTED').length,  color: '#DC2626', bg: '#FEE2E2', Icon: XCircle     },
    ];
  }
  if (role === 'PATIENT') {
    return [
      { label: 'Active Patients',   value: users.filter(u => u.isActive !== false).length,                               color: '#059669', bg: '#D1FAE5', Icon: CheckCircle },
      { label: 'Inactive',          value: users.filter(u => u.isActive === false).length,                               color: '#DC2626', bg: '#FEE2E2', Icon: XCircle     },
      { label: 'DEAF / MUTE',       value: users.filter(u => u.medicalProfile?.patientType === 'DEAF').length,           color: '#D97706', bg: '#FEF3C7', Icon: EarOff      },
    ];
  }
  // Caregivers
  return [
    { label: 'Active Caregivers', value: users.filter(u => u.isActive !== false).length, color: '#059669', bg: '#D1FAE5', Icon: CheckCircle },
    { label: 'Inactive',          value: users.filter(u => u.isActive === false).length, color: '#DC2626', bg: '#FEE2E2', Icon: XCircle     },
  ];
}

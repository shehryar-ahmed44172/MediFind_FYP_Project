import React, { useState, useEffect, useCallback, useRef } from 'react';
import { ShieldOff, ShieldCheck, Trash2, User, Eye, ArrowUpRight } from 'lucide-react';
import { Link, useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { errorMessage } from '../services/adminApi';
import { resolveFileUrl } from '../utils/resolveFileUrl';
import { useAlert } from '../context/hooks';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, StatCard, Panel, Toolbar,
  SearchInput, SegmentedControl, Notice, DataTable, StatusBadge, Avatar, IconButton, Button, ErrorBanner,
} from '../components/ui';
import { paginate } from '../components/uiStyles';
import UserDetailDrawer from '../components/UserDetailDrawer';

/* ─── Tab config ─────────────────────────────────────────────────────────── */
const TABS = [
  { key: 'ALL',       label: 'All users'  },
  { key: 'PATIENT',   label: 'Patients'   },
  { key: 'RESPONDER', label: 'Responders' },
  { key: 'CAREGIVER', label: 'Caregivers' },
];
const VALID_TABS = TABS.map(t => t.key);

const ROLE_LABEL = { PATIENT: 'Patient', RESPONDER: 'Responder', CAREGIVER: 'Caregiver' };

const PLAN_META = {
  FREE:         { label: 'Free',      tone: 'neutral' },
  PROFESSIONAL: { label: 'Pro',       tone: 'info'    },
  EXECUTIVE:    { label: 'Executive', tone: 'accent'  },
};

const VERIF_META = {
  PENDING:  { label: 'Pending review', tone: 'warning' },
  VERIFIED: { label: 'Verified',       tone: 'success' },
  REJECTED: { label: 'Rejected',       tone: 'danger'  },
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

const EFF_STATUS = {
  ACTIVE:   { label: 'Active',         tone: 'success' },
  INACTIVE: { label: 'Inactive',       tone: 'neutral' },
  PENDING:  { label: 'Pending review', tone: 'warning' },
  REJECTED: { label: 'Rejected',       tone: 'danger'  },
};

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

  const summary = getSummary(users, activeTab);
  const tab = TABS.find(t => t.key === activeTab);
  const showsResponders = activeTab === 'RESPONDER' || activeTab === 'ALL';
  const filtersActive = !!search || statusFilter !== 'ALL';

  const filterOptions = (showsResponders
    ? ['ALL', 'ACTIVE', 'INACTIVE', 'PENDING', 'REJECTED']
    : ['ALL', 'ACTIVE', 'INACTIVE']
  ).map(f => ({ value: f, label: f === 'ALL' ? 'All' : EFF_STATUS[f].label }));

  const clearFilters = () => { setSearch(''); setStatusFilter('ALL'); setPage(1); };

  const COLS = 6;

  return (
    <>
      <PageHeader
        title="User Management"
        description="Manage platform accounts, login access and subscription plans. Select a user to open their profile."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      {/* Summary */}
      <div className="mf-grid-stats" style={{ marginBottom: '16px' }}>
        {summary.map(s => (
          <StatCard key={s.label} label={s.label} value={s.value} hint={s.hint} loading={loading} />
        ))}
      </div>

      <Panel>
        {/* Role tabs */}
        <div className="mf-tabs" role="tablist" aria-label="User roles">
          {TABS.map(t => {
            const on = t.key === activeTab;
            return (
              <button
                key={t.key}
                type="button"
                role="tab"
                aria-selected={on}
                className="mf-tab"
                onClick={() => changeTab(t.key)}
              >
                {t.label}
                {on && !loading && (
                  <span className="mf-num" style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 400 }}>
                    {users.length}
                  </span>
                )}
              </button>
            );
          })}
        </div>

        <Toolbar
          right={
            <SegmentedControl
              ariaLabel="Filter by status"
              options={filterOptions}
              value={statusFilter}
              onChange={(v) => { setStatusFilter(v); setPage(1); }}
            />
          }
        >
          <SearchInput
            width={300}
            value={search}
            onChange={(v) => { setSearch(v); setPage(1); }}
            placeholder={`Search ${tab?.label.toLowerCase()} by name, email or phone…`}
            aria-label="Search users"
          />
        </Toolbar>

        {/* Responder credential notice */}
        {showsResponders && !loading && (
          <Notice
            tone="info"
            inline
            style={{ padding: '8px 16px', borderBottom: '1px solid var(--border)', color: 'var(--admin-text-sub)', fontSize: '12.5px' }}
            action={
              <Link to="/admin/verify" className="mf-link" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '12.5px', textDecoration: 'none', whiteSpace: 'nowrap' }}>
                Verification Queue <ArrowUpRight size={13} aria-hidden="true" />
              </Link>
            }
          >
            Credential status (verified, pending, rejected) is separate from login access. Approve or reject credentials in the Verification Queue.
          </Notice>
        )}

        <DataTable minWidth="900px">
          <thead>
            <tr>
              <th scope="col">User</th>
              <th scope="col">Phone</th>
              <th scope="col">{showsResponders ? 'Plan / Credentials' : 'Plan'}</th>
              <th scope="col">Status</th>
              <th scope="col">Joined</th>
              <th scope="col" className="actions"><span className="sr-only">Actions</span></th>
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
                    message={filtersActive ? 'Try a different search term or filter.' : 'No accounts in this category yet.'}
                    action={filtersActive && <Button size="sm" onClick={clearFilters}>Clear filters</Button>}
                  />
                </td>
              </tr>
            ) : (
              rows.map((user) => {
                const role = activeTab === 'ALL' ? user.role : activeTab;
                const effStatus = getEffectiveStatus(user, role);
                const status = EFF_STATUS[effStatus];
                const isDeaf = user.medicalProfile?.patientType === 'DEAF';
                const plan = PLAN_META[user.subscriptionPlan] || PLAN_META.FREE;
                const verifSt = user.responder?.verificationStatus;
                const verifMeta = verifSt ? VERIF_META[verifSt] : null;
                return (
                  <tr
                    key={user.id}
                    className="mf-table-row"
                    onClick={() => setDetailUserId(user.id)}
                    style={{ cursor: 'pointer' }}
                  >
                    {/* User */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                        <Avatar name={user.fullName} src={user.profileImageUrl ? resolveFileUrl(user.profileImageUrl) : undefined} />
                        <div style={{ minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                            <span style={{ fontWeight: 500, color: 'var(--text-main)' }}>{user.fullName || '—'}</span>
                            {activeTab === 'ALL' && ROLE_LABEL[user.role] && (
                              <StatusBadge tone="neutral" dot={false} style={{ height: '20px', fontSize: '11.5px', padding: '0 6px' }}>
                                {ROLE_LABEL[user.role]}
                              </StatusBadge>
                            )}
                            {isDeaf && (
                              <StatusBadge tone="info" dot={false} title="Deaf / hard of hearing" style={{ height: '20px', fontSize: '11.5px', padding: '0 6px' }}>
                                Deaf
                              </StatusBadge>
                            )}
                          </div>
                          <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{user.email}</div>
                        </div>
                      </div>
                    </td>

                    {/* Phone */}
                    <td className="mf-num" style={{ whiteSpace: 'nowrap' }}>{user.phoneNumber || '—'}</td>

                    {/* Plan / Credentials */}
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                        <StatusBadge tone={plan.tone} dot={false}>{plan.label}</StatusBadge>
                        {verifMeta && <StatusBadge tone={verifMeta.tone}>{verifMeta.label}</StatusBadge>}
                      </div>
                    </td>

                    {/* Effective status */}
                    <td><StatusBadge tone={status.tone}>{status.label}</StatusBadge></td>

                    {/* Joined */}
                    <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>{formatDate(user.createdAt)}</td>

                    {/* Actions — context-aware */}
                    <td className="actions">
                      <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'flex-end', gap: '2px' }}>
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
        </DataTable>

        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} noun="users" />
      </Panel>

      {detailUserId && (
        <UserDetailDrawer
          key={detailUserId}
          userId={detailUserId}
          onClose={() => setDetailUserId(null)}
          onUserUpdated={(patch) => patchUser(patch.id, patch)}
        />
      )}
    </>
  );
}

/* ─── Context-aware row actions ─────────────────────────────────────────── */
function ActionButtons({ user, role, effStatus, onView, onDeactivate, onReactivate, onDelete }) {
  const stop = (fn) => (e) => { e.stopPropagation(); fn(); };
  const name = user.fullName || user.email;
  const isAdmin = user.role === 'ADMIN';

  return (
    <>
      <IconButton icon={Eye} label="View profile" aria-label={`View profile of ${name}`} onClick={stop(onView)} />

      {role === 'RESPONDER' && (effStatus === 'PENDING' || effStatus === 'REJECTED') ? (
        // Credential flow lives in the Verification Queue, not here
        <Link
          to="/admin/verify"
          onClick={e => e.stopPropagation()}
          title="Open Verification Queue"
          className="mf-btn mf-btn--secondary mf-btn--sm"
          style={{ margin: '0 2px' }}
        >
          {effStatus === 'REJECTED' ? 'Review' : 'Verify'}
        </Link>
      ) : isAdmin ? null : effStatus === 'ACTIVE' ? (
        <IconButton icon={ShieldOff} label="Deactivate account" aria-label={`Deactivate ${name}`} onClick={stop(() => onDeactivate(user.id, name))} />
      ) : (
        <IconButton icon={ShieldCheck} label="Reactivate account" aria-label={`Reactivate ${name}`} onClick={stop(() => onReactivate(user.id, name))} />
      )}

      {!isAdmin && (
        <IconButton icon={Trash2} tone="danger" label="Delete account" aria-label={`Delete ${name}`} onClick={stop(() => onDelete(user.id, name))} />
      )}
    </>
  );
}

/* ─── Summary stats — tab-aware ─────────────────────────────────────────── */
function getSummary(users, role) {
  const active = users.filter(u => u.isActive !== false).length;
  const inactive = users.filter(u => u.isActive === false).length;
  if (role === 'ALL') {
    return [
      { label: 'Total users',    value: users.length },
      { label: 'Active',         value: active },
      { label: 'Responders',     value: users.filter(u => u.role === 'RESPONDER').length },
      { label: 'Pending review', value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length, hint: 'Responder credentials' },
    ];
  }
  if (role === 'RESPONDER') {
    return [
      { label: 'Verified responders', value: users.filter(u => u.responder?.verificationStatus === 'VERIFIED').length },
      { label: 'Pending review',      value: users.filter(u => u.responder?.verificationStatus === 'PENDING').length },
      { label: 'Rejected',            value: users.filter(u => u.responder?.verificationStatus === 'REJECTED').length },
    ];
  }
  if (role === 'PATIENT') {
    return [
      { label: 'Active patients', value: active },
      { label: 'Inactive',        value: inactive },
      { label: 'Deaf / mute',     value: users.filter(u => u.medicalProfile?.patientType === 'DEAF').length },
    ];
  }
  // Caregivers
  return [
    { label: 'Active caregivers', value: active },
    { label: 'Inactive',          value: inactive },
  ];
}

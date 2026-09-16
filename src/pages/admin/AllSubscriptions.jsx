import React, { useState, useEffect, useCallback } from 'react';
import { CreditCard } from 'lucide-react';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SegmentedControl, SearchInput, ErrorBanner,
  StatCard, Panel, Toolbar, DataTable, StatusBadge, Avatar, Button,
} from '../../components/ui';
import { paginate } from '../../components/uiStyles';

const PLAN_PRICE = { FREE: 0, PROFESSIONAL: 499, EXECUTIVE: 2499 };
const PLAN_LABEL = { FREE: 'Free', PROFESSIONAL: 'Pro', EXECUTIVE: 'Executive' };
const PLAN_TONE = { FREE: 'neutral', PROFESSIONAL: 'info', EXECUTIVE: 'accent' };
const ROLE_LABEL = { PATIENT: 'Patient', CAREGIVER: 'Caregiver', RESPONDER: 'Responder' };

const PAGE_SIZE = 12;
const fmtPKR = (n) => `PKR ${Number(n || 0).toLocaleString()}`;
const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

const AllSubscriptions = () => {
  const [subscribers, setSubscribers]   = useState([]);
  const [stats, setStats]               = useState(null);
  const [loading, setLoading]           = useState(true);
  const [error, setError]               = useState('');
  const [search, setSearch]             = useState('');
  const [roleFilter, setRoleFilter]     = useState('ALL');
  const [planFilter, setPlanFilter]     = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [page, setPage]                 = useState(1);

  const loadData = useCallback(() => (
    api.get('/api/admin/subscriptions/all')
      .then(res => {
        if (!res.data?.success) return;
        setSubscribers((res.data.data.subscribers || []).map(u => ({
          id:       u.id,
          name:     u.fullName || u.email,
          email:    u.email,
          role:     u.role,
          plan:     u.subscriptionPlan,
          amount:   PLAN_PRICE[u.subscriptionPlan] || 0,
          active:   u.isActive !== false,
          joinedAt: u.createdAt,
        })));
        setStats(res.data.data.stats);
        setError('');
      })
      .catch(err => setError(errorMessage(err, 'Failed to load subscription records.')))
      .finally(() => setLoading(false))
  ), []);

  useEffect(() => { loadData(); }, [loadData]);

  const refresh = () => { setLoading(true); loadData(); };
  const withReset = (setter) => (value) => { setter(value); setPage(1); };

  const q = search.trim().toLowerCase();
  const filtered = subscribers.filter(s => {
    if (roleFilter !== 'ALL' && s.role !== roleFilter) return false;
    if (planFilter !== 'ALL' && s.plan !== planFilter) return false;
    if (statusFilter === 'ACTIVE' && !s.active) return false;
    if (statusFilter === 'INACTIVE' && s.active) return false;
    return !q || s.name.toLowerCase().includes(q) || s.email.toLowerCase().includes(q);
  });
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);
  const totalMRR = subscribers.filter(s => s.active).reduce((sum, s) => sum + s.amount, 0);
  const filtersActive = roleFilter !== 'ALL' || planFilter !== 'ALL' || statusFilter !== 'ALL' || !!q;
  const clearFilters = () => { setRoleFilter('ALL'); setPlanFilter('ALL'); setStatusFilter('ALL'); setSearch(''); setPage(1); };

  const total = stats?.total || 0;
  const pct = (n) => Math.round(((n || 0) / (total || 1)) * 100);

  const COLS = 6;

  return (
    <div className="mf-stack">
      <div>
        <PageHeader
          title="All Subscription Records"
          description="Every patient, caregiver and responder account with its current plan."
          actions={<RefreshButton onClick={refresh} loading={loading} />}
        />
        <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

        <div className="mf-grid-stats">
          <StatCard label="Total users" value={stats?.total ?? 0} loading={loading}
            hint={['PATIENT', 'CAREGIVER', 'RESPONDER'].map(r => `${stats?.byRole?.[r] ?? 0} ${ROLE_LABEL[r].toLowerCase()}s`).join(' · ')} />
          <StatCard label="Active accounts" value={stats?.active ?? 0} loading={loading} hint={`${pct(stats?.active)}% of all users`} />
          <StatCard label="Monthly revenue" value={fmtPKR(totalMRR)} loading={loading} hint="Active paid accounts only" />
          <StatCard label="Executive subscribers" value={stats?.EXECUTIVE ?? 0} loading={loading}
            hint={`${stats?.PROFESSIONAL ?? 0} Pro · ${stats?.FREE ?? 0} Free`} />
        </div>
      </div>

      <Panel>
        <Toolbar right={<SearchInput width={240} value={search} onChange={withReset(setSearch)} placeholder="Search name or email…" />}>
          <SegmentedControl
            ariaLabel="Filter by role"
            value={roleFilter}
            onChange={withReset(setRoleFilter)}
            options={['ALL', 'PATIENT', 'CAREGIVER', 'RESPONDER'].map(r => ({
              value: r, label: r === 'ALL' ? 'All roles' : ROLE_LABEL[r], count: loading || r === 'ALL' ? undefined : (stats?.byRole?.[r] ?? 0),
            }))}
          />
          <SegmentedControl
            ariaLabel="Filter by plan"
            value={planFilter}
            onChange={withReset(setPlanFilter)}
            options={['ALL', 'FREE', 'PROFESSIONAL', 'EXECUTIVE'].map(p => ({
              value: p, label: p === 'ALL' ? 'All plans' : PLAN_LABEL[p], count: loading || p === 'ALL' ? undefined : (stats?.[p] ?? 0),
            }))}
          />
          <SegmentedControl
            ariaLabel="Filter by account status"
            value={statusFilter}
            onChange={withReset(setStatusFilter)}
            options={[{ value: 'ALL', label: 'Any status' }, { value: 'ACTIVE', label: 'Active' }, { value: 'INACTIVE', label: 'Inactive' }]}
          />
        </Toolbar>

        <DataTable minWidth="760px">
          <thead>
            <tr>
              <th scope="col">User</th>
              <th scope="col">Role</th>
              <th scope="col">Plan</th>
              <th scope="col" className="num">Monthly fee</th>
              <th scope="col">Status</th>
              <th scope="col">Joined</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={6} cols={COLS} />
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={CreditCard}
                    title="No records match your filters"
                    action={filtersActive ? <Button size="sm" onClick={clearFilters}>Clear filters</Button> : undefined}
                  />
                </td>
              </tr>
            ) : rows.map((sub) => (
              <tr key={sub.id} className="mf-table-row">
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                    <Avatar name={sub.name} />
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontWeight: 500, color: 'var(--text-main)' }}>{sub.name}</div>
                      <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{sub.email}</div>
                    </div>
                  </div>
                </td>
                <td>{ROLE_LABEL[sub.role] || ROLE_LABEL.PATIENT}</td>
                <td><StatusBadge tone={PLAN_TONE[sub.plan] || 'neutral'}>{PLAN_LABEL[sub.plan] || sub.plan}</StatusBadge></td>
                <td className="num" style={{ color: sub.amount > 0 ? 'var(--text-main)' : 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                  <span className="mf-num">{sub.amount > 0 ? fmtPKR(sub.amount) : '—'}</span>
                </td>
                <td><StatusBadge tone={sub.active ? 'success' : 'neutral'}>{sub.active ? 'Active' : 'Inactive'}</StatusBadge></td>
                <td className="mf-num" style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{formatDate(sub.joinedAt)}</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} noun="records" />
      </Panel>
    </div>
  );
};

export default AllSubscriptions;

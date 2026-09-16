import React, { useState, useEffect, useCallback } from 'react';
import { Check, Users, Lock, CreditCard } from 'lucide-react';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { updateSubscriptionPlan, PLAN_OPTIONS, errorMessage } from '../../services/adminApi';
import { useAlert } from '../../context/hooks';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SegmentedControl, SearchInput, ErrorBanner,
  StatCard, Panel, Toolbar, DataTable, StatusBadge, Avatar, Button, Select,
} from '../../components/ui';
import { paginate } from '../../components/uiStyles';

// Plan catalogue — prices are fixed server-side (PKR); this page shows them read-only
const PLAN_META = [
  { id: 'FREE', name: 'Free', price: 0, features: ['Standard SOS / dispatch / monitoring', 'Basic profile & credentials', 'Core platform access'] },
  { id: 'PROFESSIONAL', name: 'Pro', price: 499, features: ['Priority SOS / dispatch / alerts', 'Extended history & case management', 'Enhanced profile visibility'] },
  { id: 'EXECUTIVE', name: 'Executive', price: 2499, features: ['Elite priority access', 'Full analytics & unlimited history', 'VIP support & custom badge'] },
];

const PLAN_LABEL = Object.fromEntries(PLAN_OPTIONS.map(p => [p.value, p.label]));
const PLAN_PRICE = Object.fromEntries(PLAN_OPTIONS.map(p => [p.value, p.price]));
const PLAN_TONE = { FREE: 'neutral', PROFESSIONAL: 'info', EXECUTIVE: 'accent' };

const PAGE_SIZE = 10;
const fmtPKR = (n) => `PKR ${Number(n || 0).toLocaleString()}`;
const formatDate = (iso) => (iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—');

const SubscriptionManagement = () => {
  const { showAlert, showConfirm } = useAlert();
  const [search, setSearch] = useState('');
  const [planFilter, setPlanFilter] = useState('ALL');
  const [accountFilter, setAccountFilter] = useState('ALL');
  const [subscribers, setSubscribers] = useState([]);
  const [apiStats, setApiStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const [savingId, setSavingId] = useState(null);

  const loadData = useCallback(() => (
    api.get('/api/admin/subscriptions')
      .then(res => {
        if (!res.data?.success) return;
        const raw = res.data.data.subscribers || [];
        setSubscribers(raw.map(u => ({
          id: u.id,
          user: u.fullName || u.email,
          email: u.email,
          role: u.role,
          plan: u.subscriptionPlan,
          active: u.isActive !== false,
          amount: PLAN_PRICE[u.subscriptionPlan] || 0,
          joinedAt: u.createdAt,
        })));
        setApiStats(res.data.data.stats);
        setError('');
      })
      .catch(err => setError(errorMessage(err, 'Failed to load subscription data.')))
      .finally(() => setLoading(false))
  ), []);

  useEffect(() => { loadData(); }, [loadData]);

  const refresh = () => { setLoading(true); loadData(); };

  const changePlan = (sub, plan) => {
    const isCancel = plan === 'FREE';
    showConfirm({
      title: isCancel ? 'Cancel subscription?' : `Move to ${PLAN_LABEL[plan]}?`,
      message: isCancel
        ? `${sub.user} will be moved to the Free plan immediately and lose premium features. No refund is issued from the portal.`
        : `${sub.user} will move from ${PLAN_LABEL[sub.plan]} to ${PLAN_LABEL[plan]} (${fmtPKR(PLAN_PRICE[plan])}/mo). This takes effect immediately.`,
      type: isCancel ? 'danger' : 'info',
      confirmLabel: isCancel ? 'Cancel subscription' : 'Change plan',
      cancelLabel: 'Keep current plan',
      onConfirm: async () => {
        setSavingId(sub.id);
        try {
          await updateSubscriptionPlan(sub.id, plan);
          showAlert(isCancel ? `${sub.user}'s subscription was cancelled.` : `${sub.user} is now on ${PLAN_LABEL[plan]}.`, 'success');
          await loadData();
        } catch (err) {
          showAlert(err.message, 'error');
        } finally {
          setSavingId(null);
        }
      },
    });
  };

  const q = search.trim().toLowerCase();
  const filtered = subscribers.filter(s => {
    const matchPlan = planFilter === 'ALL' || s.plan === planFilter;
    const matchAccount = accountFilter === 'ALL' || (accountFilter === 'ACTIVE' ? s.active : !s.active);
    const matchSearch = !q || s.user.toLowerCase().includes(q) || s.email.toLowerCase().includes(q);
    return matchPlan && matchAccount && matchSearch;
  });
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);

  const breakdown = apiStats?.planBreakdown ?? [];
  const planCount = (id) => breakdown.find(p => p.plan === id)?.count ?? breakdown.find(p => p.plan === id)?._count ?? 0;
  const totalMRR = apiStats?.mrr ?? subscribers.reduce((sum, s) => sum + s.amount, 0);
  const filtersActive = planFilter !== 'ALL' || accountFilter !== 'ALL' || !!q;
  const clearFilters = () => { setPlanFilter('ALL'); setAccountFilter('ALL'); setSearch(''); setPage(1); };

  const COLS = 6;

  return (
    <div className="mf-stack">
      <div>
        <PageHeader
          title="Subscription Management"
          description="Revenue, plan distribution and paid subscribers. Change or cancel a subscriber's plan from the table."
          actions={(
            <>
              <Link to="/admin/subscriptions/all" className="mf-btn mf-btn--secondary">
                <Users size={15} aria-hidden="true" /> All users &amp; plans
              </Link>
              <RefreshButton onClick={refresh} loading={loading} />
            </>
          )}
        />
        <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

        <div className="mf-grid-stats">
          <StatCard label="Monthly revenue" value={fmtPKR(totalMRR)} hint="Estimated from current plans" loading={loading} />
          <StatCard label="Paid subscribers" value={apiStats?.totalPaid ?? subscribers.length} hint={`${subscribers.filter(s => !s.active).length} with deactivated accounts`} loading={loading} />
          <StatCard label="Pro accounts" value={planCount('PROFESSIONAL')} hint={`${fmtPKR(499)} / month each`} loading={loading} />
          <StatCard label="Executive accounts" value={planCount('EXECUTIVE')} hint={`${fmtPKR(2499)} / month each`} loading={loading} />
        </div>
      </div>

      {/* Plan catalogue (read-only) */}
      <Panel
        title="Plan catalogue"
        description="Plan prices and features are fixed server-side and cannot be edited from the portal."
        actions={<Lock size={14} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />}
      >
        <div className="mf-grid-3" style={{ gap: 0 }}>
          {PLAN_META.map((plan) => (
            <div key={plan.id} style={{ padding: '14px 16px', minWidth: 0 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                <StatusBadge tone={PLAN_TONE[plan.id]}>{plan.name}</StatusBadge>
                <span style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
                  <span className="mf-num" style={{ color: 'var(--text-main)', fontWeight: 600 }}>{loading ? '—' : planCount(plan.id).toLocaleString()}</span> users
                </span>
              </div>
              <p className="mf-num" style={{ fontSize: '18px', lineHeight: '26px', fontWeight: 600, color: 'var(--text-main)', margin: '0 0 8px' }}>
                {plan.price === 0 ? 'Free' : fmtPKR(plan.price)}
                {plan.price > 0 && <span style={{ fontSize: '12.5px', fontWeight: 400, color: 'var(--text-muted)' }}> /mo</span>}
              </p>
              <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                {plan.features.map(f => (
                  <li key={f} style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: 'var(--admin-text-sub)' }}>
                    <Check size={13} aria-hidden="true" style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                    {f}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </Panel>

      {/* Subscriber table */}
      <Panel>
        <Toolbar right={<SearchInput width={240} value={search} onChange={(v) => { setSearch(v); setPage(1); }} placeholder="Search subscribers…" />}>
          <SegmentedControl
            ariaLabel="Filter by plan"
            value={planFilter}
            onChange={(v) => { setPlanFilter(v); setPage(1); }}
            options={['ALL', 'PROFESSIONAL', 'EXECUTIVE'].map(p => ({ value: p, label: p === 'ALL' ? 'All plans' : PLAN_LABEL[p] }))}
          />
          <SegmentedControl
            ariaLabel="Filter by account status"
            value={accountFilter}
            onChange={(v) => { setAccountFilter(v); setPage(1); }}
            options={[{ value: 'ALL', label: 'Any account' }, { value: 'ACTIVE', label: 'Active' }, { value: 'INACTIVE', label: 'Deactivated' }]}
          />
        </Toolbar>

        <DataTable minWidth="820px">
          <thead>
            <tr>
              <th scope="col">Subscriber</th>
              <th scope="col">Plan</th>
              <th scope="col">Account</th>
              <th scope="col" className="num">Monthly</th>
              <th scope="col">Member since</th>
              <th scope="col" className="actions">Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={5} cols={COLS} />
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={CreditCard}
                    title={subscribers.length === 0 ? 'No paid subscribers yet' : 'No subscribers match your filters'}
                    message={subscribers.length === 0 ? 'Users on the Free plan are listed under All Subscriptions.' : undefined}
                    action={subscribers.length > 0 && filtersActive ? <Button size="sm" onClick={clearFilters}>Clear filters</Button> : undefined}
                  />
                </td>
              </tr>
            ) : (
              rows.map((sub) => {
                const busy = savingId === sub.id;
                return (
                  <tr key={sub.id} className="mf-table-row">
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                        <Avatar name={sub.user} />
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontWeight: 500, color: 'var(--text-main)' }}>{sub.user}</div>
                          <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{sub.email} · {sub.role}</div>
                        </div>
                      </div>
                    </td>
                    <td><StatusBadge tone={PLAN_TONE[sub.plan] || 'neutral'}>{PLAN_LABEL[sub.plan] || sub.plan}</StatusBadge></td>
                    <td><StatusBadge tone={sub.active ? 'success' : 'danger'}>{sub.active ? 'Active' : 'Deactivated'}</StatusBadge></td>
                    <td className="num" style={{ color: 'var(--text-main)', whiteSpace: 'nowrap' }}>
                      <span className="mf-num">{sub.amount > 0 ? fmtPKR(sub.amount) : '—'}</span>
                    </td>
                    <td className="mf-num" style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{formatDate(sub.joinedAt)}</td>
                    <td className="actions">
                      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', alignItems: 'center' }}>
                        <label className="sr-only" htmlFor={`plan-${sub.id}`}>Change plan for {sub.user}</label>
                        <Select
                          id={`plan-${sub.id}`}
                          value={sub.plan}
                          disabled={busy}
                          onChange={(e) => { if (e.target.value !== sub.plan) changePlan(sub, e.target.value); }}
                          style={{ height: '30px', width: 'auto', fontSize: '12.5px' }}
                        >
                          {PLAN_OPTIONS.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
                        </Select>
                        <Button size="sm" variant="danger-outline" disabled={busy} onClick={() => changePlan(sub, 'FREE')}>
                          {busy ? 'Saving…' : 'Cancel plan'}
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </DataTable>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} noun="subscribers" />
      </Panel>
    </div>
  );
};

export default SubscriptionManagement;

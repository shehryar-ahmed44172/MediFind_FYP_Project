import React, { useState, useEffect, useCallback } from 'react';
import { TrendingUp, CheckCircle, Search, Crown, Zap, Star, Users, Lock, CreditCard } from 'lucide-react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import api from '../../services/api';
import { updateSubscriptionPlan, PLAN_OPTIONS, errorMessage } from '../../services/adminApi';
import { useAlert } from '../../context/hooks';
import { PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, FilterPill, SearchInput, ErrorBanner } from '../../components/ui';
import { thStyle, paginate } from '../../components/uiStyles';

// Plan catalogue — prices are fixed server-side (PKR); this page shows them read-only
const PLAN_META = [
  {
    id: 'FREE', name: 'Free', icon: Zap, price: 0, color: 'var(--text-muted)',
    features: ['Standard SOS / dispatch / monitoring', 'Basic profile & credentials', 'Core platform access'],
  },
  {
    id: 'PROFESSIONAL', name: 'Pro', icon: Star, price: 499, color: 'var(--primary-light)',
    features: ['Priority SOS / dispatch / alerts', 'Extended history & case management', 'Enhanced profile visibility'],
  },
  {
    id: 'EXECUTIVE', name: 'Executive', icon: Crown, price: 2499, color: 'var(--primary)', featured: true,
    features: ['Elite priority access', 'Full analytics & unlimited history', 'VIP support & custom badge'],
  },
];

const PLAN_LABEL = Object.fromEntries(PLAN_OPTIONS.map(p => [p.value, p.label]));
const PLAN_PRICE = Object.fromEntries(PLAN_OPTIONS.map(p => [p.value, p.price]));
const PLAN_BADGE = {
  FREE:         { color: 'var(--text-muted)', bg: 'var(--tint-slate)' },
  PROFESSIONAL: { color: 'var(--primary-light)', bg: 'var(--tint-teal)'  },
  EXECUTIVE:    { color: 'var(--primary)', bg: 'var(--tint-blue)'  },
};

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

  const kpis = [
    { label: 'Monthly Revenue', value: fmtPKR(totalMRR), icon: TrendingUp, color: 'var(--primary)', bg: 'var(--tint-teal)', hint: 'Estimated from current plans' },
    { label: 'Paid Subscribers', value: apiStats?.totalPaid ?? subscribers.length, icon: CheckCircle, color: 'var(--success-fg)', bg: 'var(--tint-green)', hint: `${subscribers.filter(s => !s.active).length} with deactivated accounts` },
    { label: 'Pro Accounts', value: planCount('PROFESSIONAL'), icon: Star, color: 'var(--primary-light)', bg: 'var(--tint-teal)', hint: fmtPKR(499) + ' / month each' },
    { label: 'Executive Accounts', value: planCount('EXECUTIVE'), icon: Crown, color: 'var(--primary)', bg: 'var(--tint-blue)', hint: fmtPKR(2499) + ' / month each' },
  ];

  const COLS = 6;

  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.3 }}>
      <PageHeader
        title="Subscription Management"
        subtitle="Revenue, plan distribution and paid subscribers. Change or cancel a subscriber's plan from the table."
        actions={(
          <>
            <Link to="/admin/subscriptions/all" style={{ display: 'inline-flex', alignItems: 'center', gap: '7px', padding: '9px 16px', borderRadius: '10px', border: '1.5px solid var(--admin-border)', background: 'var(--surface)', color: 'var(--admin-text-sub)', fontWeight: 700, fontSize: '0.85rem' }}>
              <Users size={15} /> All users &amp; plans
            </Link>
            <RefreshButton onClick={refresh} loading={loading} />
          </>
        )}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      {/* KPI Cards */}
      <div className="mf-grid-stats" style={{ marginBottom: '20px' }}>
        {kpis.map((card) => (
          <div key={card.label} style={{ background: 'var(--surface)', borderRadius: '14px', border: '1px solid var(--admin-border)', padding: '16px 20px', display: 'flex', gap: '14px', alignItems: 'center' }}>
            <div style={{ width: '42px', height: '42px', borderRadius: '12px', background: card.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <card.icon size={20} color={card.color} />
            </div>
            <div style={{ minWidth: 0 }}>
              <p style={{ fontSize: '0.74rem', fontWeight: 700, color: 'var(--admin-text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{card.label}</p>
              <p style={{ fontSize: '1.45rem', fontWeight: 800, color: card.color, lineHeight: 1.2 }}>{loading ? '—' : card.value}</p>
              <p style={{ fontSize: '0.72rem', color: 'var(--admin-text-muted)' }}>{card.hint}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Plan catalogue (read-only) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px', marginBottom: '8px' }}>
        {PLAN_META.map((plan) => {
          const featured = plan.featured;
          const fg = featured ? 'white' : plan.color;
          return (
            <div key={plan.id}
              style={{
                padding: '20px 22px', borderRadius: '16px', position: 'relative',
                border: `1.5px solid ${featured ? 'transparent' : 'var(--admin-border)'}`,
                background: featured ? 'linear-gradient(135deg,var(--primary),var(--primary-light))' : 'var(--surface)',
              }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '14px' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                    <plan.icon size={17} color={fg} />
                    <span style={{ fontWeight: 800, fontSize: '0.98rem', color: fg }}>{plan.name}</span>
                  </div>
                  <div style={{ fontSize: '1.5rem', fontWeight: 900, color: featured ? 'white' : 'var(--admin-text-main)' }}>
                    {plan.price === 0 ? 'Free' : fmtPKR(plan.price)}
                    {plan.price > 0 && <span style={{ fontSize: '0.78rem', fontWeight: 600, opacity: 0.75 }}> /mo</span>}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: '1.6rem', fontWeight: 900, color: fg, lineHeight: 1 }}>{loading ? '—' : planCount(plan.id).toLocaleString()}</div>
                  <div style={{ fontSize: '0.72rem', color: featured ? 'rgba(255,255,255,0.8)' : 'var(--admin-text-muted)', fontWeight: 700 }}>users</div>
                </div>
              </div>
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {plan.features.map(f => (
                  <li key={f} style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.82rem', color: featured ? 'rgba(255,255,255,0.9)' : 'var(--admin-text-sub)' }}>
                    <CheckCircle size={13} color={featured ? 'rgba(255,255,255,0.75)' : plan.color} />
                    {f}
                  </li>
                ))}
              </ul>
            </div>
          );
        })}
      </div>
      <p style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.76rem', color: 'var(--admin-text-muted)', marginBottom: '20px' }}>
        <Lock size={12} /> Plan prices and features are fixed server-side and cannot be edited from the portal.
      </p>

      {/* Subscriber Table */}
      <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', overflow: 'hidden' }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', gap: '12px 18px', flexWrap: 'wrap' }}>
            <div role="group" aria-label="Filter by plan" style={{ display: 'flex', gap: '6px' }}>
              {['ALL', 'PROFESSIONAL', 'EXECUTIVE'].map(p => (
                <FilterPill key={p} active={planFilter === p} onClick={() => { setPlanFilter(p); setPage(1); }}>
                  {p === 'ALL' ? 'All plans' : PLAN_LABEL[p]}
                </FilterPill>
              ))}
            </div>
            <div role="group" aria-label="Filter by account status" style={{ display: 'flex', gap: '6px' }}>
              {[['ALL', 'Any account'], ['ACTIVE', 'Active accounts'], ['INACTIVE', 'Deactivated']].map(([k, label]) => (
                <FilterPill key={k} active={accountFilter === k} color={k === 'INACTIVE' ? 'var(--error-fg)' : k === 'ACTIVE' ? 'var(--success-fg)' : undefined} onClick={() => { setAccountFilter(k); setPage(1); }}>
                  {label}
                </FilterPill>
              ))}
            </div>
          </div>
          <SearchInput icon={Search} width={240} value={search} onChange={(v) => { setSearch(v); setPage(1); }} placeholder="Search subscribers…" />
        </div>

        <div className="mf-table-scroll">
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '820px' }}>
            <thead>
              <tr>
                {['Subscriber', 'Plan', 'Account', 'Monthly', 'Member since', 'Actions'].map((h, i) => (
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
                      icon={CreditCard}
                      title={subscribers.length === 0 ? 'No paid subscribers yet' : 'No subscribers match your filters'}
                      message={subscribers.length === 0 ? 'Users on the Free plan are listed under All Subscriptions.' : undefined}
                    />
                  </td>
                </tr>
              ) : (
                rows.map((sub) => {
                  const badge = PLAN_BADGE[sub.plan] || PLAN_BADGE.FREE;
                  const busy = savingId === sub.id;
                  return (
                    <tr key={sub.id} className="mf-table-row" style={{ borderBottom: '1px solid var(--admin-border)' }}>
                      <td style={{ padding: '12px 20px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'linear-gradient(135deg,var(--primary),var(--primary-mid))', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.9rem', flexShrink: 0 }}>
                            {(sub.user?.[0] || '?').toUpperCase()}
                          </div>
                          <div style={{ minWidth: 0 }}>
                            <div style={{ fontWeight: 700, color: 'var(--admin-text-main)', fontSize: '0.88rem' }}>{sub.user}</div>
                            <div style={{ fontSize: '0.76rem', color: 'var(--admin-text-muted)' }}>{sub.email} · {sub.role}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: '12px 20px' }}>
                        <span style={{ fontSize: '0.76rem', fontWeight: 800, padding: '3px 10px', borderRadius: '6px', background: badge.bg, color: badge.color }}>{PLAN_LABEL[sub.plan] || sub.plan}</span>
                      </td>
                      <td style={{ padding: '12px 20px' }}>
                        <span style={{ fontSize: '0.76rem', fontWeight: 700, padding: '3px 10px', borderRadius: '6px', background: sub.active ? 'var(--tint-green)' : 'var(--tint-red)', color: sub.active ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                          {sub.active ? 'Active' : 'Deactivated'}
                        </span>
                      </td>
                      <td style={{ padding: '12px 20px', fontWeight: 700, color: 'var(--admin-text-main)', fontSize: '0.88rem', whiteSpace: 'nowrap' }}>
                        {sub.amount > 0 ? fmtPKR(sub.amount) : '—'}
                      </td>
                      <td style={{ padding: '12px 20px', fontSize: '0.82rem', color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>
                        {formatDate(sub.joinedAt)}
                      </td>
                      <td style={{ padding: '12px 20px' }}>
                        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', alignItems: 'center' }}>
                          <label className="sr-only" htmlFor={`plan-${sub.id}`}>Change plan for {sub.user}</label>
                          <select
                            id={`plan-${sub.id}`}
                            value={sub.plan}
                            disabled={busy}
                            onChange={(e) => { if (e.target.value !== sub.plan) changePlan(sub, e.target.value); }}
                            style={{ height: '32px', padding: '0 8px', borderRadius: '8px', border: '1.5px solid var(--admin-border)', background: 'var(--input-bg)', color: 'var(--text-main)', fontSize: '0.78rem', fontWeight: 700, fontFamily: 'inherit' }}
                          >
                            {PLAN_OPTIONS.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
                          </select>
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => changePlan(sub, 'FREE')}
                            style={{ height: '32px', padding: '0 12px', fontSize: '0.76rem', fontWeight: 700, borderRadius: '8px', background: 'var(--tint-red)', color: 'var(--error-fg)', border: '1px solid var(--error-border)', fontFamily: 'inherit', opacity: busy ? 0.6 : 1 }}
                          >
                            {busy ? 'Saving…' : 'Cancel plan'}
                          </button>
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
    </motion.div>
  );
};

export default SubscriptionManagement;

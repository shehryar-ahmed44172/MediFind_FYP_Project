import React, { useState, useEffect, useCallback } from 'react';
import { Users, TrendingUp, CheckCircle, Crown, Zap, Star, Search, Shield, Heart, UserCheck, CreditCard } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, FilterPill, SearchInput, ErrorBanner } from '../../components/ui';
import { thStyle, paginate } from '../../components/uiStyles';

const PLAN_PRICE = { FREE: 0, PROFESSIONAL: 499, EXECUTIVE: 2499 };
const PLAN_LABEL = { FREE: 'Free', PROFESSIONAL: 'Pro', EXECUTIVE: 'Executive' };

const PLAN_STYLE = {
  FREE:         { color: 'var(--text-muted)', bg: 'var(--tint-slate)' },
  PROFESSIONAL: { color: 'var(--primary-light)', bg: 'var(--tint-teal)' },
  EXECUTIVE:    { color: 'var(--primary)', bg: 'var(--tint-blue)' },
};

const ROLE_STYLE = {
  PATIENT:   { color: 'var(--primary)',     bg: 'var(--tint-teal)',  Icon: Heart,     label: 'Patient' },
  CAREGIVER: { color: 'var(--primary-mid)', bg: 'var(--tint-blue)',  Icon: Shield,    label: 'Caregiver' },
  RESPONDER: { color: 'var(--success)',     bg: 'var(--tint-green)', Icon: UserCheck, label: 'Responder' },
};

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

  const kpiCards = [
    { label: 'Total Users',           value: stats?.total ?? 0,     Icon: Users,       color: 'var(--primary)', bg: 'var(--tint-teal)' },
    { label: 'Active Accounts',       value: stats?.active ?? 0,    Icon: CheckCircle, color: 'var(--success)', bg: 'var(--tint-green)' },
    { label: 'Monthly Revenue',       value: fmtPKR(totalMRR),      Icon: TrendingUp,  color: 'var(--primary-light)', bg: 'var(--tint-blue)', hint: 'Active paid accounts only' },
    { label: 'Executive Subscribers', value: stats?.EXECUTIVE ?? 0, Icon: Crown,       color: 'var(--primary)', bg: 'var(--tint-teal)' },
  ];

  const roleBreakdown = ['PATIENT', 'CAREGIVER', 'RESPONDER'].map(role => ({ role, count: stats?.byRole?.[role] ?? 0 }));

  const planBreakdown = [
    { id: 'FREE',         Icon: Zap,   featured: false },
    { id: 'PROFESSIONAL', Icon: Star,  featured: false },
    { id: 'EXECUTIVE',    Icon: Crown, featured: true  },
  ];

  const COLS = 6;

  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.3 }}>
      <PageHeader
        title="All Subscription Records"
        subtitle="Every patient, caregiver and responder account with its current plan."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      {/* KPI Cards */}
      <div className="mf-grid-stats" style={{ marginBottom: '20px' }}>
        {kpiCards.map((card) => (
          <div key={card.label} style={{ background: 'var(--surface)', borderRadius: '14px', border: '1px solid var(--admin-border)', padding: '16px 20px', display: 'flex', gap: '14px', alignItems: 'center' }}>
            <div style={{ width: '42px', height: '42px', borderRadius: '12px', background: card.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <card.Icon size={20} color={card.color} />
            </div>
            <div>
              <p style={{ fontSize: '0.74rem', fontWeight: 700, color: 'var(--admin-text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{card.label}</p>
              <p style={{ fontSize: '1.45rem', fontWeight: 800, color: card.color, lineHeight: 1.2 }}>{loading ? '—' : card.value}</p>
              {card.hint && <p style={{ fontSize: '0.72rem', color: 'var(--admin-text-muted)' }}>{card.hint}</p>}
            </div>
          </div>
        ))}
      </div>

      {/* Role + plan breakdown */}
      <div className="mf-grid-main-side" style={{ gridTemplateColumns: undefined, marginBottom: '20px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
          {planBreakdown.map((plan) => {
            const count = stats?.[plan.id] ?? 0;
            const fg = plan.featured ? 'white' : PLAN_STYLE[plan.id].color;
            return (
              <div key={plan.id} style={{ padding: '18px 20px', borderRadius: '16px', border: plan.featured ? 'none' : '1px solid var(--admin-border)', background: plan.featured ? 'linear-gradient(135deg, var(--grad-start), var(--grad-end))' : 'var(--surface)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <plan.Icon size={16} color={fg} />
                    <span style={{ fontWeight: 800, fontSize: '0.92rem', color: fg }}>{PLAN_LABEL[plan.id]}</span>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '1.6rem', fontWeight: 900, color: fg, lineHeight: 1 }}>{loading ? '—' : count}</div>
                    <div style={{ fontSize: '0.7rem', color: plan.featured ? 'rgba(255,255,255,0.8)' : 'var(--admin-text-muted)', fontWeight: 700 }}>users</div>
                  </div>
                </div>
                <div style={{ fontSize: '1.05rem', fontWeight: 800, color: plan.featured ? 'white' : 'var(--admin-text-main)' }}>
                  {PLAN_PRICE[plan.id] === 0 ? 'Free' : fmtPKR(PLAN_PRICE[plan.id])}
                  {PLAN_PRICE[plan.id] > 0 && <span style={{ fontSize: '0.72rem', fontWeight: 600, opacity: 0.75 }}> /mo</span>}
                </div>
              </div>
            );
          })}
        </div>

        <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', padding: '18px 20px' }}>
          <h3 style={{ fontSize: '0.92rem', fontWeight: 800, color: 'var(--admin-text-main)', marginBottom: '14px' }}>Users by role</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {roleBreakdown.map(({ role, count }) => {
              const cfg = ROLE_STYLE[role];
              const pct = Math.round((count / (stats?.total || 1)) * 100);
              return (
                <div key={role}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '5px' }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.84rem', fontWeight: 700, color: 'var(--admin-text-sub)' }}>
                      <span style={{ width: '26px', height: '26px', borderRadius: '8px', background: cfg.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <cfg.Icon size={13} color={cfg.color} />
                      </span>
                      {cfg.label}
                    </span>
                    <span style={{ fontSize: '0.84rem', fontWeight: 800, color: cfg.color }}>{loading ? '—' : `${count} · ${pct}%`}</span>
                  </div>
                  <div style={{ height: '6px', background: 'var(--tint-slate)', borderRadius: '4px', overflow: 'hidden' }}>
                    <div style={{ width: `${pct}%`, height: '100%', background: cfg.color, borderRadius: '4px', transition: 'width 0.6s ease' }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Records Table */}
      <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', overflow: 'hidden' }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', gap: '10px 16px', flexWrap: 'wrap' }}>
            <div role="group" aria-label="Filter by role" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
              {['ALL', 'PATIENT', 'CAREGIVER', 'RESPONDER'].map(r => (
                <FilterPill key={r} active={roleFilter === r} onClick={() => withReset(setRoleFilter)(r)}>
                  {r === 'ALL' ? 'All roles' : ROLE_STYLE[r].label}
                </FilterPill>
              ))}
            </div>
            <div role="group" aria-label="Filter by plan" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
              {['ALL', 'FREE', 'PROFESSIONAL', 'EXECUTIVE'].map(p => (
                <FilterPill key={p} active={planFilter === p} onClick={() => withReset(setPlanFilter)(p)}>
                  {p === 'ALL' ? 'All plans' : PLAN_LABEL[p]}
                </FilterPill>
              ))}
            </div>
            <div role="group" aria-label="Filter by account status" style={{ display: 'flex', gap: '6px' }}>
              {[['ALL', 'Any status'], ['ACTIVE', 'Active'], ['INACTIVE', 'Inactive']].map(([k, label]) => (
                <FilterPill key={k} active={statusFilter === k} onClick={() => withReset(setStatusFilter)(k)}>{label}</FilterPill>
              ))}
            </div>
          </div>
          <SearchInput icon={Search} width={240} value={search} onChange={withReset(setSearch)} placeholder="Search name or email…" />
        </div>

        <div className="mf-table-scroll">
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '760px' }}>
            <thead>
              <tr>
                {['User', 'Role', 'Plan', 'Monthly fee', 'Status', 'Joined'].map((h) => (
                  <th key={h} scope="col" style={thStyle}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <TableSkeletonRows rows={6} cols={COLS} />
              ) : filtered.length === 0 ? (
                <tr><td colSpan={COLS}><EmptyState icon={CreditCard} title="No records match your filters" /></td></tr>
              ) : rows.map((sub) => {
                const roleCfg = ROLE_STYLE[sub.role] || ROLE_STYLE.PATIENT;
                const planCfg = PLAN_STYLE[sub.plan] || PLAN_STYLE.FREE;
                return (
                  <tr key={sub.id} className="mf-table-row" style={{ borderBottom: '1px solid var(--admin-border)' }}>
                    <td style={{ padding: '12px 20px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: roleCfg.bg, color: roleCfg.color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.9rem', flexShrink: 0 }}>
                          {(sub.name?.[0] || '?').toUpperCase()}
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontWeight: 700, color: 'var(--admin-text-main)', fontSize: '0.88rem' }}>{sub.name}</div>
                          <div style={{ fontSize: '0.76rem', color: 'var(--admin-text-muted)' }}>{sub.email}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '12px 20px' }}>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', fontSize: '0.76rem', fontWeight: 700, padding: '3px 10px', borderRadius: '6px', background: roleCfg.bg, color: roleCfg.color }}>
                        <roleCfg.Icon size={12} /> {roleCfg.label}
                      </span>
                    </td>
                    <td style={{ padding: '12px 20px' }}>
                      <span style={{ fontSize: '0.76rem', fontWeight: 800, padding: '3px 10px', borderRadius: '6px', background: planCfg.bg, color: planCfg.color }}>{PLAN_LABEL[sub.plan] || sub.plan}</span>
                    </td>
                    <td style={{ padding: '12px 20px', fontWeight: 700, color: sub.amount > 0 ? 'var(--admin-text-main)' : 'var(--admin-text-muted)', fontSize: '0.88rem', whiteSpace: 'nowrap' }}>
                      {sub.amount > 0 ? fmtPKR(sub.amount) : '—'}
                    </td>
                    <td style={{ padding: '12px 20px' }}>
                      <span style={{ fontSize: '0.76rem', fontWeight: 700, padding: '3px 10px', borderRadius: '6px', background: sub.active ? 'var(--tint-green)' : 'var(--tint-slate)', color: sub.active ? 'var(--success)' : 'var(--text-muted)' }}>
                        {sub.active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 20px', fontSize: '0.82rem', color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>{formatDate(sub.joinedAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} />
      </div>
    </motion.div>
  );
};

export default AllSubscriptions;

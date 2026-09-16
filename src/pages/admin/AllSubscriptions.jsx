import React, { useState, useEffect, useCallback } from 'react';
import {
  CreditCard, Users, TrendingUp, CheckCircle, Crown, Zap, Star,
  Search, RefreshCw, ChevronLeft, ChevronRight, Shield, Heart, UserCheck,
} from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';
import { useAlert } from '../../context/AlertContext';

const PLAN_PRICE  = { FREE: 0, PROFESSIONAL: 499, EXECUTIVE: 2499 };
const PLAN_LABEL  = { FREE: 'Free', PROFESSIONAL: 'Pro', EXECUTIVE: 'Executive' };

const PLAN_STYLE = {
  Free:       { color: '#64748B', bg: '#F1F5F9' },
  Pro:        { color: '#0C637E', bg: '#E2F0F3' },
  Executive:  { color: '#04364E', bg: '#C4DDE6' },
};

const ROLE_STYLE = {
  PATIENT:   { color: '#10B981', bg: '#D1FAE5', Icon: Heart,     label: 'Patient' },
  CAREGIVER: { color: '#8B5CF6', bg: '#EDE9FE', Icon: Shield,    label: 'Caregiver' },
  RESPONDER: { color: '#F59E0B', bg: '#FEF3C7', Icon: UserCheck, label: 'Responder' },
  ADMIN:     { color: '#EF4444', bg: '#FEE2E2', Icon: Crown,     label: 'Admin' },
};

const STATUS_STYLE = {
  ACTIVE:    { color: '#10B981', bg: '#D1FAE5' },
  INACTIVE:  { color: '#6B7280', bg: '#F3F4F6' },
};

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

const AllSubscriptions = () => {
  const { showAlert } = useAlert();

  const [subscribers, setSubscribers]   = useState([]);
  const [stats, setStats]               = useState(null);
  const [loading, setLoading]           = useState(true);

  const [search, setSearch]             = useState('');
  const [roleFilter, setRoleFilter]     = useState('ALL');
  const [planFilter, setPlanFilter]     = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');

  const [currentPage, setCurrentPage]   = useState(1);
  const ITEMS_PER_PAGE = 12;

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/api/admin/subscriptions/all');
      if (res.data.success) {
        const raw = res.data.data.subscribers || [];
        setSubscribers(raw.map(u => ({
          id:       u.id,
          name:     u.fullName,
          email:    u.email,
          role:     u.role,
          rawPlan:  u.subscriptionPlan,
          plan:     PLAN_LABEL[u.subscriptionPlan] || u.subscriptionPlan,
          amount:   PLAN_PRICE[u.subscriptionPlan] || 0,
          active:   u.isActive,
          joinedAt: u.createdAt,
        })));
        setStats(res.data.data.stats);
      }
    } catch {
      showAlert('Failed to load subscription records', 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);
  useEffect(() => { setCurrentPage(1); }, [search, roleFilter, planFilter, statusFilter]);

  const filtered = subscribers.filter(s => {
    if (roleFilter   !== 'ALL' && s.role !== roleFilter)               return false;
    if (planFilter   !== 'ALL' && s.plan !== planFilter)               return false;
    if (statusFilter === 'ACTIVE'   && !s.active)                      return false;
    if (statusFilter === 'INACTIVE' && s.active)                       return false;
    if (search) {
      const q = search.toLowerCase();
      if (!s.name.toLowerCase().includes(q) && !s.email.toLowerCase().includes(q)) return false;
    }
    return true;
  });

  const totalPages  = Math.ceil(filtered.length / ITEMS_PER_PAGE);
  const pageSlice   = filtered.slice((currentPage - 1) * ITEMS_PER_PAGE, currentPage * ITEMS_PER_PAGE);
  const totalMRR    = subscribers.filter(s => s.active).reduce((sum, s) => sum + s.amount, 0);

  const kpiCards = [
    { label: 'Total Users',          value: stats?.total ?? 0,        Icon: Users,      color: '#0C637E', bg: '#E2F0F3' },
    { label: 'Active Accounts',      value: stats?.active ?? 0,       Icon: CheckCircle,color: '#10B981', bg: '#D1FAE5' },
    { label: 'Monthly Revenue',      value: `Rs. ${totalMRR.toLocaleString()}`, Icon: TrendingUp, color: '#F59E0B', bg: '#FEF3C7' },
    { label: 'Executive Subscribers',value: stats?.EXECUTIVE ?? 0,    Icon: Crown,      color: '#04364E', bg: '#C4DDE6' },
  ];

  const roleBreakdown = [
    { role: 'PATIENT',   count: stats?.byRole?.PATIENT   ?? 0 },
    { role: 'CAREGIVER', count: stats?.byRole?.CAREGIVER ?? 0 },
    { role: 'RESPONDER', count: stats?.byRole?.RESPONDER ?? 0 },
  ];

  const planBreakdown = [
    { id: 'FREE',         name: 'Free',      Icon: Zap,   price: 0,    color: '#64748B', bg: '#F8FAFC', border: '#E2E8F0' },
    { id: 'PROFESSIONAL', name: 'Pro',       Icon: Star,  price: 499,  color: '#0C637E', bg: '#E2F0F3', border: '#2496A7' },
    { id: 'EXECUTIVE',    name: 'Executive', Icon: Crown, price: 2499, color: '#04364E', bg: 'linear-gradient(135deg,#0C637E,#2891C2)', border: '#0C637E' },
  ];

  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.5 }}>

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2.5rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.25rem' }}>
            All Subscription Records
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '1.05rem' }}>
            Complete subscription overview across all user roles — Patients, Caregivers, and Responders.
          </p>
        </div>
        <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
          onClick={fetchData}
          style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', padding: '0.75rem 1.5rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, cursor: 'pointer', fontSize: '0.9rem' }}>
          <RefreshCw size={16} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} /> Refresh
        </motion.button>
      </div>

      {/* KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.5rem', marginBottom: '2rem' }}>
        {kpiCards.map((card, i) => (
          <motion.div key={i} initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.08 }}
            className="card" style={{ padding: '1.75rem 2rem', border: '1px solid var(--border)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <div style={{ width: '44px', height: '44px', borderRadius: '12px', background: card.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <card.Icon size={22} color={card.color} />
              </div>
            </div>
            <p style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.5rem' }}>{card.label}</p>
            <p style={{ fontSize: '2rem', fontWeight: 900, color: card.color }}>{loading ? '…' : card.value}</p>
          </motion.div>
        ))}
      </div>

      {/* Role Breakdown + Plan Breakdown */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1.5rem', marginBottom: '2rem' }}>

        {/* Role counts */}
        <div className="card" style={{ padding: '1.5rem', border: '1px solid var(--border)' }}>
          <h3 style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--secondary)', marginBottom: '1.25rem' }}>Users by Role</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {roleBreakdown.map(({ role, count }) => {
              const cfg    = ROLE_STYLE[role];
              const total  = stats?.total || 1;
              const pct    = Math.round((count / total) * 100);
              return (
                <div key={role}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.4rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: cfg.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <cfg.Icon size={14} color={cfg.color} />
                      </div>
                      <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--secondary)' }}>{cfg.label}</span>
                    </div>
                    <span style={{ fontSize: '0.85rem', fontWeight: 800, color: cfg.color }}>{loading ? '…' : count}</span>
                  </div>
                  <div style={{ height: '6px', background: 'var(--border)', borderRadius: '4px', overflow: 'hidden' }}>
                    <motion.div initial={{ width: 0 }} animate={{ width: `${pct}%` }} transition={{ duration: 0.8, delay: 0.3 }}
                      style={{ height: '100%', background: cfg.color, borderRadius: '4px' }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Plan breakdown cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem' }}>
          {planBreakdown.map((plan, i) => {
            const isExec  = plan.id === 'EXECUTIVE';
            const count   = stats?.[plan.id] ?? 0;
            return (
              <motion.div key={plan.id} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 + i * 0.1 }}
                style={{ padding: '1.5rem', borderRadius: '20px', border: `2px solid ${plan.border}`, background: plan.bg, position: 'relative', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <plan.Icon size={16} color={isExec ? 'white' : plan.color} />
                    <span style={{ fontWeight: 800, fontSize: '0.9rem', color: isExec ? 'white' : plan.color }}>{plan.name}</span>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '1.75rem', fontWeight: 900, color: isExec ? 'white' : plan.color }}>
                      {loading ? '…' : count}
                    </div>
                    <div style={{ fontSize: '0.7rem', color: isExec ? 'rgba(255,255,255,0.65)' : 'var(--text-muted)', fontWeight: 700 }}>Users</div>
                  </div>
                </div>
                <div style={{ fontSize: '1.2rem', fontWeight: 900, color: isExec ? 'white' : plan.color }}>
                  {plan.price === 0 ? 'Free' : `Rs. ${plan.price.toLocaleString()}`}
                  {plan.price > 0 && <span style={{ fontSize: '0.72rem', fontWeight: 600, opacity: 0.7 }}>/mo</span>}
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>

      {/* Records Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border)' }}>

        {/* Filters */}
        <div style={{ padding: '1.25rem 2rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1rem', flexWrap: 'wrap', background: 'var(--surface)' }}>
          {/* Role pills */}
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            {['ALL', 'PATIENT', 'CAREGIVER', 'RESPONDER'].map(r => {
              const cfg    = ROLE_STYLE[r];
              const active = roleFilter === r;
              return (
                <button key={r} onClick={() => setRoleFilter(r)}
                  style={{ padding: '0.4rem 1rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.78rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg ?? 'var(--secondary)') : 'white', color: active ? (cfg?.color ?? 'white') : 'var(--text-muted)', cursor: 'pointer' }}>
                  {r === 'ALL' ? 'All Roles' : (ROLE_STYLE[r]?.label ?? r)}
                </button>
              );
            })}
          </div>

          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
            {/* Plan pills */}
            <div style={{ display: 'flex', gap: '0.4rem' }}>
              {['ALL', 'Free', 'Pro', 'Executive'].map(p => {
                const cfg    = PLAN_STYLE[p];
                const active = planFilter === p;
                return (
                  <button key={p} onClick={() => setPlanFilter(p)}
                    style={{ padding: '0.35rem 0.8rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.73rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg ?? '#f1f5f9') : 'white', color: active ? (cfg?.color ?? 'var(--secondary)') : 'var(--text-muted)', cursor: 'pointer' }}>
                    {p === 'ALL' ? 'All Plans' : p}
                  </button>
                );
              })}
            </div>

            {/* Status pills */}
            <div style={{ display: 'flex', gap: '0.4rem' }}>
              {['ALL', 'ACTIVE', 'INACTIVE'].map(s => {
                const cfg    = STATUS_STYLE[s];
                const active = statusFilter === s;
                return (
                  <button key={s} onClick={() => setStatusFilter(s)}
                    style={{ padding: '0.35rem 0.8rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.73rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg ?? '#f1f5f9') : 'white', color: active ? (cfg?.color ?? 'var(--secondary)') : 'var(--text-muted)', cursor: 'pointer' }}>
                    {s === 'ALL' ? 'All Status' : s}
                  </button>
                );
              })}
            </div>

            {/* Search */}
            <div style={{ position: 'relative' }}>
              <Search size={14} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
              <input type="text" placeholder="Search name or email…" value={search} onChange={e => setSearch(e.target.value)}
                style={{ padding: '0.55rem 1rem 0.55rem 2.25rem', width: '220px', fontSize: '0.83rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface-raised)', fontFamily: 'var(--font-sans)', outline: 'none' }} />
            </div>
          </div>
        </div>

        {/* Table */}
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ background: 'var(--surface-raised)', borderBottom: '1px solid var(--border)' }}>
              {['User', 'Role', 'Plan', 'Monthly Fee', 'Status', 'Joined'].map((h, i) => (
                <th key={h} style={{ padding: '1rem 1.75rem', fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>Loading records…</td></tr>
            ) : pageSlice.length === 0 ? (
              <tr><td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>No records match your filters.</td></tr>
            ) : pageSlice.map((sub, idx) => {
              const roleCfg   = ROLE_STYLE[sub.role]   || ROLE_STYLE.PATIENT;
              const planCfg   = PLAN_STYLE[sub.plan]   || PLAN_STYLE.Free;
              const statusCfg = sub.active ? STATUS_STYLE.ACTIVE : STATUS_STYLE.INACTIVE;
              return (
                <motion.tr key={sub.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: idx * 0.02 }}
                  style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface)' }}>

                  {/* User */}
                  <td style={{ padding: '1rem 1.75rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem' }}>
                      <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: roleCfg.bg, color: roleCfg.color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.95rem', flexShrink: 0 }}>
                        {sub.name[0]}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, color: 'var(--secondary)', fontSize: '0.9rem' }}>{sub.name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{sub.email}</div>
                      </div>
                    </div>
                  </td>

                  {/* Role */}
                  <td style={{ padding: '1rem 1.75rem' }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.75rem', fontWeight: 800, padding: '0.3rem 0.75rem', borderRadius: '6px', background: roleCfg.bg, color: roleCfg.color }}>
                      <roleCfg.Icon size={12} />
                      {roleCfg.label}
                    </span>
                  </td>

                  {/* Plan */}
                  <td style={{ padding: '1rem 1.75rem' }}>
                    <span style={{ fontSize: '0.75rem', fontWeight: 800, padding: '0.3rem 0.75rem', borderRadius: '6px', background: planCfg.bg, color: planCfg.color }}>{sub.plan}</span>
                  </td>

                  {/* Monthly fee */}
                  <td style={{ padding: '1rem 1.75rem', fontWeight: 700, color: sub.amount > 0 ? 'var(--secondary)' : 'var(--text-muted)', fontSize: '0.9rem' }}>
                    {sub.amount > 0 ? `Rs. ${sub.amount.toLocaleString()}` : '—'}
                  </td>

                  {/* Status */}
                  <td style={{ padding: '1rem 1.75rem' }}>
                    <span style={{ fontSize: '0.75rem', fontWeight: 800, padding: '0.3rem 0.75rem', borderRadius: '6px', background: statusCfg.bg, color: statusCfg.color }}>
                      {sub.active ? 'ACTIVE' : 'INACTIVE'}
                    </span>
                  </td>

                  {/* Joined */}
                  <td style={{ padding: '1rem 1.75rem', fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                    {formatDate(sub.joinedAt)}
                  </td>
                </motion.tr>
              );
            })}
          </tbody>
        </table>

        {/* Footer / Pagination */}
        <div style={{ padding: '1.25rem 2rem', background: 'var(--surface-raised)', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)', fontWeight: 500 }}>
            {loading ? 'Loading…' : filtered.length === 0 ? 'Showing 0 of 0 entries' :
              `Showing ${(currentPage - 1) * ITEMS_PER_PAGE + 1}–${Math.min(currentPage * ITEMS_PER_PAGE, filtered.length)} of ${filtered.length} entries`}
          </span>

          {totalPages > 1 && !loading && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
              <button onClick={() => setCurrentPage(p => Math.max(p - 1, 1))} disabled={currentPage === 1}
                style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '32px', height: '32px', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--surface)', color: currentPage === 1 ? 'var(--text-muted)' : 'var(--secondary)', cursor: currentPage === 1 ? 'not-allowed' : 'pointer', opacity: currentPage === 1 ? 0.5 : 1 }}>
                <ChevronLeft size={16} />
              </button>

              {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => {
                const isCurrent = page === currentPage;
                return (
                  <button key={page} onClick={() => setCurrentPage(page)}
                    style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minWidth: '32px', height: '32px', padding: '0 6px', borderRadius: '8px', border: isCurrent ? '1px solid var(--primary)' : '1px solid var(--border)', background: isCurrent ? 'var(--primary)' : 'var(--surface)', color: isCurrent ? 'white' : 'var(--secondary)', fontWeight: isCurrent ? 700 : 600, fontSize: '0.82rem', cursor: 'pointer' }}>
                    {page}
                  </button>
                );
              })}

              <button onClick={() => setCurrentPage(p => Math.min(p + 1, totalPages))} disabled={currentPage === totalPages}
                style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: '32px', height: '32px', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--surface)', color: currentPage === totalPages ? 'var(--text-muted)' : 'var(--secondary)', cursor: currentPage === totalPages ? 'not-allowed' : 'pointer', opacity: currentPage === totalPages ? 0.5 : 1 }}>
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  );
};

export default AllSubscriptions;

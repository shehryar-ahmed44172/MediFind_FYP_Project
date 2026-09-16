import React, { useState, useEffect, useCallback } from 'react';
import { CreditCard, Users, TrendingUp, CheckCircle, AlertCircle, Clock, Search, RefreshCw, Crown, Zap, Star, Edit3, X, Save, ChevronLeft, ChevronRight } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';
import { useAlert } from '../../context/AlertContext';

// Plan metadata — userCount is populated from API planBreakdown at runtime
const PLAN_META = [
  {
    id: 'FREE',
    name: 'Free',
    icon: Zap,
    price: 0,
    color: '#64748B',
    bg: '#F8FAFC',
    border: '#E2E8F0',
    features: ['Standard SOS / dispatch / monitoring', 'Basic profile & credentials', 'Core platform access'],
  },
  {
    id: 'PROFESSIONAL',
    name: 'Pro',
    icon: Star,
    price: 499,
    color: '#0C637E',
    bg: '#E2F0F3',
    border: '#2496A7',
    features: ['Priority SOS / dispatch / alerts', 'Extended history & case management', 'Enhanced profile visibility'],
  },
  {
    id: 'EXECUTIVE',
    name: 'Executive',
    icon: Crown,
    price: 2499,
    color: '#04364E',
    bg: 'linear-gradient(135deg,#0C637E,#2891C2)',
    border: '#0C637E',
    features: ['Elite priority access', 'Full analytics & unlimited history', 'VIP support & custom badge'],
  },
];

const PLAN_LABEL = { FREE: 'Free', PROFESSIONAL: 'Pro', EXECUTIVE: 'Executive' };
const PLAN_PRICE = { FREE: 0, PROFESSIONAL: 499, EXECUTIVE: 2499 };

const STATUS_STYLE = {
  ACTIVE:    { color: '#10B981', bg: '#D1FAE5' },
  CANCELLED: { color: '#6B7280', bg: '#F3F4F6' },
  PAST_DUE:  { color: '#EF4444', bg: '#FEE2E2' },
  TRIALING:  { color: '#F59E0B', bg: '#FEF3C7' },
};

const PLAN_STYLE = {
  Free:       { color: '#64748B', bg: '#F1F5F9' },
  Pro:        { color: '#0C637E', bg: '#E2F0F3' },
  Executive: { color: '#04364E', bg: '#C4DDE6' },
};

const formatDate = (iso) => iso === '—' ? '—' : new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' });

const SubscriptionManagement = () => {
  const { showAlert, showConfirm } = useAlert();
  const [search, setSearch] = useState('');
  const [planFilter, setPlanFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [subscribers, setSubscribers] = useState([]);
  const [apiStats, setApiStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editingPlan, setEditingPlan] = useState(null);
  const [plans, setPlans] = useState(PLAN_META);

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/api/admin/subscriptions');
      if (res.data.success) {
        const raw = res.data.data.subscribers || [];
        // Normalize to table row format
        const mapped = raw.map(u => ({
          id: u.id,
          user: u.fullName,
          email: u.email,
          plan: PLAN_LABEL[u.subscriptionPlan] || u.subscriptionPlan,
          rawPlan: u.subscriptionPlan,
          status: u.isActive ? 'ACTIVE' : 'CANCELLED',
          amount: PLAN_PRICE[u.subscriptionPlan] || 0,
          renewsAt: '—',
          joinedAt: u.createdAt,
        }));
        setSubscribers(mapped);
        setApiStats(res.data.data.stats);
      }
    } catch (e) {
      showAlert('Failed to load subscription data', 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Reset pagination to page 1 on local filter/search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, planFilter, statusFilter]);

  const handleCancelSub = (id) => {
    showConfirm({
      title: 'Cancel Subscription?',
      message: 'Are you sure you want to cancel this user\'s subscription? This will revoke their access to premium features at the end of the current billing cycle.',
      type: 'warning',
      onConfirm: () => {
        showAlert('Subscription cancellation request processed.', 'success');
      }
    });
  };

  const handleUpgrade = (id) => {
    showAlert('Upgrade request sent to user.', 'info');
  };

  const filtered = subscribers.filter(s => {
    const matchPlan = planFilter === 'ALL' || s.plan === planFilter;
    const matchStatus = statusFilter === 'ALL' || s.status === statusFilter;
    const matchSearch = !search || s.user.toLowerCase().includes(search.toLowerCase()) || s.email.toLowerCase().includes(search.toLowerCase());
    return matchPlan && matchStatus && matchSearch;
  });

  const totalMRR = apiStats?.mrr ?? subscribers.filter(s => s.status === 'ACTIVE').reduce((sum, s) => sum + s.amount, 0);
  const activeCount = subscribers.filter(s => s.status === 'ACTIVE').length;
  const pastDueCount = subscribers.filter(s => s.status === 'PAST_DUE').length;

  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.5 }}>


      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2.5rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.25rem' }}>Subscription Management</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '1.05rem' }}>Monitor plans, revenue, and user billing status across the network.</p>
        </div>
        <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
          onClick={fetchData}
          style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', padding: '0.75rem 1.5rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, cursor: 'pointer', fontSize: '0.9rem' }}>
          <RefreshCw size={16} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} /> Refresh
        </motion.button>
      </div>

      {/* Summary KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.5rem', marginBottom: '2.5rem' }}>
        {[
          { label: 'Monthly Revenue', value: `Rs. ${totalMRR.toLocaleString()}`, icon: TrendingUp, color: '#0C637E', bg: '#E2F0F3' },
          { label: 'Active Subscriptions', value: activeCount, icon: CheckCircle, color: '#10B981', bg: '#D1FAE5' },
          { label: 'Past Due', value: pastDueCount, icon: AlertCircle, color: '#EF4444', bg: '#FEE2E2' },
          { label: 'Executive Accounts', value: subscribers.filter(s => s.plan === 'Executive').length, icon: Crown, color: '#04364E', bg: '#C4DDE6' },
        ].map((card, i) => (
          <motion.div key={i} initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.08 }}
            className="card" style={{ padding: '1.75rem 2rem', border: '1px solid var(--border)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <div style={{ width: '44px', height: '44px', borderRadius: '12px', background: card.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <card.icon size={22} color={card.color} />
              </div>
            </div>
            <p style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.5rem' }}>{card.label}</p>
            <p style={{ fontSize: '2rem', fontWeight: 900, color: card.color }}>{card.value}</p>
          </motion.div>
        ))}
      </div>

      {/* Plan Overview Cards — user counts from real API planBreakdown */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.5rem', marginBottom: '2.5rem' }}>
        {plans.map((plan, i) => {
          const isEnterprise = plan.id === 'EXECUTIVE';
          const breakdown = apiStats?.planBreakdown ?? [];
          const userCount = breakdown.find(p => p.plan === plan.id)?._count
                         ?? breakdown.find(p => p.plan === plan.id)?.count
                         ?? 0;
          return (
            <motion.div key={plan.id} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 + i * 0.1 }}
              style={{ padding: '2rem', borderRadius: '20px', border: `2px solid ${plan.border}`, background: plan.bg, position: 'relative', overflow: 'hidden' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.5rem' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginBottom: '0.5rem' }}>
                    <plan.icon size={18} color={isEnterprise ? 'white' : plan.color} />
                    <span style={{ fontWeight: 800, fontSize: '1rem', color: isEnterprise ? 'white' : plan.color }}>{plan.name}</span>
                  </div>
                  <div style={{ fontSize: '1.75rem', fontWeight: 900, color: isEnterprise ? 'white' : plan.color }}>
                    {plan.price === 0 ? 'Free' : `Rs. ${plan.price.toLocaleString()}`}
                    {plan.price > 0 && <span style={{ fontSize: '0.8rem', fontWeight: 600, opacity: 0.7 }}>/mo</span>}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: '2rem', fontWeight: 900, color: isEnterprise ? 'white' : plan.color }}>
                    {loading ? '…' : userCount.toLocaleString()}
                  </div>
                  <div style={{ fontSize: '0.72rem', color: isEnterprise ? 'rgba(255,255,255,0.7)' : 'var(--text-muted)', fontWeight: 700 }}>Users</div>
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {plan.features.map(f => (
                  <div key={f} style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', fontSize: '0.82rem', color: isEnterprise ? 'rgba(255,255,255,0.85)' : 'var(--text-muted)', fontWeight: 500 }}>
                    <CheckCircle size={13} color={isEnterprise ? 'rgba(255,255,255,0.6)' : plan.color} />
                    {f}
                  </div>
                ))}
              </div>
              
              <div style={{ marginTop: '1.5rem', paddingTop: '1.25rem', borderTop: `1px solid ${isEnterprise ? 'rgba(255,255,255,0.15)' : 'var(--border)'}` }}>
                <motion.button
                  whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                  onClick={() => setEditingPlan(plan)}
                  style={{
                    width: '100%', padding: '0.625rem', borderRadius: '10px',
                    background: isEnterprise ? 'white' : 'var(--primary)',
                    color: isEnterprise ? 'var(--secondary)' : 'white',
                    border: 'none', fontWeight: 700, fontSize: '0.8rem',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem',
                    cursor: 'pointer'
                  }}
                >
                  <Edit3 size={14} /> Update Plan
                </motion.button>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Subscriber Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border)' }}>
        {/* Table Filters */}
        <div style={{ padding: '1.25rem 2rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1.5rem', flexWrap: 'wrap', background: 'var(--surface)' }}>
          <div style={{ display: 'flex', gap: '0.625rem' }}>
            {['ALL', 'Free', 'Pro', 'Executive'].map(p => {
              const cfg = PLAN_STYLE[p];
              const active = planFilter === p;
              return (
                <button key={p} onClick={() => setPlanFilter(p)}
                  style={{ padding: '0.5rem 1.25rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.8rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg || 'var(--secondary)') : 'white', color: active ? (cfg?.color || 'white') : 'var(--text-muted)', cursor: 'pointer' }}>
                  {p}
                </button>
              );
            })}
          </div>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              {['ALL', 'ACTIVE', 'PAST_DUE', 'CANCELLED'].map(s => {
                const cfg = STATUS_STYLE[s];
                const active = statusFilter === s;
                return (
                  <button key={s} onClick={() => setStatusFilter(s)}
                    style={{ padding: '0.375rem 0.875rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.72rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg || '#f1f5f9') : 'white', color: active ? (cfg?.color || 'var(--secondary)') : 'var(--text-muted)', cursor: 'pointer' }}>
                    {s}
                  </button>
                );
              })}
            </div>
            <div style={{ position: 'relative' }}>
              <Search size={15} style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
              <input type="text" placeholder="Search users..." value={search} onChange={e => setSearch(e.target.value)}
                style={{ padding: '0.625rem 1rem 0.625rem 2.5rem', width: '220px', fontSize: '0.85rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface-raised)', fontFamily: 'var(--font-sans)', outline: 'none' }} />
            </div>
          </div>
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ background: 'var(--surface-raised)', borderBottom: '1px solid var(--border)' }}>
              {['User', 'Plan', 'Status', 'Monthly', 'Renews', 'Actions'].map((h, i) => (
                <th key={h} style={{ padding: '1rem 1.75rem', fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', textAlign: i === 5 ? 'right' : 'left' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>No subscribers match your filters.</td></tr>
            ) : (
              filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((sub, idx) => {
                const statusCfg = STATUS_STYLE[sub.status] || STATUS_STYLE.ACTIVE;
                const planCfg = PLAN_STYLE[sub.plan] || PLAN_STYLE.Free;
                return (
                  <motion.tr key={sub.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: idx * 0.03 }}
                    style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface)' }}>
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem' }}>
                        <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: 'linear-gradient(135deg,#0C637E,#2496A7)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.95rem', flexShrink: 0 }}>
                          {sub.user[0]}
                        </div>
                        <div>
                          <div style={{ fontWeight: 700, color: 'var(--secondary)', fontSize: '0.9rem' }}>{sub.user}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{sub.email}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 800, padding: '0.3rem 0.75rem', borderRadius: '6px', background: planCfg.bg, color: planCfg.color }}>{sub.plan}</span>
                    </td>
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 800, padding: '0.3rem 0.75rem', borderRadius: '6px', background: statusCfg.bg, color: statusCfg.color }}>{sub.status}</span>
                    </td>
                    <td style={{ padding: '1rem 1.75rem', fontWeight: 700, color: sub.amount > 0 ? 'var(--secondary)' : 'var(--text-muted)', fontSize: '0.9rem' }}>
                      {sub.amount > 0 ? `Rs. ${sub.amount.toLocaleString()}` : '—'}
                    </td>
                    <td style={{ padding: '1rem 1.75rem', fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                      {sub.renewsAt === '—' ? '—' : formatDate(sub.renewsAt)}
                    </td>
                    <td style={{ padding: '1rem 1.75rem', textAlign: 'right' }}>
                      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem' }}>
                        {sub.plan !== 'Executive' && (
                          <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                            onClick={() => handleUpgrade(sub.id)}
                            style={{ padding: '0.375rem 0.875rem', fontSize: '0.75rem', fontWeight: 700, borderRadius: '8px', background: '#E2F0F3', color: '#0C637E', border: 'none', cursor: 'pointer' }}>
                            Upgrade
                          </motion.button>
                        )}
                        {sub.status === 'ACTIVE' && sub.plan !== 'Free' && (
                          <motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                            onClick={() => handleCancelSub(sub.id)}
                            style={{ padding: '0.375rem 0.875rem', fontSize: '0.75rem', fontWeight: 700, borderRadius: '8px', background: '#FEE2E2', color: '#EF4444', border: 'none', cursor: 'pointer' }}>
                            Cancel
                          </motion.button>
                        )}
                      </div>
                    </td>
                  </motion.tr>
                );
              })
            )}
          </tbody>
        </table>

        {/* Footer & Pagination */}
        <div style={{ padding: '1.25rem 2rem', background: 'var(--surface-raised)', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)', fontWeight: 500 }}>
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
                  border: '1px solid var(--border)', background: 'var(--surface)',
                  color: currentPage === 1 ? 'var(--text-muted)' : 'var(--secondary)',
                  cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
                  opacity: currentPage === 1 ? 0.5 : 1,
                  transition: 'all 0.2s ease',
                }}
                onMouseEnter={e => { if (currentPage !== 1) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; }}
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
                      border: isCurrent ? '1px solid var(--primary)' : '1px solid var(--border)',
                      background: isCurrent ? 'var(--primary)' : 'var(--surface)',
                      color: isCurrent ? 'white' : 'var(--secondary)',
                      fontWeight: isCurrent ? 700 : 600,
                      fontSize: '0.82rem', cursor: 'pointer',
                      transition: 'all 0.2s ease',
                    }}
                    onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                    onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.borderColor = 'var(--border)'; }}
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
                  border: '1px solid var(--border)', background: 'var(--surface)',
                  color: currentPage === Math.ceil(filtered.length / itemsPerPage) ? 'var(--text-muted)' : 'var(--secondary)',
                  cursor: currentPage === Math.ceil(filtered.length / itemsPerPage) ? 'not-allowed' : 'pointer',
                  opacity: currentPage === Math.ceil(filtered.length / itemsPerPage) ? 0.5 : 1,
                  transition: 'all 0.2s ease',
                }}
                onMouseEnter={e => { if (currentPage !== Math.ceil(filtered.length / itemsPerPage)) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; }}
              >
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Edit Plan Modal */}
      {editingPlan && (
        <div style={{ position: 'fixed', inset: 0, zIndex: 10000, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(15, 26, 34, 0.6)', backdropFilter: 'blur(4px)' }}>
          <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
            style={{ background: 'var(--surface)', width: '480px', borderRadius: '24px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)' }}>
            <div style={{ padding: '1.5rem 2rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--secondary)' }}>Update {editingPlan.name} Plan</h3>
              <button onClick={() => setEditingPlan(null)} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}>
                <X size={24} />
              </button>
            </div>
            
            <div style={{ padding: '2rem' }}>
              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>Monthly Price (Rs.)</label>
                <input type="number" defaultValue={editingPlan.price} id="plan-price"
                  style={{ width: '100%', padding: '0.875rem 1.25rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface-raised)', fontSize: '1rem', fontWeight: 700, color: 'var(--secondary)' }} />
              </div>

              <div style={{ marginBottom: '2rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.5rem', textTransform: 'uppercase' }}>Plan Features</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  {editingPlan.features.map((f, i) => (
                    <input key={i} type="text" defaultValue={f} className="plan-feature-input"
                      style={{ width: '100%', padding: '0.75rem 1rem', borderRadius: '10px', border: '1px solid var(--border)', fontSize: '0.875rem' }} />
                  ))}
                </div>
              </div>

              <div style={{ display: 'flex', gap: '1rem' }}>
                <button onClick={() => setEditingPlan(null)}
                  style={{ flex: 1, padding: '0.875rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, cursor: 'pointer' }}>
                  Cancel
                </button>
                <button 
                  onClick={() => {
                    const newPrice = parseInt(document.getElementById('plan-price').value);
                    const newFeatures = Array.from(document.querySelectorAll('.plan-feature-input')).map(el => el.value);
                    setPlans(plans.map(p => p.id === editingPlan.id ? { ...p, price: newPrice, features: newFeatures } : p));
                    setEditingPlan(null);
                    showAlert(`${editingPlan.name} plan updated successfully`, 'success');
                  }}
                  style={{ flex: 1, padding: '0.875rem', borderRadius: '12px', border: 'none', background: 'var(--primary)', color: 'white', fontWeight: 700, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem' }}>
                  <Save size={18} /> Save Changes
                </button>
              </div>
            </div>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
};

export default SubscriptionManagement;

import React, { useState, useEffect, useCallback } from 'react';
import { Mail, MessageSquare, Bell, Search, CheckCircle, Clock, XCircle, RefreshCw, Smartphone, ChevronLeft, ChevronRight } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

const STATUS_CONFIG = {
  DELIVERED: { color: '#10b981', bg: '#d1fae5', icon: CheckCircle },
  PENDING:   { color: '#f59e0b', bg: '#fef3c7', icon: Clock },
  FAILED:    { color: '#ef4444', bg: '#fee2e2', icon: XCircle },
};

const TYPE_CONFIG = {
  EMAIL:  { color: 'var(--primary)', bg: '#ebf8ff', icon: Mail },
  PUSH:   { color: '#8b5cf6', bg: '#ede9fe', icon: Bell },
  IN_APP: { color: '#10b981', bg: '#d1fae5', icon: Smartphone },
  SMS:    { color: '#f59e0b', bg: '#fef3c7', icon: MessageSquare },
};

const formatTime = (iso) =>
  new Date(iso).toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });

const CommunicationAudit = () => {
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [comms, setComms] = useState([]);
  const [summary, setSummary] = useState({ total: 0, delivered: 0, failed: 0, pending: 0 });
  const [loading, setLoading] = useState(true);

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const fetchComms = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get('/api/admin/notifications?limit=500');
      if (res.data.success) {
        const { notifications, total, summary: apiSummary } = res.data.data;
        const mapped = notifications.map((n) => ({
          id: n.id,
          type: Array.isArray(n.channels) && n.channels.length > 0
            ? n.channels[0].toUpperCase()
            : 'IN_APP',
          recipient: n.recipientEmail || n.recipient || 'Unknown',
          subject: n.title,
          status: n.status,
          sentAt: n.sentAt,
          channel: (n.type || '').replace(/_/g, ' '),
        }));
        setComms(mapped);
        setSummary({
          total,
          delivered: apiSummary?.delivered ?? 0,
          failed: apiSummary?.failed ?? 0,
          pending: apiSummary?.pending ?? 0,
        });
      }
    } catch (err) {
      console.error('Failed to fetch communication audit:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchComms(); }, [fetchComms]);

  // Reset pagination to page 1 on local filter/search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, typeFilter, statusFilter]);

  const filtered = comms.filter((c) => {
    const matchType = typeFilter === 'ALL' || c.type === typeFilter;
    const matchStatus = statusFilter === 'ALL' || c.status === statusFilter;
    const matchSearch = !search ||
      c.recipient.toLowerCase().includes(search.toLowerCase()) ||
      c.subject.toLowerCase().includes(search.toLowerCase()) ||
      c.channel.toLowerCase().includes(search.toLowerCase());
    return matchType && matchStatus && matchSearch;
  });

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.5 }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.5rem' }}>Communication Audit</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '1.05rem' }}>Full audit trail of every email and push notification sent by the system.</p>
        </div>
        <button
          onClick={fetchComms}
          disabled={loading}
          style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.6rem 1.25rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, fontSize: '0.85rem', cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.6 : 1 }}
        >
          <RefreshCw size={15} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} /> Refresh
        </button>
      </div>

      {/* Summary Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.5rem', marginBottom: '2.5rem' }}>
        {[
          { label: 'Total Sent', value: summary.total, color: 'var(--primary)', bg: '#ebf8ff' },
          { label: 'Delivered', value: summary.delivered, color: '#10b981', bg: '#d1fae5' },
          { label: 'Pending', value: summary.pending, color: '#f59e0b', bg: '#fef3c7' },
          { label: 'Failed', value: summary.failed, color: '#ef4444', bg: '#fee2e2' },
        ].map((card, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.08 }}
            className="card"
            style={{ padding: '1.75rem 2rem', border: '1px solid var(--border)' }}
          >
            <p style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.75rem' }}>{card.label}</p>
            <p style={{ fontSize: '1.75rem', fontWeight: 700, color: card.color }}>
              {loading ? '…' : card.value}
            </p>
          </motion.div>
        ))}
      </div>

      {/* Filters */}
      <div className="card" style={{ padding: '1.25rem 2rem', border: '1px solid var(--border)', marginBottom: '1.5rem', display: 'flex', gap: '2rem', alignItems: 'center', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', gap: '0.625rem' }}>
          {['ALL', 'EMAIL', 'PUSH', 'IN_APP'].map((t) => {
            const cfg = TYPE_CONFIG[t];
            const active = typeFilter === t;
            return (
              <button
                key={t}
                onClick={() => setTypeFilter(t)}
                style={{ padding: '0.5rem 1.25rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.8rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg || 'var(--secondary)') : 'white', color: active ? (cfg?.color || 'white') : 'var(--text-muted)', cursor: 'pointer' }}
              >
                {t}
              </button>
            );
          })}
        </div>
        <div style={{ display: 'flex', gap: '0.625rem' }}>
          {['ALL', 'DELIVERED', 'PENDING', 'FAILED'].map((s) => {
            const cfg = STATUS_CONFIG[s];
            const active = statusFilter === s;
            return (
              <button
                key={s}
                onClick={() => setStatusFilter(s)}
                style={{ padding: '0.5rem 1.25rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.8rem', border: active ? 'none' : '1px solid var(--border)', background: active ? (cfg?.bg || '#f1f5f9') : 'white', color: active ? (cfg?.color || 'var(--secondary)') : 'var(--text-muted)', cursor: 'pointer' }}
              >
                {s}
              </button>
            );
          })}
        </div>
        <div style={{ marginLeft: 'auto', position: 'relative' }}>
          <Search size={16} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            type="text"
            placeholder="Search communications..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ padding: '0.75rem 1rem 0.75rem 2.75rem', width: '260px', fontSize: '0.875rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface-raised)', fontFamily: 'var(--font-sans)', outline: 'none' }}
          />
        </div>
      </div>

      {/* Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border)' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ background: 'var(--surface-raised)', borderBottom: '1px solid var(--border)' }}>
              {['Channel', 'Type', 'Recipient', 'Subject', 'Status', 'Sent At'].map((h) => (
                <th key={h} style={{ padding: '1.25rem 1.75rem', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <RefreshCw size={24} style={{ animation: 'spin 1s linear infinite', display: 'block', margin: '0 auto 0.75rem', opacity: 0.4 }} />
                  Loading communications...
                </td>
              </tr>
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                  No communications match your filters.
                </td>
              </tr>
            ) : (
              filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((comm, idx) => {
                const typeCfg = TYPE_CONFIG[comm.type] || TYPE_CONFIG.IN_APP;
                const statusCfg = STATUS_CONFIG[comm.status] || STATUS_CONFIG.DELIVERED;
                const TypeIcon = typeCfg.icon;
                const StatusIcon = statusCfg.icon;
                return (
                  <motion.tr
                    key={comm.id}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: idx * 0.02 }}
                    style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface)' }}
                  >
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 700, background: 'var(--surface-raised)', color: 'var(--primary)', padding: '0.35rem 0.75rem', borderRadius: '6px' }}>{comm.channel || '—'}</span>
                    </td>
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: typeCfg.color }}>
                        <TypeIcon size={16} />
                        <span style={{ fontSize: '0.85rem', fontWeight: 700 }}>{comm.type}</span>
                      </div>
                    </td>
                    <td style={{ padding: '1rem 1.75rem', fontSize: '0.9rem', color: 'var(--secondary)', fontWeight: 600 }}>{comm.recipient}</td>
                    <td style={{ padding: '1rem 1.75rem', fontSize: '0.875rem', color: 'var(--text-muted)', maxWidth: '250px' }}>
                      <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{comm.subject}</div>
                    </td>
                    <td style={{ padding: '1rem 1.75rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: statusCfg.color }}>
                        <StatusIcon size={15} />
                        <span style={{ fontSize: '0.8rem', fontWeight: 700 }}>{comm.status}</span>
                      </div>
                    </td>
                    <td style={{ padding: '1rem 1.75rem', fontSize: '0.8rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{formatTime(comm.sentAt)}</td>
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
    </motion.div>
  );
};

export default CommunicationAudit;

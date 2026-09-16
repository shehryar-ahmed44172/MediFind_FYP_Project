import React, { useState, useEffect, useCallback } from 'react';
import { Mail, MessageSquare, Bell, Search, CheckCircle, Clock, XCircle, Smartphone, Inbox } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, FilterPill, SearchInput, ErrorBanner } from '../../components/ui';
import { thStyle, paginate } from '../../components/uiStyles';

const STATUS_CONFIG = {
  DELIVERED: { color: 'var(--success-fg)', pill: 'var(--success-fg)', icon: CheckCircle, label: 'Delivered' },
  PENDING:   { color: 'var(--warning-fg)', pill: 'var(--warning-fg)', icon: Clock,       label: 'Pending' },
  FAILED:    { color: 'var(--error-fg)', pill: 'var(--error-fg)', icon: XCircle,     label: 'Failed' },
};

const TYPE_CONFIG = {
  EMAIL:  { color: 'var(--admin-accent)', icon: Mail,          label: 'Email' },
  PUSH:   { color: 'var(--primary)',             icon: Bell,          label: 'Push' },
  IN_APP: { color: 'var(--success-fg)',             icon: Smartphone,    label: 'In-app' },
  SMS:    { color: 'var(--warning-fg)',             icon: MessageSquare, label: 'SMS' },
};

const PAGE_SIZE = 15;

const formatTime = (iso) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};

const CommunicationAudit = () => {
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [comms, setComms] = useState([]);
  const [summary, setSummary] = useState({ total: 0, delivered: 0, failed: 0, pending: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);

  const loadComms = useCallback(() => (
    api.get('/api/admin/notifications?limit=500')
      .then(res => {
        if (!res.data?.success) return;
        const { notifications = [], total = 0, summary: apiSummary } = res.data.data || {};
        setComms(notifications.map((n) => ({
          id: n.id,
          type: Array.isArray(n.channels) && n.channels.length > 0 ? String(n.channels[0]).toUpperCase() : 'IN_APP',
          recipient: n.recipientEmail || n.recipient || 'Unknown',
          recipientName: n.recipient,
          subject: n.title || '—',
          status: n.status,
          failureReason: n.failureReason,
          sentAt: n.sentAt,
          category: (n.type || '').replace(/_/g, ' '),
        })));
        setSummary({
          total,
          delivered: apiSummary?.delivered ?? 0,
          failed: apiSummary?.failed ?? 0,
          pending: apiSummary?.pending ?? 0,
        });
        setError('');
      })
      .catch(err => setError(errorMessage(err, 'Failed to load the communication audit.')))
      .finally(() => setLoading(false))
  ), []);

  useEffect(() => { loadComms(); }, [loadComms]);

  const refresh = () => { setLoading(true); loadComms(); };

  const q = search.trim().toLowerCase();
  const filtered = comms.filter((c) => {
    const matchType = typeFilter === 'ALL' || c.type === typeFilter;
    const matchStatus = statusFilter === 'ALL' || c.status === statusFilter;
    const matchSearch = !q ||
      c.recipient.toLowerCase().includes(q) ||
      String(c.recipientName || '').toLowerCase().includes(q) ||
      c.subject.toLowerCase().includes(q) ||
      c.category.toLowerCase().includes(q);
    return matchType && matchStatus && matchSearch;
  });
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);

  const cards = [
    { label: 'Total Sent', value: summary.total,     color: 'var(--admin-accent)' },
    { label: 'Delivered',  value: summary.delivered, color: 'var(--success-fg)' },
    { label: 'Pending',    value: summary.pending,   color: 'var(--warning-fg)' },
    { label: 'Failed',     value: summary.failed,    color: 'var(--error-fg)' },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.3 }}
    >
      <PageHeader
        title="Communication Audit"
        subtitle="Every email, push and in-app notification the system has sent (latest 500)."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      {/* Summary Cards */}
      <div className="mf-grid-stats" style={{ marginBottom: '20px' }}>
        {cards.map((card) => (
          <div key={card.label} style={{ background: 'var(--surface)', borderRadius: '14px', border: '1px solid var(--admin-border)', padding: '16px 20px' }}>
            <p style={{ fontSize: '0.76rem', fontWeight: 700, color: 'var(--admin-text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '6px' }}>{card.label}</p>
            <p style={{ fontSize: '1.75rem', fontWeight: 800, color: card.color, lineHeight: 1.1 }}>
              {loading ? '—' : Number(card.value).toLocaleString()}
            </p>
          </div>
        ))}
      </div>

      <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', overflow: 'hidden' }}>
        {/* Filters */}
        <div style={{ padding: '14px 20px', borderBottom: '1px solid var(--admin-border)', display: 'flex', gap: '12px 20px', alignItems: 'center', flexWrap: 'wrap' }}>
          <div role="group" aria-label="Filter by channel" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
            {['ALL', 'EMAIL', 'PUSH', 'IN_APP'].map((t) => (
              <FilterPill key={t} active={typeFilter === t} onClick={() => { setTypeFilter(t); setPage(1); }}>
                {t === 'ALL' ? 'All channels' : TYPE_CONFIG[t].label}
              </FilterPill>
            ))}
          </div>
          <div role="group" aria-label="Filter by status" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
            {['ALL', 'DELIVERED', 'PENDING', 'FAILED'].map((s) => (
              <FilterPill key={s} active={statusFilter === s} color={STATUS_CONFIG[s]?.pill} onClick={() => { setStatusFilter(s); setPage(1); }}>
                {s === 'ALL' ? 'All statuses' : STATUS_CONFIG[s].label}
              </FilterPill>
            ))}
          </div>
          <div style={{ marginLeft: 'auto' }}>
            <SearchInput icon={Search} width={260} value={search} onChange={(v) => { setSearch(v); setPage(1); }} placeholder="Search recipient or subject…" />
          </div>
        </div>

        {/* Table */}
        <div className="mf-table-scroll">
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '860px' }}>
            <thead>
              <tr>
                {['Category', 'Channel', 'Recipient', 'Subject', 'Status', 'Sent At'].map((h) => (
                  <th key={h} scope="col" style={thStyle}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <TableSkeletonRows rows={6} cols={6} />
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <EmptyState
                      icon={Inbox}
                      title={comms.length === 0 ? 'No communications sent yet' : 'No communications match your filters'}
                      message={comms.length === 0 ? undefined : 'Try another channel, status or search term.'}
                    />
                  </td>
                </tr>
              ) : (
                rows.map((comm) => {
                  const typeCfg = TYPE_CONFIG[comm.type] || TYPE_CONFIG.IN_APP;
                  const statusCfg = STATUS_CONFIG[comm.status] || { color: 'var(--admin-text-muted)', icon: Clock, label: comm.status || 'Unknown' };
                  const TypeIcon = typeCfg.icon;
                  const StatusIcon = statusCfg.icon;
                  return (
                    <tr key={comm.id} className="mf-table-row" style={{ borderBottom: '1px solid var(--admin-border)' }}>
                      <td style={{ padding: '12px 20px' }}>
                        <span style={{ fontSize: '0.74rem', fontWeight: 700, background: 'var(--tint-teal)', color: 'var(--admin-accent)', padding: '3px 8px', borderRadius: '6px', whiteSpace: 'nowrap' }}>{comm.category || '—'}</span>
                      </td>
                      <td style={{ padding: '12px 20px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: typeCfg.color }}>
                          <TypeIcon size={15} />
                          <span style={{ fontSize: '0.84rem', fontWeight: 700 }}>{typeCfg.label}</span>
                        </div>
                      </td>
                      <td style={{ padding: '12px 20px', fontSize: '0.86rem', color: 'var(--admin-text-main)', fontWeight: 600 }}>
                        {comm.recipientName && comm.recipientName !== comm.recipient && (
                          <div>{comm.recipientName}</div>
                        )}
                        <div style={{ fontSize: comm.recipientName && comm.recipientName !== comm.recipient ? '0.76rem' : undefined, color: comm.recipientName && comm.recipientName !== comm.recipient ? 'var(--admin-text-muted)' : undefined, fontWeight: comm.recipientName && comm.recipientName !== comm.recipient ? 500 : undefined }}>{comm.recipient}</div>
                      </td>
                      <td style={{ padding: '12px 20px', fontSize: '0.86rem', color: 'var(--admin-text-sub)', maxWidth: '280px' }}>
                        <div title={comm.subject} style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{comm.subject}</div>
                      </td>
                      <td style={{ padding: '12px 20px' }}>
                        <div title={comm.failureReason || undefined} style={{ display: 'flex', alignItems: 'center', gap: '6px', color: statusCfg.color }}>
                          <StatusIcon size={15} />
                          <span style={{ fontSize: '0.8rem', fontWeight: 700 }}>{statusCfg.label}</span>
                        </div>
                      </td>
                      <td style={{ padding: '12px 20px', fontSize: '0.8rem', color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>{formatTime(comm.sentAt)}</td>
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

export default CommunicationAudit;

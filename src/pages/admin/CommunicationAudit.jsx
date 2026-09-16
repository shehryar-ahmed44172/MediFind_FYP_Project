import React, { useState, useEffect, useCallback } from 'react';
import { Mail, MessageSquare, Bell, Smartphone, Inbox } from 'lucide-react';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SearchInput, ErrorBanner,
  Panel, Toolbar, SegmentedControl, DataTable, StatusBadge, StatCard, Button,
} from '../../components/ui';
import { paginate, toneFor } from '../../components/uiStyles';

const STATUS_LABEL = { DELIVERED: 'Delivered', PENDING: 'Pending', FAILED: 'Failed' };

const TYPE_CONFIG = {
  EMAIL:  { icon: Mail,          label: 'Email' },
  PUSH:   { icon: Bell,          label: 'Push' },
  IN_APP: { icon: Smartphone,    label: 'In-app' },
  SMS:    { icon: MessageSquare, label: 'SMS' },
};

const PAGE_SIZE = 15;
const COLS = 6;

const formatTime = (iso) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};

const truncate = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

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
  const hasFilters = !!q || typeFilter !== 'ALL' || statusFilter !== 'ALL';
  const clearFilters = () => { setSearch(''); setTypeFilter('ALL'); setStatusFilter('ALL'); setPage(1); };

  const cards = [
    { label: 'Total sent', value: summary.total },
    { label: 'Delivered',  value: summary.delivered },
    { label: 'Pending',    value: summary.pending },
    { label: 'Failed',     value: summary.failed },
  ];

  return (
    <div className="mf-stack">
      <PageHeader
        title="Communication Audit"
        description="Every email, push and in-app notification the system has sent (latest 500)."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      {error && <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>}

      <div className="mf-grid-stats">
        {cards.map((card) => (
          <StatCard key={card.label} label={card.label} value={Number(card.value)} loading={loading} />
        ))}
      </div>

      <Panel>
        <Toolbar right={<SearchInput width={260} value={search} onChange={(v) => { setSearch(v); setPage(1); }} placeholder="Search recipient or subject…" />}>
          <SegmentedControl
            ariaLabel="Filter by channel"
            value={typeFilter}
            onChange={(v) => { setTypeFilter(v); setPage(1); }}
            options={['ALL', 'EMAIL', 'PUSH', 'IN_APP'].map(t => ({ value: t, label: t === 'ALL' ? 'All channels' : TYPE_CONFIG[t].label }))}
          />
          <SegmentedControl
            ariaLabel="Filter by status"
            value={statusFilter}
            onChange={(v) => { setStatusFilter(v); setPage(1); }}
            options={['ALL', 'DELIVERED', 'PENDING', 'FAILED'].map(s => ({ value: s, label: s === 'ALL' ? 'All statuses' : STATUS_LABEL[s] }))}
          />
        </Toolbar>

        <DataTable minWidth={900} maxHeight="calc(100vh - 380px)">
          <thead>
            <tr>
              {['Category', 'Channel', 'Recipient', 'Subject', 'Status', 'Sent at'].map((h) => (
                <th key={h} scope="col">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={8} cols={COLS} />
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={Inbox}
                    title={comms.length === 0 ? 'No communications sent yet' : 'No communications match your filters'}
                    message={comms.length === 0 ? undefined : 'Try another channel, status or search term.'}
                    action={comms.length > 0 && hasFilters && <Button size="sm" onClick={clearFilters}>Clear filters</Button>}
                  />
                </td>
              </tr>
            ) : (
              rows.map((comm) => {
                const typeCfg = TYPE_CONFIG[comm.type] || TYPE_CONFIG.IN_APP;
                const TypeIcon = typeCfg.icon;
                const hasName = comm.recipientName && comm.recipientName !== comm.recipient;
                return (
                  <tr key={comm.id} className="mf-table-row">
                    <td style={{ whiteSpace: 'nowrap' }}>
                      {comm.category
                        ? <StatusBadge tone="neutral" dot={false}>{comm.category.charAt(0) + comm.category.slice(1).toLowerCase()}</StatusBadge>
                        : '—'}
                    </td>
                    <td style={{ whiteSpace: 'nowrap' }}>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', color: 'var(--admin-text-sub)' }}>
                        <TypeIcon size={14} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />
                        {typeCfg.label}
                      </span>
                    </td>
                    <td style={{ maxWidth: '240px' }}>
                      {hasName && <div style={{ ...truncate, color: 'var(--text-main)', fontWeight: 500 }}>{comm.recipientName}</div>}
                      <div style={{ ...truncate, ...(hasName ? { fontSize: '12.5px', color: 'var(--text-muted)' } : { color: 'var(--text-main)' }) }} title={comm.recipient}>
                        {comm.recipient}
                      </div>
                    </td>
                    <td style={{ maxWidth: '300px' }}>
                      <div title={comm.subject} style={truncate}>{comm.subject}</div>
                    </td>
                    <td style={{ whiteSpace: 'nowrap' }}>
                      <StatusBadge tone={toneFor(comm.status)} title={comm.failureReason || undefined}>
                        {STATUS_LABEL[comm.status] || comm.status || 'Unknown'}
                      </StatusBadge>
                    </td>
                    <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>{formatTime(comm.sentAt)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </DataTable>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} />
      </Panel>
    </div>
  );
};

export default CommunicationAudit;

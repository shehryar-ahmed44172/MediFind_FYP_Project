import React, { useState, useEffect, useCallback, useRef } from 'react';
import { History, Search, CheckCircle, AlertCircle, Info, XCircle } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { PageHeader, RefreshButton, EmptyState, ErrorBanner, FilterPill, SearchInput, Skeleton, Pagination } from '../../components/ui';
import { paginate } from '../../components/uiStyles';

// Backend derives level from the action name: DELETE/FAIL → ERROR, UPDATE → WARNING, else INFO
const LEVEL_CONFIG = {
  INFO:    { color: 'var(--admin-accent)', bg: 'var(--tint-teal)',  icon: Info,        pill: 'var(--primary-light)' },
  WARNING: { color: 'var(--warning-fg)',             bg: 'var(--tint-amber)', icon: AlertCircle, pill: 'var(--warning-fg)' },
  ERROR:   { color: 'var(--error-fg)',             bg: 'var(--tint-red)',   icon: XCircle,     pill: 'var(--error-fg)' },
  SUCCESS: { color: 'var(--success-fg)',             bg: 'var(--tint-green)', icon: CheckCircle, pill: 'var(--success-fg)' },
};
const LEVELS = ['ALL', 'INFO', 'WARNING', 'ERROR'];
const SEARCH_DEBOUNCE_MS = 350;
const PAGE_SIZE = 25;

const formatTime = (iso) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};

const SystemLogs = () => {
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const requestId = useRef(0);

  // Debounce the server-side search so we don't fire a request per keystroke
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search.trim()), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(t);
  }, [search]);

  const loadLogs = useCallback((term) => {
    const id = ++requestId.current;
    return api.get('/api/admin/logs', { params: { limit: 200, search: term || undefined } })
      .then(res => {
        if (id !== requestId.current) return;
        if (res.data?.success) {
          setLogs(res.data.data.map(log => ({
            id:        log.id,
            level:     log.level,
            action:    log.action || '—',
            detail:    [log.entity, log.entityId && `#${log.entityId}`].filter(Boolean).join(' '),
            user:      log.user || 'System',
            ipAddress: log.ipAddress,
            timestamp: log.timestamp,
          })));
          setError('');
        }
      })
      .catch(err => { if (id === requestId.current) setError(errorMessage(err, 'Failed to load system logs.')); })
      .finally(() => { if (id === requestId.current) setLoading(false); });
  }, []);

  useEffect(() => { loadLogs(debouncedSearch); }, [debouncedSearch, loadLogs]);

  const refresh = () => { setLoading(true); loadLogs(debouncedSearch); };

  const onSearchChange = (value) => {
    setSearch(value);
    setPage(1);
    if (value.trim() !== debouncedSearch) setLoading(true);
  };

  const filtered = logs.filter(log => filter === 'ALL' || log.level === filter);
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.3 }}
    >
      <PageHeader
        title="System Logs"
        subtitle="Audit trail of system and administrator actions (latest 200 entries)."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', overflow: 'hidden' }}>
        {/* Filters */}
        <div style={{ padding: '14px 20px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <div role="group" aria-label="Filter by level" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
            {LEVELS.map((lvl) => (
              <FilterPill key={lvl} active={filter === lvl} color={LEVEL_CONFIG[lvl]?.pill} onClick={() => { setFilter(lvl); setPage(1); }}>
                {lvl === 'ALL' ? 'All levels' : lvl.charAt(0) + lvl.slice(1).toLowerCase()}
                {lvl !== 'ALL' && !loading && ` (${logs.filter(l => l.level === lvl).length})`}
              </FilterPill>
            ))}
          </div>
          <SearchInput icon={Search} width={300} value={search} onChange={onSearchChange} placeholder="Search action, entity or ID…" />
        </div>

        {/* Log entries */}
        <div aria-busy={loading} aria-live="polite">
          {loading ? (
            Array.from({ length: 6 }, (_, i) => (
              <div key={i} style={{ display: 'flex', gap: '16px', padding: '16px 20px', borderBottom: '1px solid var(--admin-border)' }}>
                <Skeleton h={38} w="38px" br={10} />
                <div style={{ flex: 1 }}>
                  <Skeleton h={13} w="35%" mb={8} />
                  <Skeleton h={11} w="55%" />
                </div>
              </div>
            ))
          ) : filtered.length === 0 ? (
            <EmptyState
              icon={History}
              title={search || filter !== 'ALL' ? 'No logs match your filters' : 'No log entries yet'}
              message={search ? `Nothing found for “${search}”.` : undefined}
            />
          ) : (
            rows.map((log, idx) => {
              const cfg = LEVEL_CONFIG[log.level] || LEVEL_CONFIG.INFO;
              const Icon = cfg.icon;
              return (
                <div
                  key={log.id}
                  className="mf-table-row"
                  style={{
                    display: 'flex', alignItems: 'flex-start', gap: '14px',
                    padding: '14px 20px', borderBottom: idx < rows.length - 1 ? '1px solid var(--admin-border)' : 'none',
                  }}
                >
                  <div aria-label={log.level} style={{ padding: '9px', borderRadius: '10px', background: cfg.bg, color: cfg.color, flexShrink: 0, display: 'flex' }}>
                    <Icon size={18} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: '12px', flexWrap: 'wrap', marginBottom: '3px' }}>
                      <span style={{ fontWeight: 700, color: 'var(--admin-text-main)', fontSize: '0.92rem', wordBreak: 'break-word' }}>{log.action}</span>
                      <time dateTime={log.timestamp} style={{ fontSize: '0.76rem', color: 'var(--admin-text-muted)', whiteSpace: 'nowrap' }}>{formatTime(log.timestamp)}</time>
                    </div>
                    {log.detail && <p style={{ fontSize: '0.84rem', color: 'var(--admin-text-sub)', marginBottom: '6px', wordBreak: 'break-all' }}>{log.detail}</p>}
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center' }}>
                      <span style={{ fontSize: '0.74rem', fontWeight: 600, color: cfg.color, background: cfg.bg, padding: '2px 8px', borderRadius: '6px' }}>{log.user}</span>
                      {log.ipAddress && log.ipAddress !== '—' && (
                        <span style={{ fontSize: '0.72rem', color: 'var(--admin-text-muted)', fontFamily: 'monospace' }}>{log.ipAddress}</span>
                      )}
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} />
      </div>
    </motion.div>
  );
};

export default SystemLogs;

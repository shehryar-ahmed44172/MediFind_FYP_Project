import React, { useState, useEffect, useCallback, useRef } from 'react';
import { History } from 'lucide-react';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import {
  PageHeader, RefreshButton, EmptyState, ErrorBanner, SearchInput, Pagination, Panel, Toolbar,
  SegmentedControl, DataTable, TableSkeletonRows, StatusBadge, Button,
} from '../../components/ui';
import { paginate, toneFor, humanize } from '../../components/uiStyles';

// Backend derives level from the action name: DELETE/FAIL → ERROR, UPDATE → WARNING, else INFO
const LEVELS = ['ALL', 'INFO', 'WARNING', 'ERROR'];
const SEARCH_DEBOUNCE_MS = 350;
const PAGE_SIZE = 25;
const COLS = 6;

const formatTime = (iso) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};

const truncate = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

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
  const hasFilters = !!search || filter !== 'ALL';

  const levelOptions = LEVELS.map(lvl => ({
    value: lvl,
    label: lvl === 'ALL' ? 'All levels' : humanize(lvl),
    count: lvl !== 'ALL' && !loading ? logs.filter(l => l.level === lvl).length : undefined,
  }));

  const clearFilters = () => { onSearchChange(''); setFilter('ALL'); };

  return (
    <div className="mf-stack">
      <PageHeader
        title="System Logs"
        description="Audit trail of system and administrator actions (latest 200 entries)."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      {error && <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>}

      <Panel>
        <Toolbar right={<SearchInput width={300} value={search} onChange={onSearchChange} placeholder="Search action, entity or ID…" />}>
          <SegmentedControl
            ariaLabel="Filter by level"
            options={levelOptions}
            value={filter}
            onChange={(v) => { setFilter(v); setPage(1); }}
          />
        </Toolbar>

        <div aria-busy={loading} aria-live="polite">
          <DataTable minWidth={880} maxHeight="calc(100vh - 300px)">
            <thead>
              <tr>
                <th scope="col" style={{ width: '170px' }}>Timestamp</th>
                <th scope="col" style={{ width: '110px' }}>Level</th>
                <th scope="col">Actor</th>
                <th scope="col">Action</th>
                <th scope="col">Details</th>
                <th scope="col">IP address</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <TableSkeletonRows rows={8} cols={COLS} />
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={COLS}>
                    <EmptyState
                      icon={History}
                      title={hasFilters ? 'No logs match your filters' : 'No log entries yet'}
                      message={search ? `Nothing found for “${search}”.` : undefined}
                      action={hasFilters && <Button size="sm" onClick={clearFilters}>Clear filters</Button>}
                    />
                  </td>
                </tr>
              ) : (
                rows.map(log => (
                  <tr key={log.id} className="mf-table-row">
                    <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>
                      <time dateTime={log.timestamp}>{formatTime(log.timestamp)}</time>
                    </td>
                    <td><StatusBadge tone={toneFor(log.level)}>{humanize(log.level)}</StatusBadge></td>
                    <td style={{ ...truncate, maxWidth: '180px', color: 'var(--text-main)', fontWeight: 500 }} title={log.user}>{log.user}</td>
                    <td style={{ ...truncate, maxWidth: '240px', color: 'var(--text-main)' }} title={log.action}>{log.action}</td>
                    <td style={{ ...truncate, maxWidth: '280px' }} title={log.detail || undefined}>{log.detail || '—'}</td>
                    <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>
                      {log.ipAddress && log.ipAddress !== '—' ? log.ipAddress : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </DataTable>
        </div>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} noun="entries" />
      </Panel>
    </div>
  );
};

export default SystemLogs;

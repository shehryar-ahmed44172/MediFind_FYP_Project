import React, { useState, useEffect, useCallback } from 'react';
import { Phone, Video, PhoneOff } from 'lucide-react';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SearchInput, ErrorBanner,
  Panel, Toolbar, SegmentedControl, DataTable, StatusBadge, StatCard, Button, Avatar, Notice,
} from '../../components/ui';
import { paginate, humanize } from '../../components/uiStyles';

/*
 * Call records between responders and patients / caregivers during emergencies.
 * Metadata only (who, when, how long, outcome) — call audio and video are not recorded.
 * Patient ↔ caregiver (family) calls are private and never shown here.
 */
const OUTCOME = {
  COMPLETED:     { label: 'Completed',     tone: 'success' },
  MISSED:        { label: 'Missed',        tone: 'warning' },
  DECLINED:      { label: 'Declined',      tone: 'danger' },
  CANCELLED:     { label: 'Cancelled',     tone: 'neutral' },
  NOT_CONNECTED: { label: 'Not connected', tone: 'neutral' },
};
const END_REASON = {
  HANGUP: 'Hung up',
  EMERGENCY_ENDED: 'Emergency ended',
  RESPONDER_RELEASED: 'Responder released',
  CONNECTION_LOST: 'Connection lost',
  NO_ANSWER: 'No answer',
  DECLINED: 'Declined',
  CANCELLED: 'Caller cancelled',
  CALLER_OFFLINE: 'Caller went offline',
};

const PAGE_SIZE = 15;
const COLS = 7;

const formatTime = (iso) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};
const formatDuration = (s) => {
  if (!s) return '—';
  const m = Math.floor(s / 60);
  return m > 0 ? `${m}m ${String(s % 60).padStart(2, '0')}s` : `${s}s`;
};
const truncate = { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' };

function Person({ person, sub }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', minWidth: 0 }}>
      <Avatar name={person.fullName} size={26} />
      <span style={{ minWidth: 0 }}>
        <span style={{ ...truncate, display: 'block', color: 'var(--text-main)', fontWeight: 500 }}>{person.fullName}</span>
        <span style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)' }}>{sub}</span>
      </span>
    </span>
  );
}

const CallRecords = () => {
  const [calls, setCalls] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState('ALL');
  const [outcome, setOutcome] = useState('ALL');
  const [page, setPage] = useState(1);

  const load = useCallback(() => (
    api.get('/api/admin/calls?limit=100')
      .then(res => {
        if (!res.data?.success) return;
        setCalls(res.data.data?.calls ?? []);
        setSummary(res.data.data?.summary ?? null);
        setError('');
      })
      .catch(err => setError(errorMessage(err, 'Failed to load call records.')))
      .finally(() => setLoading(false))
  ), []);

  useEffect(() => { load(); }, [load]);
  const refresh = () => { setLoading(true); load(); };

  const q = search.trim().toLowerCase();
  const filtered = calls.filter(c =>
    (kind === 'ALL' || c.kind === kind) &&
    (outcome === 'ALL' || c.outcome === outcome || (outcome === 'MISSED' && c.outcome === 'DECLINED')) &&
    (!q || [c.responder.fullName, c.party.fullName, c.emergency?.type].some(x => String(x || '').toLowerCase().includes(q))));
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);
  const hasFilters = !!q || kind !== 'ALL' || outcome !== 'ALL';
  const clearFilters = () => { setSearch(''); setKind('ALL'); setOutcome('ALL'); setPage(1); };

  const cards = [
    { label: 'Emergency calls', value: summary?.total ?? 0, hint: `${summary?.withPatients ?? 0} with patients · ${summary?.withCaregivers ?? 0} with caregivers` },
    { label: 'Connected', value: summary?.completed ?? 0 },
    { label: 'Missed / declined', value: summary?.missedOrDeclined ?? 0 },
    { label: 'Total talk time', value: formatDuration(summary?.talkSeconds ?? 0), format: false },
  ];

  return (
    <div className="mf-stack">
      <PageHeader
        title="Call Records"
        description="Voice and video calls between responders and patients or caregivers during emergencies."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      {error && <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>}

      <Notice tone="info">
        Records show who called whom, when, for how long and how the call ended. Call audio and video are not recorded,
        and private patient ↔ caregiver calls are never listed.
      </Notice>

      <div className="mf-grid-stats">
        {cards.map(card => (
          <StatCard key={card.label} label={card.label} value={card.value} hint={card.hint} format={card.format !== false} loading={loading} />
        ))}
      </div>

      <Panel>
        <Toolbar right={<SearchInput width={260} value={search} onChange={v => { setSearch(v); setPage(1); }} placeholder="Search name or emergency…" />}>
          <SegmentedControl
            ariaLabel="Filter by who was called"
            value={kind}
            onChange={v => { setKind(v); setPage(1); }}
            options={[{ value: 'ALL', label: 'All calls' }, { value: 'PATIENT', label: 'Responder ↔ patient' }, { value: 'CAREGIVER', label: 'Responder ↔ caregiver' }]}
          />
          <SegmentedControl
            ariaLabel="Filter by outcome"
            value={outcome}
            onChange={v => { setOutcome(v); setPage(1); }}
            options={[{ value: 'ALL', label: 'All outcomes' }, { value: 'COMPLETED', label: 'Connected' }, { value: 'MISSED', label: 'Missed / declined' }]}
          />
        </Toolbar>

        <DataTable minWidth={980} maxHeight="calc(100vh - 430px)">
          <thead>
            <tr>
              {['Call', 'Responder', 'With', 'Emergency', 'Outcome', 'Duration', 'Started'].map(h => <th key={h} scope="col">{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={8} cols={COLS} />
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={PhoneOff}
                    title={calls.length === 0 ? 'No emergency calls yet' : 'No calls match your filters'}
                    message={calls.length === 0 ? 'Calls between responders and patients or caregivers will appear here.' : 'Try another filter or search term.'}
                    action={calls.length > 0 && hasFilters && <Button size="sm" onClick={clearFilters}>Clear filters</Button>}
                  />
                </td>
              </tr>
            ) : rows.map(c => {
              const MediaIcon = c.media === 'video' ? Video : Phone;
              const out = OUTCOME[c.outcome] ?? OUTCOME.NOT_CONNECTED;
              const reason = END_REASON[c.endReason] ?? humanize(c.endReason);
              return (
                <tr key={c.id} className="mf-table-row">
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
                      <span aria-hidden="true" style={{ width: 30, height: 30, borderRadius: 8, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--ui-accent-tint)', color: 'var(--ui-accent)' }}>
                        <MediaIcon size={15} />
                      </span>
                      <span>
                        <span style={{ display: 'block', color: 'var(--text-main)', fontWeight: 500 }}>{c.media === 'video' ? 'Video call' : 'Voice call'}</span>
                        <span style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)' }}>
                          {c.calledBy === 'RESPONDER' ? 'Responder called' : `${humanize(c.calledBy)} called`}
                        </span>
                      </span>
                    </span>
                  </td>
                  <td style={{ maxWidth: 200 }}><Person person={c.responder} sub="Responder" /></td>
                  <td style={{ maxWidth: 200 }}><Person person={c.party} sub={c.kind === 'CAREGIVER' ? 'Caregiver' : 'Patient'} /></td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    {c.emergency ? (
                      <>
                        <span style={{ display: 'block', color: 'var(--text-main)' }}>{humanize(c.emergency.type)}</span>
                        <span style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)' }}>{humanize(c.emergency.status)}</span>
                      </>
                    ) : '—'}
                  </td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <StatusBadge tone={out.tone} title={reason}>{out.label}</StatusBadge>
                    {reason && reason !== '—' && <span style={{ display: 'block', fontSize: '12px', color: 'var(--text-muted)', marginTop: 4 }}>{reason}</span>}
                  </td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap' }}>{formatDuration(c.durationSeconds)}</td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>{formatTime(c.startedAt)}</td>
                </tr>
              );
            })}
          </tbody>
        </DataTable>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} />
      </Panel>
    </div>
  );
};

export default CallRecords;

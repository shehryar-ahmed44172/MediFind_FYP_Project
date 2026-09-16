import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Bell, CheckCheck, AlertTriangle, UserCheck, Info,
  ExternalLink, ChevronRight, MailOpen, EyeOff, ArrowLeft,
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useAlert } from '../../context/hooks';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { acquireSocket, releaseSocket } from '../../services/socket';
import {
  PageHeader, RefreshButton, Button, EmptyState, ErrorBanner, Skeleton, Card, SearchInput,
  SegmentedControl, StatusBadge, DetailItem,
} from '../../components/ui';

/*
 * Admin Inbox — the signed-in admin's notification history
 * (GET /api/notifications/history) plus alerts pushed live over the admin socket.
 */

const FILTERS = [
  { key: 'ALL',    label: 'All' },
  { key: 'UNREAD', label: 'Unread' },
  { key: 'SOS',    label: 'SOS & Emergencies' },
  { key: 'SYSTEM', label: 'System' },
];

const typeOf = (n) => String(n?.type || '');
const isSos = (n) => /SOS|EMERGENCY|ESCALATION/.test(typeOf(n));
const isRegistration = (n) => /REGISTRATION|DOCUMENT|VERIFICATION/.test(typeOf(n));
const bodyOf = (n) => n?.body ?? n?.message ?? '';
const dateOf = (n) => n?.createdAt || n?.timestamp;

const fmtTime = (iso, opts) => {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '' : d.toLocaleString([], opts);
};

const displayValue = (val) => {
  if (val == null) return '—';
  if (typeof val === 'object') return JSON.stringify(val);
  return String(val);
};

// Small neutral type glyph; red is kept for SOS / emergencies only
const TypeIcon = ({ n, size = 15 }) => {
  if (isSos(n)) return <AlertTriangle size={size} aria-hidden="true" style={{ color: 'var(--error-fg)' }} />;
  if (isRegistration(n)) return <UserCheck size={size} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />;
  if (typeOf(n).includes('SYSTEM')) return <CheckCheck size={size} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />;
  return <Info size={size} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />;
};

// Page-scoped layout: list (fixed) + reading pane; stacks below 1024px
const INBOX_CSS = `
.mf-inbox-grid { display: grid; grid-template-columns: minmax(300px, 380px) minmax(0, 1fr); gap: 16px; min-height: 0; }
.mf-inbox-list-btn { display: block; width: 100%; text-align: left; font-family: inherit; padding: 10px 16px 10px 26px;
  border: none; border-bottom: 1px solid var(--border); background: transparent; cursor: pointer; position: relative; }
.mf-inbox-list-btn[aria-current="true"] { background: var(--ui-accent-tint); }
.mf-inbox-list-btn[aria-current="true"]:hover { background: var(--ui-accent-tint-strong); }
@media (max-width: 1023px) { .mf-inbox-grid { grid-template-columns: minmax(0, 1fr); } }
`;

const AdminInbox = () => {
  const navigate = useNavigate();
  const { showAlert } = useAlert();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [selectedId, setSelectedId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notifications, setNotifications] = useState([]);
  const [hiddenIds, setHiddenIds] = useState(() => new Set());
  const seenIds = useRef(new Set());

  const loadNotifications = useCallback(() => (
    api.get('/api/notifications/history?limit=100')
      .then(res => {
        if (res.data?.success && Array.isArray(res.data.data)) {
          res.data.data.forEach(n => n?.id && seenIds.current.add(n.id));
          setNotifications(res.data.data);
          setError('');
        }
      })
      .catch(err => setError(errorMessage(err, 'Failed to load notifications.')))
      .finally(() => setLoading(false))
  ), []);

  useEffect(() => { loadNotifications(); }, [loadNotifications]);

  // Live alerts: prepend anything pushed to the admin room while this page is open
  useEffect(() => {
    const socket = acquireSocket();
    const prepend = (n) => {
      if (n.id && seenIds.current.has(n.id)) return;
      if (n.id) seenIds.current.add(n.id);
      setNotifications(prev => [n, ...prev]);
    };
    const onAdminNotification = (raw) => {
      if (!raw) return;
      prepend({
        ...raw,
        id: raw.id || `live-${Date.now()}`,
        type: raw.type || 'SYSTEM',
        title: raw.title || 'New alert',
        body: bodyOf(raw),
        createdAt: raw.timestamp || raw.createdAt || new Date().toISOString(),
        isRead: false,
        live: true,
      });
    };
    const onEscalation = (payload) => {
      const d = payload?.data || payload || {};
      prepend({
        id: `esc-${d.emergencyId || 'unknown'}-${d.timestamp || Date.now()}`,
        type: 'ESCALATION_ALERT',
        title: d.title || 'Emergency escalation',
        body: d.body || '',
        createdAt: d.timestamp || new Date().toISOString(),
        isRead: false,
        live: true,
        data: d.emergencyId ? { emergencyId: d.emergencyId, waitingSeconds: d.ageSeconds } : undefined,
      });
    };
    socket.on('admin_notification', onAdminNotification);
    socket.on('ESCALATION_ALERT', onEscalation);
    return () => {
      socket.off('admin_notification', onAdminNotification);
      socket.off('ESCALATION_ALERT', onEscalation);
      releaseSocket();
    };
  }, []);

  const refresh = () => { setLoading(true); loadNotifications(); };

  const markAllRead = async () => {
    try {
      await api.patch('/api/notifications/read-all');
      setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
      showAlert('All notifications marked as read', 'success');
    } catch (err) {
      showAlert(errorMessage(err, 'Failed to update notifications'), 'error');
    }
  };

  const markRead = async (n) => {
    if (n.isRead) return;
    setNotifications(prev => prev.map(item => (item.id === n.id ? { ...item, isRead: true } : item)));
    if (n.live) return; // live socket events are not persisted rows yet
    try {
      await api.patch(`/api/notifications/${n.id}/read`);
    } catch (err) {
      console.error('Failed to mark read:', err);
    }
  };

  const hideNotif = (id) => {
    // There is no delete endpoint for notifications — hide it for this session only
    setHiddenIds(prev => new Set(prev).add(id));
    if (selectedId === id) setSelectedId(null);
  };

  const openRelated = (n) => {
    markRead(n);
    if (isSos(n)) navigate('/admin/sos');
    else if (isRegistration(n)) navigate('/admin/verify');
  };

  const q = search.trim().toLowerCase();
  const visible = notifications.filter(n => !hiddenIds.has(n.id));
  const filteredNotifs = visible.filter(n => {
    const matchesSearch = !q ||
      String(n.title || '').toLowerCase().includes(q) ||
      String(bodyOf(n)).toLowerCase().includes(q);
    const matchesFilter = filter === 'ALL' ||
      (filter === 'UNREAD' && !n.isRead) ||
      (filter === 'SOS' && isSos(n)) ||
      (filter === 'SYSTEM' && typeOf(n).includes('SYSTEM'));
    return matchesSearch && matchesFilter;
  });
  const unreadCount = visible.filter(n => !n.isRead).length;
  const selectedNotif = visible.find(n => n.id === selectedId) || null;
  const hasAction = selectedNotif && (isSos(selectedNotif) || isRegistration(selectedNotif));
  const hasFilters = !!q || filter !== 'ALL';

  const paneHeight = 'calc(100vh - 220px)';

  return (
    <div className="mf-stack">
      <style>{INBOX_CSS}</style>
      <PageHeader
        title="Admin Inbox"
        description="Alerts and notifications sent to your admin account. New alerts appear here live."
        badge={unreadCount > 0 && <StatusBadge tone="info"><span className="mf-num">{unreadCount}</span> unread</StatusBadge>}
        actions={(
          <>
            <RefreshButton onClick={refresh} loading={loading} />
            <Button icon={CheckCheck} onClick={markAllRead} disabled={unreadCount === 0}>Mark all read</Button>
          </>
        )}
      />

      {error && <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>}

      <div className="mf-inbox-grid">
        {/* List */}
        <Card style={{ display: 'flex', flexDirection: 'column', height: paneHeight, minHeight: '420px' }}>
          <div style={{ padding: '12px', borderBottom: '1px solid var(--border)', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <SearchInput width="100%" value={search} onChange={setSearch} placeholder="Search alerts…" />
            <SegmentedControl
              ariaLabel="Filter alerts"
              value={filter}
              onChange={setFilter}
              options={FILTERS.map(f => ({ value: f.key, label: f.label, count: f.key === 'UNREAD' && unreadCount > 0 ? unreadCount : undefined }))}
            />
          </div>

          <div style={{ flex: 1, overflowY: 'auto' }}>
            {loading ? (
              Array.from({ length: 6 }, (_, i) => (
                <div key={i} style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
                  <Skeleton h={12} w="60%" mb={8} />
                  <Skeleton h={10} w="85%" />
                </div>
              ))
            ) : filteredNotifs.length === 0 ? (
              <EmptyState
                compact
                icon={MailOpen}
                title="No notifications"
                message={hasFilters ? 'Nothing matches the current filter.' : 'You are all caught up.'}
                action={hasFilters && <Button size="sm" onClick={() => { setSearch(''); setFilter('ALL'); }}>Clear filters</Button>}
              />
            ) : (
              <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
                {filteredNotifs.map(n => {
                  const selected = selectedId === n.id;
                  return (
                    <li key={n.id}>
                      <button
                        type="button"
                        className="mf-inbox-list-btn mf-row-hover"
                        onClick={() => { setSelectedId(n.id); markRead(n); }}
                        aria-current={selected ? 'true' : undefined}
                      >
                        {!n.isRead && (
                          <span aria-label="Unread" style={{ position: 'absolute', left: '11px', top: '17px', width: '7px', height: '7px', borderRadius: '50%', background: 'var(--ui-accent)' }} />
                        )}
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                          <span style={{ display: 'flex', alignItems: 'center', gap: '6px', minWidth: 0 }}>
                            {isSos(n) && <TypeIcon n={n} size={13} />}
                            <span style={{ fontSize: '13px', fontWeight: n.isRead ? 500 : 600, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {n.title || 'Notification'}
                            </span>
                          </span>
                          <span className="mf-num" style={{ fontSize: '12px', color: 'var(--text-muted)', flexShrink: 0 }}>
                            {fmtTime(dateOf(n), { hour: '2-digit', minute: '2-digit' })}
                          </span>
                        </div>
                        <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '2px 0 0', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {bodyOf(n) || '—'}
                        </p>
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </Card>

        {/* Reading pane */}
        <Card style={{ display: 'flex', flexDirection: 'column', height: paneHeight, minHeight: '420px' }}>
          {selectedNotif ? (
            <div key={selectedNotif.id} className="mf-fade" style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
              <div style={{ padding: '8px 12px', minHeight: '52px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                <Button variant="ghost" size="sm" icon={ArrowLeft} onClick={() => setSelectedId(null)} aria-label="Close notification">
                  Back
                </Button>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {hasAction && (
                    <Button size="sm" icon={ExternalLink} onClick={() => openRelated(selectedNotif)}>Open in portal</Button>
                  )}
                  <Button variant="ghost" size="sm" icon={EyeOff} onClick={() => hideNotif(selectedNotif.id)} title="Hide from this list for the current session" aria-label="Hide notification">
                    Hide
                  </Button>
                </div>
              </div>

              <div style={{ flex: 1, padding: '20px 24px', overflowY: 'auto' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap', marginBottom: '4px' }}>
                  <TypeIcon n={selectedNotif} size={16} />
                  <h2 style={{ fontSize: '16px', lineHeight: '24px', fontWeight: 600, color: 'var(--text-main)', margin: 0 }}>
                    {selectedNotif.title || 'Notification'}
                  </h2>
                  <StatusBadge tone={isSos(selectedNotif) ? 'danger' : 'neutral'}>
                    {typeOf(selectedNotif).replace(/_/g, ' ') || 'NOTIFICATION'}
                  </StatusBadge>
                </div>
                <p className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '0 0 16px' }}>
                  {fmtTime(dateOf(selectedNotif)) || 'Unknown time'}
                </p>

                <p style={{ fontSize: '14px', color: 'var(--admin-text-sub)', lineHeight: 1.65, whiteSpace: 'pre-wrap', margin: '0 0 16px', maxWidth: '72ch' }}>
                  {bodyOf(selectedNotif) || 'No message body.'}
                </p>

                {hasAction && (
                  <div style={{ marginBottom: '20px' }}>
                    <Button variant="primary" onClick={() => openRelated(selectedNotif)}>
                      {isSos(selectedNotif) ? 'Open SOS monitor' : 'Open verification queue'} <ChevronRight size={15} aria-hidden="true" />
                    </Button>
                  </div>
                )}

                {selectedNotif.data && typeof selectedNotif.data === 'object' && Object.keys(selectedNotif.data).length > 0 && (
                  <div style={{ borderTop: '1px solid var(--border)', paddingTop: '16px' }}>
                    <h3 style={{ fontSize: '11.5px', fontWeight: 500, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', margin: '0 0 12px' }}>
                      Attached data
                    </h3>
                    <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px 16px', margin: 0 }}>
                      {Object.entries(selectedNotif.data).map(([key, val]) => (
                        <DetailItem key={key} label={key}>
                          <span className="mf-num" style={{ wordBreak: 'break-all' }}>{displayValue(val)}</span>
                        </DetailItem>
                      ))}
                    </dl>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <EmptyState icon={Bell} title="Select a notification" message="Choose an alert from the list to see its details." />
            </div>
          )}
        </Card>
      </div>
    </div>
  );
};

export default AdminInbox;

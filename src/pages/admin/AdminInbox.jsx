import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Bell, CheckCheck, AlertTriangle, UserCheck, Info, Clock,
  ExternalLink, ChevronRight, MailOpen, EyeOff, Search, ArrowLeft,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { useAlert } from '../../context/hooks';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { acquireSocket, releaseSocket } from '../../services/socket';
import { PageHeader, RefreshButton, Button, EmptyState, ErrorBanner, FilterPill, Skeleton } from '../../components/ui';

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

const TypeIcon = ({ n, size = 18 }) => {
  if (isSos(n)) return <AlertTriangle size={size} color="var(--sos)" />;
  if (isRegistration(n)) return <UserCheck size={size} color="var(--primary-light)" />;
  if (typeOf(n).includes('SYSTEM')) return <CheckCheck size={size} color="var(--success)" />;
  return <Info size={size} color="var(--text-muted)" />;
};

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

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.3 }}
      style={{ display: 'flex', flexDirection: 'column', minHeight: 'calc(100vh - 140px)' }}
    >
      <PageHeader
        title="Admin Inbox"
        subtitle="Alerts and notifications sent to your admin account. New alerts appear here live."
        badge={unreadCount > 0 && (
          <span style={{ fontSize: '0.72rem', fontWeight: 800, padding: '3px 9px', borderRadius: '999px', background: 'var(--tint-teal)', color: 'var(--admin-accent)' }}>
            {unreadCount} unread
          </span>
        )}
        actions={(
          <>
            <RefreshButton onClick={refresh} loading={loading} />
            <Button onClick={markAllRead} disabled={unreadCount === 0}>
              <CheckCheck size={16} /> Mark all read
            </Button>
          </>
        )}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem', minHeight: 0 }}>

        {/* List */}
        <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', display: 'flex', flexDirection: 'column', overflow: 'hidden', maxHeight: 'calc(100vh - 220px)', minHeight: '420px' }}>
          <div style={{ padding: '14px', borderBottom: '1px solid var(--admin-border)', background: 'var(--table-head-bg)' }}>
            <div style={{ position: 'relative', marginBottom: '10px' }}>
              <Search size={14} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--admin-text-muted)', pointerEvents: 'none' }} />
              <input
                type="search"
                placeholder="Search alerts…"
                aria-label="Search alerts"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{ width: '100%', height: '38px', padding: '0 12px 0 34px', fontSize: '0.875rem', borderRadius: '10px', border: '1.5px solid var(--admin-border)', background: 'var(--input-bg)', color: 'var(--text-main)', outline: 'none' }}
              />
            </div>
            <div role="group" aria-label="Filter alerts" style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
              {FILTERS.map(f => (
                <FilterPill key={f.key} active={filter === f.key} onClick={() => setFilter(f.key)}>{f.label}</FilterPill>
              ))}
            </div>
          </div>

          <div style={{ flex: 1, overflowY: 'auto' }}>
            {loading ? (
              Array.from({ length: 5 }, (_, i) => (
                <div key={i} style={{ padding: '16px', borderBottom: '1px solid var(--admin-border)' }}>
                  <Skeleton h={13} w="60%" mb={8} />
                  <Skeleton h={11} w="85%" />
                </div>
              ))
            ) : filteredNotifs.length === 0 ? (
              <EmptyState compact icon={MailOpen} title="No notifications" message={q || filter !== 'ALL' ? 'Nothing matches the current filter.' : 'You are all caught up.'} />
            ) : (
              <ul style={{ listStyle: 'none' }}>
                {filteredNotifs.map(n => {
                  const selected = selectedId === n.id;
                  return (
                    <li key={n.id}>
                      <button
                        type="button"
                        onClick={() => { setSelectedId(n.id); markRead(n); }}
                        aria-current={selected ? 'true' : undefined}
                        style={{
                          display: 'block', width: '100%', textAlign: 'left', fontFamily: 'inherit',
                          padding: '14px 16px', border: 'none', borderBottom: '1px solid var(--admin-border)',
                          cursor: 'pointer', position: 'relative',
                          background: selected ? 'var(--row-hover-bg)' : 'transparent',
                        }}
                      >
                        {!n.isRead && (
                          <span aria-label="Unread" style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '4px', background: 'var(--admin-accent)' }} />
                        )}
                        <div style={{ display: 'flex', gap: '12px' }}>
                          <div style={{ flexShrink: 0, marginTop: '2px' }}><TypeIcon n={n} /></div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', gap: '8px', marginBottom: '2px' }}>
                              <span style={{ fontSize: '0.86rem', fontWeight: n.isRead ? 600 : 800, color: 'var(--admin-text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{n.title || 'Notification'}</span>
                              <span style={{ fontSize: '0.7rem', color: 'var(--admin-text-muted)', flexShrink: 0 }}>{fmtTime(dateOf(n), { hour: '2-digit', minute: '2-digit' })}</span>
                            </div>
                            <p style={{ fontSize: '0.8rem', color: 'var(--admin-text-muted)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{bodyOf(n) || '—'}</p>
                          </div>
                        </div>
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </div>

        {/* Detail */}
        <div style={{ background: 'var(--surface)', borderRadius: '16px', border: '1px solid var(--admin-border)', display: 'flex', flexDirection: 'column', overflow: 'hidden', minHeight: '420px' }}>
          <AnimatePresence mode="wait">
            {selectedNotif ? (
              <motion.div
                key={selectedNotif.id}
                initial={{ opacity: 0, x: 10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 10 }}
                style={{ flex: 1, display: 'flex', flexDirection: 'column' }}
              >
                <div style={{ padding: '12px 20px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                  <Button variant="ghost" onClick={() => setSelectedId(null)} aria-label="Close notification">
                    <ArrowLeft size={15} /> Back
                  </Button>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {hasAction && (
                      <Button onClick={() => openRelated(selectedNotif)}>
                        <ExternalLink size={14} /> Open in portal
                      </Button>
                    )}
                    <Button variant="ghost" onClick={() => hideNotif(selectedNotif.id)} title="Hide from this list for the current session" aria-label="Hide notification">
                      <EyeOff size={15} /> Hide
                    </Button>
                  </div>
                </div>

                <div style={{ flex: 1, padding: '24px 28px', overflowY: 'auto' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: '20px' }}>
                    <div style={{ width: '46px', height: '46px', borderRadius: '14px', background: 'var(--table-head-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <TypeIcon n={selectedNotif} size={20} />
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', marginBottom: '2px' }}>
                        <h2 style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--admin-text-main)', margin: 0 }}>{selectedNotif.title || 'Notification'}</h2>
                        <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '4px', background: isSos(selectedNotif) ? 'var(--tint-red)' : 'var(--tint-teal)', color: isSos(selectedNotif) ? 'var(--error-fg)' : 'var(--admin-accent)' }}>
                          {typeOf(selectedNotif).replace(/_/g, ' ') || 'NOTIFICATION'}
                        </span>
                      </div>
                      <p style={{ fontSize: '0.82rem', color: 'var(--admin-text-muted)', margin: 0, display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Clock size={13} /> {fmtTime(dateOf(selectedNotif)) || 'Unknown time'}
                      </p>
                    </div>
                  </div>

                  <div style={{ background: 'var(--table-head-bg)', padding: '18px 20px', borderRadius: '14px', border: '1px solid var(--admin-border)', marginBottom: '18px' }}>
                    <p style={{ fontSize: '0.98rem', color: 'var(--admin-text-sub)', lineHeight: 1.65, whiteSpace: 'pre-wrap', margin: 0 }}>
                      {bodyOf(selectedNotif) || 'No message body.'}
                    </p>
                  </div>

                  {hasAction && (
                    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '18px' }}>
                      <Button variant="primary" onClick={() => openRelated(selectedNotif)}>
                        {isSos(selectedNotif) ? 'Open SOS monitor' : 'Open verification queue'} <ChevronRight size={16} />
                      </Button>
                    </div>
                  )}

                  {selectedNotif.data && typeof selectedNotif.data === 'object' && Object.keys(selectedNotif.data).length > 0 && (
                    <div style={{ borderTop: '1px solid var(--admin-border)', paddingTop: '18px' }}>
                      <h3 style={{ fontSize: '0.78rem', fontWeight: 800, color: 'var(--admin-text-muted)', textTransform: 'uppercase', marginBottom: '10px', letterSpacing: '0.06em' }}>Attached data</h3>
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '10px' }}>
                        {Object.entries(selectedNotif.data).map(([key, val]) => (
                          <div key={key} style={{ padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--admin-border)' }}>
                            <p style={{ fontSize: '0.66rem', fontWeight: 800, color: 'var(--admin-text-muted)', textTransform: 'uppercase', marginBottom: '3px' }}>{key}</p>
                            <p style={{ fontSize: '0.86rem', fontWeight: 700, color: 'var(--admin-text-main)', margin: 0, wordBreak: 'break-all' }}>{displayValue(val)}</p>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </motion.div>
            ) : (
              <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <EmptyState icon={Bell} title="Select a notification" message="Choose an alert from the list to see its details." />
              </div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  );
};

export default AdminInbox;

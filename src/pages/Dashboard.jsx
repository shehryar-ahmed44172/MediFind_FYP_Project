import React, { useState, useEffect, useRef, useCallback, useSyncExternalStore } from 'react';
import { Routes, Route, Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Siren, UserCheck, ClipboardList, Users, CreditCard, Receipt,
  Megaphone, MailCheck, Inbox, ScrollText, Settings, LogOut, Search, Sun, Moon,
  Menu, X, ChevronDown, PanelLeftClose, PanelLeftOpen, ArrowLeft, ArrowRight, Bell,
} from 'lucide-react';
import { useAuth, useAlert, useTheme } from '../context/hooks';
import api from '../services/api';
import { acquireSocket, releaseSocket } from '../services/socket';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip as ChartTooltip,
  BarChart, Bar, ResponsiveContainer,
} from 'recharts';
import { MapContainer, TileLayer, Marker, Popup, Circle as MapCircle } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import UserManagement from './UserManagement';
import ResponderVerification from './admin/ResponderVerification';
import ResponderRecords from './admin/ResponderRecords';
import SOSMonitor from './admin/SOSMonitor';
import SystemLogs from './admin/SystemLogs';
import CommunicationAudit from './admin/CommunicationAudit';
import SubscriptionManagement from './admin/SubscriptionManagement';
import AllSubscriptions from './admin/AllSubscriptions';
import PlatformSettings from './admin/PlatformSettings';
import SystemNotifications from './admin/SystemNotifications';
import AdminInbox from './admin/AdminInbox';
import {
  Avatar, Button, DataTable, EmptyState, IconButton, LiveIndicator, Notice, PageHeader,
  Panel, RefreshButton, Skeleton, StatCard, StatusBadge,
} from '../components/ui';
import { chartColors } from '../components/uiStyles';
import useAdminScope from '../components/useAdminScope';
import appMark from '../assets/medifind_app_mark.png';

/* ─── Leaflet icon fix (Vite breaks default icon asset path) ────────────── */
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl:       'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl:     'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});
const redMapIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [20, 33], iconAnchor: [10, 33], popupAnchor: [1, -28], shadowSize: [33, 33],
});
const greenMapIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [18, 29], iconAnchor: [9, 29], popupAnchor: [1, -24], shadowSize: [29, 29],
});

/* ─── Responder type labels ─────────────────────────────────────────────── */
const RESPONDER_LABELS = {
  PARAMEDIC: 'Paramedic',
  RESCUE_OFFICER: 'Rescue Officer',
  EMT: 'EMT',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER: 'Volunteer',
};

/* ─── Navigation (grouped) ──────────────────────────────────────────────── */
const NAV_GROUPS = [
  { label: null, items: [
    { label: 'Overview', to: '/admin', Icon: LayoutDashboard, exact: true },
  ] },
  { label: 'Operations', items: [
    { label: 'SOS Logistics', to: '/admin/sos', Icon: Siren },
    { label: 'Verification Queue', to: '/admin/verify', Icon: UserCheck },
    { label: 'Responder Records', to: '/admin/records', Icon: ClipboardList },
  ] },
  { label: 'People', items: [
    { label: 'User Management', to: '/admin/users', Icon: Users },
  ] },
  { label: 'Subscriptions', items: [
    { label: 'Subscriptions', to: '/admin/subscriptions', Icon: CreditCard, exact: true },
    { label: 'All Subscriptions', to: '/admin/subscriptions/all', Icon: Receipt },
  ] },
  { label: 'Communication', items: [
    { label: 'Notifications', to: '/admin/notifications', Icon: Megaphone },
    { label: 'Comm Audit', to: '/admin/emails', Icon: MailCheck },
    { label: 'Admin Inbox', to: '/admin/inbox', Icon: Inbox },
  ] },
  { label: 'System', items: [
    { label: 'System Logs', to: '/admin/logs', Icon: ScrollText },
    { label: 'Platform Settings', to: '/admin/settings', Icon: Settings },
  ] },
];
const NAV = NAV_GROUPS.flatMap(g => g.items.map(item => ({ ...item, group: g.label })));
const isActiveItem = (item, pathname) => (item.exact ? pathname === item.to : pathname.startsWith(item.to));

const SIDEBAR_W = 232;
const SIDEBAR_W_COLLAPSED = 60;
const NARROW_QUERY = '(max-width: 899px)';
const IS_MAC = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

/* Subscribe to a media query without setState-in-effect */
function useMediaQuery(query) {
  return useSyncExternalStore(
    (onChange) => {
      const mql = window.matchMedia(query);
      mql.addEventListener('change', onChange);
      return () => mql.removeEventListener('change', onChange);
    },
    () => window.matchMedia(query).matches,
    () => false,
  );
}

/* ─── Health summary helper (shared by top bar + overview) ─────────────── */
function summarizeHealth(health) {
  const services = health?.services ? Object.values(health.services) : [];
  if (services.length === 0) return null;
  const healthy = services.filter(s => s?.status === 'healthy').length;
  const anyDown = services.some(s => s?.status === 'down');
  const pct = Math.round((healthy / services.length) * 100);
  return {
    healthy, total: services.length, pct,
    tone: pct === 100 ? 'success' : anyDown ? 'danger' : 'warning',
    color: pct === 100 ? 'var(--success)' : anyDown ? 'var(--sos)' : 'var(--warning)',
    label: pct === 100 ? 'All systems operational' : anyDown ? 'Service outage detected' : 'Degraded performance',
  };
}

/* ─── Notification helpers ──────────────────────────────────────────────── */
const notifTime = (n) => {
  const d = new Date(n?.timestamp || n?.createdAt || 0);
  return Number.isNaN(d.getTime()) || d.getTime() === 0 ? '' : d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};
const isCriticalType = (type = '') => /SOS|EMERGENCY|ESCALATION/.test(type);
const notifRoute = (type = '') => {
  if (isCriticalType(type)) return '/admin/sos';
  if (/REGISTRATION|DOCUMENT|VERIFICATION/.test(type)) return '/admin/verify';
  return '/admin/inbox';
};

/* ─── Sidebar ───────────────────────────────────────────────────────────── */
function BrandMark({ size = 28 }) {
  return (
    <span style={{
      width: size, height: size, borderRadius: '7px', background: '#FFFFFF', border: '1px solid var(--border)',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, overflow: 'hidden',
    }}>
      <img src={appMark} alt="" style={{ width: size - 6, height: size - 6, objectFit: 'contain' }} />
    </span>
  );
}

function Sidebar({ open, narrow, onToggle, onNavigate }) {
  const { pathname } = useLocation();
  const expanded = narrow ? true : open;
  const width = expanded ? SIDEBAR_W : SIDEBAR_W_COLLAPSED;

  return (
    <aside
      aria-label="Main navigation"
      style={{
        position: 'fixed', top: 0, left: 0, bottom: 0, width,
        transform: narrow && !open ? `translateX(-${SIDEBAR_W + 8}px)` : 'none',
        transition: 'width 160ms ease, transform 180ms ease',
        background: 'var(--surface)', borderRight: '1px solid var(--border)',
        display: 'flex', flexDirection: 'column', zIndex: 300, overflow: 'hidden',
        boxShadow: narrow && open ? 'var(--shadow-lg)' : 'none',
      }}
    >
      {/* Brand */}
      <div style={{
        height: '56px', flexShrink: 0, display: 'flex', alignItems: 'center',
        justifyContent: expanded ? 'space-between' : 'center',
        padding: expanded ? '0 10px 0 16px' : 0, borderBottom: '1px solid var(--border)',
      }}>
        <Link to="/admin" onClick={onNavigate} aria-label="MediFind admin home" style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
          <BrandMark />
          {expanded && (
            <span style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.15, minWidth: 0 }}>
              <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-main)' }}>MediFind</span>
              <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>Admin console</span>
            </span>
          )}
        </Link>
        {narrow && <IconButton label="Close navigation" icon={X} onClick={onToggle} tooltip={false} />}
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: expanded ? '10px 10px 16px' : '10px 0 16px' }}>
        {NAV_GROUPS.map((group, gi) => (
          <div key={group.label || 'root'} style={{ marginTop: gi === 0 ? 0 : expanded ? '14px' : '8px' }}>
            {group.label && (expanded ? (
              <p style={{ padding: '0 10px', margin: '0 0 4px', fontSize: '11px', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                {group.label}
              </p>
            ) : (
              <div aria-hidden="true" style={{ height: '1px', background: 'var(--border)', margin: '0 14px 8px' }} />
            ))}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1px' }}>
              {group.items.map(item => {
                const on = isActiveItem(item, pathname);
                return (
                  <Link
                    key={item.to}
                    to={item.to}
                    onClick={onNavigate}
                    aria-current={on ? 'page' : undefined}
                    aria-label={expanded ? undefined : item.label}
                    title={expanded ? undefined : item.label}
                    className={expanded ? 'mf-nav-item' : 'mf-nav-item mf-nav-item--icon'}
                  >
                    <item.Icon size={16} strokeWidth={1.75} aria-hidden="true" />
                    {expanded && <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.label}</span>}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* Collapse control (desktop only) */}
      {!narrow && (
        <div style={{ flexShrink: 0, borderTop: '1px solid var(--border)', padding: expanded ? '8px 10px' : '8px 0' }}>
          <button
            type="button"
            onClick={onToggle}
            aria-label={open ? 'Collapse sidebar' : 'Expand sidebar'}
            title={open ? undefined : 'Expand sidebar'}
            className={expanded ? 'mf-nav-item' : 'mf-nav-item mf-nav-item--icon'}
            style={{ width: expanded ? '100%' : undefined, background: 'transparent', border: 'none', fontFamily: 'inherit' }}
          >
            {open ? <PanelLeftClose size={16} strokeWidth={1.75} aria-hidden="true" /> : <PanelLeftOpen size={16} strokeWidth={1.75} aria-hidden="true" />}
            {expanded && <span>Collapse</span>}
          </button>
        </div>
      )}
    </aside>
  );
}

/* ─── Root Dashboard ────────────────────────────────────────────────────── */
export default function Dashboard() {
  useAdminScope();
  const narrow = useMediaQuery(NARROW_QUERY);
  const [desktopOpen, setDesktopOpen] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [notifs, setNotifs] = useState([]);
  const [showNotifs, setShowNotifs] = useState(false);
  const [unread, setUnread] = useState(0);
  const [health, setHealth] = useState(null);
  const [healthError, setHealthError] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { showAlert } = useAlert();
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === 'dark';

  const [showProfile, setShowProfile] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFocused, setSearchFocused] = useState(false);
  const [users, setUsers] = useState([]);

  const notifRef = useRef(null);
  const searchRef = useRef(null);
  const searchInputRef = useRef(null);
  const profileRef = useRef(null);
  const seenNotifIds = useRef(new Set());

  const contentOffset = narrow ? 0 : (desktopOpen ? SIDEBAR_W : SIDEBAR_W_COLLAPSED);

  // Users for global search
  useEffect(() => {
    api.get('/api/admin/users').then(res => {
      if (res.data?.success && Array.isArray(res.data.data)) setUsers(res.data.data);
    }).catch(err => console.error('Failed to load users for global search:', err));
  }, []);

  // System health — drives the top-bar status and the Overview health panel
  useEffect(() => {
    let cancelled = false;
    const loadHealth = async () => {
      try {
        const res = await api.get('/api/admin/health');
        if (cancelled) return;
        if (res.data?.success) { setHealth(res.data.data); setHealthError(false); }
      } catch {
        if (!cancelled) setHealthError(true);
      }
    };
    loadHealth();
    const id = setInterval(loadHealth, 60000);
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  // Click outside / Escape closes dropdowns; Ctrl/⌘+K focuses search
  useEffect(() => {
    function handleClickOutside(event) {
      if (showNotifs && notifRef.current && !notifRef.current.contains(event.target)) setShowNotifs(false);
      if (showProfile && profileRef.current && !profileRef.current.contains(event.target)) setShowProfile(false);
      if (searchFocused && searchRef.current && !searchRef.current.contains(event.target)) setSearchFocused(false);
    }
    function handleKey(event) {
      if (event.key === 'Escape') { setShowNotifs(false); setShowProfile(false); setSearchFocused(false); setMobileOpen(false); }
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchInputRef.current?.focus();
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKey);
    };
  }, [showNotifs, showProfile, searchFocused]);

  // Notification history + real-time admin socket
  useEffect(() => {
    api.get('/api/notifications/history?limit=10').then(res => {
      if (res.data?.success && Array.isArray(res.data.data)) {
        res.data.data.forEach(n => n?.id && seenNotifIds.current.add(n.id));
        setNotifs(res.data.data);
        setUnread(res.data.data.filter((n) => !n.isRead).length);
      }
    }).catch(err => console.error('Failed to load initial notifications:', err));

    const socket = acquireSocket();

    const pushNotif = (notif, { critical } = {}) => {
      // Backend sometimes emits the same event to both the admin room and the
      // global channel — de-duplicate by id so the admin sees one toast.
      if (notif.id && seenNotifIds.current.has(notif.id)) return;
      if (notif.id) seenNotifIds.current.add(notif.id);
      setNotifs(prev => [notif, ...prev].slice(0, 10));
      setUnread(u => u + 1);
      if (critical) showAlert(`CRITICAL: ${notif.title}`, 'error', 10000);
      else showAlert(notif.title, 'info');
    };

    const onAdminNotification = (raw) => {
      if (!raw) return;
      const notif = {
        ...raw,
        type: raw.type || 'SYSTEM',
        title: raw.title || 'New alert',
        body: raw.body ?? raw.message ?? '',
        createdAt: raw.timestamp || raw.createdAt || new Date().toISOString(),
        isRead: false,
      };
      pushNotif(notif, { critical: notif.type === 'SOS_TRIGGERED' || notif.type === 'PATIENT_EMERGENCY' });
    };

    const onEscalation = (payload) => {
      const d = payload?.data || payload || {};
      pushNotif({
        id: `esc-${d.emergencyId || 'unknown'}-${d.timestamp || Date.now()}`,
        type: 'ESCALATION_ALERT',
        title: d.title || 'Emergency escalation — no responder has accepted',
        body: d.body || (d.ageSeconds ? `Unanswered for ${d.ageSeconds}s.` : ''),
        createdAt: d.timestamp || new Date().toISOString(),
        isRead: false,
        data: d.emergencyId ? { emergencyId: d.emergencyId } : undefined,
      }, { critical: true });
    };

    socket.on('admin_notification', onAdminNotification);
    socket.on('ESCALATION_ALERT', onEscalation);

    return () => {
      socket.off('admin_notification', onAdminNotification);
      socket.off('ESCALATION_ALERT', onEscalation);
      releaseSocket();
    };
  }, [showAlert]);

  const handleLogout = async () => { await logout(); navigate('/login', { replace: true }); };

  const adminName = user?.fullName ?? 'System Administrator';
  const currentNav = NAV.find(n => isActiveItem(n, location.pathname));
  const summary = summarizeHealth(health);

  /* ── Global search ── */
  const q = searchQuery.trim().toLowerCase();
  const navMatches = NAV.filter(item => item.label.toLowerCase().includes(q));
  const userMatches = q
    ? users.filter(u =>
        u.fullName?.toLowerCase().includes(q) ||
        u.email?.toLowerCase().includes(q) ||
        u.phoneNumber?.toLowerCase().includes(q))
    : [];

  const closeSearch = () => { setSearchFocused(false); setSearchQuery(''); };

  const submitSearch = () => {
    if (!q) return;
    // A page-name match with no user match jumps to that page; everything else
    // (including no match at all) opens User Management filtered by the query.
    const target = navMatches.length > 0 && userMatches.length === 0
      ? navMatches[0].to
      : `/admin/users?search=${encodeURIComponent(searchQuery.trim())}`;
    closeSearch();
    searchInputRef.current?.blur();
    navigate(target);
  };

  const toggleSidebar = () => (narrow ? setMobileOpen(o => !o) : setDesktopOpen(o => !o));

  return (
    <div style={{ minHeight: '100vh', background: 'var(--admin-bg)' }}>
      <Sidebar
        open={narrow ? mobileOpen : desktopOpen}
        narrow={narrow}
        onToggle={toggleSidebar}
        onNavigate={() => narrow && setMobileOpen(false)}
      />
      {narrow && mobileOpen && (
        <div
          className="mf-fade"
          onClick={() => setMobileOpen(false)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.45)', zIndex: 250 }}
        />
      )}

      {/* ── Main ── */}
      <div style={{
        marginLeft: contentOffset, transition: 'margin-left 160ms ease',
        display: 'flex', flexDirection: 'column', minWidth: 0, minHeight: '100vh',
      }}>
        {/* ── Top bar ── */}
        <header style={{
          height: '56px', flexShrink: 0, position: 'sticky', top: 0, zIndex: 100,
          display: 'flex', alignItems: 'center', gap: '12px',
          padding: narrow ? '0 12px' : '0 20px',
          background: 'var(--surface)', borderBottom: '1px solid var(--border)',
        }}>
          {/* Left: menu (narrow) + breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0, flex: '1 1 0' }}>
            {narrow && <IconButton label="Open navigation" icon={Menu} onClick={() => setMobileOpen(true)} size="md" tooltip={false} />}
            <nav aria-label="Breadcrumb" style={{ display: 'flex', alignItems: 'center', gap: '6px', whiteSpace: 'nowrap', minWidth: 0, fontSize: '13px' }}>
              {currentNav?.group && (
                <span className="mf-breadcrumb-trail" style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-muted)' }}>
                  {currentNav.group}
                  <span aria-hidden="true" style={{ color: 'var(--border-strong)' }}>/</span>
                </span>
              )}
              <span aria-current="page" style={{ color: 'var(--text-main)', fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {currentNav?.label ?? 'Dashboard'}
              </span>
            </nav>
          </div>

          {/* Center: global search */}
          <div ref={searchRef} role="search" style={{ position: 'relative', flex: '0 1 360px', minWidth: '140px', marginLeft: 'auto' }}>
            <Search size={14} aria-hidden="true" style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' }} />
            <input
              ref={searchInputRef}
              type="text"
              className="mf-input mf-input--with-icon"
              placeholder="Search users or pages…"
              aria-label="Search users or pages"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onKeyDown={e => { if (e.key === 'Enter') submitSearch(); }}
              style={{ height: '34px', paddingRight: narrow ? '10px' : '56px', background: 'var(--surface-alt)' }}
            />
            {!narrow && !searchFocused && (
              <span aria-hidden="true" style={{ position: 'absolute', right: '8px', top: '50%', transform: 'translateY(-50%)', display: 'flex', gap: '2px', pointerEvents: 'none' }}>
                <kbd className="mf-kbd">{IS_MAC ? '⌘' : 'Ctrl'}</kbd><kbd className="mf-kbd">K</kbd>
              </span>
            )}

            {searchFocused && (
              <div className="mf-menu mf-pop" style={{ position: 'absolute', top: '40px', left: 0, width: 'min(400px, calc(100vw - 24px))', zIndex: 1000, padding: '4px 0' }}>
                <div className="mf-menu-label">Pages</div>
                {navMatches.length === 0 ? (
                  <div style={{ padding: '6px 12px', fontSize: '13px', color: 'var(--text-muted)' }}>No matching pages</div>
                ) : navMatches.slice(0, 5).map(item => (
                  <Link key={item.to} to={item.to} onClick={closeSearch} className="mf-menu-item">
                    <item.Icon size={15} strokeWidth={1.75} aria-hidden="true" />
                    <span style={{ flex: 1 }}>{item.label}</span>
                    {item.group && <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{item.group}</span>}
                  </Link>
                ))}

                {q && (
                  <>
                    <div className="mf-menu-label" style={{ borderTop: '1px solid var(--border)', marginTop: '4px', paddingTop: '10px' }}>
                      Users &amp; responders
                    </div>
                    {userMatches.length === 0 ? (
                      <div style={{ padding: '6px 12px', fontSize: '13px', color: 'var(--text-muted)' }}>No users match “{searchQuery.trim()}”</div>
                    ) : userMatches.slice(0, 5).map(u => (
                      <Link key={u.id} to={`/admin/users?search=${encodeURIComponent(u.email || u.fullName)}`} onClick={closeSearch} className="mf-menu-item">
                        <Avatar name={u.fullName} size={24} />
                        <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
                          <span style={{ color: 'var(--text-main)', fontWeight: 500 }}>{u.fullName}</span>
                          <span style={{ fontSize: '12px', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.email} · {u.role}</span>
                        </span>
                      </Link>
                    ))}
                    <div style={{ padding: '6px 12px 4px', fontSize: '12px', color: 'var(--text-muted)' }}>
                      Press <kbd className="mf-kbd">Enter</kbd> to search all users
                    </div>
                  </>
                )}
              </div>
            )}
          </div>

          {/* Right: status, theme, alerts, account */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '4px', flex: '0 0 auto' }}>
            <span
              className="mf-hide-narrow"
              title={summary ? `${summary.healthy} of ${summary.total} services healthy` : undefined}
              style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', marginRight: '8px', fontSize: '12.5px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}
            >
              <span aria-hidden="true" style={{ width: '7px', height: '7px', borderRadius: '50%', background: summary ? summary.color : 'var(--border-strong)' }} />
              <span className="mf-breadcrumb-trail">{summary ? summary.label : healthError ? 'Health check unavailable' : 'Checking services…'}</span>
            </span>

            <IconButton
              label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              icon={isDark ? Sun : Moon}
              onClick={toggleTheme}
              size="md"
              tooltip={false}
              title={isDark ? 'Light mode' : 'Dark mode'}
            />

            <div ref={notifRef} style={{ position: 'relative' }}>
              <button
                type="button"
                className={showNotifs ? 'mf-icon-btn mf-icon-btn--md mf-icon-btn--active' : 'mf-icon-btn mf-icon-btn--md'}
                onClick={() => { setShowNotifs(s => !s); setUnread(0); }}
                aria-label={unread > 0 ? `Alerts, ${unread} new` : 'Alerts'}
                aria-expanded={showNotifs}
                title="Recent alerts"
                style={{ position: 'relative' }}
              >
                <Bell size={16} aria-hidden="true" />
                {unread > 0 && (
                  <span className="mf-num" style={{
                    position: 'absolute', top: '3px', right: '2px', minWidth: '16px', height: '16px', padding: '0 4px',
                    background: 'var(--danger-solid)', color: '#fff', borderRadius: '999px', border: '2px solid var(--surface)',
                    fontSize: '10px', fontWeight: 600, lineHeight: '12px', textAlign: 'center',
                  }}>
                    {unread > 9 ? '9+' : unread}
                  </span>
                )}
              </button>

              {showNotifs && (
                <div className="mf-menu mf-pop" style={{ position: 'absolute', top: '44px', right: 0, width: '360px', maxWidth: 'calc(100vw - 24px)', zIndex: 1000 }}>
                  <div style={{ padding: '10px 14px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <h2 style={{ margin: 0, fontSize: '13.5px', fontWeight: 600 }}>Recent alerts</h2>
                    {notifs.length > 0 && (
                      <button type="button" onClick={() => setNotifs([])} title="Hide these alerts from this list (they remain in the Admin Inbox)"
                        className="mf-btn mf-btn--ghost mf-btn--sm">
                        Clear list
                      </button>
                    )}
                  </div>
                  <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                    {notifs.length === 0 ? (
                      <EmptyState icon={Bell} compact title="No recent alerts" message="New SOS and system alerts will appear here." />
                    ) : notifs.map((n, i) => (
                      <button
                        type="button"
                        key={n.id || i}
                        onClick={() => { navigate(notifRoute(n.type)); setShowNotifs(false); }}
                        className="mf-row-hover"
                        style={{
                          display: 'flex', gap: '10px', width: '100%', textAlign: 'left', fontFamily: 'inherit',
                          padding: '10px 14px', border: 'none', background: 'transparent', cursor: 'pointer',
                          borderBottom: i < notifs.length - 1 ? '1px solid var(--border)' : 'none',
                        }}
                      >
                        <span aria-hidden="true" style={{ width: '6px', height: '6px', borderRadius: '50%', marginTop: '7px', flexShrink: 0, background: isCriticalType(n.type) ? 'var(--sos)' : 'var(--text-muted)' }} />
                        <span style={{ minWidth: 0, flex: 1 }}>
                          <span style={{ display: 'flex', justifyContent: 'space-between', gap: '8px' }}>
                            <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-main)' }}>{n.title || 'Alert'}</span>
                            <span className="mf-num" style={{ fontSize: '12px', color: 'var(--text-muted)', flexShrink: 0 }}>{notifTime(n)}</span>
                          </span>
                          {(n.body || n.message) && (
                            <span style={{ display: '-webkit-box', marginTop: '2px', fontSize: '12.5px', color: 'var(--text-muted)', lineHeight: 1.4, WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                              {n.body || n.message}
                            </span>
                          )}
                        </span>
                      </button>
                    ))}
                  </div>
                  <div style={{ padding: '8px 14px', borderTop: '1px solid var(--border)' }}>
                    <Link to="/admin/inbox" onClick={() => setShowNotifs(false)} className="mf-link" style={{ fontSize: '13px' }}>Open Admin Inbox</Link>
                  </div>
                </div>
              )}
            </div>

            <div ref={profileRef} style={{ position: 'relative', marginLeft: '4px' }}>
              <button
                type="button"
                onClick={() => setShowProfile(s => !s)}
                aria-label="Account menu"
                aria-expanded={showProfile}
                className="mf-btn mf-btn--ghost"
                style={{ padding: '0 6px', gap: '8px', height: '36px' }}
              >
                <Avatar name={adminName} size={26} />
                <span className="mf-hide-narrow mf-breadcrumb-trail" style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', maxWidth: '140px', overflow: 'hidden', textOverflow: 'ellipsis' }}>{adminName}</span>
                <ChevronDown size={14} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />
              </button>

              {showProfile && (
                <div className="mf-menu mf-pop" style={{ position: 'absolute', top: '44px', right: 0, width: '248px', zIndex: 1000 }}>
                  <div style={{ padding: '12px 14px', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <Avatar name={adminName} size={32} />
                    <div style={{ minWidth: 0 }}>
                      <p style={{ margin: 0, fontSize: '13px', fontWeight: 600, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{adminName}</p>
                      {user?.email && <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{user.email}</p>}
                      <p style={{ margin: '2px 0 0', fontSize: '12px', color: 'var(--text-muted)' }}>System administrator</p>
                    </div>
                  </div>
                  <div style={{ padding: '4px 0' }}>
                    {[
                      { to: '/admin/settings', label: 'Platform Settings', Icon: Settings },
                      { to: '/admin/logs', label: 'System Logs', Icon: ScrollText },
                      { to: '/admin/inbox', label: 'Admin Inbox', Icon: Inbox },
                    ].map(item => (
                      <Link key={item.to} to={item.to} onClick={() => setShowProfile(false)} className="mf-menu-item">
                        <item.Icon size={15} strokeWidth={1.75} aria-hidden="true" />
                        <span>{item.label}</span>
                      </Link>
                    ))}
                  </div>
                  <div style={{ padding: '4px 0', borderTop: '1px solid var(--border)' }}>
                    <button type="button" onClick={() => { setShowProfile(false); handleLogout(); }} className="mf-menu-item mf-menu-item--danger">
                      <LogOut size={15} strokeWidth={1.75} aria-hidden="true" />
                      <span>Sign out</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* ── Page content ── */}
        <main style={{ flex: 1, padding: narrow ? '16px' : '24px', minWidth: 0 }}>
          <div key={location.pathname} className="mf-page" style={{ maxWidth: '1600px', margin: '0 auto' }}>
            <Routes location={location}>
              <Route path="/" element={<Overview health={health} healthError={healthError} />} />
              <Route path="/users" element={<UserManagement />} />
              <Route path="/verify" element={<ResponderVerification />} />
              <Route path="/records" element={<ResponderRecords />} />
              <Route path="/sos" element={<SOSMonitor />} />
              <Route path="/subscriptions" element={<SubscriptionManagement />} />
              <Route path="/subscriptions/all" element={<AllSubscriptions />} />
              <Route path="/logs" element={<SystemLogs />} />
              <Route path="/emails" element={<CommunicationAudit />} />
              <Route path="/notifications" element={<SystemNotifications />} />
              <Route path="/inbox" element={<AdminInbox />} />
              <Route path="/settings" element={<PlatformSettings />} />
              <Route path="*" element={<AdminNotFound />} />
            </Routes>
          </div>
        </main>
      </div>
    </div>
  );
}

/* ─── Admin 404 — shown inside the admin dashboard shell ────────────────── */
function AdminNotFound() {
  const navigate = useNavigate();
  const location = useLocation();
  const [count, setCount] = React.useState(8);

  React.useEffect(() => {
    const t = setInterval(() => setCount(p => Math.max(0, p - 1)), 1000);
    return () => clearInterval(t);
  }, []);

  React.useEffect(() => {
    if (count === 0) navigate('/admin', { replace: true });
  }, [count, navigate]);

  return (
    <div style={{ minHeight: '60vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ maxWidth: '440px', textAlign: 'center' }}>
        <p className="mf-num" style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-muted)', margin: '0 0 8px' }}>404 · Page not found</p>
        <h1 style={{ fontSize: '20px', fontWeight: 600, margin: '0 0 6px' }}>This admin page doesn’t exist</h1>
        <p style={{ fontSize: '13.5px', color: 'var(--text-muted)', margin: '0 0 20px' }}>
          <code style={{ background: 'var(--surface-alt)', border: '1px solid var(--border)', padding: '1px 6px', borderRadius: '4px', fontSize: '12.5px', color: 'var(--text-main)' }}>
            {location.pathname}
          </code>{' '}
          is not a valid admin page. Use the sidebar to find the section you need.
        </p>
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center', marginBottom: '16px' }}>
          <Button icon={ArrowLeft} onClick={() => navigate(-1)}>Go back</Button>
          <Button variant="primary" icon={LayoutDashboard} onClick={() => navigate('/admin', { replace: true })}>Back to overview</Button>
        </div>
        <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: 0 }}>
          Redirecting to the overview in <span className="mf-num" style={{ color: 'var(--text-main)', fontWeight: 500 }}>{count}s</span>
        </p>
      </div>
    </div>
  );
}

/* ─── Overview Page ─────────────────────────────────────────────────────── */
const SECTION_LABELS = {
  stats: 'key statistics',
  pending: 'verification queue',
  analytics: 'emergency analytics',
  subs: 'subscription revenue',
};

const okResult = (r) => r.status === 'fulfilled' && r.value?.data?.success;

const fetchOverviewData = () => Promise.allSettled([
  api.get('/api/admin/stats'),
  api.get('/api/admin/responders/pending'),
  api.get('/api/admin/analytics/emergencies?days=14'),
  api.get('/api/admin/subscriptions/all'),
]);

const PENDING_PREVIEW = 5;

function Overview({ health, healthError }) {
  const navigate = useNavigate();
  const { theme } = useTheme();
  const colors = chartColors(theme === 'dark');
  const [stats,             setStats]             = useState(null);
  const [pendingCount,      setPendingCount]      = useState(null);
  const [pendingResponders, setPendingResponders] = useState([]);
  const [loading,           setLoading]           = useState(true);
  const [failed,            setFailed]            = useState({});
  const [analytics,         setAnalytics]         = useState(null);
  const [lastUpdated,       setLastUpdated]       = useState(null);
  const [refreshing,        setRefreshing]        = useState(false);
  const [statsDelta,        setStatsDelta]        = useState(null);
  const prevStatsRef   = useRef(null);
  const mapSectionRef  = useRef(null);
  const [mapEmergencies, setMapEmergencies] = useState([]);
  const [mapResponders,  setMapResponders]  = useState([]);
  const [dismissedAtCount, setDismissedAtCount] = useState(null);
  const [subStats,       setSubStats]       = useState(null);

  /* Full load — each section degrades independently if its request fails */
  const applyOverview = useCallback(([statsR, pendR, analyticsR, subR]) => {
    const nextFailed = {};

    if (okResult(statsR)) {
      const s = statsR.value.data.data;
      prevStatsRef.current = s;
      setStats(s);
      setStatsDelta(null);
    } else nextFailed.stats = true;

    if (okResult(pendR)) {
      const arr = pendR.value.data.data || [];
      setPendingCount(arr.length);
      setPendingResponders(arr);
    } else nextFailed.pending = true;

    if (okResult(analyticsR)) setAnalytics(analyticsR.value.data.data);
    else nextFailed.analytics = true;

    if (okResult(subR)) setSubStats(subR.value.data.data.stats);
    else nextFailed.subs = true;

    setFailed(nextFailed);
    setLastUpdated(new Date());
    setLoading(false);
  }, []);

  /* Silent background refresh — updates stats without showing skeleton */
  const silentRefresh = useCallback(async () => {
    const [statsR, pendR] = await Promise.allSettled([
      api.get('/api/admin/stats'),
      api.get('/api/admin/responders/pending'),
    ]);
    if (okResult(statsR)) {
      const newS = statsR.value.data.data;
      const prev = prevStatsRef.current;
      if (prev) {
        setStatsDelta({
          totalUsers:        newS.totalUsers        - prev.totalUsers,
          activeEmergencies: newS.activeEmergencies - prev.activeEmergencies,
          totalEmergencies:  newS.totalEmergencies  - prev.totalEmergencies,
          onlineResponders:  newS.onlineResponders  - prev.onlineResponders,
        });
      }
      prevStatsRef.current = newS;
      setStats(newS);
      setFailed(f => (f.stats ? { ...f, stats: false } : f));
    }
    if (okResult(pendR)) {
      const arr = pendR.value.data.data || [];
      setPendingCount(arr.length);
      setPendingResponders(arr);
    }
    setLastUpdated(new Date());
  }, []);

  useEffect(() => {
    let alive = true;
    fetchOverviewData().then(results => { if (alive) applyOverview(results); });
    const interval = setInterval(silentRefresh, 15000);
    return () => { alive = false; clearInterval(interval); };
  }, [applyOverview, silentRefresh]);

  const handleRefresh = async () => {
    setRefreshing(true);
    try { applyOverview(await fetchOverviewData()); } finally { setRefreshing(false); }
  };

  /* Active SOS pins + online responders for the Live Map (10 s poll) */
  useEffect(() => {
    const fetchMapData = async () => {
      const [emRes, respRes] = await Promise.allSettled([
        api.get('/api/emergencies'),
        api.get('/api/admin/responders/online'),
      ]);
      if (okResult(emRes)) {
        setMapEmergencies((emRes.value.data.data || []).filter(e => e.status === 'ACTIVE'));
      }
      if (okResult(respRes)) {
        setMapResponders(respRes.value.data.data || []);
      }
    };
    fetchMapData();
    const id = setInterval(fetchMapData, 10000);
    return () => clearInterval(id);
  }, []);

  const failedKeys = Object.keys(failed).filter(k => failed[k]);
  const allFailed = failedKeys.length === 4;

  /* Delta text only when something changed since the previous refresh */
  const deltaProps = (d) => (d ? { delta: d > 0 ? `+${d}` : `${d}`, deltaTone: d > 0 ? 'up' : 'down' } : {});
  const d = statsDelta;

  const mapCenter = mapEmergencies.length > 0
    ? [
        mapEmergencies.reduce((s, e) => s + (e.latitude  || 30.3753), 0) / mapEmergencies.length,
        mapEmergencies.reduce((s, e) => s + (e.longitude || 69.3451), 0) / mapEmergencies.length,
      ]
    : [30.3753, 69.3451];
  const mapZoom   = mapEmergencies.length > 0 ? 11 : 5;
  // Popup re-appears automatically when the number of active SOS changes after a dismiss
  const showPopup = mapEmergencies.length > 0 && dismissedAtCount !== mapEmergencies.length;
  const tooltipStyle = {
    borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--text-main)',
    fontSize: '12px', fontFamily: 'inherit', boxShadow: 'var(--shadow-overlay)', padding: '6px 10px',
  };
  const axisTick = { fontSize: 11, fill: colors.axis };

  const chartMessage = (text) => (
    <div style={{ height: '220px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', fontSize: '13px', textAlign: 'center', padding: '0 16px' }}>
      {text}
    </div>
  );

  const legendDot = (color, label, dashed) => (
    <span key={label} style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--text-muted)' }}>
      <span aria-hidden="true" style={{ width: '12px', height: 0, borderTop: `2px ${dashed ? 'dashed' : 'solid'} ${color}` }} />
      {label}
    </span>
  );

  return (
    <div>
      {/* ── Active SOS reminder (bottom-right) ── */}
      {showPopup && (
        <div role="alert" className="mf-pop" style={{
          position: 'fixed', bottom: '20px', right: '20px', zIndex: 600, minWidth: '280px',
          display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 8px 10px 14px',
          background: 'var(--surface)', border: '1px solid var(--border)', borderLeft: '3px solid var(--sos)',
          borderRadius: '10px', boxShadow: 'var(--shadow-overlay)',
        }}>
          <span className="mf-live-dot" aria-hidden="true" style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--sos)', flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <p className="mf-num" style={{ margin: 0, fontSize: '13px', fontWeight: 600, color: 'var(--text-main)' }}>
              {mapEmergencies.length} active SOS alert{mapEmergencies.length > 1 ? 's' : ''}
            </p>
            <button type="button" className="mf-link" onClick={() => mapSectionRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
              style={{ background: 'none', border: 'none', padding: 0, fontSize: '12.5px', fontFamily: 'inherit', cursor: 'pointer' }}>
              View on live map
            </button>
          </div>
          <IconButton label="Dismiss SOS reminder" icon={X} onClick={() => setDismissedAtCount(mapEmergencies.length)} tooltip={false} />
        </div>
      )}

      <PageHeader
        title="Overview"
        description="Real-time status of the MediFind emergency response network."
        actions={(
          <>
            <span className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)', marginRight: '4px' }}>
              {lastUpdated
                ? `Updated ${lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })} · auto-refresh 15s`
                : 'Auto-refresh 15s'}
            </span>
            <RefreshButton onClick={handleRefresh} loading={refreshing} />
          </>
        )}
      />

      <div className="mf-stack">
        {/* Partial / total failure banner */}
        {!loading && failedKeys.length > 0 && (
          <Notice tone="warning" action={<Button size="sm" onClick={handleRefresh}>Retry</Button>}>
            {allFailed
              ? 'Unable to reach the backend — check that the API server is running.'
              : `Some sections could not be loaded: ${failedKeys.map(k => SECTION_LABELS[k]).join(', ')}.`}
          </Notice>
        )}

        {/* ── KPI row ── */}
        <div className="mf-grid-stats">
          <StatCard
            label="Total users" value={stats?.totalUsers} loading={loading} unavailable={!stats}
            hint={d?.totalUsers ? 'since last refresh' : 'Registered accounts'} {...deltaProps(d?.totalUsers)}
            onClick={() => navigate('/admin/users?role=ALL')}
          />
          <StatCard
            label="Active emergencies" value={stats?.activeEmergencies} loading={loading} unavailable={!stats}
            live={stats?.activeEmergencies > 0 ? 'Live' : undefined}
            hint={stats?.activeEmergencies > 0 ? 'Ongoing SOS events' : 'No ongoing SOS events'}
            onClick={() => navigate('/admin/sos?filter=ACTIVE')}
          />
          <StatCard
            label="Total emergencies" value={stats?.totalEmergencies} loading={loading} unavailable={!stats}
            {...deltaProps(d?.totalEmergencies)}
            hint={d?.totalEmergencies ? 'since last refresh' : analytics ? `${analytics.totalInPeriod ?? 0} in the last 14 days` : 'All-time SOS events'}
            onClick={() => navigate('/admin/sos?filter=ALL')}
          />
          <StatCard
            label="Verified responders" value={stats?.onlineResponders} loading={loading} unavailable={!stats}
            {...deltaProps(d?.onlineResponders)}
            hint={d?.onlineResponders ? 'since last refresh' : pendingCount ? `${pendingCount} awaiting verification` : 'Approved to respond'}
            onClick={() => navigate('/admin/records')}
          />
        </div>

        {/* ── Analytics ── */}
        <div className="mf-grid-main-side">
          <Panel
            title="Emergency trend"
            description={`${analytics?.period ?? 'Last 14 days'}${analytics ? ` · ${analytics.totalInPeriod ?? 0} total` : ''}`}
            actions={(
              <span className="mf-hide-narrow" style={{ display: 'flex', gap: '12px' }}>
                {legendDot(colors.primary, 'Total')}
                {legendDot(colors.success, 'Resolved')}
                {legendDot(colors.axis, 'Cancelled', true)}
              </span>
            )}
            bodyStyle={{ padding: '12px 12px 8px 0' }}
          >
            {loading ? (
              <div style={{ height: '220px', padding: '8px 16px' }}><Skeleton h="100%" /></div>
            ) : !analytics ? chartMessage('Emergency analytics are unavailable right now.') : (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={analytics.trend} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                  <CartesianGrid stroke={colors.grid} vertical={false} />
                  <XAxis dataKey="date" tick={axisTick} tickLine={false} axisLine={{ stroke: colors.grid }} minTickGap={16}
                    tickFormatter={v => new Date(v).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })} />
                  <YAxis allowDecimals={false} tick={axisTick} tickLine={false} axisLine={false} width={36} />
                  <ChartTooltip
                    contentStyle={tooltipStyle}
                    cursor={{ stroke: colors.grid }}
                    labelFormatter={v => new Date(v).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })}
                  />
                  <Line type="monotone" dataKey="total"     name="Total"     stroke={colors.primary} strokeWidth={1.75} dot={false} activeDot={{ r: 3 }} />
                  <Line type="monotone" dataKey="resolved"  name="Resolved"  stroke={colors.success} strokeWidth={1.75} dot={false} activeDot={{ r: 3 }} />
                  <Line type="monotone" dataKey="cancelled" name="Cancelled" stroke={colors.axis} strokeWidth={1.5} strokeDasharray="4 3" dot={false} activeDot={{ r: 3 }} />
                </LineChart>
              </ResponsiveContainer>
            )}
          </Panel>

          <Panel title="Emergencies by type" description="Top categories, last 14 days" bodyStyle={{ padding: '12px 16px 8px 4px' }}>
            {loading ? (
              <div style={{ height: '220px', padding: '8px 12px' }}><Skeleton h="100%" /></div>
            ) : !analytics ? chartMessage('Unavailable') : analytics.typeBreakdown.length === 0 ? (
              chartMessage('No emergencies in this period')
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <BarChart data={analytics.typeBreakdown.slice(0, 6)} layout="vertical" margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
                  <CartesianGrid stroke={colors.grid} horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={axisTick} tickLine={false} axisLine={false} />
                  <YAxis type="category" dataKey="type" tick={axisTick} tickLine={false} axisLine={false} width={92}
                    tickFormatter={v => String(v).replace(/_/g, ' ').toLowerCase().replace(/^\w/, c => c.toUpperCase())} />
                  <ChartTooltip contentStyle={tooltipStyle} cursor={{ fill: colors.cursor }} />
                  <Bar dataKey="count" name="Count" fill={colors.primary} barSize={12} radius={[0, 3, 3, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </Panel>
        </div>

        {/* ── Live map + system health ── */}
        <div className="mf-grid-main-side">
          <div ref={mapSectionRef} style={{ scrollMarginTop: '72px', minWidth: 0 }}>
            <Panel
              title="Live SOS map"
              description="Active emergencies and available responder positions"
              actions={(
                <>
                  {mapEmergencies.length > 0 && <StatusBadge tone="danger"><span className="mf-num">{mapEmergencies.length}</span> active</StatusBadge>}
                  <Link to="/admin/sos" className="mf-btn mf-btn--secondary mf-btn--sm">
                    SOS Logistics <ArrowRight size={13} aria-hidden="true" />
                  </Link>
                </>
              )}
              style={{ height: '100%' }}
              footer={(
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flexWrap: 'wrap' }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                    <span aria-hidden="true" style={{ width: '7px', height: '7px', borderRadius: '50%', background: 'var(--sos)' }} />
                    SOS <span className="mf-num" style={{ color: 'var(--text-main)' }}>{mapEmergencies.length}</span>
                  </span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                    <span aria-hidden="true" style={{ width: '7px', height: '7px', borderRadius: '50%', background: 'var(--success)' }} />
                    Responders <span className="mf-num" style={{ color: 'var(--text-main)' }}>{mapResponders.length}</span>
                  </span>
                  <span style={{ marginLeft: 'auto' }}>Auto-refresh 10s</span>
                </div>
              )}
            >
              <div style={{ position: 'relative', isolation: 'isolate', zIndex: 0, height: '340px' }}>
                <MapContainer
                  key={mapCenter.join(',')}
                  center={mapCenter}
                  zoom={mapZoom}
                  style={{ height: '100%', width: '100%' }}
                  scrollWheelZoom={false}
                  zoomControl
                  attributionControl={false}
                >
                  <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

                  {mapEmergencies.map(e => e.latitude && e.longitude && (
                    <React.Fragment key={e.id}>
                      <MapCircle center={[e.latitude, e.longitude]} radius={300} color={colors.sos} weight={1} fillColor={colors.sos} fillOpacity={0.1} />
                      <Marker position={[e.latitude, e.longitude]} icon={redMapIcon}>
                        <Popup>
                          <div style={{ minWidth: '160px', fontFamily: 'var(--font-sans)' }}>
                            <strong style={{ color: 'var(--error-fg)', fontSize: '12px', display: 'block', marginBottom: '2px' }}>
                              {e.emergencyType || 'Medical'} emergency
                            </strong>
                            <p style={{ margin: '0 0 2px', fontSize: '12.5px', fontWeight: 500 }}>
                              {e.patient?.fullName || 'Unknown patient'}
                            </p>
                            <p className="mf-num" style={{ margin: 0, fontSize: '11.5px', color: 'var(--text-muted)' }}>
                              {e.latitude?.toFixed(5)}, {e.longitude?.toFixed(5)}
                            </p>
                          </div>
                        </Popup>
                      </Marker>
                    </React.Fragment>
                  ))}

                  {mapResponders.map(r => r.currentLatitude && r.currentLongitude && (
                    <Marker key={r.userId} position={[r.currentLatitude, r.currentLongitude]} icon={greenMapIcon}>
                      <Popup>
                        <div style={{ minWidth: '150px', fontFamily: 'var(--font-sans)' }}>
                          <strong style={{ color: 'var(--text-main)', fontSize: '12.5px', display: 'block', marginBottom: '2px' }}>
                            {r.user?.fullName || 'Responder'}
                          </strong>
                          <p style={{ margin: 0, fontSize: '11.5px', color: 'var(--text-muted)' }}>
                            {r.responderType?.replace(/_/g, ' ') || 'Responder'}
                          </p>
                        </div>
                      </Popup>
                    </Marker>
                  ))}
                </MapContainer>
              </div>
            </Panel>
          </div>

          <HealthPanel health={health} error={healthError} />
        </div>

        {/* ── Verification queue + subscription revenue ── */}
        <div className="mf-grid-main-side">
          <Panel
            title={(
              <>
                Pending verification
                {pendingResponders.length > 0 && <StatusBadge tone="warning"><span className="mf-num">{pendingResponders.length}</span> pending</StatusBadge>}
              </>
            )}
            description="Responders awaiting credential review and activation"
            actions={<Link to="/admin/verify" className="mf-btn mf-btn--secondary mf-btn--sm">Open queue</Link>}
            footer={pendingResponders.length > PENDING_PREVIEW && (
              <Link to="/admin/verify" className="mf-link" style={{ fontSize: '12.5px' }}>
                View {pendingResponders.length - PENDING_PREVIEW} more in the Verification Queue
              </Link>
            )}
          >
            {loading ? (
              <div style={{ padding: '12px 16px' }}>
                {Array.from({ length: 3 }, (_, i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '10px', height: '46px' }}>
                    <Skeleton h={28} w="28px" br={14} />
                    <Skeleton h={10} w="30%" />
                    <Skeleton h={10} w="20%" style={{ marginLeft: 'auto' }} />
                  </div>
                ))}
              </div>
            ) : failed.pending ? (
              <EmptyState compact title="Could not load the verification queue" message="Try refreshing the overview." />
            ) : pendingResponders.length === 0 ? (
              <EmptyState compact icon={UserCheck} title="Queue is clear" message="No responders are currently awaiting verification." />
            ) : (
              <DataTable minWidth="600px">
                <thead>
                  <tr>
                    <th scope="col">Responder</th>
                    <th scope="col">Type</th>
                    <th scope="col">Organization</th>
                    <th scope="col">Applied</th>
                    <th scope="col" className="actions"><span className="sr-only">Actions</span></th>
                  </tr>
                </thead>
                <tbody>
                  {pendingResponders.slice(0, PENDING_PREVIEW).map((r, i) => {
                    const name = r.user?.fullName ?? r.fullName;
                    return (
                      <tr key={r.id || i} className="mf-table-row">
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                            <Avatar name={name} size={28} />
                            <div style={{ minWidth: 0 }}>
                              <div style={{ fontWeight: 500, color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{name ?? '—'}</div>
                              <div style={{ fontSize: '12px', color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.user?.email ?? r.email ?? '—'}</div>
                            </div>
                          </div>
                        </td>
                        <td><StatusBadge dot={false}>{RESPONDER_LABELS[r.responderType] ?? r.responderType ?? 'Responder'}</StatusBadge></td>
                        <td style={{ whiteSpace: 'nowrap', maxWidth: '180px', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.organization ?? '—'}</td>
                        <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>
                          {r.createdAt ? new Date(r.createdAt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: '2-digit' }) : '—'}
                        </td>
                        <td className="actions">
                          <Button size="sm" onClick={() => navigate('/admin/verify')} aria-label={`Review ${name ?? 'responder'}`}>Review</Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </DataTable>
            )}
          </Panel>

          <SubscriptionRevenuePanel subStats={subStats} loading={loading} unavailable={failed.subs} />
        </div>
      </div>
    </div>
  );
}

/* ─── Subscription revenue ──────────────────────────────────────────────── */
const PLAN_PRICE_PKR = { PROFESSIONAL: 499, EXECUTIVE: 2499 };

function SubscriptionRevenuePanel({ subStats, loading, unavailable }) {
  const proCount  = subStats?.PROFESSIONAL ?? 0;
  const execCount = subStats?.EXECUTIVE    ?? 0;
  const freeCount = subStats?.FREE         ?? 0;
  const total     = subStats?.total        ?? 0;
  const proRev    = proCount  * PLAN_PRICE_PKR.PROFESSIONAL;
  const execRev   = execCount * PLAN_PRICE_PKR.EXECUTIVE;
  const mrr       = proRev + execRev;
  const paidCount = proCount + execCount;
  const convRate  = total > 0 ? ((paidCount / total) * 100).toFixed(1) : '0.0';
  const fmtPKR    = (n) => 'PKR ' + n.toLocaleString();

  const planRows = [
    { label: 'Executive',    count: execCount, rev: execRev, color: 'var(--primary)',     pct: total > 0 ? (execCount / total * 100) : 0 },
    { label: 'Professional', count: proCount,  rev: proRev,  color: 'var(--primary-mid)', pct: total > 0 ? (proCount / total * 100)  : 0 },
    { label: 'Free',         count: freeCount, rev: 0,       color: 'var(--border-strong)', pct: total > 0 ? (freeCount / total * 100) : 0 },
  ];

  return (
    <Panel
      title="Subscription revenue"
      description="Estimated from current plans"
      actions={<Link to="/admin/subscriptions/all" className="mf-link" style={{ fontSize: '12.5px' }}>View all</Link>}
    >
      {loading ? (
        <div style={{ padding: '16px' }}>
          <Skeleton h={12} w="40%" mb={8} />
          <Skeleton h={26} w="55%" mb={16} />
          <Skeleton h={8} mb={14} />
          <Skeleton h={10} w="70%" mb={10} />
          <Skeleton h={10} w="60%" />
        </div>
      ) : unavailable ? (
        <EmptyState compact title="Subscription data is unavailable" message="Try refreshing the overview." />
      ) : (
        <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div>
            <p style={{ margin: 0, fontSize: '12.5px', color: 'var(--text-muted)' }}>Monthly recurring revenue</p>
            <p className="mf-num" style={{ margin: '2px 0 0', fontSize: '24px', lineHeight: '32px', fontWeight: 600, color: 'var(--text-main)', letterSpacing: '-0.02em' }}>{fmtPKR(mrr)}</p>
          </div>

          <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', margin: 0, border: '1px solid var(--border)', borderRadius: '8px' }}>
            {[['Paid users', paidCount.toLocaleString()], ['Conversion', `${convRate}%`], ['Total users', total.toLocaleString()]].map(([label, val], i) => (
              <div key={label} style={{ padding: '8px 12px', borderLeft: i > 0 ? '1px solid var(--border)' : 'none', minWidth: 0 }}>
                <dt style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{label}</dt>
                <dd className="mf-num" style={{ margin: 0, fontSize: '14px', fontWeight: 600, color: 'var(--text-main)' }}>{val}</dd>
              </div>
            ))}
          </dl>

          <div>
            <div aria-hidden="true" style={{ display: 'flex', height: '6px', borderRadius: '3px', overflow: 'hidden', background: 'var(--surface-alt)', gap: '2px' }}>
              {planRows.filter(r => r.pct > 0).map(r => (
                <span key={r.label} style={{ width: `${r.pct}%`, background: r.color }} />
              ))}
            </div>
            <div style={{ marginTop: '10px', display: 'flex', flexDirection: 'column' }}>
              {planRows.map(row => (
                <div key={row.label} style={{ display: 'flex', alignItems: 'center', gap: '8px', height: '30px', fontSize: '13px' }}>
                  <span aria-hidden="true" style={{ width: '8px', height: '8px', borderRadius: '2px', background: row.color }} />
                  <span style={{ color: 'var(--text-main)' }}>{row.label}</span>
                  <span className="mf-num" style={{ color: 'var(--text-muted)' }}>{row.count.toLocaleString()} users</span>
                  <span className="mf-num" style={{ marginLeft: 'auto', color: row.rev > 0 ? 'var(--text-main)' : 'var(--text-muted)' }}>
                    {row.rev > 0 ? fmtPKR(row.rev) : '—'}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {freeCount > 0 && (
            <p style={{ margin: 0, paddingTop: '12px', borderTop: '1px solid var(--border)', fontSize: '12.5px', color: 'var(--text-muted)' }}>
              Upgrade potential: <span className="mf-num" style={{ color: 'var(--text-main)' }}>{freeCount}</span> free user{freeCount !== 1 ? 's' : ''} · up to{' '}
              <span className="mf-num" style={{ color: 'var(--text-main)' }}>{fmtPKR(freeCount * PLAN_PRICE_PKR.PROFESSIONAL)}</span> additional MRR on Pro
            </p>
          )}
        </div>
      )}
    </Panel>
  );
}

/* ─── System health list (real data from /api/admin/health) ─────────────── */
const HEALTH_STATUS = {
  healthy:  { tone: 'success', label: 'Healthy'  },
  degraded: { tone: 'warning', label: 'Degraded' },
  down:     { tone: 'danger',  label: 'Down'     },
};

const formatUptime = (secs) => {
  if (secs == null) return '—';
  const dd = Math.floor(secs / 86400);
  const h = Math.floor((secs % 86400) / 3600);
  const m = Math.floor((secs % 3600) / 60);
  if (dd > 0) return `${dd}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m ${secs % 60}s`;
};

function HealthPanel({ health, error }) {
  const services = [
    { label: 'API',              key: 'api' },
    { label: 'Database',         key: 'database' },
    { label: 'Push notifications', key: 'push' },
    { label: 'Realtime sockets', key: 'socket' },
  ];
  const summary = summarizeHealth(health);
  const row = { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', height: '44px', padding: '0 16px', borderBottom: '1px solid var(--border)', fontSize: '13px' };

  return (
    <Panel
      title="System health"
      description={summary ? summary.label : error ? 'Health check unavailable' : 'Checking services…'}
      actions={summary && <LiveIndicator tone={summary.tone} label={`${summary.healthy}/${summary.total}`} />}
    >
      {!health ? (
        error
          ? <EmptyState compact title="Health check unavailable" message="The health endpoint did not respond." />
          : (
            <div style={{ padding: '8px 16px' }}>
              {services.map(s => <Skeleton key={s.key} h={12} mb={20} style={{ marginTop: '12px' }} />)}
            </div>
          )
      ) : (
        <div>
          {services.map(({ label, key }) => {
            const svc = health.services?.[key];
            const s = HEALTH_STATUS[svc?.status] || HEALTH_STATUS.down;
            return (
              <div key={key} style={row}>
                <span style={{ color: 'var(--text-main)' }}>{label}</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: '10px' }}>
                  {svc?.latencyMs != null && <span className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{svc.latencyMs} ms</span>}
                  <StatusBadge tone={s.tone}>{s.label}</StatusBadge>
                </span>
              </div>
            );
          })}
          <div style={row}>
            <span style={{ color: 'var(--text-muted)' }}>Uptime</span>
            <span className="mf-num" style={{ color: 'var(--text-main)' }}>{formatUptime(health.uptime)}</span>
          </div>
          {health.memory && (
            <div style={{ ...row, borderBottom: 'none' }}>
              <span style={{ color: 'var(--text-muted)' }}>Heap memory</span>
              <span className="mf-num" style={{ color: health.memory.usedPct > 80 ? 'var(--error-fg)' : 'var(--text-main)' }}>
                {health.memory.usedMB} / {health.memory.totalMB} MB
              </span>
            </div>
          )}
        </div>
      )}
    </Panel>
  );
}

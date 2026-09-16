import React, { useState, useEffect, useRef, useCallback, useSyncExternalStore } from 'react';
import { Routes, Route, Link, useLocation, useNavigate } from 'react-router-dom';
import {
  BarChart3, Users, UserCheck, Activity, History, Mail,
  LogOut, Bell, Search, Zap, AlertTriangle, CreditCard,
  ChevronRight, TrendingUp, TrendingDown,
  Shield, ArrowRight, PanelLeftClose, PanelLeftOpen,
  Circle, Settings, CheckCircle, RefreshCw,
  Send, LayoutDashboard, Sun, Moon, MapPin, ExternalLink, Menu, X, Inbox, Server,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth, useAlert, useTheme } from '../context/hooks';
import api from '../services/api';
import { acquireSocket, releaseSocket } from '../services/socket';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  BarChart, Bar, ResponsiveContainer, Legend,
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
import { Skeleton } from '../components/ui';
import logo from '../assets/Medifind_New_Logo-removebg-preview.png';

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

/* ─── Theme (CSS tokens — adapt to light/dark automatically) ───────────── */
const C = {
  sidebarBg: 'linear-gradient(175deg, var(--primary-dark) 0%, var(--primary) 70%, var(--primary-mid) 130%)',
  accent:    'var(--admin-accent)',
  border:    'var(--admin-border)',
  bg:        'var(--admin-bg)',
  white:     'var(--surface)',
  textMain:  'var(--admin-text-main)',
  textSub:   'var(--admin-text-sub)',
  textMuted: 'var(--admin-text-muted)',
  hover:     'var(--row-hover-bg)',
  headBg:    'var(--table-head-bg)',
};

const CARD = {
  background: C.white, borderRadius: '16px',
  border: `1px solid ${C.border}`,
  boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
  overflow: 'hidden',
};

/* ─── Responder type labels ─────────────────────────────────────────────── */
const RESPONDER_LABELS = {
  PARAMEDIC: 'Paramedic',
  RESCUE_OFFICER: 'Rescue Officer',
  EMT: 'EMT',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER: 'Volunteer',
};

/* ─── Nav items ─────────────────────────────────────────────────────────── */
const NAV = [
  { label: 'Overview', to: '/admin', Icon: BarChart3, exact: true },
  { label: 'User Management', to: '/admin/users', Icon: Users },
  { label: 'Verification Queue', to: '/admin/verify', Icon: UserCheck },
  { label: 'Responder Records', to: '/admin/records', Icon: CheckCircle },
  { label: 'SOS Logistics', to: '/admin/sos', Icon: Activity },
  { label: 'Subscriptions', to: '/admin/subscriptions', Icon: CreditCard, exact: true },
  { label: 'All Subscriptions', to: '/admin/subscriptions/all', Icon: CreditCard },
  { label: 'System Logs', to: '/admin/logs', Icon: History },
  { label: 'Comm Audit', to: '/admin/emails', Icon: Mail },
  { label: 'Notifications', to: '/admin/notifications', Icon: Bell },
  { label: 'Admin Inbox', to: '/admin/inbox', Icon: Inbox },
  { label: 'Platform Settings', to: '/admin/settings', Icon: Settings },
];

const NARROW_QUERY = '(max-width: 899px)';

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

/* ─── Health summary helper (shared by sidebar + overview) ─────────────── */
function summarizeHealth(health) {
  const services = health?.services ? Object.values(health.services) : [];
  if (services.length === 0) return null;
  const healthy = services.filter(s => s?.status === 'healthy').length;
  const anyDown = services.some(s => s?.status === 'down');
  const pct = Math.round((healthy / services.length) * 100);
  return {
    healthy, total: services.length, pct,
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
function Sidebar({ open, narrow, onToggle, onNavigate, onLogout, health, healthError }) {
  const { pathname } = useLocation();
  const W = open ? 248 : 68;
  const summary = summarizeHealth(health);

  const active = (item) =>
    item.exact ? pathname === item.to : pathname.startsWith(item.to);

  return (
    <motion.aside
      aria-label="Main navigation"
      animate={narrow ? { x: open ? 0 : -260, width: 248 } : { x: 0, width: W }}
      initial={false}
      transition={{ type: 'spring', stiffness: 320, damping: 32 }}
      style={{
        position: 'fixed', top: 0, left: 0, height: '100vh',
        background: C.sidebarBg,
        display: 'flex', flexDirection: 'column',
        zIndex: 300, overflow: 'hidden',
        boxShadow: '2px 0 20px rgba(3,41,60,0.22)',
        flexShrink: 0,
      }}
    >
      {/* ── Logo + toggle row ── */}
      <div style={{
        height: open ? '112px' : '72px',
        display: 'flex', alignItems: 'center',
        justifyContent: open ? 'space-between' : 'center',
        padding: open ? '0 14px 0 16px' : '0',
        borderBottom: '1px solid rgba(255,255,255,0.07)',
        flexShrink: 0,
      }}>
        {open && (
          <Link to="/admin" onClick={onNavigate} aria-label="MediFind admin home" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none' }}>
            <img
              src={logo} alt="MediFind"
              style={{
                height: '88px', objectFit: 'contain', display: 'block',
                maxWidth: '190px',
                filter: 'brightness(1.25) drop-shadow(0 2px 10px rgba(0,0,0,0.4))',
              }}
            />
          </Link>
        )}
        <button
          type="button"
          onClick={onToggle}
          aria-label={narrow ? 'Close navigation' : open ? 'Collapse sidebar' : 'Expand sidebar'}
          title={narrow ? 'Close navigation' : open ? 'Collapse sidebar' : 'Expand sidebar'}
          style={{
            width: '32px', height: '32px', borderRadius: '10px',
            background: 'rgba(255,255,255,0.08)',
            border: '1px solid rgba(255,255,255,0.12)',
            color: 'rgba(255,255,255,0.8)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', flexShrink: 0, transition: 'background 0.2s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.16)'}
          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
        >
          {narrow ? <X size={16} /> : open ? <PanelLeftClose size={16} /> : <PanelLeftOpen size={16} />}
        </button>
      </div>

      {/* ── Nav ── */}
      <nav style={{
        flex: 1, padding: open ? '14px 10px' : '14px 8px',
        display: 'flex', flexDirection: 'column', gap: '2px',
        overflowY: 'auto', overflowX: 'hidden',
      }}>
        {open && (
          <p style={{
            fontSize: '0.65rem', fontWeight: 800, letterSpacing: '0.16em',
            textTransform: 'uppercase', color: 'rgba(255,255,255,0.4)',
            padding: '0 8px', marginBottom: '8px',
          }}>Management</p>
        )}

        {NAV.map((item) => {
          const on = active(item);
          return (
            <Link
              key={item.to}
              to={item.to}
              onClick={onNavigate}
              aria-current={on ? 'page' : undefined}
              aria-label={!open ? item.label : undefined}
              title={!open ? item.label : undefined}
              style={{
                display: 'flex', alignItems: 'center',
                gap: open ? '10px' : '0',
                justifyContent: open ? 'flex-start' : 'center',
                padding: open ? '9px 12px' : '11px 0',
                borderRadius: '12px',
                background: on ? 'rgba(255,255,255,0.14)' : 'transparent',
                color: on ? '#FFFFFF' : 'rgba(255,255,255,0.62)',
                fontWeight: on ? 700 : 500,
                fontSize: '0.875rem',
                transition: 'all 0.15s',
                textDecoration: 'none',
                whiteSpace: 'nowrap', overflow: 'hidden',
                position: 'relative', flexShrink: 0,
                borderLeft: on && open ? '3px solid var(--primary-light)' : '3px solid transparent',
              }}
              onMouseEnter={e => { if (!on) { e.currentTarget.style.background = 'rgba(255,255,255,0.07)'; e.currentTarget.style.color = 'rgba(255,255,255,0.9)'; } }}
              onMouseLeave={e => { if (!on) { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = 'rgba(255,255,255,0.62)'; } }}
            >
              <item.Icon size={18} strokeWidth={on ? 2.5 : 2} style={{ flexShrink: 0 }} />
              {open && <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      {/* ── Footer ── */}
      <div style={{
        padding: open ? '12px 10px 16px' : '12px 8px 16px',
        borderTop: '1px solid rgba(255,255,255,0.06)',
        flexShrink: 0,
      }}>
        {/* Live system health (from /api/admin/health) */}
        {open ? (
          <div
            title={summary ? `${summary.healthy} of ${summary.total} services healthy` : undefined}
            style={{
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: '12px', padding: '10px 12px', marginBottom: '10px',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
              <span style={{ fontSize: '0.66rem', fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.5)' }}>System Health</span>
              <span style={{ fontSize: '0.75rem', fontWeight: 800, color: summary ? summary.color : 'rgba(255,255,255,0.5)' }}>
                {summary ? `${summary.healthy}/${summary.total}` : healthError ? 'N/A' : '…'}
              </span>
            </div>
            <div style={{ height: '3px', background: 'rgba(255,255,255,0.08)', borderRadius: '2px' }}>
              <div style={{ height: '100%', width: `${summary?.pct ?? 0}%`, background: summary?.color ?? 'transparent', borderRadius: '2px', transition: 'width 0.6s ease' }} />
            </div>
            <p style={{ fontSize: '0.68rem', color: 'rgba(255,255,255,0.55)', marginTop: '6px' }}>
              {summary ? summary.label : healthError ? 'Health check unavailable' : 'Checking services…'}
            </p>
          </div>
        ) : summary && (
          <div title={summary.label} style={{ display: 'flex', justifyContent: 'center', marginBottom: '10px' }}>
            <span style={{ width: '9px', height: '9px', borderRadius: '50%', background: summary.color }} />
          </div>
        )}

        {/* Sign out */}
        <button
          type="button"
          onClick={onLogout}
          aria-label="Sign out"
          title={!open ? 'Sign Out' : undefined}
          style={{
            display: 'flex', alignItems: 'center',
            gap: open ? '9px' : '0',
            justifyContent: open ? 'flex-start' : 'center',
            width: '100%', padding: open ? '10px 12px' : '11px 0',
            borderRadius: '12px',
            background: 'rgba(255,100,100,0.08)',
            border: '1px solid rgba(255,100,100,0.15)',
            color: '#FECACA', fontWeight: 700, fontSize: '0.875rem', // light red on the always-dark sidebar
            cursor: 'pointer', transition: 'all 0.15s', fontFamily: 'inherit',
          }}
          onMouseEnter={e => { e.currentTarget.style.background = 'rgba(255,100,100,0.18)'; e.currentTarget.style.color = '#FFFFFF'; }}
          onMouseLeave={e => { e.currentTarget.style.background = 'rgba(255,100,100,0.08)'; e.currentTarget.style.color = '#FECACA'; }}
        >
          <LogOut size={17} style={{ flexShrink: 0 }} />
          {open && 'Sign Out'}
        </button>
      </div>
    </motion.aside>
  );
}

/* Dropdown shell used by the header menus */
const dropdownStyle = (width, top = '52px') => ({
  position: 'absolute', top, right: 0, width, maxWidth: 'calc(100vw - 24px)',
  background: C.white, borderRadius: '16px', border: `1px solid ${C.border}`,
  boxShadow: 'var(--shadow-md)', zIndex: 1000, overflow: 'hidden',
});

const menuLinkStyle = {
  display: 'flex', alignItems: 'center', gap: '10px',
  padding: '12px 20px', fontSize: '0.85rem', color: C.textSub,
  textDecoration: 'none', transition: 'all 0.15s',
  background: 'transparent', border: 'none', width: '100%', textAlign: 'left',
  fontFamily: 'inherit', cursor: 'pointer',
};

/* ─── Root Dashboard ────────────────────────────────────────────────────── */
export default function Dashboard() {
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
  const profileRef = useRef(null);
  const seenNotifIds = useRef(new Set());

  const contentOffset = narrow ? 0 : (desktopOpen ? 248 : 68);

  // Users for global search
  useEffect(() => {
    api.get('/api/admin/users').then(res => {
      if (res.data?.success && Array.isArray(res.data.data)) setUsers(res.data.data);
    }).catch(err => console.error('Failed to load users for global search:', err));
  }, []);

  // System health — drives the sidebar indicator and the Overview health strip
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

  // Click outside / Escape closes dropdowns
  useEffect(() => {
    function handleClickOutside(event) {
      if (showNotifs && notifRef.current && !notifRef.current.contains(event.target)) setShowNotifs(false);
      if (showProfile && profileRef.current && !profileRef.current.contains(event.target)) setShowProfile(false);
      if (searchFocused && searchRef.current && !searchRef.current.contains(event.target)) setSearchFocused(false);
    }
    function handleEscape(event) {
      if (event.key === 'Escape') { setShowNotifs(false); setShowProfile(false); setSearchFocused(false); setMobileOpen(false); }
    }
    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleEscape);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleEscape);
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

  const adminInitial = user?.fullName?.charAt(0)?.toUpperCase() ?? 'A';
  const adminName = user?.fullName ?? 'System Administrator';

  const pageLabel = NAV.find(n =>
    n.exact ? location.pathname === n.to : location.pathname.startsWith(n.to)
  )?.label ?? 'Dashboard';

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
    navigate(target);
  };

  const toggleSidebar = () => (narrow ? setMobileOpen(o => !o) : setDesktopOpen(o => !o));

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: C.bg }}>
      <Sidebar
        open={narrow ? mobileOpen : desktopOpen}
        narrow={narrow}
        onToggle={toggleSidebar}
        onNavigate={() => narrow && setMobileOpen(false)}
        onLogout={handleLogout}
        health={health}
        healthError={healthError}
      />
      <AnimatePresence>
        {narrow && mobileOpen && (
          <motion.div
            key="backdrop"
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            onClick={() => setMobileOpen(false)}
            style={{ position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.45)', zIndex: 250 }}
          />
        )}
      </AnimatePresence>

      {/* ── Main ── */}
      <motion.div
        animate={{ marginLeft: contentOffset }}
        initial={false}
        transition={{ type: 'spring', stiffness: 320, damping: 32 }}
        style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, minHeight: '100vh' }}
      >
        {/* ── Top Bar ── */}
        <header style={{
          height: '64px',
          background: C.white,
          borderBottom: `1px solid ${C.border}`,
          display: 'flex', alignItems: 'center',
          justifyContent: 'space-between', gap: '12px',
          padding: narrow ? '0 12px' : '0 28px', position: 'sticky', top: 0, zIndex: 100,
          boxShadow: isDark ? '0 1px 3px rgba(0,0,0,0.2)' : '0 1px 3px rgba(12,99,126,0.06)',
        }}>
          {/* Left: menu (narrow) + breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
            {narrow && (
              <button
                type="button"
                onClick={() => setMobileOpen(true)}
                aria-label="Open navigation"
                style={{ width: '40px', height: '40px', borderRadius: '10px', background: C.bg, border: `1.5px solid ${C.border}`, color: C.textSub, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
              >
                <Menu size={18} />
              </button>
            )}
            <nav aria-label="Breadcrumb" className="mf-breadcrumb" style={{ display: 'flex', alignItems: 'center', gap: '10px', whiteSpace: 'nowrap' }}>
              <Shield size={16} color="var(--primary-light)" />
              <span style={{ fontSize: '0.8rem', color: C.textMuted, fontWeight: 600 }}>MediFind Admin</span>
              <ChevronRight size={14} color="var(--text-muted)" />
              <span style={{ fontSize: '0.8rem', color: C.textMain, fontWeight: 700 }}>{pageLabel}</span>
            </nav>
          </div>

          {/* Center: search */}
          <div ref={searchRef} role="search" style={{ position: 'relative', flex: '0 1 340px', minWidth: 0 }}>
            <Search style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.textMuted, pointerEvents: 'none' }} size={16} />
            <input
              type="text"
              placeholder="Search users or pages…"
              aria-label="Search users or pages"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onKeyDown={e => { if (e.key === 'Enter') submitSearch(); }}
              style={{
                width: '100%', height: '40px', paddingLeft: '38px', paddingRight: '12px',
                border: `1.5px solid ${searchFocused ? C.accent : C.border}`, borderRadius: '10px',
                background: 'var(--input-bg)', outline: 'none', fontSize: '0.875rem',
                fontFamily: 'inherit', color: C.textMain, transition: 'border 0.2s',
              }}
            />

            <AnimatePresence>
              {searchFocused && (
                <motion.div
                  initial={{ opacity: 0, y: 8, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 8, scale: 0.97 }}
                  style={{
                    position: 'absolute', top: '46px', left: 0, width: 'min(380px, calc(100vw - 24px))',
                    background: C.white, borderRadius: '12px', border: `1px solid ${C.border}`,
                    boxShadow: 'var(--shadow-md)', zIndex: 1000, overflow: 'hidden',
                    padding: '8px 0', display: 'flex', flexDirection: 'column', gap: '2px',
                  }}
                >
                  <div style={{ padding: '4px 14px 4px', fontSize: '0.68rem', fontWeight: 800, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                    Pages
                  </div>
                  {navMatches.length === 0 ? (
                    <div style={{ padding: '6px 16px', fontSize: '0.8rem', color: C.textMuted }}>No matching pages</div>
                  ) : navMatches.slice(0, 4).map(item => (
                    <Link
                      key={item.to}
                      to={item.to}
                      onClick={closeSearch}
                      style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '8px 16px', fontSize: '0.85rem', color: C.textSub, textDecoration: 'none' }}
                      onMouseEnter={e => e.currentTarget.style.background = C.hover}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                    >
                      <item.Icon size={14} color="var(--primary-light)" />
                      <span>{item.label}</span>
                    </Link>
                  ))}

                  {q && (
                    <>
                      <div style={{ padding: '8px 14px 4px', borderTop: `1px solid ${C.border}`, fontSize: '0.68rem', fontWeight: 800, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.06em', marginTop: '4px' }}>
                        Users &amp; Responders
                      </div>
                      {userMatches.length === 0 ? (
                        <div style={{ padding: '6px 16px', fontSize: '0.8rem', color: C.textMuted }}>No users match “{searchQuery.trim()}”</div>
                      ) : userMatches.slice(0, 5).map(u => (
                        <Link
                          key={u.id}
                          to={`/admin/users?search=${encodeURIComponent(u.email || u.fullName)}`}
                          onClick={closeSearch}
                          style={{ display: 'flex', flexDirection: 'column', padding: '8px 16px', fontSize: '0.85rem', color: C.textMain, textDecoration: 'none' }}
                          onMouseEnter={e => e.currentTarget.style.background = C.hover}
                          onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                        >
                          <span style={{ fontWeight: 700 }}>{u.fullName}</span>
                          <span style={{ fontSize: '0.74rem', color: C.textMuted }}>{u.email} &bull; {u.role}</span>
                        </Link>
                      ))}
                      <div style={{ padding: '6px 16px 2px', fontSize: '0.7rem', color: C.textMuted }}>
                        Press <kbd style={{ fontFamily: 'inherit', fontWeight: 700 }}>Enter</kbd> to search all users
                      </div>
                    </>
                  )}
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* Right: theme toggle + bell + user */}
          <div style={{ display: 'flex', alignItems: 'center', gap: narrow ? '8px' : '12px', position: 'relative', flexShrink: 0 }}>
            <button
              type="button"
              onClick={toggleTheme}
              aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              style={{
                width: '40px', height: '40px', borderRadius: '10px',
                background: C.bg, border: `1.5px solid ${C.border}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', color: isDark ? 'var(--warning)' : C.textMuted,
              }}
            >
              {isDark ? <Sun size={18} /> : <Moon size={18} />}
            </button>

            <div ref={notifRef} style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <button
                type="button"
                onClick={() => { setShowNotifs(s => !s); setUnread(0); }}
                aria-label={unread > 0 ? `Alerts, ${unread} new` : 'Alerts'}
                aria-expanded={showNotifs}
                title="Recent alerts"
                style={{
                  position: 'relative', width: '40px', height: '40px', borderRadius: '10px',
                  background: C.bg, border: `1.5px solid ${showNotifs ? C.accent : C.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  cursor: 'pointer', color: showNotifs ? C.accent : C.textMuted, transition: 'all 0.15s',
                }}
              >
                <Bell size={18} />
                {unread > 0 && (
                  <span style={{
                    position: 'absolute', top: '-5px', right: '-5px', minWidth: '18px', height: '18px',
                    padding: '0 5px', background: 'var(--sos)', color: 'white', borderRadius: '999px',
                    border: `2px solid ${C.white}`, fontSize: '0.62rem', fontWeight: 800,
                    display: 'flex', alignItems: 'center', justifyContent: 'center', lineHeight: 1,
                  }}>
                    {unread > 9 ? '9+' : unread}
                  </span>
                )}
              </button>

              <AnimatePresence>
                {showNotifs && (
                  <motion.div
                    initial={{ opacity: 0, y: 8, scale: 0.97 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 8, scale: 0.97 }}
                    style={dropdownStyle('340px', '55px')}
                  >
                    <div style={{ padding: '14px 18px', borderBottom: `1px solid ${C.border}`, background: C.headBg, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h4 style={{ margin: 0, fontSize: '0.9rem', fontWeight: 700, color: C.textMain }}>Recent Alerts</h4>
                      {notifs.length > 0 && (
                        <button type="button" onClick={() => setNotifs([])} title="Hide these alerts from this list (they remain in the Admin Inbox)"
                          style={{ fontSize: '0.75rem', fontWeight: 700, color: C.accent, background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>
                          Clear list
                        </button>
                      )}
                    </div>
                    <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                      {notifs.length === 0 ? (
                        <div style={{ padding: '36px 20px', textAlign: 'center', color: C.textMuted }}>
                          <Bell size={24} style={{ marginBottom: '10px', opacity: 0.3 }} />
                          <p style={{ fontSize: '0.85rem', margin: 0 }}>No recent alerts.</p>
                        </div>
                      ) : (
                        notifs.map((n, i) => (
                          <button
                            type="button"
                            key={n.id || i}
                            onClick={() => { navigate(notifRoute(n.type)); setShowNotifs(false); }}
                            style={{
                              display: 'block', width: '100%', textAlign: 'left', fontFamily: 'inherit',
                              padding: '12px 18px', border: 'none', background: 'transparent',
                              borderBottom: i < notifs.length - 1 ? `1px solid ${C.border}` : 'none',
                              cursor: 'pointer', transition: 'background 0.2s',
                            }}
                            onMouseEnter={e => e.currentTarget.style.background = C.hover}
                            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                          >
                            <div style={{ display: 'flex', gap: '12px' }}>
                              <div style={{
                                width: '8px', height: '8px', borderRadius: '50%',
                                background: isCriticalType(n.type) ? 'var(--sos)' : 'var(--primary-light)',
                                marginTop: '6px', flexShrink: 0,
                              }} />
                              <div style={{ minWidth: 0 }}>
                                <p style={{ margin: '0 0 2px 0', fontSize: '0.86rem', fontWeight: 700, color: C.textMain }}>{n.title || 'Alert'}</p>
                                {(n.body || n.message) && (
                                  <p style={{ margin: 0, fontSize: '0.78rem', color: C.textSub, lineHeight: 1.4, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                                    {n.body || n.message}
                                  </p>
                                )}
                                <p style={{ margin: '6px 0 0 0', fontSize: '0.7rem', color: C.textMuted }}>{notifTime(n)}</p>
                              </div>
                            </div>
                          </button>
                        ))
                      )}
                    </div>
                    <div style={{ padding: '12px', textAlign: 'center', borderTop: `1px solid ${C.border}`, background: C.headBg }}>
                      <Link to="/admin/inbox" onClick={() => setShowNotifs(false)} style={{ fontSize: '0.8rem', fontWeight: 700, color: C.accent, textDecoration: 'none' }}>Open Admin Inbox</Link>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            <div className="mf-hide-narrow" style={{ width: '1px', height: '28px', background: C.border }} />

            <div ref={profileRef} style={{ position: 'relative' }}>
              <button
                type="button"
                onClick={() => setShowProfile(s => !s)}
                aria-label="Account menu"
                aria-expanded={showProfile}
                style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', background: 'none', border: 'none', padding: 0, fontFamily: 'inherit' }}
              >
                <div className="mf-hide-narrow" style={{ textAlign: 'right' }}>
                  <p style={{ fontSize: '0.85rem', fontWeight: 700, color: C.textMain, lineHeight: 1.2 }}>{adminName}</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px', justifyContent: 'flex-end' }}>
                    <Circle size={7} fill="var(--success)" color="var(--success)" />
                    <span style={{ fontSize: '0.72rem', color: C.textMuted, fontWeight: 600 }}>Administrator</span>
                  </div>
                </div>
                <div style={{
                  width: '40px', height: '40px',
                  background: 'linear-gradient(135deg,var(--primary),var(--primary-mid))',
                  borderRadius: '11px', color: 'white',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 800, fontSize: '1rem', flexShrink: 0,
                }}>
                  {adminInitial}
                </div>
              </button>

              <AnimatePresence>
                {showProfile && (
                  <motion.div
                    initial={{ opacity: 0, y: 8, scale: 0.97 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 8, scale: 0.97 }}
                    style={dropdownStyle('280px')}
                  >
                    <div style={{ padding: '20px', background: 'linear-gradient(135deg,var(--primary),var(--primary-mid))', color: 'white', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                      <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.4rem', fontWeight: 800 }}>{adminInitial}</div>
                      <div style={{ textAlign: 'center' }}>
                        <p style={{ margin: 0, fontWeight: 700, fontSize: '1rem' }}>{adminName}</p>
                        {user?.email && <p style={{ margin: '2px 0 0 0', fontSize: '0.78rem', color: 'var(--primary-pale)', opacity: 0.9 }}>{user.email}</p>}
                      </div>
                      <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '20px', background: 'rgba(255,255,255,0.25)', color: 'white' }}>System Admin</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                      {[
                        { to: '/admin/settings', label: 'Platform Settings', Icon: Settings },
                        { to: '/admin/logs', label: 'System Logs', Icon: History },
                        { to: '/admin/inbox', label: 'Admin Inbox', Icon: Inbox },
                      ].map(item => (
                        <Link
                          key={item.to}
                          to={item.to}
                          onClick={() => setShowProfile(false)}
                          style={{ ...menuLinkStyle, borderBottom: `1px solid ${C.border}` }}
                          onMouseEnter={e => { e.currentTarget.style.background = C.hover; e.currentTarget.style.color = C.accent; }}
                          onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = C.textSub; }}
                        >
                          <item.Icon size={15} />
                          <span>{item.label}</span>
                        </Link>
                      ))}
                      <button
                        type="button"
                        onClick={() => { setShowProfile(false); handleLogout(); }}
                        style={{ ...menuLinkStyle, color: 'var(--sos)' }}
                        onMouseEnter={e => e.currentTarget.style.background = 'var(--tint-red)'}
                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                      >
                        <LogOut size={15} />
                        <span style={{ fontWeight: 700 }}>Sign Out</span>
                      </button>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </header>

        {/* ── Page Content ── */}
        <main style={{ flex: 1, padding: narrow ? '20px 14px' : '28px 32px', overflow: 'auto', background: C.bg }}>
          <AnimatePresence mode="wait">
            <Routes location={location} key={location.pathname}>
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
          </AnimatePresence>
        </main>
      </motion.div>
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
    <motion.div
      initial={{ opacity: 0, scale: 0.97 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.35 }}
      style={{
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        minHeight: '70vh', textAlign: 'center', padding: '2rem',
      }}
    >
      <div style={{ marginBottom: '1.5rem', opacity: 0.25 }}>
        <svg width="260" height="40" viewBox="0 0 260 40">
          <motion.polyline
            points="0,20 50,20 65,5 75,35 85,2 95,38 105,20 160,20 175,5 185,35 195,2 205,38 215,20 260,20"
            fill="none" stroke="var(--primary-light)" strokeWidth="2"
            initial={{ pathLength: 0 }} animate={{ pathLength: 1 }}
            transition={{ duration: 1.5, ease: 'easeInOut' }}
          />
        </svg>
      </div>

      <div style={{
        fontSize: '6rem', fontWeight: 900, lineHeight: 1,
        background: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-mid) 50%, var(--primary-light) 100%)',
        WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
        backgroundClip: 'text', letterSpacing: '-4px', marginBottom: '1rem',
      }}>
        404
      </div>

      <div style={{
        display: 'inline-flex', alignItems: 'center', gap: '6px',
        background: 'var(--tint-amber)', border: '1px solid var(--warning-border)',
        borderRadius: '999px', padding: '4px 14px', marginBottom: '1.25rem',
      }}>
        <AlertTriangle size={13} color="var(--warning-fg)" />
        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: 'var(--warning-fg)', textTransform: 'uppercase', letterSpacing: '0.07em' }}>
          Page Not Found
        </span>
      </div>

      <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-sub)', marginBottom: '0.6rem', letterSpacing: '-0.02em' }}>
        This admin page doesn't exist
      </h2>
      <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
        The URL{' '}
        <code style={{ background: 'var(--surface-raised)', padding: '2px 8px', borderRadius: '5px', fontSize: '0.82rem', color: 'var(--admin-accent)' }}>
          {location.pathname}
        </code>{' '}
        is not a valid admin page.
      </p>
      <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: '2rem' }}>
        Use the sidebar to navigate to a valid section.
      </p>

      <div style={{ display: 'flex', gap: '0.875rem', flexWrap: 'wrap', justifyContent: 'center', marginBottom: '2rem' }}>
        <button
          type="button"
          onClick={() => navigate(-1)}
          style={{
            display: 'flex', alignItems: 'center', gap: '6px',
            padding: '0.7rem 1.4rem', borderRadius: '10px',
            border: '1.5px solid var(--border)', background: 'var(--surface)',
            color: 'var(--text-sub)', fontWeight: 600, fontSize: '0.875rem',
            cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          ← Go Back
        </button>
        <button
          type="button"
          onClick={() => navigate('/admin', { replace: true })}
          style={{
            display: 'flex', alignItems: 'center', gap: '6px',
            padding: '0.7rem 1.6rem', borderRadius: '10px',
            background: 'linear-gradient(135deg, var(--primary), var(--primary-light))',
            border: 'none', color: 'white', fontWeight: 700, fontSize: '0.875rem',
            cursor: 'pointer', fontFamily: 'inherit',
            boxShadow: '0 4px 12px rgba(12,99,126,0.3)',
          }}
        >
          <LayoutDashboard size={15} /> Back to Dashboard
        </button>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <svg width="24" height="24" viewBox="0 0 24 24" style={{ transform: 'rotate(-90deg)', flexShrink: 0 }}>
          <circle cx="12" cy="12" r="9" fill="none" stroke="var(--border)" strokeWidth="2" />
          <circle cx="12" cy="12" r="9" fill="none" stroke="var(--primary-light)" strokeWidth="2"
            strokeDasharray={`${2 * Math.PI * 9}`}
            strokeDashoffset={`${2 * Math.PI * 9 * (1 - count / 8)}`}
            strokeLinecap="round"
            style={{ transition: 'stroke-dashoffset 0.9s linear' }}
          />
        </svg>
        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
          Redirecting to dashboard in <strong style={{ color: 'var(--text-sub)' }}>{count}s</strong>
        </span>
      </div>
    </motion.div>
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

function Overview({ health, healthError }) {
  const navigate = useNavigate();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
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

  const deltaLabel = (d) => {
    if (d == null || d === 0) return 'Live';
    return d > 0 ? `+${d}` : `${d}`;
  };
  const deltaUp = (d) => d == null || d >= 0;

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

  /* Real 14-day trend (daily totals) used as the Total Emergencies sparkline */
  const trendBars = analytics?.trend?.map(t => t.total) ?? null;
  const trendMax = trendBars ? Math.max(1, ...trendBars) : 1;

  const d = statsDelta;
  const cards = stats ? [
    {
      label: 'Total Users', value: stats.totalUsers,
      trend: deltaLabel(d?.totalUsers), up: deltaUp(d?.totalUsers),
      Icon: Users, accent: 'var(--primary)', pale: 'var(--tint-teal)',
      sub: 'Registered accounts',
      to: '/admin/users?role=ALL',
    },
    {
      label: 'Active Emergencies', value: stats.activeEmergencies,
      trend: 'LIVE', up: null,
      Icon: Activity, accent: 'var(--sos)', pale: 'var(--tint-red)',
      sub: 'Ongoing SOS events',
      to: '/admin/sos?filter=ACTIVE',
    },
    {
      label: 'Total Emergencies', value: stats.totalEmergencies,
      trend: deltaLabel(d?.totalEmergencies), up: deltaUp(d?.totalEmergencies),
      Icon: AlertTriangle, accent: 'var(--warning)', pale: 'var(--tint-amber)',
      sub: 'All-time SOS events',
      to: '/admin/sos?filter=ALL',
      spark: trendBars,
    },
    {
      label: 'Verified Responders', value: stats.onlineResponders,
      trend: deltaLabel(d?.onlineResponders), up: deltaUp(d?.onlineResponders),
      Icon: Zap, accent: 'var(--success)', pale: 'var(--tint-green)',
      sub: 'Approved to respond',
      to: '/admin/records',
    },
  ] : Array(4).fill(null);

  const quickActions = [
    {
      label: 'Verify Responders',
      desc: pendingCount != null ? `${pendingCount} awaiting review` : 'Review credentials',
      Icon: UserCheck, accent: 'var(--success)', pale: 'var(--tint-green)',
      to: '/admin/verify',
      badge: pendingCount > 0 ? pendingCount : null,
    },
    {
      label: 'Live SOS Monitor',
      desc: stats ? `${stats.activeEmergencies} active now` : 'Track emergencies',
      Icon: Activity, accent: 'var(--sos)', pale: 'var(--tint-red)',
      to: '/admin/sos',
      badge: stats?.activeEmergencies > 0 ? stats.activeEmergencies : null,
      pulse: stats?.activeEmergencies > 0,
    },
    {
      label: 'User Management',
      desc: stats ? `${stats.totalUsers} registered users` : 'Manage all users',
      Icon: Users, accent: 'var(--primary)', pale: 'var(--tint-teal)',
      to: '/admin/users',
    },
    {
      label: 'Send Notification',
      desc: 'Broadcast to users',
      Icon: Send, accent: 'var(--primary-mid)', pale: 'var(--tint-blue)',
      to: '/admin/notifications',
    },
    {
      label: 'Subscriptions',
      desc: 'Plans & billing',
      Icon: CreditCard, accent: 'var(--warning)', pale: 'var(--tint-amber)',
      to: '/admin/subscriptions',
    },
    {
      label: 'System Logs',
      desc: 'Audit trail',
      Icon: History, accent: 'var(--text-muted)', pale: 'var(--tint-slate)',
      to: '/admin/logs',
    },
  ];

  const mapCenter = mapEmergencies.length > 0
    ? [
        mapEmergencies.reduce((s, e) => s + (e.latitude  || 30.3753), 0) / mapEmergencies.length,
        mapEmergencies.reduce((s, e) => s + (e.longitude || 69.3451), 0) / mapEmergencies.length,
      ]
    : [30.3753, 69.3451];
  const mapZoom   = mapEmergencies.length > 0 ? 11 : 5;
  // Popup re-appears automatically when the number of active SOS changes after a dismiss
  const showPopup = mapEmergencies.length > 0 && dismissedAtCount !== mapEmergencies.length;
  // Recharts writes these as SVG attributes, so use literal slate values of --border (light / dark)
  const gridStroke = isDark ? '#334155' : '#E2E8F0';
  const tooltipStyle = { borderRadius: '10px', border: `1px solid ${C.border}`, background: C.white, color: C.textMain, fontSize: '0.78rem', fontFamily: 'inherit' };

  const sectionHeader = (title, subtitle, right) => (
    <div style={{ padding: '16px 22px', borderBottom: `1px solid ${C.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px' }}>
      <div style={{ minWidth: 0 }}>
        <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>{title}</h3>
        {subtitle && <p style={{ fontSize: '0.78rem', color: C.textMuted, marginTop: '2px' }}>{subtitle}</p>}
      </div>
      {right}
    </div>
  );

  const sectionError = (text) => (
    <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.textMuted, fontSize: '0.84rem', textAlign: 'center', padding: '0 16px' }}>
      {text}
    </div>
  );

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.3 }}
    >
      {/* ── Emergency popup reminder ── */}
      <AnimatePresence>
        {showPopup && (
          <motion.div
            role="alert"
            initial={{ x: 140, opacity: 0, scale: 0.88 }}
            animate={{ x: 0, opacity: 1, scale: 1 }}
            exit={{ x: 140, opacity: 0, scale: 0.88 }}
            transition={{ type: 'spring', stiffness: 330, damping: 30 }}
            style={{
              position: 'fixed', bottom: '24px', right: '24px', zIndex: 600,
              background: C.white, border: '1.5px solid var(--error-border)',
              borderRadius: '16px', boxShadow: '0 12px 40px rgba(239,68,68,0.25)',
              padding: '12px 14px', display: 'flex', alignItems: 'center', gap: '10px',
              minWidth: '240px',
            }}
          >
            <motion.div
              animate={{ scale: [1, 1.45, 1] }}
              transition={{ repeat: Infinity, duration: 1.25, ease: 'easeInOut' }}
              style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'var(--sos)', flexShrink: 0 }}
            />
            <button
              type="button"
              onClick={() => mapSectionRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
              style={{ flex: 1, textAlign: 'left', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit', padding: 0 }}
            >
              <span style={{ display: 'block', fontWeight: 800, color: 'var(--error-fg)', fontSize: '0.875rem' }}>
                {mapEmergencies.length} Active SOS Alert{mapEmergencies.length > 1 ? 's' : ''}
              </span>
              <span style={{ display: 'block', fontSize: '0.73rem', color: C.textMuted }}>View on live map ↓</span>
            </button>
            <button
              type="button"
              aria-label="Dismiss SOS reminder"
              onClick={() => setDismissedAtCount(mapEmergencies.length)}
              style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--sos)', padding: '2px', display: 'flex' }}
            >
              <X size={16} />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Page header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', gap: '16px', flexWrap: 'wrap', marginBottom: '20px' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: C.textMain, letterSpacing: '-0.02em', marginBottom: '4px' }}>
            Infrastructure Pulse
          </h1>
          <p style={{ color: C.textMuted, fontSize: '0.92rem' }}>
            Real-time status of the MediFind emergency response network.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          {lastUpdated && (
            <span style={{ fontSize: '0.76rem', color: C.textMuted, fontWeight: 600 }}>
              Updated {lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
            </span>
          )}
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: '8px',
            padding: '8px 12px', borderRadius: '10px',
            background: 'var(--tint-green)', border: '1px solid var(--success-border)',
            fontSize: '0.76rem', fontWeight: 700, color: 'var(--success-fg)',
          }}>
            <motion.span
              animate={{ opacity: [1, 0.3, 1] }}
              transition={{ repeat: Infinity, duration: 2 }}
              style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--success)' }}
            />
            Auto-refresh 15s
          </span>
          <button
            type="button"
            onClick={handleRefresh}
            disabled={refreshing}
            style={{
              display: 'flex', alignItems: 'center', gap: '7px',
              padding: '8px 14px', borderRadius: '10px',
              border: `1.5px solid ${C.border}`, background: C.white,
              color: C.textSub, fontWeight: 700, cursor: refreshing ? 'wait' : 'pointer',
              fontSize: '0.82rem', fontFamily: 'inherit',
            }}
          >
            <RefreshCw size={14} style={{ animation: refreshing ? 'spin 1s linear infinite' : 'none' }} />
            Refresh
          </button>
        </div>
      </div>

      {/* Partial / total failure banner */}
      {!loading && failedKeys.length > 0 && (
        <div role="alert" style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap',
          padding: '12px 16px', background: 'var(--warning-bg)', border: '1px solid var(--warning-border)',
          borderRadius: '12px', color: 'var(--warning-fg)', fontSize: '0.875rem', fontWeight: 600, marginBottom: '18px',
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={16} />
            {allFailed
              ? 'Unable to reach the backend — check that the API server is running.'
              : `Some sections could not be loaded: ${failedKeys.map(k => SECTION_LABELS[k]).join(', ')}.`}
          </span>
          <button type="button" onClick={handleRefresh} style={{ background: 'none', border: '1px solid currentColor', color: 'inherit', borderRadius: '8px', padding: '4px 12px', fontWeight: 700, fontSize: '0.78rem', fontFamily: 'inherit' }}>
            Retry
          </button>
        </div>
      )}

      {/* ── System health strip ── */}
      <HealthStrip health={health} error={healthError} />

      {/* ── Stat Cards ── */}
      <div className="mf-grid-stats" style={{ marginBottom: '20px' }}>
        {cards.map((card, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.06 }}
            whileHover={card ? { y: -3 } : undefined}
            role={card?.to ? 'link' : undefined}
            tabIndex={card?.to ? 0 : undefined}
            aria-label={card ? `${card.label}: ${card.value}` : undefined}
            onClick={() => card?.to && navigate(card.to)}
            onKeyDown={e => { if (card?.to && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); navigate(card.to); } }}
            style={{ ...CARD, position: 'relative', cursor: card?.to ? 'pointer' : 'default', display: 'flex', flexDirection: 'column' }}
          >
            {loading || !card ? (
              <div style={{ padding: '20px' }}>
                {failed.stats && !loading ? (
                  <p style={{ fontSize: '0.82rem', color: C.textMuted }}>Statistics unavailable</p>
                ) : (
                  <>
                    <Skeleton h={14} w="50%" mb={12} />
                    <Skeleton h={32} w="40%" mb={10} />
                    <Skeleton h={10} w="60%" />
                  </>
                )}
              </div>
            ) : (
              <>
                <div style={{ height: '4px', background: card.accent }} />
                <div style={{ padding: '18px 20px 20px', flex: 1, display: 'flex', flexDirection: 'column' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
                    <div style={{
                      width: '42px', height: '42px', borderRadius: '12px',
                      background: card.pale, color: card.accent,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <card.Icon size={20} strokeWidth={2.5} />
                    </div>
                    {card.trend === 'LIVE' ? (
                      <div style={{
                        display: 'flex', alignItems: 'center', gap: '5px',
                        padding: '4px 10px', borderRadius: '20px',
                        background: 'var(--tint-red)', border: '1px solid var(--error-border)',
                      }}>
                        <motion.div
                          animate={{ opacity: [1, 0.2, 1] }}
                          transition={{ repeat: Infinity, duration: 1.4 }}
                          style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--sos)' }}
                        />
                        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: 'var(--sos)', letterSpacing: '0.05em' }}>LIVE</span>
                      </div>
                    ) : (
                      <div
                        title={card.trend === 'Live' ? 'No change since last refresh' : 'Change since last refresh'}
                        style={{
                          display: 'flex', alignItems: 'center', gap: '4px',
                          padding: '4px 10px', borderRadius: '20px',
                          background: card.up ? 'var(--tint-green)' : 'var(--tint-red)',
                          border: `1px solid ${card.up ? 'var(--success-border)' : 'var(--error-border)'}`,
                        }}
                      >
                        {card.up ? <TrendingUp size={12} color="var(--success-fg)" /> : <TrendingDown size={12} color="var(--error-fg)" />}
                        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: card.up ? 'var(--success-fg)' : 'var(--error-fg)' }}>{card.trend}</span>
                      </div>
                    )}
                  </div>
                  <p style={{ fontSize: '1.75rem', fontWeight: 800, color: C.textMain, letterSpacing: '-0.02em', lineHeight: 1, marginBottom: '6px' }}>
                    {typeof card.value === 'number' ? card.value.toLocaleString() : (card.value ?? '—')}
                  </p>
                  <p style={{ fontSize: '0.86rem', fontWeight: 700, color: C.textSub, marginBottom: '2px' }}>{card.label}</p>
                  <p style={{ fontSize: '0.76rem', color: C.textMuted }}>{card.sub}</p>
                  {card.spark && card.spark.length > 0 && (
                    <div style={{ marginTop: 'auto', paddingTop: '14px' }} title="Emergencies per day, last 14 days">
                      <div style={{ display: 'flex', alignItems: 'flex-end', gap: '3px', height: '28px' }}>
                        {card.spark.map((v, j) => (
                          <div key={j} style={{
                            flex: 1, height: `${Math.max(6, (v / trendMax) * 100)}%`, borderRadius: '3px',
                            background: j === card.spark.length - 1 ? card.accent : `color-mix(in srgb, ${card.accent} 25%, transparent)`,
                          }} />
                        ))}
                      </div>
                      <p style={{ fontSize: '0.66rem', color: C.textMuted, marginTop: '4px' }}>Last 14 days</p>
                    </div>
                  )}
                </div>
              </>
            )}
          </motion.div>
        ))}
      </div>

      {/* ── Quick Actions ── */}
      <div style={{ ...CARD, marginBottom: '20px' }}>
        {sectionHeader('Quick Actions', 'Most-used admin tasks — one click to navigate', <LayoutDashboard size={18} color="var(--text-muted)" />)}
        <div className="mf-grid-actions">
          {quickActions.map((qa) => (
            <Link
              key={qa.to}
              to={qa.to}
              style={{
                padding: '18px 16px', textDecoration: 'none',
                display: 'flex', flexDirection: 'column', gap: '10px',
                position: 'relative', transition: 'background 0.15s',
                borderRight: `1px solid ${C.border}`, borderBottom: `1px solid ${C.border}`,
                marginRight: '-1px', marginBottom: '-1px',
              }}
              onMouseEnter={e => e.currentTarget.style.background = C.hover}
              onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
            >
              {qa.badge != null && (
                <span style={{
                  position: 'absolute', top: '10px', right: '10px',
                  minWidth: '20px', height: '20px', borderRadius: '10px',
                  background: 'var(--sos)', color: 'white',
                  fontSize: '0.66rem', fontWeight: 800,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  padding: '0 5px',
                }}>
                  {qa.pulse && (
                    <motion.span
                      animate={{ scale: [1, 1.5, 1], opacity: [0.35, 0, 0.35] }}
                      transition={{ repeat: Infinity, duration: 1.8 }}
                      style={{ position: 'absolute', inset: -3, borderRadius: '50%', background: 'var(--sos)' }}
                    />
                  )}
                  {qa.badge}
                </span>
              )}
              <div style={{
                width: '42px', height: '42px', borderRadius: '12px',
                background: qa.pale, color: qa.accent,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <qa.Icon size={19} strokeWidth={2.5} />
              </div>
              <div>
                <p style={{ fontSize: '0.85rem', fontWeight: 700, color: C.textMain }}>{qa.label}</p>
                <p style={{ fontSize: '0.75rem', color: C.textMuted, marginTop: '3px', lineHeight: 1.4 }}>{qa.desc}</p>
              </div>
              <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: qa.accent, fontSize: '0.74rem', fontWeight: 700 }}>
                Open <ArrowRight size={11} />
              </span>
            </Link>
          ))}
        </div>
      </div>

      {/* ── Pending Verification Queue ── */}
      <div style={{ ...CARD, marginBottom: '20px' }}>
        <div style={{
          padding: '16px 22px', borderBottom: `1px solid ${C.border}`,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap',
          background: pendingResponders.length > 0 ? 'var(--tint-amber)' : C.white,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '38px', height: '38px', borderRadius: '10px',
              background: pendingResponders.length > 0 ? 'var(--warning-bg)' : 'var(--tint-green)',
              color: pendingResponders.length > 0 ? 'var(--warning-fg)' : 'var(--success)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <UserCheck size={18} strokeWidth={2.5} />
            </div>
            <div>
              <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain, display: 'flex', alignItems: 'center', gap: '8px' }}>
                Pending Verification Queue
                {pendingResponders.length > 0 && (
                  <span style={{ background: 'var(--sos)', color: 'white', fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '20px', lineHeight: 1.5 }}>
                    {pendingResponders.length} pending
                  </span>
                )}
              </h3>
              <p style={{ fontSize: '0.8rem', color: C.textMuted, marginTop: '2px' }}>
                Emergency responders awaiting credential review and activation
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => navigate('/admin/verify')}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 16px', borderRadius: '10px',
              background: 'var(--primary-light)', color: 'white', border: 'none',
              fontWeight: 700, cursor: 'pointer', fontSize: '0.83rem', fontFamily: 'inherit',
            }}
          >
            <UserCheck size={14} /> Open Queue
          </button>
        </div>

        {loading ? (
          <div style={{ padding: '20px 24px' }}>
            {Array(3).fill(null).map((_, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: i < 2 ? '16px' : 0 }}>
                <Skeleton h={40} w="40px" br={20} />
                <div style={{ flex: 1 }}>
                  <Skeleton h={13} w="30%" mb={7} />
                  <Skeleton h={10} w="50%" />
                </div>
                <Skeleton h={30} w="70px" br={8} />
              </div>
            ))}
          </div>
        ) : failed.pending ? (
          <div style={{ padding: '32px 24px', textAlign: 'center', color: C.textMuted, fontSize: '0.86rem' }}>
            Could not load the verification queue.
          </div>
        ) : pendingResponders.length === 0 ? (
          <div style={{ padding: '36px 24px', textAlign: 'center' }}>
            <CheckCircle size={40} style={{ color: 'var(--success)', opacity: 0.5, marginBottom: '10px' }} />
            <p style={{ fontWeight: 700, fontSize: '0.95rem', color: C.textSub, marginBottom: '4px' }}>Queue is clear</p>
            <p style={{ fontSize: '0.84rem', color: C.textMuted }}>No responders are currently awaiting verification.</p>
          </div>
        ) : (
          <div className="mf-table-scroll">
            <div style={{ minWidth: '640px' }}>
              <div style={{
                display: 'grid', gridTemplateColumns: '2fr 1.2fr 1.2fr 1fr 100px',
                padding: '10px 24px', background: C.headBg,
                borderBottom: `1px solid ${C.border}`,
                fontSize: '0.7rem', fontWeight: 800, color: C.textMuted,
                textTransform: 'uppercase', letterSpacing: '0.08em',
              }}>
                <span>Responder</span>
                <span>Type</span>
                <span>Organization</span>
                <span>Applied</span>
                <span style={{ textAlign: 'right' }}>Action</span>
              </div>
              {pendingResponders.slice(0, 6).map((r, i) => (
                <div
                  key={r.id || i}
                  className="mf-table-row"
                  style={{
                    display: 'grid', gridTemplateColumns: '2fr 1.2fr 1.2fr 1fr 100px',
                    padding: '13px 24px', alignItems: 'center',
                    borderBottom: i < Math.min(pendingResponders.length, 6) - 1 ? `1px solid ${C.border}` : 'none',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '11px', minWidth: 0 }}>
                    <div style={{
                      width: '38px', height: '38px', borderRadius: '50%',
                      background: 'var(--tint-teal)', border: '1.5px solid rgba(40,145,194,0.2)', color: 'var(--primary-light)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontWeight: 800, fontSize: '0.95rem', flexShrink: 0,
                    }}>
                      {(r.user?.fullName ?? r.fullName ?? '?')[0].toUpperCase()}
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <p style={{ fontWeight: 700, fontSize: '0.875rem', color: C.textMain, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {r.user?.fullName ?? r.fullName ?? '—'}
                      </p>
                      <p style={{ fontSize: '0.74rem', color: C.textMuted, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {r.user?.email ?? r.email ?? '—'}
                      </p>
                    </div>
                  </div>
                  <div>
                    <span style={{ background: 'var(--tint-blue)', color: 'var(--primary-mid)', padding: '3px 10px', borderRadius: '20px', fontSize: '0.74rem', fontWeight: 700, display: 'inline-block' }}>
                      {RESPONDER_LABELS[r.responderType] ?? r.responderType ?? 'Responder'}
                    </span>
                  </div>
                  <p style={{ fontSize: '0.84rem', color: C.textSub, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {r.organization ?? '—'}
                  </p>
                  <p style={{ fontSize: '0.8rem', color: C.textMuted }}>
                    {r.createdAt ? new Date(r.createdAt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: '2-digit' }) : '—'}
                  </p>
                  <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                    <button
                      type="button"
                      onClick={() => navigate('/admin/verify')}
                      aria-label={`Review ${r.user?.fullName ?? 'responder'}`}
                      style={{
                        padding: '6px 14px', borderRadius: '8px',
                        background: 'var(--primary-light)', color: 'white', border: 'none',
                        fontWeight: 700, fontSize: '0.78rem', cursor: 'pointer',
                        fontFamily: 'inherit', display: 'flex', alignItems: 'center', gap: '4px',
                      }}
                    >
                      Review <ArrowRight size={11} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
            {pendingResponders.length > 6 && (
              <div style={{ padding: '12px 24px', textAlign: 'center', borderTop: `1px solid ${C.border}`, background: C.headBg }}>
                <Link to="/admin/verify" style={{ color: C.accent, fontWeight: 700, fontSize: '0.84rem', display: 'inline-flex', alignItems: 'center', gap: '5px' }}>
                  View {pendingResponders.length - 6} more in Verification Queue <ArrowRight size={13} />
                </Link>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Analytics Charts ── */}
      <div className="mf-grid-main-side" style={{ marginBottom: '20px' }}>
        <div style={CARD}>
          {sectionHeader('Emergency Trend', analytics?.period ?? 'Last 14 days', (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '4px 10px', background: 'var(--tint-teal)', borderRadius: '8px', whiteSpace: 'nowrap' }}>
              <Activity size={12} color="var(--primary-light)" />
              <span style={{ fontSize: '0.74rem', fontWeight: 700, color: C.accent }}>{analytics?.totalInPeriod ?? 0} total</span>
            </div>
          ))}
          <div style={{ padding: '16px 8px 8px' }}>
            {loading ? (
              <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Skeleton h={160} w="95%" />
              </div>
            ) : !analytics ? sectionError('Emergency analytics are unavailable right now.') : (
              <ResponsiveContainer width="100%" height={180}>
                <AreaChart data={analytics.trend} margin={{ top: 4, right: 16, left: -16, bottom: 0 }}>
                  <defs>
                    <linearGradient id="gradResolved" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="var(--success)" stopOpacity={0.18} />
                      <stop offset="95%" stopColor="var(--success)" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gradTotal" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="var(--primary-light)" stopOpacity={0.14} />
                      <stop offset="95%" stopColor="var(--primary-light)" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} />
                  <XAxis dataKey="date" tick={{ fontSize: 10, fill: 'var(--text-muted)' }}
                    tickFormatter={v => { const dt = new Date(v); return `${dt.getDate()}/${dt.getMonth() + 1}`; }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: 'var(--text-muted)' }} />
                  <Tooltip
                    contentStyle={tooltipStyle}
                    labelFormatter={v => new Date(v).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })}
                  />
                  <Legend wrapperStyle={{ fontSize: '0.72rem', paddingTop: '8px' }} />
                  <Area type="monotone" dataKey="total"     name="Total"     stroke="var(--primary-light)" fill="url(#gradTotal)"    strokeWidth={2} dot={false} />
                  <Area type="monotone" dataKey="resolved"  name="Resolved"  stroke="var(--success)" fill="url(#gradResolved)" strokeWidth={2} dot={false} />
                  <Area type="monotone" dataKey="cancelled" name="Cancelled" stroke="var(--sos)" fill="none" strokeWidth={1.5} strokeDasharray="4 3" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        <div style={CARD}>
          {sectionHeader('By Type', 'Top emergency categories (14 days)')}
          <div style={{ padding: '16px 8px 8px' }}>
            {loading ? (
              <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Skeleton h={160} w="90%" />
              </div>
            ) : !analytics ? sectionError('Unavailable') : analytics.typeBreakdown.length === 0 ? (
              sectionError('No emergencies in this period')
            ) : (
              <ResponsiveContainer width="100%" height={180}>
                <BarChart data={analytics.typeBreakdown.slice(0, 6)} layout="vertical"
                  margin={{ top: 0, right: 16, left: 8, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 10, fill: 'var(--text-muted)' }} />
                  <YAxis type="category" dataKey="type" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} width={70} />
                  <Tooltip contentStyle={tooltipStyle} cursor={{ fill: isDark ? 'rgba(255,255,255,0.04)' : 'rgba(12,99,126,0.05)' }} />
                  <Bar dataKey="count" name="Count" fill="var(--primary-light)" radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>

      {/* ── Bottom Row ── */}
      <div className="mf-grid-main-side">
        {/* ── SOS Live Map ── */}
        <div ref={mapSectionRef} style={{ ...CARD, display: 'flex', flexDirection: 'column' }}>
          {sectionHeader(
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
              <MapPin size={16} color="var(--sos)" /> SOS Live Map
              {mapEmergencies.length > 0 && (
                <span style={{ fontSize: '0.7rem', fontWeight: 800, color: 'var(--sos)', background: 'var(--tint-red)', padding: '2px 8px', borderRadius: '20px' }}>
                  {mapEmergencies.length} SOS
                </span>
              )}
            </span>,
            'Active emergencies & available responder positions',
            <Link
              to="/admin/sos"
              style={{
                display: 'flex', alignItems: 'center', gap: '5px', whiteSpace: 'nowrap',
                fontSize: '0.78rem', fontWeight: 700, color: C.accent,
                background: 'var(--tint-teal)', border: `1px solid ${C.border}`,
                borderRadius: '8px', padding: '6px 12px',
              }}
            >
              Full Monitor <ExternalLink size={12} />
            </Link>,
          )}

          <div style={{ flex: 1, position: 'relative', isolation: 'isolate', zIndex: 0 }}>
            <MapContainer
              key={mapCenter.join(',')}
              center={mapCenter}
              zoom={mapZoom}
              style={{ height: '330px', width: '100%' }}
              scrollWheelZoom={false}
              zoomControl
              attributionControl={false}
            >
              <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

              {mapEmergencies.map(e => e.latitude && e.longitude && (
                <React.Fragment key={e.id}>
                  <MapCircle center={[e.latitude, e.longitude]} radius={300} color="var(--sos)" fillColor="var(--sos)" fillOpacity={0.12} />
                  <Marker position={[e.latitude, e.longitude]} icon={redMapIcon}>
                    <Popup>
                      <div style={{ minWidth: '160px' }}>
                        <strong style={{ color: 'var(--sos)', fontSize: '12px', display: 'block', marginBottom: '4px' }}>
                          {e.emergencyType || 'Medical'} Emergency
                        </strong>
                        <p style={{ margin: '0 0 2px', fontSize: '12px', fontWeight: 600 }}>
                          {e.patient?.fullName || 'Unknown Patient'}
                        </p>
                        <p style={{ margin: 0, fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
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
                    <div style={{ minWidth: '150px' }}>
                      <strong style={{ color: 'var(--success-fg)', fontSize: '12px', display: 'block', marginBottom: '4px' }}>
                        {r.user?.fullName || 'Responder'}
                      </strong>
                      <p style={{ margin: 0, fontSize: '11px', color: 'var(--text-muted)' }}>
                        {r.responderType?.replace(/_/g, ' ') || 'Responder'}
                      </p>
                    </div>
                  </Popup>
                </Marker>
              ))}
            </MapContainer>
          </div>

          <div style={{
            padding: '10px 22px', borderTop: `1px solid ${C.border}`,
            display: 'flex', alignItems: 'center', gap: '16px', flexWrap: 'wrap',
            flexShrink: 0, background: C.headBg,
          }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.74rem', color: 'var(--sos)', fontWeight: 700 }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--sos)' }} />
              SOS ({mapEmergencies.length})
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.74rem', color: 'var(--success-fg)', fontWeight: 700 }}>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--success)' }} />
              Responders ({mapResponders.length})
            </span>
            <span style={{ fontSize: '0.7rem', color: C.textMuted }}>Auto-refresh 10s</span>
          </div>
        </div>

        {/* ── Subscription Revenue ── */}
        <SubscriptionRevenueCard subStats={subStats} loading={loading} unavailable={failed.subs} />
      </div>
    </motion.div>
  );
}

/* ─── Subscription revenue card ─────────────────────────────────────────── */
const PLAN_PRICE_PKR = { PROFESSIONAL: 499, EXECUTIVE: 2499 };

function SubscriptionRevenueCard({ subStats, loading, unavailable }) {
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
    { label: 'Executive',    count: execCount, rev: execRev, color: 'var(--primary)', pct: total > 0 ? (execCount / total * 100) : 0 },
    { label: 'Professional', count: proCount,  rev: proRev,  color: 'var(--primary-mid)', pct: total > 0 ? (proCount / total * 100)  : 0 },
    { label: 'Free',         count: freeCount, rev: 0,       color: 'var(--text-muted)', pct: total > 0 ? (freeCount / total * 100) : 0 },
  ];

  return (
    <div style={{ ...CARD, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '16px 22px', borderBottom: `1px solid ${C.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>Subscription Revenue</h3>
          <p style={{ fontSize: '0.76rem', color: C.textMuted, marginTop: '2px' }}>Estimated from current plans</p>
        </div>
        <Link to="/admin/subscriptions/all" style={{ fontSize: '0.76rem', fontWeight: 700, color: C.accent, textDecoration: 'none', whiteSpace: 'nowrap' }}>
          View All →
        </Link>
      </div>

      {loading ? (
        <div style={{ padding: '16px 20px' }}>
          <Skeleton h={96} br={14} mb={14} />
          <Skeleton h={12} w="70%" mb={10} />
          <Skeleton h={12} w="60%" mb={10} />
          <Skeleton h={12} w="50%" />
        </div>
      ) : unavailable ? (
        <div style={{ padding: '32px 20px', textAlign: 'center', color: C.textMuted, fontSize: '0.84rem' }}>
          Subscription data is unavailable right now.
        </div>
      ) : (
        <div style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div style={{ background: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-mid) 100%)', borderRadius: '14px', padding: '18px 20px', color: '#fff' }}>
            <p style={{ fontSize: '0.7rem', fontWeight: 600, opacity: 0.8, letterSpacing: '0.06em', textTransform: 'uppercase', marginBottom: '6px' }}>Monthly Recurring Revenue</p>
            <p style={{ fontSize: '1.7rem', fontWeight: 900, letterSpacing: '-0.02em', lineHeight: 1 }}>{fmtPKR(mrr)}</p>
            <div style={{ display: 'flex', gap: '16px', marginTop: '12px' }}>
              {[['Paid Users', paidCount], ['Conversion', `${convRate}%`], ['Total Users', total]].map(([label, val], i) => (
                <React.Fragment key={label}>
                  {i > 0 && <div style={{ width: '1px', background: 'rgba(255,255,255,0.2)' }} />}
                  <div>
                    <p style={{ fontSize: '0.66rem', opacity: 0.75 }}>{label}</p>
                    <p style={{ fontSize: '1rem', fontWeight: 800 }}>{val}</p>
                  </div>
                </React.Fragment>
              ))}
            </div>
          </div>

          {planRows.map((row) => (
            <div key={row.label}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '5px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: row.color }} />
                  <span style={{ fontSize: '0.8rem', fontWeight: 700, color: C.textMain }}>{row.label}</span>
                  <span style={{ fontSize: '0.7rem', color: C.textMuted, background: 'var(--tint-slate)', padding: '1px 7px', borderRadius: '10px' }}>{row.count} users</span>
                </div>
                <span style={{ fontSize: '0.8rem', fontWeight: 700, color: row.rev > 0 ? row.color : C.textMuted }}>
                  {row.rev > 0 ? fmtPKR(row.rev) : '—'}
                </span>
              </div>
              <div style={{ height: '5px', background: 'var(--tint-slate)', borderRadius: '99px', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${row.pct}%`, background: row.color, borderRadius: '99px', transition: 'width 0.6s ease' }} />
              </div>
            </div>
          ))}

          {freeCount > 0 && (
            <div style={{ background: 'var(--warning-bg)', border: '1px solid var(--warning-border)', borderRadius: '10px', padding: '10px 14px' }}>
              <p style={{ fontSize: '0.76rem', fontWeight: 700, color: 'var(--warning-fg)' }}>Upgrade potential</p>
              <p style={{ fontSize: '0.72rem', color: 'var(--warning-fg)', opacity: 0.9 }}>
                {freeCount} free user{freeCount !== 1 ? 's' : ''} · up to {fmtPKR(freeCount * PLAN_PRICE_PKR.PROFESSIONAL)} additional MRR on Pro
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

/* ─── Compact system health strip (real data from /api/admin/health) ────── */
const HEALTH_STATUS = {
  healthy:  { color: 'var(--success)', bg: 'var(--tint-green)', label: 'Healthy'  },
  degraded: { color: 'var(--warning)', bg: 'var(--tint-amber)', label: 'Degraded' },
  down:     { color: 'var(--sos)', bg: 'var(--tint-red)',   label: 'Down'     },
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

function HealthStrip({ health, error }) {
  const services = [
    { label: 'API',      key: 'api' },
    { label: 'Database', key: 'database' },
    { label: 'Push',     key: 'push' },
    { label: 'Sockets',  key: 'socket' },
  ];
  const summary = summarizeHealth(health);

  return (
    <div style={{ ...CARD, marginBottom: '20px', display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: '10px 18px', padding: '12px 18px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginRight: '4px' }}>
        <Server size={16} color="var(--primary-light)" />
        <span style={{ fontSize: '0.86rem', fontWeight: 800, color: C.textMain }}>System Health</span>
      </div>

      {!health ? (
        error
          ? <span style={{ fontSize: '0.8rem', color: C.textMuted }}>Health check unavailable</span>
          : <Skeleton h={22} w="320px" br={8} style={{ maxWidth: '100%' }} />
      ) : (
        <>
          {services.map(({ label, key }) => {
            const svc = health.services?.[key];
            const s = HEALTH_STATUS[svc?.status] || HEALTH_STATUS.down;
            return (
              <span key={key} title={`${label}: ${s.label}${svc?.latencyMs != null ? ` (${svc.latencyMs} ms)` : ''}`}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '4px 10px', borderRadius: '8px', background: s.bg, fontSize: '0.76rem', fontWeight: 700, color: C.textSub }}>
                <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: s.color }} />
                {label}
                {svc?.latencyMs != null && <span style={{ color: C.textMuted, fontWeight: 600 }}>{svc.latencyMs} ms</span>}
              </span>
            );
          })}
          <span style={{ fontSize: '0.76rem', color: C.textMuted, fontWeight: 600 }}>
            Uptime <strong style={{ color: C.textSub }}>{formatUptime(health.uptime)}</strong>
          </span>
          {health.memory && (
            <span style={{ fontSize: '0.76rem', color: C.textMuted, fontWeight: 600 }}>
              Heap <strong style={{ color: health.memory.usedPct > 80 ? 'var(--sos)' : C.textSub }}>{health.memory.usedMB}/{health.memory.totalMB} MB</strong>
            </span>
          )}
          {summary && (
            <span style={{ marginLeft: 'auto', fontSize: '0.76rem', fontWeight: 700, color: summary.pct === 100 ? 'var(--success-fg)' : 'var(--warning-fg)' }}>
              {summary.label}
            </span>
          )}
        </>
      )}
    </div>
  );
}

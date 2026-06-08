import React, { useState, useEffect, useRef } from 'react';
import { Routes, Route, Link, useLocation, useNavigate } from 'react-router-dom';
import {
  BarChart3, Users, UserCheck, Activity, History, Mail,
  LogOut, Bell, Search, Zap, AlertTriangle, CreditCard,
  ChevronLeft, ChevronRight, TrendingUp, TrendingDown,
  Shield, Clock, ArrowRight, PanelLeftClose, PanelLeftOpen,
  Circle, Settings, CheckCircle, XCircle, EarOff, RefreshCw,
  Send, LayoutDashboard, Sun, Moon,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAuth } from '../context/AuthContext';
import { useAlert } from '../context/AlertContext';
import { useTheme } from '../context/ThemeContext';
import api from '../services/api';
import { io } from 'socket.io-client';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip,
  BarChart, Bar, ResponsiveContainer, Legend,
} from 'recharts';
import UserManagement from './UserManagement';
import ResponderVerification from './admin/ResponderVerification';
import ResponderRecords from './admin/ResponderRecords';
import SOSMonitor from './admin/SOSMonitor';
import SystemLogs from './admin/SystemLogs';
import CommunicationAudit from './admin/CommunicationAudit';
import SubscriptionManagement from './admin/SubscriptionManagement';
import PlatformSettings from './admin/PlatformSettings';
import SystemNotifications from './admin/SystemNotifications';
import AdminInbox from './admin/AdminInbox';
import logo from '../assets/Medifind_New_Logo-removebg-preview.png';

/* ─── Theme ────────────────────────────────────────────────────────────── */
const C = {
  sidebarBg: 'linear-gradient(175deg,#03293C 0%,#0A5570 55%,#0E6E82 100%)',
  accent: '#2891C2',
  accentHover: '#1e7aab',
  border: '#E4EEF3',
  bg: '#F3F7FA',
  white: '#FFFFFF',
  textMain: '#0F1A22',
  textSub: '#3D5360',
  textMuted: '#7A96A3',
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
  { label: 'Subscriptions', to: '/admin/subscriptions', Icon: CreditCard },
  { label: 'System Logs', to: '/admin/logs', Icon: History },
  { label: 'Comm Audit', to: '/admin/emails', Icon: Mail },
  { label: 'Notifications', to: '/admin/notifications', Icon: Bell },
  { label: 'Admin Inbox', to: '/admin/inbox', Icon: Mail },
  { label: 'Platform Settings', to: '/admin/settings', Icon: Settings },
];

/* ─── Sidebar ───────────────────────────────────────────────────────────── */
function Sidebar({ open, onToggle, onLogout }) {
  const { pathname } = useLocation();
  const W = open ? 248 : 68;

  const active = (item) =>
    item.exact ? pathname === item.to : pathname.startsWith(item.to);

  return (
    <motion.aside
      animate={{ width: W }}
      initial={false}
      transition={{ type: 'spring', stiffness: 320, damping: 32 }}
      style={{
        position: 'fixed', top: 0, left: 0, height: '100vh',
        background: C.sidebarBg,
        display: 'flex', flexDirection: 'column',
        zIndex: 200, overflow: 'hidden',
        boxShadow: '2px 0 20px rgba(3,41,60,0.22)',
        flexShrink: 0,
      }}
    >
      {/* ── Logo + toggle row ── */}
      <div style={{
        height: '130px',
        display: 'flex', alignItems: 'center',
        justifyContent: open ? 'space-between' : 'center',
        padding: open ? '0 14px 0 16px' : '0',
        borderBottom: '1px solid rgba(255,255,255,0.07)',
        flexShrink: 0,
      }}>
        {open && (
          <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none' }}>
              <img
                src={logo} alt="MediFind"
                style={{
                  height: '100px', objectFit: 'contain', display: 'block',
                  maxWidth: '220px',
                  filter: 'brightness(1.25) drop-shadow(0 2px 10px rgba(0,0,0,0.4))',
                  cursor: 'pointer',
                }}
              />
          </Link>
        )}
        {/* collapse / expand toggle */}
        <button
          onClick={onToggle}
          title={open ? 'Collapse sidebar' : 'Expand sidebar'}
          style={{
            width: '32px', height: '32px', borderRadius: '10px',
            background: 'rgba(255,255,255,0.08)',
            border: '1px solid rgba(255,255,255,0.12)',
            color: 'rgba(255,255,255,0.75)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', flexShrink: 0, transition: 'background 0.2s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.16)'}
          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
        >
          {open ? <PanelLeftClose size={16} /> : <PanelLeftOpen size={16} />}
        </button>
      </div>

      {/* ── Nav ── */}
      <nav style={{
        flex: 1, padding: open ? '16px 10px' : '16px 8px',
        display: 'flex', flexDirection: 'column', gap: '2px',
        overflow: 'hidden',            /* never scroll */
      }}>
        {open && (
          <p style={{
            fontSize: '0.65rem', fontWeight: 800, letterSpacing: '0.16em',
            textTransform: 'uppercase', color: 'rgba(255,255,255,0.28)',
            padding: '0 8px', marginBottom: '8px',
          }}>Management</p>
        )}

        {NAV.map((item) => {
          const on = active(item);
          return (
            <Link
              key={item.to}
              to={item.to}
              title={!open ? item.label : undefined}
              style={{
                display: 'flex', alignItems: 'center',
                gap: open ? '10px' : '0',
                justifyContent: open ? 'flex-start' : 'center',
                padding: open ? '10px 12px' : '11px 0',
                borderRadius: '12px',
                background: on ? 'rgba(255,255,255,0.13)' : 'transparent',
                color: on ? '#FFFFFF' : 'rgba(255,255,255,0.48)',
                fontWeight: on ? 700 : 500,
                fontSize: '0.875rem',
                transition: 'all 0.15s',
                textDecoration: 'none',
                whiteSpace: 'nowrap', overflow: 'hidden',
                position: 'relative',
                borderLeft: on && open ? '3px solid #2891C2' : '3px solid transparent',
              }}
              onMouseEnter={e => { if (!on) { e.currentTarget.style.background = 'rgba(255,255,255,0.07)'; e.currentTarget.style.color = 'rgba(255,255,255,0.8)'; } }}
              onMouseLeave={e => { if (!on) { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = 'rgba(255,255,255,0.48)'; } }}
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
        {/* Integrity bar — only when open */}
        {open && (
          <div style={{
            background: 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,255,255,0.08)',
            borderRadius: '12px', padding: '10px 12px', marginBottom: '10px',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
              <span style={{ fontSize: '0.66rem', fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.35)' }}>System Integrity</span>
              <span style={{ fontSize: '0.78rem', fontWeight: 800, color: '#4ade80' }}>98.2%</span>
            </div>
            <div style={{ height: '3px', background: 'rgba(255,255,255,0.08)', borderRadius: '2px' }}>
              <div style={{ height: '100%', width: '98.2%', background: 'linear-gradient(90deg,#2891C2,#4ade80)', borderRadius: '2px' }} />
            </div>
          </div>
        )}

        {/* Sign out */}
        <button
          onClick={onLogout}
          title={!open ? 'Sign Out' : undefined}
          style={{
            display: 'flex', alignItems: 'center',
            gap: open ? '9px' : '0',
            justifyContent: open ? 'flex-start' : 'center',
            width: '100%', padding: open ? '10px 12px' : '11px 0',
            borderRadius: '12px',
            background: 'rgba(255,100,100,0.08)',
            border: '1px solid rgba(255,100,100,0.15)',
            color: '#ff8585', fontWeight: 700, fontSize: '0.875rem',
            cursor: 'pointer', transition: 'all 0.15s',
          }}
          onMouseEnter={e => { e.currentTarget.style.background = 'rgba(255,100,100,0.18)'; e.currentTarget.style.color = '#ff6b6b'; }}
          onMouseLeave={e => { e.currentTarget.style.background = 'rgba(255,100,100,0.08)'; e.currentTarget.style.color = '#ff8585'; }}
        >
          <LogOut size={17} style={{ flexShrink: 0 }} />
          {open && 'Sign Out'}
        </button>
      </div>
    </motion.aside>
  );
}

/* ─── Root Dashboard ────────────────────────────────────────────────────── */
export default function Dashboard() {
  const [open, setOpen] = useState(true);
  const [notifs, setNotifs] = useState([]);
  const [showNotifs, setShowNotifs] = useState(false);
  const [unread, setUnread] = useState(0);
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

  // Refs for click outside
  const notifRef = useRef(null);
  const searchRef = useRef(null);
  const profileRef = useRef(null);

  // Fetch users for global search
  useEffect(() => {
    api.get('/api/admin/users').then(res => {
      if (res.data && res.data.success && Array.isArray(res.data.data)) {
        setUsers(res.data.data);
      }
    }).catch(err => console.error('Failed to load users for global search:', err));
  }, []);

  // Click outside listener for all dropdowns
  useEffect(() => {
    function handleClickOutside(event) {
      if (showNotifs && notifRef.current && !notifRef.current.contains(event.target)) {
        setShowNotifs(false);
      }
      if (showProfile && profileRef.current && !profileRef.current.contains(event.target)) {
        setShowProfile(false);
      }
      if (searchFocused && searchRef.current && !searchRef.current.contains(event.target)) {
        setSearchFocused(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showNotifs, showProfile, searchFocused]);

  const W = open ? 248 : 68;

  // Real-time Socket Listener
  useEffect(() => {
    // Initial Fetch
    api.get('/api/notifications/history?limit=10').then(res => {
      if (res.data.success) {
        setNotifs(res.data.data);
        setUnread(res.data.data.filter((n) => !n.isRead).length);
      }
    }).catch(err => console.error('Failed to load initial notifications:', err));

    const socket = io(import.meta.env.VITE_API_URL || 'http://localhost:3000');
    
    socket.on('connect', () => {
      console.log('📡 Connected to Real-time Admin Network');
      socket.emit('join', { userId: user?.id, role: 'ADMIN' });
    });

    socket.on('admin_notification', (notif) => {
      console.log('📢 Admin Alert Received:', notif);
      setNotifs(prev => [notif, ...prev].slice(0, 10));
      setUnread(u => u + 1);
      
      // Critical Popups
      if (notif.type === 'SOS_TRIGGERED' || notif.type === 'PATIENT_EMERGENCY') {
        showAlert(`CRITICAL: ${notif.title}`, 'error');
      } else {
        showAlert(notif.title, 'info');
      }
    });

    return () => socket.disconnect();
  }, [user, showAlert]);

  const handleLogout = async () => { await logout(); navigate('/login', { replace: true }); };

  const adminInitial = user?.fullName?.charAt(0)?.toUpperCase() ?? 'A';
  const adminName = user?.fullName ?? 'System Administrator';

  const pageLabel = NAV.find(n =>
    n.exact ? location.pathname === n.to : location.pathname.startsWith(n.to)
  )?.label ?? 'Dashboard';

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: isDark ? 'var(--background)' : C.bg }}>
      <Sidebar open={open} onToggle={() => setOpen(o => !o)} onLogout={handleLogout} />

      {/* ── Main ── */}
      <motion.div
        animate={{ marginLeft: W }}
        initial={false}
        transition={{ type: 'spring', stiffness: 320, damping: 32 }}
        style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, minHeight: '100vh' }}
      >
        {/* ── Top Bar ── */}
        <header style={{
          height: '64px',
          background: isDark ? 'var(--surface)' : C.white,
          borderBottom: `1px solid ${isDark ? 'var(--border)' : C.border}`,
          display: 'flex', alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 28px', position: 'sticky', top: 0, zIndex: 100,
          boxShadow: isDark ? '0 1px 3px rgba(0,0,0,0.2)' : '0 1px 3px rgba(12,99,126,0.06)',
        }}>
          {/* Left: page title */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Shield size={16} color={C.accent} />
            <span style={{ fontSize: '0.8rem', color: C.textMuted, fontWeight: 600 }}>MediFind Admin</span>
            <ChevronRight size={14} color={C.textMuted} />
            <span style={{ fontSize: '0.8rem', color: C.textMain, fontWeight: 700 }}>{pageLabel}</span>
          </div>

          {/* Center: search */}
          <div ref={searchRef} style={{ position: 'relative', width: '320px' }}>
            <Search style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.textMuted }} size={16} />
            <input
              type="text"
              placeholder="Search users, pages..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onKeyDown={e => {
                if (e.key === 'Enter' && searchQuery.trim()) {
                  // Check if there are any matching nav items or users
                  const hasNavMatch = NAV.some(item => item.label.toLowerCase().includes(searchQuery.toLowerCase()));
                  const hasUserMatch = users.some(u =>
                    u.fullName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                    u.email?.toLowerCase().includes(searchQuery.toLowerCase())
                  );
                  if (!hasNavMatch && !hasUserMatch) {
                    setSearchFocused(false);
                    setSearchQuery('');
                    navigate(`/admin/${encodeURIComponent(searchQuery.trim())}`);
                  }
                }
              }}
              style={{
                width: '100%', height: '40px', paddingLeft: '38px',
                border: `1.5px solid ${searchFocused ? C.accent : C.border}`, borderRadius: '10px',
                background: isDark ? 'var(--input-bg)' : C.bg, outline: 'none', fontSize: '0.875rem',
                fontFamily: 'inherit', color: isDark ? 'var(--text-main)' : C.textMain, transition: 'border 0.2s',
              }}
            />

            <AnimatePresence>
              {searchFocused && (
                <motion.div
                  initial={{ opacity: 0, y: 10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 10, scale: 0.95 }}
                  style={{
                    position: 'absolute', top: '46px', left: 0, width: '360px',
                    background: 'white', borderRadius: '12px', border: `1px solid ${C.border}`,
                    boxShadow: '0 10px 25px rgba(0,0,0,0.08)', zIndex: 1000, overflow: 'hidden',
                    padding: '8px 0', display: 'flex', flexDirection: 'column', gap: '4px'
                  }}
                >
                  {/* Quick links & navigation */}
                  <div style={{ padding: '4px 12px 2px 12px', fontSize: '0.7rem', fontWeight: 800, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    ⚡ Navigation & Quick Links
                  </div>
                  {NAV.filter(item => 
                    item.label.toLowerCase().includes(searchQuery.toLowerCase())
                  ).slice(0, 4).map(item => (
                    <Link
                      key={item.to}
                      to={item.to}
                      onClick={() => { setSearchFocused(false); setSearchQuery(''); }}
                      style={{
                        display: 'flex', alignItems: 'center', gap: '8px',
                        padding: '8px 16px', fontSize: '0.84rem', color: C.textSub,
                        textDecoration: 'none', transition: 'background 0.15s'
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = '#f8fafc'}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                    >
                      <item.Icon size={14} color={C.accent} />
                      <span>{item.label}</span>
                    </Link>
                  ))}

                  {/* Users search */}
                  {searchQuery && (
                    <>
                      <div style={{ padding: '8px 12px 2px 12px', borderTop: `1px solid ${C.border}`, fontSize: '0.7rem', fontWeight: 800, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em', marginTop: '4px' }}>
                        👤 Users & Responders
                      </div>
                      {users.filter(u => 
                        u.fullName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                        u.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                        u.phoneNumber?.toLowerCase().includes(searchQuery.toLowerCase())
                      ).length === 0 ? (
                        <div style={{ padding: '8px 16px', fontSize: '0.8rem', color: C.textMuted }}>No users found matching query</div>
                      ) : (
                        users.filter(u => 
                          u.fullName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          u.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          u.phoneNumber?.toLowerCase().includes(searchQuery.toLowerCase())
                        ).slice(0, 5).map(u => (
                          <Link
                            key={u.id}
                            to={`/admin/users?search=${encodeURIComponent(u.fullName)}`}
                            onClick={() => { setSearchFocused(false); setSearchQuery(''); }}
                            style={{
                              display: 'flex', flexDirection: 'column',
                              padding: '8px 16px', fontSize: '0.84rem', color: C.textMain,
                              textDecoration: 'none', transition: 'background 0.15s', borderBottom: '1px dotted #f1f5f9'
                            }}
                            onMouseEnter={e => e.currentTarget.style.background = '#f8fafc'}
                            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                          >
                            <span style={{ fontWeight: 700 }}>{u.fullName}</span>
                            <span style={{ fontSize: '0.74rem', color: C.textMuted }}>{u.email} &bull; {u.role}</span>
                          </Link>
                        ))
                      )}
                    </>
                  )}
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* Right: theme toggle + bell + user */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', position: 'relative' }}>

            {/* ── Theme Toggle ── */}
            <motion.button
              onClick={toggleTheme}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.93 }}
              title={isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
              style={{
                width: '40px', height: '40px', borderRadius: '10px',
                background: isDark ? 'rgba(255,255,255,0.08)' : C.bg,
                border: `1.5px solid ${isDark ? 'rgba(255,255,255,0.15)' : C.border}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', color: isDark ? '#fcd34d' : C.textMuted,
                transition: 'all 0.2s',
              }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = C.accent; e.currentTarget.style.color = isDark ? '#fcd34d' : C.accent; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = isDark ? 'rgba(255,255,255,0.15)' : C.border; e.currentTarget.style.color = isDark ? '#fcd34d' : C.textMuted; }}
            >
              <AnimatePresence mode="wait" initial={false}>
                <motion.span
                  key={theme}
                  initial={{ rotate: -30, opacity: 0, scale: 0.7 }}
                  animate={{ rotate: 0, opacity: 1, scale: 1 }}
                  exit={{ rotate: 30, opacity: 0, scale: 0.7 }}
                  transition={{ duration: 0.2 }}
                  style={{ display: 'flex' }}
                >
                  {isDark ? <Sun size={18} /> : <Moon size={18} />}
                </motion.span>
              </AnimatePresence>
            </motion.button>

            <div ref={notifRef} style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <button
                onClick={() => { setShowNotifs(!showNotifs); setUnread(0); }}
                style={{
                  position: 'relative', width: '40px', height: '40px', borderRadius: '10px',
                  background: C.bg, border: `1.5px solid ${showNotifs ? C.accent : C.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  cursor: 'pointer', color: showNotifs ? C.accent : C.textMuted, transition: 'all 0.15s',
                }}
              >
                <Bell size={18} />
                {unread > 0 && (
                  <span style={{ position: 'absolute', top: '9px', right: '9px', width: '10px', height: '10px', background: '#FF6B6B', borderRadius: '50%', border: '2px solid white', fontSize: '10px', display: 'flex', alignItems: 'center', justifyContent: 'center' }} />
                )}
              </button>

              {/* Notification Dropdown */}
              <AnimatePresence>
                {showNotifs && (
                  <motion.div
                    initial={{ opacity: 0, y: 10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 10, scale: 0.95 }}
                    style={{
                      position: 'absolute', top: '55px', right: 0, width: '320px',
                      background: 'white', borderRadius: '16px', border: `1px solid ${C.border}`,
                      boxShadow: '0 20px 40px rgba(0,0,0,0.12)', zIndex: 1000, overflow: 'hidden'
                    }}
                  >
                    <div style={{ padding: '16px 20px', borderBottom: `1px solid ${C.border}`, background: '#f8fafc', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h4 style={{ margin: 0, fontSize: '0.9rem', fontWeight: 700, color: C.textMain }}>Recent Alerts</h4>
                      <span style={{ fontSize: '0.75rem', fontWeight: 600, color: C.accent, cursor: 'pointer' }} onClick={() => setNotifs([])}>Clear All</span>
                    </div>
                    <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                      {notifs.length === 0 ? (
                        <div style={{ padding: '40px 20px', textAlign: 'center', color: C.textMuted }}>
                          <Mail size={24} style={{ marginBottom: '10px', opacity: 0.3 }} />
                          <p style={{ fontSize: '0.85rem', margin: 0 }}>All quiet on the network.</p>
                        </div>
                      ) : (
                        notifs.map((n, i) => (
                          <div key={i} 
                            onClick={() => { if(n.type.includes('SOS')) navigate('/admin/sos'); setShowNotifs(false); }}
                            style={{ 
                              padding: '12px 20px', borderBottom: i < notifs.length - 1 ? `1px solid ${C.border}` : 'none',
                              cursor: 'pointer', transition: 'background 0.2s'
                            }}
                            onMouseEnter={e => e.currentTarget.style.background = '#f1f5f9'}
                            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                          >
                            <div style={{ display: 'flex', gap: '12px' }}>
                              <div style={{ 
                                width: '8px', height: '8px', borderRadius: '50%', 
                                background: n.type.includes('SOS') ? '#FF6B6B' : C.accent,
                                marginTop: '6px', flexShrink: 0
                              }} />
                              <div>
                                <p style={{ margin: '0 0 2px 0', fontSize: '0.875rem', fontWeight: 700, color: C.textMain }}>{n.title}</p>
                                <p style={{ margin: 0, fontSize: '0.78rem', color: C.textSub, lineHeight: 1.4 }}>{n.body}</p>
                                <p style={{ margin: '6px 0 0 0', fontSize: '0.7rem', color: C.textMuted }}>{new Date(n.timestamp).toLocaleTimeString()}</p>
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                    {notifs.length > 0 && (
                      <div style={{ padding: '12px', textAlign: 'center', borderTop: `1px solid ${C.border}`, background: '#f8fafc' }}>
                        <Link to="/admin/emails" onClick={() => setShowNotifs(false)} style={{ fontSize: '0.8rem', fontWeight: 700, color: C.accent, textDecoration: 'none' }}>View Communication Audit</Link>
                      </div>
                    )}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            <div style={{ width: '1px', height: '28px', background: C.border }} />

            <div ref={profileRef} style={{ position: 'relative' }}>
              <div 
                onClick={() => setShowProfile(!showProfile)}
                style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}
              >
                <div style={{ textAlign: 'right' }}>
                  <p style={{ fontSize: '0.85rem', fontWeight: 700, color: C.textMain, lineHeight: 1.2 }}>{adminName}</p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px', justifyContent: 'flex-end' }}>
                    <Circle size={7} fill="#10B981" color="#10B981" />
                    <span style={{ fontSize: '0.72rem', color: C.textMuted, fontWeight: 600 }}>Network Online</span>
                  </div>
                </div>
                <div style={{
                  width: '40px', height: '40px',
                  background: 'linear-gradient(135deg,#0C637E,#2496A7)',
                  borderRadius: '11px', color: 'white',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontWeight: 800, fontSize: '1rem', flexShrink: 0,
                }}>
                  {adminInitial}
                </div>
              </div>

              <AnimatePresence>
                {showProfile && (
                  <motion.div
                    initial={{ opacity: 0, y: 10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 10, scale: 0.95 }}
                    style={{
                      position: 'absolute', top: '52px', right: 0, width: '280px',
                      background: 'white', borderRadius: '16px', border: `1px solid ${C.border}`,
                      boxShadow: '0 20px 40px rgba(0,0,0,0.12)', zIndex: 1000, overflow: 'hidden'
                    }}
                  >
                    <div style={{ padding: '20px', background: 'linear-gradient(135deg,#0C637E,#2496A7)', color: 'white', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                      <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.4rem', fontWeight: 800 }}>{adminInitial}</div>
                      <div style={{ textAlign: 'center' }}>
                        <p style={{ margin: 0, fontWeight: 700, fontSize: '1rem' }}>{adminName}</p>
                        <p style={{ margin: '2px 0 0 0', fontSize: '0.78rem', color: '#E2F0F3', opacity: 0.9 }}>{user?.email || 'admin@medifind.com'}</p>
                      </div>
                      <span style={{ fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px', borderRadius: '20px', background: 'rgba(255,255,255,0.25)', color: 'white' }}>System Admin</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                      <Link
                        to="/admin/settings"
                        onClick={() => setShowProfile(false)}
                        style={{
                          display: 'flex', alignItems: 'center', gap: '10px',
                          padding: '12px 20px', fontSize: '0.85rem', color: C.textSub,
                          textDecoration: 'none', transition: 'all 0.15s', borderBottom: '1px solid #f1f5f9'
                        }}
                        onMouseEnter={e => { e.currentTarget.style.background = '#f8fafc'; e.currentTarget.style.color = C.accent; }}
                        onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = C.textSub; }}
                      >
                        <Settings size={15} />
                        <span>Platform Settings</span>
                      </Link>
                      <Link
                        to="/admin/logs"
                        onClick={() => setShowProfile(false)}
                        style={{
                          display: 'flex', alignItems: 'center', gap: '10px',
                          padding: '12px 20px', fontSize: '0.85rem', color: C.textSub,
                          textDecoration: 'none', transition: 'all 0.15s', borderBottom: '1px solid #f1f5f9'
                        }}
                        onMouseEnter={e => { e.currentTarget.style.background = '#f8fafc'; e.currentTarget.style.color = C.accent; }}
                        onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = C.textSub; }}
                      >
                        <History size={15} />
                        <span>System Logs</span>
                      </Link>
                      <Link
                        to="/admin/inbox"
                        onClick={() => setShowProfile(false)}
                        style={{
                          display: 'flex', alignItems: 'center', gap: '10px',
                          padding: '12px 20px', fontSize: '0.85rem', color: C.textSub,
                          textDecoration: 'none', transition: 'all 0.15s', borderBottom: '1px solid #f1f5f9'
                        }}
                        onMouseEnter={e => { e.currentTarget.style.background = '#f8fafc'; e.currentTarget.style.color = C.accent; }}
                        onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = C.textSub; }}
                      >
                        <Mail size={15} />
                        <span>Admin Inbox</span>
                      </Link>
                      <div
                        onClick={() => { setShowProfile(false); handleLogout(); }}
                        style={{
                          display: 'flex', alignItems: 'center', gap: '10px',
                          padding: '12px 20px', fontSize: '0.85rem', color: '#EF4444',
                          cursor: 'pointer', transition: 'all 0.15s'
                        }}
                        onMouseEnter={e => e.currentTarget.style.background = '#FEF2F2'}
                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                      >
                        <LogOut size={15} />
                        <span style={{ fontWeight: 700 }}>Sign Out</span>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </header>

        {/* ── Page Content ── */}
        <div style={{ flex: 1, padding: '28px 32px', overflow: 'auto', background: isDark ? 'var(--background)' : C.bg }}>
          <AnimatePresence mode="wait">
            <Routes location={location} key={location.pathname}>
              <Route path="/" element={<Overview />} />
              <Route path="/users" element={<UserManagement />} />
              <Route path="/verify" element={<ResponderVerification />} />
              <Route path="/records" element={<ResponderRecords />} />
              <Route path="/sos" element={<SOSMonitor />} />
              <Route path="/subscriptions" element={<SubscriptionManagement />} />
              <Route path="/logs" element={<SystemLogs />} />
              <Route path="/emails" element={<CommunicationAudit />} />
              <Route path="/notifications" element={<SystemNotifications />} />
              <Route path="/inbox" element={<AdminInbox />} />
              <Route path="/settings" element={<PlatformSettings />} />
              <Route path="*" element={<AdminNotFound />} />
            </Routes>
          </AnimatePresence>
        </div>
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
    const t = setInterval(() => {
      setCount(p => {
        if (p <= 1) { clearInterval(t); navigate('/admin', { replace: true }); return 0; }
        return p - 1;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [navigate]);

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
      {/* Animated ECG pulse */}
      <div style={{ marginBottom: '1.5rem', opacity: 0.25 }}>
        <svg width="260" height="40" viewBox="0 0 260 40">
          <motion.polyline
            points="0,20 50,20 65,5 75,35 85,2 95,38 105,20 160,20 175,5 185,35 195,2 205,38 215,20 260,20"
            fill="none" stroke="#0C637E" strokeWidth="2"
            initial={{ pathLength: 0 }} animate={{ pathLength: 1 }}
            transition={{ duration: 1.5, ease: 'easeInOut' }}
          />
        </svg>
      </div>

      {/* 404 number */}
      <div style={{
        fontSize: '6rem', fontWeight: 900, lineHeight: 1,
        background: 'linear-gradient(135deg, #0C637E 0%, #2496A7 50%, #2891C2 100%)',
        WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
        backgroundClip: 'text', letterSpacing: '-4px', marginBottom: '1rem',
      }}>
        404
      </div>

      {/* Badge */}
      <div style={{
        display: 'inline-flex', alignItems: 'center', gap: '6px',
        background: '#FEF3C7', border: '1px solid #FDE68A',
        borderRadius: '999px', padding: '4px 14px', marginBottom: '1.25rem',
      }}>
        <AlertTriangle size={13} color="#D97706" />
        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: '#D97706', textTransform: 'uppercase', letterSpacing: '0.07em' }}>
          Page Not Found
        </span>
      </div>

      <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-sub)', marginBottom: '0.6rem', letterSpacing: '-0.02em' }}>
        This admin page doesn't exist
      </h2>
      <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
        The URL{' '}
        <code style={{ background: 'var(--surface-raised)', padding: '2px 8px', borderRadius: '5px', fontSize: '0.82rem', color: 'var(--primary)' }}>
          {location.pathname}
        </code>{' '}
        is not a valid admin page.
      </p>
      <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: '2rem' }}>
        Use the sidebar to navigate to a valid section.
      </p>

      {/* Buttons */}
      <div style={{ display: 'flex', gap: '0.875rem', flexWrap: 'wrap', justifyContent: 'center', marginBottom: '2rem' }}>
        <button
          onClick={() => navigate(-1)}
          style={{
            display: 'flex', alignItems: 'center', gap: '6px',
            padding: '0.7rem 1.4rem', borderRadius: '10px',
            border: '1.5px solid var(--border)', background: 'var(--surface)',
            color: 'var(--text-sub)', fontWeight: 600, fontSize: '0.875rem',
            cursor: 'pointer', fontFamily: 'inherit', transition: 'all 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.borderColor = 'var(--primary)'}
          onMouseLeave={e => e.currentTarget.style.borderColor = 'var(--border)'}
        >
          ← Go Back
        </button>
        <button
          onClick={() => navigate('/admin', { replace: true })}
          style={{
            display: 'flex', alignItems: 'center', gap: '6px',
            padding: '0.7rem 1.6rem', borderRadius: '10px',
            background: 'linear-gradient(135deg, #0C637E, #2891C2)',
            border: 'none', color: 'white', fontWeight: 700, fontSize: '0.875rem',
            cursor: 'pointer', fontFamily: 'inherit',
            boxShadow: '0 4px 12px rgba(12,99,126,0.3)',
          }}
        >
          🏠 Back to Dashboard
        </button>
      </div>

      {/* Countdown */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
        <svg width="24" height="24" viewBox="0 0 24 24" style={{ transform: 'rotate(-90deg)', flexShrink: 0 }}>
          <circle cx="12" cy="12" r="9" fill="none" stroke="var(--border)" strokeWidth="2" />
          <circle cx="12" cy="12" r="9" fill="none" stroke="#0C637E" strokeWidth="2"
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
function Overview() {
  const navigate = useNavigate();
  const [stats,             setStats]             = useState(null);
  const [pendingCount,      setPendingCount]      = useState(null);
  const [pendingResponders, setPendingResponders] = useState([]);
  const [health,            setHealth]            = useState(null);
  const [loading,           setLoading]           = useState(true);
  const [error,             setError]             = useState('');
  const [recentActivity,    setRecentActivity]    = useState([]);
  const [analytics,         setAnalytics]         = useState(null);
  const [lastUpdated,       setLastUpdated]       = useState(null);
  const [refreshing,        setRefreshing]        = useState(false);

  const loadData = () => {
    setLoading(true);
    Promise.all([
      api.get('/api/admin/stats'),
      api.get('/api/admin/responders/pending'),
      api.get('/api/admin/health'),
      api.get('/api/admin/logs?limit=7'),
      api.get('/api/admin/analytics/emergencies?days=14'),
    ])
      .then(([statsRes, pendRes, healthRes, logsRes, analyticsRes]) => {
        if (statsRes.data.success)     setStats(statsRes.data.data);
        if (pendRes.data.success) {
          const arr = pendRes.data.data || [];
          setPendingCount(arr.length);
          setPendingResponders(arr);
        }
        if (healthRes.data.success)    setHealth(healthRes.data.data);
        if (logsRes.data.success)      setRecentActivity(logsRes.data.data || []);
        if (analyticsRes.data.success) setAnalytics(analyticsRes.data.data);
        setLastUpdated(new Date());
      })
      .catch(() => setError('Unable to reach backend — check your server is running.'))
      .finally(() => setLoading(false));
  };

  /* Silent background refresh — updates stats without showing skeleton */
  const silentRefresh = () => {
    setRefreshing(true);
    Promise.all([
      api.get('/api/admin/stats'),
      api.get('/api/admin/responders/pending'),
    ])
      .then(([statsRes, pendRes]) => {
        if (statsRes.data.success) setStats(statsRes.data.data);
        if (pendRes.data.success) {
          const arr = pendRes.data.data || [];
          setPendingCount(arr.length);
          setPendingResponders(arr);
        }
        setLastUpdated(new Date());
      })
      .catch(() => {}) // fail silently — don't override the error banner
      .finally(() => setRefreshing(false));
  };

  useEffect(() => {
    loadData();
    /* Poll key stats every 15 seconds */
    const interval = setInterval(silentRefresh, 15000);
    return () => clearInterval(interval);
  }, []);

  /* Stat card definitions */
  const cards = stats ? [
    {
      label: 'Total Users', value: stats.totalUsers,
      trend: '+12%', up: true,
      Icon: Users, accent: '#0C637E', pale: '#E2F0F3',
      sub: 'Registered accounts',
      to: '/admin/users?role=ALL',
    },
    {
      label: 'Active Emergencies', value: stats.activeEmergencies,
      trend: 'LIVE', up: null,
      Icon: Activity, accent: '#EF4444', pale: '#FEF2F2',
      sub: 'Ongoing SOS events',
      to: '/admin/sos?filter=ACTIVE',
    },
    {
      label: 'Total Emergencies', value: stats.totalEmergencies,
      trend: '+5%', up: true,
      Icon: AlertTriangle, accent: '#F59E0B', pale: '#FFFBEB',
      sub: 'All-time SOS events',
      to: '/admin/sos?filter=ALL',
    },
    {
      label: 'Verified Responders', value: stats.onlineResponders,
      trend: '+3', up: true,
      Icon: Zap, accent: '#10B981', pale: '#ECFDF5',
      sub: 'Ready to respond',
      to: '/admin/users?role=RESPONDER',
    },
  ] : Array(4).fill(null);

  const sparkBars = [40, 65, 45, 80, 55, 90, 70];

  /* Quick action definitions */
  const quickActions = [
    {
      label: 'Verify Responders',
      desc: pendingCount != null ? `${pendingCount} awaiting review` : 'Review credentials',
      Icon: UserCheck,
      accent: '#10B981', pale: '#ECFDF5',
      to: '/admin/verify',
      badge: pendingCount > 0 ? pendingCount : null,
      badgeColor: '#EF4444',
    },
    {
      label: 'Live SOS Monitor',
      desc: stats ? `${stats.activeEmergencies} active now` : 'Track emergencies',
      Icon: Activity,
      accent: '#EF4444', pale: '#FEF2F2',
      to: '/admin/sos',
      badge: stats?.activeEmergencies > 0 ? stats.activeEmergencies : null,
      badgeColor: '#EF4444',
      pulse: stats?.activeEmergencies > 0,
    },
    {
      label: 'User Management',
      desc: stats ? `${stats.totalUsers} registered users` : 'Manage all users',
      Icon: Users,
      accent: '#0C637E', pale: '#E2F0F3',
      to: '/admin/users',
      badge: null,
    },
    {
      label: 'Send Notification',
      desc: 'Broadcast to users',
      Icon: Send,
      accent: '#8B5CF6', pale: '#EDE9FE',
      to: '/admin/notifications',
      badge: null,
    },
    {
      label: 'Subscriptions',
      desc: 'Plans & billing',
      Icon: CreditCard,
      accent: '#F59E0B', pale: '#FFFBEB',
      to: '/admin/subscriptions',
      badge: null,
    },
    {
      label: 'System Logs',
      desc: 'Audit trail',
      Icon: History,
      accent: '#64748B', pale: '#F1F5F9',
      to: '/admin/logs',
      badge: null,
    },
  ];

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -12 }}
      transition={{ duration: 0.35 }}
    >
      {/* ── Page header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: C.textMain, letterSpacing: '-0.02em', marginBottom: '4px' }}>
            Infrastructure Pulse
          </h1>
          <p style={{ color: C.textMuted, fontSize: '0.9rem' }}>
            Real-time status of the MediFind emergency response network.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {/* Last-updated timestamp */}
          {lastUpdated && (
            <span style={{ fontSize: '0.74rem', color: C.textMuted, fontWeight: 600 }}>
              Updated {lastUpdated.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
            </span>
          )}
          <motion.button
            whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }}
            onClick={loadData}
            style={{
              display: 'flex', alignItems: 'center', gap: '7px',
              padding: '8px 14px', borderRadius: '10px',
              border: `1.5px solid ${C.border}`, background: C.white,
              color: C.textSub, fontWeight: 700, cursor: 'pointer',
              fontSize: '0.82rem', fontFamily: 'inherit',
            }}
          >
            <motion.span
              animate={refreshing ? { rotate: 360 } : { rotate: 0 }}
              transition={refreshing ? { repeat: Infinity, duration: 1, ease: 'linear' } : {}}
              style={{ display: 'flex' }}
            >
              <RefreshCw size={14} />
            </motion.span>
            Refresh
          </motion.button>
          <div style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            padding: '8px 14px', borderRadius: '10px',
            background: '#ECFDF5', border: '1px solid #6EE7B7',
          }}>
            <motion.div
              animate={{ opacity: [1, 0.3, 1] }}
              transition={{ repeat: Infinity, duration: 2 }}
              style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10B981' }}
            />
            <span style={{ fontSize: '0.78rem', fontWeight: 700, color: '#059669' }}>Live · Auto-refresh</span>
          </div>
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div style={{
          padding: '12px 18px', background: '#FFF7ED',
          border: '1px solid #FED7AA', borderRadius: '12px',
          color: '#C2410C', fontSize: '0.875rem', fontWeight: 600, marginBottom: '20px',
        }}>
          ⚠️ {error}
        </div>
      )}

      {/* ── Stat Cards ── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: '16px', marginBottom: '20px' }}>
        {cards.map((card, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.07 }}
            whileHover={{ y: -3, boxShadow: '0 8px 24px rgba(12,99,126,0.12)' }}
            onClick={() => card?.to && navigate(card.to)}
            style={{
              background: C.white, borderRadius: '16px',
              border: `1px solid ${C.border}`,
              overflow: 'hidden', position: 'relative',
              boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
              cursor: card?.to ? 'pointer' : 'default',
            }}
          >
            {loading || !card ? (
              <div style={{ padding: '20px' }}>
                <Skeleton h={14} w="50%" mb={12} />
                <Skeleton h={32} w="40%" mb={10} />
                <Skeleton h={10} w="60%" />
              </div>
            ) : (
              <>
                <div style={{ height: '4px', background: card.accent }} />
                <div style={{ padding: '18px 20px 20px' }}>
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
                        background: '#FEF2F2', border: '1px solid #FECACA',
                      }}>
                        <motion.div
                          animate={{ opacity: [1, 0.2, 1] }}
                          transition={{ repeat: Infinity, duration: 1.4 }}
                          style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#EF4444' }}
                        />
                        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: '#EF4444', letterSpacing: '0.05em' }}>LIVE</span>
                      </div>
                    ) : (
                      <div style={{
                        display: 'flex', alignItems: 'center', gap: '4px',
                        padding: '4px 10px', borderRadius: '20px',
                        background: card.up ? '#F0FDF4' : '#FEF2F2',
                        border: `1px solid ${card.up ? '#BBF7D0' : '#FECACA'}`,
                      }}>
                        {card.up ? <TrendingUp size={12} color="#16A34A" /> : <TrendingDown size={12} color="#DC2626" />}
                        <span style={{ fontSize: '0.72rem', fontWeight: 800, color: card.up ? '#16A34A' : '#DC2626' }}>{card.trend}</span>
                      </div>
                    )}
                  </div>
                  <p style={{ fontSize: '1.75rem', fontWeight: 700, color: C.textMain, letterSpacing: '-0.02em', lineHeight: 1, marginBottom: '4px' }}>
                    {typeof card.value === 'number' ? card.value.toLocaleString() : (card.value ?? '—')}
                  </p>
                  <p style={{ fontSize: '0.85rem', fontWeight: 600, color: C.textSub, marginBottom: '2px' }}>{card.label}</p>
                  <p style={{ fontSize: '0.75rem', color: C.textMuted }}>{card.sub}</p>
                  <div style={{ display: 'flex', alignItems: 'flex-end', gap: '3px', marginTop: '14px', height: '28px' }}>
                    {sparkBars.map((h, j) => (
                      <div key={j} style={{
                        flex: 1, height: `${h}%`, borderRadius: '3px',
                        background: j === sparkBars.length - 1 ? card.accent : `${card.accent}30`,
                      }} />
                    ))}
                  </div>
                </div>
              </>
            )}
          </motion.div>
        ))}
      </div>

      {/* ── Quick Actions ── */}
      <div style={{
        background: C.white, borderRadius: '16px',
        border: `1px solid ${C.border}`,
        boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
        marginBottom: '20px', overflow: 'hidden',
      }}>
        <div style={{ padding: '18px 24px', borderBottom: `1px solid ${C.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>Quick Actions</h3>
            <p style={{ fontSize: '0.8rem', color: C.textMuted, marginTop: '2px' }}>Most-used admin tasks — one click to navigate</p>
          </div>
          <LayoutDashboard size={18} color={C.textMuted} />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6,1fr)', gap: '0', background: C.white }}>
          {quickActions.map((qa, i) => (
            <motion.div
              key={i}
              whileHover={{ backgroundColor: qa.pale }}
              onClick={() => navigate(qa.to)}
              style={{
                background: C.white, padding: '20px 16px',
                cursor: 'pointer', transition: 'background 0.15s',
                display: 'flex', flexDirection: 'column', gap: '10px',
                position: 'relative',
                borderRight: i < quickActions.length - 1 ? `1px solid ${C.border}` : 'none',
              }}
            >
              {/* Badge */}
              {qa.badge != null && (
                <div style={{
                  position: 'absolute', top: '10px', right: '10px',
                  minWidth: '20px', height: '20px', borderRadius: '10px',
                  background: qa.badgeColor, color: 'white',
                  fontSize: '0.65rem', fontWeight: 800,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  padding: '0 5px',
                }}>
                  {qa.pulse && (
                    <motion.div
                      animate={{ scale: [1, 1.5, 1], opacity: [1, 0, 1] }}
                      transition={{ repeat: Infinity, duration: 1.8 }}
                      style={{
                        position: 'absolute', inset: -3, borderRadius: '50%',
                        background: qa.badgeColor, opacity: 0.3,
                      }}
                    />
                  )}
                  {qa.badge}
                </div>
              )}
              <div style={{
                width: '42px', height: '42px', borderRadius: '12px',
                background: qa.pale, color: qa.accent,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                border: `1.5px solid ${qa.accent}22`,
              }}>
                <qa.Icon size={19} strokeWidth={2.5} />
              </div>
              <div>
                <p style={{ fontSize: '0.83rem', fontWeight: 700, color: C.textMain }}>{qa.label}</p>
                <p style={{ fontSize: '0.73rem', color: C.textMuted, marginTop: '3px', lineHeight: 1.4 }}>{qa.desc}</p>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: qa.accent, fontSize: '0.72rem', fontWeight: 700 }}>
                Open <ArrowRight size={11} />
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* ── Pending Verification Queue ── */}
      <div style={{
        background: C.white, borderRadius: '16px',
        border: `1px solid ${C.border}`,
        boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
        marginBottom: '20px', overflow: 'hidden',
      }}>
        {/* Header */}
        <div style={{
          padding: '18px 24px', borderBottom: `1px solid ${C.border}`,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          background: pendingResponders.length > 0 ? '#FFFBEB' : C.white,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '38px', height: '38px', borderRadius: '10px',
              background: pendingResponders.length > 0 ? '#FEF3C7' : '#ECFDF5',
              color: pendingResponders.length > 0 ? '#D97706' : '#10B981',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <UserCheck size={18} strokeWidth={2.5} />
            </div>
            <div>
              <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain, display: 'flex', alignItems: 'center', gap: '8px' }}>
                Pending Verification Queue
                {pendingResponders.length > 0 && (
                  <span style={{
                    background: '#EF4444', color: 'white',
                    fontSize: '0.68rem', fontWeight: 800,
                    padding: '2px 8px', borderRadius: '20px',
                    lineHeight: 1.5,
                  }}>
                    {pendingResponders.length} pending
                  </span>
                )}
              </h3>
              <p style={{ fontSize: '0.8rem', color: C.textMuted, marginTop: '2px' }}>
                Emergency responders awaiting credential review and activation
              </p>
            </div>
          </div>
          <motion.button
            whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
            onClick={() => navigate('/admin/verify')}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 16px', borderRadius: '10px',
              background: C.accent, color: 'white', border: 'none',
              fontWeight: 700, cursor: 'pointer', fontSize: '0.83rem', fontFamily: 'inherit',
            }}
          >
            <UserCheck size={14} /> View All
          </motion.button>
        </div>

        {/* Body */}
        {loading ? (
          <div style={{ padding: '20px 24px' }}>
            {Array(3).fill(null).map((_, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '14px', marginBottom: i < 2 ? '16px' : 0 }}>
                <Skeleton h={40} w="40px" br={20} />
                <div style={{ flex: 1 }}>
                  <Skeleton h={13} w="30%" mb={7} />
                  <Skeleton h={10} w="50%" />
                </div>
                <Skeleton h={13} w="15%" />
                <Skeleton h={13} w="12%" />
                <Skeleton h={30} w="70px" br={8} />
              </div>
            ))}
          </div>
        ) : pendingResponders.length === 0 ? (
          <div style={{ padding: '40px 24px', textAlign: 'center' }}>
            <CheckCircle size={44} style={{ color: '#10B981', opacity: 0.45, marginBottom: '12px' }} />
            <p style={{ fontWeight: 700, fontSize: '0.95rem', color: C.textSub, marginBottom: '4px' }}>Queue is clear!</p>
            <p style={{ fontSize: '0.84rem', color: C.textMuted }}>No responders are currently awaiting verification.</p>
          </div>
        ) : (
          <>
            {/* Table header */}
            <div style={{
              display: 'grid', gridTemplateColumns: '2fr 1.2fr 1.2fr 1fr 100px',
              padding: '10px 24px', background: '#F8FAFC',
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
            {/* Rows */}
            {pendingResponders.slice(0, 6).map((r, i) => (
              <motion.div
                key={r.id || i}
                initial={{ opacity: 0, x: -8 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.06 }}
                style={{
                  display: 'grid', gridTemplateColumns: '2fr 1.2fr 1.2fr 1fr 100px',
                  padding: '14px 24px', alignItems: 'center',
                  borderBottom: i < Math.min(pendingResponders.length, 6) - 1
                    ? `1px solid ${C.border}` : 'none',
                }}
                whileHover={{ backgroundColor: '#F8FAFC' }}
              >
                {/* Name + avatar */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '11px' }}>
                  <div style={{
                    width: '38px', height: '38px', borderRadius: '50%',
                    background: 'linear-gradient(135deg,#0C637E22,#2891C222)',
                    border: `1.5px solid ${C.accent}33`,
                    color: C.accent,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontWeight: 800, fontSize: '0.95rem', flexShrink: 0,
                  }}>
                    {(r.user?.fullName ?? r.fullName ?? '?')[0].toUpperCase()}
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <p style={{ fontWeight: 700, fontSize: '0.875rem', color: C.textMain, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {r.user?.fullName ?? r.fullName ?? '—'}
                    </p>
                    <p style={{ fontSize: '0.72rem', color: C.textMuted, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {r.user?.email ?? r.email ?? '—'}
                    </p>
                  </div>
                </div>
                {/* Responder type badge */}
                <div>
                  <span style={{
                    background: '#EDE9FE', color: '#7C3AED',
                    padding: '3px 10px', borderRadius: '20px',
                    fontSize: '0.73rem', fontWeight: 700, display: 'inline-block',
                  }}>
                    {RESPONDER_LABELS[r.responderType] ?? r.responderType ?? 'Responder'}
                  </span>
                </div>
                {/* Organization */}
                <p style={{ fontSize: '0.84rem', color: C.textSub, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {r.organization ?? '—'}
                </p>
                {/* Date */}
                <p style={{ fontSize: '0.78rem', color: C.textMuted }}>
                  {r.createdAt ? new Date(r.createdAt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: '2-digit' }) : '—'}
                </p>
                {/* Action */}
                <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                  <motion.button
                    whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
                    onClick={() => navigate('/admin/verify')}
                    style={{
                      padding: '6px 14px', borderRadius: '8px',
                      background: C.accent, color: 'white', border: 'none',
                      fontWeight: 700, fontSize: '0.78rem', cursor: 'pointer',
                      fontFamily: 'inherit', display: 'flex', alignItems: 'center', gap: '4px',
                    }}
                  >
                    Review <ArrowRight size={11} />
                  </motion.button>
                </div>
              </motion.div>
            ))}
            {/* "More" footer */}
            {pendingResponders.length > 6 && (
              <div style={{
                padding: '12px 24px', textAlign: 'center',
                borderTop: `1px solid ${C.border}`, background: '#F8FAFC',
              }}>
                <button
                  onClick={() => navigate('/admin/verify')}
                  style={{
                    background: 'none', border: 'none', color: C.accent,
                    fontWeight: 700, cursor: 'pointer', fontSize: '0.84rem', fontFamily: 'inherit',
                    display: 'inline-flex', alignItems: 'center', gap: '5px',
                  }}
                >
                  View {pendingResponders.length - 6} more in Verification Queue <ArrowRight size={13} />
                </button>
              </div>
            )}
          </>
        )}
      </div>

      {/* ── Analytics Charts ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: '16px', marginBottom: '20px' }}>

        {/* Emergency Trend Area Chart */}
        <div style={{ background: C.white, borderRadius: '16px', border: `1px solid ${C.border}`, boxShadow: '0 1px 4px rgba(12,99,126,0.05)', overflow: 'hidden' }}>
          <div style={{ padding: '18px 24px', borderBottom: `1px solid ${C.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>Emergency Trend</h3>
              <p style={{ fontSize: '0.75rem', color: C.textMuted, marginTop: '2px' }}>{analytics?.period ?? 'Last 14 days'}</p>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '4px 10px', background: '#E2F0F3', borderRadius: '8px' }}>
              <Activity size={12} color="#0C637E" />
              <span style={{ fontSize: '0.72rem', fontWeight: 700, color: '#0C637E' }}>{analytics?.totalInPeriod ?? 0} total</span>
            </div>
          </div>
          <div style={{ padding: '16px 8px 8px' }}>
            {loading || !analytics ? (
              <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Skeleton h={160} w="95%" />
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={180}>
                <AreaChart data={analytics.trend} margin={{ top: 4, right: 16, left: -16, bottom: 0 }}>
                  <defs>
                    <linearGradient id="gradResolved" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#0C637E" stopOpacity={0.18} />
                      <stop offset="95%" stopColor="#0C637E" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="gradTotal" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#2891C2" stopOpacity={0.12} />
                      <stop offset="95%" stopColor="#2891C2" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E4EEF3" />
                  <XAxis dataKey="date" tick={{ fontSize: 10, fill: '#7A96A3' }}
                    tickFormatter={d => { const dt = new Date(d); return `${dt.getDate()}/${dt.getMonth()+1}`; }} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 10, fill: '#7A96A3' }} />
                  <Tooltip
                    contentStyle={{ borderRadius: '10px', border: `1px solid ${C.border}`, fontSize: '0.78rem', fontFamily: 'inherit' }}
                    labelFormatter={d => new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })}
                  />
                  <Legend wrapperStyle={{ fontSize: '0.72rem', paddingTop: '8px' }} />
                  <Area type="monotone" dataKey="total"    name="Total"    stroke="#2891C2" fill="url(#gradTotal)"    strokeWidth={2} dot={false} />
                  <Area type="monotone" dataKey="resolved" name="Resolved" stroke="#0C637E" fill="url(#gradResolved)" strokeWidth={2} dot={false} />
                  <Area type="monotone" dataKey="cancelled" name="Cancelled" stroke="#EF4444" fill="none" strokeWidth={1.5} strokeDasharray="4 3" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        {/* Emergency Type Breakdown Bar Chart */}
        <div style={{ background: C.white, borderRadius: '16px', border: `1px solid ${C.border}`, boxShadow: '0 1px 4px rgba(12,99,126,0.05)', overflow: 'hidden' }}>
          <div style={{ padding: '18px 24px', borderBottom: `1px solid ${C.border}` }}>
            <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>By Type</h3>
            <p style={{ fontSize: '0.75rem', color: C.textMuted, marginTop: '2px' }}>Top emergency categories</p>
          </div>
          <div style={{ padding: '16px 8px 8px' }}>
            {loading || !analytics ? (
              <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Skeleton h={160} w="90%" />
              </div>
            ) : analytics.typeBreakdown.length === 0 ? (
              <div style={{ height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.textMuted, fontSize: '0.82rem' }}>
                No data yet
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={180}>
                <BarChart data={analytics.typeBreakdown.slice(0, 6)} layout="vertical"
                  margin={{ top: 0, right: 16, left: 8, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E4EEF3" horizontal={false} />
                  <XAxis type="number" allowDecimals={false} tick={{ fontSize: 10, fill: '#7A96A3' }} />
                  <YAxis type="category" dataKey="type" tick={{ fontSize: 9, fill: '#7A96A3' }} width={70} />
                  <Tooltip
                    contentStyle={{ borderRadius: '10px', border: `1px solid ${C.border}`, fontSize: '0.78rem', fontFamily: 'inherit' }}
                  />
                  <Bar dataKey="count" name="Count" fill="#0C637E" radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>

      {/* ── Bottom Row ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: '16px' }}>

        {/* ── Recent Activity (full-height, wider) ── */}
        <div style={{
          background: C.white, borderRadius: '16px',
          border: `1px solid ${C.border}`,
          boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
          overflow: 'hidden',
        }}>
          <div style={{
            padding: '20px 24px', borderBottom: `1px solid ${C.border}`,
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          }}>
            <div>
              <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>Recent Activity</h3>
              <p style={{ fontSize: '0.8rem', color: C.textMuted, marginTop: '2px' }}>Latest system events across the platform</p>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <motion.div
                animate={{ opacity: [1, 0.2, 1] }}
                transition={{ repeat: Infinity, duration: 1.6 }}
                style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10B981' }}
              />
              <span style={{ fontSize: '0.75rem', fontWeight: 800, color: '#10B981' }}>LIVE</span>
            </div>
          </div>

          {/* Recent Activity list */}
          <div style={{ padding: '8px 0', maxHeight: '340px', overflowY: 'auto' }}>
              {loading ? (
                Array(5).fill(null).map((_, i) => (
                  <div key={i} style={{ padding: '12px 20px', display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                    <Skeleton h={28} w="28px" br={14} />
                    <div style={{ flex: 1 }}>
                      <Skeleton h={11} w="70%" mb={5} />
                      <Skeleton h={9} w="45%" />
                    </div>
                  </div>
                ))
              ) : recentActivity.length === 0 ? (
                <div style={{ padding: '28px 20px', textAlign: 'center', color: C.textMuted }}>
                  <History size={28} style={{ opacity: 0.25, marginBottom: '8px' }} />
                  <p style={{ fontSize: '0.82rem', fontWeight: 600 }}>No activity yet</p>
                  <p style={{ fontSize: '0.75rem', opacity: 0.7, marginTop: '2px' }}>Events will appear here as the system is used</p>
                </div>
              ) : (
                recentActivity.map((entry, i) => {
                  const isError   = entry.level === 'ERROR';
                  const isWarning = entry.level === 'WARNING';
                  const dotColor  = isError ? '#EF4444' : isWarning ? '#F59E0B' : '#10B981';
                  const bgColor   = isError ? '#FEF2F2' : isWarning ? '#FFFBEB' : '#ECFDF5';
                  const iconColor = dotColor;

                  // pick an icon based on action keyword
                  const action = (entry.action || '').toUpperCase();
                  let Icon = Activity;
                  if (action.includes('USER') || action.includes('REGISTER')) Icon = Users;
                  else if (action.includes('LOGIN'))    Icon = Shield;
                  else if (action.includes('SOS') || action.includes('EMERGENCY')) Icon = Zap;
                  else if (action.includes('VERIFY') || action.includes('RESPONDER')) Icon = UserCheck;
                  else if (action.includes('DELETE'))   Icon = XCircle;
                  else if (action.includes('EMAIL') || action.includes('NOTIF')) Icon = Send;

                  // relative time
                  const ts = new Date(entry.timestamp);
                  const diffMin = Math.floor((Date.now() - ts.getTime()) / 60000);
                  const timeLabel = diffMin < 1 ? 'just now'
                    : diffMin < 60 ? `${diffMin}m ago`
                    : diffMin < 1440 ? `${Math.floor(diffMin / 60)}h ago`
                    : ts.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });

                  // clean up action label
                  const label = (entry.action || 'System Event')
                    .replace(/_/g, ' ')
                    .toLowerCase()
                    .replace(/^\w/, c => c.toUpperCase());

                  return (
                    <div
                      key={entry.id || i}
                      style={{
                        display: 'flex', alignItems: 'flex-start', gap: '12px',
                        padding: '11px 20px',
                        borderBottom: i < recentActivity.length - 1 ? `1px solid ${C.border}` : 'none',
                      }}
                    >
                      {/* Icon bubble */}
                      <div style={{
                        width: '30px', height: '30px', borderRadius: '9px',
                        background: bgColor, color: iconColor, flexShrink: 0,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        <Icon size={14} strokeWidth={2.5} />
                      </div>

                      {/* Text */}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <p style={{
                          fontSize: '0.8rem', fontWeight: 700, color: C.textMain,
                          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                          marginBottom: '2px',
                        }}>
                          {label}
                        </p>
                        <p style={{
                          fontSize: '0.71rem', color: C.textMuted, lineHeight: 1.4,
                          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                        }}>
                          {entry.user || 'System'}
                          {entry.entity ? ` · ${entry.entity}` : ''}
                        </p>
                      </div>

                      {/* Time */}
                      <span style={{
                        fontSize: '0.68rem', color: C.textMuted,
                        fontWeight: 600, whiteSpace: 'nowrap', flexShrink: 0,
                      }}>
                        {timeLabel}
                      </span>
                    </div>
                  );
                })
              )}
          </div>

          {/* View all link at bottom */}
          <div style={{ padding: '12px 24px', borderTop: `1px solid ${C.border}`, textAlign: 'right' }}>
            <Link to="/admin/logs" style={{ fontSize: '0.78rem', fontWeight: 700, color: C.accent, textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
              View all logs <ArrowRight size={12} />
            </Link>
          </div>
        </div>

        {/* ── Right: Quick Actions ── */}
        <div style={{
          background: C.white, borderRadius: '16px',
          border: `1px solid ${C.border}`,
          boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
          overflow: 'hidden',
        }}>
          <div style={{ padding: '18px 22px', borderBottom: `1px solid ${C.border}` }}>
            <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>Quick Actions</h3>
            <p style={{ fontSize: '0.72rem', color: C.textMuted, marginTop: '2px' }}>Jump to key admin tasks</p>
          </div>
          <div style={{ padding: '12px 16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {[
              { label: 'Review Pending Responders', sub: `${pendingCount ?? 0} awaiting approval`, icon: UserCheck, color: '#F59E0B', bg: '#FFFBEB', to: '/admin/verify' },
              { label: 'Monitor Active SOS', sub: `${stats?.activeEmergencies ?? 0} active emergencies`, icon: Activity, color: '#EF4444', bg: '#FEF2F2', to: '/admin/sos' },
              { label: 'User Management', sub: `${stats?.totalUsers ?? 0} total users`, icon: Users, color: '#0C637E', bg: '#E2F0F3', to: '/admin/users' },
              { label: 'Send Notification', sub: 'Broadcast to all users', icon: Bell, color: '#6366F1', bg: '#EEF2FF', to: '/admin/notifications' },
              { label: 'Communication Audit', sub: 'Email & push history', icon: Send, color: '#2496A7', bg: '#E0F7FA', to: '/admin/emails' },
              { label: 'Subscription Plans', sub: 'Manage user subscriptions', icon: CreditCard, color: '#10B981', bg: '#ECFDF5', to: '/admin/subscriptions' },
            ].map((item, i) => (
              <Link
                key={i}
                to={item.to}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  padding: '10px 12px', borderRadius: '12px',
                  border: `1px solid ${C.border}`,
                  textDecoration: 'none', transition: 'all 0.15s',
                  background: 'transparent',
                }}
                onMouseEnter={e => { e.currentTarget.style.background = item.bg; e.currentTarget.style.borderColor = item.color + '44'; }}
                onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.borderColor = C.border; }}
              >
                <div style={{ width: '34px', height: '34px', borderRadius: '9px', background: item.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <item.icon size={16} color={item.color} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontSize: '0.82rem', fontWeight: 700, color: C.textMain, marginBottom: '1px' }}>{item.label}</p>
                  <p style={{ fontSize: '0.7rem', color: C.textMuted }}>{item.sub}</p>
                </div>
                <ArrowRight size={13} color={C.textMuted} />
              </Link>
            ))}
          </div>
        </div>

      </div>
    </motion.div>
  );
}

/* ─── System Health Panel (real data) ──────────────────────────────────── */
function SystemHealthPanel({ health, loading }) {
  // Map backend status strings to colours and labels
  const STATUS = {
    healthy:  { color: '#10B981', bg: '#ECFDF5', label: 'Healthy'  },
    degraded: { color: '#F59E0B', bg: '#FFFBEB', label: 'Degraded' },
    down:     { color: '#EF4444', bg: '#FEF2F2', label: 'Down'     },
  };

  const services = health ? [
    {
      label: 'API Gateway',
      key: 'api',
      extra: health.services.api.latencyMs != null
        ? `${health.services.api.latencyMs} ms` : null,
    },
    {
      label: 'Database',
      key: 'database',
      extra: health.services.database.latencyMs != null
        ? `${health.services.database.latencyMs} ms` : null,
    },
    { label: 'Push Service',  key: 'push',   extra: null },
    { label: 'Socket Layer',  key: 'socket', extra: null },
  ] : [];

  // Format uptime: e.g. 2d 4h 13m
  const formatUptime = (secs) => {
    if (secs == null) return '—';
    const d = Math.floor(secs / 86400);
    const h = Math.floor((secs % 86400) / 3600);
    const m = Math.floor((secs % 3600) / 60);
    if (d > 0) return `${d}d ${h}h ${m}m`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m ${secs % 60}s`;
  };

  return (
    <div style={{
      background: C.white, borderRadius: '16px',
      border: `1px solid ${C.border}`,
      boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
      overflow: 'hidden',
    }}>
      <div style={{
        padding: '18px 22px', borderBottom: `1px solid ${C.border}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <div>
          <h3 style={{ fontSize: '1rem', fontWeight: 800, color: C.textMain }}>System Health</h3>
          {health && (
            <p style={{ fontSize: '0.72rem', color: C.textMuted, marginTop: '2px' }}>
              Uptime: <strong style={{ color: '#10B981' }}>{formatUptime(health.uptime)}</strong>
            </p>
          )}
        </div>
        <Shield size={16} color={C.textMuted} />
      </div>

      <div style={{ padding: '16px 22px' }}>
        {loading ? (
          Array(4).fill(null).map((_, i) => (
            <div key={i} style={{ marginBottom: i < 3 ? '14px' : 0 }}>
              <Skeleton h={10} w="60%" mb={6} />
              <Skeleton h={5} w="100%" />
            </div>
          ))
        ) : (
          services.map(({ label, key, extra }, i) => {
            const svc    = health.services[key];
            const s      = STATUS[svc?.status] || STATUS.down;
            return (
              <div key={i} style={{ marginBottom: i < services.length - 1 ? '14px' : 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '5px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '7px' }}>
                    <span style={{ fontSize: '0.8rem', fontWeight: 600, color: C.textSub }}>{label}</span>
                    {extra && (
                      <span style={{ fontSize: '0.68rem', color: C.textMuted, fontWeight: 600 }}>
                        ({extra})
                      </span>
                    )}
                  </div>
                  <span style={{
                    fontSize: '0.68rem', fontWeight: 800, padding: '2px 8px',
                    borderRadius: '6px', background: s.bg, color: s.color,
                  }}>
                    {s.label}
                  </span>
                </div>
                <div style={{ height: '5px', background: '#E2ECF0', borderRadius: '3px' }}>
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: svc?.status === 'healthy' ? '100%' : svc?.status === 'degraded' ? '55%' : '10%' }}
                    transition={{ delay: 0.3 + i * 0.08, duration: 0.9, ease: 'easeOut' }}
                    style={{
                      height: '100%',
                      background: `linear-gradient(90deg,#0C637E,${s.color})`,
                      borderRadius: '3px',
                    }}
                  />
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Memory usage footer */}
      {health && !loading && (
        <div style={{
          padding: '12px 22px', background: '#FAFCFD',
          borderTop: `1px solid ${C.border}`,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: C.textMuted }}>
              Heap Memory
            </span>
            <span style={{ fontSize: '0.75rem', fontWeight: 800, color: health.memory.usedPct > 80 ? '#EF4444' : '#10B981' }}>
              {health.memory.usedMB} / {health.memory.totalMB} MB ({health.memory.usedPct}%)
            </span>
          </div>
          <div style={{ height: '5px', background: '#E2ECF0', borderRadius: '3px' }}>
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${health.memory.usedPct}%` }}
              transition={{ delay: 0.6, duration: 1.0, ease: 'easeOut' }}
              style={{
                height: '100%',
                background: health.memory.usedPct > 80
                  ? 'linear-gradient(90deg,#F59E0B,#EF4444)'
                  : 'linear-gradient(90deg,#0C637E,#10B981)',
                borderRadius: '3px',
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}

/* ─── Skeleton helper ───────────────────────────────────────────────────── */
function Skeleton({ h, w, mb = 0, br = 6 }) {
  return (
    <div style={{
      height: h, width: w, borderRadius: br, marginBottom: mb,
      background: 'linear-gradient(90deg,#EEF2F5 25%,#E4EBF0 50%,#EEF2F5 75%)',
      backgroundSize: '200% 100%',
      animation: 'shimmer 1.4s ease infinite',
    }} />
  );
}

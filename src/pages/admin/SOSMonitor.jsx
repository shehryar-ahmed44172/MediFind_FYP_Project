import React, { useState, useEffect, useRef } from 'react';
import { Activity, MapPin, Clock, Phone, AlertTriangle, ShieldCheck, RefreshCw, User, Filter, Wifi, WifiOff, Users, Navigation } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useSearchParams } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { io } from 'socket.io-client';
import api from '../../services/api';

// Fix Leaflet default marker icons broken by Vite/Webpack bundling
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl:       'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl:     'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

// Custom red icon for active emergencies (patient SOS)
const redIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41],
});

// Green icon for available online responders
const greenIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [20, 33], iconAnchor: [10, 33], popupAnchor: [1, -28], shadowSize: [33, 33],
});

// Orange icon for assigned/en-route responders
const orangeIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-orange.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [20, 33], iconAnchor: [10, 33], popupAnchor: [1, -28], shadowSize: [33, 33],
});

// Client-side Haversine: returns distance in km between two GPS points
const haversineKm = (lat1, lon1, lat2, lon2) => {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

const NEARBY_RADIUS_KM = 5; // radius used for "nearby" badge on cards

// ─── Ctrl+Scroll overlay: shows hint when user scrolls without Ctrl ──────────
function CtrlScrollHint() {
  const map = useMap();
  const [hint, setHint] = React.useState(false);
  const timerRef = React.useRef(null);

  React.useEffect(() => {
    const container = map.getContainer();

    const onWheel = (e) => {
      if (!e.ctrlKey) {
        // Scroll without Ctrl — show hint, let page scroll naturally
        e.stopPropagation();
        setHint(true);
        clearTimeout(timerRef.current);
        timerRef.current = setTimeout(() => setHint(false), 1500);
      }
    };

    // Enable scroll zoom only when Ctrl is held
    map.scrollWheelZoom.disable();
    container.addEventListener('wheel', onWheel, { passive: true });

    // When Ctrl is pressed and mouse is over map, re-enable zoom
    const onKeyDown = (e) => { if (e.ctrlKey) map.scrollWheelZoom.enable(); };
    const onKeyUp   = ()  => { map.scrollWheelZoom.disable(); setHint(false); };

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup',   onKeyUp);

    return () => {
      container.removeEventListener('wheel', onWheel);
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup',   onKeyUp);
      clearTimeout(timerRef.current);
    };
  }, [map]);

  if (!hint) return null;

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 1000,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      pointerEvents: 'none',
    }}>
      <div style={{
        background: 'rgba(0,0,0,0.72)', color: 'white',
        padding: '0.75rem 1.5rem', borderRadius: '10px',
        fontSize: '0.9rem', fontWeight: 600,
        display: 'flex', alignItems: 'center', gap: '0.5rem',
        backdropFilter: 'blur(4px)',
      }}>
        🖱️ Use <kbd style={{ background: 'rgba(255,255,255,0.2)', padding: '0.15rem 0.4rem', borderRadius: '4px', fontFamily: 'monospace' }}>Ctrl</kbd> + scroll to zoom the map
      </div>
    </div>
  );
}

const STATUS_STYLE = {
  ACTIVE:    { color: 'var(--s-active)',    bg: 'var(--s-active-bg)',    tint: 'var(--s-active-tint)',    label: 'Active'    },
  PENDING:   { color: 'var(--s-pending)',   bg: 'var(--s-pending-bg)',   tint: 'var(--s-pending-tint)',   label: 'Pending'   },
  ASSIGNED:  { color: 'var(--s-assigned)',  bg: 'var(--s-assigned-bg)',  tint: 'var(--s-assigned-tint)',  label: 'Assigned'  },
  RESOLVED:  { color: 'var(--s-resolved)',  bg: 'var(--s-resolved-bg)',  tint: 'var(--s-resolved-tint)',  label: 'Resolved'  },
  COMPLETED: { color: 'var(--s-resolved)',  bg: 'var(--s-resolved-bg)',  tint: 'var(--s-resolved-tint)',  label: 'Completed' },
  CANCELLED: { color: 'var(--s-cancelled)', bg: 'var(--s-cancelled-bg)', tint: 'var(--s-cancelled-tint)', label: 'Cancelled' },
};

const FILTER_OPTIONS = [
  { key: 'ALL',       label: 'All',       color: 'var(--primary)',    statuses: null },
  { key: 'ACTIVE',    label: 'Active',    color: 'var(--s-active)',   statuses: ['ACTIVE'] },
  { key: 'ASSIGNED',  label: 'Assigned',  color: 'var(--s-assigned)', statuses: ['ASSIGNED'] },
  { key: 'RESOLVED',  label: 'Resolved',  color: 'var(--s-resolved)', statuses: ['RESOLVED', 'COMPLETED'] },
  { key: 'CANCELLED', label: 'Cancelled', color: 'var(--s-cancelled)',statuses: ['CANCELLED'] },
];

const formatTime = (iso) => {
  if (!iso) return '—';
  return new Date(iso).toLocaleTimeString('en-PK', { hour: '2-digit', minute: '2-digit', hour12: true });
};

const timeAgo = (iso) => {
  if (!iso) return '';
  const diff = Math.floor((Date.now() - new Date(iso)) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
};

const SOSMonitor = () => {
  const [searchParams] = useSearchParams();
  const urlFilter = searchParams.get('filter')?.toUpperCase();
  const validFilters = FILTER_OPTIONS.map(f => f.key);
  // Default to ACTIVE so the live monitor only shows current emergencies.
  // Historical data (Cancelled, Resolved) is accessible via the All filter or stat cards.
  const initialFilter = validFilters.includes(urlFilter) ? urlFilter : 'ACTIVE';

  const [emergencies,        setEmergencies]        = useState([]);
  const [loading,            setLoading]            = useState(true);
  const [error,              setError]              = useState('');
  const [lastUpdated,        setLastUpdated]        = useState(null);
  const [activeFilter,       setActiveFilter]       = useState(initialFilter);
  const [socketOnline,       setSocketOnline]       = useState(false);
  const [timeRange,          setTimeRange]          = useState('today'); // 'today' | 'week' | 'all'
  const [onlineResponders,   setOnlineResponders]   = useState([]); // live GPS-located available responders
  const [selectedEmergency,  setSelectedEmergency]  = useState(null); // clicked emergency for map focus
  const intervalRef    = useRef(null);
  const respIntervalRef = useRef(null);
  const socketRef      = useRef(null);

  const fetchEmergencies = async () => {
    try {
      const response = await api.get('/api/emergencies');
      if (response.data.success) {
        setEmergencies(response.data.data);
        setLastUpdated(new Date());
        setError('');
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to fetch emergencies.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEmergencies();
    intervalRef.current = setInterval(fetchEmergencies, 4000); // 4s — fast enough to catch status changes without socket
    return () => clearInterval(intervalRef.current);
  }, []);

  // ── Online responders: fetch on mount then every 10 s ──────────────────────
  const fetchOnlineResponders = async () => {
    try {
      const res = await api.get('/api/admin/responders/online');
      if (res.data.success) setOnlineResponders(res.data.data || []);
    } catch { /* silent — map still shows without responder pins */ }
  };

  useEffect(() => {
    fetchOnlineResponders();
    respIntervalRef.current = setInterval(fetchOnlineResponders, 10000);
    return () => clearInterval(respIntervalRef.current);
  }, []);

  // ── Real-time Socket.io connection ──────────────────────────────────────
  useEffect(() => {
    const BACKEND = import.meta.env.VITE_API_URL || 'http://localhost:3000';
    const token   = localStorage.getItem('accessToken') || sessionStorage.getItem('accessToken') || '';

    const socket = io(BACKEND, {
      auth: { token },
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 5,
      reconnectionDelay: 2000,
    });
    socketRef.current = socket;

    socket.on('connect', () => {
      setSocketOnline(true);
      // Join admin_notifications room so we receive emergency status changes
      socket.emit('join', { role: 'ADMIN' });
    });

    socket.on('disconnect', () => setSocketOnline(false));
    socket.on('connect_error', () => setSocketOnline(false));

    // Backend emits EMERGENCY_STATUS_CHANGE to admin_notifications on cancel/update
    socket.on('EMERGENCY_STATUS_CHANGE', () => {
      // Re-fetch immediately — don't wait for the 10-second poll
      fetchEmergencies();
    });

    // Also listen for new SOS triggers broadcast to admin
    socket.on('admin_notification', (data) => {
      if (data?.type === 'SOS_TRIGGERED' || data?.type === 'EMERGENCY_STATUS_CHANGE') {
        fetchEmergencies();
      }
    });

    // Responder moved during an active emergency — refresh the online responders list
    // so the green pin on the admin map stays up to date without waiting for the 10s poll
    socket.on('LOCATION_UPDATE', () => { fetchOnlineResponders(); });
    socket.on('RESPONDER_LOCATION_UPDATE', () => { fetchOnlineResponders(); });

    return () => {
      socket.disconnect();
      socketRef.current = null;
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Update filter when URL param changes (e.g. user clicks a stat card again)
  useEffect(() => { setActiveFilter(initialFilter); }, [initialFilter]);

  /* ── Time-range scoping — applied before status filter ── */
  const scopedEmergencies = (() => {
    if (timeRange === 'today') {
      const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
      return emergencies.filter(e => new Date(e.createdAt) >= cutoff);
    }
    if (timeRange === 'week') {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      return emergencies.filter(e => new Date(e.createdAt) >= cutoff);
    }
    return emergencies; // 'all'
  })();

  /* ── Derived data ── */
  const filterOpt = FILTER_OPTIONS.find(f => f.key === activeFilter);
  const filtered  = activeFilter === 'ALL'
    ? scopedEmergencies
    : scopedEmergencies.filter(e => filterOpt?.statuses?.includes(e.status));

  const activeEmergencies = scopedEmergencies.filter(e => e.status === 'ACTIVE');

  /* ── Status breakdown counts (scoped to selected time range) ── */
  const breakdown = {
    ACTIVE:    scopedEmergencies.filter(e => e.status === 'ACTIVE').length,
    ASSIGNED:  scopedEmergencies.filter(e => e.status === 'ASSIGNED').length,
    RESOLVED:  scopedEmergencies.filter(e => ['RESOLVED', 'COMPLETED'].includes(e.status)).length,
    CANCELLED: scopedEmergencies.filter(e => e.status === 'CANCELLED').length,
  };

  /* ── Map center: center of all active emergencies or Pakistan default ── */
  const mapCenter = activeEmergencies.length > 0
    ? [
        activeEmergencies.reduce((s, e) => s + (e.latitude || 30.3753), 0) / activeEmergencies.length,
        activeEmergencies.reduce((s, e) => s + (e.longitude || 69.3451), 0) / activeEmergencies.length,
      ]
    : [30.3753, 69.3451]; // Pakistan center

  /* ── Show map whenever there's something to display ── */
  const shouldShowMap = !loading && (activeEmergencies.length > 0 || onlineResponders.length > 0);

  /* ── Per-emergency nearby responder count (client-side Haversine) ── */
  const nearbyCount = (emergency) => {
    if (!emergency?.latitude || !emergency?.longitude) return 0;
    return onlineResponders.filter(r =>
      r.currentLatitude && r.currentLongitude &&
      haversineKm(emergency.latitude, emergency.longitude, r.currentLatitude, r.currentLongitude) <= NEARBY_RADIUS_KM
    ).length;
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.4 }}
    >
      {/* ── Page Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '1.5rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '0.375rem' }}>
            <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-sub)', letterSpacing: '-0.03em' }}>
              SOS Logistics
            </h1>
            <div style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              background: 'var(--s-resolved-bg)', color: 'var(--s-resolved)',
              padding: '0.3rem 0.875rem', borderRadius: '100px',
              fontSize: '0.7rem', fontWeight: 800,
              textTransform: 'uppercase', letterSpacing: '0.06em',
            }}>
              <motion.div
                animate={{ scale: [1, 1.5, 1], opacity: [0.5, 1, 0.5] }}
                transition={{ repeat: Infinity, duration: 1.5 }}
                style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--s-resolved)', flexShrink: 0 }}
              />
              Live
            </div>
            {/* Real-time socket status pill */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: '0.4rem',
              padding: '0.25rem 0.75rem', borderRadius: '100px',
              fontSize: '0.68rem', fontWeight: 700,
              background: socketOnline ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.08)',
              color: socketOnline ? '#059669' : '#DC2626',
              border: `1px solid ${socketOnline ? 'rgba(16,185,129,0.25)' : 'rgba(239,68,68,0.2)'}`,
            }}>
              {socketOnline ? <Wifi size={11} /> : <WifiOff size={11} />}
              {socketOnline ? 'Real-time' : 'Polling only'}
            </div>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
            {activeFilter === 'ACTIVE'
              ? `Live view of active emergencies. ${onlineResponders.length} responder${onlineResponders.length !== 1 ? 's' : ''} online on map.`
              : activeFilter === 'ALL'
              ? 'All emergency requests with full status breakdown.'
              : `Filtered view — ${filterOpt?.label} emergencies.`}
            {lastUpdated && (
              <span style={{ marginLeft: '0.875rem', fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                Updated {timeAgo(lastUpdated)}
              </span>
            )}
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {/* Time-range toggle */}
          <div style={{
            display: 'flex', alignItems: 'center',
            border: '1px solid var(--border)', borderRadius: '10px',
            overflow: 'hidden', background: 'var(--surface)',
          }}>
            {[
              { key: 'today', label: 'Today' },
              { key: 'week',  label: '7 Days' },
              { key: 'all',   label: 'All Time' },
            ].map(tr => (
              <button
                key={tr.key}
                onClick={() => setTimeRange(tr.key)}
                style={{
                  padding: '6px 14px', border: 'none',
                  background: timeRange === tr.key ? 'var(--primary)' : 'transparent',
                  color: timeRange === tr.key ? 'white' : 'var(--text-muted)',
                  fontWeight: 700, fontSize: '0.78rem',
                  cursor: 'pointer', fontFamily: 'inherit',
                  transition: 'all 0.15s ease',
                }}
              >
                {tr.label}
              </button>
            ))}
          </div>
          <motion.button
            whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}
            onClick={fetchEmergencies}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.7rem 1.375rem', borderRadius: '12px',
              border: '1px solid var(--border)', background: 'var(--surface)',
              color: 'var(--text-sub)', fontWeight: 700, cursor: 'pointer',
              fontSize: '0.875rem', fontFamily: 'inherit',
            }}
          >
            <RefreshCw size={15} /> Refresh
          </motion.button>
        </div>
      </div>

      {/* ── Stats Breakdown Cards ── */}
      {!loading && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: '12px', marginBottom: '1.25rem' }}>
          {[
            { key: 'ACTIVE',    label: 'Active SOS', count: breakdown.ACTIVE,    color: 'var(--s-active)',    bg: 'var(--s-active-bg)'    },
            { key: 'ASSIGNED',  label: 'Assigned',   count: breakdown.ASSIGNED,  color: 'var(--s-assigned)',  bg: 'var(--s-assigned-bg)'  },
            { key: 'RESOLVED',  label: 'Resolved',   count: breakdown.RESOLVED,  color: 'var(--s-resolved)',  bg: 'var(--s-resolved-bg)'  },
            { key: 'CANCELLED', label: 'Cancelled',  count: breakdown.CANCELLED, color: 'var(--s-cancelled)', bg: 'var(--s-cancelled-bg)' },
          ].map(stat => (
            <motion.div
              key={stat.key}
              whileHover={{ y: -2 }}
              onClick={() => setActiveFilter(stat.key)}
              style={{
                background: activeFilter === stat.key ? stat.bg : 'var(--surface)',
                border: `1.5px solid ${activeFilter === stat.key ? stat.color : 'var(--border)'}`,
                borderRadius: '14px', padding: '14px 18px',
                cursor: 'pointer', transition: 'all 0.18s ease',
              }}
            >
              <p style={{ fontSize: '1.75rem', fontWeight: 800, color: stat.color, lineHeight: 1, marginBottom: '4px' }}>
                {stat.count}
              </p>
              <p style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)' }}>{stat.label}</p>
            </motion.div>
          ))}
          {/* Online Responders — not a filter, just a live counter */}
          <motion.div
            whileHover={{ y: -2 }}
            style={{
              background: 'var(--surface)',
              border: '1.5px solid #10B981',
              borderRadius: '14px', padding: '14px 18px',
              position: 'relative', overflow: 'hidden',
            }}
          >
            <motion.div
              animate={{ opacity: [0.15, 0.35, 0.15] }}
              transition={{ repeat: Infinity, duration: 2 }}
              style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg,#10B98112,transparent)', pointerEvents: 'none' }}
            />
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
              <p style={{ fontSize: '1.75rem', fontWeight: 800, color: '#10B981', lineHeight: 1 }}>
                {onlineResponders.length}
              </p>
              <motion.div
                animate={{ scale: [1, 1.4, 1], opacity: [0.6, 1, 0.6] }}
                transition={{ repeat: Infinity, duration: 1.6 }}
                style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#10B981', flexShrink: 0 }}
              />
            </div>
            <p style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)' }}>Online Responders</p>
          </motion.div>
        </div>
      )}

      {/* ── Filter Buttons ── */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '1.25rem', flexWrap: 'wrap' }}>
        <Filter size={14} color="var(--text-muted)" />
        {FILTER_OPTIONS.map(f => {
          const on = activeFilter === f.key;
          return (
            <button
              key={f.key}
              onClick={() => setActiveFilter(f.key)}
              style={{
                padding: '6px 14px', borderRadius: '20px',
                border: `1.5px solid ${on ? f.color : 'var(--border)'}`,
                background: on ? f.color : 'var(--surface)',
                color: on ? 'white' : 'var(--text-sub)',
                fontWeight: 700, fontSize: '0.8rem', cursor: 'pointer',
                fontFamily: 'inherit', transition: 'all 0.15s ease',
              }}
            >
              {f.label}
              {f.key !== 'ALL' && !loading && (
                <span style={{ marginLeft: '5px', opacity: 0.8 }}>
                  ({f.statuses?.reduce((acc, s) => acc + scopedEmergencies.filter(e => e.status === s).length, 0)})
                </span>
              )}
              {f.key === 'ALL' && !loading && (
                <span style={{ marginLeft: '5px', opacity: 0.8 }}>({scopedEmergencies.length})</span>
              )}
            </button>
          );
        })}
      </div>

      {/* ── Active Emergency Alert Banner ── */}
      {breakdown.ACTIVE > 0 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }}
          style={{
            padding: '1rem 1.5rem', background: 'var(--error-bg)',
            border: '1px solid var(--error-border)', borderRadius: '14px',
            marginBottom: '1.25rem', display: 'flex', alignItems: 'center', gap: '0.875rem',
          }}
        >
          <motion.div animate={{ scale: [1, 1.2, 1] }} transition={{ repeat: Infinity, duration: 1.4 }}>
            <AlertTriangle size={20} style={{ color: 'var(--s-active)' }} />
          </motion.div>
          <span style={{ fontWeight: 700, color: 'var(--error-fg)', fontSize: '0.95rem' }}>
            {breakdown.ACTIVE} active emergency{breakdown.ACTIVE > 1 ? 'ies' : ''} requiring immediate attention
          </span>
        </motion.div>
      )}

      {/* ── Live Map ─────────────────────────────────────────────────────────────
           Shows two layers simultaneously:
             🔴  Patient SOS pins  (red) — ACTIVE emergencies only
             🟢  Responder pins    (green) — all available + GPS-located responders
           Click any SOS pin / card to draw a 5 km radius and highlight nearby
           responders. isolation:isolate traps Leaflet z-indexes inside the box.
      ─────────────────────────────────────────────────────────────────────────── */}
      {shouldShowMap && (
        <motion.div
          initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
          style={{
            marginBottom: '1.5rem', borderRadius: '16px',
            border: activeEmergencies.length > 0 ? '1.5px solid var(--s-active)' : '1.5px solid #10B981',
            overflow: 'hidden',
            boxShadow: activeEmergencies.length > 0 ? '0 4px 24px rgba(239,68,68,0.12)' : '0 4px 24px rgba(16,185,129,0.12)',
            position: 'relative', isolation: 'isolate', zIndex: 0,
          }}
        >
          {/* Map header bar */}
          <div style={{
            padding: '10px 18px',
            background: activeEmergencies.length > 0 ? 'var(--error-bg)' : 'rgba(16,185,129,0.06)',
            borderBottom: `1px solid ${activeEmergencies.length > 0 ? 'var(--s-active)' : '#10B981'}`,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              {activeEmergencies.length > 0 && (
                <motion.div
                  animate={{ opacity: [1, 0.3, 1] }} transition={{ repeat: Infinity, duration: 1.2 }}
                  style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--s-active)', flexShrink: 0 }}
                />
              )}
              <span style={{ fontWeight: 800, color: activeEmergencies.length > 0 ? 'var(--s-active)' : '#10B981', fontSize: '0.85rem' }}>
                LIVE MAP
                {activeEmergencies.length > 0 && ` — ${activeEmergencies.length} Active SOS Signal${activeEmergencies.length !== 1 ? 's' : ''}`}
              </span>
              {selectedEmergency && (
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                  · Showing {NEARBY_RADIUS_KM} km radius for selected SOS
                </span>
              )}
            </div>
            {/* Legend */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: '#EF4444' }}>
                <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#EF4444' }} />
                Patient SOS
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: '#10B981' }}>
                <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10B981' }} />
                Available Responder ({onlineResponders.length})
              </div>
              {selectedEmergency && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: '#3B82F6' }}>
                  <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#3B82F640', border: '1.5px solid #3B82F6' }} />
                  {NEARBY_RADIUS_KM} km radius
                </div>
              )}
              {selectedEmergency && (
                <button
                  onClick={() => setSelectedEmergency(null)}
                  style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', background: 'none', border: 'none', cursor: 'pointer', padding: '2px 6px', borderRadius: '4px' }}
                >
                  ✕ Clear
                </button>
              )}
            </div>
          </div>

          {/* Map itself */}
          <div style={{ position: 'relative' }}>
            <MapContainer
              center={mapCenter}
              zoom={activeEmergencies.length > 0 ? 12 : 6}
              style={{ height: '420px', width: '100%' }}
              key={`${activeFilter}-${onlineResponders.length}`}
              scrollWheelZoom={false}
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <CtrlScrollHint />

              {/* ── Patient SOS markers (red) ── */}
              {activeEmergencies.map((e) => (
                e.latitude && e.longitude ? (
                  <React.Fragment key={e.id}>
                    <Circle
                      center={[e.latitude, e.longitude]}
                      radius={250}
                      color="#EF4444" fillColor="#EF4444" fillOpacity={0.12}
                    />
                    <Marker
                      position={[e.latitude, e.longitude]}
                      icon={redIcon}
                      eventHandlers={{ click: () => setSelectedEmergency(e) }}
                    >
                      <Popup>
                        <div style={{ minWidth: '200px' }}>
                          <strong style={{ color: '#EF4444', fontSize: '13px', display: 'block', marginBottom: '6px' }}>
                            🆘 {e.emergencyType || 'Medical'} Emergency
                          </strong>
                          <p style={{ margin: '0 0 2px', fontSize: '13px', fontWeight: 600 }}>
                            {e.patient?.fullName || 'Unknown Patient'}
                          </p>
                          <p style={{ margin: '0 0 4px', fontSize: '12px', color: '#64748B' }}>
                            📞 {e.patient?.phoneNumber || 'No phone'}
                          </p>
                          <p style={{ margin: '0 0 6px', fontSize: '11px', color: '#94A3B8', fontFamily: 'monospace' }}>
                            {e.latitude?.toFixed(5)}, {e.longitude?.toFixed(5)}
                          </p>
                          <div style={{ background: nearbyCount(e) > 0 ? '#ECFDF5' : '#FEF2F2', borderRadius: '6px', padding: '4px 8px', fontSize: '12px', fontWeight: 700, color: nearbyCount(e) > 0 ? '#059669' : '#DC2626' }}>
                            {nearbyCount(e) > 0
                              ? `✅ ${nearbyCount(e)} responder${nearbyCount(e) !== 1 ? 's' : ''} within ${NEARBY_RADIUS_KM} km`
                              : `⚠️ No responders within ${NEARBY_RADIUS_KM} km`}
                          </div>
                          <button
                            onClick={() => setSelectedEmergency(e)}
                            style={{ marginTop: '8px', width: '100%', padding: '5px', borderRadius: '6px', background: '#3B82F6', color: 'white', border: 'none', fontWeight: 700, fontSize: '11px', cursor: 'pointer' }}
                          >
                            Show {NEARBY_RADIUS_KM} km radius
                          </button>
                        </div>
                      </Popup>
                    </Marker>
                  </React.Fragment>
                ) : null
              ))}

              {/* ── 5 km radius circle for selected emergency ── */}
              {selectedEmergency?.latitude && selectedEmergency?.longitude && (
                <Circle
                  center={[selectedEmergency.latitude, selectedEmergency.longitude]}
                  radius={NEARBY_RADIUS_KM * 1000}
                  color="#3B82F6" fillColor="#3B82F6" fillOpacity={0.06}
                  weight={2} dashArray="6 4"
                />
              )}

              {/* ── Online responder markers (green) ── */}
              {onlineResponders.map((r) => (
                r.currentLatitude && r.currentLongitude ? (
                  <Marker
                    key={r.userId}
                    position={[r.currentLatitude, r.currentLongitude]}
                    icon={greenIcon}
                  >
                    <Popup>
                      <div style={{ minWidth: '180px' }}>
                        <strong style={{ color: '#059669', fontSize: '13px', display: 'block', marginBottom: '5px' }}>
                          🟢 Available Responder
                        </strong>
                        <p style={{ margin: '0 0 2px', fontSize: '13px', fontWeight: 600 }}>
                          {r.user?.fullName || 'Responder'}
                        </p>
                        <p style={{ margin: '0 0 2px', fontSize: '12px', color: '#64748B' }}>
                          {r.responderType?.replace('_', ' ') || 'Responder'} {r.organization ? `· ${r.organization}` : ''}
                        </p>
                        {r.user?.phoneNumber && (
                          <p style={{ margin: '0 0 4px', fontSize: '12px', color: '#64748B' }}>
                            📞 {r.user.phoneNumber}
                          </p>
                        )}
                        {r.motorbikeNumber && (
                          <p style={{ margin: '0 0 2px', fontSize: '11px', color: '#94A3B8', fontFamily: 'monospace' }}>
                            🏍️ {r.motorbikeNumber}
                          </p>
                        )}
                        <p style={{ margin: '4px 0 0', fontSize: '11px', color: '#94A3B8', fontFamily: 'monospace' }}>
                          {r.currentLatitude?.toFixed(5)}, {r.currentLongitude?.toFixed(5)}
                        </p>
                        <div style={{ marginTop: '6px', background: '#ECFDF5', borderRadius: '5px', padding: '3px 7px', fontSize: '11px', fontWeight: 700, color: '#059669', display: 'inline-block' }}>
                          ⭐ {Number(r.rating || 5).toFixed(1)}
                        </div>
                      </div>
                    </Popup>
                  </Marker>
                ) : null
              ))}
            </MapContainer>
          </div>
        </motion.div>
      )}

      {/* ── Error Banner ── */}
      {error && (
        <div style={{
          padding: '0.875rem 1.375rem', background: 'var(--error-bg)',
          border: '1px solid var(--error-border)', borderRadius: '12px',
          color: 'var(--error-fg)', marginBottom: '1.5rem',
          fontWeight: 600, fontSize: '0.9rem',
        }}>
          {error}
        </div>
      )}

      {/* ── Loading Skeleton ── */}
      {loading ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(380px, 1fr))', gap: '1.5rem' }}>
          {Array(4).fill(null).map((_, i) => (
            <div key={i} className="card" style={{
              padding: '1.5rem', border: '1px solid var(--border)',
              height: '220px', background: 'var(--surface-raised)',
              borderRadius: 'var(--radius-md)',
              animation: 'pulse 1.5s ease-in-out infinite',
            }} />
          ))}
        </div>

      /* ── Empty State ── */
      ) : filtered.length === 0 ? (
        <div className="card" style={{
          padding: '5rem 2rem', textAlign: 'center',
          border: '1px solid var(--border)', borderRadius: 'var(--radius-md)',
          background: 'var(--surface)',
        }}>
          <ShieldCheck size={56} style={{ margin: '0 auto 1.5rem', color: 'var(--s-resolved)', opacity: 0.7 }} />
          <h3 style={{ fontSize: '1.375rem', color: 'var(--s-resolved)', marginBottom: '0.75rem' }}>
            {activeFilter === 'ACTIVE' ? 'No Active Emergencies' : 'No Records Found'}
          </h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem' }}>
            {activeFilter === 'ACTIVE'
              ? 'All clear — no active SOS signals at this time.'
              : `No emergencies match the "${filterOpt?.label}" filter.`}
          </p>
        </div>

      /* ── Emergency Cards Grid ── */
      ) : (
        <AnimatePresence>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(380px, 1fr))', gap: '1.5rem' }}>
            {filtered.map((e, idx) => {
              const s = STATUS_STYLE[e.status] || STATUS_STYLE.ACTIVE;
              return (
                <motion.div
                  key={e.id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.04 }}
                  className="card"
                  style={{
                    padding: '1.625rem',
                    border: selectedEmergency?.id === e.id ? '1.5px solid #3B82F6' : '1px solid var(--border)',
                    borderLeft: `4px solid ${selectedEmergency?.id === e.id ? '#3B82F6' : s.color}`,
                    borderRadius: 'var(--radius-md)',
                    background: selectedEmergency?.id === e.id ? 'rgba(59,130,246,0.04)' : 'var(--surface)',
                    transition: 'box-shadow 0.2s ease, border-color 0.2s ease',
                    cursor: e.latitude && e.longitude ? 'pointer' : 'default',
                  }}
                  onClick={() => e.latitude && e.longitude && setSelectedEmergency(selectedEmergency?.id === e.id ? null : e)}
                >
                  {/* Card header */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: '0.5rem',
                      color: s.color, fontWeight: 800,
                      fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '0.05em',
                    }}>
                      <AlertTriangle size={14} />
                      {e.emergencyType || 'Medical'} Emergency
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                      <Clock size={12} /> {formatTime(e.createdAt)}
                    </div>
                  </div>

                  {/* Patient info */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', marginBottom: '1.125rem' }}>
                    <div style={{
                      width: '42px', height: '42px', borderRadius: '11px',
                      background: s.tint, color: s.color,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontWeight: 800, fontSize: '1rem', flexShrink: 0,
                    }}>
                      {e.patient?.fullName?.charAt(0) || <User size={18} />}
                    </div>
                    <div>
                      <h4 style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-sub)', marginBottom: '0.2rem' }}>
                        {e.patient?.fullName || 'Anonymous Patient'}
                      </h4>
                      <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                        <Phone size={11} /> {e.patient?.phoneNumber || 'No contact on file'}
                      </p>
                    </div>
                  </div>

                  {/* Location */}
                  <div style={{
                    display: 'flex', alignItems: 'flex-start', gap: '0.75rem',
                    padding: '0.75rem 0.875rem',
                    background: 'var(--surface-raised)', border: '1px solid var(--border)',
                    borderRadius: '10px', marginBottom: '1.125rem',
                  }}>
                    <MapPin size={16} style={{ color: 'var(--s-active)', flexShrink: 0, marginTop: '2px' }} />
                    <div>
                      <strong style={{ display: 'block', fontSize: '0.75rem', color: 'var(--primary)', marginBottom: '0.2rem' }}>
                        GPS Coordinates
                      </strong>
                      <p style={{ fontSize: '0.75rem', fontFamily: 'monospace', color: 'var(--text-muted)' }}>
                        {e.latitude?.toFixed(6)}, {e.longitude?.toFixed(6)}
                      </p>
                    </div>
                    {e.latitude && e.longitude && (
                      <a
                        href={`https://maps.google.com/?q=${e.latitude},${e.longitude}`}
                        target="_blank" rel="noopener noreferrer"
                        style={{ marginLeft: 'auto', fontSize: '0.72rem', color: 'var(--primary)', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap' }}
                      >
                        Open Maps ↗
                      </a>
                    )}
                  </div>

                  {/* Nearby Responders Badge — only for ACTIVE/ASSIGNED emergencies with GPS */}
                  {(e.status === 'ACTIVE' || e.status === 'ASSIGNED') && e.latitude && e.longitude && (
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: '0.5rem',
                      padding: '0.55rem 0.875rem', borderRadius: '10px', marginBottom: '0.875rem',
                      background: nearbyCount(e) > 0 ? '#ECFDF5' : '#FEF9EC',
                      border: `1px solid ${nearbyCount(e) > 0 ? '#A7F3D0' : '#FDE68A'}`,
                    }}>
                      <Navigation size={13} color={nearbyCount(e) > 0 ? '#059669' : '#D97706'} />
                      <span style={{ fontSize: '0.78rem', fontWeight: 700, color: nearbyCount(e) > 0 ? '#059669' : '#D97706' }}>
                        {nearbyCount(e) > 0
                          ? `${nearbyCount(e)} responder${nearbyCount(e) !== 1 ? 's' : ''} within ${NEARBY_RADIUS_KM} km`
                          : `No responders within ${NEARBY_RADIUS_KM} km`}
                      </span>
                      <span style={{ marginLeft: 'auto', fontSize: '0.68rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                        {selectedEmergency?.id === e.id ? 'Shown on map ↑' : 'Click card to focus map'}
                      </span>
                    </div>
                  )}

                  {/* Status row */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border)', paddingTop: '1rem' }}>
                    <span style={{
                      fontSize: '0.72rem', fontWeight: 800, padding: '0.3rem 0.75rem',
                      borderRadius: '6px', background: s.bg, color: s.color,
                      textTransform: 'uppercase', letterSpacing: '0.05em',
                    }}>
                      {s.label}
                    </span>
                    <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                      {e.emergencyRequests?.length || 0} responder{e.emergencyRequests?.length !== 1 ? 's' : ''} notified
                    </span>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </AnimatePresence>
      )}
    </motion.div>
  );
};

export default SOSMonitor;

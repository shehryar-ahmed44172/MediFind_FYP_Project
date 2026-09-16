import React, { useState, useEffect, useRef, useCallback } from 'react';
import { MapPin, Clock, Phone, AlertTriangle, ShieldCheck, RefreshCw, User, Filter, Wifi, WifiOff, Navigation } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useSearchParams } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import api from '../../services/api';
import { acquireSocket, releaseSocket } from '../../services/socket';

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

// Green icon for available online responders (normal view)
const greenIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [20, 33], iconAnchor: [10, 33], popupAnchor: [1, -28], shadowSize: [33, 33],
});

// Large green icon for responder-focus mode — stands out clearly on the map
const greenIconLarge = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [32, 52], iconAnchor: [16, 52], popupAnchor: [1, -46], shadowSize: [52, 52],
});

// ── Compass bearing (0-360°) from point A to point B ───────────────────────
const calcBearing = (lat1, lon1, lat2, lon2) => {
  const φ1 = lat1 * Math.PI / 180, φ2 = lat2 * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  return ((Math.atan2(y, x) * 180 / Math.PI) + 360) % 360;
};

// ── Ambulance motorbike SVG DivIcon — rotates to face direction of travel ───
// The SVG is drawn facing east (right). We subtract 90° so bearing=0 (north)
// makes the icon point up, bearing=90 makes it point right, etc.
const makeAmbulanceIcon = (bearing = 0) => L.divIcon({
  className: '',
  html: `
    <div style="
      width:52px;height:32px;
      transform:rotate(${bearing - 90}deg);
      transform-origin:center center;
      transition:transform 0.55s ease;
      filter:drop-shadow(0 3px 10px rgba(5,150,105,0.72));
    ">
      <svg xmlns="http://www.w3.org/2000/svg" width="52" height="32" viewBox="0 0 52 32">
        <style>@keyframes siren{0%,49%{opacity:1}50%,100%{opacity:0.18}}</style>
        <!-- Main body -->
        <rect x="10" y="10" width="30" height="11" rx="4" fill="var(--success-fg)"/>
        <!-- Siren bar (animated red) -->
        <rect x="17" y="4" width="15" height="7" rx="3" fill="var(--sos)" style="animation:siren 0.75s ease infinite"/>
        <!-- Siren lights -->
        <circle cx="20" cy="7.5" r="1.5" fill="white" style="animation:siren 0.75s 0.375s ease infinite"/>
        <circle cx="29" cy="7.5" r="1.5" fill="white"/>
        <!-- White cross horizontal -->
        <rect x="18" y="13" width="14" height="3" rx="0.5" fill="white"/>
        <!-- White cross vertical -->
        <rect x="23.5" y="10" width="3" height="9" rx="0.5" fill="white"/>
        <!-- Front fork / handlebar -->
        <rect x="40" y="12" width="7" height="3" rx="1.5" fill="var(--success-fg)"/>
        <!-- Rear exhaust -->
        <rect x="4" y="14.5" width="6" height="2" rx="1" fill="var(--success-fg)" opacity="0.8"/>
        <!-- Back wheel -->
        <circle cx="14" cy="25" r="6" fill="var(--text-main)" stroke="var(--success)" stroke-width="2"/>
        <circle cx="14" cy="25" r="2" fill="var(--success)"/>
        <!-- Front wheel -->
        <circle cx="38" cy="25" r="6" fill="var(--text-main)" stroke="var(--success)" stroke-width="2"/>
        <circle cx="38" cy="25" r="2" fill="var(--success)"/>
      </svg>
    </div>
  `,
  iconSize:    [52, 32],
  iconAnchor:  [26, 30],
  popupAnchor: [0, -32],
});

// Escape values interpolated into Leaflet popup HTML
const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, ch => (
  { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]
));

const vehiclePopupHtml = (vehicle) => `
  <div style="min-width:175px">
    <strong style="color:var(--success-fg);font-size:13px;display:block;margin-bottom:5px">
      ${vehicle.isDemo ? 'Demo simulation — not real data' : 'En Route'}
    </strong>
    <b style="font-size:12px">${escapeHtml(vehicle.name)}</b><br/>
    <span style="font-size:11px;color:var(--text-muted)">${escapeHtml((vehicle.responderType || 'Responder').replace(/_/g, ' '))}</span><br/>
    ${vehicle.eta != null
      ? `<span style="font-size:12px;font-weight:700;color:var(--warning-fg)">ETA ≈ ${escapeHtml(vehicle.eta)} min</span><br/>`
      : ''}
    <span style="font-size:10px;color:var(--text-muted);font-family:monospace">
      ${Number(vehicle.lat).toFixed(5)}, ${Number(vehicle.lon).toFixed(5)}
    </span>
  </div>
`;

// ── MovingVehicleMarker ─────────────────────────────────────────────────────
// Renders an ambulance motorbike that moves & rotates smoothly.
// Uses imperative Leaflet API (L.marker + setLatLng) so the DOM element
// persists between React renders — no flickering, true smooth movement.
function MovingVehicleMarker({ vehicle }) {
  const map = useMap();
  const markerRef = useRef(null);

  // Create marker once on mount; remove on unmount
  useEffect(() => {
    const marker = L.marker([vehicle.lat, vehicle.lon], {
      icon: makeAmbulanceIcon(vehicle.bearing || 0),
      zIndexOffset: 2000,
    }).addTo(map);
    marker.bindPopup(vehiclePopupHtml(vehicle));
    markerRef.current = marker;
    return () => { marker.remove(); markerRef.current = null; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Update position + icon rotation on each GPS update — this is what makes it "move"
  useEffect(() => {
    if (!markerRef.current) return;
    markerRef.current.setLatLng([vehicle.lat, vehicle.lon]);
    markerRef.current.setIcon(makeAmbulanceIcon(vehicle.bearing || 0));
    markerRef.current.setPopupContent(vehiclePopupHtml(vehicle));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vehicle.lat, vehicle.lon, vehicle.bearing, vehicle.eta, vehicle.name, vehicle.responderType]);

  return null;
}

// ── Lahore demo simulation route (Liberty Market → Model Town, ~2.5 km) ────
// Used by the "Simulate Route" button so the defence demo shows a live-moving
// ambulance without needing a physical responder to be moving.
const SIM_ROUTE = [
  [31.5166, 74.3477], [31.5148, 74.3455], [31.5130, 74.3430],
  [31.5110, 74.3405], [31.5088, 74.3380], [31.5065, 74.3355],
  [31.5042, 74.3330], [31.5018, 74.3305], [31.4995, 74.3280],
  [31.4972, 74.3255], [31.4950, 74.3230], [31.4928, 74.3205],
  [31.4907, 74.3180], [31.4886, 74.3155], [31.4866, 74.3132],
];

// ── FitBoundsToResponders: zooms/pans the Leaflet map to fit all responder pins ──
function FitBoundsToResponders({ responders }) {
  const map = useMap();
  useEffect(() => {
    const valid = responders.filter(r => r.currentLatitude && r.currentLongitude);
    if (valid.length === 0) return;
    if (valid.length === 1) {
      map.setView([valid[0].currentLatitude, valid[0].currentLongitude], 14, { animate: true });
      return;
    }
    const bounds = L.latLngBounds(valid.map(r => [r.currentLatitude, r.currentLongitude]));
    map.fitBounds(bounds.pad(0.25), { animate: true, maxZoom: 14 });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [responders.length]);
  return null;
}

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

const DAY_MS = 24 * 60 * 60 * 1000;

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
  // A local filter choice only applies while the URL filter it was made under is unchanged,
  // so clicking an Overview stat card (which changes ?filter=) always wins.
  const [filterChoice,       setFilterChoice]       = useState(null); // { urlFilter, value }
  const [socketOnline,       setSocketOnline]       = useState(false);
  const [timeRange,          setTimeRange]          = useState('today'); // 'today' | 'week' | 'all'
  const [onlineResponders,   setOnlineResponders]   = useState([]); // live GPS-located available responders
  const [selectedEmergency,  setSelectedEmergency]  = useState(null); // clicked emergency for map focus
  const [responderFocused,   setResponderFocused]   = useState(false); // Online Responders card clicked — focus map on responders
  const mapRef = useRef(null); // scroll-to-map anchor
  // Moving ambulance markers (live GPS + simulation)
  const [movingVehicles, setMovingVehicles] = useState({}); // { responderId: { lat, lon, bearing, emergencyId, eta, status, isDemo? } }
  const [simRunning,     setSimRunning]     = useState(false);
  const simIntervalRef = useRef(null);
  const simIndexRef    = useRef(0);

  const activeFilter = filterChoice && filterChoice.urlFilter === initialFilter ? filterChoice.value : initialFilter;
  const setActiveFilter = (value) => setFilterChoice({ urlFilter: initialFilter, value });

  /* ── Data loaders: fetch → apply (state is only set in async callbacks) ── */
  const applyEmergencies = useCallback((response) => {
    if (response?.data?.success) {
      setEmergencies(response.data.data || []);
      setLastUpdated(new Date());
      setError('');
    }
    setLoading(false);
  }, []);

  const handleEmergencyError = useCallback((err) => {
    setError(err.response?.data?.message || 'Failed to fetch emergencies. Retrying automatically…');
    setLoading(false);
  }, []);

  const fetchEmergencies = useCallback(() => (
    api.get('/api/emergencies').then(applyEmergencies, handleEmergencyError)
  ), [applyEmergencies, handleEmergencyError]);

  const fetchOnlineResponders = useCallback(() => (
    api.get('/api/admin/responders/online')
      .then(res => { if (res.data?.success) setOnlineResponders(res.data.data || []); })
      .catch(() => { /* silent — map still shows without responder pins */ })
  ), []);

  // Emergencies: poll every 4 s (fast enough to catch status changes without the socket)
  useEffect(() => {
    fetchEmergencies();
    const id = setInterval(fetchEmergencies, 4000);
    return () => clearInterval(id);
  }, [fetchEmergencies]);

  // Online responders: fetch on mount then every 10 s
  useEffect(() => {
    fetchOnlineResponders();
    const id = setInterval(fetchOnlineResponders, 10000);
    return () => clearInterval(id);
  }, [fetchOnlineResponders]);

  // ── Real-time updates over the shared admin socket ─────────────────────
  useEffect(() => {
    const socket = acquireSocket();

    const onConnect    = () => setSocketOnline(true);
    const onDisconnect = () => setSocketOnline(false);
    const onStatus     = () => fetchEmergencies(); // re-fetch immediately, don't wait for the poll
    const onAdminNotif = (data) => {
      if (data?.type === 'SOS_TRIGGERED' || data?.type === 'EMERGENCY_STATUS_CHANGE') fetchEmergencies();
    };
    // Responder moved during an active emergency — move the ambulance marker
    const onLocation = (payload) => {
      const d = payload?.data || payload;
      if (d?.responderId && d?.latitude != null && d?.longitude != null) {
        setMovingVehicles(prev => {
          const existing = prev[d.responderId];
          const bearing = existing
            ? calcBearing(existing.lat, existing.lon, d.latitude, d.longitude)
            : 0;
          return {
            ...prev,
            [d.responderId]: {
              lat: d.latitude,
              lon: d.longitude,
              bearing,
              emergencyId: d.emergencyId,
              eta:         d.estimatedArrivalMinutes,
              status:      d.status,
            },
          };
        });
      }
      fetchOnlineResponders();
    };

    // The shared socket may already be connected (e.g. opened by the dashboard shell)
    if (socket.connected) queueMicrotask(onConnect);

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('connect_error', onDisconnect);
    socket.on('EMERGENCY_STATUS_CHANGE', onStatus);
    socket.on('admin_notification', onAdminNotif);
    socket.on('LOCATION_UPDATE', onLocation);
    socket.on('RESPONDER_LOCATION_UPDATE', fetchOnlineResponders);

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('connect_error', onDisconnect);
      socket.off('EMERGENCY_STATUS_CHANGE', onStatus);
      socket.off('admin_notification', onAdminNotif);
      socket.off('LOCATION_UPDATE', onLocation);
      socket.off('RESPONDER_LOCATION_UPDATE', fetchOnlineResponders);
      releaseSocket();
    };
  }, [fetchEmergencies, fetchOnlineResponders]);

  // ── Clean up simulation interval if the component unmounts ────────────────
  useEffect(() => () => clearInterval(simIntervalRef.current), []);

  /* ── Time-range scoping — relative to the last successful fetch ── */
  const refTime = lastUpdated ? lastUpdated.getTime() : 0;
  const scopedEmergencies = timeRange === 'all'
    ? emergencies
    : emergencies.filter(e => new Date(e.createdAt).getTime() >= refTime - (timeRange === 'week' ? 7 : 1) * DAY_MS);

  /* ── Derived data ── */
  const filterOpt = FILTER_OPTIONS.find(f => f.key === activeFilter);
  const filtered  = activeFilter === 'ALL'
    ? scopedEmergencies
    : scopedEmergencies.filter(e => filterOpt?.statuses?.includes(e.status));

  const activeEmergencies = scopedEmergencies.filter(e => e.status === 'ACTIVE');

  /* ── Moving vehicles: drop finished emergencies, enrich with responder names ── */
  const liveEmergencyIds = new Set(
    emergencies.filter(e => ['ACTIVE', 'ASSIGNED'].includes(e.status)).map(e => e.id)
  );
  const displayVehicles = Object.entries(movingVehicles)
    .filter(([, v]) => v.isDemo || !v.emergencyId || liveEmergencyIds.has(v.emergencyId))
    .map(([rid, v]) => {
      const r = onlineResponders.find(o => o.userId === rid);
      return [rid, {
        ...v,
        name: v.name || r?.user?.fullName || 'Responder',
        responderType: v.responderType || r?.responderType || '',
      }];
    });

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

  /* ── Show map whenever there's something to display (or a simulation is running) ── */
  const shouldShowMap = !loading && (
    activeEmergencies.length > 0 ||
    onlineResponders.length > 0 ||
    displayVehicles.length > 0
  );

  /* ── Defence demo: simulate an ambulance moving along SIM_ROUTE ── */
  const startSimulation = () => {
    simIndexRef.current = 0;
    setSimRunning(true);
    simIntervalRef.current = setInterval(() => {
      const idx = simIndexRef.current;
      if (idx >= SIM_ROUTE.length) {
        clearInterval(simIntervalRef.current);
        setSimRunning(false);
        return;
      }
      const [lat, lon] = SIM_ROUTE[idx];
      const prevPt = idx > 0 ? SIM_ROUTE[idx - 1] : null;
      const bearing = prevPt ? calcBearing(prevPt[0], prevPt[1], lat, lon) : 225; // initial = SW
      const eta = Math.max(0, SIM_ROUTE.length - idx - 1);
      setMovingVehicles(prev => ({
        ...prev,
        DEMO_AMBULANCE: {
          lat, lon, bearing,
          emergencyId:  'DEMO',
          isDemo:       true,
          eta,
          status:       idx === SIM_ROUTE.length - 1 ? 'ARRIVED' : 'EN_ROUTE',
          name:         'Demo Unit (simulated)',
          responderType:'PARAMEDIC',
        },
      }));
      simIndexRef.current += 1;
    }, 1400); // step every 1.4 s — smooth but not frantic
  };

  const stopSimulation = () => {
    clearInterval(simIntervalRef.current);
    setSimRunning(false);
    simIndexRef.current = 0;
    setMovingVehicles(prev => {
      const next = { ...prev };
      delete next.DEMO_AMBULANCE;
      return next;
    });
  };

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
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', gap: '12px 16px', flexWrap: 'wrap', marginBottom: '1.5rem' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap', marginBottom: '0.375rem' }}>
            <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-sub)', letterSpacing: '-0.03em', whiteSpace: 'nowrap' }}>
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
              color: socketOnline ? 'var(--success-fg)' : 'var(--error-fg)',
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
                  padding: '6px 14px', border: 'none', whiteSpace: 'nowrap',
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
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '12px', marginBottom: '1.25rem' }}>
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
          {/* Online Responders — clickable: focuses map on all responder pins */}
          <motion.div
            whileHover={{ y: -2, boxShadow: '0 6px 24px rgba(16,185,129,0.25)' }}
            whileTap={{ scale: 0.97 }}
            onClick={() => {
              setResponderFocused(f => !f);
              setSelectedEmergency(null); // clear any SOS focus
              // Scroll map into view
              setTimeout(() => mapRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 80);
            }}
            style={{
              background: responderFocused ? 'var(--tint-green)' : 'var(--surface)',
              border: `1.5px solid ${responderFocused ? 'var(--success-fg)' : 'var(--success)'}`,
              borderRadius: '14px', padding: '14px 18px',
              position: 'relative', overflow: 'hidden',
              cursor: 'pointer', transition: 'all 0.18s ease',
              boxShadow: responderFocused ? '0 0 0 3px rgba(16,185,129,0.18)' : 'none',
            }}
          >
            {/* Ambient shimmer */}
            <motion.div
              animate={{ opacity: [0.12, 0.28, 0.12] }}
              transition={{ repeat: Infinity, duration: 2 }}
              style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, rgba(16,185,129,0.08), transparent)', pointerEvents: 'none' }}
            />
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
              <p style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--success-fg)', lineHeight: 1 }}>
                {onlineResponders.length}
              </p>
              <motion.div
                animate={{ scale: [1, 1.5, 1], opacity: [0.5, 1, 0.5] }}
                transition={{ repeat: Infinity, duration: 1.6 }}
                style={{ width: '7px', height: '7px', borderRadius: '50%', background: 'var(--success)', flexShrink: 0 }}
              />
            </div>
            <p style={{ fontSize: '0.8rem', fontWeight: 700, color: responderFocused ? 'var(--success-fg)' : 'var(--text-muted)', position: 'relative' }}>
              Online Responders
            </p>
            {responderFocused && (
              <p style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--success-fg)', marginTop: '3px', position: 'relative', letterSpacing: '0.04em' }}>
                📍 Pinned on map ↓
              </p>
            )}
            {!responderFocused && (
              <p style={{ fontSize: '0.65rem', color: 'var(--text-muted)', marginTop: '3px', position: 'relative' }}>
                Click to view on map
              </p>
            )}
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
          ref={mapRef}
          initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
          style={{
            marginBottom: '1.5rem', borderRadius: '16px',
            border: responderFocused
              ? '2px solid var(--success-fg)'
              : activeEmergencies.length > 0 ? '1.5px solid var(--s-active)' : '1.5px solid var(--success)',
            overflow: 'hidden',
            boxShadow: responderFocused
              ? '0 0 0 4px rgba(16,185,129,0.15), 0 8px 32px rgba(16,185,129,0.2)'
              : activeEmergencies.length > 0 ? '0 4px 24px rgba(239,68,68,0.12)' : '0 4px 24px rgba(16,185,129,0.12)',
            position: 'relative', isolation: 'isolate', zIndex: 0,
            transition: 'border-color 0.3s ease, box-shadow 0.3s ease',
          }}
        >
          {/* Map header bar */}
          <div style={{
            padding: '10px 18px',
            background: responderFocused
              ? 'rgba(16,185,129,0.08)'
              : activeEmergencies.length > 0 ? 'var(--error-bg)' : 'rgba(16,185,129,0.06)',
            borderBottom: `1px solid ${responderFocused ? 'var(--success-fg)' : activeEmergencies.length > 0 ? 'var(--s-active)' : 'var(--success)'}`,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              {/* Blinking dot */}
              <motion.div
                animate={{ opacity: [1, 0.25, 1] }}
                transition={{ repeat: Infinity, duration: responderFocused ? 1.8 : 1.2 }}
                style={{ width: '8px', height: '8px', borderRadius: '50%', background: responderFocused ? 'var(--success)' : 'var(--s-active)', flexShrink: 0 }}
              />
              <span style={{ fontWeight: 800, color: responderFocused ? 'var(--success-fg)' : activeEmergencies.length > 0 ? 'var(--s-active)' : 'var(--success)', fontSize: '0.85rem' }}>
                {responderFocused
                  ? `RESPONDER VIEW — ${onlineResponders.length} Online Responder${onlineResponders.length !== 1 ? 's' : ''}`
                  : `LIVE MAP${activeEmergencies.length > 0 ? ` — ${activeEmergencies.length} Active SOS Signal${activeEmergencies.length !== 1 ? 's' : ''}` : ''}`}
              </span>
              {selectedEmergency && !responderFocused && (
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                  · Showing {NEARBY_RADIUS_KM} km radius
                </span>
              )}
            </div>

            {/* Legend + controls */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
              {activeEmergencies.length > 0 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: 'var(--sos)' }}>
                  <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'var(--sos)' }} />
                  Patient SOS
                </div>
              )}
              <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: 'var(--success-fg)' }}>
                <div style={{ width: responderFocused ? '12px' : '10px', height: responderFocused ? '12px' : '10px', borderRadius: '50%', background: 'var(--success)', transition: 'all 0.2s', boxShadow: responderFocused ? '0 0 0 3px rgba(16,185,129,0.25)' : 'none' }} />
                Responder ({onlineResponders.length})
              </div>
              {/* Ambulance legend — only when at least one vehicle is moving */}
              {displayVehicles.length > 0 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: 'var(--success-fg)' }}>
                  🚑 En Route ({displayVehicles.length})
                </div>
              )}
              {selectedEmergency && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '0.72rem', fontWeight: 700, color: 'var(--primary-light)' }}>
                  <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: 'rgba(40,145,194,0.12)', border: '1.5px solid var(--primary-light)' }} />
                  {NEARBY_RADIUS_KM} km radius
                </div>
              )}
              {/* Demo-only route simulation (for presentations) — clearly labelled as not real data */}
              <button
                type="button"
                onClick={simRunning ? stopSimulation : startSimulation}
                title="Plays a simulated ambulance along a fixed Lahore route. Not real responder data."
                style={{
                  display: 'inline-flex', alignItems: 'center', gap: '6px',
                  fontSize: '0.7rem', fontWeight: 800, cursor: 'pointer',
                  padding: '4px 11px', borderRadius: '7px', fontFamily: 'inherit',
                  background: simRunning ? 'var(--tint-red)' : 'var(--tint-slate)',
                  color: simRunning ? 'var(--error-fg)' : 'var(--text-muted)',
                  border: `1px dashed ${simRunning ? 'var(--error-border)' : 'var(--border)'}`,
                  transition: 'all 0.15s ease',
                }}
              >
                <span style={{ fontSize: '0.6rem', letterSpacing: '0.08em', padding: '1px 5px', borderRadius: '4px', background: simRunning ? 'var(--error-fg)' : 'var(--text-muted)', color: 'white' }}>DEMO</span>
                {simRunning ? 'Stop simulation' : 'Demo simulation'}
              </button>
              {/* Clear buttons */}
              {responderFocused && (
                <button
                  onClick={() => setResponderFocused(false)}
                  style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--success-fg)', background: 'rgba(16,185,129,0.12)', border: '1px solid var(--success)', cursor: 'pointer', padding: '3px 10px', borderRadius: '6px' }}
                >
                  ✕ Exit Responder View
                </button>
              )}
              {selectedEmergency && !responderFocused && (
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
              style={{ height: responderFocused ? '500px' : '420px', width: '100%', transition: 'height 0.35s ease' }}
              key={activeFilter}
              scrollWheelZoom={false}
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <CtrlScrollHint />

              {/* Auto-fit to all responders when Responder View is active */}
              {responderFocused && <FitBoundsToResponders responders={onlineResponders} />}

              {/* ── Patient SOS markers (red) — dimmed in responder-focus mode ── */}
              {activeEmergencies.map((e) => (
                e.latitude && e.longitude ? (
                  <React.Fragment key={e.id}>
                    <Circle
                      center={[e.latitude, e.longitude]}
                      radius={250}
                      color="var(--sos)" fillColor="var(--sos)"
                      fillOpacity={responderFocused ? 0.04 : 0.12}
                      opacity={responderFocused ? 0.3 : 1}
                    />
                    <Marker
                      position={[e.latitude, e.longitude]}
                      icon={redIcon}
                      opacity={responderFocused ? 0.35 : 1}
                      eventHandlers={{ click: () => { if (!responderFocused) setSelectedEmergency(e); } }}
                    >
                      <Popup>
                        <div style={{ minWidth: '200px' }}>
                          <strong style={{ color: 'var(--sos)', fontSize: '13px', display: 'block', marginBottom: '6px' }}>
                            🆘 {e.emergencyType || 'Medical'} Emergency
                          </strong>
                          <p style={{ margin: '0 0 2px', fontSize: '13px', fontWeight: 600 }}>
                            {e.patient?.fullName || 'Unknown Patient'}
                          </p>
                          <p style={{ margin: '0 0 4px', fontSize: '12px', color: 'var(--text-muted)' }}>
                            📞 {e.patient?.phoneNumber || 'No phone'}
                          </p>
                          <p style={{ margin: '0 0 6px', fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                            {e.latitude?.toFixed(5)}, {e.longitude?.toFixed(5)}
                          </p>
                          <div style={{ background: nearbyCount(e) > 0 ? 'var(--tint-green)' : 'var(--tint-red)', borderRadius: '6px', padding: '4px 8px', fontSize: '12px', fontWeight: 700, color: nearbyCount(e) > 0 ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                            {nearbyCount(e) > 0
                              ? `✅ ${nearbyCount(e)} responder${nearbyCount(e) !== 1 ? 's' : ''} within ${NEARBY_RADIUS_KM} km`
                              : `⚠️ No responders within ${NEARBY_RADIUS_KM} km`}
                          </div>
                          <button
                            onClick={() => { setSelectedEmergency(e); setResponderFocused(false); }}
                            style={{ marginTop: '8px', width: '100%', padding: '5px', borderRadius: '6px', background: 'var(--primary-light)', color: 'white', border: 'none', fontWeight: 700, fontSize: '11px', cursor: 'pointer' }}
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
              {selectedEmergency?.latitude && selectedEmergency?.longitude && !responderFocused && (
                <Circle
                  center={[selectedEmergency.latitude, selectedEmergency.longitude]}
                  radius={NEARBY_RADIUS_KM * 1000}
                  color="var(--primary-light)" fillColor="var(--primary-light)" fillOpacity={0.06}
                  weight={2} dashArray="6 4"
                />
              )}

              {/* ── Online responder markers ── */}
              {/* In focus mode: large icon + green pulse halo. Normal: small icon. */}
              {onlineResponders.map((r) => (
                r.currentLatitude && r.currentLongitude ? (
                  <React.Fragment key={r.userId}>
                    {/* Pulse halo (only in responder-focus mode) */}
                    {responderFocused && (
                      <Circle
                        center={[r.currentLatitude, r.currentLongitude]}
                        radius={180}
                        color="var(--success)" fillColor="var(--success)" fillOpacity={0.18}
                        weight={2}
                      />
                    )}
                    <Marker
                      position={[r.currentLatitude, r.currentLongitude]}
                      icon={responderFocused ? greenIconLarge : greenIcon}
                    >
                      <Popup>
                        <div style={{ minWidth: '200px' }}>
                          <strong style={{ color: 'var(--success-fg)', fontSize: '13px', display: 'block', marginBottom: '5px' }}>
                            🟢 Available Responder
                          </strong>
                          <p style={{ margin: '0 0 2px', fontSize: '13px', fontWeight: 700 }}>
                            {r.user?.fullName || 'Responder'}
                          </p>
                          <p style={{ margin: '0 0 2px', fontSize: '12px', color: 'var(--text-muted)' }}>
                            {r.responderType?.replace(/_/g, ' ') || 'Responder'}{r.organization ? ` · ${r.organization}` : ''}
                          </p>
                          {r.user?.phoneNumber && (
                            <p style={{ margin: '0 0 4px', fontSize: '12px', color: 'var(--text-muted)' }}>
                              📞 {r.user.phoneNumber}
                            </p>
                          )}
                          <p style={{ margin: '4px 0 4px', fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                            {r.currentLatitude?.toFixed(5)}, {r.currentLongitude?.toFixed(5)}
                          </p>
                          <div style={{ background: 'var(--tint-green)', borderRadius: '5px', padding: '3px 7px', fontSize: '11px', fontWeight: 700, color: 'var(--success-fg)', display: 'inline-block' }}>
                            ⭐ {Number(r.rating || 5).toFixed(1)}
                          </div>
                        </div>
                      </Popup>
                    </Marker>
                  </React.Fragment>
                ) : null
              ))}

              {/* ── Ambulance motorbike markers (live GPS + simulation) ─────────────
                   Each MovingVehicleMarker uses imperative Leaflet API internally
                   so it glides smoothly between GPS updates (no React flicker).
                   Bearing is recalculated from consecutive positions so the icon
                   rotates to face the actual direction of travel, exactly like
                   how Uber / Careem / InDrive show moving vehicles.
              ──────────────────────────────────────────────────────────────────── */}
              {displayVehicles.map(([rid, v]) => (
                <MovingVehicleMarker key={rid} vehicle={{ ...v, responderId: rid }} />
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
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(380px, 100%), 1fr))', gap: '1.5rem' }}>
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
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(380px, 100%), 1fr))', gap: '1.5rem' }}>
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
                    border: selectedEmergency?.id === e.id ? '1.5px solid var(--primary-light)' : '1px solid var(--border)',
                    borderLeft: `4px solid ${selectedEmergency?.id === e.id ? 'var(--primary-light)' : s.color}`,
                    borderRadius: 'var(--radius-md)',
                    background: selectedEmergency?.id === e.id ? 'rgba(40,145,194,0.06)' : 'var(--surface)',
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
                      background: nearbyCount(e) > 0 ? 'var(--tint-green)' : 'var(--tint-amber)',
                      border: `1px solid ${nearbyCount(e) > 0 ? 'var(--success-border)' : 'var(--warning-border)'}`,
                    }}>
                      <Navigation size={13} color={nearbyCount(e) > 0 ? 'var(--success-fg)' : 'var(--warning-fg)'} />
                      <span style={{ fontSize: '0.78rem', fontWeight: 700, color: nearbyCount(e) > 0 ? 'var(--success-fg)' : 'var(--warning-fg)' }}>
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

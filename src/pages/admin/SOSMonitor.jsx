import React, { useState, useEffect, useRef, useCallback } from 'react';
import { MapPin, Phone, ShieldCheck, Navigation, Wifi, WifiOff, X, Play, Square, ExternalLink } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { MapContainer, Marker, Popup, Circle, useMap } from 'react-leaflet';
import ThemedTileLayer from '../../components/ThemedTileLayer';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import api from '../../services/api';
import { acquireSocket, releaseSocket } from '../../services/socket';
import { useTheme } from '../../context/hooks';
import {
  PageHeader, RefreshButton, Button, StatCard, StatusBadge, LiveIndicator, SegmentedControl,
  EmptyState, Notice, Skeleton, Card, PanelHeader,
} from '../../components/ui';
import { toneFor, humanize, chartColors } from '../../components/uiStyles';

// Fix Leaflet default marker icons broken by Vite/Webpack bundling
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl:       'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl:     'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
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

// Map marker colours are literal values (SVG attributes) — map tiles are always light
const MAP = chartColors(false);

// ── Ambulance motorbike mascot — same top-down design as the mobile app ─────
// Drawn on a 64x64 grid facing north, so rotate(bearing) points it along the road.
const MASCOT_SVG = `
  <svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 64 64" aria-hidden="true">
    <style>
      .mf-halo{animation:mfHalo 1.2s ease-in-out infinite;transform-origin:32px 33px}
      .mf-l{animation:mfSiren .8s steps(1) infinite}
      .mf-r{animation:mfSiren .8s steps(1) .4s infinite}
      @keyframes mfHalo{0%,100%{opacity:.12;transform:scale(1)}50%{opacity:.22;transform:scale(1.1)}}
      @keyframes mfSiren{0%{fill:#EF4444}50%{fill:#2891C2}}
    </style>
    <circle class="mf-halo" cx="32" cy="33" r="26" fill="#EF4444"/>
    <rect x="21" y="9" width="22" height="50" rx="10" fill="#000" opacity=".22" filter="blur(1.5px)"/>
    <rect x="28.8" y="5" width="6.4" height="12" rx="3" fill="#111827"/>
    <rect x="28.4" y="48" width="7.2" height="12" rx="3" fill="#111827"/>
    <line x1="22" y1="17" x2="42" y2="17" stroke="#374151" stroke-width="2.4" stroke-linecap="round"/>
    <circle cx="22" cy="17" r="1.8" fill="#9CA3AF"/><circle cx="42" cy="17" r="1.8" fill="#9CA3AF"/>
    <rect x="26" y="12" width="12" height="22" rx="6" fill="#EF4444"/>
    <rect x="28" y="13.5" width="8" height="4" rx="2" fill="#E2F0F3" opacity=".9"/>
    <ellipse cx="32" cy="26.5" rx="8" ry="5.5" fill="#1F2937"/>
    <circle cx="32" cy="24.5" r="5.2" fill="#fff" stroke="#EF4444" stroke-width="1.2"/>
    <path d="M28.6 22.2 A4 4 0 0 1 35.4 22.2" fill="none" stroke="#2496A7" stroke-width="1.8" stroke-linecap="round"/>
    <rect x="21" y="34" width="22" height="20" rx="4" fill="#fff" stroke="#CBD5E1" stroke-width="1"/>
    <rect x="26" y="43" width="12" height="4" rx="1" fill="#EF4444"/>
    <rect x="30" y="39" width="4" height="12" rx="1" fill="#EF4444"/>
    <rect x="23" y="33" width="18" height="4.5" rx="2" fill="#374151"/>
    <circle class="mf-l" cx="27" cy="35.2" r="2.3" fill="#EF4444"/>
    <circle class="mf-r" cx="37" cy="35.2" r="2.3" fill="#2891C2"/>
  </svg>`;

const makeAmbulanceIcon = (bearing = 0) => L.divIcon({
  className: '',
  html: `<div style="width:56px;height:56px;transform:rotate(${bearing}deg);transform-origin:center center;transition:transform 0.55s ease;">${MASCOT_SVG}</div>`,
  iconSize:    [56, 56],
  iconAnchor:  [28, 28],
  popupAnchor: [0, -26],
});

// ── Patient pin — same design as the mobile app (person pin + SOS badge) ─────
const patientIcon = L.divIcon({
  className: '',
  html: `
    <svg xmlns="http://www.w3.org/2000/svg" width="46" height="55" viewBox="0 0 104 124" aria-hidden="true">
      <circle cx="52" cy="48" r="44" fill="#DC2626" opacity=".16"/>
      <path d="M52 14a34 34 0 0 1 14 65 Q52 122 52 122 Q52 122 38 79 A34 34 0 0 1 52 14z" fill="#fff" stroke="#0C637E" stroke-width="4"/>
      <circle cx="52" cy="39" r="10" fill="#04364E"/>
      <path d="M34 68 Q34 51 52 51 Q70 51 70 68z" fill="#04364E"/>
      <rect x="60" y="2" width="42" height="22" rx="11" fill="#DC2626" stroke="#fff" stroke-width="2"/>
      <text x="81" y="18" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="12" font-weight="700" fill="#fff">SOS</text>
    </svg>`,
  iconSize:    [46, 55],
  iconAnchor:  [23, 54],
  popupAnchor: [0, -50],
});

// Frames the open emergencies and moving ambulances whenever that set changes,
// so a new SOS is shown at street level instead of the country view.
function FocusOpenEmergencies({ points, focusKey }) {
  const map = useMap();
  useEffect(() => {
    if (!focusKey || points.length === 0) return;
    if (points.length === 1) {
      map.setView(points[0], 15, { animate: true });
    } else {
      map.fitBounds(L.latLngBounds(points).pad(0.3), { animate: true, maxZoom: 16 });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focusKey]);
  return null;
}

// Escape values interpolated into Leaflet popup HTML
const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, ch => (
  { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]
));

const vehiclePopupHtml = (vehicle) => `
  <div style="min-width:175px;font-size:13px;line-height:1.4">
    <span style="display:block;margin-bottom:4px;font-size:12px;font-weight:500;color:${vehicle.isDemo ? 'var(--warning-fg)' : 'var(--success-fg)'}">
      ${vehicle.isDemo ? 'Demo simulation — not real data' : 'En route'}
    </span>
    <span style="display:block;font-weight:600;color:var(--text-main)">${escapeHtml(vehicle.name)}</span>
    <span style="display:block;font-size:12px;color:var(--text-muted)">${escapeHtml((vehicle.responderType || 'Responder').replace(/_/g, ' '))}</span>
    ${vehicle.eta != null
      ? `<span style="display:block;margin-top:4px;font-size:12.5px;font-weight:500;color:var(--text-main);font-variant-numeric:tabular-nums">ETA ≈ ${escapeHtml(vehicle.eta)} min</span>`
      : ''}
    <span style="display:block;margin-top:2px;font-size:11.5px;color:var(--text-muted);font-variant-numeric:tabular-nums">
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
// Used by the "Demo simulation" button so the defence demo shows a live-moving
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

// Keeps Leaflet's tile grid in sync when the flexible map panel changes size
function InvalidateOnResize() {
  const map = useMap();
  useEffect(() => {
    const el = map.getContainer();
    if (typeof ResizeObserver === 'undefined') return undefined;
    const ro = new ResizeObserver(() => map.invalidateSize());
    ro.observe(el);
    return () => ro.disconnect();
  }, [map]);
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

const NEARBY_RADIUS_KM = 5; // radius used for "nearby" hint on list rows

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
      pointerEvents: 'none', background: 'rgba(15,23,42,0.18)',
    }}>
      <div className="mf-fade" style={{
        background: 'var(--surface)', color: 'var(--text-main)', border: '1px solid var(--border)',
        padding: '8px 14px', borderRadius: '8px', boxShadow: 'var(--shadow-overlay)',
        fontSize: '13px', fontWeight: 500, display: 'flex', alignItems: 'center', gap: '6px',
      }}>
        Use <kbd className="mf-kbd">Ctrl</kbd> + scroll to zoom the map
      </div>
    </div>
  );
}

const FILTER_OPTIONS = [
  { key: 'ALL',       label: 'All',       statuses: null },
  { key: 'ACTIVE',    label: 'Active',    statuses: ['ACTIVE'] },
  { key: 'ASSIGNED',  label: 'Assigned',  statuses: ['ASSIGNED'] },
  { key: 'RESOLVED',  label: 'Resolved',  statuses: ['RESOLVED', 'COMPLETED'] },
  { key: 'CANCELLED', label: 'Cancelled', statuses: ['CANCELLED'] },
];

const TIME_RANGES = [
  { value: 'today', label: 'Today' },
  { value: 'week',  label: '7 days' },
  { value: 'all',   label: 'All time' },
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

// Page-scoped layout: map (flexible) + emergency list (fixed); stacks below 1200px
const SOS_CSS = `
.mf-sos-stats { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 16px; }
.mf-sos-main  { display: grid; grid-template-columns: minmax(0, 1fr) 372px; gap: 16px; align-items: stretch; }
.mf-sos-pane  { height: calc(100vh - 260px); min-height: 480px; display: flex; flex-direction: column; }
.mf-sos-row   { padding: 12px 16px; border-bottom: 1px solid var(--border); outline-offset: -2px; }
.mf-sos-row[aria-pressed="true"] { background: var(--ui-accent-tint); box-shadow: inset 2px 0 0 var(--ui-accent); }
.mf-sos-row[aria-pressed="true"]:hover { background: var(--ui-accent-tint-strong); }
.mf-sos-legend { display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; }
.mf-sos-legend i { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
@media (max-width: 1200px) {
  .mf-sos-stats { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .mf-sos-main  { grid-template-columns: minmax(0, 1fr); }
  .mf-sos-list  { height: auto; min-height: 0; max-height: 640px; }
}
@media (max-width: 700px) { .mf-sos-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
`;

const SOSMonitor = () => {
  const [searchParams] = useSearchParams();
  const urlFilter = searchParams.get('filter')?.toUpperCase();
  const validFilters = FILTER_OPTIONS.map(f => f.key);
  // Default to ACTIVE so the live monitor only shows current emergencies.
  // Historical data (Cancelled, Resolved) is accessible via the All filter or stat cards.
  const initialFilter = validFilters.includes(urlFilter) ? urlFilter : 'ACTIVE';
  const { theme } = useTheme() || {};
  const colors = chartColors(theme === 'dark');

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
  const OPEN_STATUSES = ['ACTIVE', 'ASSIGNED', 'ARRIVED'];
  const openEmergencies = scopedEmergencies.filter(e => OPEN_STATUSES.includes(e.status) && e.latitude && e.longitude);

  /* ── Moving vehicles: drop finished emergencies, enrich with responder names ── */
  const liveEmergencyIds = new Set(
    emergencies.filter(e => ['ACTIVE', 'ASSIGNED', 'ARRIVED'].includes(e.status)).map(e => e.id)
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

  const toggleResponderFocus = () => {
    setResponderFocused(f => !f);
    setSelectedEmergency(null); // clear any SOS focus
    // Scroll map into view
    setTimeout(() => mapRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 80);
  };

  const description = activeFilter === 'ACTIVE'
    ? `Live view of active emergencies. ${onlineResponders.length} responder${onlineResponders.length !== 1 ? 's' : ''} online on map.`
    : activeFilter === 'ALL'
      ? 'All emergency requests with full status breakdown.'
      : `Filtered view — ${filterOpt?.label} emergencies.`;

  const statCards = [
    { key: 'ACTIVE',    label: 'Active SOS', value: breakdown.ACTIVE },
    { key: 'ASSIGNED',  label: 'Assigned',   value: breakdown.ASSIGNED },
    { key: 'RESOLVED',  label: 'Resolved',   value: breakdown.RESOLVED },
    { key: 'CANCELLED', label: 'Cancelled',  value: breakdown.CANCELLED },
  ];

  const mapTitle = responderFocused
    ? `Responder view — ${onlineResponders.length} online responder${onlineResponders.length !== 1 ? 's' : ''}`
    : `Live map${activeEmergencies.length > 0 ? ` — ${activeEmergencies.length} active SOS signal${activeEmergencies.length !== 1 ? 's' : ''}` : ''}`;

  return (
    <div className="mf-stack">
      <style>{SOS_CSS}</style>

      {/* ── Page header ── */}
      <PageHeader
        title="SOS Logistics"
        description={description}
        badge={(
          <>
            <LiveIndicator label="Live" tone="success" />
            <StatusBadge tone={socketOnline ? 'success' : 'warning'} icon={socketOnline ? Wifi : WifiOff}>
              {socketOnline ? 'Real-time' : 'Polling only'}
            </StatusBadge>
          </>
        )}
        meta={lastUpdated && (
          <span className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>Updated {timeAgo(lastUpdated)}</span>
        )}
        actions={(
          <>
            <SegmentedControl ariaLabel="Time range" options={TIME_RANGES} value={timeRange} onChange={setTimeRange} />
            <RefreshButton onClick={fetchEmergencies} />
          </>
        )}
      />

      {/* ── Status breakdown ── */}
      <div className="mf-sos-stats">
        {statCards.map(stat => (
          <StatCard
            key={stat.key}
            label={stat.label}
            value={stat.value}
            loading={loading}
            live={stat.key === 'ACTIVE' && stat.value > 0 ? 'Live' : undefined}
            hint={activeFilter === stat.key ? 'Shown in list' : 'Click to filter'}
            onClick={() => setActiveFilter(stat.key)}
          />
        ))}
        {/* Online Responders — clickable: focuses map on all responder pins */}
        <StatCard
          label="Online responders"
          value={onlineResponders.length}
          loading={loading}
          hint={responderFocused ? 'Pinned on map' : 'Click to view on map'}
          onClick={toggleResponderFocus}
        />
      </div>

      {/* ── Error ── */}
      {error && <Notice tone="danger">{error}</Notice>}

      {/* ── Active emergency alert ── */}
      {breakdown.ACTIVE > 0 && (
        <Notice tone="danger" role="status">
          <span className="mf-num" style={{ fontWeight: 600 }}>{breakdown.ACTIVE}</span>{' '}
          active emergenc{breakdown.ACTIVE > 1 ? 'ies' : 'y'} requiring immediate attention
        </Notice>
      )}

      <div className="mf-sos-main">
        {/* ── Live map ─────────────────────────────────────────────────────────
             Shows two layers simultaneously:
               Patient SOS pins (red) — ACTIVE emergencies only
               Responder pins (green) — all available + GPS-located responders
             Click any SOS pin / list row to draw a 5 km radius and highlight nearby
             responders. isolation:isolate traps Leaflet z-indexes inside the box.
        ─────────────────────────────────────────────────────────────────────── */}
        <div ref={mapRef} style={{ minWidth: 0 }}>
          <Card className="mf-sos-pane" style={{ position: 'relative', isolation: 'isolate', zIndex: 0 }}>
            <PanelHeader
              title={mapTitle}
              description={selectedEmergency && !responderFocused
                ? `Showing ${NEARBY_RADIUS_KM} km radius around ${selectedEmergency.patient?.fullName || 'the selected emergency'}`
                : 'Hold Ctrl and scroll to zoom'}
              actions={(
                <>
                  {responderFocused && (
                    <Button size="sm" icon={X} onClick={() => setResponderFocused(false)}>Exit responder view</Button>
                  )}
                  {selectedEmergency && !responderFocused && (
                    <Button size="sm" variant="ghost" icon={X} onClick={() => setSelectedEmergency(null)}>Clear</Button>
                  )}
                </>
              )}
            />

            <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
              {shouldShowMap ? (
                <MapContainer
                  center={mapCenter}
                  zoom={activeEmergencies.length > 0 ? 12 : 6}
                  style={{ height: '100%', width: '100%' }}
                  key={activeFilter}
                  scrollWheelZoom={false}
                >
                  <ThemedTileLayer />
                  <CtrlScrollHint />
                  <InvalidateOnResize />

                  {/* Auto-fit to all responders when Responder View is active */}
                  {responderFocused && <FitBoundsToResponders responders={onlineResponders} />}
                  {!responderFocused && !selectedEmergency && (
                    <FocusOpenEmergencies
                      points={[
                        ...openEmergencies.map(e => [e.latitude, e.longitude]),
                        ...displayVehicles.filter(([, v]) => !v.isDemo).map(([, v]) => [v.lat, v.lon]),
                      ]}
                      focusKey={openEmergencies.map(e => `${e.id}:${e.status}`).join('|')}
                    />
                  )}

                  {/* ── Patient SOS markers (red) — dimmed in responder-focus mode ── */}
                  {openEmergencies.map((e) => (
                    e.latitude && e.longitude ? (
                      <React.Fragment key={e.id}>
                        <Circle
                          center={[e.latitude, e.longitude]}
                          radius={250}
                          color={colors.sos} fillColor={colors.sos}
                          fillOpacity={responderFocused ? 0.04 : 0.12}
                          opacity={responderFocused ? 0.3 : 1}
                          weight={1.5}
                        />
                        <Marker
                          position={[e.latitude, e.longitude]}
                          icon={patientIcon}
                          opacity={responderFocused ? 0.35 : 1}
                          eventHandlers={{ click: () => { if (!responderFocused) setSelectedEmergency(e); } }}
                        >
                          <Popup>
                            <div style={{ minWidth: '210px', fontSize: '13px', lineHeight: 1.4 }}>
                              <StatusBadge tone="danger" style={{ marginBottom: '8px' }}>
                                {humanize(e.emergencyType || 'Medical')} emergency
                              </StatusBadge>
                              <p style={{ margin: '0 0 2px', fontWeight: 600, color: 'var(--text-main)' }}>
                                {e.patient?.fullName || 'Unknown Patient'}
                              </p>
                              <p style={{ margin: '0 0 2px', fontSize: '12.5px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                                <Phone size={12} aria-hidden="true" /> {e.patient?.phoneNumber || 'No phone'}
                              </p>
                              <p className="mf-num" style={{ margin: '0 0 8px', fontSize: '12px', color: 'var(--text-muted)' }}>
                                {e.latitude?.toFixed(5)}, {e.longitude?.toFixed(5)}
                              </p>
                              <p style={{ margin: 0, fontSize: '12.5px', fontWeight: 500, color: nearbyCount(e) > 0 ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                                {nearbyCount(e) > 0
                                  ? `${nearbyCount(e)} responder${nearbyCount(e) !== 1 ? 's' : ''} within ${NEARBY_RADIUS_KM} km`
                                  : `No responders within ${NEARBY_RADIUS_KM} km`}
                              </p>
                              <button
                                type="button"
                                className="mf-btn mf-btn--primary mf-btn--sm"
                                onClick={() => { setSelectedEmergency(e); setResponderFocused(false); }}
                                style={{ marginTop: '10px', width: '100%' }}
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
                      color={colors.primary} fillColor={colors.primary} fillOpacity={0.06}
                      weight={2} dashArray="6 4"
                    />
                  )}

                  {/* ── Online responder markers ── */}
                  {/* In focus mode: large icon + green halo. Normal: small icon. */}
                  {onlineResponders.map((r) => (
                    r.currentLatitude && r.currentLongitude ? (
                      <React.Fragment key={r.userId}>
                        {responderFocused && (
                          <Circle
                            center={[r.currentLatitude, r.currentLongitude]}
                            radius={180}
                            color={colors.success} fillColor={colors.success} fillOpacity={0.18}
                            weight={2}
                          />
                        )}
                        <Marker
                          position={[r.currentLatitude, r.currentLongitude]}
                          icon={responderFocused ? greenIconLarge : greenIcon}
                        >
                          <Popup>
                            <div style={{ minWidth: '200px', fontSize: '13px', lineHeight: 1.4 }}>
                              <StatusBadge tone="success" style={{ marginBottom: '8px' }}>Available responder</StatusBadge>
                              <p style={{ margin: '0 0 2px', fontWeight: 600, color: 'var(--text-main)' }}>
                                {r.user?.fullName || 'Responder'}
                              </p>
                              <p style={{ margin: '0 0 2px', fontSize: '12.5px', color: 'var(--text-muted)' }}>
                                {r.responderType?.replace(/_/g, ' ') || 'Responder'}{r.organization ? ` · ${r.organization}` : ''}
                              </p>
                              {r.user?.phoneNumber && (
                                <p style={{ margin: '0 0 2px', fontSize: '12.5px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                                  <Phone size={12} aria-hidden="true" /> {r.user.phoneNumber}
                                </p>
                              )}
                              <p className="mf-num" style={{ margin: '4px 0', fontSize: '12px', color: 'var(--text-muted)' }}>
                                {r.currentLatitude?.toFixed(5)}, {r.currentLongitude?.toFixed(5)}
                              </p>
                              <p className="mf-num" style={{ margin: 0, fontSize: '12.5px', fontWeight: 500, color: 'var(--text-main)' }}>
                                Rating {Number(r.rating || 5).toFixed(1)}
                              </p>
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
                       rotates to face the actual direction of travel.
                  ──────────────────────────────────────────────────────────────────── */}
                  {displayVehicles.map(([rid, v]) => (
                    <MovingVehicleMarker key={rid} vehicle={{ ...v, responderId: rid }} />
                  ))}
                </MapContainer>
              ) : loading ? (
                <div style={{ position: 'absolute', inset: 0, padding: '16px' }}>
                  <Skeleton h="100%" br={8} />
                </div>
              ) : (
                <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--surface-alt)' }}>
                  <EmptyState
                    icon={MapPin}
                    title="Nothing to show on the map"
                    message="Active SOS signals and GPS-located online responders appear here."
                  />
                </div>
              )}
            </div>

            {/* Legend */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px 16px', flexWrap: 'wrap', padding: '8px 16px', borderTop: '1px solid var(--border)', fontSize: '12px', color: 'var(--text-muted)' }}>
              {activeEmergencies.length > 0 && (
                <span className="mf-sos-legend"><i style={{ background: 'var(--sos)' }} />Patient SOS</span>
              )}
              <span className="mf-sos-legend">
                <i style={{ background: 'var(--success)' }} />Responder <span className="mf-num">({onlineResponders.length})</span>
              </span>
              {displayVehicles.length > 0 && (
                <span className="mf-sos-legend">
                  <Navigation size={12} aria-hidden="true" style={{ color: 'var(--success-fg)' }} />En route <span className="mf-num">({displayVehicles.length})</span>
                </span>
              )}
              {selectedEmergency && (
                <span className="mf-sos-legend">
                  <i style={{ background: 'var(--ui-accent-tint-strong)', border: '1px dashed var(--ui-accent)' }} />{NEARBY_RADIUS_KM} km radius
                </span>
              )}
            </div>
          </Card>
        </div>

        {/* ── Emergency list ── */}
        <Card className="mf-sos-pane mf-sos-list">
          <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)', display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '8px' }}>
              <h2 style={{ fontSize: '14px', lineHeight: '20px', fontWeight: 600, color: 'var(--text-main)', margin: 0 }}>Emergencies</h2>
              {!loading && (
                <span className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
                  {filtered.length} of {scopedEmergencies.length}
                </span>
              )}
            </div>
            <SegmentedControl
              ariaLabel="Filter emergencies by status"
              value={activeFilter}
              onChange={setActiveFilter}
              options={FILTER_OPTIONS.map(f => ({ value: f.key, label: f.label }))}
            />
          </div>

          <div style={{ flex: 1, minHeight: 0, overflowY: 'auto' }} aria-live="polite">
            {loading ? (
              Array.from({ length: 5 }, (_, i) => (
                <div key={i} className="mf-sos-row">
                  <Skeleton h={18} w="30%" mb={10} br={999} />
                  <Skeleton h={12} w="55%" mb={6} />
                  <Skeleton h={10} w="75%" />
                </div>
              ))
            ) : filtered.length === 0 ? (
              <EmptyState
                compact
                icon={ShieldCheck}
                title={activeFilter === 'ACTIVE' ? 'No active emergencies' : 'No records found'}
                message={activeFilter === 'ACTIVE'
                  ? 'All clear — no active SOS signals at this time.'
                  : `No emergencies match the "${filterOpt?.label}" filter.`}
                action={activeFilter !== 'ALL' && activeFilter !== 'ACTIVE' && (
                  <Button size="sm" onClick={() => setActiveFilter('ALL')}>Show all</Button>
                )}
              />
            ) : (
              filtered.map((e) => {
                const hasGps = !!(e.latitude && e.longitude);
                const selected = selectedEmergency?.id === e.id;
                const toggle = () => hasGps && setSelectedEmergency(selected ? null : e);
                const nearby = nearbyCount(e);
                const responderName = e.responder?.fullName || e.assignedResponderName;
                const notified = e.emergencyRequests?.length || 0;
                return (
                  <div
                    key={e.id}
                    className="mf-sos-row mf-row-hover"
                    role={hasGps ? 'button' : undefined}
                    tabIndex={hasGps ? 0 : undefined}
                    aria-pressed={hasGps ? selected : undefined}
                    onClick={toggle}
                    onKeyDown={hasGps ? (ev) => {
                      if (ev.target !== ev.currentTarget) return;
                      if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); toggle(); }
                    } : undefined}
                    style={{ cursor: hasGps ? 'pointer' : 'default' }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginBottom: '6px' }}>
                      <StatusBadge tone={e.status === 'ACTIVE' ? 'danger' : toneFor(e.status)}>{humanize(e.status)}</StatusBadge>
                      <span className="mf-num" style={{ fontSize: '12px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }} title={e.createdAt ? new Date(e.createdAt).toLocaleString() : undefined}>
                        {formatTime(e.createdAt)}{e.createdAt ? ` · ${timeAgo(e.createdAt)}` : ''}
                      </span>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '8px' }}>
                      <span style={{ fontSize: '13.5px', fontWeight: 600, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {e.patient?.fullName || 'Anonymous Patient'}
                      </span>
                      <span style={{ fontSize: '12.5px', color: 'var(--admin-text-sub)', whiteSpace: 'nowrap' }}>
                        {humanize(e.emergencyType || 'Medical')}
                      </span>
                    </div>

                    <p style={{ margin: '2px 0 0', fontSize: '12.5px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '5px', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                      <Phone size={11} aria-hidden="true" style={{ flexShrink: 0 }} />
                      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.patient?.phoneNumber || 'No contact on file'}</span>
                    </p>

                    <p style={{ margin: '2px 0 0', fontSize: '12.5px', color: 'var(--text-muted)' }}>
                      {responderName
                        ? <>Responder: <span style={{ color: 'var(--admin-text-sub)' }}>{responderName}</span></>
                        : <><span className="mf-num">{notified}</span> responder{notified !== 1 ? 's' : ''} notified</>}
                    </p>

                    {/* Nearby responders — only for ACTIVE/ASSIGNED emergencies with GPS */}
                    {(e.status === 'ACTIVE' || e.status === 'ASSIGNED') && hasGps && (
                      <p style={{ margin: '4px 0 0', fontSize: '12.5px', fontWeight: 500, color: nearby > 0 ? 'var(--success-fg)' : 'var(--warning-fg)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                        <Navigation size={11} aria-hidden="true" />
                        {nearby > 0
                          ? `${nearby} responder${nearby !== 1 ? 's' : ''} within ${NEARBY_RADIUS_KM} km`
                          : `No responders within ${NEARBY_RADIUS_KM} km`}
                      </p>
                    )}

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginTop: '6px' }}>
                      <span className="mf-num" style={{ fontSize: '12px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                        <MapPin size={11} aria-hidden="true" />
                        {hasGps ? `${e.latitude?.toFixed(6)}, ${e.longitude?.toFixed(6)}` : 'No GPS coordinates'}
                      </span>
                      {hasGps && (
                        <a
                          href={`https://maps.google.com/?q=${e.latitude},${e.longitude}`}
                          target="_blank" rel="noopener noreferrer"
                          className="mf-link"
                          onClick={(ev) => ev.stopPropagation()}
                          style={{ fontSize: '12px', display: 'inline-flex', alignItems: 'center', gap: '4px', whiteSpace: 'nowrap' }}
                        >
                          Open Maps <ExternalLink size={11} aria-hidden="true" />
                        </a>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Demo-only route simulation (for presentations) — clearly labelled as not real data */}
          <div style={{ padding: '10px 16px', borderTop: '1px solid var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', background: 'var(--surface-alt)' }}>
            <div style={{ minWidth: 0 }}>
              <p style={{ margin: 0, fontSize: '11px', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>Demo</p>
              <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-muted)' }}>
                {simRunning ? 'Simulated ambulance running — not real data.' : 'Simulated ambulance on a fixed Lahore route. Not real data.'}
              </p>
            </div>
            <Button
              size="sm"
              variant={simRunning ? 'danger-outline' : 'secondary'}
              icon={simRunning ? Square : Play}
              onClick={simRunning ? stopSimulation : startSimulation}
              title="Plays a simulated ambulance along a fixed Lahore route. Not real responder data."
            >
              {simRunning ? 'Stop simulation' : 'Demo simulation'}
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
};

export default SOSMonitor;

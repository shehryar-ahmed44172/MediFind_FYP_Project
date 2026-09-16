import React, { useState, useEffect } from 'react';
import { Users, Activity, ShieldCheck, HeartPulse, ArrowUpRight, TrendingUp, Zap, MapPin, ExternalLink } from 'lucide-react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import api from '../../services/api';

// Fix Leaflet default marker icons broken by Vite bundling
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl:       'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl:     'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

const redIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [20, 33], iconAnchor: [10, 33], popupAnchor: [1, -28], shadowSize: [33, 33],
});

const greenIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
  iconSize: [18, 29], iconAnchor: [9, 29], popupAnchor: [1, -24], shadowSize: [29, 29],
});

const Overview = () => {
  const navigate = useNavigate();

  const [stats, setStats] = useState({
    totalUsers: 0,
    totalEmergencies: 0,
    activeEmergencies: 0,
    onlineResponders: 0,
  });

  // Map data
  const [mapEmergencies,  setMapEmergencies]  = useState([]);
  const [mapResponders,   setMapResponders]   = useState([]);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await api.get('/api/admin/stats');
        if (response.data.success) setStats(response.data.data);
      } catch (error) {
        console.error('Error fetching stats:', error);
      }
    };
    fetchStats();
  }, []);

  // Fetch active emergencies + online responders for the map (refresh every 10 s)
  useEffect(() => {
    const fetchMapData = async () => {
      try {
        const [emRes, respRes] = await Promise.allSettled([
          api.get('/api/emergencies'),
          api.get('/api/admin/responders/online'),
        ]);
        if (emRes.status === 'fulfilled' && emRes.value.data.success) {
          setMapEmergencies(
            (emRes.value.data.data || []).filter(e => e.status === 'ACTIVE')
          );
        }
        if (respRes.status === 'fulfilled' && respRes.value.data.success) {
          setMapResponders(respRes.value.data.data || []);
        }
      } catch { /* silent — map still renders empty */ }
    };
    fetchMapData();
    const id = setInterval(fetchMapData, 10000);
    return () => clearInterval(id);
  }, []);

  // Derive map center from active SOS pins, fall back to Pakistan centre
  const mapCenter = mapEmergencies.length > 0
    ? [
        mapEmergencies.reduce((s, e) => s + (e.latitude  || 30.3753), 0) / mapEmergencies.length,
        mapEmergencies.reduce((s, e) => s + (e.longitude || 69.3451), 0) / mapEmergencies.length,
      ]
    : [30.3753, 69.3451];
  const mapZoom = mapEmergencies.length > 0 ? 11 : 5;

  const statCards = [
    {
      label: 'Total Users',
      value: stats.totalUsers,
      icon: <Users size={22} />,
      color: '#6366f1',
      colorVar: 'rgba(99,102,241,0.12)',
      trend: '+12.5%',
    },
    {
      label: 'Total SOS Requests',
      value: stats.totalEmergencies,
      icon: <HeartPulse size={22} />,
      color: 'var(--s-active)',
      colorVar: 'var(--s-active-tint)',
      trend: '+8.2%',
    },
    {
      label: 'Active Emergencies',
      value: stats.activeEmergencies,
      icon: <Activity size={22} />,
      color: 'var(--s-pending)',
      colorVar: 'var(--s-pending-tint)',
      trend: 'Live',
      isLive: true,
    },
    {
      label: 'Verified Responders',
      value: stats.onlineResponders,
      icon: <ShieldCheck size={22} />,
      color: 'var(--s-resolved)',
      colorVar: 'var(--s-resolved-tint)',
      trend: '+5.1%',
    },
  ];

  return (
    <div style={{ animation: 'fadeIn 0.5s ease-out' }}>
      {/* ── Page Header ── */}
      <div style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--primary)', letterSpacing: '-0.03em', marginBottom: '0.375rem' }}>
          Dashboard Overview
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
          Real-time platform metrics and system health status.
        </p>
      </div>

      {/* ── Stats Grid ── */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '1.25rem',
        marginBottom: '2rem',
      }}>
        {statCards.map((stat, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.08 }}
            className="glass-card"
            style={{
              padding: '1.5rem',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '1rem',
              position: 'relative',
              borderRadius: 'var(--radius-md)',
              cursor: 'default',
            }}
          >
            <div style={{
              width: '46px', height: '46px', borderRadius: '12px',
              background: stat.colorVar, color: stat.color,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              {stat.icon}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <span style={{ display: 'block', fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '0.25rem', fontWeight: 600 }}>
                {stat.label}
              </span>
              <h2 style={{
                fontSize: '1.75rem', fontWeight: 800,
                color: 'var(--text-sub)', marginBottom: '0.375rem',
                letterSpacing: '-0.04em', lineHeight: 1,
              }}>
                {stat.value}
              </h2>
              <span style={{
                fontSize: '0.75rem',
                color: stat.isLive ? 'var(--s-active)' : 'var(--s-resolved)',
                display: 'flex', alignItems: 'center', gap: '0.25rem', fontWeight: 700,
              }}>
                {stat.isLive
                  ? <><Zap size={12} /> Live</>
                  : <><TrendingUp size={12} /> {stat.trend}</>
                }
              </span>
            </div>
            <ArrowUpRight size={18} style={{ color: 'var(--text-muted)', position: 'absolute', top: '1.25rem', right: '1.25rem' }} />
          </motion.div>
        ))}
      </div>

      {/* ── Dashboard Charts + Live Map Row ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '3fr 2fr', gap: '1.25rem' }}>

        {/* Chart placeholder */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.35 }}
          className="glass-card"
          style={{ padding: '1.5rem', borderRadius: 'var(--radius-md)', minHeight: '300px' }}
        >
          <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-sub)', marginBottom: '1.25rem' }}>
            Emergency Frequency — Last 7 Days
          </h3>
          <div style={{
            height: '220px',
            background: 'var(--surface-raised)',
            border: '2px dashed var(--border)',
            borderRadius: 'var(--radius-sm)',
            display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            color: 'var(--text-muted)',
            gap: '0.75rem',
          }}>
            <Activity size={32} style={{ opacity: 0.35 }} />
            <p style={{ fontSize: '0.9rem', fontWeight: 600 }}>Chart coming soon</p>
            <p style={{ fontSize: '0.78rem', opacity: 0.7 }}>Analytics integration in progress</p>
          </div>
        </motion.div>

        {/* ── Live Map Panel ── */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.42 }}
          className="glass-card"
          style={{
            padding: 0,
            borderRadius: 'var(--radius-md)',
            overflow: 'hidden',
            isolation: 'isolate',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {/* Map header */}
          <div style={{
            padding: '0.875rem 1.125rem',
            borderBottom: '1px solid var(--border)',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            flexShrink: 0,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
              <MapPin size={15} color="var(--s-active)" />
              <h3 style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-sub)' }}>
                Live Map
              </h3>
              {mapEmergencies.length > 0 && (
                <motion.span
                  animate={{ opacity: [1, 0.4, 1] }}
                  transition={{ repeat: Infinity, duration: 1.4 }}
                  style={{
                    fontSize: '0.68rem', fontWeight: 800,
                    color: 'var(--s-active)',
                    background: 'var(--s-active-tint)',
                    padding: '0.2rem 0.55rem',
                    borderRadius: '20px',
                    letterSpacing: '0.04em',
                  }}
                >
                  {mapEmergencies.length} SOS
                </motion.span>
              )}
            </div>
            <button
              onClick={() => navigate('/admin/sos')}
              style={{
                display: 'flex', alignItems: 'center', gap: '0.35rem',
                fontSize: '0.75rem', fontWeight: 700,
                color: 'var(--primary)', background: 'none',
                border: '1px solid var(--border)',
                borderRadius: '8px', padding: '0.3rem 0.75rem',
                cursor: 'pointer', fontFamily: 'inherit',
                transition: 'background 0.15s',
              }}
              onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-raised)'}
              onMouseLeave={e => e.currentTarget.style.background = 'none'}
            >
              <ExternalLink size={12} /> Full Monitor
            </button>
          </div>

          {/* Leaflet map */}
          <div style={{ flex: 1, minHeight: 0, position: 'relative' }}>
            <MapContainer
              center={mapCenter}
              zoom={mapZoom}
              style={{ height: '100%', minHeight: '270px', width: '100%' }}
              scrollWheelZoom={false}
              zoomControl={true}
              attributionControl={false}
            >
              <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />

              {/* Active SOS — red pins */}
              {mapEmergencies.map(e => e.latitude && e.longitude && (
                <React.Fragment key={e.id}>
                  <Circle
                    center={[e.latitude, e.longitude]}
                    radius={300}
                    color="#EF4444" fillColor="#EF4444" fillOpacity={0.12}
                  />
                  <Marker position={[e.latitude, e.longitude]} icon={redIcon}>
                    <Popup>
                      <div style={{ minWidth: '160px' }}>
                        <strong style={{ color: '#EF4444', fontSize: '12px', display: 'block', marginBottom: '4px' }}>
                          🆘 {e.emergencyType || 'Medical'} Emergency
                        </strong>
                        <p style={{ margin: '0 0 2px', fontSize: '12px', fontWeight: 600 }}>
                          {e.patient?.fullName || 'Unknown Patient'}
                        </p>
                        <p style={{ margin: '0', fontSize: '11px', color: '#64748B', fontFamily: 'monospace' }}>
                          {e.latitude?.toFixed(5)}, {e.longitude?.toFixed(5)}
                        </p>
                      </div>
                    </Popup>
                  </Marker>
                </React.Fragment>
              ))}

              {/* Online responders — green pins */}
              {mapResponders.map(r => r.currentLatitude && r.currentLongitude && (
                <Marker
                  key={r.userId}
                  position={[r.currentLatitude, r.currentLongitude]}
                  icon={greenIcon}
                >
                  <Popup>
                    <div style={{ minWidth: '150px' }}>
                      <strong style={{ color: '#059669', fontSize: '12px', display: 'block', marginBottom: '4px' }}>
                        🟢 {r.user?.fullName || 'Responder'}
                      </strong>
                      <p style={{ margin: '0', fontSize: '11px', color: '#64748B' }}>
                        {r.responderType?.replace(/_/g, ' ') || 'Responder'}
                      </p>
                    </div>
                  </Popup>
                </Marker>
              ))}
            </MapContainer>
          </div>

          {/* Map footer legend */}
          <div style={{
            padding: '0.5rem 1.125rem',
            borderTop: '1px solid var(--border)',
            display: 'flex', alignItems: 'center', gap: '1rem',
            flexShrink: 0,
            background: 'var(--surface)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.72rem', color: '#EF4444', fontWeight: 700 }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#EF4444' }} />
              SOS ({mapEmergencies.length})
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.72rem', color: '#059669', fontWeight: 700 }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10B981' }} />
              Responders ({mapResponders.length})
            </div>
            <span style={{ marginLeft: 'auto', fontSize: '0.68rem', color: 'var(--text-muted)' }}>
              Auto-refresh 10s
            </span>
          </div>
        </motion.div>

      </div>
    </div>
  );
};

export default Overview;

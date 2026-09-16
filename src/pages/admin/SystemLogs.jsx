import React, { useState, useEffect, useCallback } from 'react';
import { History, Search, Filter, RefreshCw, CheckCircle, AlertCircle, Info, XCircle } from 'lucide-react';
import { motion } from 'framer-motion';
import api from '../../services/api';

const LEVEL_CONFIG = {
  INFO:    { color: 'var(--primary)', bg: '#ebf8ff', icon: Info },
  SUCCESS: { color: '#10b981', bg: '#d1fae5', icon: CheckCircle },
  WARNING: { color: '#f59e0b', bg: '#fef3c7', icon: AlertCircle },
  ERROR:   { color: '#ef4444', bg: '#fee2e2', icon: XCircle },
};

const formatTime = (iso) => {
  const d = new Date(iso);
  return d.toLocaleString('en-PK', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit', hour12: true });
};

const SystemLogs = () => {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('ALL');
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);

  const levels = ['ALL', 'INFO', 'SUCCESS', 'WARNING', 'ERROR'];

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/api/admin/logs', { params: { limit: 200, search: search || undefined } });
      if (res.data.success) {
        setLogs(res.data.data.map(log => ({
          id:        log.id,
          level:     log.level,
          action:    log.action,
          detail:    `${log.entity} #${log.entityId}`,
          user:      log.user,
          timestamp: log.timestamp,
        })));
      }
    } catch {
      // fallback: keep existing logs
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => { fetchLogs(); }, [fetchLogs]);

  const filtered = logs.filter((log) => {
    const matchesLevel = filter === 'ALL' || log.level === filter;
    const matchesSearch = search === '' ||
      log.action.toLowerCase().includes(search.toLowerCase()) ||
      log.detail.toLowerCase().includes(search.toLowerCase()) ||
      log.user.toLowerCase().includes(search.toLowerCase());
    return matchesLevel && matchesSearch;
  });

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.5 }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2.5rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.5rem' }}>System Logs</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '1.05rem' }}>Immutable audit trail of all system and admin interactions.</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}
          onClick={fetchLogs}
          style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', padding: '0.75rem 1.5rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, cursor: 'pointer', fontSize: '0.9rem' }}
        >
          <RefreshCw size={16} /> Refresh
        </motion.button>
      </div>

      {/* Filters */}
      <div className="card" style={{ padding: '1.5rem 2rem', border: '1px solid var(--border)', marginBottom: '1.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '1.5rem', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
          {levels.map((lvl) => {
            const cfg = LEVEL_CONFIG[lvl];
            const active = filter === lvl;
            return (
              <button
                key={lvl}
                onClick={() => setFilter(lvl)}
                style={{
                  padding: '0.5rem 1.25rem', borderRadius: '100px', fontWeight: 700, fontSize: '0.8rem',
                  border: active ? 'none' : '1px solid var(--border)',
                  background: active ? (cfg?.bg || 'var(--secondary)') : 'white',
                  color: active ? (cfg?.color || 'white') : 'var(--text-muted)',
                  cursor: 'pointer', transition: 'all 0.15s',
                }}
              >
                {lvl}
              </button>
            );
          })}
        </div>
        <div style={{ position: 'relative' }}>
          <Search size={16} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
          <input
            type="text"
            placeholder="Search logs..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ padding: '0.75rem 1rem 0.75rem 2.75rem', width: '280px', fontSize: '0.875rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface-raised)', fontFamily: 'var(--font-sans)', outline: 'none' }}
          />
        </div>
      </div>

      {/* Log Entries */}
      <div className="card" style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border)' }}>
        {filtered.length === 0 ? (
          <div style={{ padding: '5rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            <History size={48} style={{ opacity: 0.2, marginBottom: '1.5rem', display: 'block', margin: '0 auto 1.5rem' }} />
            <p style={{ fontWeight: 600 }}>No logs match your filters</p>
          </div>
        ) : (
          filtered.map((log, idx) => {
            const cfg = LEVEL_CONFIG[log.level] || LEVEL_CONFIG.INFO;
            const Icon = cfg.icon;
            return (
              <motion.div
                key={log.id}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: idx * 0.03 }}
                style={{
                  display: 'flex', alignItems: 'flex-start', gap: '1.5rem',
                  padding: '1.5rem 2rem', borderBottom: idx < filtered.length - 1 ? '1px solid var(--border)' : 'none',
                  background: 'var(--surface)',
                }}
              >
                <div style={{ padding: '0.625rem', borderRadius: '10px', background: cfg.bg, color: cfg.color, flexShrink: 0 }}>
                  <Icon size={18} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.375rem' }}>
                    <span style={{ fontWeight: 700, color: 'var(--secondary)', fontSize: '0.95rem' }}>{log.action}</span>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', whiteSpace: 'nowrap', marginLeft: '2rem' }}>{formatTime(log.timestamp)}</span>
                  </div>
                  <p style={{ fontSize: '0.875rem', color: 'var(--text-muted)', marginBottom: '0.375rem' }}>{log.detail}</p>
                  <span style={{ fontSize: '0.75rem', fontWeight: 600, color: cfg.color, background: cfg.bg, padding: '0.2rem 0.625rem', borderRadius: '6px' }}>{log.user}</span>
                </div>
              </motion.div>
            );
          })
        )}
      </div>
    </motion.div>
  );
};

export default SystemLogs;

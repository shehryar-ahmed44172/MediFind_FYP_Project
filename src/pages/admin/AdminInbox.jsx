import React, { useState, useEffect } from 'react';
import { 
  Bell, 
  Search, 
  Trash2, 
  CheckCheck, 
  Filter, 
  AlertTriangle, 
  UserCheck, 
  Info,
  Clock,
  ExternalLink,
  ChevronRight,
  MoreVertical,
  MailOpen,
  RotateCcw
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { useAlert } from '../../context/AlertContext';
import api from '../../services/api';

// This would typically come from a global state or context in a real app
// For this demo, we'll use mock data and eventually hook into the socket state
const AdminInbox = () => {
  const navigate = useNavigate();
  const { showAlert } = useAlert();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('ALL'); 
  const [selectedNotif, setSelectedNotif] = useState(null);
  const [loading, setLoading] = useState(true);
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    fetchNotifications();
  }, []);

  const fetchNotifications = async () => {
    try {
      setLoading(true);
      const res = await api.get('/api/notifications/history?limit=100');
      if (res.data.success) {
        setNotifications(res.data.data);
      }
    } catch (err) {
      console.error('Failed to fetch notifications:', err);
    } finally {
      setLoading(false);
    }
  };

  const markAllRead = async () => {
    try {
      await api.patch('/api/notifications/read-all');
      setNotifications(notifications.map(n => ({ ...n, isRead: true })));
      showAlert('All notifications marked as read', 'success');
    } catch (err) {
      showAlert('Failed to update notifications', 'error');
    }
  };

  const markRead = async (id) => {
    try {
      await api.patch(`/api/notifications/${id}/read`);
      setNotifications(notifications.map(n => n.id === id ? { ...n, isRead: true } : n));
    } catch (err) {
      console.error('Failed to mark read:', err);
    }
  };

  const deleteNotif = (id) => {
    // Note: Backend doesn't have a hard delete for notifications yet
    // We'll filter it locally for now
    setNotifications(notifications.filter(n => n.id !== id));
    if (selectedNotif?.id === id) setSelectedNotif(null);
  };

  const filteredNotifs = notifications.filter(n => {
    const matchesSearch = n.title.toLowerCase().includes(search.toLowerCase()) || 
                          n.body.toLowerCase().includes(search.toLowerCase());
    const matchesFilter = filter === 'ALL' || 
                         (filter === 'UNREAD' && !n.isRead) ||
                         (filter === 'SOS' && n.type.includes('SOS')) ||
                         (filter === 'SYSTEM' && n.type.includes('SYSTEM'));
    return matchesSearch && matchesFilter;
  });

  const getIcon = (type) => {
    if (type.includes('SOS')) return <AlertTriangle size={18} color="#ef4444" />;
    if (type.includes('REGISTRATION')) return <UserCheck size={18} color="var(--primary)" />;
    if (type.includes('SYSTEM')) return <CheckCheck size={18} color="#10b981" />;
    return <Info size={18} color="#64748b" />;
  };

  const handleAction = (n) => {
    setNotifications(notifications.map(item => item.id === n.id ? { ...item, isRead: true } : item));
    if (n.type.includes('SOS')) navigate('/admin/sos');
    else if (n.type.includes('REGISTRATION')) navigate('/admin/verify');
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
      style={{ height: 'calc(100vh - 120px)', display: 'flex', flexDirection: 'column' }}
    >
      {/* Header Area */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '1.5rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--secondary)', letterSpacing: '-0.02em', marginBottom: '0.4rem' }}>Admin Inbox</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>Review and manage real-time alerts from across the network.</p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem' }}>
          <button
            onClick={fetchNotifications}
            disabled={loading}
            style={{ padding: '0.6rem 1.25rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, fontSize: '0.85rem', cursor: loading ? 'not-allowed' : 'pointer', display: 'flex', alignItems: 'center', gap: '0.5rem', opacity: loading ? 0.6 : 1 }}
          >
            <RotateCcw size={15} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} /> Refresh
          </button>
          <button
            onClick={markAllRead}
            style={{ padding: '0.6rem 1.25rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--secondary)', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.5rem' }}
          >
            <CheckCheck size={16} /> Mark all read
          </button>
        </div>
      </div>

      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '380px 1fr', gap: '1.5rem', minHeight: 0 }}>
        
        {/* Sidebar: List */}
        <div className="card" style={{ padding: 0, display: 'flex', flexDirection: 'column', border: '1px solid var(--border)', overflow: 'hidden' }}>
          <div style={{ padding: '1.25rem', borderBottom: '1px solid var(--border)', background: 'var(--surface-raised)' }}>
            <div style={{ position: 'relative', marginBottom: '1rem' }}>
              <Search size={14} style={{ position: 'absolute', left: '1rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
              <input 
                type="text" 
                placeholder="Search alerts..." 
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{ width: '100%', padding: '0.6rem 1rem 0.6rem 2.5rem', fontSize: '0.875rem', borderRadius: '10px', border: '1px solid var(--border)', background: 'var(--surface)', outline: 'none' }} 
              />
            </div>
            <div style={{ display: 'flex', gap: '0.5rem', overflowX: 'auto', paddingBottom: '2px' }}>
              {['ALL', 'UNREAD', 'SOS', 'SYSTEM'].map(f => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  style={{
                    padding: '0.4rem 0.8rem', borderRadius: '8px', border: 'none',
                    background: filter === f ? 'var(--primary)' : 'white',
                    color: filter === f ? 'white' : 'var(--text-muted)',
                    fontWeight: 700, fontSize: '0.7rem', cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)', whiteSpace: 'nowrap'
                  }}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          <div style={{ flex: 1, overflowY: 'auto' }}>
            {loading ? (
              <div style={{ padding: '4rem 2rem', textAlign: 'center' }}>
                 <RotateCcw className="animate-spin" style={{ color: 'var(--primary)', opacity: 0.5 }} />
              </div>
            ) : filteredNotifs.length === 0 ? (
              <div style={{ padding: '4rem 2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                <MailOpen size={32} style={{ marginBottom: '1rem', opacity: 0.3 }} />
                <p style={{ fontSize: '0.9rem', margin: 0 }}>No notifications found.</p>
              </div>
            ) : (
              filteredNotifs.map(n => (
                <div 
                  key={n.id}
                  onClick={() => { setSelectedNotif(n); if(!n.isRead) markRead(n.id); }}
                  style={{ 
                    padding: '1.25rem', borderBottom: '1px solid var(--border)', 
                    cursor: 'pointer', position: 'relative',
                    background: selectedNotif?.id === n.id ? '#f1f5f9' : 'transparent',
                    transition: 'background 0.2s'
                  }}
                >
                  {!n.isRead && (
                    <div style={{ position: 'absolute', left: '0', top: '0', bottom: '0', width: '4px', background: 'var(--primary)' }} />
                  )}
                  <div style={{ display: 'flex', gap: '1rem' }}>
                    <div style={{ flexShrink: 0, marginTop: '2px' }}>{getIcon(n.type)}</div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '2px' }}>
                        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{n.title}</span>
                        <span style={{ fontSize: '0.65rem', color: 'var(--text-muted)', flexShrink: 0 }}>{new Date(n.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                      </div>
                      <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{n.body}</p>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Content View */}
        <div className="card" style={{ padding: 0, display: 'flex', flexDirection: 'column', border: '1px solid var(--border)', overflow: 'hidden' }}>
          <AnimatePresence mode="wait">
            {selectedNotif ? (
              <motion.div 
                key={selectedNotif.id}
                initial={{ opacity: 0, x: 10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 10 }}
                style={{ flex: 1, display: 'flex', flexDirection: 'column' }}
              >
                {/* View Toolbar */}
                <div style={{ padding: '1rem 2rem', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', gap: '1rem' }}>
                    <button 
                      onClick={() => handleAction(selectedNotif)}
                      style={{ padding: '0.5rem 1rem', borderRadius: '8px', background: 'var(--surface-raised)', border: 'none', color: 'var(--primary)', fontWeight: 700, fontSize: '0.8rem', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.4rem' }}
                    >
                      <ExternalLink size={14} /> Open in Portal
                    </button>
                    <button 
                      onClick={() => setNotifications(notifications.map(item => item.id === selectedNotif.id ? { ...item, isRead: !item.isRead } : item))}
                      style={{ padding: '0.5rem 1rem', borderRadius: '8px', background: 'transparent', border: '1px solid var(--border)', color: 'var(--text-muted)', fontWeight: 700, fontSize: '0.8rem', cursor: 'pointer' }}
                    >
                      {selectedNotif.isRead ? 'Mark as Unread' : 'Mark as Read'}
                    </button>
                  </div>
                  <button 
                    onClick={() => deleteNotif(selectedNotif.id)}
                    style={{ padding: '0.5rem', borderRadius: '8px', background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer' }}
                  >
                    <Trash2 size={18} />
                  </button>
                </div>

                {/* View Body */}
                <div style={{ flex: 1, padding: '3rem 4rem', overflowY: 'auto' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '2rem' }}>
                    <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'var(--surface-raised)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      {getIcon(selectedNotif.type)}
                    </div>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '2px' }}>
                        <h2 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--secondary)', margin: 0 }}>{selectedNotif.title}</h2>
                        <span style={{ fontSize: '0.7rem', fontWeight: 800, padding: '0.2rem 0.6rem', borderRadius: '4px', background: selectedNotif.type.includes('SOS') ? '#fee2e2' : '#ebf8ff', color: selectedNotif.type.includes('SOS') ? '#ef4444' : 'var(--primary)' }}>
                          {selectedNotif.type}
                        </span>
                      </div>
                      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: 0, display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                        <Clock size={14} /> {new Date(selectedNotif.createdAt).toLocaleString()}
                      </p>
                    </div>
                  </div>

                  <div style={{ background: 'var(--surface-raised)', padding: '2rem', borderRadius: '20px', border: '1px solid var(--border)', marginBottom: '1.5rem' }}>
                    <p style={{ fontSize: '1.05rem', color: 'var(--secondary)', lineHeight: 1.6, whiteSpace: 'pre-wrap', margin: 0 }}>
                      {selectedNotif.body}
                    </p>
                  </div>

                  {/* Show Action button inside the content flow if relevant */}
                  {(selectedNotif.type.includes('SOS') || selectedNotif.type.includes('REGISTRATION')) && (
                    <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '1rem' }}>
                       <button 
                        onClick={() => handleAction(selectedNotif)}
                        style={{ 
                          padding: '0.8rem 1.8rem', borderRadius: '12px', 
                          background: 'linear-gradient(135deg, #0C637E, #2496A7)', 
                          border: 'none', color: 'white', fontWeight: 800, 
                          fontSize: '0.9rem', cursor: 'pointer', display: 'flex', 
                          alignItems: 'center', gap: '0.6rem',
                          boxShadow: '0 4px 12px rgba(12, 99, 126, 0.2)'
                        }}
                      >
                        Action Required <ChevronRight size={18} />
                      </button>
                    </div>
                  )}

                  {selectedNotif.data && (
                    <div style={{ borderTop: '1px solid var(--border)', paddingTop: '2rem' }}>
                      <h4 style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '1rem', letterSpacing: '0.05em' }}>Attached Data</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '1rem' }}>
                        {Object.entries(selectedNotif.data).map(([key, val]) => (
                          <div key={key} style={{ padding: '1rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)' }}>
                            <p style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '4px' }}>{key}</p>
                            <p style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--primary)', margin: 0 }}>{val}</p>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Footer removed and moved inside the scrollable content for better flow */}
              </motion.div>
            ) : (
              <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', color: 'var(--text-muted)' }}>
                <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'var(--surface-raised)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1.5rem' }}>
                  <Bell size={32} opacity={0.3} />
                </div>
                <p style={{ fontSize: '1rem', fontWeight: 600 }}>Select a notification to view details</p>
                <p style={{ fontSize: '0.85rem', opacity: 0.7 }}>Click on an item from the list on the left.</p>
              </div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  );
};

export default AdminInbox;

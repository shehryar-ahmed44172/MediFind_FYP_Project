import React, { createContext, useContext, useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, AlertCircle, Info, X, Bell } from 'lucide-react';

const AlertContext = createContext(null);

export const AlertProvider = ({ children }) => {
  const [alerts, setAlerts] = useState([]);
  const [modal, setModal] = useState(null);

  const showAlert = useCallback((message, type = 'info', duration = 4000) => {
    const id = Math.random().toString(36).substr(2, 9);
    setAlerts(prev => [...prev, { id, message, type }]);

    setTimeout(() => {
      setAlerts(prev => prev.filter(a => a.id !== id));
    }, duration);
  }, []);

  const showConfirm = useCallback(({ title, message, onConfirm, type = 'danger' }) => {
    setModal({ title, message, onConfirm, type });
  }, []);

  const removeAlert = (id) => {
    setAlerts(prev => prev.filter(a => a.id !== id));
  };

  const closeModal = () => setModal(null);

  return (
    <AlertContext.Provider value={{ showAlert, showConfirm }}>
      {children}
      <AnimatePresence>
        {modal && (
          <ConfirmModal 
            {...modal} 
            onClose={closeModal} 
          />
        )}
      </AnimatePresence>
      <div style={{ position: 'fixed', top: '24px', right: '24px', zIndex: 9999, display: 'flex', flexDirection: 'column', gap: '12px', pointerEvents: 'none' }}>
        <AnimatePresence>
          {alerts.map((alert) => (
            <Toast key={alert.id} alert={alert} onRemove={() => removeAlert(alert.id)} />
          ))}
        </AnimatePresence>
      </div>
    </AlertContext.Provider>
  );
};

const Toast = ({ alert, onRemove }) => {
  const config = {
    success: { icon: CheckCircle, color: '#10B981', bg: '#ECFDF5', border: '#D1FAE5' },
    error: { icon: AlertCircle, color: '#EF4444', bg: '#FEF2F2', border: '#FEE2E2' },
    warning: { icon: AlertCircle, color: '#F59E0B', bg: '#FFFBEB', border: '#FEF3C7' },
    info: { icon: Info, color: '#0C637E', bg: '#F0F9FF', border: '#E0F2FE' },
  };

  const { icon: Icon, color, bg, border } = config[alert.type] || config.info;

  return (
    <motion.div
      initial={{ opacity: 0, x: 50, scale: 0.9 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.2 } }}
      style={{
        pointerEvents: 'auto',
        minWidth: '320px',
        maxWidth: '420px',
        background: 'rgba(255, 255, 255, 0.95)',
        backdropFilter: 'blur(12px)',
        border: `1px solid ${border}`,
        borderRadius: '16px',
        padding: '1rem 1.25rem',
        boxShadow: '0 12px 40px rgba(0,0,0,0.08)',
        display: 'flex',
        alignItems: 'center',
        gap: '1rem',
      }}
    >
      <div style={{ width: '40px', height: '40px', borderRadius: '12px', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon size={20} color={color} />
      </div>
      <div style={{ flex: 1 }}>
        <p style={{ margin: 0, fontSize: '0.9rem', fontWeight: 600, color: '#1E293B', lineHeight: 1.4 }}>{alert.message}</p>
      </div>
      <button 
        onClick={onRemove}
        style={{ background: 'none', border: 'none', padding: '4px', cursor: 'pointer', color: '#94A3B8', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        <X size={16} />
      </button>
      <motion.div 
        initial={{ width: '100%' }}
        animate={{ width: '0%' }}
        transition={{ duration: 4, ease: 'linear' }}
        style={{ position: 'absolute', bottom: 0, left: 0, height: '3px', background: color, borderBottomLeftRadius: '16px' }}
      />
    </motion.div>
  );
};

const ConfirmModal = ({ title, message, onConfirm, onClose, type }) => {
  const isDanger = type === 'danger';
  
  return (
    <div style={{ 
      position: 'fixed', inset: 0, zIndex: 10000, 
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '1.5rem', background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(8px)'
    }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.9, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.9, y: 20 }}
        style={{
          width: '100%', maxWidth: '440px', background: 'white',
          borderRadius: '28px', padding: '2.5rem', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.25)',
          textAlign: 'center', border: '1px solid rgba(0,0,0,0.05)'
        }}
      >
        <div style={{ 
          width: '64px', height: '64px', borderRadius: '20px', 
          background: isDanger ? '#FEF2F2' : '#F0F9FF',
          color: isDanger ? '#EF4444' : '#0C637E',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 1.5rem', border: `1px solid ${isDanger ? '#FEE2E2' : '#E0F2FE'}`
        }}>
          {isDanger ? <AlertCircle size={32} /> : <Info size={32} />}
        </div>
        
        <h3 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#0F172A', marginBottom: '0.75rem', letterSpacing: '-0.02em' }}>
          {title}
        </h3>
        
        <p style={{ fontSize: '1rem', color: '#64748B', lineHeight: 1.6, marginBottom: '2.5rem' }}>
          {message}
        </p>
        
        <div style={{ display: 'flex', gap: '1rem' }}>
          <button 
            onClick={onClose}
            style={{ 
              flex: 1, padding: '1rem', borderRadius: '14px', border: '1px solid #E2E8F0',
              background: 'white', color: '#64748B', fontWeight: 700, fontSize: '0.95rem',
              cursor: 'pointer', transition: 'all 0.2s'
            }}
            onMouseEnter={(e) => e.target.style.background = '#F8FAFC'}
            onMouseLeave={(e) => e.target.style.background = 'white'}
          >
            Cancel
          </button>
          <button 
            onClick={() => { onConfirm(); onClose(); }}
            style={{ 
              flex: 1.2, padding: '1rem', borderRadius: '14px', border: 'none',
              background: isDanger ? 'linear-gradient(135deg, #EF4444, #DC2626)' : 'linear-gradient(135deg, #0C637E, #2496A7)',
              color: 'white', fontWeight: 700, fontSize: '0.95rem',
              cursor: 'pointer', boxShadow: `0 10px 20px ${isDanger ? 'rgba(239,68,68,0.2)' : 'rgba(12,99,126,0.2)'}`
            }}
          >
            {isDanger ? 'Delete Permanently' : 'Confirm Action'}
          </button>
        </div>
      </motion.div>
    </div>
  );
};

export const useAlert = () => {
  const context = useContext(AlertContext);
  if (!context) throw new Error('useAlert must be used within AlertProvider');
  return context;
};

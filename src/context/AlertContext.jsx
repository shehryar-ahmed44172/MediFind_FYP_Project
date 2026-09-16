import React, { useState, useCallback, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, AlertCircle, AlertTriangle, Info, X } from 'lucide-react';
import { AlertContext } from './contexts';

/* Toast palette — tint/border tokens flip automatically in dark mode */
const TOAST_TYPES = {
  success: { Icon: CheckCircle,   color: 'var(--success)', bg: 'var(--tint-green)', border: 'var(--success-border)' },
  error:   { Icon: AlertCircle,   color: 'var(--error)',   bg: 'var(--tint-red)',   border: 'var(--error-border)'   },
  warning: { Icon: AlertTriangle, color: 'var(--warning)', bg: 'var(--tint-amber)', border: 'var(--warning-border)' },
  info:    { Icon: Info,          color: 'var(--admin-accent)', bg: 'var(--tint-teal)', border: 'var(--admin-border)' },
};

export const AlertProvider = ({ children }) => {
  const [alerts, setAlerts] = useState([]);
  const [modal, setModal] = useState(null);

  const removeAlert = useCallback((id) => {
    setAlerts(prev => prev.filter(a => a.id !== id));
  }, []);

  const showAlert = useCallback((message, type = 'info', duration = 4000) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
    // Cap the stack so a burst of socket events can't flood the screen
    setAlerts(prev => [...prev.slice(-4), { id, message, type, duration }]);
    setTimeout(() => removeAlert(id), duration);
  }, [removeAlert]);

  /**
   * showConfirm({ title, message, onConfirm, type, confirmLabel, cancelLabel })
   * type: 'danger' | 'warning' | 'info'
   */
  const showConfirm = useCallback((opts) => {
    setModal({ type: 'danger', ...opts });
  }, []);

  const closeModal = useCallback(() => setModal(null), []);

  return (
    <AlertContext.Provider value={{ showAlert, showConfirm }}>
      {children}
      <AnimatePresence>
        {modal && <ConfirmModal {...modal} onClose={closeModal} />}
      </AnimatePresence>
      <div
        role="region"
        aria-live="polite"
        aria-label="Notifications"
        style={{ position: 'fixed', top: '20px', right: '20px', left: 'auto', zIndex: 11000, display: 'flex', flexDirection: 'column', gap: '10px', pointerEvents: 'none', maxWidth: 'calc(100vw - 40px)' }}
      >
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
  const { Icon, color, bg, border } = TOAST_TYPES[alert.type] || TOAST_TYPES.info;

  return (
    <motion.div
      layout
      role={alert.type === 'error' ? 'alert' : 'status'}
      initial={{ opacity: 0, x: 50, scale: 0.95 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95, transition: { duration: 0.2 } }}
      style={{
        pointerEvents: 'auto',
        width: '380px',
        maxWidth: '100%',
        background: 'var(--surface)',
        border: `1px solid ${border}`,
        borderRadius: '14px',
        padding: '0.875rem 1rem',
        boxShadow: 'var(--shadow-md)',
        display: 'flex',
        alignItems: 'center',
        gap: '0.875rem',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon size={18} color={color} />
      </div>
      <p style={{ flex: 1, margin: 0, fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-sub)', lineHeight: 1.45 }}>
        {alert.message}
      </p>
      <button
        type="button"
        onClick={onRemove}
        aria-label="Dismiss notification"
        style={{ background: 'none', border: 'none', padding: '4px', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: '6px' }}
      >
        <X size={16} />
      </button>
      <motion.div
        initial={{ width: '100%' }}
        animate={{ width: '0%' }}
        transition={{ duration: (alert.duration || 4000) / 1000, ease: 'linear' }}
        style={{ position: 'absolute', bottom: 0, left: 0, height: '3px', background: color }}
      />
    </motion.div>
  );
};

const MODAL_TYPES = {
  danger:  { color: 'var(--error)',   bg: 'var(--tint-red)',   grad: 'linear-gradient(135deg, var(--sos), var(--error-fg))', shadow: 'rgba(239,68,68,0.22)', Icon: AlertCircle,   label: 'Delete' },
  warning: { color: 'var(--warning)', bg: 'var(--tint-amber)', grad: 'linear-gradient(135deg, var(--warning), var(--warning-fg))', shadow: 'rgba(245,158,11,0.22)', Icon: AlertTriangle, label: 'Confirm' },
  info:    { color: 'var(--primary)', bg: 'var(--tint-teal)',  grad: 'linear-gradient(135deg, var(--primary), var(--primary-mid))', shadow: 'rgba(12,99,126,0.22)', Icon: Info,          label: 'Confirm' },
};

const ConfirmModal = ({ title, message, onConfirm, onClose, type, confirmLabel, cancelLabel = 'Cancel' }) => {
  const cfg = MODAL_TYPES[type] || MODAL_TYPES.info;
  const cancelRef = useRef(null);
  const [busy, setBusy] = useState(false);

  // Escape closes; focus the safe (cancel) action by default
  useEffect(() => {
    cancelRef.current?.focus();
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const handleConfirm = async () => {
    setBusy(true);
    try {
      await onConfirm?.();
    } finally {
      setBusy(false);
      onClose();
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 10500,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '1.5rem', background: 'rgba(15, 23, 42, 0.45)', backdropFilter: 'blur(6px)',
      }}
    >
      <motion.div
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="mf-confirm-title"
        aria-describedby="mf-confirm-message"
        initial={{ opacity: 0, scale: 0.94, y: 16 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.94, y: 16 }}
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%', maxWidth: '420px', background: 'var(--surface)',
          borderRadius: '20px', padding: '2rem', boxShadow: 'var(--shadow-lg)',
          textAlign: 'center', border: '1px solid var(--border)',
        }}
      >
        <div style={{
          width: '56px', height: '56px', borderRadius: '16px',
          background: cfg.bg, color: cfg.color,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 1.25rem',
        }}>
          <cfg.Icon size={28} />
        </div>

        <h3 id="mf-confirm-title" style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-main)', marginBottom: '0.5rem', letterSpacing: '-0.02em' }}>
          {title}
        </h3>

        <p id="mf-confirm-message" style={{ fontSize: '0.92rem', color: 'var(--text-muted)', lineHeight: 1.6, marginBottom: '1.75rem' }}>
          {message}
        </p>

        <div style={{ display: 'flex', gap: '0.75rem' }}>
          <button
            ref={cancelRef}
            type="button"
            onClick={onClose}
            disabled={busy}
            style={{
              flex: 1, padding: '0.8rem', borderRadius: '12px', border: '1px solid var(--border)',
              background: 'var(--surface)', color: 'var(--text-sub)', fontWeight: 700, fontSize: '0.9rem',
              cursor: 'pointer', fontFamily: 'inherit',
            }}
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            onClick={handleConfirm}
            disabled={busy}
            style={{
              flex: 1, padding: '0.8rem', borderRadius: '12px', border: 'none',
              background: cfg.grad, color: 'white', fontWeight: 700, fontSize: '0.9rem',
              cursor: busy ? 'wait' : 'pointer', fontFamily: 'inherit', opacity: busy ? 0.75 : 1,
              boxShadow: `0 8px 18px ${cfg.shadow}`,
            }}
          >
            {busy ? 'Working…' : (confirmLabel || cfg.label)}
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
};

import React, { useState, useCallback, useEffect, useRef } from 'react';
import { CheckCircle, AlertCircle, AlertTriangle, Info, X } from 'lucide-react';
import { AlertContext } from './contexts';
import { Button, Modal } from '../components/ui';

/* Toast palette — a small status icon on a neutral surface */
const TOAST_TYPES = {
  success: { Icon: CheckCircle,   color: 'var(--success)' },
  error:   { Icon: AlertCircle,   color: 'var(--sos)' },
  warning: { Icon: AlertTriangle, color: 'var(--warning)' },
  info:    { Icon: Info,          color: 'var(--ui-accent, var(--admin-accent))' },
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
      {modal && <ConfirmModal {...modal} onClose={closeModal} />}
      <div
        role="region"
        aria-live="polite"
        aria-label="Notifications"
        style={{ position: 'fixed', top: '64px', right: '16px', left: 'auto', zIndex: 11000, display: 'flex', flexDirection: 'column', gap: '8px', pointerEvents: 'none', maxWidth: 'calc(100vw - 40px)' }}
      >
        {alerts.map((alert) => (
          <Toast key={alert.id} alert={alert} onRemove={() => removeAlert(alert.id)} />
        ))}
      </div>
    </AlertContext.Provider>
  );
};

const Toast = ({ alert, onRemove }) => {
  const { Icon, color } = TOAST_TYPES[alert.type] || TOAST_TYPES.info;

  return (
    <div
      role={alert.type === 'error' ? 'alert' : 'status'}
      className="mf-pop"
      style={{
        pointerEvents: 'auto', width: '360px', maxWidth: '100%',
        background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: '10px',
        padding: '10px 8px 10px 12px', boxShadow: 'var(--shadow-overlay)',
        display: 'flex', alignItems: 'flex-start', gap: '10px',
      }}
    >
      <Icon size={16} color={color} aria-hidden="true" style={{ flexShrink: 0, marginTop: '2px' }} />
      <p style={{ flex: 1, margin: 0, fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', lineHeight: 1.45 }}>
        {alert.message}
      </p>
      <button type="button" onClick={onRemove} aria-label="Dismiss notification" className="mf-icon-btn" style={{ width: '24px', height: '24px' }}>
        <X size={14} />
      </button>
    </div>
  );
};

const MODAL_TYPES = {
  danger:  { variant: 'danger',  label: 'Delete' },
  warning: { variant: 'primary', label: 'Confirm' },
  info:    { variant: 'primary', label: 'Confirm' },
};

const ConfirmModal = ({ title, message, onConfirm, onClose, type, confirmLabel, cancelLabel = 'Cancel' }) => {
  const cfg = MODAL_TYPES[type] || MODAL_TYPES.info;
  const cancelRef = useRef(null);
  const [busy, setBusy] = useState(false);

  // Focus the safe (cancel) action by default; Escape is handled by Modal
  useEffect(() => { cancelRef.current?.focus(); }, []);

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
    <Modal
      role="alertdialog"
      onClose={busy ? undefined : onClose}
      title={title}
      width={440}
      footer={(
        <>
          <Button ref={cancelRef} onClick={onClose} disabled={busy}>{cancelLabel}</Button>
          <Button variant={cfg.variant} onClick={handleConfirm} disabled={busy}>
            {busy ? 'Working…' : (confirmLabel || cfg.label)}
          </Button>
        </>
      )}
    >
      <p id="mf-confirm-message" style={{ fontSize: '13.5px', color: 'var(--admin-text-sub)', lineHeight: 1.55, margin: 0 }}>
        {message}
      </p>
    </Modal>
  );
};

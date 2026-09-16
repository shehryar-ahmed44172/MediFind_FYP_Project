/* Non-component style helpers shared by admin pages (kept out of ui.jsx so
   Vite fast-refresh keeps working for the component module). */

/* Badge / notice tones. `dot` is the saturated status colour; text uses the
   AA-contrast foreground token for the current theme. Red is reserved for
   SOS, critical and destructive states. */
export const BADGE_TONES = {
  neutral: { bg: 'var(--surface-alt)',   fg: 'var(--admin-text-sub)', border: 'var(--border)',         dot: 'var(--text-muted)' },
  info:    { bg: 'var(--ui-accent-tint)', fg: 'var(--ui-accent)',     border: 'var(--info-border)',    dot: 'var(--ui-accent)' },
  accent:  { bg: 'var(--ui-accent-tint)', fg: 'var(--ui-accent)',     border: 'var(--info-border)',    dot: 'var(--ui-accent)' },
  success: { bg: 'var(--success-bg)',     fg: 'var(--success-fg)',    border: 'var(--success-border)', dot: 'var(--success)' },
  warning: { bg: 'var(--warning-bg)',     fg: 'var(--warning-fg)',    border: 'var(--warning-border)', dot: 'var(--warning)' },
  danger:  { bg: 'var(--error-bg)',       fg: 'var(--error-fg)',      border: 'var(--error-border)',   dot: 'var(--sos)' },
};

/* Common status → tone mapping used across emergencies, subscriptions,
   verification and delivery logs. Unknown values fall back to neutral. */
export const STATUS_TONE = {
  ACTIVE: 'danger', CRITICAL: 'danger', FAILED: 'danger', REJECTED: 'danger', DOWN: 'danger', ERROR: 'danger', SOS: 'danger',
  PENDING: 'warning', ASSIGNED: 'info', ACCEPTED: 'info', ARRIVED: 'info', EN_ROUTE: 'info', IN_PROGRESS: 'info', WARNING: 'warning', DEGRADED: 'warning', EXPIRED: 'neutral',
  RESOLVED: 'success', COMPLETED: 'success', VERIFIED: 'success', DELIVERED: 'success', SENT: 'success', PAID: 'success', HEALTHY: 'success', SUCCESS: 'success',
  CANCELLED: 'neutral', INACTIVE: 'neutral', FREE: 'neutral', INFO: 'info',
};
export const toneFor = (status) => STATUS_TONE[String(status || '').toUpperCase()] || 'neutral';

/* Human label from an ENUM_VALUE ("EN_ROUTE" → "En route") */
export const humanize = (v) => {
  if (v == null || v === '') return '—';
  const s = String(v).replace(/_/g, ' ').toLowerCase();
  return s.charAt(0).toUpperCase() + s.slice(1);
};

/* Table header / cell inline styles for tables that don't use .mf-table */
export const thStyle = {
  height: '36px', padding: '0 16px', textAlign: 'left', fontSize: '11.5px', fontWeight: 500,
  color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em',
  background: 'var(--table-head-bg)', borderBottom: '1px solid var(--border)', whiteSpace: 'nowrap',
  position: 'sticky', top: 0, zIndex: 1,
};
export const tdStyle = {
  height: '46px', padding: '6px 16px', fontSize: '13px', color: 'var(--admin-text-sub)',
  borderBottom: '1px solid var(--border)', verticalAlign: 'middle',
};

/* Clamp the requested page into range and return that page's rows. Clamping
   here means pages never need an effect to "reset" after the data shrinks. */
export const paginate = (items, page, pageSize) => {
  const pageCount = Math.max(1, Math.ceil(items.length / pageSize));
  const current = Math.min(Math.max(1, page), pageCount);
  return { page: current, pageCount, rows: items.slice((current - 1) * pageSize, current * pageSize) };
};

/* CSS text of the light-theme token rule (":root, [data-theme=\"light\"]").
   Injected into print windows so var(--…) colours resolve outside the app. */
export const lightTokenCss = () => {
  try {
    for (const sheet of Array.from(document.styleSheets)) {
      for (const rule of Array.from(sheet.cssRules || [])) {
        if (rule.selectorText && rule.selectorText.startsWith(':root')) return rule.cssText;
      }
    }
  } catch { /* cross-origin sheet — ignore */ }
  return '';
};

/* Recharts writes colours as SVG attributes, so charts need literal values
   that match the tokens for the current theme. */
export const chartColors = (isDark) => ({
  grid: isDark ? '#243044' : '#EEF2F6',
  axis: isDark ? '#94A3B8' : '#64748B',
  primary: isDark ? '#5CB8DC' : '#0C637E',
  secondary: isDark ? '#7DD3C0' : '#2496A7',
  success: '#10B981',
  sos: '#EF4444',
  muted: isDark ? '#475569' : '#CBD5E1',
  cursor: isDark ? 'rgba(148,163,184,0.08)' : 'rgba(15,23,42,0.04)',
});

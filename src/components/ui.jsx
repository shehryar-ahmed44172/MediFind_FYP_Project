import React, { useCallback, useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, RefreshCw, Inbox, Search, X, AlertTriangle, Info, CheckCircle2, AlertCircle } from 'lucide-react';
import { BADGE_TONES } from './uiStyles';

/* Shared admin UI building blocks.
   Visual rules: neutral surfaces, 1px borders, 8px controls / 12px panels,
   shadows only on overlays, accent colour only for primary actions & focus,
   red only for SOS / destructive. Interactive states live in index.css
   (.mf-btn, .mf-icon-btn, .mf-input, .mf-seg, .mf-table …). */

const cx = (...parts) => parts.filter(Boolean).join(' ');

/* ── Page header: title + description on the left, actions on the right ── */
export function PageHeader({ title, subtitle, description, actions, badge, meta }) {
  const text = description ?? subtitle;
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start',
      gap: '12px 24px', flexWrap: 'wrap', marginBottom: '20px',
    }}>
      <div style={{ minWidth: 0, flex: '1 1 320px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          <h1 style={{ fontSize: '20px', lineHeight: '28px', fontWeight: 600, color: 'var(--text-main)', letterSpacing: '-0.015em', margin: 0 }}>
            {title}
          </h1>
          {badge}
        </div>
        {text && (
          <p style={{ color: 'var(--text-muted)', fontSize: '13.5px', lineHeight: '20px', margin: '2px 0 0', maxWidth: '760px' }}>{text}</p>
        )}
        {meta && <div style={{ marginTop: '6px' }}>{meta}</div>}
      </div>
      {actions && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
          {actions}
        </div>
      )}
    </div>
  );
}

/* ── Buttons ───────────────────────────────────────────────────────────── */
const BUTTON_VARIANTS = {
  primary: 'mf-btn--primary',
  secondary: 'mf-btn--secondary',
  ghost: 'mf-btn--ghost',
  danger: 'mf-btn--danger',
  'danger-outline': 'mf-btn--danger-outline',
};

export function Button({ variant = 'secondary', size = 'md', icon, children, className, type = 'button', ...rest }) {
  const Glyph = icon;
  return (
    <button
      type={type}
      className={cx('mf-btn', BUTTON_VARIANTS[variant] || BUTTON_VARIANTS.secondary, size !== 'md' && `mf-btn--${size}`, className)}
      {...rest}
    >
      {Glyph && <Glyph size={size === 'sm' ? 14 : 15} aria-hidden="true" />}
      {children}
    </button>
  );
}

export function RefreshButton({ onClick, loading, label = 'Refresh', iconOnly = false }) {
  if (iconOnly) {
    return (
      <IconButton label={label} onClick={onClick} disabled={loading} variant="outline" size="md"
        icon={(p) => <RefreshCw {...p} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} />} />
    );
  }
  return (
    <Button onClick={onClick} disabled={loading} aria-label={label}>
      <RefreshCw size={14} aria-hidden="true" style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} />
      {label}
    </Button>
  );
}

/* ── Tooltip (portal, so table overflow never clips it) ────────────────── */
export function Tooltip({ content, children, side = 'top' }) {
  const [pos, setPos] = useState(null);
  const ref = useRef(null);
  const id = useId();

  const show = useCallback(() => {
    const el = ref.current;
    if (!el || !content) return;
    const r = el.getBoundingClientRect();
    setPos(side === 'bottom'
      ? { top: r.bottom + 6, left: r.left + r.width / 2, transform: 'translateX(-50%)' }
      : side === 'right'
        ? { top: r.top + r.height / 2, left: r.right + 8, transform: 'translateY(-50%)' }
        : { top: r.top - 6, left: r.left + r.width / 2, transform: 'translate(-50%, -100%)' });
  }, [content, side]);
  const hide = useCallback(() => setPos(null), []);

  useEffect(() => {
    if (!pos) return undefined;
    window.addEventListener('scroll', hide, true);
    return () => window.removeEventListener('scroll', hide, true);
  }, [pos, hide]);

  return (
    <span
      ref={ref}
      style={{ display: 'inline-flex' }}
      onMouseEnter={show} onMouseLeave={hide} onFocus={show} onBlur={hide}
      aria-describedby={pos ? id : undefined}
    >
      {children}
      {pos && createPortal(
        <span id={id} role="tooltip" className="mf-tooltip" style={pos}>{content}</span>,
        document.body,
      )}
    </span>
  );
}

/* ── Icon button with tooltip ──────────────────────────────────────────── */
export function IconButton({
  label, icon, onClick, tone = 'default', variant = 'ghost', size = 'sm', active = false,
  tooltip = true, as: As = 'button', className, iconSize, ...rest
}) {
  const Glyph = icon;
  const btn = (
    <As
      {...(As === 'button' ? { type: 'button' } : {})}
      aria-label={label}
      onClick={onClick}
      className={cx(
        'mf-icon-btn',
        size === 'md' && 'mf-icon-btn--md',
        variant === 'outline' && 'mf-icon-btn--outline',
        tone === 'danger' && 'mf-icon-btn--danger',
        active && 'mf-icon-btn--active',
        className,
      )}
      {...rest}
    >
      <Glyph size={iconSize || (size === 'md' ? 16 : 15)} aria-hidden="true" />
    </As>
  );
  return tooltip ? <Tooltip content={label}>{btn}</Tooltip> : btn;
}

/* ── Panels ────────────────────────────────────────────────────────────── */
export function Card({ children, style, className, ...rest }) {
  return (
    <div
      className={className}
      style={{
        background: 'var(--surface)', borderRadius: 'var(--radius-panel, 12px)',
        border: '1px solid var(--border)', overflow: 'hidden', ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

export function PanelHeader({ title, description, actions, icon, style }) {
  const Glyph = icon;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px',
      padding: '12px 16px', minHeight: '52px', borderBottom: '1px solid var(--border)', ...style,
    }}>
      <div style={{ minWidth: 0 }}>
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px', lineHeight: '20px', fontWeight: 600, color: 'var(--text-main)', margin: 0 }}>
          {Glyph && <Glyph size={15} aria-hidden="true" style={{ color: 'var(--text-muted)' }} />}
          {title}
        </h2>
        {description && <p style={{ fontSize: '12.5px', lineHeight: '18px', color: 'var(--text-muted)', margin: 0 }}>{description}</p>}
      </div>
      {actions && <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>{actions}</div>}
    </div>
  );
}

export function Panel({ title, description, actions, icon, children, footer, padded = false, style, bodyStyle, headerStyle, ...rest }) {
  return (
    <Card style={{ display: 'flex', flexDirection: 'column', ...style }} {...rest}>
      {(title || actions) && <PanelHeader title={title} description={description} actions={actions} icon={icon} style={headerStyle} />}
      <div style={{ flex: 1, minHeight: 0, ...(padded ? { padding: '16px' } : null), ...bodyStyle }}>{children}</div>
      {footer && (
        <div style={{ padding: '10px 16px', borderTop: '1px solid var(--border)', fontSize: '12.5px', color: 'var(--text-muted)' }}>
          {footer}
        </div>
      )}
    </Card>
  );
}

/* ── KPI stat card ─────────────────────────────────────────────────────── */
export function StatCard({ label, value, hint, delta, deltaTone = 'neutral', loading, unavailable, onClick, live, format = true }) {
  const interactive = !!onClick && !loading;
  const deltaColor = { up: 'var(--success-fg)', down: 'var(--error-fg)', danger: 'var(--error-fg)', neutral: 'var(--text-muted)' }[deltaTone] || 'var(--text-muted)';
  const shown = typeof value === 'number' && format ? value.toLocaleString() : (value ?? '—');
  return (
    <div
      role={interactive ? 'link' : undefined}
      tabIndex={interactive ? 0 : undefined}
      onClick={interactive ? onClick : undefined}
      onKeyDown={interactive ? (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(); } } : undefined}
      className={interactive ? 'mf-row-hover' : undefined}
      style={{
        background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--radius-panel, 12px)',
        padding: '14px 16px', cursor: interactive ? 'pointer' : 'default', minWidth: 0,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
        <p style={{ fontSize: '12.5px', fontWeight: 500, color: 'var(--text-muted)', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</p>
        {live && <LiveIndicator label={typeof live === 'string' ? live : 'Live'} tone={live === true || typeof live === 'string' ? 'danger' : 'neutral'} />}
      </div>
      {loading ? (
        <>
          <Skeleton h={26} w="45%" style={{ margin: '8px 0 6px' }} />
          <Skeleton h={11} w="60%" />
        </>
      ) : unavailable ? (
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: '10px 0 0' }}>Unavailable</p>
      ) : (
        <>
          <p className="mf-num" style={{ fontSize: '26px', lineHeight: '34px', fontWeight: 600, color: 'var(--text-main)', letterSpacing: '-0.02em', margin: '4px 0 2px' }}>
            {shown}
          </p>
          <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {delta != null && <span className="mf-num" style={{ color: deltaColor, fontWeight: 500, marginRight: hint ? '6px' : 0 }}>{delta}</span>}
            {hint}
          </p>
        </>
      )}
    </div>
  );
}

/* ── Status badge (pill with dot) ──────────────────────────────────────── */
export function StatusBadge({ tone = 'neutral', children, dot = true, icon, title, style }) {
  const t = BADGE_TONES[tone] || BADGE_TONES.neutral;
  const Glyph = icon;
  return (
    <span title={title} style={{
      display: 'inline-flex', alignItems: 'center', gap: '6px', height: '22px', padding: '0 8px',
      borderRadius: '999px', fontSize: '12px', fontWeight: 500, lineHeight: 1, whiteSpace: 'nowrap',
      background: t.bg, color: t.fg, border: `1px solid ${t.border}`, ...style,
    }}>
      {Glyph ? <Glyph size={12} aria-hidden="true" /> : dot && <span aria-hidden="true" style={{ width: '6px', height: '6px', borderRadius: '50%', background: t.dot, flexShrink: 0 }} />}
      {children}
    </span>
  );
}

export function LiveIndicator({ label = 'Live', tone = 'success' }) {
  const t = BADGE_TONES[tone] || BADGE_TONES.success;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '12px', fontWeight: 500, color: t.fg, whiteSpace: 'nowrap' }}>
      <span className="mf-live-dot" aria-hidden="true" style={{ width: '6px', height: '6px', borderRadius: '50%', background: t.dot }} />
      {label}
    </span>
  );
}

/* ── Avatar (neutral initials, or image) ───────────────────────────────── */
export function Avatar({ name, src, size = 28 }) {
  const initial = (name?.trim()?.[0] || '?').toUpperCase();
  return (
    <span aria-hidden="true" style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0, overflow: 'hidden',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      background: 'var(--surface-alt)', border: '1px solid var(--border)', color: 'var(--admin-text-sub)',
      fontSize: Math.round(size * 0.42), fontWeight: 600,
    }}>
      {src ? <img src={src} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initial}
    </span>
  );
}

/* ── Skeletons ─────────────────────────────────────────────────────────── */
export function Skeleton({ h = 14, w = '100%', mb = 0, br = 6, style }) {
  return <div className="mf-skeleton" aria-hidden="true" style={{ height: h, width: w, borderRadius: br, marginBottom: mb, ...style }} />;
}

export function TableSkeletonRows({ rows = 5, cols = 5 }) {
  return Array.from({ length: rows }, (_, i) => (
    <tr key={i}>
      {Array.from({ length: cols }, (__, j) => (
        <td key={j} style={{ padding: '6px 16px', height: '46px', borderBottom: '1px solid var(--border)' }}>
          <Skeleton h={10} w={j === 0 ? '65%' : j === cols - 1 ? '35%' : '50%'} />
        </td>
      ))}
    </tr>
  ));
}

/* ── Table container: scroll wrapper + .mf-table (sticky header) ───────── */
export function DataTable({ children, minWidth, maxHeight, style, tableStyle, ...rest }) {
  return (
    <div className="mf-table-scroll" style={{ ...(maxHeight ? { maxHeight, overflowY: 'auto' } : null), ...style }}>
      <table className="mf-table" style={{ minWidth, ...tableStyle }} {...rest}>
        {children}
      </table>
    </div>
  );
}

/* ── Empty state ───────────────────────────────────────────────────────── */
export function EmptyState({ icon = Inbox, title, message, action, compact = false }) {
  const Glyph = icon;
  return (
    <div style={{ padding: compact ? '28px 16px' : '48px 24px', textAlign: 'center', color: 'var(--text-muted)' }}>
      <Glyph size={compact ? 18 : 22} aria-hidden="true" style={{ color: 'var(--text-muted)', opacity: 0.7, marginBottom: '8px' }} />
      {title && <p style={{ fontWeight: 600, fontSize: '13.5px', color: 'var(--text-main)', margin: '0 0 2px' }}>{title}</p>}
      {message && <p style={{ fontSize: '13px', margin: 0 }}>{message}</p>}
      {action && <div style={{ marginTop: '12px', display: 'flex', justifyContent: 'center' }}>{action}</div>}
    </div>
  );
}

/* ── Notices ───────────────────────────────────────────────────────────── */
const NOTICE_ICONS = { danger: AlertCircle, warning: AlertTriangle, info: Info, success: CheckCircle2, neutral: Info };

export function Notice({ tone = 'info', children, action, style, inline = false, role }) {
  const t = BADGE_TONES[tone] || BADGE_TONES.info;
  const Glyph = NOTICE_ICONS[tone] || Info;
  return (
    <div role={role || (tone === 'danger' ? 'alert' : undefined)} style={{
      display: 'flex', alignItems: 'center', gap: '10px', padding: '9px 12px',
      background: inline ? 'transparent' : t.bg, border: inline ? 'none' : `1px solid ${t.border}`,
      borderRadius: inline ? 0 : 'var(--radius-control, 8px)', color: t.fg, fontSize: '13px', ...style,
    }}>
      <Glyph size={15} aria-hidden="true" style={{ flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>{children}</div>
      {action && <div style={{ flexShrink: 0 }}>{action}</div>}
    </div>
  );
}

export function ErrorBanner({ children, onRetry }) {
  if (!children) return null;
  return (
    <div className="mf-error-banner">
      <Notice tone="danger" action={onRetry && <Button size="sm" variant="secondary" onClick={onRetry}>Retry</Button>}>
        {children}
      </Notice>
    </div>
  );
}

/* ── Pagination footer ─────────────────────────────────────────────────── */
function pageList(current, total) {
  // Compact list with ellipses: 1 … 4 5 6 … 20
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const pages = new Set([1, total, current, current - 1, current + 1]);
  const sorted = [...pages].filter(p => p >= 1 && p <= total).sort((a, b) => a - b);
  const out = [];
  sorted.forEach((p, i) => {
    if (i > 0 && p - sorted[i - 1] > 1) out.push(`gap-${p}`);
    out.push(p);
  });
  return out;
}

export function Pagination({ page, pageSize, total, onChange, loading, noun }) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(page, pageCount);
  const from = total === 0 ? 0 : (safePage - 1) * pageSize + 1;
  const to = Math.min(safePage * pageSize, total);

  const btn = (active) => ({
    minWidth: '28px', width: 'auto', height: '28px', padding: '0 6px', fontSize: '12.5px', fontWeight: 500,
    fontFamily: 'inherit', color: active ? 'var(--text-main)' : 'var(--text-muted)',
    background: active ? 'var(--surface-alt)' : 'transparent',
    borderColor: active ? 'var(--border)' : 'transparent',
  });

  return (
    <div style={{
      padding: '8px 16px', minHeight: '44px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      borderTop: '1px solid var(--border)', flexWrap: 'wrap', gap: '8px',
    }}>
      <span className="mf-num" style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
        {loading ? 'Loading…' : total === 0 ? 'No results' : `${from}–${to} of ${total.toLocaleString()}${noun ? ` ${noun}` : ''}`}
      </span>
      {pageCount > 1 && !loading && (
        <nav aria-label="Pagination" style={{ display: 'flex', alignItems: 'center', gap: '2px' }}>
          <button type="button" className="mf-icon-btn" aria-label="Previous page" disabled={safePage === 1} onClick={() => onChange(safePage - 1)}>
            <ChevronLeft size={15} />
          </button>
          {pageList(safePage, pageCount).map(p => (
            typeof p === 'string'
              ? <span key={p} style={{ color: 'var(--text-muted)', padding: '0 4px', fontSize: '12.5px' }}>…</span>
              : (
                <button key={p} type="button" className="mf-icon-btn mf-num" aria-label={`Page ${p}`} aria-current={p === safePage ? 'page' : undefined} onClick={() => onChange(p)} style={btn(p === safePage)}>
                  {p}
                </button>
              )
          ))}
          <button type="button" className="mf-icon-btn" aria-label="Next page" disabled={safePage === pageCount} onClick={() => onChange(safePage + 1)}>
            <ChevronRight size={15} />
          </button>
        </nav>
      )}
    </div>
  );
}

/* ── Filters ───────────────────────────────────────────────────────────── */
/* Segmented control: options = [{ value, label, count? }] */
export function SegmentedControl({ options, value, onChange, ariaLabel = 'Filter' }) {
  return (
    <div className="mf-seg" role="group" aria-label={ariaLabel}>
      {options.map(o => (
        <button key={o.value} type="button" className="mf-seg__btn" aria-pressed={o.value === value} onClick={() => onChange(o.value)}>
          {o.dot && <span aria-hidden="true" style={{ width: '6px', height: '6px', borderRadius: '50%', background: o.dot }} />}
          {o.label}
          {o.count != null && <span className="mf-seg__count">{o.count}</span>}
        </button>
      ))}
    </div>
  );
}

/* Standalone filter chip (for pages that build their own groups). A legacy
   `color` prop is ignored on purpose — filters stay neutral. */
export function FilterPill({ active, onClick, children, count }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className="mf-seg__btn"
      style={{ border: `1px solid ${active ? 'var(--border-strong)' : 'var(--border)'}`, background: active ? 'var(--surface-alt)' : 'var(--surface)', color: active ? 'var(--text-main)' : 'var(--text-muted)' }}
    >
      {children}
      {count != null && <span className="mf-seg__count">{count}</span>}
    </button>
  );
}

/* Toolbar row for search + filters (inside a Panel, above a table) */
export function Toolbar({ children, right, style }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px 12px', flexWrap: 'wrap',
      padding: '10px 16px', borderBottom: '1px solid var(--border)', ...style,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap', minWidth: 0, flex: '1 1 auto' }}>{children}</div>
      {right && <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>{right}</div>}
    </div>
  );
}

/* ── Search input ──────────────────────────────────────────────────────── */
export function SearchInput({ value, onChange, placeholder = 'Search…', width = 260, icon = Search, style, ...rest }) {
  const Glyph = icon;
  return (
    <div style={{ position: 'relative', width, maxWidth: '100%', ...style }}>
      {Glyph && <Glyph size={14} aria-hidden="true" style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' }} />}
      <input
        type="search"
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        className={cx('mf-input', Glyph && 'mf-input--with-icon')}
        style={{ height: '32px' }}
        {...rest}
      />
    </div>
  );
}

/* ── Forms ─────────────────────────────────────────────────────────────── */
/* A settings section: heading + description in the left column, fields right */
export function FormSection({ title, description, children, actions, id }) {
  return (
    <Card id={id} style={{ overflow: 'visible' }}>
      <div className="mf-form-row" style={{ padding: '20px' }}>
        <div>
          <h2 style={{ fontSize: '14px', lineHeight: '20px', fontWeight: 600, color: 'var(--text-main)', margin: 0 }}>{title}</h2>
          {description && <p style={{ fontSize: '13px', lineHeight: '19px', color: 'var(--text-muted)', margin: '4px 0 0' }}>{description}</p>}
          {actions && <div style={{ marginTop: '10px' }}>{actions}</div>}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', minWidth: 0 }}>{children}</div>
      </div>
    </Card>
  );
}

export function FormField({ label, htmlFor, help, error, children, inline = false, right }) {
  return (
    <div style={inline ? { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '16px' } : undefined}>
      <div style={{ minWidth: 0 }}>
        {label && (
          <label htmlFor={htmlFor} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', fontSize: '13px', fontWeight: 500, color: 'var(--text-main)', marginBottom: inline ? 0 : '6px' }}>
            <span>{label}</span>{right}
          </label>
        )}
        {inline && help && <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '2px 0 0' }}>{help}</p>}
      </div>
      {children}
      {!inline && help && !error && <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '6px 0 0' }}>{help}</p>}
      {error && <p role="alert" style={{ fontSize: '12.5px', color: 'var(--error-fg)', margin: '6px 0 0' }}>{error}</p>}
    </div>
  );
}

export const Input = React.forwardRef(function Input({ className, ...rest }, ref) {
  return <input ref={ref} className={cx('mf-input', className)} {...rest} />;
});
export const Select = React.forwardRef(function Select({ className, children, ...rest }, ref) {
  return <select ref={ref} className={cx('mf-input', className)} {...rest}>{children}</select>;
});
export const Textarea = React.forwardRef(function Textarea({ className, ...rest }, ref) {
  return <textarea ref={ref} className={cx('mf-input', className)} {...rest} />;
});

/* Toggle switch (role=switch) */
export function Switch({ checked, onChange, label, disabled, id }) {
  return (
    <button
      id={id}
      type="button"
      role="switch"
      aria-checked={!!checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      style={{
        position: 'relative', width: '34px', height: '20px', borderRadius: '999px', flexShrink: 0, padding: 0,
        border: 'none', background: checked ? 'var(--ui-accent-solid)' : 'var(--border-strong)',
        transition: 'background-color 120ms', opacity: disabled ? 0.5 : 1,
      }}
    >
      <span aria-hidden="true" style={{
        position: 'absolute', top: '2px', left: checked ? '16px' : '2px', width: '16px', height: '16px',
        borderRadius: '50%', background: '#fff', boxShadow: '0 1px 2px rgba(15,23,42,0.25)', transition: 'left 120ms',
      }} />
    </button>
  );
}

/* Save bar that sticks to the bottom of the viewport while a form is dirty */
export function StickySaveBar({ visible, saving, onSave, onDiscard, message = 'You have unsaved changes', saveLabel = 'Save changes' }) {
  if (!visible) return null;
  return (
    <div className="mf-pop" role="region" aria-label="Unsaved changes" style={{
      position: 'sticky', bottom: '16px', zIndex: 50, marginTop: '16px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap',
      padding: '10px 12px 10px 16px', background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 'var(--radius-panel, 12px)', boxShadow: 'var(--shadow-overlay)',
    }}>
      <span style={{ fontSize: '13px', color: 'var(--admin-text-sub)' }}>{message}</span>
      <div style={{ display: 'flex', gap: '8px' }}>
        {onDiscard && <Button variant="ghost" onClick={onDiscard} disabled={saving}>Discard</Button>}
        <Button variant="primary" onClick={onSave} disabled={saving}>{saving ? 'Saving…' : saveLabel}</Button>
      </div>
    </div>
  );
}

/* ── Overlays: Modal and Drawer ────────────────────────────────────────── */
function useEscape(onClose) {
  useEffect(() => {
    if (!onClose) return undefined;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
}

const OVERLAY_BACKDROP = { position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.45)' };

function OverlayHeader({ title, description, onClose, titleId, extra }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '12px', padding: '14px 16px 14px 20px', borderBottom: '1px solid var(--border)' }}>
      <div style={{ minWidth: 0 }}>
        <h2 id={titleId} style={{ fontSize: '15px', lineHeight: '22px', fontWeight: 600, color: 'var(--text-main)', margin: 0 }}>{title}</h2>
        {description && <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: '2px 0 0' }}>{description}</p>}
        {extra}
      </div>
      {onClose && <IconButton label="Close" icon={X} onClick={onClose} tooltip={false} />}
    </div>
  );
}

export function Modal({ onClose, title, description, children, footer, width = 520, role = 'dialog', zIndex = 10500, bodyStyle }) {
  const titleId = useId();
  useEscape(onClose);
  return createPortal(
    <div className="mf-fade" style={{ ...OVERLAY_BACKDROP, zIndex, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }} onMouseDown={e => { if (e.target === e.currentTarget) onClose?.(); }}>
      <div role={role} aria-modal="true" aria-labelledby={titleId} className="mf-pop" style={{
        width: '100%', maxWidth: width, maxHeight: 'calc(100vh - 32px)', display: 'flex', flexDirection: 'column',
        background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--radius-panel, 12px)', boxShadow: 'var(--shadow-lg)',
      }}>
        {title && <OverlayHeader title={title} description={description} onClose={onClose} titleId={titleId} />}
        <div style={{ padding: '16px 20px', overflowY: 'auto', flex: 1, ...bodyStyle }}>{children}</div>
        {footer && (
          <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '8px', padding: '12px 20px', borderTop: '1px solid var(--border)' }}>
            {footer}
          </div>
        )}
      </div>
    </div>,
    document.body,
  );
}

/* Side drawer; `centered` shows the same panel as a dialog in the middle of the screen */
export function Drawer({ onClose, title, description, headerExtra, children, footer, width = 560, zIndex = 10400, centered = false }) {
  const titleId = useId();
  useEscape(onClose);
  const w = typeof width === 'number' ? `${width}px` : width;
  const panelStyle = centered
    ? {
        position: 'relative', width: `min(${w}, calc(100vw - 32px))`, maxHeight: 'calc(100vh - 48px)',
        display: 'flex', flexDirection: 'column', background: 'var(--surface)', border: '1px solid var(--border)',
        borderRadius: 'var(--radius-panel, 12px)', boxShadow: 'var(--shadow-lg)', overflow: 'hidden',
      }
    : {
        position: 'absolute', top: 0, right: 0, bottom: 0, width: `min(${w}, 100vw)`,
        display: 'flex', flexDirection: 'column', background: 'var(--surface)', borderLeft: '1px solid var(--border)', boxShadow: 'var(--shadow-lg)',
      };
  return createPortal(
    <div style={{ position: 'fixed', inset: 0, zIndex, ...(centered ? { display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px 16px' } : null) }}>
      <div className="mf-fade" style={OVERLAY_BACKDROP} onClick={onClose} />
      <aside role="dialog" aria-modal="true" aria-labelledby={titleId} className={centered ? 'mf-pop' : 'mf-drawer'} style={panelStyle}>
        <OverlayHeader title={title} description={description} onClose={onClose} titleId={titleId} extra={headerExtra} />
        <div style={{ flex: 1, overflowY: 'auto' }}>{children}</div>
        {footer && (
          <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '8px', padding: '12px 20px', borderTop: '1px solid var(--border)' }}>
            {footer}
          </div>
        )}
      </aside>
    </div>,
    document.body,
  );
}

/* Label / value pair for detail views */
export function DetailItem({ label, children }) {
  return (
    <div style={{ minWidth: 0 }}>
      <dt style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '2px' }}>{label}</dt>
      <dd style={{ fontSize: '13.5px', color: 'var(--text-main)', margin: 0, wordBreak: 'break-word' }}>{children ?? '—'}</dd>
    </div>
  );
}

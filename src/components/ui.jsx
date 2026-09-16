import React from 'react';
import { ChevronLeft, ChevronRight, RefreshCw, Inbox } from 'lucide-react';

/* Shared admin UI building blocks. Styling uses CSS tokens from index.css so
   every page renders consistently in both light and dark mode. */

/* ── Page header: title + subtitle on the left, actions on the right ────── */
export function PageHeader({ title, subtitle, actions, badge }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end',
      gap: '16px', flexWrap: 'wrap', marginBottom: '24px',
    }}>
      <div style={{ minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', marginBottom: '4px' }}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--admin-text-main)', letterSpacing: '-0.02em', margin: 0 }}>
            {title}
          </h1>
          {badge}
        </div>
        {subtitle && (
          <p style={{ color: 'var(--admin-text-muted)', fontSize: '0.92rem', margin: 0 }}>{subtitle}</p>
        )}
      </div>
      {actions && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
          {actions}
        </div>
      )}
    </div>
  );
}

/* ── Buttons ───────────────────────────────────────────────────────────── */
const BTN_BASE = {
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: '7px',
  padding: '9px 16px', borderRadius: '10px', fontWeight: 700, fontSize: '0.85rem',
  fontFamily: 'inherit', cursor: 'pointer', transition: 'background 0.15s, border-color 0.15s, opacity 0.15s',
  whiteSpace: 'nowrap',
};

export function Button({ variant = 'secondary', children, style, disabled, ...rest }) {
  const variants = {
    primary:   { background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))', color: 'white', border: 'none', boxShadow: '0 4px 12px rgba(12,99,126,0.22)' },
    secondary: { background: 'var(--surface)', color: 'var(--admin-text-sub)', border: '1.5px solid var(--admin-border)' },
    danger:    { background: 'var(--tint-red)', color: 'var(--error)', border: '1px solid var(--error-border)' },
    ghost:     { background: 'transparent', color: 'var(--admin-text-sub)', border: '1px solid transparent' },
  };
  return (
    <button
      type="button"
      disabled={disabled}
      style={{ ...BTN_BASE, ...variants[variant], opacity: disabled ? 0.6 : 1, cursor: disabled ? 'not-allowed' : 'pointer', ...style }}
      {...rest}
    >
      {children}
    </button>
  );
}

export function RefreshButton({ onClick, loading, label = 'Refresh' }) {
  return (
    <Button onClick={onClick} disabled={loading} aria-label={label} title={label}>
      <RefreshCw size={15} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} />
      {label}
    </Button>
  );
}

/* ── Card container ────────────────────────────────────────────────────── */
export function Card({ children, style, ...rest }) {
  return (
    <div
      style={{
        background: 'var(--surface)', borderRadius: '16px',
        border: '1px solid var(--admin-border)', boxShadow: '0 1px 4px rgba(12,99,126,0.05)',
        overflow: 'hidden', ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

/* ── Skeleton shimmer bar ──────────────────────────────────────────────── */
export function Skeleton({ h = 14, w = '100%', mb = 0, br = 6, style }) {
  return <div className="mf-skeleton" aria-hidden="true" style={{ height: h, width: w, borderRadius: br, marginBottom: mb, ...style }} />;
}

export function TableSkeletonRows({ rows = 5, cols = 5 }) {
  return Array.from({ length: rows }, (_, i) => (
    <tr key={i} style={{ borderBottom: '1px solid var(--admin-border)' }}>
      {Array.from({ length: cols }, (__, j) => (
        <td key={j} style={{ padding: '16px 20px' }}>
          <Skeleton h={13} w={j === 0 ? '70%' : j === cols - 1 ? '40%' : '55%'} />
        </td>
      ))}
    </tr>
  ));
}

/* ── Empty state ───────────────────────────────────────────────────────── */
export function EmptyState({ icon = Inbox, title, message, action, compact = false }) {
  const Glyph = icon;
  return (
    <div style={{ padding: compact ? '32px 20px' : '56px 24px', textAlign: 'center', color: 'var(--admin-text-muted)' }}>
      <div style={{
        width: compact ? 44 : 56, height: compact ? 44 : 56, borderRadius: '16px',
        background: 'var(--tint-slate)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        margin: '0 auto 14px',
      }}>
        <Glyph size={compact ? 20 : 26} style={{ opacity: 0.6 }} />
      </div>
      {title && <p style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--admin-text-sub)', marginBottom: '4px' }}>{title}</p>}
      {message && <p style={{ fontSize: '0.85rem', margin: 0 }}>{message}</p>}
      {action && <div style={{ marginTop: '16px' }}>{action}</div>}
    </div>
  );
}

/* ── Inline error banner ───────────────────────────────────────────────── */
export function ErrorBanner({ children, onRetry }) {
  if (!children) return null;
  return (
    <div role="alert" style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px',
      padding: '12px 16px', background: 'var(--error-bg)', border: '1px solid var(--error-border)',
      borderRadius: '12px', color: 'var(--error-fg)', fontSize: '0.875rem', fontWeight: 600, marginBottom: '16px',
    }}>
      <span>{children}</span>
      {onRetry && (
        <button type="button" onClick={onRetry} style={{ background: 'none', border: '1px solid var(--error-border)', color: 'var(--error-fg)', borderRadius: '8px', padding: '4px 10px', fontWeight: 700, fontSize: '0.78rem', fontFamily: 'inherit' }}>
          Retry
        </button>
      )}
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

export function Pagination({ page, pageSize, total, onChange, loading }) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(page, pageCount);
  const from = total === 0 ? 0 : (safePage - 1) * pageSize + 1;
  const to = Math.min(safePage * pageSize, total);

  const btn = (active, disabled) => ({
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    minWidth: '32px', height: '32px', padding: '0 6px', borderRadius: '8px',
    border: `1.5px solid ${active ? 'var(--admin-accent)' : 'var(--admin-border)'}`,
    background: active ? 'var(--admin-accent)' : 'var(--surface)',
    color: active ? 'white' : 'var(--admin-text-sub)',
    fontWeight: active ? 700 : 600, fontSize: '0.82rem', fontFamily: 'inherit',
    cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.45 : 1,
  });

  return (
    <div style={{
      padding: '12px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      background: 'var(--table-head-bg)', borderTop: '1px solid var(--admin-border)', flexWrap: 'wrap', gap: '12px',
    }}>
      <span style={{ fontSize: '0.82rem', color: 'var(--admin-text-muted)' }}>
        {loading ? 'Loading…' : total === 0 ? 'No entries' : `Showing ${from}–${to} of ${total}`}
      </span>
      {pageCount > 1 && !loading && (
        <nav aria-label="Pagination" style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <button type="button" aria-label="Previous page" disabled={safePage === 1} onClick={() => onChange(safePage - 1)} style={btn(false, safePage === 1)}>
            <ChevronLeft size={16} />
          </button>
          {pageList(safePage, pageCount).map(p => (
            typeof p === 'string'
              ? <span key={p} style={{ color: 'var(--admin-text-muted)', padding: '0 4px' }}>…</span>
              : (
                <button key={p} type="button" aria-label={`Page ${p}`} aria-current={p === safePage ? 'page' : undefined} onClick={() => onChange(p)} style={btn(p === safePage, false)}>
                  {p}
                </button>
              )
          ))}
          <button type="button" aria-label="Next page" disabled={safePage === pageCount} onClick={() => onChange(safePage + 1)} style={btn(false, safePage === pageCount)}>
            <ChevronRight size={16} />
          </button>
        </nav>
      )}
    </div>
  );
}

/* ── Filter pill ───────────────────────────────────────────────────────── */
export function FilterPill({ active, onClick, children, color }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      style={{
        padding: '5px 12px', borderRadius: '999px', fontFamily: 'inherit',
        fontSize: '0.76rem', fontWeight: 700, cursor: 'pointer', transition: 'all 0.15s',
        border: `1.5px solid ${active ? (color || 'var(--admin-accent)') : 'var(--admin-border)'}`,
        background: active ? (color || 'var(--admin-accent)') : 'var(--surface)',
        color: active ? 'white' : 'var(--admin-text-muted)',
        whiteSpace: 'nowrap',
      }}
    >
      {children}
    </button>
  );
}

/* ── Search input ──────────────────────────────────────────────────────── */
export function SearchInput({ value, onChange, placeholder = 'Search…', width = 280, icon, ...rest }) {
  const Glyph = icon;
  return (
    <div style={{ position: 'relative', width, maxWidth: '100%' }}>
      {Glyph && <Glyph size={15} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--admin-text-muted)', pointerEvents: 'none' }} />}
      <input
        type="search"
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        style={{
          width: '100%', height: '38px', paddingLeft: Glyph ? '36px' : '12px', paddingRight: '12px',
          border: '1.5px solid var(--admin-border)', borderRadius: '10px',
          background: 'var(--input-bg)', color: 'var(--text-main)', outline: 'none',
          fontSize: '0.875rem', fontFamily: 'inherit', boxSizing: 'border-box',
        }}
        {...rest}
      />
    </div>
  );
}

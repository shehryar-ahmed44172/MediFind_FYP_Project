/* Table header cell style shared by admin tables */
export const thStyle = {
  padding: '12px 20px', textAlign: 'left', fontSize: '0.72rem', fontWeight: 700,
  color: 'var(--admin-text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em',
  background: 'var(--table-head-bg)', borderBottom: '1px solid var(--admin-border)', whiteSpace: 'nowrap',
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

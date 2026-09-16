import { useEffect } from 'react';

/**
 * Applies the admin console design scope (`.mf-admin` on <html>) while the
 * calling component is mounted. Scoping on <html> lets portals, toasts and the
 * confirm dialog share the admin tokens, while the public landing page — which
 * never mounts an admin screen — keeps its own typography and palette.
 */
export default function useAdminScope() {
  useEffect(() => {
    const root = document.documentElement;
    root.classList.add('mf-admin');
    return () => root.classList.remove('mf-admin');
  }, []);
}

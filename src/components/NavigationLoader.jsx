import React from 'react';
import { useLocation } from 'react-router-dom';

/**
 * Slim top progress bar shown briefly on every route change.
 * Purely decorative: it never blocks clicks (pointer-events: none) and needs no
 * state — remounting via `key` restarts the CSS animation (see index.css).
 */
export default function NavigationLoader() {
  const { pathname } = useLocation();
  return <div key={pathname} className="mf-route-progress" aria-hidden="true" />;
}

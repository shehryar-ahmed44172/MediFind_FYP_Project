/**
 * resolveFileUrl — converts any stored file URL to a URL the browser can load.
 *
 * URL formats stored in DB:
 *   • New (relative): "/uploads/documents/cnic-xxx.jpg"
 *   • Old (absolute, any host): "http://10.0.2.2:3000/uploads/..." or a tunnel
 *   • Production absolute: "https://api.medifind.app/uploads/..."
 *
 * In development the path stays relative and Vite proxies /uploads to the
 * backend. A deployed portal has no proxy in front of it, so the backend origin
 * has to go back on the front or every document 404s against the static site.
 */
const API_BASE = (import.meta.env.VITE_API_URL || '').replace(/\/+$/, '');

export function resolveFileUrl(url) {
  if (!url) return null;

  // Already a relative path starting with /uploads
  if (url.startsWith('/uploads/')) return `${API_BASE}${url}`;

  // Absolute URL — keep only the /uploads/... path, then point it at the
  // backend we are actually talking to. This fixes old records stored with
  // mobile-device hosts (10.0.2.2, a tunnel, a laptop on Wi-Fi).
  if (url.includes('/uploads/')) {
    return `${API_BASE}${url.slice(url.indexOf('/uploads/'))}`;
  }

  // Some other external URL — leave it alone
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  // Bare relative path without a leading slash
  return `${API_BASE}/${url}`;
}

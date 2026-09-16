/**
 * resolveFileUrl — converts any stored file URL to a URL the browser can load.
 *
 * URL formats stored in DB:
 *   • New (relative): "/uploads/documents/cnic-xxx.jpg"
 *     → returned as-is; Vite proxies /uploads → http://localhost:3000
 *   • Old (absolute, any host): "http://10.0.2.2:3000/uploads/..." or ngrok
 *     → strip to just the path, let Vite proxy handle it
 *   • Production absolute: "https://api.medifind.app/uploads/..."
 *     → returned as-is
 */
export function resolveFileUrl(url) {
  if (!url) return null;

  // Already a relative path starting with /uploads — Vite proxy handles it
  if (url.startsWith('/uploads/')) return url;

  // Absolute URL — extract just the /uploads/... path so Vite proxy works
  // This fixes old records stored with mobile-device hosts (10.0.2.2, ngrok, etc.)
  if (url.includes('/uploads/')) {
    const idx = url.indexOf('/uploads/');
    return url.slice(idx); // e.g. "/uploads/documents/file.jpg"
  }

  // Production or other external URLs — return as-is
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  // Bare relative path without leading slash
  return `/${url}`;
}

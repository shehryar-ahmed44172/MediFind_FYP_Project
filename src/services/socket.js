import { io } from 'socket.io-client';

/**
 * Single shared Socket.IO connection for the admin portal.
 *
 * - URL: VITE_API_URL when set (production / ngrok); otherwise `undefined`, which
 *   makes socket.io connect to the page origin. In dev, Vite proxies /socket.io
 *   to the backend (see vite.config.js).
 * - Auth: the server only admits a socket into the `admin_notifications` room when
 *   the JWT carries role ADMIN, so the token is sent in the handshake. `auth` is a
 *   callback so reconnects pick up a token that was silently refreshed.
 * - Ref-counted: the dashboard shell and SOS monitor share one connection; it is
 *   closed when the last consumer releases it.
 */
const SOCKET_URL = import.meta.env.VITE_API_URL || undefined;

let socket = null;
let refs = 0;

const currentUserId = () => {
  try {
    return JSON.parse(localStorage.getItem('medifind_user') || 'null')?.id;
  } catch {
    return undefined;
  }
};

export function acquireSocket() {
  if (!socket) {
    socket = io(SOCKET_URL, {
      auth: (cb) => cb({ token: localStorage.getItem('medifind_token') }),
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
    });
    // Legacy room join — harmless alongside token auth
    socket.on('connect', () => {
      socket.emit('join', { userId: currentUserId(), role: 'ADMIN' });
    });
  }
  refs += 1;
  return socket;
}

export function releaseSocket() {
  refs = Math.max(0, refs - 1);
  if (refs === 0 && socket) {
    socket.disconnect();
    socket = null;
  }
}

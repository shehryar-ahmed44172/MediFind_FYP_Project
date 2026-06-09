import { useEffect, useState, useRef } from 'react';
import { useLocation } from 'react-router-dom';

const SHOW_MS  = 5000; // how long the loader stays fully visible
const FADE_MS  = 320;  // fade-out duration

/* ─── keyframe CSS injected once ─────────────────────────────────────────── */
const KEYFRAMES = `
@keyframes sos-ripple {
  0%   { transform: scale(0.55); opacity: 0.85; }
  100% { transform: scale(1.75); opacity: 0;    }
}
@keyframes pin-pulse {
  0%, 100% { transform: scale(1);    filter: drop-shadow(0 4px 22px rgba(36,150,167,0.55)); }
  50%       { transform: scale(1.13); filter: drop-shadow(0 6px 30px rgba(36,150,167,0.90)); }
}
@keyframes ecg-draw {
  to { stroke-dashoffset: 0; }
}
@keyframes ecg-glow {
  0%, 100% { opacity: 1;   }
  50%       { opacity: 0.5; }
}
@keyframes loader-fade-up {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0);    }
}
@keyframes dot-blink {
  0%, 80%, 100% { opacity: 0.2; transform: scale(0.8); }
  40%           { opacity: 1;   transform: scale(1.2); }
}
`;

let stylesInjected = false;

export default function NavigationLoader() {
  const location  = useLocation();
  const [phase, setPhase] = useState('hidden'); // 'hidden' | 'show' | 'fading'
  const timers = useRef([]);

  /* inject keyframes once into <head> */
  useEffect(() => {
    if (!stylesInjected) {
      const el = document.createElement('style');
      el.textContent = KEYFRAMES;
      document.head.appendChild(el);
      stylesInjected = true;
    }
  }, []);

  /* trigger on every pathname change */
  useEffect(() => {
    timers.current.forEach(clearTimeout);
    timers.current = [];

    setPhase('show');
    timers.current.push(setTimeout(() => setPhase('fading'), SHOW_MS));
    timers.current.push(setTimeout(() => setPhase('hidden'), SHOW_MS + FADE_MS));

    return () => timers.current.forEach(clearTimeout);
  }, [location.pathname]);

  if (phase === 'hidden') return null;

  const isFading = phase === 'fading';

  return (
    <div
      aria-hidden="true"
      style={{
        position:       'fixed',
        inset:          0,
        zIndex:         9999,
        background:     'linear-gradient(155deg, #021B28 0%, #08485F 50%, #0C637E 100%)',
        display:        'flex',
        flexDirection:  'column',
        alignItems:     'center',
        justifyContent: 'center',
        gap:            0,
        opacity:        isFading ? 0 : 1,
        transition:     `opacity ${FADE_MS}ms cubic-bezier(0.4, 0, 0.2, 1)`,
        pointerEvents:  isFading ? 'none' : 'auto',
        userSelect:     'none',
      }}
    >
      {/* ── Ripple rings ───────────────────────────────────────── */}
      <div style={{
        position:       'relative',
        width:          200,
        height:         200,
        display:        'flex',
        alignItems:     'center',
        justifyContent: 'center',
      }}>
        {[0, 1, 2, 3].map(i => (
          <div
            key={i}
            style={{
              position:     'absolute',
              width:        64 + i * 34,
              height:       64 + i * 34,
              borderRadius: '50%',
              border:       `${Math.max(1, 3 - i)}px solid rgba(36, 150, 167, ${0.75 - i * 0.15})`,
              animation:    `sos-ripple 2s ease-out ${i * 0.38}s infinite`,
            }}
          />
        ))}

        {/* ── Location pin ── */}
        <svg
          width="72"
          height="84"
          viewBox="0 0 72 84"
          style={{ animation: 'pin-pulse 2s ease-in-out infinite', position: 'relative', zIndex: 2 }}
        >
          {/* Outer pin body */}
          <path
            d="M36 5 C19 5 6 18 6 33 C6 52 36 79 36 79 C36 79 66 52 66 33 C66 18 53 5 36 5Z"
            fill="#0C3A6E"
            stroke="rgba(36,150,167,0.6)"
            strokeWidth="1.5"
          />
          {/* Inner circle */}
          <circle cx="36" cy="32" r="15" fill="#0A4F70" />
          {/* Medical cross — horizontal */}
          <rect x="26" y="29.5" width="20" height="5" rx="2.5" fill="#2496A7" />
          {/* Medical cross — vertical */}
          <rect x="33.5" y="22" width="5" height="20" rx="2.5" fill="#2496A7" />
        </svg>
      </div>

      {/* ── ECG / heartbeat line ─────────────────────────────────── */}
      <div style={{ marginTop: 24, width: 280 }}>
        <svg width="280" height="44" viewBox="0 0 280 44">
          {/* Glow duplicate (blurred) */}
          <polyline
            points="0,22 44,22 56,5 65,40 74,2 84,42 95,22 139,22 151,5 160,40 169,2 179,42 190,22 280,22"
            fill="none"
            stroke="#2496A7"
            strokeWidth="6"
            strokeLinecap="round"
            strokeLinejoin="round"
            opacity="0.2"
            style={{
              filter:           'blur(4px)',
              strokeDasharray:  700,
              strokeDashoffset: 700,
              animation:        `ecg-draw 1.1s cubic-bezier(0.4,0,0.2,1) 0.05s forwards,
                                 ecg-glow 1.6s ease-in-out 1.2s infinite`,
            }}
          />
          {/* Sharp line */}
          <polyline
            points="0,22 44,22 56,5 65,40 74,2 84,42 95,22 139,22 151,5 160,40 169,2 179,42 190,22 280,22"
            fill="none"
            stroke="#2891C2"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{
              strokeDasharray:  700,
              strokeDashoffset: 700,
              animation:        `ecg-draw 1.1s cubic-bezier(0.4,0,0.2,1) 0.05s forwards`,
            }}
          />
        </svg>
      </div>

      {/* ── Brand text ───────────────────────────────────────────── */}
      <div style={{
        marginTop: 20,
        textAlign: 'center',
        animation: 'loader-fade-up 0.5s ease-out 0.15s both',
      }}>
        <p style={{
          margin:        0,
          fontSize:      '1.55rem',
          fontWeight:    900,
          letterSpacing: '0.2em',
          color:         'white',
          fontFamily:    'inherit',
        }}>
          <span style={{
            background:           'linear-gradient(90deg, #2496A7, #2891C2)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor:  'transparent',
            backgroundClip:       'text',
          }}>MEDI</span>FIND
        </p>
        <p style={{
          margin:        '7px 0 0',
          fontSize:      '0.67rem',
          fontWeight:    700,
          letterSpacing: '0.25em',
          color:         'rgba(255,255,255,0.35)',
          textTransform: 'uppercase',
        }}>
          Emergency Response Network
        </p>
      </div>

      {/* ── Loading dots ─────────────────────────────────────────── */}
      <div style={{
        display:    'flex',
        gap:        '7px',
        marginTop:  20,
        animation:  'loader-fade-up 0.5s ease-out 0.3s both',
      }}>
        {[0, 1, 2].map(i => (
          <div
            key={i}
            style={{
              width:        7,
              height:       7,
              borderRadius: '50%',
              background:   '#2496A7',
              animation:    `dot-blink 1.2s ease-in-out ${i * 0.2}s infinite`,
            }}
          />
        ))}
      </div>
    </div>
  );
}

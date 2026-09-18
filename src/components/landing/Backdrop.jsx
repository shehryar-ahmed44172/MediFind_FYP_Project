import React from 'react';

/*
 * Animated hero background drawn from what MediFind does: a faint city map,
 * road routes that draw themselves, ambulance dots riding them, location pulse
 * rings (like the logo) and a heartbeat line. Decorative only (aria-hidden),
 * never catches clicks, and stops under prefers-reduced-motion (landing.css).
 */
const ROUTES = [
  'M-40 560 H300 V420 H620 V300 H900',
  'M1480 180 H1180 V330 H980 V470 H760',
  'M180 -40 V160 H460 V260',
  'M1500 620 H1240 V520 H1060',
];

export function HeroBackdrop() {
  return (
    <div className="lp-backdrop" aria-hidden="true">
      <svg className="lp-backdrop-svg" viewBox="0 0 1440 720" preserveAspectRatio="xMidYMid slice">
        <defs>
          <pattern id="lp-grid" width="72" height="72" patternUnits="userSpaceOnUse">
            <path d="M72 0 H0 V72" fill="none" className="lp-bd-grid" />
          </pattern>
          <radialGradient id="lp-fade" cx="50%" cy="45%" r="65%">
            <stop offset="0%" stopColor="#fff" stopOpacity="1" />
            <stop offset="100%" stopColor="#fff" stopOpacity="0" />
          </radialGradient>
          <mask id="lp-grid-mask">
            <rect width="1440" height="720" fill="url(#lp-fade)" />
          </mask>
        </defs>

        {/* City grid, fading out towards the edges */}
        <rect width="1440" height="720" fill="url(#lp-grid)" mask="url(#lp-grid-mask)" />

        {/* Routes draw in, then ambulance dots ride them */}
        {ROUTES.map((d, i) => (
          <g key={d}>
            <path d={d} className="lp-bd-road" />
            <path d={d} className="lp-bd-route" style={{ animationDelay: `${i * 1.6}s` }} />
            <circle r="6" className="lp-bd-rider">
              <animateMotion dur={`${9 + i * 2}s`} begin={`${i * 1.6}s`} repeatCount="indefinite" path={d} rotate="auto" />
            </circle>
            <circle r="14" className="lp-bd-rider-glow">
              <animateMotion dur={`${9 + i * 2}s`} begin={`${i * 1.6}s`} repeatCount="indefinite" path={d} />
            </circle>
          </g>
        ))}

        {/* Location pulses where help is heading */}
        {[[900, 300], [760, 470], [460, 260]].map(([cx, cy], i) => (
          <g key={`${cx}-${cy}`} transform={`translate(${cx} ${cy})`}>
            <circle r="60" className="lp-bd-pulse" style={{ animationDelay: `${i * 0.9}s` }} />
            <circle r="60" className="lp-bd-pulse" style={{ animationDelay: `${i * 0.9 + 1.4}s` }} />
            <circle r="5" className="lp-bd-dot" />
          </g>
        ))}

        {/* Heartbeat line across the bottom */}
        <path
          className="lp-bd-ecg"
          d="M0 660 H380 l18 -34 l16 60 l20 -92 l18 118 l16 -52 H760 l14 -26 l12 44 l16 -70 l16 92 l14 -40 H1440"
        />
      </svg>
    </div>
  );
}

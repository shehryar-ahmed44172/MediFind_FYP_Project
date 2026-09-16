import React from 'react';
import {
  HeartPulse, Wind, Brain, Zap, Droplet, Bone, BadgeCheck, Check,
  Vibrate, MessageSquare, Sparkles, Signal, BatteryFull, Wifi, MapPin, Ear,
} from 'lucide-react';
import appMark from '../../assets/medifind_app_mark.png';

/*
 * Lightweight HTML/CSS/SVG recreations of real MediFind mobile screens.
 * Purely illustrative (aria-hidden content + a text label on the frame).
 * Styles live in src/pages/landing.css (lp-phone*, lp-sos*, lp-map*, lp-deaf*).
 */

export function PhoneFrame({ label, children, className = '' }) {
  return (
    <figure className={`lp-phone-figure ${className}`}>
      <div className="lp-phone" role="img" aria-label={label}>
        <div className="lp-phone-notch" aria-hidden="true" />
        <div className="lp-phone-screen" aria-hidden="true">
          <div className="lp-statusbar">
            <span>9:41</span>
            <span className="lp-statusbar-icons"><Signal size={11} /><Wifi size={11} /><BatteryFull size={13} /></span>
          </div>
          {children}
        </div>
      </div>
      <figcaption className="lp-caption">App preview</figcaption>
    </figure>
  );
}

function AppHeader({ right }) {
  return (
    <div className="lp-app-header">
      <img src={appMark} alt="" width="26" height="25" />
      <span className="lp-app-title">Medi<b>Find</b></span>
      <span style={{ marginLeft: 'auto' }}>{right}</span>
    </div>
  );
}

const EMERGENCY_TYPES = [
  { label: 'Cardiac',   Icon: HeartPulse },
  { label: 'Breathing', Icon: Wind },
  { label: 'Stroke',    Icon: Brain },
  { label: 'Seizure',   Icon: Zap },
  { label: 'Diabetic',  Icon: Droplet },
  { label: 'Injury / Fall', Icon: Bone },
];

/* 1 — SOS home screen with 60-second cancel ring */
export function SosScreen() {
  const R = 74;
  const C = 2 * Math.PI * R;
  return (
    <div className="lp-screen">
      <AppHeader right={<span className="lp-pill lp-pill-deaf"><Ear size={10} /> DEAF MODE</span>} />
      <p className="lp-screen-hello">Assalam-o-Alaikum, Ayesha</p>
      <p className="lp-screen-sub">Medical emergency? Help comes to you.</p>

      <div className="lp-sos-wrap">
        <svg className="lp-sos-ring" width="176" height="176" viewBox="0 0 176 176">
          <circle cx="88" cy="88" r={R} fill="none" stroke="var(--lp-ring-track)" strokeWidth="6" />
          <circle
            className="lp-sos-ring-progress"
            cx="88" cy="88" r={R} fill="none" stroke="var(--sos)" strokeWidth="6" strokeLinecap="round"
            strokeDasharray={C} style={{ '--ring-c': C }}
            transform="rotate(-90 88 88)"
          />
        </svg>
        <div className="lp-sos-button">
          <span className="lp-sos-text">SOS</span>
          <span className="lp-sos-hint">Hold / tap for<br />medical emergency</span>
        </div>
      </div>
      <div className="lp-sos-cancel">
        <span>Sent by mistake? <b>60s</b> to cancel</span>
        <span className="lp-pill lp-pill-outline">Cancel</span>
      </div>

      <p className="lp-screen-label">Emergency type</p>
      <div className="lp-type-grid">
        {EMERGENCY_TYPES.map(({ label, Icon }) => (
          <span key={label} className="lp-type-chip"><Icon size={14} /> {label}</span>
        ))}
      </div>
    </div>
  );
}

/* Motorbike ambulance (side view) — drawn inline so it stays crisp and tiny */
export function MotorbikeAmbulance({ size = 44 }) {
  return (
    <svg width={size} height={size * 0.7} viewBox="0 0 60 42" aria-hidden="true">
      <circle cx="13" cy="32" r="8" fill="#1B2632" />
      <circle cx="13" cy="32" r="3.2" fill="var(--text-muted)" />
      <circle cx="47" cy="32" r="8" fill="#1B2632" />
      <circle cx="47" cy="32" r="3.2" fill="var(--text-muted)" />
      <path d="M13 32 L24 20 L40 20 L47 32" fill="none" stroke="#3D4F5F" strokeWidth="3" strokeLinecap="round" />
      <rect x="4" y="11" width="18" height="13" rx="3" fill="#FFFFFF" stroke="var(--primary)" strokeWidth="1.5" />
      <rect x="11.5" y="13.5" width="3" height="8" rx="0.8" fill="var(--sos)" />
      <rect x="9" y="16" width="8" height="3" rx="0.8" fill="var(--sos)" />
      <path d="M24 20 Q30 12 40 14 L44 20 Z" fill="#FFFFFF" stroke="var(--primary)" strokeWidth="1.5" />
      <rect x="26" y="15" width="12" height="2.4" rx="1.2" fill="var(--primary-mid)" />
      <rect x="7" y="7" width="10" height="4" rx="2" fill="var(--sos)" className="lp-siren" />
      <path d="M42 14 L50 12" stroke="#3D4F5F" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}

/* 2 — Live tracking screen */
export function TrackingScreen() {
  return (
    <div className="lp-screen">
      <AppHeader right={<span className="lp-pill lp-pill-eta">ETA 4 min</span>} />
      <p className="lp-screen-title">Help is on the way</p>

      <div className="lp-map">
        <svg className="lp-map-svg" width="100%" height="100%" viewBox="0 0 248 190" preserveAspectRatio="none">
          <rect x="0" y="0" width="248" height="190" fill="var(--lp-map-bg)" />
          <rect x="150" y="18" width="70" height="46" rx="8" fill="var(--lp-map-block)" />
          <rect x="22" y="112" width="58" height="52" rx="8" fill="var(--lp-map-block)" />
          <g stroke="var(--lp-map-street)" strokeLinecap="round" fill="none">
            <path d="M0 40 H248" strokeWidth="9" />
            <path d="M0 96 H248" strokeWidth="7" />
            <path d="M0 150 H248" strokeWidth="9" />
            <path d="M48 0 V190" strokeWidth="7" />
            <path d="M120 0 V190" strokeWidth="9" />
            <path d="M200 0 V190" strokeWidth="7" />
          </g>
          <path d="M20 150 H120 V96 H200 V52" fill="none" stroke="var(--primary-light)" strokeWidth="4" strokeDasharray="7 6" strokeLinecap="round" />
        </svg>
        {/* Moving motorbike follows the same route (see .lp-bike offset-path) */}
        <div className="lp-bike"><MotorbikeAmbulance size={40} /></div>
        <div className="lp-patient-pin">
          <MapPin size={26} fill="var(--sos)" color="#FFFFFF" strokeWidth={1.6} />
          <span className="lp-patient-pulse" />
        </div>
      </div>

      <div className="lp-responder-card">
        <div className="lp-avatar">HR</div>
        <div style={{ minWidth: 0 }}>
          <p className="lp-responder-name">Hamza R. <BadgeCheck size={13} color="var(--success)" /></p>
          <p className="lp-responder-meta">Verified responder • Motorbike Ambulance • ETA 4 min</p>
        </div>
      </div>

      <ol className="lp-timeline">
        <li className="is-done"><span className="lp-dot"><Check size={10} /></span>Accepted</li>
        <li className="is-active"><span className="lp-dot" />En route</li>
        <li><span className="lp-dot" />Arrived</li>
      </ol>
    </div>
  );
}

const QUICK_REPLIES = ["I can't hear", 'Chest pain', "I'm allergic to penicillin", 'Please text me'];

/* 3 — Deaf-first visual alert + text chat */
export function DeafAlertScreen() {
  return (
    <div className="lp-screen">
      <div className="lp-deaf-alert">
        <span className="lp-deaf-flash" />
        <Vibrate size={26} />
        <p className="lp-deaf-alert-title">HELP IS ON THE WAY</p>
        <p className="lp-deaf-alert-sub">Responder accepted · 4 min away</p>
      </div>

      <div className="lp-chat">
        <p className="lp-chat-label"><MessageSquare size={11} /> Text chat with your responder</p>
        <div className="lp-bubble lp-bubble-in">I'm 4 minutes away. Are you awake and breathing okay?</div>
        <div className="lp-bubble lp-bubble-out">Yes. I can't hear — please text me.</div>
        <div className="lp-bubble lp-bubble-in">Understood. I will text only. Stay where you are.</div>
      </div>

      <p className="lp-chat-label" style={{ marginTop: 8 }}><Sparkles size={11} /> AI quick replies</p>
      <div className="lp-quick-replies">
        {QUICK_REPLIES.map(t => <span key={t} className="lp-quick-chip">{t}</span>)}
      </div>
    </div>
  );
}

import React from 'react';
import {
  HeartPulse, Wind, Brain, Zap, Droplet, Bone, BadgeCheck, Check,
  Vibrate, MessageSquare, Sparkles, Signal, BatteryFull, Wifi, MapPin, Ear,
  TriangleAlert, ClipboardPlus, Navigation, Bell, Users,
} from 'lucide-react';
import appMark from '../../assets/medifind_mark.png';
import bikeFrame0 from '../../assets/mascot_bike_0.png';
import bikeFrame1 from '../../assets/mascot_bike_1.png';

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
    </figure>
  );
}

function AppHeader({ right }) {
  return (
    <div className="lp-app-header">
      <img src={appMark} alt="" width="26" height="26" />
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

/* 2 — Live tracking screen */
export function TrackingScreen() {
  return (
    <div className="lp-screen">
      {/* Header pill and title change with the ride (see .lp-live-* keyframes) */}
      <AppHeader right={(
        <span className="lp-live-stack">
          <span className="lp-pill lp-pill-eta lp-live-a">ETA 4 min</span>
          <span className="lp-pill lp-pill-eta lp-live-b">Arrived</span>
          <span className="lp-pill lp-pill-eta lp-live-c">Resolved</span>
        </span>
      )} />
      <p className="lp-screen-title lp-live-stack">
        <span className="lp-live-a">Help is on the way</span>
        <span className="lp-live-b">Responder has arrived</span>
        <span className="lp-live-c">Emergency resolved</span>
      </p>

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
        <div className="lp-bike" role="img" aria-label="Motorbike ambulance">
          {/* Same mascot as the app's live map; the second frame flashes the siren */}
          <img src={bikeFrame0} alt="" />
          <img src={bikeFrame1} alt="" className="lp-bike-siren" />
        </div>
        <div className="lp-patient-pin">
          <MapPin size={26} fill="var(--sos)" color="#FFFFFF" strokeWidth={1.6} />
          <span className="lp-patient-pulse" />
        </div>
      </div>

      <div className="lp-responder-card">
        <div className="lp-avatar">HR</div>
        <div style={{ minWidth: 0 }}>
          <p className="lp-responder-name">Hamza R. <BadgeCheck size={13} color="var(--success)" /></p>
          <p className="lp-responder-meta">Verified responder • Motorbike Ambulance</p>
        </div>
      </div>

      {/* Same four steps as the responder app, advancing with the motorbike */}
      <ol className="lp-timeline lp-timeline-live">
        <li className="is-done"><span className="lp-dot"><Check size={10} /></span>Accepted</li>
        <li className="lp-tl-2 is-active"><span className="lp-dot"><Check size={10} className="lp-tl-check" /></span>On the way</li>
        <li className="lp-tl-3"><span className="lp-dot"><Check size={10} className="lp-tl-check" /></span>Arrived</li>
        <li className="lp-tl-4"><span className="lp-dot"><Check size={10} className="lp-tl-check" /></span>Resolved</li>
      </ol>
    </div>
  );
}

/* 2b — Responder's phone: the incoming emergency request (same content as the app's alert) */
export function ResponderAlertScreen() {
  return (
    <div className="lp-screen">
      <AppHeader right={<span className="lp-pill lp-pill-online"><span className="lp-online-dot" /> Online</span>} />
      <p className="lp-screen-hello">Hello, Hamza</p>
      <p className="lp-screen-sub">Responder dashboard</p>

      <div className="lp-alert-card">
        <span className="lp-alert-icon"><TriangleAlert size={22} /></span>
        <p className="lp-alert-title">Emergency Request!</p>
        <p className="lp-alert-type">CARDIAC</p>
        <p className="lp-alert-expiry">Request expires in <b>0:52</b></p>
        <p className="lp-alert-distance"><Navigation size={11} /> 1.4 km away · ~3 min</p>
        <div className="lp-alert-medical">
          <p className="lp-alert-medical-title"><ClipboardPlus size={12} /> Medical summary</p>
          <p><b>Blood type:</b> B+</p>
          <p className="lp-alert-allergy">Allergies: Penicillin</p>
          <p className="lp-alert-condition">Conditions: Asthma</p>
        </div>
        <div className="lp-alert-actions">
          <span className="lp-alert-btn lp-alert-btn-ghost">Reject</span>
          <span className="lp-alert-btn lp-alert-btn-primary"><Check size={12} /> Accept</span>
        </div>
      </div>
    </div>
  );
}

/* 4 — Caregiver's dashboard following the same emergency */
export function CaregiverScreen() {
  return (
    <div className="lp-screen">
      <div className="lp-notif">
        <img src={appMark} alt="" width="18" height="18" />
        <span><b>Ayesha Khan raised an SOS</b><br />Hamza R. accepted · on the way</span>
      </div>
      <AppHeader right={<span className="lp-pill lp-pill-outline"><Bell size={10} /> 1</span>} />
      <p className="lp-screen-hello">Hello, Sara</p>
      <p className="lp-screen-sub">Caregiver dashboard</p>

      <div className="lp-cg-sos">
        <p className="lp-cg-sos-label"><span className="lp-online-dot lp-dot-red" /> Active SOS · just now</p>
        <p className="lp-cg-name">Ayesha Khan</p>
        <p className="lp-cg-meta">Cardiac · Responder on the way</p>
        <div className="lp-cg-map">
          <svg width="100%" height="100%" viewBox="0 0 220 80" preserveAspectRatio="none">
            <rect width="220" height="80" fill="var(--lp-map-bg)" />
            <g stroke="var(--lp-map-street)" strokeWidth="6" fill="none"><path d="M0 28 H220" /><path d="M0 62 H220" /><path d="M70 0 V80" /><path d="M160 0 V80" /></g>
            <path d="M16 62 H70 V28 H150" fill="none" stroke="var(--primary-light)" strokeWidth="3" strokeDasharray="6 5" strokeLinecap="round" />
          </svg>
          <span className="lp-cg-bike"><img src={bikeFrame0} alt="" /><img src={bikeFrame1} alt="" className="lp-bike-siren" /></span>
          <span className="lp-cg-pin"><MapPin size={20} fill="var(--sos)" color="#FFFFFF" strokeWidth={1.6} /></span>
        </div>
        <span className="lp-cg-track"><MapPin size={12} /> Track live</span>
      </div>

      <p className="lp-screen-label">Linked patients</p>
      <div className="lp-cg-row"><span className="lp-avatar lp-avatar-sm">AK</span><span><b>Ayesha Khan</b><br />Friend · SOS active</span><span className="lp-pill lp-pill-sos">SOS</span></div>
      <div className="lp-cg-row"><span className="lp-avatar lp-avatar-sm">BA</span><span><b>Bilal Ahmed</b><br />Brother · Deaf</span><span className="lp-pill lp-pill-safe"><Users size={9} /> Safe</span></div>
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

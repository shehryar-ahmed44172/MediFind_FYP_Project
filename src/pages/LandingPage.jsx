import React, { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { AnimatePresence, MotionConfig, motion, useInView, useReducedMotion } from 'framer-motion';
import {
  Ambulance, ArrowRight, BellRing, BookmarkCheck, Check, ChevronDown, ClipboardPlus, Download,
  EarOff, FileLock2, HeartHandshake, HeartPulse, IdCard, LayoutGrid, ListOrdered, LocateFixed,
  Mail, Menu, MessageSquareText, MicOff, PhoneCall, Presentation, ScrollText, ShieldCheck,
  Smartphone, Sparkles, UserRound, Users, Vibrate, X,
} from 'lucide-react';
import appMark from '../assets/medifind_mark.png';
import {
  PhoneFrame, SosScreen, TrackingScreen, DeafAlertScreen, ResponderAlertScreen, CaregiverScreen,
} from '../components/landing/AppMockups';
import { HeroBackdrop } from '../components/landing/Backdrop';
import './landing.css';

/* Update when the app is published on Google Play */
const PLAY_STORE_URL = '#';
const PLAY_STORE_LIVE = PLAY_STORE_URL !== '#';
const SUPPORT_EMAIL = 'support@medifind.pk';

const NAV_LINKS = [
  { href: '#features',   label: 'Features' },
  { href: '#deaf',       label: 'For Deaf Users' },
  { href: '#how',        label: 'How it works' },
  { href: '#responders', label: 'Responders' },
  { href: '#faq',        label: 'FAQ' },
];

const fadeUp = {
  initial: { opacity: 0, y: 18 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: '-60px' },
  transition: { duration: 0.45, ease: 'easeOut' },
};

/* ── Download CTA — honest "coming soon" state until the store link exists ── */
function DownloadButton({ size }) {
  const cls = `lp-btn lp-btn-primary${size === 'sm' ? ' lp-btn-sm' : ''}`;
  if (PLAY_STORE_LIVE) {
    return (
      <a className={cls} href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer">
        <Download size={18} /> Get it on Google Play
      </a>
    );
  }
  return (
    <span className={cls} aria-disabled="true" title="The Android app is not published yet">
      <Smartphone size={18} /> Coming soon on Google Play
    </span>
  );
}

/* ── Header ── */
function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="lp-header">
      <div className="lp-container lp-header-inner">
        <Link to="/" className="lp-logo" aria-label="MediFind home">
          <img src={appMark} alt="" width="34" height="34" />
          <span>Medi<b>Find</b></span>
        </Link>
        <nav className="lp-nav" aria-label="Primary">
          {NAV_LINKS.map(l => <a key={l.href} href={l.href}>{l.label}</a>)}
        </nav>
        <Link to="/login" className="lp-btn lp-btn-secondary lp-btn-sm lp-header-cta">Admin login</Link>
        <button
          type="button"
          className="lp-menu-btn"
          aria-expanded={open}
          aria-controls="lp-mobile-nav"
          aria-label={open ? 'Close menu' : 'Open menu'}
          onClick={() => setOpen(o => !o)}
        >
          {open ? <X size={20} /> : <Menu size={20} />}
        </button>
      </div>
      <nav id="lp-mobile-nav" className={`lp-mobile-nav${open ? ' is-open' : ''}`} aria-label="Mobile">
        {NAV_LINKS.map(l => <a key={l.href} href={l.href} onClick={() => setOpen(false)}>{l.label}</a>)}
        <Link to="/login" className="lp-btn lp-btn-secondary lp-btn-sm">Admin login</Link>
      </nav>
    </header>
  );
}

/* ── Hero ── */
function Hero() {
  return (
    <section className="lp-hero" aria-labelledby="hero-title">
      <HeroBackdrop />
      <div className="lp-container lp-hero-grid">
        <motion.div {...fadeUp}>
          <span className="lp-eyebrow"><EarOff size={14} /> Deaf-first medical emergency app · Pakistan</span>
          <h1 id="hero-title">Emergency help that doesn't depend on hearing or speaking.</h1>
          <p className="lp-lead">
            One tap sends your location and medical profile to the nearest verified motorbike ambulance.
            You follow help on a live map and talk to your responder by text — no phone call needed.
          </p>
          <div className="lp-hero-cta">
            <DownloadButton />
            <a className="lp-btn lp-btn-secondary" href="#how">See how it works <ArrowRight size={18} /></a>
          </div>
          {!PLAY_STORE_LIVE && (
            <p className="lp-store-note">The Android app is in final testing. iOS is planned later.</p>
          )}
          <ul className="lp-hero-points">
            <li><Check size={16} /> No voice call required</li>
            <li><Check size={16} /> Verified responders only</li>
            <li><Check size={16} /> Live ambulance tracking</li>
          </ul>
        </motion.div>

        <div className="lp-hero-visual">
          <div className="lp-hero-phones">
            <PhoneFrame label="MediFind app: SOS screen with a 60-second cancel ring and medical emergency types">
              <SosScreen />
            </PhoneFrame>
            <PhoneFrame className="secondary" label="MediFind app: live tracking of a motorbike ambulance">
              <TrackingScreen />
            </PhoneFrame>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ── Built for Deaf users ── */
const DEAF_FEATURES = [
  { Icon: MicOff,            title: 'Visual SOS, no voice',     text: 'Trigger help and pick the emergency type with taps — nothing to say or hear.' },
  { Icon: Vibrate,           title: 'Flash + vibration alerts', text: 'Full-screen flashing and strong vibration tell you when help accepts and arrives.' },
  { Icon: MessageSquareText, title: 'Text-only responder chat', text: 'Your responder is told you are Deaf and communicates with you in writing.' },
  { Icon: Sparkles,          title: 'AI quick-reply cards',     text: 'Suggested replies like “Chest pain” or “Please text me” so you can answer fast.' },
  { Icon: BookmarkCheck,     title: 'Saved quick phrases',      text: 'Prepare your own phrases in advance — allergies, conditions, how to reach you.' },
  { Icon: Presentation,      title: 'Show-to-bystander card',   text: 'A large on-screen card explains you are Deaf and need medical help.' },
];

function DeafSection() {
  return (
    <section id="deaf" className="lp-section lp-section-alt" aria-labelledby="deaf-title">
      <div className="lp-container lp-split">
        <motion.div {...fadeUp}>
          <span className="lp-eyebrow"><EarOff size={14} /> Built for Deaf users</span>
          <h2 id="deaf-title">Designed around sight and touch — not sound.</h2>
          <p className="lp-lead">
            Most emergency services start with a voice call. MediFind starts with a tap, keeps you
            informed with visual alerts, and keeps every conversation in text.
          </p>
          <div className="lp-feature-grid">
            {DEAF_FEATURES.map(({ Icon, title, text }) => (
              <div key={title} className="lp-mini-feature">
                <span className="lp-icon" aria-hidden="true"><Icon size={18} /></span>
                <div>
                  <h3>{title}</h3>
                  <p>{text}</p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame label="MediFind app: flashing 'Help is on the way' alert and text chat with AI quick replies">
            <DeafAlertScreen />
          </PhoneFrame>
        </div>
      </div>
    </section>
  );
}

/* ── How it works ── */
/* Each step shows its own screen in the phone; `ms` is how long it stays before moving on */
const STEPS = [
  { title: 'Tap SOS and choose the emergency', text: 'Cardiac, breathing, stroke, seizure, diabetic or injury. You have 60 seconds to cancel an accidental alert.',
    Screen: SosScreen, ms: 6000, label: 'Patient app: SOS button with the 60-second cancel ring and emergency types' },
  { title: 'The nearest verified responder accepts', text: 'Available responders close to you are notified at once with your location and medical profile.',
    Screen: ResponderAlertScreen, ms: 6000, label: 'Responder app: incoming emergency request with distance, medical summary and Accept button' },
  { title: 'Track the motorbike ambulance live', text: 'See the responder move on the map with an ETA, and chat by text while they travel.',
    Screen: TrackingScreen, ms: 12000, label: 'Patient app: motorbike ambulance moving on the map through Accepted, On the way, Arrived and Resolved' },
  { title: 'Caregivers follow along', text: 'Linked family members and caregivers are notified and can watch the same live map.',
    Screen: CaregiverScreen, ms: 7000, label: 'Caregiver app: SOS notification and a live map of the responder' },
];

function HowItWorks() {
  const sectionRef = useRef(null);
  const inView = useInView(sectionRef, { amount: 0.35 });
  const reduceMotion = useReducedMotion();
  const [active, setActive] = useState(0);
  const [hovered, setHovered] = useState(false);
  const playing = inView && !hovered && !reduceMotion;

  // Advance to the next step when the current one has had its time on screen
  useEffect(() => {
    if (!playing) return undefined;
    const t = setTimeout(() => setActive(a => (a + 1) % STEPS.length), STEPS[active].ms);
    return () => clearTimeout(t);
  }, [active, playing]);

  const { Screen, label } = STEPS[active];
  return (
    <section id="how" ref={sectionRef} className="lp-section" aria-labelledby="how-title">
      <div className="lp-container lp-split reverse" onMouseEnter={() => setHovered(true)} onMouseLeave={() => setHovered(false)}>
        <motion.div {...fadeUp}>
          <span className="lp-eyebrow"><ListOrdered size={14} /> How it works</span>
          <h2 id="how-title">From tap to treatment in four steps.</h2>
          <p className="lp-lead">Motorbike ambulances reach patients through traffic that stops larger vehicles.</p>
          <ol className="lp-steps lp-steps-live" style={{ marginTop: 24 }}>
            {STEPS.map((s, i) => (
              <li key={s.title} className={`lp-step${i === active ? ' is-current' : ''}`}>
                <button type="button" className="lp-step-btn" onClick={() => setActive(i)} aria-current={i === active ? 'step' : undefined}>
                  <span className="lp-step-num" aria-hidden="true">{i + 1}</span>
                  <span>
                    <span className="lp-step-title">{s.title}</span>
                    <span className="lp-step-text">{s.text}</span>
                  </span>
                </button>
                {i === active && !reduceMotion && (
                  <span
                    key={`progress-${active}`}
                    className="lp-step-progress"
                    aria-hidden="true"
                    style={{ animationDuration: `${s.ms}ms`, animationPlayState: playing ? 'running' : 'paused' }}
                  />
                )}
              </li>
            ))}
          </ol>
        </motion.div>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame label={label}>
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={active}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3, ease: 'easeOut' }}
              >
                <Screen />
              </motion.div>
            </AnimatePresence>
          </PhoneFrame>
        </div>
      </div>
    </section>
  );
}

/* ── Core features ── */
const FEATURES = [
  { Icon: HeartPulse,  title: 'Medical-only emergencies', text: 'Built for health emergencies — no police or fire menus to get lost in.' },
  { Icon: ClipboardPlus, title: 'Medical profile shared',   text: 'Blood type, allergies, conditions and medications reach your responder instantly.' },
  { Icon: LocateFixed, title: 'Precise location',         text: 'GPS location is sent with every alert and updated while help is on the way.' },
  { Icon: BellRing,    title: 'Caregiver alerts',         text: 'Linked caregivers are alerted the moment you raise an SOS, and your emergency contacts are kept on your profile.' },
];

function Features() {
  return (
    <section id="features" className="lp-section lp-section-alt" aria-labelledby="features-title">
      <div className="lp-container">
        <motion.div className="lp-section-head center" {...fadeUp}>
          <span className="lp-eyebrow"><LayoutGrid size={14} /> Features</span>
          <h2 id="features-title">Everything a responder needs, before they arrive.</h2>
        </motion.div>
        <div className="lp-cards-4">
          {FEATURES.map(({ Icon, title, text }) => (
            <motion.div key={title} className="lp-card" {...fadeUp}>
              <span className="lp-icon" aria-hidden="true"><Icon size={20} /></span>
              <h3>{title}</h3>
              <p>{text}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── Roles ── */
const ROLES = [
  {
    id: 'patients', Icon: UserRound, title: 'Patients',
    text: 'For anyone who may need urgent medical help — with Deaf mode for people who cannot rely on calls.',
    points: ['One-tap SOS with a 60-second cancel window', 'Medical profile & emergency contacts', 'Text chat and visual alerts'],
  },
  {
    id: 'caregivers', Icon: HeartHandshake, title: 'Caregivers',
    text: 'Family members and carers linked to a patient stay informed without needing to be there.',
    points: ['Alerts when a linked patient raises SOS', 'Watch the responder on a live map', 'Chat with the patient and responder'],
  },
  {
    id: 'responders', Icon: Ambulance, title: 'Responders',
    text: 'Paramedics, rescue officers and trained volunteers on motorbike ambulances.',
    points: ['Apply in the app with CNIC, license and employee ID', 'Every application reviewed by MediFind admins', 'Receive nearby emergencies with patient details'],
  },
];

function Roles() {
  return (
    <section className="lp-section" aria-labelledby="roles-title">
      <div className="lp-container">
        <motion.div className="lp-section-head center" {...fadeUp}>
          <span className="lp-eyebrow"><Users size={14} /> Who it's for</span>
          <h2 id="roles-title">One network, three roles.</h2>
        </motion.div>
        <div className="lp-cards-3">
          {ROLES.map(({ id, Icon, title, text, points }) => (
            <motion.article key={id} id={id} className="lp-card lp-role-card" {...fadeUp} style={{ scrollMarginTop: 80 }}>
              <span className="lp-icon" aria-hidden="true"><Icon size={20} /></span>
              <h3>{title}</h3>
              <p>{text}</p>
              <ul>
                {points.map(pt => <li key={pt}><Check size={14} /> {pt}</li>)}
              </ul>
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── Trust ── */
const TRUST = [
  { Icon: IdCard,      title: 'Verified responders',       text: 'Every responder is reviewed by our admin team — CNIC, license and employee ID — before they can accept an emergency.' },
  { Icon: FileLock2,   title: 'Encrypted medical profile', text: 'Sensitive medical details are encrypted and only shared with the responder handling your emergency.' },
  { Icon: PhoneCall,   title: 'Rescue 1122 fallback',      text: 'MediFind works alongside public services. Rescue 1122 remains available across Pakistan.' },
  { Icon: ScrollText,  title: 'Audited admin actions',     text: 'Verification decisions and account changes are recorded in an audit log.' },
];

function Trust() {
  return (
    <section className="lp-section lp-trust" aria-labelledby="trust-title">
      <div className="lp-container">
        <motion.div className="lp-section-head center" {...fadeUp}>
          <span className="lp-eyebrow"><ShieldCheck size={14} /> Safety &amp; trust</span>
          <h2 id="trust-title">Built to be trusted in the worst moment.</h2>
        </motion.div>
        <div className="lp-cards-4">
          {TRUST.map(({ Icon, title, text }) => (
            <motion.div key={title} className="lp-card" {...fadeUp}>
              <span className="lp-icon" aria-hidden="true"><Icon size={20} /></span>
              <h3>{title}</h3>
              <p>{text}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── FAQ ── */
const FAQS = [
  { q: 'Do I need to speak or hear to use MediFind?', a: 'No. You raise an SOS with taps, receive flashing and vibration alerts, and communicate with your responder by text. Deaf mode also tells the responder to use text only.' },
  { q: 'What happens if I press SOS by mistake?', a: 'You have 60 seconds to cancel before the alert is treated as a real emergency. Cancelling notifies anyone who was already alerted.' },
  { q: 'Who responds to my emergency?', a: 'Verified responders — paramedics, rescue officers and trained volunteers on motorbike ambulances. Their documents are reviewed by MediFind before they can respond.' },
  { q: 'Is MediFind free?', a: 'Yes, raising an SOS is available on the Free plan. Optional Pro and Executive plans add extras such as extended history.' },
  { q: 'Can my family see where help is?', a: 'Yes. Caregivers linked to your account are notified when you raise an SOS and can follow the responder on a live map.' },
  { q: 'How do I become a responder?', a: 'Register as a responder in the MediFind app and upload your CNIC, license and employee ID. Our team reviews every application and emails you the result.' },
];

function Faq() {
  const [openIdx, setOpenIdx] = useState(0);
  return (
    <section id="faq" className="lp-section lp-section-alt" aria-labelledby="faq-title">
      <div className="lp-container">
        <div className="lp-section-head center">
          <span className="lp-eyebrow">FAQ</span>
          <h2 id="faq-title">Questions, answered.</h2>
        </div>
        <div className="lp-faq">
          {FAQS.map((item, i) => {
            const open = openIdx === i;
            return (
              <div key={item.q} className="lp-faq-item">
                <h3 style={{ margin: 0 }}>
                  <button
                    type="button"
                    className="lp-faq-q"
                    aria-expanded={open}
                    aria-controls={`faq-panel-${i}`}
                    id={`faq-q-${i}`}
                    onClick={() => setOpenIdx(open ? -1 : i)}
                  >
                    {item.q}
                    <ChevronDown size={20} aria-hidden="true" />
                  </button>
                </h3>
                <div id={`faq-panel-${i}`} role="region" aria-labelledby={`faq-q-${i}`} hidden={!open} className="lp-faq-a">
                  <p>{item.a}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

/* ── Contact (opens the visitor's email app — nothing is sent from this page) ── */
function Contact() {
  const [form, setForm] = useState({ name: '', email: '', message: '' });
  const [errors, setErrors] = useState({});
  const [opened, setOpened] = useState(false);

  const update = (key) => (e) => {
    setForm(f => ({ ...f, [key]: e.target.value }));
    setErrors(er => ({ ...er, [key]: undefined }));
  };

  const submit = (e) => {
    e.preventDefault();
    const next = {};
    if (!form.name.trim()) next.name = 'Please enter your name.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) next.email = 'Please enter a valid email address.';
    if (!form.message.trim()) next.message = 'Please write a message.';
    setErrors(next);
    if (Object.keys(next).length) return;
    const subject = encodeURIComponent(`MediFind enquiry from ${form.name.trim()}`);
    const body = encodeURIComponent(`${form.message.trim()}\n\n— ${form.name.trim()} (${form.email.trim()})`);
    window.location.href = `mailto:${SUPPORT_EMAIL}?subject=${subject}&body=${body}`;
    setOpened(true);
  };

  return (
    <section id="contact" className="lp-section" aria-labelledby="contact-title">
      <div className="lp-container lp-contact">
        <div>
          <span className="lp-eyebrow"><Mail size={14} /> Contact</span>
          <h2 id="contact-title">Talk to the MediFind team.</h2>
          <p className="lp-lead">
            Partnerships, responder organisations or feedback from the Deaf community — we'd like to hear from you.
          </p>
          <p style={{ marginTop: 16 }}>
            Email us directly at <a href={`mailto:${SUPPORT_EMAIL}`} style={{ color: 'var(--primary)', fontWeight: 700 }}>{SUPPORT_EMAIL}</a>.
          </p>
          <p style={{ marginTop: 8, fontSize: '0.9rem' }}>
            This form is not for emergencies. In an emergency use the app or call <strong>Rescue 1122</strong>.
          </p>
        </div>
        <form className="lp-form lp-card" onSubmit={submit} noValidate>
          <div className="lp-form-row">
            <div className="lp-field">
              <label htmlFor="c-name">Name</label>
              <input id="c-name" autoComplete="name" value={form.name} onChange={update('name')} aria-invalid={!!errors.name} aria-describedby={errors.name ? 'c-name-err' : undefined} />
              {errors.name && <p id="c-name-err" className="lp-field-error">{errors.name}</p>}
            </div>
            <div className="lp-field">
              <label htmlFor="c-email">Email</label>
              <input id="c-email" type="email" autoComplete="email" value={form.email} onChange={update('email')} aria-invalid={!!errors.email} aria-describedby={errors.email ? 'c-email-err' : undefined} />
              {errors.email && <p id="c-email-err" className="lp-field-error">{errors.email}</p>}
            </div>
          </div>
          <div className="lp-field">
            <label htmlFor="c-message">Message</label>
            <textarea id="c-message" value={form.message} onChange={update('message')} aria-invalid={!!errors.message} aria-describedby={errors.message ? 'c-message-err' : undefined} />
            {errors.message && <p id="c-message-err" className="lp-field-error">{errors.message}</p>}
          </div>
          <button type="submit" className="lp-btn lp-btn-primary"><Mail size={18} /> Open in my email app</button>
          <p role="status" style={{ fontSize: '0.85rem' }}>
            {opened
              ? `Your email app should now be open with the message ready — press send there. If nothing opened, email ${SUPPORT_EMAIL}.`
              : 'This opens your own email app with the message filled in. Nothing is sent from this website.'}
          </p>
        </form>
      </div>
    </section>
  );
}

/* ── Final call-to-action ── */
function FinalCta() {
  return (
    <section className="lp-section" aria-labelledby="cta-title" style={{ paddingTop: 0 }}>
      <div className="lp-container">
        <div className="lp-card" style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: 20, padding: 'clamp(24px, 4vw, 40px)', background: 'var(--primary-pale)', borderColor: 'transparent' }}>
          <div style={{ maxWidth: 560 }}>
            <h2 id="cta-title" style={{ fontSize: 'clamp(1.4rem, 2.6vw, 1.9rem)' }}>Be ready before an emergency happens.</h2>
            <p style={{ marginTop: 8 }}>Set up your medical profile, emergency contacts and quick phrases once — MediFind handles the rest.</p>
          </div>
          <DownloadButton />
        </div>
      </div>
    </section>
  );
}

/* ── Footer ── */
const FOOTER_COLUMNS = [
  {
    title: 'Product',
    links: [
      { href: '#features', label: 'Features' },
      { href: '#deaf', label: 'For Deaf users' },
      { href: '#how', label: 'How it works' },
      { href: '#faq', label: 'FAQ' },
    ],
  },
  {
    title: 'Who it’s for',
    links: [
      { href: '#patients', label: 'Patients' },
      { href: '#caregivers', label: 'Caregivers' },
      { href: '#responders', label: 'Responders' },
    ],
  },
  {
    title: 'Support',
    links: [
      { href: '#contact', label: 'Contact us' },
      { href: `mailto:${SUPPORT_EMAIL}`, label: SUPPORT_EMAIL, Icon: Mail },
      { to: '/login', label: 'Admin login' },
    ],
  },
];

function SiteFooter() {
  const year = new Date().getFullYear();
  return (
    <footer className="lp-footer">
      <div className="lp-container">
        <div className="lp-footer-grid">
          <div className="lp-footer-brand">
            <Link to="/" className="lp-logo lp-logo-badge" aria-label="MediFind home">
              <img src={appMark} alt="" width="34" height="34" /><span>Medi<b>Find</b></span>
            </Link>
            <p>Deaf-first medical emergency response for Pakistan — verified motorbike ambulances, live tracking and text-based help.</p>
            <p className="lp-emergency-note"><PhoneCall size={15} /> Emergency? Call Rescue 1122</p>
          </div>
          {FOOTER_COLUMNS.map(col => (
            <nav key={col.title} aria-label={col.title}>
              <h3>{col.title}</h3>
              <ul>
                {col.links.map(l => (
                  <li key={l.label}>
                    {l.to
                      ? <Link to={l.to}>{l.label}</Link>
                      : <a href={l.href}>{l.Icon && <l.Icon size={14} aria-hidden="true" />}{l.label}</a>}
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>
        <div className="lp-footer-bottom">
          <span>© {year} MediFind. All rights reserved.</span>
          <nav className="lp-footer-legal" aria-label="Legal">
            <Link to="/privacy">Privacy Policy</Link>
            <Link to="/terms">Terms of Service</Link>
          </nav>
        </div>
      </div>
    </footer>
  );
}

export default function LandingPage() {
  return (
    <MotionConfig reducedMotion="user">
      <div className="lp">
        <a className="lp-skip" href="#main">Skip to content</a>
        <SiteHeader />
        <main id="main">
          <Hero />
          <DeafSection />
          <HowItWorks />
          <Features />
          <Roles />
          <Trust />
          <Faq />
          <Contact />
          <FinalCta />
        </main>
        <SiteFooter />
      </div>
    </MotionConfig>
  );
}

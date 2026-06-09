import React, { useState, useEffect, useRef } from 'react';
import {
  Zap, MapPin, FileText, Users, Lock, ArrowRight,
  Phone, Heart, Truck, User, Shield, Activity, Clock,
  CheckCircle, Star, MessageSquare, Bell, BarChart3,
  Download, Play, HeartPulse, ChevronDown, Menu, X,
  Mic, Eye, Smartphone, UserPlus, ChevronUp
} from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAlert } from '../context/AlertContext';
import logo from '../assets/Medifind_New_Logo-removebg-preview.png';
import heroMockup from '../assets/medifind_bento_hero_1776705879322.png';

const P = 'Poppins, sans-serif';

/* ─── Update this constant when the app goes live on Play Store ─── */
const PLAY_STORE_URL = '#'; // TODO: replace with real Play Store link

/* ── Animated Counter ─────────────────────────────────────────── */
const Counter = ({ end, suffix = '', prefix = '' }) => {
  const [count, setCount] = useState(0);
  const ref = useRef(null);
  const started = useRef(false);
  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting && !started.current) {
        started.current = true;
        let s = 0;
        const step = end / 80;
        const timer = setInterval(() => {
          s += step;
          if (s >= end) { setCount(end); clearInterval(timer); }
          else setCount(Math.floor(s));
        }, 20);
      }
    }, { threshold: 0.3 });
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, [end]);
  return <span ref={ref}>{prefix}{count.toLocaleString()}{suffix}</span>;
};

/* ── Animation Variants ────────────────────────────────────────── */
const fadeInUp = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }
};
const staggerContainer = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.12 } }
};
const float = {
  animate: { y: [0, -15, 0], transition: { duration: 4, repeat: Infinity, ease: 'easeInOut' } }
};
const FadeIn = ({ children, delay = 0 }) => (
  <motion.div
    initial="hidden" whileInView="visible"
    viewport={{ once: true, margin: '-100px' }}
    variants={fadeInUp} transition={{ delay: delay / 1000 }}
  >{children}</motion.div>
);

/* ── Contact Form ─────────────────────────────────────────────── */
const ContactForm = () => {
  const { showAlert } = useAlert();
  const [form, setForm] = useState({ name: '', email: '', role: '', message: '' });
  const [submitted, setSubmitted] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const validate = () => {
    const e = {};
    if (!form.name.trim()) e.name = 'Required';
    if (!form.email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) e.email = 'Valid email required';
    if (!form.message.trim()) e.message = 'Required';
    return e;
  };
  const handleSubmit = (ev) => {
    ev.preventDefault();
    const e = validate();
    if (Object.keys(e).length > 0) { setErrors(e); return; }
    setLoading(true);
    setTimeout(() => {
      setLoading(false); setSubmitted(true);
      showAlert('Message sent successfully! Our team will contact you soon.', 'success');
    }, 800);
  };
  if (submitted) return (
    <div style={{ textAlign: 'center', padding: '3rem 2rem', fontFamily: P }}>
      <div style={{ width: '68px', height: '68px', borderRadius: '50%', background: 'linear-gradient(135deg,#0C637E,#2891C2)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.5rem' }}>
        <CheckCircle size={30} color="white" />
      </div>
      <h3 style={{ fontSize: '1.35rem', color: '#0C637E', fontWeight: 700, marginBottom: '0.6rem', fontFamily: P }}>Message Received!</h3>
      <p style={{ color: '#64748B', fontSize: '0.9rem', fontFamily: P }}>We'll get back to you within 24 hours.</p>
    </div>
  );
  const fieldStyle = (name) => ({
    width: '100%', padding: '0.8rem 1rem', borderRadius: '10px',
    border: `1.5px solid ${errors[name] ? '#EF4444' : '#E2E8F0'}`,
    background: '#F8FAFC', fontSize: '0.875rem', outline: 'none',
    fontFamily: P, color: '#1E293B', transition: 'border-color 0.2s',
    boxSizing: 'border-box', fontWeight: 400,
  });
  return (
    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', fontFamily: P }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
        <div>
          <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="Full Name *" style={fieldStyle('name')} />
          {errors.name && <p style={{ color: '#EF4444', fontSize: '0.72rem', marginTop: '4px', fontWeight: 500 }}>{errors.name}</p>}
        </div>
        <div>
          <input value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} placeholder="Email Address *" type="email" style={fieldStyle('email')} />
          {errors.email && <p style={{ color: '#EF4444', fontSize: '0.72rem', marginTop: '4px', fontWeight: 500 }}>{errors.email}</p>}
        </div>
      </div>
      <select value={form.role} onChange={e => setForm({ ...form, role: e.target.value })}
        style={{ ...fieldStyle('role'), color: form.role ? '#1E293B' : '#94A3B8' }}>
        <option value="">I am a... (select role)</option>
        <option value="patient">Patient / Individual</option>
        <option value="responder">Emergency Responder</option>
        <option value="caregiver">Caregiver / Family</option>
        <option value="organization">Healthcare Organization</option>
      </select>
      <div>
        <textarea value={form.message} onChange={e => setForm({ ...form, message: e.target.value })}
          placeholder="Your message *" rows={4}
          style={{ ...fieldStyle('message'), resize: 'vertical', minHeight: '110px' }} />
        {errors.message && <p style={{ color: '#EF4444', fontSize: '0.72rem', marginTop: '4px', fontWeight: 500 }}>{errors.message}</p>}
      </div>
      <button type="submit" disabled={loading}
        style={{ width: '100%', padding: '0.9rem', borderRadius: '10px', background: 'linear-gradient(135deg,#0C637E,#2496A7)', color: 'white', fontWeight: 600, fontSize: '0.9rem', border: 'none', cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.8 : 1, fontFamily: P, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', letterSpacing: '0.01em' }}>
        {loading ? 'Sending...' : <><span>Send Message</span><ArrowRight size={15} /></>}
      </button>
    </form>
  );
};

/* ── Badge Pill ───────────────────────────────────────────────── */
const Badge = ({ icon: Icon, label, bg = '#E2F0F3', color = '#0C637E' }) => (
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem', padding: '0.35rem 0.9rem', background: bg, borderRadius: '100px', marginBottom: '1.25rem' }}>
    {Icon && <Icon size={12} color={color} />}
    <span style={{ fontSize: '0.7rem', fontWeight: 600, color, textTransform: 'uppercase', letterSpacing: '0.09em', fontFamily: P }}>{label}</span>
  </div>
);

/* ── Section Heading ──────────────────────────────────────────── */
const SectionHead = ({ badge, badgeBg, badgeColor, badgeIcon, title, sub, light = false }) => (
  <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
    <Badge icon={badgeIcon} label={badge} bg={badgeBg} color={badgeColor} />
    <h2 style={{ fontSize: '2rem', fontWeight: 700, color: light ? 'white' : '#0F172A', marginBottom: '0.75rem', fontFamily: P, lineHeight: 1.25 }}>{title}</h2>
    {sub && <p style={{ fontSize: '0.95rem', color: light ? 'rgba(255,255,255,0.75)' : '#64748B', maxWidth: '520px', margin: '0 auto', lineHeight: 1.75, fontFamily: P, fontWeight: 400 }}>{sub}</p>}
  </div>
);

/* ── Play Store Badge Button ──────────────────────────────────── */
const StoreButton = ({ store, available, href, roleColor }) => {
  const isAndroid = store === 'android';
  return (
    <a
      href={available ? href : undefined}
      target={available ? '_blank' : undefined}
      rel="noopener noreferrer"
      aria-label={isAndroid ? 'Download on Google Play' : 'Download on App Store (Coming Soon)'}
      style={{
        display: 'flex', alignItems: 'center', gap: '0.85rem',
        padding: '0.85rem 1.25rem', borderRadius: '14px',
        background: available ? 'white' : 'rgba(255,255,255,0.12)',
        textDecoration: 'none', cursor: available ? 'pointer' : 'default',
        border: available ? 'none' : '1px solid rgba(255,255,255,0.2)',
        opacity: available ? 1 : 0.65,
        transition: 'transform 0.2s, box-shadow 0.2s',
        position: 'relative', overflow: 'hidden',
      }}
      onMouseEnter={e => { if (available) { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.15)'; }}}
      onMouseLeave={e => { e.currentTarget.style.transform = 'none'; e.currentTarget.style.boxShadow = 'none'; }}
    >
      {/* Icon */}
      <div style={{ width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {isAndroid ? (
          /* Play Store triangle icon */
          <svg viewBox="0 0 24 24" width="28" height="28">
            <defs>
              <linearGradient id="pg1" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#00BCD4"/>
                <stop offset="100%" stopColor="#00E676"/>
              </linearGradient>
            </defs>
            <path d="M3 20.5v-17c0-.83 1.008-1.28 1.6-.67l14 8.5c.53.32.53 1.02 0 1.34L4.6 21.17C4.008 21.78 3 21.33 3 20.5z" fill="url(#pg1)" />
          </svg>
        ) : (
          /* Apple logo */
          <svg viewBox="0 0 24 24" width="26" height="26" fill={available ? '#1E293B' : 'white'}>
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
          </svg>
        )}
      </div>
      {/* Text */}
      <div style={{ textAlign: 'left' }}>
        <div style={{ fontSize: '0.6rem', fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: available ? '#64748B' : 'rgba(255,255,255,0.6)', fontFamily: P }}>
          {available ? (isAndroid ? 'GET IT ON' : 'DOWNLOAD ON THE') : 'COMING SOON'}
        </div>
        <div style={{ fontSize: '0.95rem', fontWeight: 700, color: available ? '#0F172A' : 'white', fontFamily: P, lineHeight: 1.2 }}>
          {isAndroid ? 'Google Play' : 'App Store'}
        </div>
      </div>
      {/* Coming Soon ribbon */}
      {!available && (
        <div style={{ position: 'absolute', top: '8px', right: '-18px', background: 'rgba(255,255,255,0.25)', color: 'white', fontSize: '0.55rem', fontWeight: 700, padding: '2px 20px', transform: 'rotate(35deg)', letterSpacing: '0.08em', fontFamily: P }}>
          SOON
        </div>
      )}
    </a>
  );
};

/* ── Ecosystem Phone Screen Placeholder ───────────────────────
   Renders a simplified CSS-drawn app screen inside the phone
   mockup for each mobile role. Replaced by a real <img> once
   Flutter screenshots are exported and imported at the top.
   Props:
     type   — "primary" | "secondary"
     color  — role accent hex  (e.g. "#0C637E")
     gradient — CSS gradient string
     role   — "Patient" | "Caregiver" | "Responder"
─────────────────────────────────────────────────────────────── */
const EcosystemScreenPlaceholder = ({ type, color, gradient, role }) => {
  /* Shared micro-layout helpers */
  const bar = (w = '60%', h = 6, bg = '#E2E8F0', r = 3) => (
    <div style={{ width: w, height: h, borderRadius: r, background: bg, flexShrink: 0 }} />
  );
  const avatar = (letter, bg, fg, size = 24) => (
    <div style={{ width: size, height: size, borderRadius: '50%', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <span style={{ fontSize: size * 0.4, fontWeight: 700, color: fg, fontFamily: P }}>{letter}</span>
    </div>
  );
  const statusDot = (c) => (
    <div style={{ width: 7, height: 7, borderRadius: '50%', background: c, flexShrink: 0 }} />
  );

  /* ── PATIENT ─────────────────────────────────────────── */
  if (role === 'Patient') {
    if (type === 'primary') {
      /* Home / SOS screen */
      return (
        <div style={{ width: '100%', height: '100%', background: '#F8FAFC', display: 'flex', flexDirection: 'column', fontFamily: P }}>
          {/* Status bar */}
          <div style={{ height: 14, background: color, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 8, gap: 4 }}>
            {[1,0.7,0.4].map((o,i) => <div key={i} style={{ width: 3, height: 7+(i*2), borderRadius: 1, background: `rgba(255,255,255,${o})` }} />)}
          </div>
          {/* Header */}
          <div style={{ background: color, padding: '8px 10px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontSize: 7, color: 'rgba(255,255,255,0.65)', fontWeight: 600, marginBottom: 2 }}>MEDIFIND</div>
              <div style={{ fontSize: 9, color: 'white', fontWeight: 700 }}>Good morning! 👋</div>
            </div>
            <div style={{ width: 26, height: 26, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'white' }} />
            </div>
          </div>
          {/* Body */}
          <div style={{ flex: 1, padding: '10px 10px 6px', display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'center' }}>
            {/* SOS button */}
            <div style={{ marginTop: 4, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5 }}>
              {/* Outer pulse ring */}
              <div style={{ width: 72, height: 72, borderRadius: '50%', border: '3px solid #EF444430', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <div style={{ width: 58, height: 58, borderRadius: '50%', border: '2px solid #EF444450', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <div style={{ width: 46, height: 46, borderRadius: '50%', background: 'linear-gradient(135deg,#EF4444,#DC2626)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 14px rgba(239,68,68,0.5)' }}>
                    <span style={{ fontSize: 9, fontWeight: 800, color: 'white', letterSpacing: '0.05em' }}>SOS</span>
                  </div>
                </div>
              </div>
              <div style={{ fontSize: 7, color: '#94A3B8', fontWeight: 500 }}>Hold to trigger emergency</div>
            </div>
            {/* Quick info cards */}
            <div style={{ width: '100%', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 5 }}>
              {[
                { label: 'Blood Type', value: 'A+', bg: '#FEF2F2', c: '#EF4444' },
                { label: 'Caregiver', value: 'Linked', bg: '#ECFDF5', c: '#10B981' },
              ].map(card => (
                <div key={card.label} style={{ background: card.bg, borderRadius: 8, padding: '5px 6px' }}>
                  <div style={{ fontSize: 6, color: '#94A3B8', marginBottom: 2 }}>{card.label}</div>
                  <div style={{ fontSize: 8, fontWeight: 700, color: card.c }}>{card.value}</div>
                </div>
              ))}
            </div>
            {/* Bottom nav */}
            <div style={{ width: '100%', marginTop: 'auto', borderTop: '1px solid #F1F5F9', paddingTop: 6, display: 'flex', justifyContent: 'space-around' }}>
              {['⚡','📋','👥','👤'].map((icon,i) => (
                <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                  <div style={{ fontSize: 11 }}>{icon}</div>
                  <div style={{ width: i === 0 ? 16 : 0, height: 2, borderRadius: 1, background: color }} />
                </div>
              ))}
            </div>
          </div>
        </div>
      );
    } else {
      /* Secondary — Live tracking screen */
      return (
        <div style={{ width: '100%', height: '100%', background: '#E8F4F8', display: 'flex', flexDirection: 'column', fontFamily: P, position: 'relative' }}>
          {/* Map placeholder */}
          <div style={{ flex: 1, background: `linear-gradient(135deg, ${color}10, ${color}05)`, position: 'relative', overflow: 'hidden' }}>
            {/* Road lines */}
            <div style={{ position: 'absolute', top: '30%', left: 0, right: 0, height: 2, background: 'rgba(255,255,255,0.6)', transform: 'rotate(-8deg)' }} />
            <div style={{ position: 'absolute', top: '55%', left: 0, right: 0, height: 2, background: 'rgba(255,255,255,0.6)', transform: 'rotate(5deg)' }} />
            {/* Responder pin */}
            <div style={{ position: 'absolute', top: '22%', left: '35%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ width: 18, height: 18, borderRadius: '50% 50% 50% 0', background: '#10B981', transform: 'rotate(-45deg)', border: '2px solid white', boxShadow: '0 2px 6px rgba(0,0,0,0.3)' }} />
              <div style={{ fontSize: 6, color: '#10B981', fontWeight: 700, marginTop: 2, background: 'white', padding: '1px 4px', borderRadius: 3 }}>Resp.</div>
            </div>
            {/* Patient pin */}
            <div style={{ position: 'absolute', top: '48%', left: '58%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ width: 14, height: 14, borderRadius: '50%', background: color, border: '2px solid white', boxShadow: '0 2px 6px rgba(0,0,0,0.3)' }} />
              <div style={{ fontSize: 6, color: color, fontWeight: 700, marginTop: 2, background: 'white', padding: '1px 4px', borderRadius: 3 }}>You</div>
            </div>
            {/* Route line */}
            <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} viewBox="0 0 100 100" preserveAspectRatio="none">
              <path d="M 43 30 Q 55 45 62 56" stroke={color} strokeWidth="1.5" fill="none" strokeDasharray="3,2" opacity="0.6" />
            </svg>
          </div>
          {/* Bottom card */}
          <div style={{ background: 'white', padding: '8px 10px', borderRadius: '12px 12px 0 0', marginTop: -10, boxShadow: '0 -4px 12px rgba(0,0,0,0.08)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5 }}>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: '#ECFDF5', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span style={{ fontSize: 11 }}>🚑</span>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 8, fontWeight: 700, color: '#0F172A' }}>Responder On the Way</div>
                <div style={{ fontSize: 7, color: '#10B981', fontWeight: 600 }}>ETA: 3 min 42 sec</div>
              </div>
            </div>
            {bar('100%', 4, `${color}20`)}
            <div style={{ width: '45%', height: 4, borderRadius: 3, background: color, marginTop: -4 }} />
          </div>
        </div>
      );
    }
  }

  /* ── CAREGIVER ───────────────────────────────────────── */
  if (role === 'Caregiver') {
    if (type === 'primary') {
      /* My Patients list */
      return (
        <div style={{ width: '100%', height: '100%', background: '#EBF5FB', display: 'flex', flexDirection: 'column', fontFamily: P }}>
          <div style={{ height: 14, background: color, display: 'flex', alignItems: 'center', paddingLeft: 8 }}>
            <div style={{ fontSize: 6, color: 'rgba(255,255,255,0.85)', fontWeight: 700 }}>MEDIFIND — CAREGIVER</div>
          </div>
          <div style={{ background: color, padding: '8px 10px 14px' }}>
            <div style={{ fontSize: 9, color: 'white', fontWeight: 700, marginBottom: 2 }}>My Patients</div>
            <div style={{ fontSize: 7, color: 'rgba(255,255,255,0.65)' }}>3 linked · all monitored</div>
          </div>
          <div style={{ flex: 1, padding: '8px 8px', display: 'flex', flexDirection: 'column', gap: 6 }}>
            {[
              { name: 'Patient A', status: 'Safe', dot: '#10B981', bg: '#ECFDF5', alert: false },
              { name: 'Patient B', status: 'SOS Active!', dot: '#EF4444', bg: '#FEF2F2', alert: true },
              { name: 'Patient C',  status: 'Safe', dot: '#10B981', bg: '#ECFDF5', alert: false },
            ].map((p, i) => (
              <div key={i} style={{ background: 'white', borderRadius: 10, padding: '7px 8px', display: 'flex', alignItems: 'center', gap: 7, border: `1.5px solid ${p.alert ? '#EF444430' : '#F1F5F9'}`, boxShadow: p.alert ? '0 2px 10px rgba(239,68,68,0.12)' : 'none' }}>
                {avatar(p.name[0], p.alert ? '#FEF2F2' : '#E2F0F3', p.alert ? '#EF4444' : color, 24)}
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 7.5, fontWeight: 700, color: '#0F172A' }}>{p.name}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 3, marginTop: 1 }}>
                    {statusDot(p.dot)}
                    <span style={{ fontSize: 6.5, color: p.dot, fontWeight: 600 }}>{p.status}</span>
                  </div>
                </div>
                {p.alert && (
                  <div style={{ background: '#EF4444', borderRadius: 6, padding: '2px 5px' }}>
                    <span style={{ fontSize: 6, color: 'white', fontWeight: 700 }}>LIVE</span>
                  </div>
                )}
              </div>
            ))}
            {/* Bottom nav */}
            <div style={{ marginTop: 'auto', borderTop: '1px solid #F1F5F9', paddingTop: 6, display: 'flex', justifyContent: 'space-around' }}>
              {['👥','🗺️','📋','👤'].map((icon,i) => (
                <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                  <div style={{ fontSize: 11 }}>{icon}</div>
                  <div style={{ width: i === 0 ? 16 : 0, height: 2, borderRadius: 1, background: color }} />
                </div>
              ))}
            </div>
          </div>
        </div>
      );
    } else {
      /* Secondary — Emergency monitor map */
      return (
        <div style={{ width: '100%', height: '100%', background: '#EBF5FB', display: 'flex', flexDirection: 'column', fontFamily: P }}>
          {/* Alert banner */}
          <div style={{ background: '#EF4444', padding: '7px 10px', display: 'flex', alignItems: 'center', gap: 5 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'rgba(255,255,255,0.5)', animation: 'pulse 1s infinite' }} />
            <span style={{ fontSize: 7, color: 'white', fontWeight: 700 }}>⚠ EMERGENCY · Patient B triggered SOS</span>
          </div>
          {/* Map */}
          <div style={{ flex: 1, background: `linear-gradient(135deg, ${color}08, #F59E0B08)`, position: 'relative' }}>
            <div style={{ position: 'absolute', top: '20%', left: '30%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ width: 14, height: 14, borderRadius: '50% 50% 50% 0', background: '#EF4444', transform: 'rotate(-45deg)', border: '2px solid white', boxShadow: '0 2px 6px rgba(239,68,68,0.5)' }} />
              <div style={{ fontSize: 6, color: '#EF4444', fontWeight: 700, marginTop: 2, background: 'white', padding: '1px 4px', borderRadius: 3 }}>Patient</div>
            </div>
            <div style={{ position: 'absolute', top: '45%', left: '55%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#10B981', border: '2px solid white', boxShadow: '0 2px 6px rgba(16,185,129,0.5)' }} />
              <div style={{ fontSize: 6, color: '#10B981', fontWeight: 700, marginTop: 2, background: 'white', padding: '1px 4px', borderRadius: 3 }}>Resp.</div>
            </div>
          </div>
          {/* Bottom info */}
          <div style={{ background: 'white', padding: '7px 9px', borderTop: '1px solid #BFDBF7' }}>
            <div style={{ fontSize: 7, fontWeight: 700, color: '#1A5276', marginBottom: 3 }}>Responder assigned — ETA 5 min</div>
            <div style={{ display: 'flex', gap: 4 }}>
              {bar('50%', 4, '#FDE68A')}
              {bar('30%', 4, '#FCA5A5')}
            </div>
          </div>
        </div>
      );
    }
  }

  /* ── RESPONDER ───────────────────────────────────────── */
  if (role === 'Responder') {
    if (type === 'primary') {
      /* Responder dashboard */
      return (
        <div style={{ width: '100%', height: '100%', background: '#F0F9FB', display: 'flex', flexDirection: 'column', fontFamily: P }}>
          <div style={{ height: 14, background: color, display: 'flex', alignItems: 'center', paddingLeft: 8 }}>
            <div style={{ fontSize: 6, color: 'rgba(255,255,255,0.85)', fontWeight: 700 }}>MEDIFIND — RESPONDER</div>
          </div>
          <div style={{ background: color, padding: '8px 10px 14px' }}>
            <div style={{ fontSize: 9, color: 'white', fontWeight: 700 }}>Welcome, Responder!</div>
            <div style={{ fontSize: 7, color: 'rgba(255,255,255,0.65)', marginTop: 1 }}>Lahore · Verified Paramedic</div>
          </div>
          <div style={{ flex: 1, padding: '8px 8px', display: 'flex', flexDirection: 'column', gap: 7 }}>
            {/* Availability toggle */}
            <div style={{ background: 'white', borderRadius: 10, padding: '8px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', border: '1.5px solid #D1FAE5' }}>
              <div>
                <div style={{ fontSize: 8, fontWeight: 700, color: '#0F172A' }}>Availability</div>
                <div style={{ fontSize: 7, color: '#10B981', fontWeight: 600 }}>● Currently Available</div>
              </div>
              {/* Toggle pill */}
              <div style={{ width: 32, height: 18, borderRadius: 9, background: '#10B981', padding: '2px', display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
                <div style={{ width: 14, height: 14, borderRadius: '50%', background: 'white' }} />
              </div>
            </div>
            {/* Stats row */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 5 }}>
              {[
                { label: 'Responses', value: '47', color: color },
                { label: 'Avg Time',  value: '3.8m', color: '#F59E0B' },
                { label: 'Rating',    value: '4.9★', color: '#EF4444' },
              ].map(s => (
                <div key={s.label} style={{ background: 'white', borderRadius: 8, padding: '6px 5px', textAlign: 'center', border: '1px solid #E2E8F0' }}>
                  <div style={{ fontSize: 9, fontWeight: 800, color: s.color }}>{s.value}</div>
                  <div style={{ fontSize: 5.5, color: '#94A3B8', fontWeight: 500 }}>{s.label}</div>
                </div>
              ))}
            </div>
            {/* Nearby emergencies */}
            <div style={{ background: 'white', borderRadius: 10, padding: '7px 9px', border: '1px solid #E2E8F0' }}>
              <div style={{ fontSize: 7, fontWeight: 700, color: '#0F172A', marginBottom: 5 }}>Nearby Emergencies</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                <div style={{ width: 24, height: 24, borderRadius: 7, background: '#FEF2F2', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span style={{ fontSize: 10 }}>🚨</span>
                </div>
                <div>
                  <div style={{ fontSize: 7, fontWeight: 700, color: '#EF4444' }}>1 Active SOS nearby</div>
                  <div style={{ fontSize: 6, color: '#94A3B8' }}>1.2 km · Gulberg, Lahore</div>
                </div>
              </div>
            </div>
            {/* Bottom nav */}
            <div style={{ marginTop: 'auto', borderTop: '1px solid #F1F5F9', paddingTop: 5, display: 'flex', justifyContent: 'space-around' }}>
              {['🏠','🗺️','📋','👤'].map((icon,i) => (
                <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                  <div style={{ fontSize: 11 }}>{icon}</div>
                  <div style={{ width: i === 0 ? 16 : 0, height: 2, borderRadius: 1, background: color }} />
                </div>
              ))}
            </div>
          </div>
        </div>
      );
    } else {
      /* Secondary — Incoming emergency request */
      return (
        <div style={{ width: '100%', height: '100%', background: '#F0F9FB', display: 'flex', flexDirection: 'column', fontFamily: P, position: 'relative' }}>
          {/* Dimmed background */}
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1 }} />
          {/* Request card */}
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'white', borderRadius: '18px 18px 0 0', padding: '12px 12px 14px', zIndex: 2 }}>
            {/* Alert header */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
              <div style={{ width: 30, height: 30, borderRadius: 9, background: '#FEF2F2', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span style={{ fontSize: 14 }}>🚨</span>
              </div>
              <div>
                <div style={{ fontSize: 8.5, fontWeight: 800, color: '#EF4444' }}>INCOMING EMERGENCY</div>
                <div style={{ fontSize: 7, color: '#64748B' }}>You have 30 seconds to respond</div>
              </div>
            </div>
            {/* Patient info */}
            <div style={{ background: '#F8FAFC', borderRadius: 9, padding: '7px 8px', marginBottom: 7 }}>
              {[
                { label: 'Patient', value: 'Anonymous' },
                { label: 'Blood Type', value: 'A+' },
                { label: 'Distance', value: '1.2 km away' },
              ].map(row => (
                <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                  <span style={{ fontSize: 6.5, color: '#94A3B8', fontWeight: 500 }}>{row.label}</span>
                  <span style={{ fontSize: 6.5, color: '#0F172A', fontWeight: 700 }}>{row.value}</span>
                </div>
              ))}
            </div>
            {/* Action buttons */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
              <div style={{ background: '#FEF2F2', borderRadius: 8, padding: '6px', textAlign: 'center' }}>
                <div style={{ fontSize: 7.5, fontWeight: 700, color: '#EF4444' }}>✕ Reject</div>
              </div>
              <div style={{ background: '#10B981', borderRadius: 8, padding: '6px', textAlign: 'center' }}>
                <div style={{ fontSize: 7.5, fontWeight: 700, color: 'white' }}>✓ Accept</div>
              </div>
            </div>
          </div>
        </div>
      );
    }
  }

  /* Fallback — should never reach here */
  return <div style={{ width: '100%', height: '100%', background: '#F1F5F9' }} />;
};

/* ══════════════════════════════════════════════════════════════
   Main Landing Page
══════════════════════════════════════════════════════════════ */
const LandingPage = () => {
  const [openFaq, setOpenFaq] = useState(null);
  const [scrolled, setScrolled] = useState(false);
  const [activeRole, setActiveRole] = useState('Patient');
  const [activeSection, setActiveSection] = useState('');
  const [showBackToTop, setShowBackToTop] = useState(false);
  const [activeEcosystem, setActiveEcosystem] = useState('Patient');

  /* scroll-based effects */
  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 60);
      setShowBackToTop(window.scrollY > 500);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  /* active nav section tracking via IntersectionObserver */
  useEffect(() => {
    const sectionIds = ['about', 'features', 'how-it-works', 'solutions', 'ecosystem', 'get-started', 'contact'];
    const observers = sectionIds.map(id => {
      const el = document.getElementById(id);
      if (!el) return null;
      const obs = new IntersectionObserver(
        ([entry]) => { if (entry.isIntersecting) setActiveSection(id); },
        { threshold: 0.25 }
      );
      obs.observe(el);
      return obs;
    }).filter(Boolean);
    return () => observers.forEach(obs => obs.disconnect());
  }, []);

  /* ── Static data ─────────────────────────────────────────── */
  const features = [
    { icon: Zap,          title: 'Instant SOS',               desc: 'One-tap emergency alert reaches all nearby verified responders within seconds.',                                               color: '#DC2626', bg: '#FEF2F2' },
    { icon: MapPin,       title: 'Live GPS Tracking',          desc: 'Real-time responder location on an interactive map so you always know when help arrives.',                                     color: '#0C637E', bg: '#E2F0F3' },
    { icon: FileText,     title: 'Medical Profile Sharing',    desc: 'Blood type, allergies, medications — instantly delivered to incoming responders.',                                             color: '#2496A7', bg: '#E0F4F7' },
    { icon: Heart,        title: 'Caregiver Alerts',           desc: 'Family members receive live push notifications and a map view the moment an SOS is triggered.',                               color: '#2891C2', bg: '#EBF5FB' },
    { icon: Mic,          title: 'Silent SOS for Deaf Users',  desc: 'Icon-driven, voice-free emergency interface built specifically for Deaf and Mute patients.',                                  color: '#03293C', bg: '#E2F0F3' },
    { icon: Lock,         title: 'End-to-End Encryption',      desc: 'All communications and medical data are encrypted at rest and in transit.',                                                   color: '#0E6E82', bg: '#D9EDF1' },
  ];

  const steps = [
    { num: '01', icon: Zap,         title: 'Trigger SOS',         desc: 'One tap sends your GPS coordinates and medical snapshot to our dispatch network.',    color: '#DC2626' },
    { num: '02', icon: Bell,        title: 'Responders Notified',  desc: 'Nearest verified responders are alerted with your location and condition summary.',   color: '#0C637E' },
    { num: '03', icon: MapPin,      title: 'Live Tracking',        desc: 'You and your caregivers watch the responder navigate to you on a live map.',          color: '#2496A7' },
    { num: '04', icon: CheckCircle, title: 'Resolution & Report',  desc: 'Responder confirms arrival, logs the outcome. Your caregiver gets notified.',        color: '#2891C2' },
  ];

  const roles = [
    {
      icon: User,      title: 'For Patients',       gradient: 'linear-gradient(135deg,#0C637E,#2496A7)',
      headline: 'Help is One Tap Away',
      desc: "No calls. No delays. Whether you speak or not, MediFind's inclusive SOS works for everyone — including Deaf and Mute users through our Silent Request feature.",
      points: ['One-tap SOS with instant GPS sharing', 'Silent Request for Deaf & Mute users', 'Medical profile auto-shared with responder', 'Live ETA tracking on map'],
    },
    {
      icon: Heart,     title: 'For Caregivers',     gradient: 'linear-gradient(135deg,#1A6FA5,#2891C2)',
      headline: 'Stay Connected to the People You Love',
      desc: 'Receive instant alerts the moment your patient triggers SOS. Track the responder live and stay informed at every step — without being physically there.',
      points: ['Instant push notification on SOS trigger', 'Live responder tracking on map', 'Real-time emergency status updates', 'Emergency history & outcome reports'],
    },
    {
      icon: HeartPulse, title: 'For Responders',    gradient: 'linear-gradient(135deg,#2496A7,#2891C2)',
      headline: 'Precision Emergency Dispatch',
      desc: 'Receive verified SOS signals with full patient context before you arrive. Smart routing means you are always the right person in the right place.',
      points: ['Smart dispatch with patient data preview', 'Voice-guided GPS navigation', 'Digital credential management', 'Emergency history & outcome logging'],
    },
    {
      icon: BarChart3, title: 'For Administrators', gradient: 'linear-gradient(135deg,#04364E,#0C637E)',
      headline: 'Total System Visibility',
      desc: 'Monitor every active emergency, verify responder credentials, and analyze performance — all from a single secure web dashboard.',
      points: ['Real-time emergency monitoring dashboard', 'Responder credential verification queue', 'User directory & subscription management', 'Immutable audit logs & analytics'],
    },
  ];

  const stats = [
    { value: 4,     suffix: ' min', prefix: '< ', label: 'Avg Response Time',   icon: Clock    },
    { value: 99.9,  suffix: '%',    prefix: '',   label: 'System Uptime',       icon: Activity },
    { value: 10000, suffix: '+',    prefix: '',   label: 'Registered Users',    icon: Users    },
    { value: 500,   suffix: '+',    prefix: '',   label: 'Verified Responders', icon: Shield   },
  ];

  const faqs = [
    { q: 'How are emergency responders verified?',     a: 'Every responder submits professional credentials — CNIC, license number, and employee ID — which are manually audited by our admin team before they can receive any SOS signals.' },
    { q: 'Does MediFind work for Deaf or Mute users?', a: 'Yes. Our "Silent Request" interface uses an icon-driven emergency protocol designed for non-verbal communication, with pre-written phrases and haptic feedback.' },
    { q: 'Where is my medical data stored?',           a: 'Your data is stored in localized encrypted databases. It is only shared temporarily during an active emergency event, then re-encrypted immediately after.' },
    { q: 'What happens if my GPS or internet is off?', a: 'MediFind caches your last known GPS location and queues the SOS signal for immediate transmission when connectivity restores. An offline banner keeps you informed.' },
    { q: 'Can I add family members as caregivers?',    a: 'Yes. Invite caregivers directly from the app. Once accepted, they receive real-time push notifications and a live map view every time you trigger an SOS.' },
  ];

  /* ── Get Started role data ───────────────────────────────── */
  const getStartedData = {
    Patient: {
      color: '#0C637E',
      gradient: 'linear-gradient(135deg,#0C637E,#2496A7)',
      lightBg: '#E2F0F3',
      icon: User,
      tagline: 'Get protected in under 3 minutes',
      steps: [
        {
          icon: Download,
          title: 'Download the MediFind App',
          desc: 'Get the free app from Google Play Store. No credit card or subscription needed to get started.',
        },
        {
          icon: UserPlus,
          title: 'Register as a Patient',
          desc: 'Tap "Register" on the welcome screen, select "Patient" as your role, then fill in your full name, email address, phone number and a secure password.',
        },
        {
          icon: Smartphone,
          title: 'Choose Your Patient Mode',
          desc: 'MediFind offers two interface modes for patients. You will be prompted to select one during registration — pick the one that suits you best.',
          modes: [
            {
              icon: User,
              label: 'Standard Mode',
              color: '#0C637E',
              bg: '#E2F0F3',
              tag: 'Default',
              features: [
                'Voice + touch SOS interface',
                'Audio countdown & spoken alerts',
                'Standard SOS button with timer',
                'Full audio guidance throughout',
              ],
            },
            {
              icon: Mic,
              label: 'Deaf & Mute Mode',
              color: '#8B5CF6',
              bg: '#F5F3FF',
              tag: 'Inclusive',
              features: [
                'Icon-only, completely voice-free',
                'Silent SOS — haptic + screen flash',
                'Pre-written message shortcuts',
                'Visual-only alerts, zero audio',
              ],
            },
          ],
        },
        {
          icon: FileText,
          title: 'Build Your Medical Profile',
          desc: 'Add your blood type, chronic conditions, allergies, current medications and emergency contacts. This information is shared with your assigned responder the moment you trigger SOS — helping them treat you faster.',
          note: 'This step is optional but strongly recommended. A complete profile can be life-saving.',
        },
        {
          icon: Shield,
          title: "You're Protected — Use MediFind",
          desc: 'Tap the large SOS button any time you need emergency help. MediFind will connect you to a verified responder in your area within minutes.',
        },
      ],
    },
    Caregiver: {
      color: '#1A6FA5',
      gradient: 'linear-gradient(135deg,#1A6FA5,#2891C2)',
      lightBg: '#EBF5FB',
      icon: Heart,
      tagline: 'Start watching over your loved ones today',
      steps: [
        {
          icon: Download,
          title: 'Download the MediFind App',
          desc: 'Get the free app from Google Play Store. Available on all Android devices.',
        },
        {
          icon: UserPlus,
          title: 'Register as a Caregiver',
          desc: 'Tap "Register", select "Caregiver" as your role, then provide your name, email, phone number and a password.',
        },
        {
          icon: Bell,
          title: 'Wait for a Patient Invitation',
          desc: 'Ask the person you care for to open MediFind, go to their "Caregivers" tab, and send you an invitation using the email address you registered with.',
          note: 'The patient must have an active MediFind account to send you an invitation.',
        },
        {
          icon: CheckCircle,
          title: 'Accept the Invitation',
          desc: "You'll receive a notification inside the app. Open your Invitations screen and tap 'Accept' to link your account with the patient's account.",
        },
        {
          icon: Eye,
          title: 'Start Monitoring',
          desc: 'You are now linked. You will receive instant alerts and see a live map view every time your patient triggers an SOS — from anywhere in the world.',
        },
      ],
    },
    Responder: {
      color: '#2496A7',
      gradient: 'linear-gradient(135deg,#2496A7,#2891C2)',
      lightBg: '#E0F7FA',
      icon: HeartPulse,
      tagline: 'Full account activation within 24–48 hours',
      steps: [
        {
          icon: Download,
          title: 'Download the MediFind App',
          desc: 'Get the free app from Google Play Store.',
        },
        {
          icon: UserPlus,
          title: 'Register as a Responder',
          desc: 'Tap "Register", select "Responder" as your role, and fill in your full name, email address, phone number and a secure password.',
        },
        {
          icon: FileText,
          title: 'Upload Your Professional Credentials',
          desc: 'Submit your CNIC front and back images, your Employee Card photo, and your professional license number. All documents are encrypted and reviewed securely.',
          note: 'Documents are only visible to the MediFind admin team and are never shared publicly.',
        },
        {
          icon: Clock,
          title: 'Wait for Admin Review',
          desc: "Our team manually reviews every responder application within 24–48 hours. Your app will display a step-tracker showing 'Submitted → Under Review → Approved' so you always know where your application stands.",
        },
        {
          icon: Bell,
          title: 'Check Your Email for a 6-Digit OTP',
          desc: 'Once approved, you will receive a One-Time Password (OTP) to your registered email address. This code is valid for 15 minutes.',
          note: "Didn't receive it? Check your spam folder or use the Resend Code option inside the app.",
        },
        {
          icon: Shield,
          title: 'Enter OTP to Activate Your Account',
          desc: 'Open the app, tap "Enter Verification Code", type in your 6-digit OTP and confirm. Your account is now fully verified and active.',
        },
        {
          icon: Zap,
          title: 'Toggle Availability & Start Responding',
          desc: 'Set your status to "Available" on your Responder home dashboard. You will now receive emergency dispatch alerts for patients in your area.',
        },
      ],
    },
  };

  const PX = '0 5%';
  const gs = getStartedData[activeRole]; // current tab data

  const navLinks = [
    ['About',        '#about'],
    ['Features',     '#features'],
    ['How It Works', '#how-it-works'],
    ['Ecosystem',    '#ecosystem'],
    ['Get Started',  '#get-started'],
    ['Contact',      '#contact'],
  ];

  /* ── Ecosystem showcase data ─────────────────────────────── */
  const ecosystemTabs = ['Patient', 'Caregiver', 'Responder', 'Admin'];

  const ecosystemData = {
    Patient: {
      color: '#0C637E', gradient: 'linear-gradient(135deg,#0C637E,#2496A7)',
      icon: User, label: 'Patient App', device: 'phone',
      headline: 'The Patient Experience',
      tagline: 'Help is always one tap away',
      desc: 'A clean, accessible home screen built around one priority — getting help fast. The SOS button dominates the screen for instant reach. Below it: medical profile, caregiver links, and emergency history. Deaf & Mute Mode transforms the entire interface to icon-driven, voice-free interaction.',
      /* ── Replace these with real screenshot imports once exported from Flutter ── */
      primaryScreenshot: null,   // e.g. import sosScreen from '../assets/screens/patient-sos.png'
      secondaryScreenshot: null, // e.g. import trackScreen from '../assets/screens/patient-tracking.png'
      primaryLabel: 'Home · SOS Screen',
      secondaryLabel: 'Live Tracking',
      callouts: [
        { icon: Zap,      label: 'One-Tap SOS Button',    desc: 'Dominant centre-screen trigger — always one tap, never buried', color: '#EF4444', bg: '#FEF2F2' },
        { icon: MapPin,   label: 'Live Responder Map',    desc: 'GPS of assigned responder updates every 5 seconds en route',   color: '#0C637E', bg: '#E2F0F3' },
        { icon: FileText, label: 'Medical Profile Share', desc: 'Blood type, allergies & meds auto-delivered to responder',     color: '#10B981', bg: '#ECFDF5' },
        { icon: Mic,      label: 'Deaf & Mute Mode',      desc: 'Silent icon-only SOS with haptic feedback and screen flash',   color: '#8B5CF6', bg: '#F5F3FF' },
      ],
    },
    Caregiver: {
      color: '#1A6FA5', gradient: 'linear-gradient(135deg,#1A6FA5,#2891C2)',
      icon: Heart, label: 'Caregiver App', device: 'phone',
      headline: 'The Caregiver Experience',
      tagline: 'Watch over loved ones from anywhere in the world',
      desc: 'A monitoring-first interface. Caregivers see all linked patients and their status at a glance. The moment SOS fires, a push notification appears and the live emergency map opens — showing both the patient and the incoming responder moving in real time.',
      primaryScreenshot: null,
      secondaryScreenshot: null,
      primaryLabel: 'My Patients',
      secondaryLabel: 'Emergency Monitor',
      callouts: [
        { icon: Users,    label: 'Linked Patients List',   desc: 'All patients and their real-time status in one dashboard',      color: '#1A6FA5', bg: '#EBF5FB' },
        { icon: Bell,     label: 'Instant SOS Alert',      desc: 'Push notification fires the exact moment patient triggers SOS', color: '#DC2626', bg: '#FEF2F2' },
        { icon: MapPin,   label: 'Dual Live Map',          desc: 'See patient and responder positions simultaneously on map',     color: '#0C637E', bg: '#E2F0F3' },
        { icon: Clock,    label: 'Emergency History',      desc: 'Full outcome reports for every past emergency event',           color: '#2891C2', bg: '#EBF5FB' },
      ],
    },
    Responder: {
      color: '#2496A7', gradient: 'linear-gradient(135deg,#2496A7,#2891C2)',
      icon: HeartPulse, label: 'Responder App', device: 'phone',
      headline: 'The Responder Experience',
      tagline: 'Precision dispatch with full patient context before arrival',
      desc: 'A professional dispatch interface. Responders toggle availability with one tap, receive voice + haptic emergency alerts with the patient\'s full medical data, stream GPS live to the patient during response, and log resolution outcomes. Every interaction is designed around speed.',
      primaryScreenshot: null,   // e.g. import respHome from '../assets/screens/responder-home.png'
      secondaryScreenshot: null, // e.g. import respRequest from '../assets/screens/responder-request.png'
      primaryLabel: 'Responder Dashboard',
      secondaryLabel: 'Incoming Request',
      callouts: [
        { icon: Activity, label: 'Availability Toggle',    desc: 'Go on/off duty instantly — dispatches only reach available responders', color: '#10B981', bg: '#ECFDF5' },
        { icon: Bell,     label: 'Emergency Alert Modal',  desc: 'Voice + haptic + fullscreen modal with patient name and location',      color: '#EF4444', bg: '#FEF2F2' },
        { icon: FileText, label: 'Patient Data Preview',   desc: 'Blood type, allergies and conditions shown before you arrive',          color: '#2496A7', bg: '#E0F7FA' },
        { icon: Star,     label: 'Response History',       desc: 'Track total responses, average time and your responder rating',         color: '#F59E0B', bg: '#FFFBEB' },
      ],
    },
    Admin: {
      color: '#0C637E', gradient: 'linear-gradient(135deg,#04364E,#0C637E)',
      icon: BarChart3, label: 'Admin Web Portal', device: 'browser',
      headline: 'The Admin Command Centre',
      tagline: 'Total control and visibility from a single secure dashboard',
      desc: 'A React-powered web portal — not a mobile app. Admins get a real-time command centre with live SOS monitoring, responder credential review, user management, subscription tracking, and an immutable audit log. Every action across the entire ecosystem flows through here.',
      primaryScreenshot: null,   // e.g. import adminDash from '../assets/screens/admin-dashboard.png'
      primaryLabel: 'Admin Overview Dashboard',
      callouts: [
        { icon: BarChart3, label: 'Live Analytics',          desc: 'KPI cards, sparkline trends and MRR — refreshed in real time',   color: '#0C637E', bg: '#E2F0F3' },
        { icon: Shield,    label: 'Responder Verification',  desc: 'Review CNIC, employee card and licence — approve or reject',     color: '#10B981', bg: '#ECFDF5' },
        { icon: Activity,  label: 'SOS Live Monitor',        desc: 'All active emergencies on one auto-updating board',              color: '#EF4444', bg: '#FEF2F2' },
        { icon: Users,     label: 'User Management',         desc: 'Patients, Caregivers and Responders — searchable, paginated',    color: '#8B5CF6', bg: '#F5F3FF' },
      ],
    },
  };

  return (
    <div style={{ background: '#FFFFFF', overflowX: 'hidden', fontFamily: P }}>

      {/* ── Navigation ─────────────────────────────────────────── */}
      <nav style={{
        position: 'fixed', top: 0, left: 0, right: 0, zIndex: 1000,
        background: scrolled ? 'rgba(255,255,255,0.96)' : 'transparent',
        backdropFilter: scrolled ? 'blur(20px)' : 'none',
        borderBottom: scrolled ? '1px solid #E2E8F0' : '1px solid transparent',
        transition: 'all 0.3s ease',
      }}>
        <div style={{ padding: PX, display: 'flex', justifyContent: 'space-between', alignItems: 'center', height: '104px' }}>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none' }}>
            <img src={logo} alt="MediFind" style={{ height: '96px', objectFit: 'contain' }} />
          </Link>
          <div style={{ display: 'flex', gap: '2rem', alignItems: 'center' }}>
            {navLinks.map(([label, href]) => {
              const sectionId = href.replace('#', '');
              const isActive = activeSection === sectionId;
              return (
                <a key={href} href={href}
                  style={{
                    fontWeight: isActive ? 600 : 500,
                    color: isActive ? '#0C637E' : '#475569',
                    fontSize: '0.875rem', textDecoration: 'none',
                    transition: 'color 0.2s', fontFamily: P,
                    position: 'relative', paddingBottom: '4px',
                  }}
                  onMouseEnter={e => e.currentTarget.style.color = '#0C637E'}
                  onMouseLeave={e => e.currentTarget.style.color = isActive ? '#0C637E' : '#475569'}
                >
                  {label}
                  {/* Active underline indicator */}
                  {isActive && (
                    <span style={{
                      position: 'absolute', bottom: 0, left: 0, right: 0,
                      height: '2px', borderRadius: '2px',
                      background: 'linear-gradient(90deg,#0C637E,#2891C2)',
                    }} />
                  )}
                </a>
              );
            })}
            <Link to="/login" style={{ padding: '0.6rem 1.25rem', borderRadius: '10px', background: 'linear-gradient(135deg,#0C637E,#2496A7)', color: 'white', fontWeight: 600, fontSize: '0.85rem', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.4rem', fontFamily: P }}>
              Admin Portal <ArrowRight size={14} />
            </Link>
          </div>
        </div>
      </nav>

      {/* ── Hero ───────────────────────────────────────────────── */}
      <section style={{ paddingTop: '140px', paddingBottom: '72px', background: 'linear-gradient(150deg,#F0F9FC 0%,#E8F5FA 55%,#F8FAFC 100%)' }}>
        <div style={{ padding: PX, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '5rem', alignItems: 'center' }}>
          <div>
            <Badge icon={HeartPulse} label="Emergency Response Platform" />
            <h1 style={{ fontSize: '3.2rem', lineHeight: 1.15, fontWeight: 700, marginBottom: '1.35rem', color: '#0F172A', fontFamily: P }}>
              Empowering<br />
              <span style={{ background: 'linear-gradient(135deg,#0C637E,#2891C2)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
                Accessibility
              </span><br />
              in Emergencies.
            </h1>
            <p style={{ fontSize: '1rem', color: '#64748B', marginBottom: '2rem', lineHeight: 1.8, maxWidth: '460px', fontFamily: P, fontWeight: 400 }}>
              The only emergency platform with built-in support for{' '}
              <strong style={{ color: '#0C637E', fontWeight: 600 }}>Deaf & Mute users</strong>{' '}
              — connecting Patients, Responders, and Caregivers in real time.
            </p>
            <motion.div initial="hidden" animate="visible" variants={staggerContainer} style={{ display: 'flex', gap: '0.875rem', flexWrap: 'wrap', marginBottom: '2.75rem' }}>
              <motion.a
                href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer"
                variants={fadeInUp}
                whileHover={{ scale: 1.05, boxShadow: '0 10px 25px rgba(12,99,126,0.35)' }}
                whileTap={{ scale: 0.95 }}
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.8rem 1.6rem', borderRadius: '10px', background: 'linear-gradient(135deg,#0C637E,#2496A7)', color: 'white', fontWeight: 600, fontSize: '0.875rem', textDecoration: 'none', cursor: 'pointer', fontFamily: P }}
              >
                <Download size={15} /> Download App
              </motion.a>
              <motion.a
                href="#get-started"
                variants={fadeInUp}
                whileHover={{ scale: 1.05, background: '#F1F5F9' }}
                whileTap={{ scale: 0.95 }}
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.8rem 1.6rem', borderRadius: '10px', background: 'white', color: '#0C637E', fontWeight: 600, fontSize: '0.875rem', border: '1.5px solid #E2E8F0', cursor: 'pointer', fontFamily: P, textDecoration: 'none' }}
              >
                <Play size={14} /> How to Get Started
              </motion.a>
            </motion.div>
            <div style={{ display: 'flex', gap: '2.5rem', paddingTop: '1.75rem', borderTop: '1px solid #E2E8F0' }}>
              {[['< 4 min', 'Response Time'], ['10K+', 'Active Users'], ['99.9%', 'Uptime']].map(([val, lbl]) => (
                <div key={lbl}>
                  <div style={{ fontSize: '1.35rem', fontWeight: 700, color: '#0C637E', marginBottom: '2px', fontFamily: P }}>{val}</div>
                  <div style={{ fontSize: '0.72rem', color: '#94A3B8', fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.07em', fontFamily: P }}>{lbl}</div>
                </div>
              ))}
            </div>
          </div>
          <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 1 }} style={{ position: 'relative' }}>
            <div style={{ position: 'absolute', inset: '-40px', borderRadius: '60px', background: 'radial-gradient(ellipse at center,rgba(12,99,126,0.1) 0%,transparent 70%)', pointerEvents: 'none' }} />
            <motion.img src={heroMockup} alt="MediFind App" loading="lazy" animate="animate" variants={float}
              style={{ width: '100%', borderRadius: '28px', boxShadow: '0 28px 70px rgba(12,99,126,0.16)', position: 'relative', zIndex: 1 }} />
            <motion.div initial={{ x: -20, opacity: 0 }} animate={{ x: 0, opacity: 1 }} transition={{ delay: 0.8 }}
              style={{ position: 'absolute', bottom: '2rem', left: '-1.5rem', background: 'white', borderRadius: '14px', padding: '0.9rem 1.1rem', boxShadow: '0 10px 36px rgba(0,0,0,0.1)', display: 'flex', alignItems: 'center', gap: '0.7rem', zIndex: 2 }}>
              <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: '#ECFDF5', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Shield size={18} color="#10B981" />
              </div>
              <div>
                <div style={{ fontWeight: 600, fontSize: '0.85rem', color: '#0F172A', fontFamily: P }}>Responder Verified</div>
                <div style={{ fontSize: '0.72rem', color: '#10B981', fontWeight: 500, fontFamily: P }}>● ETA 3 min 42 sec</div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* ── Trust Stats Bar (moved here from mid-page per QA) ─────── */}
      <section style={{ background: 'linear-gradient(135deg,#03293C 0%,#0C637E 55%,#2496A7 100%)', padding: '2.25rem 0' }}>
        <div style={{ padding: PX, display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: '1rem', textAlign: 'center' }}>
          {stats.map((s, i) => (
            <FadeIn key={s.label} delay={i * 80}>
              <div style={{ padding: '0.5rem 1rem', borderRight: i < stats.length - 1 ? '1px solid rgba(255,255,255,0.15)' : 'none' }}>
                <div style={{ fontSize: '1.9rem', fontWeight: 700, color: 'white', marginBottom: '0.25rem', fontFamily: P }}>
                  <Counter end={s.value} suffix={s.suffix} prefix={s.prefix} />
                </div>
                <div style={{ fontSize: '0.7rem', color: 'rgba(255,255,255,0.65)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.09em', fontFamily: P }}>{s.label}</div>
              </div>
            </FadeIn>
          ))}
        </div>
      </section>

      {/* ── Brand Pillars (About) ────────────────────────────────── */}
      <section id="about" style={{ padding: '5.5rem 0', background: '#0F172A', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: '10%', left: '-5%', width: '400px', height: '400px', background: 'radial-gradient(circle, rgba(12,99,126,0.15) 0%, transparent 70%)', borderRadius: '50%' }} />
        <div style={{ position: 'absolute', bottom: '10%', right: '-5%', width: '400px', height: '400px', background: 'radial-gradient(circle, rgba(36,150,167,0.1) 0%, transparent 70%)', borderRadius: '50%' }} />
        <div style={{ padding: PX, position: 'relative', zIndex: 1 }}>
          <SectionHead badge="The MediFind Identity" badgeBg="rgba(255,255,255,0.05)" badgeColor="white"
            title="Our Core Branding Pillars"
            sub="MediFind is more than an app; it is a promise of safety and inclusivity for every individual in crisis."
            light />
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2.5rem', marginTop: '2rem' }}>
            {[
              { icon: Mic,    title: 'Universal Inclusivity', color: '#8B5CF6', desc: 'We are the first emergency platform built for silence. Our mission is to ensure that being Deaf or Mute is never a barrier to being saved.', tag: 'The Silent SOS' },
              { icon: Users,  title: 'The Human Network',     color: '#0C637E', desc: 'We bridge the gap between Patient, Caregiver, and Responder, creating a unified ecosystem of trust and real-time coordination.',           tag: 'Bonded Safety' },
              { icon: Shield, title: 'Verified Precision',    color: '#10B981', desc: 'Trust is our foundation. We verify every responder and encrypt every medical report to ensure professional-grade care.',                    tag: 'Security & Integrity' },
            ].map((p, i) => (
              <FadeIn key={p.title} delay={i * 150}>
                <motion.div whileHover={{ y: -15, background: 'rgba(255,255,255,0.05)' }}
                  style={{ background: 'rgba(255,255,255,0.03)', padding: '3.5rem 2.5rem', borderRadius: '32px', border: '1px solid rgba(255,255,255,0.08)', backdropFilter: 'blur(10px)', height: '100%', textAlign: 'center', transition: 'all 0.4s cubic-bezier(0.22, 1, 0.36, 1)' }}>
                  <div style={{ width: '72px', height: '72px', borderRadius: '22px', background: `${p.color}20`, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 2rem', border: `1px solid ${p.color}40`, boxShadow: `0 10px 30px ${p.color}15` }}>
                    <p.icon size={32} color={p.color} />
                  </div>
                  <div style={{ fontSize: '0.7rem', fontWeight: 800, color: p.color, textTransform: 'uppercase', letterSpacing: '0.15em', marginBottom: '0.75rem' }}>{p.tag}</div>
                  <h3 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'white', marginBottom: '1.25rem', fontFamily: P }}>{p.title}</h3>
                  <p style={{ fontSize: '0.95rem', color: 'rgba(255,255,255,0.5)', lineHeight: 1.8, fontFamily: P }}>{p.desc}</p>
                </motion.div>
              </FadeIn>
            ))}
          </div>
          <FadeIn delay={500}>
            <div style={{ marginTop: '5rem', padding: '3rem', borderRadius: '32px', background: 'linear-gradient(135deg, rgba(255,255,255,0.05) 0%, transparent 100%)', border: '1px solid rgba(255,255,255,0.05)', textAlign: 'center' }}>
              <h4 style={{ color: 'white', fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem' }}>Our Vision for 2026</h4>
              <p style={{ color: 'rgba(255,255,255,0.4)', fontSize: '0.9rem', maxWidth: '600px', margin: '0 auto' }}>
                To become the global standard for inclusive emergency response, ensuring no one is left behind because of a communication barrier.
              </p>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── Features ───────────────────────────────────────────── */}
      <section id="features" style={{ padding: '4.5rem 0', background: '#F8FAFC' }}>
        <div style={{ padding: PX }}>
          <FadeIn>
            <SectionHead badge="Core Features" badgeIcon={Zap} badgeBg="#E2F0F3" badgeColor="#0C637E"
              title="Built for Every Emergency"
              sub="Every feature is designed around one goal: getting the right help to the right person in the shortest time possible." />
          </FadeIn>
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }} variants={staggerContainer}
            style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: '1.25rem' }}>
            {features.map((f) => (
              <motion.div key={f.title} variants={fadeInUp}
                whileHover={{ y: -10, boxShadow: '0 20px 40px rgba(12,99,126,0.12)' }}
                style={{ background: 'white', borderRadius: '18px', padding: '1.75rem', border: '1px solid #E2E8F0', transition: 'box-shadow 0.3s ease', cursor: 'default', height: '100%' }}>
                <div style={{ width: '46px', height: '46px', borderRadius: '13px', background: f.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1.1rem' }}>
                  <f.icon size={20} color={f.color} />
                </div>
                <h3 style={{ fontSize: '0.95rem', fontWeight: 600, color: '#0F172A', marginBottom: '0.5rem', fontFamily: P }}>{f.title}</h3>
                <p style={{ fontSize: '0.855rem', color: '#64748B', lineHeight: 1.7, fontFamily: P, fontWeight: 400 }}>{f.desc}</p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* ── How It Works ───────────────────────────────────────── */}
      <section id="how-it-works" style={{ padding: '4.5rem 0', background: 'white' }}>
        <div style={{ padding: PX }}>
          <FadeIn>
            <SectionHead badge="How It Works" badgeIcon={Activity} badgeBg="#E2F0F3" badgeColor="#0C637E"
              title="From SOS to Safety in 4 Steps"
              sub="A seamless emergency response pipeline designed to minimize every second of delay." />
          </FadeIn>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: '1.5rem', position: 'relative' }}>
            <div style={{ position: 'absolute', top: '2.4rem', left: 'calc(12.5% + 26px)', right: 'calc(12.5% + 26px)', height: '2px', background: 'linear-gradient(90deg,#DC2626,#0C637E,#2496A7,#2891C2)', borderRadius: '2px', zIndex: 0 }} />
            {steps.map((s, i) => (
              <FadeIn key={s.title} delay={i * 110}>
                <div style={{ textAlign: 'center', position: 'relative', zIndex: 1 }}>
                  <div style={{ width: '50px', height: '50px', borderRadius: '50%', background: 'white', border: `2px solid ${s.color}`, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.35rem', boxShadow: `0 0 0 5px ${s.color}18` }}>
                    <s.icon size={20} color={s.color} />
                  </div>
                  <div style={{ fontSize: '0.68rem', fontWeight: 600, color: s.color, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.4rem', fontFamily: P }}>{s.num}</div>
                  <h3 style={{ fontSize: '0.95rem', fontWeight: 600, color: '#0F172A', marginBottom: '0.5rem', fontFamily: P }}>{s.title}</h3>
                  <p style={{ fontSize: '0.82rem', color: '#64748B', lineHeight: 1.65, fontFamily: P, fontWeight: 400 }}>{s.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ── Role Sections (Solutions) ───────────────────────────── */}
      <section id="solutions" style={{ padding: '4.5rem 0', background: '#F8FAFC' }}>
        <div style={{ padding: PX }}>
          <FadeIn>
            <SectionHead badge="Built for Every Role" badgeIcon={Users} badgeBg="#EEF2FF" badgeColor="#6366F1"
              title="One Platform. Four Roles." />
          </FadeIn>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {roles.map((r, i) => (
              <FadeIn key={r.title} delay={i * 80}>
                <div style={{ display: 'grid', gridTemplateColumns: i % 2 === 0 ? '1fr 1.5fr' : '1.5fr 1fr', gap: '0', borderRadius: '20px', overflow: 'hidden', boxShadow: '0 2px 20px rgba(0,0,0,0.05)' }}>
                  <div style={{ order: i % 2 === 0 ? 0 : 1, background: r.gradient, padding: '2.5rem 2.75rem', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                    <div style={{ width: '48px', height: '48px', borderRadius: '13px', background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '1.25rem' }}>
                      <r.icon size={24} color="white" />
                    </div>
                    <div style={{ fontSize: '0.68rem', fontWeight: 600, color: 'rgba(255,255,255,0.65)', textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: '0.4rem', fontFamily: P }}>{r.title}</div>
                    <h3 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'white', marginBottom: '0.9rem', lineHeight: 1.25, fontFamily: P }}>{r.headline}</h3>
                    <p style={{ color: 'rgba(255,255,255,0.82)', fontSize: '0.875rem', lineHeight: 1.75, fontFamily: P, fontWeight: 400 }}>{r.desc}</p>
                  </div>
                  <div style={{ order: i % 2 === 0 ? 1 : 0, background: 'white', padding: '2.5rem 2.75rem', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
                      {r.points.map((pt) => (
                        <div key={pt} style={{ display: 'flex', alignItems: 'flex-start', gap: '0.8rem' }}>
                          <div style={{ width: '20px', height: '20px', borderRadius: '50%', background: '#ECFDF5', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: '2px' }}>
                            <CheckCircle size={12} color="#10B981" />
                          </div>
                          <span style={{ fontSize: '0.875rem', color: '#334155', fontWeight: 500, lineHeight: 1.55, fontFamily: P }}>{pt}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ══════════════════════════════════════════════════════════
          ── ECOSYSTEM SHOWCASE ──
          Shows the actual interface for each role:
          Patient App · Caregiver App · Responder App · Admin Portal
          Device mockups + feature callouts per role.
          Add real screenshot paths to ecosystemData when available.
      ══════════════════════════════════════════════════════════ */}
      <section id="ecosystem" style={{ padding: '5rem 0', background: '#0F172A', position: 'relative', overflow: 'hidden' }}>

        {/* Ambient background glow — shifts colour with active tab */}
        <motion.div
          key={activeEcosystem + '-glow'}
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.8 }}
          style={{ position: 'absolute', top: '15%', left: '-8%', width: '550px', height: '550px', background: `radial-gradient(circle, ${ecosystemData[activeEcosystem].color}18 0%, transparent 65%)`, borderRadius: '50%', pointerEvents: 'none' }}
        />
        <div style={{ position: 'absolute', bottom: '5%', right: '-8%', width: '400px', height: '400px', background: 'radial-gradient(circle, rgba(36,150,167,0.1) 0%, transparent 65%)', borderRadius: '50%', pointerEvents: 'none' }} />

        <div style={{ padding: PX, position: 'relative', zIndex: 1 }}>

          {/* Section header */}
          <FadeIn>
            <SectionHead
              badge="The Full Ecosystem" badgeBg="rgba(255,255,255,0.06)" badgeColor="rgba(255,255,255,0.8)"
              title="One Ecosystem. Four Interfaces."
              sub="MediFind is not just an app — it is a connected platform where every role has a purpose-built interface designed for their exact needs. Explore each one below."
              light
            />
          </FadeIn>

          {/* ── Role tab selector ── */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.65rem', marginBottom: '4.5rem', flexWrap: 'wrap' }}>
            {ecosystemTabs.map(tab => {
              const ed = ecosystemData[tab];
              const isActive = activeEcosystem === tab;
              return (
                <motion.button
                  key={tab}
                  onClick={() => setActiveEcosystem(tab)}
                  whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.97 }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '0.5rem',
                    padding: '0.65rem 1.4rem', borderRadius: '100px',
                    border: isActive ? 'none' : '1px solid rgba(255,255,255,0.1)',
                    background: isActive ? ed.gradient : 'rgba(255,255,255,0.04)',
                    color: isActive ? 'white' : 'rgba(255,255,255,0.5)',
                    fontWeight: 600, fontSize: '0.85rem', cursor: 'pointer', fontFamily: P,
                    boxShadow: isActive ? `0 6px 24px ${ed.color}45` : 'none',
                    transition: 'all 0.25s ease',
                  }}
                >
                  <ed.icon size={14} />
                  {ed.label}
                </motion.button>
              );
            })}
          </div>

          {/* ── Tab content ── */}
          <AnimatePresence mode="wait">
            <motion.div
              key={activeEcosystem}
              initial={{ opacity: 0, y: 28 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.42, ease: [0.22, 1, 0.36, 1] }}
            >
              {ecosystemData[activeEcosystem].device === 'phone' ? (

                /* ════ PHONE LAYOUT (Patient / Caregiver / Responder) ════ */
                <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: '5rem', alignItems: 'center' }}>

                  {/* Left — device mockups */}
                  <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '500px' }}>

                    {/* Back phone (secondary screen, rotated) */}
                    <div style={{ position: 'absolute', left: '4%', top: '6%', transform: 'rotate(-7deg) scale(0.88)', zIndex: 1, opacity: 0.65, filter: 'blur(0.5px)' }}>
                      <div style={{ width: '185px', background: '#1a1a2e', borderRadius: '36px', padding: '10px', boxShadow: '0 20px 60px rgba(0,0,0,0.6)', border: '2px solid rgba(255,255,255,0.07)' }}>
                        {/* Notch */}
                        <div style={{ width: '60px', height: '18px', background: '#0d0d1a', borderRadius: '10px', margin: '0 auto 6px' }} />
                        {/* Screen */}
                        <div style={{ borderRadius: '22px', overflow: 'hidden', aspectRatio: '9/19', background: ecosystemData[activeEcosystem].primaryScreenshot ? 'transparent' : `linear-gradient(160deg, ${ecosystemData[activeEcosystem].color}22, ${ecosystemData[activeEcosystem].color}08)`, position: 'relative' }}>
                          {ecosystemData[activeEcosystem].secondaryScreenshot
                            ? <img src={ecosystemData[activeEcosystem].secondaryScreenshot} alt={ecosystemData[activeEcosystem].secondaryLabel} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            : <EcosystemScreenPlaceholder type="secondary" color={ecosystemData[activeEcosystem].color} gradient={ecosystemData[activeEcosystem].gradient} role={activeEcosystem} />
                          }
                        </div>
                        {/* Screen label */}
                        <div style={{ textAlign: 'center', marginTop: '6px', fontSize: '7px', color: 'rgba(255,255,255,0.3)', fontFamily: P, fontWeight: 500 }}>{ecosystemData[activeEcosystem].secondaryLabel}</div>
                      </div>
                    </div>

                    {/* Front phone (primary screen, featured) */}
                    <div style={{ position: 'relative', zIndex: 2, marginLeft: '10%' }}>
                      <div style={{ width: '210px', background: '#111827', borderRadius: '40px', padding: '12px', boxShadow: `0 30px 80px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.08), 0 0 40px ${ecosystemData[activeEcosystem].color}25`, border: '2px solid rgba(255,255,255,0.1)' }}>
                        {/* Notch */}
                        <div style={{ width: '70px', height: '20px', background: '#0a0a14', borderRadius: '10px', margin: '0 auto 8px', position: 'relative' }}>
                          {/* Camera dot */}
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#1a1a2e', position: 'absolute', right: '10px', top: '50%', transform: 'translateY(-50%)' }} />
                        </div>
                        {/* Screen */}
                        <div style={{ borderRadius: '26px', overflow: 'hidden', aspectRatio: '9/19', background: ecosystemData[activeEcosystem].primaryScreenshot ? 'transparent' : '#F8FAFC', position: 'relative' }}>
                          {ecosystemData[activeEcosystem].primaryScreenshot
                            ? <img src={ecosystemData[activeEcosystem].primaryScreenshot} alt={ecosystemData[activeEcosystem].primaryLabel} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            : <EcosystemScreenPlaceholder type="primary" color={ecosystemData[activeEcosystem].color} gradient={ecosystemData[activeEcosystem].gradient} role={activeEcosystem} />
                          }
                        </div>
                        {/* Screen label */}
                        <div style={{ textAlign: 'center', marginTop: '8px', fontSize: '8px', color: 'rgba(255,255,255,0.4)', fontFamily: P, fontWeight: 500 }}>{ecosystemData[activeEcosystem].primaryLabel}</div>
                      </div>

                      {/* Floating device type badge */}
                      <div style={{ position: 'absolute', bottom: '-16px', left: '50%', transform: 'translateX(-50%)', background: ecosystemData[activeEcosystem].gradient, color: 'white', borderRadius: '100px', padding: '0.25rem 0.9rem', fontSize: '0.65rem', fontWeight: 700, fontFamily: P, whiteSpace: 'nowrap', boxShadow: `0 4px 16px ${ecosystemData[activeEcosystem].color}40` }}>
                        Android · Flutter
                      </div>
                    </div>
                  </div>

                  {/* Right — description + callouts */}
                  <div>
                    {/* Role pill */}
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', padding: '0.3rem 0.9rem', borderRadius: '100px', background: `${ecosystemData[activeEcosystem].color}25`, border: `1px solid ${ecosystemData[activeEcosystem].color}40`, marginBottom: '1.25rem' }}>
                      {React.createElement(ecosystemData[activeEcosystem].icon, { size: 12, color: ecosystemData[activeEcosystem].color })}
                      <span style={{ fontSize: '0.68rem', fontWeight: 700, color: ecosystemData[activeEcosystem].color, textTransform: 'uppercase', letterSpacing: '0.08em', fontFamily: P }}>{ecosystemData[activeEcosystem].label}</span>
                    </div>

                    <h3 style={{ fontSize: '1.75rem', fontWeight: 700, color: 'white', marginBottom: '0.5rem', fontFamily: P, lineHeight: 1.25 }}>{ecosystemData[activeEcosystem].headline}</h3>
                    <p style={{ fontSize: '0.78rem', color: ecosystemData[activeEcosystem].color, fontWeight: 600, marginBottom: '1rem', fontFamily: P, letterSpacing: '0.01em' }}>{ecosystemData[activeEcosystem].tagline}</p>
                    <p style={{ fontSize: '0.875rem', color: 'rgba(255,255,255,0.55)', lineHeight: 1.8, marginBottom: '2rem', fontFamily: P, fontWeight: 400 }}>{ecosystemData[activeEcosystem].desc}</p>

                    {/* Feature callouts */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                      {ecosystemData[activeEcosystem].callouts.map((c, i) => (
                        <motion.div
                          key={c.label}
                          initial={{ opacity: 0, x: 20 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: i * 0.08, duration: 0.35 }}
                          style={{ display: 'flex', gap: '0.875rem', alignItems: 'flex-start', padding: '0.9rem 1rem', borderRadius: '14px', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.06)', transition: 'background 0.2s' }}
                          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.07)'}
                          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.04)'}
                        >
                          <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: c.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <c.icon size={16} color={c.color} />
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, color: 'white', fontSize: '0.875rem', marginBottom: '0.2rem', fontFamily: P }}>{c.label}</div>
                            <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.45)', lineHeight: 1.55, fontFamily: P, fontWeight: 400 }}>{c.desc}</div>
                          </div>
                        </motion.div>
                      ))}
                    </div>
                  </div>
                </div>

              ) : (

                /* ════ BROWSER LAYOUT (Admin) ════ */
                <div>
                  {/* Description row */}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4rem', marginBottom: '3rem', alignItems: 'start' }}>
                    <div>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', padding: '0.3rem 0.9rem', borderRadius: '100px', background: 'rgba(12,99,126,0.3)', border: '1px solid rgba(12,99,126,0.5)', marginBottom: '1.25rem' }}>
                        <BarChart3 size={12} color="#2496A7" />
                        <span style={{ fontSize: '0.68rem', fontWeight: 700, color: '#2496A7', textTransform: 'uppercase', letterSpacing: '0.08em', fontFamily: P }}>Admin Web Portal · React + Vite</span>
                      </div>
                      <h3 style={{ fontSize: '1.75rem', fontWeight: 700, color: 'white', marginBottom: '0.5rem', fontFamily: P, lineHeight: 1.25 }}>{ecosystemData.Admin.headline}</h3>
                      <p style={{ fontSize: '0.78rem', color: '#2496A7', fontWeight: 600, marginBottom: '1rem', fontFamily: P }}>{ecosystemData.Admin.tagline}</p>
                      <p style={{ fontSize: '0.875rem', color: 'rgba(255,255,255,0.55)', lineHeight: 1.8, fontFamily: P, fontWeight: 400 }}>{ecosystemData.Admin.desc}</p>
                    </div>
                    {/* Callouts right column */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                      {ecosystemData.Admin.callouts.map((c, i) => (
                        <motion.div
                          key={c.label}
                          initial={{ opacity: 0, x: 20 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: i * 0.08 }}
                          style={{ display: 'flex', gap: '0.75rem', alignItems: 'flex-start', padding: '0.8rem 0.9rem', borderRadius: '12px', background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.06)', transition: 'background 0.2s' }}
                          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.07)'}
                          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.04)'}
                        >
                          <div style={{ width: '32px', height: '32px', borderRadius: '9px', background: c.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <c.icon size={15} color={c.color} />
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, color: 'white', fontSize: '0.83rem', marginBottom: '0.15rem', fontFamily: P }}>{c.label}</div>
                            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.42)', lineHeight: 1.5, fontFamily: P }}>{c.desc}</div>
                          </div>
                        </motion.div>
                      ))}
                    </div>
                  </div>

                  {/* Browser mockup — full width */}
                  <div style={{ background: '#1a1a2e', borderRadius: '16px', padding: '12px', boxShadow: '0 30px 80px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)' }}>
                    {/* Browser chrome */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '10px', padding: '0 4px' }}>
                      {['#EF4444', '#F59E0B', '#10B981'].map(c => (
                        <div key={c} style={{ width: '11px', height: '11px', borderRadius: '50%', background: c, opacity: 0.85 }} />
                      ))}
                      {/* URL bar */}
                      <div style={{ flex: 1, height: '22px', background: 'rgba(255,255,255,0.05)', borderRadius: '6px', marginLeft: '8px', display: 'flex', alignItems: 'center', paddingLeft: '10px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Lock size={8} color="rgba(255,255,255,0.3)" />
                          <span style={{ fontSize: '8px', color: 'rgba(255,255,255,0.35)', fontFamily: P }}>medifind.pk/admin</span>
                        </div>
                      </div>
                    </div>

                    {/* Dashboard content area */}
                    {ecosystemData.Admin.primaryScreenshot ? (
                      <img src={ecosystemData.Admin.primaryScreenshot} alt="Admin Dashboard" style={{ width: '100%', borderRadius: '8px', display: 'block' }} />
                    ) : (
                      /* CSS-drawn admin dashboard mockup */
                      <div style={{ display: 'flex', borderRadius: '8px', overflow: 'hidden', background: '#F8FAFC', aspectRatio: '16/7' }}>

                        {/* Sidebar */}
                        <div style={{ width: '180px', background: '#03293C', flexShrink: 0, padding: '16px 12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                          {/* Logo area */}
                          <div style={{ width: '100px', height: '14px', borderRadius: '4px', background: 'rgba(255,255,255,0.15)', marginBottom: '16px' }} />
                          {/* Nav items */}
                          {[
                            { w: '85%', active: true,  color: '#0C637E' },
                            { w: '75%', active: false, color: null },
                            { w: '90%', active: false, color: null },
                            { w: '70%', active: false, color: null },
                            { w: '80%', active: false, color: null },
                            { w: '65%', active: false, color: null },
                            { w: '75%', active: false, color: null },
                            { w: '80%', active: false, color: null },
                          ].map((item, i) => (
                            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '5px 7px', borderRadius: '6px', background: item.active ? 'rgba(12,99,126,0.4)' : 'transparent' }}>
                              <div style={{ width: '12px', height: '12px', borderRadius: '3px', background: item.active ? '#0C637E' : 'rgba(255,255,255,0.12)', flexShrink: 0 }} />
                              <div style={{ height: '6px', borderRadius: '3px', background: item.active ? 'rgba(255,255,255,0.7)' : 'rgba(255,255,255,0.2)', width: item.w }} />
                            </div>
                          ))}
                        </div>

                        {/* Main content */}
                        <div style={{ flex: 1, padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px', background: '#F0F4F8' }}>

                          {/* Top bar */}
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div style={{ width: '140px', height: '10px', borderRadius: '4px', background: '#CBD5E1' }} />
                            <div style={{ display: 'flex', gap: '6px' }}>
                              <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'white', border: '1px solid #E2E8F0' }} />
                              <div style={{ width: '28px', height: '28px', borderRadius: '50%', background: 'linear-gradient(135deg,#0C637E,#2496A7)' }} />
                            </div>
                          </div>

                          {/* Stat cards row */}
                          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: '8px' }}>
                            {[
                              { label: 'Total Users',    value: '10,482', color: '#0C637E', icon: '👥' },
                              { label: 'Active SOS',     value: '3',       color: '#EF4444', icon: '🚨' },
                              { label: 'Responders',     value: '500+',    color: '#10B981', icon: '🛡️' },
                              { label: 'Monthly Revenue',value: 'PKR 12K', color: '#F59E0B', icon: '💰' },
                            ].map(card => (
                              <div key={card.label} style={{ background: 'white', borderRadius: '8px', padding: '8px 10px', boxShadow: '0 1px 3px rgba(0,0,0,0.06)', border: '1px solid #E8EDF2' }}>
                                <div style={{ fontSize: '8px', color: '#94A3B8', fontFamily: P, marginBottom: '3px', display: 'flex', alignItems: 'center', gap: '3px' }}>
                                  <span>{card.icon}</span>
                                  <span>{card.label}</span>
                                </div>
                                <div style={{ fontSize: '12px', fontWeight: 700, color: card.color, fontFamily: P }}>{card.value}</div>
                                {/* Sparkline */}
                                <div style={{ display: 'flex', alignItems: 'flex-end', gap: '2px', marginTop: '4px', height: '16px' }}>
                                  {[40,60,45,75,55,80,70].map((h, i) => (
                                    <div key={i} style={{ flex: 1, height: `${h}%`, borderRadius: '1px', background: `${card.color}40` }} />
                                  ))}
                                </div>
                              </div>
                            ))}
                          </div>

                          {/* Bottom row: chart + table */}
                          <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '8px', flex: 1 }}>

                            {/* Chart card */}
                            <div style={{ background: 'white', borderRadius: '8px', padding: '10px', border: '1px solid #E8EDF2' }}>
                              <div style={{ width: '100px', height: '7px', borderRadius: '3px', background: '#E2E8F0', marginBottom: '8px' }} />
                              {/* Bar chart */}
                              <div style={{ display: 'flex', alignItems: 'flex-end', gap: '5px', height: '60px', padding: '0 4px' }}>
                                {[55,40,70,85,60,90,75,65,80,95,70,88].map((h, i) => (
                                  <div key={i} style={{ flex: 1, height: `${h}%`, borderRadius: '3px 3px 0 0', background: i === 9 ? 'linear-gradient(180deg,#0C637E,#2496A7)' : `rgba(12,99,126,${0.2 + (i % 3) * 0.1})` }} />
                                ))}
                              </div>
                              {/* X axis labels */}
                              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '4px' }}>
                                {['Jan','Apr','Jul','Oct'].map(m => (
                                  <div key={m} style={{ fontSize: '6px', color: '#94A3B8', fontFamily: P }}>{m}</div>
                                ))}
                              </div>
                            </div>

                            {/* User table card */}
                            <div style={{ background: 'white', borderRadius: '8px', padding: '10px', border: '1px solid #E8EDF2', overflow: 'hidden' }}>
                              <div style={{ width: '80px', height: '7px', borderRadius: '3px', background: '#E2E8F0', marginBottom: '8px' }} />
                              {/* Table rows */}
                              {[
                                { role: 'P', color: '#0C637E', bg: '#E2F0F3' },
                                { role: 'R', color: '#10B981', bg: '#ECFDF5' },
                                { role: 'C', color: '#F59E0B', bg: '#FFFBEB' },
                                { role: 'P', color: '#0C637E', bg: '#E2F0F3' },
                                { role: 'R', color: '#10B981', bg: '#ECFDF5' },
                              ].map((row, i) => (
                                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '4px 0', borderBottom: i < 4 ? '1px solid #F1F5F9' : 'none' }}>
                                  <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: row.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                                    <span style={{ fontSize: '7px', fontWeight: 700, color: row.color, fontFamily: P }}>{row.role}</span>
                                  </div>
                                  <div style={{ flex: 1 }}>
                                    <div style={{ height: '5px', borderRadius: '2px', background: '#F1F5F9', width: `${60 + (i * 8)}%` }} />
                                  </div>
                                  <div style={{ width: '28px', height: '14px', borderRadius: '4px', background: i % 3 === 0 ? '#ECFDF5' : i % 3 === 1 ? '#FEF2F2' : '#FFFBEB' }}>
                                    <div style={{ height: '5px', borderRadius: '2px', margin: '4px 4px 0', background: i % 3 === 0 ? '#10B981' : i % 3 === 1 ? '#EF4444' : '#F59E0B' }} />
                                  </div>
                                </div>
                              ))}
                            </div>

                          </div>
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Screenshot hint */}
                  <p style={{ textAlign: 'center', marginTop: '1rem', fontSize: '0.72rem', color: 'rgba(255,255,255,0.2)', fontFamily: P }}>
                    💡 Replace the mockup above with a real screenshot — set <code style={{ background: 'rgba(255,255,255,0.06)', padding: '1px 5px', borderRadius: '4px', fontSize: '0.68rem' }}>ecosystemData.Admin.primaryScreenshot</code> to your image import
                  </p>
                </div>
              )}
            </motion.div>
          </AnimatePresence>

          {/* ── Screenshot placeholder notice for mobile roles ── */}
          {ecosystemData[activeEcosystem].device === 'phone' && (
            <p style={{ textAlign: 'center', marginTop: '3rem', fontSize: '0.72rem', color: 'rgba(255,255,255,0.18)', fontFamily: P }}>
              💡 Replace mockup screens with real app screenshots — set <code style={{ background: 'rgba(255,255,255,0.06)', padding: '1px 5px', borderRadius: '4px', fontSize: '0.68rem' }}>primaryScreenshot</code> / <code style={{ background: 'rgba(255,255,255,0.06)', padding: '1px 5px', borderRadius: '4px', fontSize: '0.68rem' }}>secondaryScreenshot</code> in <code style={{ background: 'rgba(255,255,255,0.06)', padding: '1px 5px', borderRadius: '4px', fontSize: '0.68rem' }}>ecosystemData.{activeEcosystem}</code>
            </p>
          )}

        </div>
      </section>

      {/* ══════════════════════════════════════════════════════════
          ── GET STARTED — Role-based account creation guide ──
          HCI principles applied:
          • Recognition over recall  — numbered visual steps
          • Visibility of system status — progress timeline
          • User control & freedom   — role selector tabs
          • Feedback                 — animated tab transitions
          • Match with real world    — role icons + language
          • Consistency              — same teal brand colours
      ══════════════════════════════════════════════════════════ */}
      <section id="get-started" style={{ padding: '5rem 0', background: 'white' }}>
        <div style={{ padding: PX }}>

          {/* Section header */}
          <FadeIn>
            <SectionHead
              badge="Get Started" badgeIcon={UserPlus} badgeBg="#E2F0F3" badgeColor="#0C637E"
              title="Create Your Account in Minutes"
              sub="Not sure where to begin? Pick your role below and we'll walk you through every step — from download to your first day on MediFind."
            />
          </FadeIn>

          {/* ── Role Tab Selector ── */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.75rem', marginBottom: '3.5rem' }}>
            {(['Patient', 'Caregiver', 'Responder']).map((role) => {
              const rd = getStartedData[role];
              const isActive = activeRole === role;
              return (
                <motion.button
                  key={role}
                  onClick={() => setActiveRole(role)}
                  whileHover={{ scale: 1.04 }}
                  whileTap={{ scale: 0.97 }}
                  aria-pressed={isActive}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '0.55rem',
                    padding: '0.75rem 1.75rem', borderRadius: '100px',
                    border: isActive ? 'none' : `1.5px solid ${rd.color}30`,
                    background: isActive ? rd.gradient : `${rd.color}08`,
                    color: isActive ? 'white' : rd.color,
                    fontWeight: 600, fontSize: '0.9rem',
                    cursor: 'pointer', fontFamily: P,
                    transition: 'all 0.25s ease',
                    boxShadow: isActive ? `0 6px 20px ${rd.color}35` : 'none',
                  }}
                >
                  <rd.icon size={16} />
                  {role}
                </motion.button>
              );
            })}
          </div>

          {/* ── Tab content with animated transition ── */}
          <AnimatePresence mode="wait">
            <motion.div
              key={activeRole}
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -16 }}
              transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
            >
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '4rem', alignItems: 'start' }}>

                {/* ── Left: vertical step timeline ── */}
                <div>
                  {/* Role headline */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', marginBottom: '2.5rem', padding: '1.25rem 1.5rem', borderRadius: '16px', background: `${gs.color}08`, border: `1px solid ${gs.color}20` }}>
                    <div style={{ width: '44px', height: '44px', borderRadius: '12px', background: gs.gradient, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <gs.icon size={22} color="white" />
                    </div>
                    <div>
                      <div style={{ fontWeight: 700, color: '#0F172A', fontSize: '1rem', fontFamily: P }}>
                        {activeRole === 'Patient' ? 'Registering as a Patient' : activeRole === 'Caregiver' ? 'Registering as a Caregiver' : 'Registering as a Responder'}
                      </div>
                      <div style={{ fontSize: '0.8rem', color: gs.color, fontWeight: 500, fontFamily: P, marginTop: '2px' }}>
                        {gs.tagline}
                      </div>
                    </div>
                    {/* Step count badge */}
                    <div style={{ marginLeft: 'auto', flexShrink: 0, background: gs.gradient, color: 'white', borderRadius: '100px', padding: '0.3rem 0.9rem', fontSize: '0.72rem', fontWeight: 700, fontFamily: P, whiteSpace: 'nowrap' }}>
                      {gs.steps.length} steps
                    </div>
                  </div>

                  {/* Steps */}
                  <div style={{ position: 'relative' }}>
                    {gs.steps.map((step, i) => {
                      const isLast = i === gs.steps.length - 1;
                      return (
                        <motion.div
                          key={i}
                          initial={{ opacity: 0, x: -16 }}
                          animate={{ opacity: 1, x: 0 }}
                          transition={{ delay: i * 0.07, duration: 0.4 }}
                          style={{ display: 'flex', gap: '1.25rem', position: 'relative' }}
                        >
                          {/* Vertical connector line */}
                          {!isLast && (
                            <div style={{ position: 'absolute', left: '19px', top: '46px', bottom: 0, width: '2px', background: `linear-gradient(180deg, ${gs.color}40, ${gs.color}08)`, zIndex: 0 }} />
                          )}

                          {/* Step circle */}
                          <div style={{
                            width: '40px', height: '40px', borderRadius: '50%',
                            background: gs.gradient, flexShrink: 0,
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            color: 'white', fontWeight: 700, fontSize: '0.82rem',
                            position: 'relative', zIndex: 1,
                            boxShadow: `0 4px 14px ${gs.color}35`,
                            fontFamily: P,
                          }}>
                            {i + 1}
                          </div>

                          {/* Step body */}
                          <div style={{ paddingBottom: isLast ? 0 : '2rem', flex: 1 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.3rem' }}>
                              <h4 style={{ fontWeight: 600, color: '#0F172A', fontSize: '0.95rem', fontFamily: P, margin: 0 }}>{step.title}</h4>
                            </div>
                            <p style={{ color: '#64748B', fontSize: '0.855rem', lineHeight: 1.7, fontFamily: P, fontWeight: 400, margin: '0 0 0.6rem' }}>{step.desc}</p>

                            {/* ── Patient Mode Cards (Standard vs Deaf & Mute) ── */}
                            {step.modes && (
                              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginTop: '0.5rem', marginBottom: '0.25rem' }}>
                                {step.modes.map((mode) => (
                                  <div key={mode.label} style={{
                                    padding: '1.1rem 1rem',
                                    borderRadius: '14px',
                                    background: mode.bg,
                                    border: `1.5px solid ${mode.color}30`,
                                    transition: 'box-shadow 0.2s',
                                  }}
                                    onMouseEnter={e => e.currentTarget.style.boxShadow = `0 6px 20px ${mode.color}20`}
                                    onMouseLeave={e => e.currentTarget.style.boxShadow = 'none'}
                                  >
                                    {/* Mode header */}
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.55rem', marginBottom: '0.85rem' }}>
                                      <div style={{ width: '34px', height: '34px', borderRadius: '9px', background: `${mode.color}18`, border: `1px solid ${mode.color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                                        <mode.icon size={17} color={mode.color} />
                                      </div>
                                      <div>
                                        <div style={{ fontWeight: 700, fontSize: '0.83rem', color: '#0F172A', fontFamily: P, lineHeight: 1.2 }}>{mode.label}</div>
                                        <div style={{ fontSize: '0.6rem', fontWeight: 700, color: mode.color, textTransform: 'uppercase', letterSpacing: '0.08em', fontFamily: P }}>{mode.tag}</div>
                                      </div>
                                    </div>
                                    {/* Feature list */}
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.38rem' }}>
                                      {mode.features.map((feat) => (
                                        <div key={feat} style={{ display: 'flex', alignItems: 'flex-start', gap: '0.42rem' }}>
                                          <CheckCircle size={11} color={mode.color} style={{ flexShrink: 0, marginTop: '2px' }} />
                                          <span style={{ fontSize: '0.75rem', color: '#475569', fontFamily: P, lineHeight: 1.45, fontWeight: 400 }}>{feat}</span>
                                        </div>
                                      ))}
                                    </div>
                                  </div>
                                ))}
                              </div>
                            )}

                            {step.note && (
                              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.45rem', padding: '0.55rem 0.85rem', background: '#E2F0F3', border: '1px solid #A8D8E8', borderRadius: '10px', fontSize: '0.78rem', color: '#0C637E', fontFamily: P, fontWeight: 500 }}>
                                <span style={{ flexShrink: 0, marginTop: '1px' }}>💡</span>
                                <span>{step.note}</span>
                              </div>
                            )}
                          </div>
                        </motion.div>
                      );
                    })}
                  </div>
                </div>

                {/* ── Right: sticky CTA download card ── */}
                <div style={{ position: 'sticky', top: '140px' }}>
                  <div style={{ background: gs.gradient, borderRadius: '28px', padding: '2.5rem 2rem', textAlign: 'center', boxShadow: `0 20px 50px ${gs.color}30` }}>

                    {/* Phone mockup icon area */}
                    <div style={{ width: '72px', height: '72px', borderRadius: '20px', background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.5rem', border: '1px solid rgba(255,255,255,0.25)' }}>
                      <Smartphone size={34} color="white" />
                    </div>

                    <h3 style={{ color: 'white', fontWeight: 700, fontSize: '1.25rem', marginBottom: '0.4rem', fontFamily: P }}>Download MediFind</h3>
                    <p style={{ color: 'rgba(255,255,255,0.72)', fontSize: '0.82rem', lineHeight: 1.65, fontFamily: P, marginBottom: '1.75rem' }}>
                      Free to download. No credit card required.<br />Available on Android — iOS coming soon.
                    </p>

                    {/* Store buttons */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                      <StoreButton store="android" available={PLAY_STORE_URL !== '#'} href={PLAY_STORE_URL} roleColor={gs.color} />
                      <StoreButton store="ios" available={false} href="#" roleColor={gs.color} />
                    </div>

                    {/* Divider */}
                    <div style={{ borderTop: '1px solid rgba(255,255,255,0.15)', margin: '1.75rem 0 1.25rem' }} />

                    {/* Step count reminder */}
                    <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.65)', fontFamily: P, fontWeight: 500 }}>
                      Only <strong style={{ color: 'white' }}>{gs.steps.length} steps</strong> to get fully set up as a {activeRole}
                    </div>
                  </div>

                  {/* Role switcher hint below card */}
                  <div style={{ textAlign: 'center', marginTop: '1.25rem' }}>
                    <p style={{ fontSize: '0.78rem', color: '#94A3B8', fontFamily: P }}>
                      Not a {activeRole}?{' '}
                      {(['Patient', 'Caregiver', 'Responder']).filter(r => r !== activeRole).map((r, idx, arr) => (
                        <React.Fragment key={r}>
                          <button onClick={() => setActiveRole(r)} style={{ background: 'none', border: 'none', color: '#0C637E', fontWeight: 600, fontSize: '0.78rem', cursor: 'pointer', fontFamily: P, padding: 0, textDecoration: 'underline', textUnderlineOffset: '2px' }}>
                            {r}
                          </button>
                          {idx < arr.length - 1 && <span style={{ color: '#CBD5E1' }}> · </span>}
                        </React.Fragment>
                      ))}
                    </p>
                  </div>
                </div>

              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      </section>

      {/* ── Deaf & Mute Highlight ──────────────────────────────── */}
      <section style={{ padding: '5.5rem 0', background: 'linear-gradient(135deg,#0C637E 0%,#2891C2 100%)' }}>
        <div style={{ padding: PX, textAlign: 'center' }}>
          <FadeIn>
            <div style={{ width: '68px', height: '68px', borderRadius: '18px', background: 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.75rem' }}>
              <Mic size={30} color="white" />
            </div>
            <SectionHead badge="Inclusive Design" badgeBg="rgba(255,255,255,0.15)" badgeColor="white"
              title="The First Emergency App Designed for Silence."
              sub="MediFind's Silent Request system lets Deaf and Mute patients trigger a full emergency response using pre-written phrases and icon-driven communication — no speaking, no calling, no barriers."
              light />
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: '1rem', maxWidth: '680px', margin: '0 auto' }}>
              {[
                { icon: Smartphone,    label: 'One-Tap SOS',         sub: 'No voice required' },
                { icon: MessageSquare, label: 'Pre-Written Phrases',  sub: 'Customizable shortcuts' },
                { icon: Eye,           label: 'Visual Alerts',        sub: 'Screen flash + vibration' },
              ].map(item => (
                <div key={item.label} style={{ background: 'rgba(255,255,255,0.1)', borderRadius: '14px', padding: '1.4rem 1rem', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.15)' }}>
                  <item.icon size={22} color="white" style={{ marginBottom: '0.6rem' }} />
                  <div style={{ fontWeight: 600, color: 'white', fontSize: '0.875rem', marginBottom: '0.2rem', fontFamily: P }}>{item.label}</div>
                  <div style={{ fontSize: '0.72rem', color: 'rgba(255,255,255,0.65)', fontFamily: P, fontWeight: 400 }}>{item.sub}</div>
                </div>
              ))}
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── FAQ ────────────────────────────────────────────────── */}
      <section style={{ padding: '4.5rem 0', background: 'white' }}>
        <div style={{ padding: PX, maxWidth: '820px', margin: '0 auto' }}>
          <FadeIn>
            <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
              <h2 style={{ fontSize: '2rem', fontWeight: 700, color: '#0F172A', marginBottom: '0.6rem', fontFamily: P }}>Frequently Asked Questions</h2>
              <p style={{ color: '#64748B', fontSize: '0.9rem', fontFamily: P, fontWeight: 400 }}>Everything you need to know about MediFind.</p>
            </div>
          </FadeIn>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.65rem' }}>
            {faqs.map((faq, i) => (
              <FadeIn key={i} delay={i * 55}>
                <div style={{ border: '1px solid #E2E8F0', borderRadius: '14px', overflow: 'hidden', background: openFaq === i ? '#F8FAFC' : 'white', transition: 'background 0.2s' }}>
                  <button onClick={() => setOpenFaq(openFaq === i ? null : i)}
                    aria-expanded={openFaq === i}
                    style={{ width: '100%', padding: '1.1rem 1.4rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left', fontFamily: P }}>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem', color: '#0F172A', paddingRight: '1rem', fontFamily: P }}>{faq.q}</span>
                    <ChevronDown size={17} color="#94A3B8" style={{ flexShrink: 0, transform: openFaq === i ? 'rotate(180deg)' : 'none', transition: 'transform 0.25s ease' }} />
                  </button>
                  <AnimatePresence>
                    {openFaq === i && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.25 }}
                        style={{ overflow: 'hidden' }}
                      >
                        <div style={{ padding: '0 1.4rem 1.1rem', fontSize: '0.855rem', color: '#64748B', lineHeight: 1.75, fontFamily: P, fontWeight: 400 }}>{faq.a}</div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ── Contact ────────────────────────────────────────────── */}
      <section id="contact" style={{ padding: '4.5rem 0', background: '#F8FAFC' }}>
        <div style={{ padding: PX, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '5rem', alignItems: 'start' }}>
          <FadeIn>
            <div>
              <Badge icon={MessageSquare} label="Get In Touch" />
              <h2 style={{ fontSize: '2rem', fontWeight: 700, color: '#0F172A', marginBottom: '0.9rem', fontFamily: P }}>Let's Connect</h2>
              <p style={{ color: '#64748B', marginBottom: '2.25rem', lineHeight: 1.8, fontSize: '0.9rem', fontFamily: P, fontWeight: 400 }}>
                Whether you're a hospital, NGO, or individual — we'd love to hear from you. Our team responds within 24 hours.
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1.1rem' }}>
                {[
                  { icon: MessageSquare, label: 'Email',    value: 'support@medifind.pk' },
                  { icon: MapPin,        label: 'Based in', value: 'Pakistan 🇵🇰' },
                ].map(item => (
                  <div key={item.label} style={{ display: 'flex', alignItems: 'center', gap: '0.875rem' }}>
                    <div style={{ width: '42px', height: '42px', borderRadius: '11px', background: '#E2F0F3', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <item.icon size={17} color="#0C637E" />
                    </div>
                    <div>
                      <div style={{ fontSize: '0.7rem', fontWeight: 600, color: '#94A3B8', textTransform: 'uppercase', letterSpacing: '0.07em', fontFamily: P }}>{item.label}</div>
                      <div style={{ fontSize: '0.875rem', fontWeight: 500, color: '#1E293B', fontFamily: P }}>{item.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </FadeIn>
          <FadeIn delay={140}>
            <div style={{ background: 'white', borderRadius: '20px', padding: '2.25rem', boxShadow: '0 4px 20px rgba(0,0,0,0.05)', border: '1px solid #E2E8F0' }}>
              <ContactForm />
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── CTA Banner ─────────────────────────────────────────── */}
      <section style={{ padding: '5rem 0', background: 'linear-gradient(135deg,#04364E 0%,#0C637E 60%,#2496A7 100%)' }}>
        <div style={{ padding: PX, textAlign: 'center' }}>
          <FadeIn>
            <h2 style={{ fontSize: '2.1rem', fontWeight: 700, color: 'white', marginBottom: '1rem', lineHeight: 1.3, fontFamily: P }}>
              Be Ready Before the Emergency.
            </h2>
            <p style={{ color: 'rgba(255,255,255,0.75)', fontSize: '0.95rem', marginBottom: '2.25rem', lineHeight: 1.8, fontFamily: P, fontWeight: 400, maxWidth: '520px', margin: '0 auto 2.25rem' }}>
              Download MediFind today and give yourself and your family a fighting chance when every second matters.
            </p>
            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
              <motion.a
                href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer"
                whileHover={{ scale: 1.05, boxShadow: '0 10px 30px rgba(0,0,0,0.25)' }}
                whileTap={{ scale: 0.97 }}
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.8rem 1.6rem', borderRadius: '10px', background: 'white', color: '#0C637E', fontWeight: 600, fontSize: '0.875rem', textDecoration: 'none', cursor: 'pointer', fontFamily: P }}
              >
                <Download size={15} /> Download Free
              </motion.a>
              <motion.a
                href="#get-started"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.97 }}
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.8rem 1.6rem', borderRadius: '10px', background: 'rgba(255,255,255,0.14)', color: 'white', fontWeight: 600, fontSize: '0.875rem', textDecoration: 'none', border: '1px solid rgba(255,255,255,0.25)', cursor: 'pointer', fontFamily: P }}
              >
                <UserPlus size={14} /> Create Your Account <ArrowRight size={14} />
              </motion.a>
              <Link to="/login"
                style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.8rem 1.6rem', borderRadius: '10px', background: 'rgba(255,255,255,0.08)', color: 'rgba(255,255,255,0.75)', fontWeight: 600, fontSize: '0.875rem', textDecoration: 'none', border: '1px solid rgba(255,255,255,0.15)', fontFamily: P, transition: 'color 0.2s, background 0.2s' }}
                onMouseEnter={e => { e.currentTarget.style.color = 'white'; e.currentTarget.style.background = 'rgba(255,255,255,0.15)'; }}
                onMouseLeave={e => { e.currentTarget.style.color = 'rgba(255,255,255,0.75)'; e.currentTarget.style.background = 'rgba(255,255,255,0.08)'; }}>
                Admin Portal <ArrowRight size={14} />
              </Link>
            </div>
          </FadeIn>
        </div>
      </section>

      {/* ── Footer ─────────────────────────────────────────────── */}
      <footer style={{ background: '#0F172A', color: 'rgba(255,255,255,0.55)', padding: '4rem 0 2rem', fontFamily: P }}>
        <div style={{ padding: PX }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr 1fr 1fr', gap: '3rem', marginBottom: '3rem' }}>
            <div>
              <div style={{ marginBottom: '1.5rem' }}>
                <img src={logo} alt="MediFind" style={{ height: '110px', objectFit: 'contain', filter: 'brightness(1.15) drop-shadow(0 0 8px rgba(36,150,167,0.45))' }} loading="lazy" />
              </div>
              <p style={{ fontSize: '0.83rem', lineHeight: 1.75, maxWidth: '230px', fontFamily: P, fontWeight: 400 }}>Pakistan's first inclusive emergency response platform. Built to save every life.</p>
            </div>
            <div>
              <div style={{ fontWeight: 600, color: 'white', marginBottom: '1rem', fontSize: '0.83rem', fontFamily: P }}>Platform</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.55rem' }}>
                {[['Features', '#features'], ['How It Works', '#how-it-works'], ['Get Started', '#get-started']].map(([label, href]) => (
                  <a key={href} href={href} style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                    onMouseEnter={e => e.target.style.color = 'white'}
                    onMouseLeave={e => e.target.style.color = 'rgba(255,255,255,0.45)'}>
                    {label}
                  </a>
                ))}
                <Link to="/login"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>Admin Portal</Link>
              </div>
            </div>
            <div>
              <div style={{ fontWeight: 600, color: 'white', marginBottom: '1rem', fontSize: '0.83rem', fontFamily: P }}>Legal</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.55rem' }}>
                <Link to="/terms"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>Terms & Conditions</Link>
                <Link to="/privacy"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>Privacy Policy</Link>
                <a href="#contact"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>Contact Us</a>
              </div>
            </div>
            <div>
              <div style={{ fontWeight: 600, color: 'white', marginBottom: '1rem', fontSize: '0.83rem', fontFamily: P }}>Company</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.55rem' }}>
                <a href="#about"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>About</a>
                <a href="#contact"
                  style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)', textDecoration: 'none', transition: 'color 0.2s', fontFamily: P, fontWeight: 400 }}
                  onMouseEnter={e => e.currentTarget.style.color = 'white'}
                  onMouseLeave={e => e.currentTarget.style.color = 'rgba(255,255,255,0.45)'}>Contact</a>
              </div>
            </div>
          </div>
          <div style={{ borderTop: '1px solid rgba(255,255,255,0.07)', paddingTop: '1.75rem', display: 'flex', justifyContent: 'center', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <p style={{ fontSize: '0.78rem', fontFamily: P, fontWeight: 400 }}>© 2026 MediFind. All rights reserved. Made with ❤️ in Pakistan.</p>
          </div>
        </div>
      </footer>

      {/* ── Back to Top Button ─────────────────────────────────── */}
      <AnimatePresence>
        {showBackToTop && (
          <motion.button
            initial={{ opacity: 0, scale: 0.7, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.7, y: 20 }}
            transition={{ duration: 0.25 }}
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            aria-label="Back to top"
            title="Back to top"
            style={{
              position: 'fixed', bottom: '2rem', right: '2rem', zIndex: 999,
              width: '48px', height: '48px', borderRadius: '50%',
              background: 'linear-gradient(135deg,#0C637E,#2496A7)',
              color: 'white', border: 'none', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 6px 20px rgba(12,99,126,0.4)',
            }}
            whileHover={{ scale: 1.12, boxShadow: '0 10px 28px rgba(12,99,126,0.55)' }}
            whileTap={{ scale: 0.92 }}
          >
            <ChevronUp size={22} />
          </motion.button>
        )}
      </AnimatePresence>

    </div>
  );
};

export default LandingPage;

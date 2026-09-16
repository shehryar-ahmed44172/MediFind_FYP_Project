import React, { useState, useEffect } from 'react';
import {
  UserCheck, Shield, ExternalLink, Check, X,
  FileText, RefreshCw, Clock, Printer, AlertTriangle,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import { lightTokenCss } from '../../components/uiStyles';
import { resolveFileUrl } from '../../utils/resolveFileUrl';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function timeAgo(dateStr) {
  if (!dateStr) return 'Unknown';
  const diff  = Date.now() - new Date(dateStr).getTime();
  const mins  = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days  = Math.floor(diff / 86400000);
  if (days  > 0) return `${days} day${days  > 1 ? 's' : ''} ago`;
  if (hours > 0) return `${hours} hr${hours > 1 ? 's' : ''} ago`;
  if (mins  > 0) return `${mins} min${mins  > 1 ? 's' : ''} ago`;
  return 'Just now';
}

function waitColor(dateStr) {
  if (!dateStr) return 'var(--text-muted)';
  const days = (Date.now() - new Date(dateStr).getTime()) / 86400000;
  if (days >= 2) return 'var(--error-fg)';
  if (days >= 1) return 'var(--warning-fg)';
  return 'var(--text-muted)';
}

const RESPONDER_TYPE_LABELS = {
  RESCUE_OFFICER:  'Rescue Officer (e.g. 1122)',
  PARAMEDIC:       'Paramedic',
  EMT:             'Emergency Medical Technician (EMT)',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER:       'Community Volunteer',
};

// ─── Formal Application Modal (printable A4 form) ─────────────────────────────

const ApplicationModal = ({ responder, onClose }) => {
  const submittedDate = responder.user?.createdAt
    ? new Date(responder.user.createdAt).toLocaleDateString('en-PK', { year: 'numeric', month: 'long', day: 'numeric' })
    : 'N/A';

  const [reviewedBy,   setReviewedBy]   = React.useState('');
  const [reviewDate,   setReviewDate]   = React.useState(new Date().toLocaleDateString('en-PK'));
  const [rejectReason, setRejectReason] = React.useState('');
  const [adminSig,     setAdminSig]     = React.useState('');

  const handlePrint = () => {
    const printArea = document.getElementById('application-print-area');
    if (!printArea) return;
    const clone    = printArea.cloneNode(true);
    const origEls  = printArea.querySelectorAll('input, textarea, select');
    const cloneEls = clone.querySelectorAll('input, textarea, select');
    origEls.forEach((orig, i) => {
      if (!cloneEls[i]) return;
      if (orig.type === 'radio' || orig.type === 'checkbox') {
        if (orig.checked) cloneEls[i].setAttribute('checked', 'checked');
        else cloneEls[i].removeAttribute('checked');
      } else {
        cloneEls[i].setAttribute('value', orig.value);
        cloneEls[i].textContent = orig.value;
      }
    });
    const win = window.open('', '_blank', 'width=900,height=700');
    win.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8"/>
      <title>MediFind — Emergency Responder Application</title>
      <link href="https://fonts.googleapis.com/css2?family=Great+Vibes&display=swap" rel="stylesheet"/>
      <style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;color:#111;background:white}
      @media print{@page{margin:15mm;size:A4}body{-webkit-print-color-adjust:exact;print-color-adjust:exact}
      .print-page-break{page-break-before:always!important;break-before:page!important}}
      input,textarea{border:none;border-bottom:1.5px solid var(--text-muted);width:100%;padding:4px 0;font-size:0.875rem;font-family:Arial,sans-serif;background:transparent;outline:none}
      ${lightTokenCss()}</style></head><body>${clone.innerHTML}</body></html>`);
    win.document.close();
    win.focus();
    setTimeout(() => { win.print(); win.close(); }, 900);
  };

  const docs = [
    { label: 'CNIC — Front',                       url: resolveFileUrl(responder.cnicImageUrl),              required: true  },
    { label: 'CNIC — Back',                         url: resolveFileUrl(responder.cnicBackImageUrl),          required: true  },
    { label: 'Employee / Professional ID — Front',  url: resolveFileUrl(responder.employeeCardImageUrl),      required: true  },
    { label: 'Employee / Professional ID — Back',   url: resolveFileUrl(responder.employeeCardBackImageUrl),  required: false },
    { label: 'Driving License',                     url: resolveFileUrl(responder.drivingLicenseUrl),         required: true  },
    { label: 'Motorbike Documents (RC Book)',        url: resolveFileUrl(responder.motorbikeDocUrl),           required: true  },
  ];

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 10000,
      background: 'rgba(0,0,0,0.65)', backdropFilter: 'blur(4px)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      padding: '1.5rem 1rem', overflowY: 'auto',
    }}>
      {/* Modal shell — fixed max-height so toolbar stays pinned and form scrolls */}
      <div style={{
        width: '100%', maxWidth: '860px',
        maxHeight: 'calc(100vh - 3rem)',
        display: 'flex', flexDirection: 'column',
        borderRadius: '18px', overflow: 'hidden',
        boxShadow: '0 24px 64px rgba(0,0,0,0.4)',
        background: 'white',
      }}>

        {/* ── Sticky toolbar ── */}
        <div className="no-print" style={{
          flexShrink: 0,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '12px 20px',
          background: 'white', borderBottom: '1px solid var(--border)',
        }}>
          <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)', fontWeight: 600 }}>
            Emergency Responder Application
          </span>
          <div style={{ display: 'flex', gap: '0.75rem' }}>
            <button onClick={handlePrint} style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.55rem 1.15rem', borderRadius: '10px',
              background: 'var(--primary)', color: 'white', border: 'none',
              fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer', fontFamily: 'inherit',
            }}>
              <Printer size={14} /> Print / Save as PDF
            </button>
            <button onClick={onClose} style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.55rem 1.15rem', borderRadius: '10px',
              background: 'white', color: 'var(--text-sub)', border: '1px solid var(--border)',
              fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer', fontFamily: 'inherit',
            }}>
              <X size={14} /> Close
            </button>
          </div>
        </div>

        {/* ── Scrollable form body ── */}
        <div style={{ flex: 1, overflowY: 'auto' }}>

      {/* Printable form */}
      <div id="application-print-area" data-theme="light" style={{
        width: '100%', background: 'white',
        fontFamily: 'Arial, sans-serif',
      }}>
        {/* Banner */}
        <div style={{ background: 'linear-gradient(135deg,var(--primary-dark) 0%,var(--primary) 100%)', padding: '2rem 2.5rem', color: 'white' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '0.7rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, marginBottom: '0.4rem' }}>
                MediFind Healthcare Emergency Network · Pakistan
              </div>
              <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: 0, letterSpacing: '-0.02em', color: 'white' }}>
                Emergency Responder Application Form
              </h1>
              <p style={{ margin: '0.35rem 0 0', opacity: 0.75, fontSize: '0.875rem', color: 'white' }}>
                Submitted for Administrative Review &amp; Credential Verification
              </p>
            </div>
            <div style={{ textAlign: 'right', fontSize: '0.78rem', opacity: 0.85 }}>
              <div style={{ fontWeight: 700 }}>Application ID</div>
              <div style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>{responder.id?.slice(0, 8).toUpperCase() || 'N/A'}</div>
              <div style={{ marginTop: '0.5rem', fontWeight: 700 }}>Date Submitted</div>
              <div>{submittedDate}</div>
            </div>
          </div>
        </div>

        <div style={{ padding: '2rem 2.5rem' }}>
          <AppSectionTitle num="1" title="Personal Information" />
          <AppFieldGrid fields={[
            { label: 'Full Name',     value: responder.user?.fullName    || '—' },
            { label: 'Email Address', value: responder.user?.email       || '—' },
            { label: 'Phone Number',  value: responder.user?.phoneNumber || '—' },
            { label: 'City',          value: responder.user?.city        || '—' },
            { label: 'CNIC Number',   value: responder.cnic              || '—' },
            { label: 'Date of Birth', value: (() => {
              if (!responder.user?.dateOfBirth) return '—';
              const dob = new Date(responder.user.dateOfBirth);
              const age = Math.floor((new Date().getTime() - dob.getTime()) / (365.25 * 24 * 3600 * 1000));
              return `${dob.toLocaleDateString('en-PK', { year: 'numeric', month: 'long', day: 'numeric' })}  (Age: ${age})`;
            })() },
          ]} />

          <AppSectionTitle num="2" title="Professional Credentials" />
          <AppFieldGrid fields={[
            { label: 'Responder Type',        value: RESPONDER_TYPE_LABELS[responder.responderType] || responder.responderType || '—' },
            { label: 'License Number',        value: responder.licenseNumber    || '—' },
            { label: 'Organization',          value: responder.organization     || 'Independent / Not Affiliated' },
            { label: 'Vehicle Type',          value: responder.vehicleType === 'MOTORBIKE_AMBULANCE' ? 'Motorbike Ambulance' : (responder.vehicleType || 'Not Provided') },
            { label: 'Motorbike Reg. Number', value: responder.motorbikeNumber  || 'Not Provided' },
          ]} />
          <SpecializationRow specs={
            Array.isArray(responder.specialization) && responder.specialization.length
              ? responder.specialization : ['General Emergency']
          } />

          <AppSectionTitle num="3" title="Identity &amp; Credential Documents" />
          <p style={{ fontSize: '0.83rem', color: 'var(--text-muted)', margin: '-0.25rem 0 1.25rem', lineHeight: 1.6 }}>
            Documents uploaded by the applicant during registration. Verify each carefully before deciding.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '2rem' }}>
            {docs.map(({ label, url, required }) => (
              <div key={label} style={{ border: `1.5px solid ${url ? 'var(--border)' : 'var(--border)'}`, borderRadius: '12px', overflow: 'hidden', background: url ? 'var(--surface-alt)' : 'var(--surface-alt)' }}>
                <div style={{ padding: '0.55rem 0.875rem', borderBottom: `1px solid ${url ? 'var(--border)' : 'var(--border)'}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: url ? 'var(--primary-pale)' : 'var(--tint-slate)' }}>
                  <span style={{ fontWeight: 700, fontSize: '0.78rem', color: 'var(--text-sub)' }}>{label}</span>
                  <span style={{ fontSize: '0.63rem', fontWeight: 700, padding: '0.15rem 0.5rem', borderRadius: '999px', background: url ? 'var(--tint-green)' : 'var(--tint-red)', color: url ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                    {url ? 'UPLOADED' : required ? 'MISSING ⚠' : 'NOT PROVIDED'}
                  </span>
                </div>
                {url ? (
                  <div style={{ position: 'relative' }}>
                    <img src={url} alt={label} style={{ width: '100%', height: '160px', objectFit: 'cover', display: 'block' }}
                      onError={e => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }} />
                    <div style={{ display: 'none', height: '160px', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '8px', background: 'var(--tint-slate)', color: 'var(--text-muted)', fontSize: '0.78rem' }}>
                      <FileText size={24} style={{ opacity: 0.4 }} /><span>Cannot display</span>
                    </div>
                    <button className="no-print" onClick={() => window.open(url, '_blank')} style={{ position: 'absolute', bottom: '8px', right: '8px', background: 'rgba(0,0,0,0.6)', color: 'white', border: 'none', borderRadius: '7px', padding: '4px 10px', fontSize: '0.7rem', fontWeight: 700, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <ExternalLink size={11} /> Open Full
                    </button>
                  </div>
                ) : (
                  <div style={{ height: '160px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '8px', color: 'var(--text-muted)', fontSize: '0.82rem' }}>
                    <Shield size={28} style={{ opacity: 0.25 }} />
                    <span style={{ fontWeight: 600 }}>{required ? 'Required — Not Submitted' : 'Optional — Not Provided'}</span>
                  </div>
                )}
              </div>
            ))}
          </div>

          <AppSectionTitle num="4" title="Applicant Declaration" />
          <div style={{ background: 'var(--tint-amber)', border: '1px solid var(--warning-border)', borderRadius: '10px', padding: '1.25rem 1.5rem', marginBottom: '2rem' }}>
            <p style={{ fontSize: '0.875rem', color: 'var(--text-sub)', lineHeight: 1.8, margin: 0 }}>
              By submitting this application, <strong>{responder.user?.fullName || '[Applicant]'}</strong> hereby declares and confirms:
            </p>
            <ol style={{ margin: '1rem 0 0', paddingLeft: '1.4rem', fontSize: '0.875rem', color: 'var(--text-sub)', lineHeight: 2.1 }}>
              <li>All information provided is accurate, complete, and truthful.</li>
              <li>I hold valid professional certification as a <strong>{RESPONDER_TYPE_LABELS[responder.responderType] || 'Emergency Responder'}</strong> and license <strong>{responder.licenseNumber || 'N/A'}</strong> is genuine and active.</li>
              <li>I understand I am joining the MediFind Emergency Response Network and will respond to real medical emergencies.</li>
              <li>I acknowledge that providing false information or fraudulent documents is grounds for immediate rejection and may result in legal action.</li>
              <li>I consent to credential verification with relevant healthcare and government authorities.</li>
              <li>I understand my application will be reviewed within 2–3 business days.</li>
            </ol>
          </div>

          <div className="print-page-break" style={{ paddingTop: '0.5rem' }}>
            <AppSectionTitle num="5" title="Administrative Review — For Official Use Only" />
            <div style={{ border: '1.5px dashed var(--border)', borderRadius: '10px', padding: '1.25rem 1.5rem', marginBottom: '1.5rem', background: 'var(--surface-alt)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.25rem', marginBottom: '1.25rem' }}>
                <ReviewField label="Reviewed by (Admin Name)" value={reviewedBy} onChange={e => setReviewedBy(e.target.value)} placeholder="Enter admin name" />
                <ReviewField label="Review Date" value={reviewDate} onChange={e => setReviewDate(e.target.value)} placeholder="DD/MM/YYYY" />
              </div>
              <div style={{ marginBottom: '1.25rem' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.6rem', background: 'var(--tint-blue)', border: '1px solid var(--info-border)', borderRadius: '8px', padding: '0.75rem 1rem' }}>
                  <span style={{ fontSize: '1rem', flexShrink: 0 }}>ℹ️</span>
                  <div>
                    <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.2rem' }}>Decision Recorded Digitally</div>
                    <div style={{ fontSize: '0.78rem', color: 'var(--primary-light)', lineHeight: 1.5 }}>
                      The approval or rejection is executed via the <strong>Approve</strong> / <strong>Reject</strong> buttons in the Verification Queue. The outcome is automatically logged in the system audit trail.
                    </div>
                  </div>
                </div>
              </div>
              <div style={{ marginBottom: '1.25rem' }}>
                <ReviewField label="Notes / Rejection Reason (if applicable)" value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="Add review notes or state reason if rejected" />
              </div>
              <SignatureStampField value={adminSig} onChange={e => setAdminSig(e.target.value)} />
            </div>
          </div>

          <div style={{ marginTop: '1.5rem', paddingTop: '1rem', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
            <span>MediFind Healthcare Emergency Network · Pakistan · Confidential</span>
            <span>Application Ref: {responder.id?.slice(0, 16).toUpperCase() || 'N/A'}</span>
          </div>
        </div>
      </div>
        </div>
      </div>
    </div>
  );
};

// ─── Responder Detail Modal (replaces the right-side panel) ──────────────────
// Opens centered when the admin clicks a card in the queue list.

const ResponderDetailModal = ({ responder, processingId, onApprove, onReject, onViewApplication, onClose }) => {
  const [lightbox, setLightbox] = useState(null);

  const docs = [
    { label: 'CNIC — Front',       url: resolveFileUrl(responder.cnicImageUrl),             required: true  },
    { label: 'CNIC — Back',        url: resolveFileUrl(responder.cnicBackImageUrl),         required: true  },
    { label: 'Employee ID — Front',url: resolveFileUrl(responder.employeeCardImageUrl),     required: true  },
    { label: 'Employee ID — Back', url: resolveFileUrl(responder.employeeCardBackImageUrl), required: false },
  ];

  const isProcessing = processingId === responder.userId;

  return (
    <>
      {/* Backdrop */}
      <motion.div
        key="backdrop"
        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        onClick={onClose}
        style={{ position: 'fixed', inset: 0, zIndex: 9000, background: 'rgba(0,0,0,0.52)', backdropFilter: 'blur(3px)' }}
      />

      {/* Modal card */}
      <motion.div
        key="modal"
        initial={{ opacity: 0, scale: 0.95, y: 24 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 24 }}
        transition={{ type: 'spring', stiffness: 340, damping: 30 }}
        style={{
          position: 'fixed', inset: 0, zIndex: 9001,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: '1.5rem', pointerEvents: 'none',
        }}
      >
        <div
          onClick={e => e.stopPropagation()}
          style={{
            pointerEvents: 'all',
            width: '100%', maxWidth: '820px',
            maxHeight: '90vh', display: 'flex', flexDirection: 'column',
            background: 'var(--surface)', borderRadius: '20px',
            boxShadow: '0 32px 80px rgba(0,0,0,0.28)',
            overflow: 'hidden',
          }}
        >
          {/* ── Modal Header ── */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: '1.25rem',
            padding: '1.5rem 1.75rem',
            background: 'linear-gradient(135deg,var(--primary-dark) 0%,var(--primary) 100%)',
            flexShrink: 0,
          }}>
            {/* Avatar */}
            <div style={{
              width: '60px', height: '60px', borderRadius: '16px',
              background: 'rgba(255,255,255,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '1.625rem', fontWeight: 800, color: 'white', flexShrink: 0,
            }}>
              {responder.user?.fullName?.charAt(0) || '?'}
            </div>

            {/* Name + meta */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800, color: 'white', letterSpacing: '-0.02em' }}>
                {responder.user?.fullName}
              </h2>
              <p style={{ margin: '0.2rem 0 0', fontSize: '0.82rem', color: 'rgba(255,255,255,0.72)' }}>
                {responder.user?.email} · {responder.user?.phoneNumber || 'No phone'}
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', marginTop: '0.35rem', fontSize: '0.75rem', fontWeight: 700, color: 'rgba(255,255,255,0.8)' }}>
                <Clock size={11} />
                Waiting {timeAgo(responder.user?.createdAt)}
              </div>
            </div>

            {/* View Full Application button */}
            <button
              onClick={onViewApplication}
              style={{
                display: 'flex', alignItems: 'center', gap: '0.45rem',
                padding: '0.6rem 1.1rem', borderRadius: '10px',
                background: 'rgba(255,255,255,0.15)', color: 'white',
                border: '1px solid rgba(255,255,255,0.3)',
                fontWeight: 700, fontSize: '0.8rem', cursor: 'pointer', fontFamily: 'inherit',
                flexShrink: 0,
              }}
            >
              <FileText size={14} /> View Full Application
            </button>

            {/* Close × */}
            <button
              onClick={onClose}
              style={{
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                width: '36px', height: '36px', borderRadius: '10px',
                background: 'rgba(255,255,255,0.12)', color: 'white',
                border: '1px solid rgba(255,255,255,0.2)', cursor: 'pointer', flexShrink: 0,
              }}
            >
              <X size={17} />
            </button>
          </div>

          {/* ── Scrollable body ── */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '1.75rem' }}>

            {/* Credentials grid */}
            <p style={{ fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--text-muted)', fontWeight: 700, marginBottom: '0.875rem' }}>
              Professional Credentials
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.75rem', marginBottom: '1.75rem' }}>
              {[
                { label: 'Responder Type', value: RESPONDER_TYPE_LABELS[responder.responderType]?.split('(')[0].trim() || responder.responderType || '—' },
                { label: 'License #',      value: responder.licenseNumber || '—' },
                { label: 'Organization',   value: responder.organization  || 'Independent' },
                { label: 'Vehicle Type',   value: responder.vehicleType === 'MOTORBIKE_AMBULANCE' ? 'Motorbike Ambulance' : (responder.vehicleType || 'Not specified') },
                { label: 'Motorbike Reg.', value: responder.motorbikeNumber || 'Not provided' },
                { label: 'Specializations', value: (Array.isArray(responder.specialization) && responder.specialization.length ? responder.specialization.join(', ') : 'General Emergency') },
              ].map(item => (
                <div key={item.label} style={{ background: 'var(--surface-raised)', borderRadius: '10px', padding: '0.7rem 0.875rem', border: '1px solid var(--border)' }}>
                  <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.25rem' }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-sub)' }}>{item.value}</div>
                </div>
              ))}
            </div>

            {/* Documents */}
            <p style={{ fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--text-muted)', fontWeight: 700, marginBottom: '0.875rem' }}>
              Identity Documents
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '0.75rem' }}>
              {docs.map(({ label, url, required }) => (
                <div key={label} style={{ borderRadius: '12px', overflow: 'hidden', border: `1.5px solid ${url ? 'var(--border)' : 'var(--border)'}`, background: url ? 'var(--surface)' : 'var(--surface-raised)' }}>
                  {/* Header row */}
                  <div style={{ padding: '0.5rem 0.625rem', background: url ? 'var(--primary-pale)' : 'var(--surface-raised)', borderBottom: `1px solid ${url ? 'var(--border)' : 'var(--border)'}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-sub)' }}>{label}</span>
                    <span style={{ fontSize: '0.58rem', fontWeight: 700, padding: '0.12rem 0.4rem', borderRadius: '999px', background: url ? 'var(--tint-green)' : 'var(--tint-red)', color: url ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                      {url ? '✓' : required ? '⚠' : 'N/A'}
                    </span>
                  </div>
                  {/* Preview */}
                  {url ? (
                    <div style={{ position: 'relative', cursor: 'zoom-in', height: '110px', background: 'var(--tint-slate)' }} onClick={() => setLightbox({ url, label })}>
                      <img src={url} alt={label} style={{ width: '100%', height: '110px', objectFit: 'cover', display: 'block' }}
                        onError={e => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }} />
                      <div style={{ display: 'none', height: '110px', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '6px', color: 'var(--text-muted)', fontSize: '0.72rem' }}>
                        <FileText size={20} style={{ opacity: 0.35 }} /><span>Cannot preview</span>
                      </div>
                      <div style={{ position: 'absolute', inset: 0, background: 'rgba(12,99,126,0.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0, transition: 'opacity 0.2s' }}
                        onMouseEnter={e => e.currentTarget.style.opacity = '1'}
                        onMouseLeave={e => e.currentTarget.style.opacity = '0'}>
                        <span style={{ color: 'white', fontWeight: 700, fontSize: '0.72rem' }}>Expand</span>
                      </div>
                    </div>
                  ) : (
                    <div style={{ height: '90px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '5px', color: 'var(--text-muted)', fontSize: '0.72rem' }}>
                      <Shield size={20} style={{ opacity: 0.2 }} />
                      <span style={{ fontWeight: 600 }}>{required ? 'Not Submitted' : 'Not Provided'}</span>
                    </div>
                  )}
                  {url && (
                    <button onClick={() => window.open(url, '_blank')} style={{ width: '100%', padding: '0.4rem', background: 'transparent', border: 'none', borderTop: '1px solid var(--border)', fontSize: '0.65rem', fontWeight: 700, color: 'var(--primary)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '4px', fontFamily: 'inherit' }}
                      onMouseEnter={e => e.currentTarget.style.background = 'var(--primary-pale)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                      <ExternalLink size={10} /> Open original
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* ── Action buttons — pinned at bottom ── */}
          <div style={{
            display: 'flex', gap: '1rem', padding: '1.25rem 1.75rem',
            borderTop: '1px solid var(--border)', background: 'var(--surface)', flexShrink: 0,
          }}>
            <button
              disabled={isProcessing}
              onClick={onReject}
              style={{
                flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
                gap: '0.5rem', padding: '0.875rem', borderRadius: '14px',
                background: 'var(--error-bg)', border: '1px solid var(--error-border)',
                color: 'var(--error-fg)', fontWeight: 700, fontSize: '0.95rem',
                cursor: isProcessing ? 'not-allowed' : 'pointer', opacity: isProcessing ? 0.6 : 1,
                fontFamily: 'inherit', transition: 'all 0.18s',
              }}
            >
              <X size={17} /> Reject
            </button>
            <button
              disabled={isProcessing}
              onClick={onApprove}
              style={{
                flex: 2, display: 'flex', alignItems: 'center', justifyContent: 'center',
                gap: '0.5rem', padding: '0.875rem', borderRadius: '14px',
                background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                color: 'white', border: 'none', fontWeight: 700, fontSize: '0.95rem',
                cursor: isProcessing ? 'not-allowed' : 'pointer', opacity: isProcessing ? 0.7 : 1,
                fontFamily: 'inherit', boxShadow: isProcessing ? 'none' : '0 4px 16px rgba(12,99,126,0.30)',
                transition: 'all 0.18s',
              }}
            >
              <Check size={17} /> {isProcessing ? 'Processing…' : 'Approve Responder'}
            </button>
          </div>
        </div>
      </motion.div>

      {/* Document lightbox */}
      <AnimatePresence>
        {lightbox && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            onClick={() => setLightbox(null)}
            style={{ position: 'fixed', inset: 0, zIndex: 20000, background: 'rgba(0,0,0,0.88)', backdropFilter: 'blur(6px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem', cursor: 'zoom-out' }}
          >
            <motion.div
              initial={{ scale: 0.85, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.85, opacity: 0 }}
              transition={{ type: 'spring', stiffness: 300, damping: 28 }}
              onClick={e => e.stopPropagation()}
              style={{ position: 'relative', maxWidth: '90vw', maxHeight: '88vh', cursor: 'default' }}
            >
              <img src={lightbox.url} alt={lightbox.label} style={{ maxWidth: '90vw', maxHeight: '80vh', borderRadius: '12px', display: 'block', boxShadow: '0 32px 80px rgba(0,0,0,0.7)' }} />
              <div style={{ position: 'absolute', bottom: '-2.5rem', left: 0, right: 0, textAlign: 'center', color: 'rgba(255,255,255,0.75)', fontSize: '0.85rem', fontWeight: 600 }}>
                {lightbox.label}
              </div>
              <button onClick={() => setLightbox(null)} style={{ position: 'absolute', top: '-14px', right: '-14px', width: '36px', height: '36px', borderRadius: '50%', background: 'white', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 16px rgba(0,0,0,0.4)' }}>
                <X size={16} color="var(--text-sub)" />
              </button>
              <a href={lightbox.url} target="_blank" rel="noopener noreferrer" style={{ position: 'absolute', top: '-14px', right: '30px', padding: '0.35rem 0.875rem', borderRadius: '20px', background: 'var(--primary)', color: 'white', fontSize: '0.75rem', fontWeight: 700, textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px', boxShadow: '0 4px 12px rgba(0,0,0,0.3)' }}>
                <ExternalLink size={11} /> Open original
              </a>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

// ─── Rejection Reason Modal ───────────────────────────────────────────────────

const RejectModal = ({ responderName, onConfirm, onCancel, processing }) => {
  const [reason, setReason] = useState('');
  const presets = [
    'Incomplete or unreadable CNIC images',
    'Employee / Professional ID does not match stated organization',
    'License number could not be verified',
    'Documents appear to be expired or invalid',
    'Insufficient professional qualifications for the requested role',
  ];

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 10001, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(3px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.94 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.94 }}
        style={{ background: 'white', borderRadius: '18px', padding: '2rem', width: '100%', maxWidth: '500px', boxShadow: '0 20px 60px rgba(0,0,0,0.25)' }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', marginBottom: '1.25rem' }}>
          <div style={{ width: '42px', height: '42px', borderRadius: '12px', background: 'var(--tint-red)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <AlertTriangle size={20} color="var(--error-fg)" />
          </div>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)' }}>Reject Application</h3>
            <p style={{ margin: 0, fontSize: '0.82rem', color: 'var(--text-muted)' }}>{responderName}</p>
          </div>
        </div>
        <p style={{ fontSize: '0.875rem', color: 'var(--text-sub)', marginBottom: '1rem', lineHeight: 1.6 }}>
          Provide a reason. This message will be sent to the applicant so they know what to correct.
        </p>
        <p style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.5rem' }}>Quick select</p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.875rem' }}>
          {presets.map(p => (
            <button key={p} onClick={() => setReason(p)} style={{ padding: '0.3rem 0.7rem', borderRadius: '999px', border: `1px solid ${reason === p ? 'var(--primary)' : 'var(--border)'}`, background: reason === p ? 'var(--primary-pale)' : 'white', color: reason === p ? 'var(--primary)' : 'var(--text-sub)', fontSize: '0.75rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all 0.15s' }}>
              {p}
            </button>
          ))}
        </div>
        <textarea value={reason} onChange={e => setReason(e.target.value)} placeholder="Or type a custom reason here…" rows={3}
          style={{ width: '100%', borderRadius: '10px', border: '1.5px solid var(--border)', padding: '0.75rem 0.875rem', fontSize: '0.875rem', fontFamily: 'inherit', resize: 'vertical', outline: 'none', color: 'var(--text-sub)', lineHeight: 1.6, boxSizing: 'border-box' }} />
        <div style={{ display: 'flex', gap: '0.875rem', marginTop: '1.25rem' }}>
          <button onClick={onCancel} disabled={processing} style={{ flex: 1, padding: '0.8rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'white', color: 'var(--text-sub)', fontWeight: 700, fontSize: '0.9rem', cursor: 'pointer', fontFamily: 'inherit' }}>
            Cancel
          </button>
          <button onClick={() => reason.trim() && onConfirm(reason.trim())} disabled={!reason.trim() || processing}
            style={{ flex: 2, padding: '0.8rem', borderRadius: '12px', border: 'none', background: !reason.trim() || processing ? 'var(--tint-slate)' : 'var(--error-fg)', color: !reason.trim() || processing ? 'var(--text-muted)' : 'white', fontWeight: 700, fontSize: '0.9rem', cursor: !reason.trim() || processing ? 'not-allowed' : 'pointer', fontFamily: 'inherit', transition: 'all 0.18s' }}>
            {processing ? 'Rejecting…' : 'Confirm Rejection'}
          </button>
        </div>
      </motion.div>
    </div>
  );
};

// ─── Small shared sub-components ─────────────────────────────────────────────

const AppSectionTitle = ({ num, title }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem', marginTop: '1.75rem' }}>
    <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'var(--primary)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.875rem', flexShrink: 0 }}>{num}</div>
    <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 800, color: 'var(--primary)' }} dangerouslySetInnerHTML={{ __html: title }} />
    <div style={{ flex: 1, height: '1px', background: 'var(--border)' }} />
  </div>
);

const AppFieldGrid = ({ fields }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.875rem', marginBottom: '0.5rem' }}>
    {fields.map(({ label, value }) => (
      <div key={label} style={{ background: 'var(--surface-alt)', borderRadius: '8px', padding: '0.6rem 0.875rem', border: '1px solid var(--primary-pale)' }}>
        <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.2rem' }}>{label}</div>
        <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>{value}</div>
      </div>
    ))}
  </div>
);

const ReviewField = ({ label, value, onChange, placeholder }) => (
  <div>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.4rem' }} dangerouslySetInnerHTML={{ __html: label }} />
    <input type="text" value={value} onChange={onChange} placeholder={placeholder}
      style={{ width: '100%', padding: '0.5rem 0.6rem', border: 'none', borderBottom: '1.5px solid var(--text-muted)', fontSize: '0.875rem', fontFamily: 'Arial, sans-serif', color: 'var(--text-main)', background: 'transparent', outline: 'none', fontWeight: value ? 600 : 400 }}
      onFocus={e => e.target.style.borderBottomColor = 'var(--primary)'}
      onBlur={e => e.target.style.borderBottomColor = 'var(--text-muted)'} />
  </div>
);

const SignatureStampField = ({ value, onChange }) => (
  <div>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.75rem' }}>Admin Signature &amp; Official Stamp</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: '2rem' }}>
      <div style={{ flex: 1 }}>
        <div style={{ position: 'relative', background: value ? 'rgba(12,99,126,0.03)' : 'var(--surface-alt)', borderRadius: '8px 8px 0 0', border: '1px solid var(--border)', borderBottom: `2px solid ${value ? 'var(--primary)' : 'var(--border)'}`, transition: 'border-color 0.25s', padding: '0.75rem 1rem 0.6rem' }}>
          <input type="text" value={value} onChange={onChange} placeholder="Click here and sign your name…"
            style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: value ? '"Great Vibes", cursive' : 'inherit', fontSize: value ? '2rem' : '0.9rem', color: value ? 'var(--primary-dark)' : 'var(--text-muted)', lineHeight: 1.3, transition: 'font-size 0.2s, font-family 0.1s', boxSizing: 'border-box' }}
            onFocus={e => e.currentTarget.parentElement.style.borderBottomColor = 'var(--primary)'}
            onBlur={e => e.currentTarget.parentElement.style.borderBottomColor = value ? 'var(--primary)' : 'var(--border)'} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '0.3rem' }}>
          <span style={{ fontSize: '0.62rem', color: 'var(--text-muted)', letterSpacing: '0.06em' }}>AUTHORIZED SIGNATURE</span>
          {value && <span style={{ fontSize: '0.62rem', color: 'var(--primary)', fontWeight: 600, letterSpacing: '0.04em' }}>✓ SIGNED</span>}
        </div>
      </div>
      <div style={{ flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.4rem' }}>
        <div style={{ width: '110px', height: '110px', border: '3px solid var(--primary)', borderRadius: '50%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative', opacity: value ? 1 : 0.3, transition: 'opacity 0.4s', background: value ? 'rgba(12,99,126,0.04)' : 'transparent' }}>
          <div style={{ position: 'absolute', inset: '5px', border: '1.5px dashed var(--primary)', borderRadius: '50%' }} />
          <div style={{ textAlign: 'center', zIndex: 1, padding: '0 8px' }}>
            <div style={{ fontSize: '0.52rem', fontWeight: 800, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.12em', lineHeight: 1.4, marginBottom: '3px' }}>MediFind</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 900, color: 'var(--primary)', fontFamily: 'Arial, sans-serif', lineHeight: 1 }}>✦</div>
            <div style={{ fontSize: '0.42rem', fontWeight: 800, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.1em', lineHeight: 1.5, marginTop: '3px' }}>Emergency Response<br />Network · Pakistan</div>
          </div>
          <svg style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }} viewBox="0 0 110 110">
            <path id="topArc" d="M 10,55 A 45,45 0 0 1 100,55" fill="none" />
            <text fontSize="7" fontWeight="800" fill="var(--primary)" fontFamily="Arial, sans-serif" letterSpacing="2">
              <textPath href="#topArc" startOffset="8%">OFFICIAL · VERIFIED · AUTHORIZED</textPath>
            </text>
          </svg>
        </div>
        <div style={{ fontSize: '0.6rem', color: value ? 'var(--primary)' : 'var(--border)', fontWeight: 700, letterSpacing: '0.08em', transition: 'color 0.4s' }}>OFFICIAL STAMP</div>
      </div>
    </div>
  </div>
);

const SpecializationRow = ({ specs }) => (
  <div style={{ background: 'var(--surface-alt)', borderRadius: '8px', padding: '0.6rem 0.875rem', border: '1px solid var(--primary-pale)', marginBottom: '0.5rem' }}>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.5rem' }}>Specializations ({specs.length})</div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem' }}>
      {specs.map(spec => (
        <span key={spec} style={{ padding: '0.25rem 0.75rem', borderRadius: '999px', background: 'var(--primary-pale)', color: 'var(--primary)', fontSize: '0.78rem', fontWeight: 700, border: '1px solid var(--border)' }}>{spec}</span>
      ))}
    </div>
  </div>
);

// ─── Main Page Component ──────────────────────────────────────────────────────

const ResponderVerification = () => {
  const [pending,           setPending]           = useState([]);
  const [loading,           setLoading]           = useState(true);
  const [selectedResponder, setSelectedResponder] = useState(null); // opens detail modal
  const [processingId,      setProcessingId]      = useState(null);
  const [toast,             setToast]             = useState(null);
  const [error,             setError]             = useState('');
  const [showApplication,   setShowApplication]   = useState(false); // formal A4 form
  const [showRejectModal,   setShowRejectModal]   = useState(false);

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  };

  const loadPending = () => api.get('/api/admin/responders/pending')
    .then(response => { if (response.data.success) setPending(response.data.data); setError(''); })
    .catch(err => setError(err.response?.data?.message || 'Failed to load pending responders.'))
    .finally(() => setLoading(false));

  const fetchPending = () => { setLoading(true); setError(''); return loadPending(); };

  useEffect(() => { loadPending(); }, []);

  const handleAction = async (id, action, reason = '') => {
    setProcessingId(id);
    try {
      const response = await api.post(`/api/admin/responders/${id}/verify`, { action, reason });
      if (response.data.success) {
        setPending(prev => prev.filter(r => r.userId !== id));
        setSelectedResponder(null);
        setShowRejectModal(false);
        showToast(
          action === 'VERIFY'
            ? 'Responder approved — verification email sent.'
            : 'Application rejected — applicant has been notified.',
          action === 'VERIFY' ? 'success' : 'error',
        );
      }
    } catch {
      showToast('Failed to process verification.', 'error');
    } finally {
      setProcessingId(null);
    }
  };

  return (
    <>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -20 }}
        transition={{ duration: 0.5 }}
      >
        {/* ── Toast ── */}
        <AnimatePresence>
          {toast && (
            <motion.div key="toast" initial={{ opacity: 0, y: -16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
              style={{ position: 'fixed', top: '5.5rem', right: '2rem', zIndex: 9999, padding: '0.875rem 1.375rem', borderRadius: '14px', fontWeight: 700, fontSize: '0.9rem', background: toast.type === 'error' ? 'var(--error-bg)' : 'var(--success-bg)', color: toast.type === 'error' ? 'var(--error-fg)' : 'var(--success-fg)', border: `1px solid ${toast.type === 'error' ? 'var(--error-border)' : 'var(--success-border)'}`, boxShadow: 'var(--shadow-md)' }}>
              {toast.msg}
            </motion.div>
          )}
        </AnimatePresence>

        {/* ── Page Header ── */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2rem' }}>
          <div>
            <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-sub)', letterSpacing: '-0.03em', marginBottom: '0.375rem' }}>
              Verification Queue
            </h1>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
              {loading ? 'Loading…' : `${pending.length} application${pending.length !== 1 ? 's' : ''} awaiting review.`}
            </p>
          </div>
          <motion.button whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }} onClick={fetchPending}
            style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', padding: '0.7rem 1.375rem', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--surface)', color: 'var(--text-sub)', fontWeight: 700, cursor: 'pointer', fontSize: '0.875rem', fontFamily: 'var(--font-sans)' }}>
            <RefreshCw size={15} /> Refresh
          </motion.button>
        </div>

        {/* ── Error Banner ── */}
        {error && (
          <div style={{ padding: '0.875rem 1.375rem', background: 'var(--error-bg)', border: '1px solid var(--error-border)', borderRadius: '12px', color: 'var(--error-fg)', marginBottom: '1.75rem', fontWeight: 600, fontSize: '0.9rem' }}>
            {error}
          </div>
        )}

        {/* ── Full-width card grid ── */}
        {loading ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '1rem' }}>
            {Array(4).fill(null).map((_, i) => (
              <div key={i} className="card" style={{ padding: '1.5rem', height: '140px', background: 'var(--surface-raised)', borderRadius: 'var(--radius-md)', border: '1px solid var(--border)', animation: 'pulse 1.5s ease-in-out infinite' }} />
            ))}
          </div>
        ) : pending.length === 0 ? (
          <div className="card" style={{ padding: '5rem 2rem', textAlign: 'center', border: '1px solid var(--border)', borderRadius: 'var(--radius-md)', background: 'var(--surface)' }}>
            <UserCheck size={56} style={{ margin: '0 auto 1.5rem', color: 'var(--primary)', opacity: 0.15, display: 'block' }} />
            <h3 style={{ fontSize: '1.375rem', color: 'var(--text-sub)', marginBottom: '0.75rem' }}>All Clear</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '1rem' }}>No pending applications at this time.</p>
          </div>
        ) : (
          <AnimatePresence>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '1rem' }}>
              {pending.map((r, idx) => (
                <motion.div
                  key={r.id}
                  initial={{ opacity: 0, y: 16 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: idx * 0.05 }}
                  className="card"
                  onClick={() => setSelectedResponder(r)}
                  style={{
                    padding: '1.5rem', cursor: 'pointer',
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--radius-md)',
                    background: 'var(--surface)',
                    transition: 'box-shadow 0.2s ease, transform 0.15s ease',
                  }}
                  whileHover={{ y: -3, boxShadow: '0 8px 32px rgba(12,99,126,0.12)' }}
                  whileTap={{ scale: 0.98 }}
                >
                  {/* Card header */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '1rem' }}>
                    <div style={{ width: '48px', height: '48px', borderRadius: '14px', background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '1.125rem', flexShrink: 0 }}>
                      {r.user?.fullName?.charAt(0) || '?'}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-sub)', marginBottom: '0.15rem' }}>
                        {r.user?.fullName}
                      </div>
                      <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {r.user?.email}
                      </div>
                    </div>
                    {/* Wait badge */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', fontSize: '0.7rem', fontWeight: 700, color: waitColor(r.user?.createdAt), flexShrink: 0 }}>
                      <Clock size={11} /> {timeAgo(r.user?.createdAt)}
                    </div>
                  </div>

                  {/* Type + org */}
                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginBottom: '1rem' }}>
                    <span style={{ background: 'var(--primary-pale)', color: 'var(--primary)', padding: '0.25rem 0.7rem', borderRadius: '6px', fontSize: '0.75rem', fontWeight: 700 }}>
                      {RESPONDER_TYPE_LABELS[r.responderType]?.split('(')[0].trim() || r.responderType}
                    </span>
                    {r.organization && (
                      <span style={{ background: 'var(--surface-raised)', color: 'var(--text-muted)', padding: '0.25rem 0.7rem', borderRadius: '6px', fontSize: '0.75rem', fontWeight: 600, border: '1px solid var(--border)' }}>
                        {r.organization}
                      </span>
                    )}
                  </div>

                  {/* CTA */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: '0.875rem', borderTop: '1px solid var(--border)' }}>
                    <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                      License: {r.licenseNumber || '—'}
                    </span>
                    <span style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--primary)' }}>
                      Review →
                    </span>
                  </div>
                </motion.div>
              ))}
            </div>
          </AnimatePresence>
        )}
      </motion.div>

      {/* ── Detail Modal — opens when a card is clicked ── */}
      <AnimatePresence>
        {selectedResponder && !showApplication && (
          <ResponderDetailModal
            key="detail-modal"
            responder={selectedResponder}
            processingId={processingId}
            onApprove={() => handleAction(selectedResponder.userId, 'VERIFY')}
            onReject={() => setShowRejectModal(true)}
            onViewApplication={() => setShowApplication(true)}
            onClose={() => { setSelectedResponder(null); setShowRejectModal(false); }}
          />
        )}
      </AnimatePresence>

      {/* ── Formal A4 Application Modal ── */}
      <AnimatePresence>
        {showApplication && selectedResponder && (
          <ApplicationModal
            responder={selectedResponder}
            onClose={() => setShowApplication(false)}
          />
        )}
      </AnimatePresence>

      {/* ── Rejection Reason Modal ── */}
      <AnimatePresence>
        {showRejectModal && selectedResponder && (
          <RejectModal
            responderName={selectedResponder.user?.fullName}
            processing={!!processingId}
            onCancel={() => setShowRejectModal(false)}
            onConfirm={(reason) => handleAction(selectedResponder.userId, 'REJECT', reason)}
          />
        )}
      </AnimatePresence>
    </>
  );
};

export default ResponderVerification;

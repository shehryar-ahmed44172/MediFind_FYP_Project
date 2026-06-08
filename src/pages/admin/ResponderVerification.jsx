import React, { useState, useEffect, useRef } from 'react';
import { UserCheck, Shield, ExternalLink, Check, X, FileText, RefreshCw, ChevronRight, Clock, Printer, AlertTriangle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import { resolveFileUrl } from '../../utils/resolveFileUrl';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Returns a human-readable "X days / X hours ago" string */
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

/** Colour the wait-time text: red ≥2 days, amber ≥1 day, muted otherwise */
function waitColor(dateStr) {
  if (!dateStr) return 'var(--text-muted)';
  const days = (Date.now() - new Date(dateStr).getTime()) / 86400000;
  if (days >= 2) return '#dc2626';
  if (days >= 1) return '#d97706';
  return 'var(--text-muted)';
}

const RESPONDER_TYPE_LABELS = {
  RESCUE_OFFICER:  'Rescue Officer (e.g. 1122)',
  PARAMEDIC:       'Paramedic',
  EMT:             'Emergency Medical Technician (EMT)',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER:       'Community Volunteer',
};

// ─── Formal Application Modal ─────────────────────────────────────────────────

const ApplicationModal = ({ responder, onClose }) => {
  const submittedDate = responder.user?.createdAt
    ? new Date(responder.user.createdAt).toLocaleDateString('en-PK', { year: 'numeric', month: 'long', day: 'numeric' })
    : 'N/A';

  // Admin review state (on-screen editable, also captured in print)
  const [reviewedBy,   setReviewedBy]   = React.useState('');
  const [reviewDate,   setReviewDate]   = React.useState(new Date().toLocaleDateString('en-PK'));
  const [rejectReason, setRejectReason] = React.useState('');
  const [adminSig,     setAdminSig]     = React.useState('');

  // ── Print in new window (avoids React root / portal print issues) ─────────
  const handlePrint = () => {
    const printArea = document.getElementById('application-print-area');
    if (!printArea) return;

    // Clone so we can patch values without touching live DOM
    const clone = printArea.cloneNode(true);

    // innerHTML doesn't capture the current .value of inputs/textareas.
    // Sync each element's live value into the cloned node's value attribute.
    const origEls  = printArea.querySelectorAll('input, textarea, select');
    const cloneEls = clone.querySelectorAll('input, textarea, select');
    origEls.forEach((orig, i) => {
      if (!cloneEls[i]) return;
      if (orig.type === 'radio' || orig.type === 'checkbox') {
        if (orig.checked) cloneEls[i].setAttribute('checked', 'checked');
        else cloneEls[i].removeAttribute('checked');
      } else {
        cloneEls[i].setAttribute('value', orig.value);
        cloneEls[i].textContent = orig.value; // for textarea
      }
    });

    const win = window.open('', '_blank', 'width=900,height=700');
    win.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8" />
          <title>MediFind — Emergency Responder Application</title>
          <link rel="preconnect" href="https://fonts.googleapis.com" />
          <link href="https://fonts.googleapis.com/css2?family=Great+Vibes&display=swap" rel="stylesheet" />
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: Arial, sans-serif; color: #111; background: white; }
            @media print {
              @page { margin: 15mm; size: A4; }
              body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
              /* Section 5 always starts on its own fresh page */
              .print-page-break {
                page-break-before: always !important;
                break-before: page !important;
              }
            }
            .header-banner { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            input, textarea {
              border: none; border-bottom: 1.5px solid #9CA3AF;
              width: 100%; padding: 4px 0; font-size: 0.875rem;
              font-family: Arial, sans-serif; background: transparent; outline: none;
            }
          </style>
        </head>
        <body>${clone.innerHTML}</body>
      </html>
    `);
    win.document.close();
    win.focus();
    // Give fonts time to load before triggering print
    setTimeout(() => { win.print(); win.close(); }, 900);
  };

  const docs = [
    { label: 'CNIC — Front',                        url: resolveFileUrl(responder.cnicImageUrl),              required: true  },
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
      overflowY: 'auto', padding: '2rem 1rem',
    }}>

      {/* Toolbar (hidden when printing) */}
      <div className="no-print" style={{
        position: 'sticky', top: 0, zIndex: 1,
        display: 'flex', justifyContent: 'flex-end', gap: '0.75rem',
        width: '100%', maxWidth: '820px', marginBottom: '0.75rem',
      }}>
        <button
          onClick={handlePrint}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.5rem',
            padding: '0.6rem 1.25rem', borderRadius: '10px',
            background: '#0C637E', color: 'white', border: 'none',
            fontWeight: 700, fontSize: '0.875rem', cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          <Printer size={15} /> Print / Save as PDF
        </button>
        <button
          onClick={onClose}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.5rem',
            padding: '0.6rem 1.25rem', borderRadius: '10px',
            background: 'white', color: '#374151', border: '1px solid #d1d5db',
            fontWeight: 700, fontSize: '0.875rem', cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          <X size={15} /> Close
        </button>
      </div>

      {/* ── The Printable Form ── */}
      <div
        id="application-print-area"
        style={{
          width: '100%', maxWidth: '820px',
          background: 'white', borderRadius: '16px',
          boxShadow: '0 24px 64px rgba(0,0,0,0.3)',
          overflow: 'hidden', fontFamily: 'Arial, sans-serif',
        }}
      >
        {/* Header banner */}
        <div style={{
          background: 'linear-gradient(135deg, #03293C 0%, #0C637E 100%)',
          padding: '2rem 2.5rem', color: 'white',
        }}>
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
              <div style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                {responder.id?.slice(0, 8).toUpperCase() || 'N/A'}
              </div>
              <div style={{ marginTop: '0.5rem', fontWeight: 700 }}>Date Submitted</div>
              <div>{submittedDate}</div>
            </div>
          </div>
        </div>

        <div style={{ padding: '2rem 2.5rem' }}>

          {/* ── 1. Personal Information ── */}
          <AppSectionTitle num="1" title="Personal Information" />
          <AppFieldGrid fields={[
            { label: 'Full Name',      value: responder.user?.fullName    || '—' },
            { label: 'Email Address',  value: responder.user?.email       || '—' },
            { label: 'Phone Number',   value: responder.user?.phoneNumber || '—' },
            { label: 'City',           value: responder.user?.city        || '—' },
            { label: 'CNIC Number',    value: responder.cnic              || '—' },
            {
              label: 'Date of Birth',
              value: (() => {
                if (!responder.user?.dateOfBirth) return '—';
                const dob = new Date(responder.user.dateOfBirth);
                const age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 3600 * 1000));
                const dobStr = dob.toLocaleDateString('en-PK', { year: 'numeric', month: 'long', day: 'numeric' });
                return `${dobStr}  (Age: ${age})`;
              })(),
            },
          ]} />

          {/* ── 2. Professional Credentials ── */}
          <AppSectionTitle num="2" title="Professional Credentials" />
          <AppFieldGrid fields={[
            { label: 'Responder Type',          value: RESPONDER_TYPE_LABELS[responder.responderType] || responder.responderType || '—' },
            { label: 'License Number',          value: responder.licenseNumber    || '—' },
            { label: 'Organization',            value: responder.organization     || 'Independent / Not Affiliated' },
            { label: 'Vehicle Type',            value: responder.vehicleType === 'MOTORBIKE_AMBULANCE' ? 'Motorbike Ambulance' : (responder.vehicleType || 'Not Provided') },
            { label: 'Motorbike Reg. Number',   value: responder.motorbikeNumber  || 'Not Provided' },
          ]} />
          {/* Specializations — full-width with chips */}
          <SpecializationRow specs={
            Array.isArray(responder.specialization) && responder.specialization.length
              ? responder.specialization
              : ['General Emergency']
          } />

          {/* ── 3. Identity Documents ── */}
          <AppSectionTitle num="3" title="Identity &amp; Credential Documents" />
          <p style={{ fontSize: '0.83rem', color: '#6B7280', margin: '-0.25rem 0 1.25rem', lineHeight: 1.6 }}>
            The following documents were uploaded by the applicant during registration.
            Please verify each document carefully before making a decision.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1.25rem', marginBottom: '2rem' }}>
            {docs.map(({ label, url, required }) => (
              <div key={label} style={{
                border: `1.5px solid ${url ? '#D8ECF2' : '#e5e7eb'}`,
                borderRadius: '12px', overflow: 'hidden',
                background: url ? '#F7FAFB' : '#f9fafb',
              }}>
                {/* Doc header row */}
                <div style={{
                  padding: '0.55rem 0.875rem',
                  borderBottom: `1px solid ${url ? '#D8ECF2' : '#e5e7eb'}`,
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  background: url ? '#EEF5F8' : '#f3f4f6',
                }}>
                  <span style={{ fontWeight: 700, fontSize: '0.78rem', color: '#374151' }}>{label}</span>
                  <span style={{
                    fontSize: '0.63rem', fontWeight: 700, padding: '0.15rem 0.5rem',
                    borderRadius: '999px',
                    background: url ? '#D1FAE5' : '#FEE2E2',
                    color:      url ? '#065F46' : '#991B1B',
                  }}>
                    {url ? 'UPLOADED' : required ? 'MISSING ⚠' : 'NOT PROVIDED'}
                  </span>
                </div>
                {/* Doc image or placeholder */}
                {url ? (
                  <div style={{ position: 'relative' }}>
                    <img
                      src={url} alt={label}
                      style={{ width: '100%', height: '160px', objectFit: 'cover', display: 'block' }}
                      onError={(e) => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }}
                    />
                    <div style={{
                      display: 'none', height: '160px', alignItems: 'center', justifyContent: 'center',
                      flexDirection: 'column', gap: '8px',
                      background: '#f1f5f9', color: '#9CA3AF', fontSize: '0.78rem',
                    }}>
                      <FileText size={24} style={{ opacity: 0.4 }} />
                      <span>Cannot display — may be PDF</span>
                    </div>
                    <button
                      className="no-print"
                      onClick={() => window.open(url, '_blank')}
                      style={{
                        position: 'absolute', bottom: '8px', right: '8px',
                        background: 'rgba(0,0,0,0.6)', color: 'white',
                        border: 'none', borderRadius: '7px',
                        padding: '4px 10px', fontSize: '0.7rem', fontWeight: 700,
                        cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px',
                      }}
                    >
                      <ExternalLink size={11} /> Open Full
                    </button>
                  </div>
                ) : (
                  <div style={{
                    height: '160px', display: 'flex', flexDirection: 'column',
                    alignItems: 'center', justifyContent: 'center', gap: '8px',
                    color: '#9CA3AF', fontSize: '0.82rem',
                  }}>
                    <Shield size={28} style={{ opacity: 0.25 }} />
                    <span style={{ fontWeight: 600 }}>
                      {required ? 'Required — Not Submitted' : 'Optional — Not Provided'}
                    </span>
                  </div>
                )}
              </div>
            ))}
          </div>

          {/* ── 4. Applicant Declaration ── */}
          <AppSectionTitle num="4" title="Applicant Declaration" />
          <div style={{
            background: '#FFFBEB', border: '1px solid #FDE68A',
            borderRadius: '10px', padding: '1.25rem 1.5rem', marginBottom: '2rem',
          }}>
            <p style={{ fontSize: '0.875rem', color: '#374151', lineHeight: 1.8, margin: 0 }}>
              By submitting this application, <strong>{responder.user?.fullName || '[Applicant]'}</strong> hereby declares and confirms:
            </p>
            <ol style={{ margin: '1rem 0 0', paddingLeft: '1.4rem', fontSize: '0.875rem', color: '#374151', lineHeight: 2.1 }}>
              <li>All information provided in this application is accurate, complete, and truthful to the best of my knowledge.</li>
              <li>I hold valid professional certification as a <strong>{RESPONDER_TYPE_LABELS[responder.responderType] || 'Emergency Responder'}</strong> and the license number provided (<strong>{responder.licenseNumber || 'N/A'}</strong>) is genuine and currently active.</li>
              <li>I understand that I am applying to join the MediFind Emergency Response Network and will be responsible for responding to real medical emergencies — including situations involving patients who are deaf, mute, or speech-impaired.</li>
              <li>I acknowledge that providing false information or fraudulent documents is grounds for immediate rejection and may result in legal action under the laws of Pakistan.</li>
              <li>I consent to the MediFind administrative team verifying my credentials with the relevant healthcare and government authorities.</li>
              <li>I understand my application will be reviewed within 2–3 business days and I will be notified of the outcome via the email address I provided.</li>
            </ol>
          </div>

          {/* ── 5. Admin Review Section — page-break forces it onto its own page ── */}
          <div className="print-page-break" style={{ paddingTop: '0.5rem' }}>
          <AppSectionTitle num="5" title="Administrative Review — For Official Use Only" />
          <div style={{
            border: '1.5px dashed #D1D5DB', borderRadius: '10px',
            padding: '1.25rem 1.5rem', marginBottom: '1.5rem', background: '#FAFAFA',
          }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.25rem', marginBottom: '1.25rem' }}>
              <ReviewField label="Reviewed by (Admin Name)" value={reviewedBy}
                onChange={e => setReviewedBy(e.target.value)} placeholder="Enter admin name" />
              <ReviewField label="Review Date" value={reviewDate}
                onChange={e => setReviewDate(e.target.value)} placeholder="DD/MM/YYYY" />
            </div>
            <div style={{ marginBottom: '1.25rem' }}>
              {/* Decision note — actual action is via Approve/Reject buttons in main panel */}
              <div style={{
                display: 'flex', alignItems: 'flex-start', gap: '0.6rem',
                background: '#EFF6FF', border: '1px solid #BFDBFE',
                borderRadius: '8px', padding: '0.75rem 1rem',
              }}>
                <span style={{ fontSize: '1rem', flexShrink: 0 }}>ℹ️</span>
                <div>
                  <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#1D4ED8', marginBottom: '0.2rem' }}>
                    Decision Recorded Digitally
                  </div>
                  <div style={{ fontSize: '0.78rem', color: '#3B82F6', lineHeight: 1.5 }}>
                    The approval or rejection is executed via the <strong>Approve Responder</strong> / <strong>Reject</strong> buttons in the Verification Queue. The outcome is automatically logged in the system audit trail.
                  </div>
                </div>
              </div>
            </div>
            <div style={{ marginBottom: '1.25rem' }}>
              <ReviewField label="Notes / Rejection Reason (if applicable)" value={rejectReason}
                onChange={e => setRejectReason(e.target.value)} placeholder="Add review notes or state reason if rejected" />
            </div>
            <SignatureStampField value={adminSig} onChange={e => setAdminSig(e.target.value)} />
          </div>
          </div>{/* end print-page-break wrapper */}

          {/* Footer */}
          <div style={{
            marginTop: '1.5rem', paddingTop: '1rem',
            borderTop: '1px solid #E5E7EB',
            display: 'flex', justifyContent: 'space-between',
            fontSize: '0.7rem', color: '#9CA3AF',
          }}>
            <span>MediFind Healthcare Emergency Network · Pakistan · Confidential</span>
            <span>Application Ref: {responder.id?.slice(0, 16).toUpperCase() || 'N/A'}</span>
          </div>
        </div>
      </div>

    </div>
  );
};

// ─── Small shared sub-components ─────────────────────────────────────────────

const AppSectionTitle = ({ num, title }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem', marginTop: '1.75rem' }}>
    <div style={{
      width: '28px', height: '28px', borderRadius: '8px',
      background: '#0C637E', color: 'white',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 800, fontSize: '0.875rem', flexShrink: 0,
    }}>{num}</div>
    <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 800, color: '#0C637E' }}
      dangerouslySetInnerHTML={{ __html: title }} />
    <div style={{ flex: 1, height: '1px', background: '#D8ECF2' }} />
  </div>
);

const AppFieldGrid = ({ fields }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.875rem', marginBottom: '0.5rem' }}>
    {fields.map(({ label, value }) => (
      <div key={label} style={{
        background: '#F7FAFB', borderRadius: '8px',
        padding: '0.6rem 0.875rem', border: '1px solid #E0EEF3',
      }}>
        <div style={{ fontSize: '0.68rem', fontWeight: 700, color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.2rem' }}>
          {label}
        </div>
        <div style={{ fontSize: '0.9rem', fontWeight: 600, color: '#1A2E3A' }}>{value}</div>
      </div>
    ))}
  </div>
);

const SignatureLine = ({ label }) => (
  <div>
    <div style={{ fontSize: '0.7rem', color: '#6B7280', marginBottom: '0.375rem', fontWeight: 600 }}
      dangerouslySetInnerHTML={{ __html: label }} />
    <div style={{ borderBottom: '1.5px solid #9CA3AF', height: '28px' }} />
  </div>
);

/** Typeable review field — shows as a labelled input on-screen, prints as filled line */
const ReviewField = ({ label, value, onChange, placeholder }) => (
  <div>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.4rem' }}
      dangerouslySetInnerHTML={{ __html: label }} />
    <input
      type="text"
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      style={{
        width: '100%', padding: '0.5rem 0.6rem',
        border: 'none', borderBottom: '1.5px solid #9CA3AF',
        fontSize: '0.875rem', fontFamily: 'Arial, sans-serif',
        color: '#1A2E3A', background: 'transparent', outline: 'none',
        fontWeight: value ? 600 : 400,
      }}
      onFocus={e => e.target.style.borderBottomColor = '#0C637E'}
      onBlur={e => e.target.style.borderBottomColor = '#9CA3AF'}
    />
  </div>
);

/**
 * Admin Signature + Stamp field
 * • Single cursive input — the input IS the signature (no duplicate preview)
 * • Circular MediFind official stamp shown beside it
 */
const SignatureStampField = ({ value, onChange }) => (
  <div>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.75rem' }}>
      Admin Signature &amp; Official Stamp
    </div>

    <div style={{ display: 'flex', alignItems: 'center', gap: '2rem' }}>

      {/* Left: single cursive input field — types directly in handwriting style */}
      <div style={{ flex: 1 }}>
        <div style={{
          position: 'relative',
          background: value ? 'rgba(12,99,126,0.03)' : '#FAFAFA',
          borderRadius: '8px 8px 0 0',
          border: '1px solid #E5E7EB',
          borderBottom: `2px solid ${value ? '#0C637E' : '#D1D5DB'}`,
          transition: 'border-color 0.25s',
          padding: '0.75rem 1rem 0.6rem',
        }}>
          <input
            type="text"
            value={value}
            onChange={onChange}
            placeholder="Click here and sign your name…"
            style={{
              width: '100%',
              border: 'none', outline: 'none', background: 'transparent',
              fontFamily: value ? '"Great Vibes", cursive' : 'inherit',
              fontSize: value ? '2rem' : '0.9rem',
              color: value ? '#03293C' : '#9CA3AF',
              lineHeight: 1.3,
              transition: 'font-size 0.2s, font-family 0.1s',
              boxSizing: 'border-box',
            }}
            onFocus={e => e.currentTarget.parentElement.style.borderBottomColor = '#0C637E'}
            onBlur={e => e.currentTarget.parentElement.style.borderBottomColor = value ? '#0C637E' : '#D1D5DB'}
          />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '0.3rem' }}>
          <span style={{ fontSize: '0.62rem', color: '#9CA3AF', letterSpacing: '0.06em' }}>
            AUTHORIZED SIGNATURE
          </span>
          {value && (
            <span style={{ fontSize: '0.62rem', color: '#0C637E', fontWeight: 600, letterSpacing: '0.04em' }}>
              ✓ SIGNED
            </span>
          )}
        </div>
      </div>

      {/* Right: Official circular stamp */}
      <div style={{ flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '0.4rem' }}>
        <div style={{
          width: '110px', height: '110px',
          border: '3px solid #0C637E',
          borderRadius: '50%',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          position: 'relative',
          opacity: value ? 1 : 0.3,
          transition: 'opacity 0.4s',
          background: value ? 'rgba(12,99,126,0.04)' : 'transparent',
        }}>
          {/* Outer dashed ring */}
          <div style={{
            position: 'absolute', inset: '5px',
            border: '1.5px dashed #0C637E',
            borderRadius: '50%',
          }} />
          {/* Inner content */}
          <div style={{ textAlign: 'center', zIndex: 1, padding: '0 8px' }}>
            <div style={{
              fontSize: '0.52rem', fontWeight: 800, color: '#0C637E',
              textTransform: 'uppercase', letterSpacing: '0.12em',
              lineHeight: 1.4, marginBottom: '3px',
            }}>
              MediFind
            </div>
            {/* MediFind logo M mark */}
            <div style={{
              fontSize: '1.1rem', fontWeight: 900, color: '#0C637E',
              fontFamily: 'Arial, sans-serif', lineHeight: 1,
            }}>✦</div>
            <div style={{
              fontSize: '0.42rem', fontWeight: 800, color: '#0C637E',
              textTransform: 'uppercase', letterSpacing: '0.1em',
              lineHeight: 1.5, marginTop: '3px',
            }}>
              Emergency Response<br />Network · Pakistan
            </div>
          </div>

          {/* Circular text around stamp (top arc) */}
          <svg style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }} viewBox="0 0 110 110">
            <path id="topArc" d="M 10,55 A 45,45 0 0 1 100,55" fill="none" />
            <text fontSize="7" fontWeight="800" fill="#0C637E" fontFamily="Arial, sans-serif" letterSpacing="2">
              <textPath href="#topArc" startOffset="8%">OFFICIAL · VERIFIED · AUTHORIZED</textPath>
            </text>
          </svg>
        </div>
        <div style={{ fontSize: '0.6rem', color: value ? '#0C637E' : '#CBD5E1', fontWeight: 700, letterSpacing: '0.08em', transition: 'color 0.4s' }}>
          OFFICIAL STAMP
        </div>
      </div>

    </div>
  </div>
);

/** Full-width specializations row with individual chips */
const SpecializationRow = ({ specs }) => (
  <div style={{
    background: '#F7FAFB', borderRadius: '8px',
    padding: '0.6rem 0.875rem', border: '1px solid #E0EEF3',
    marginBottom: '0.5rem',
  }}>
    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.5rem' }}>
      Specializations ({specs.length})
    </div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem' }}>
      {specs.map(spec => (
        <span key={spec} style={{
          padding: '0.25rem 0.75rem', borderRadius: '999px',
          background: '#E2F0F3', color: '#0C637E',
          fontSize: '0.78rem', fontWeight: 700,
          border: '1px solid #C8E4EC',
        }}>
          {spec}
        </span>
      ))}
    </div>
  </div>
);

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
    <div style={{
      position: 'fixed', inset: 0, zIndex: 10001,
      background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(3px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem',
    }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.94 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.94 }}
        style={{
          background: 'white', borderRadius: '18px', padding: '2rem',
          width: '100%', maxWidth: '500px',
          boxShadow: '0 20px 60px rgba(0,0,0,0.25)',
        }}
      >
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', marginBottom: '1.25rem' }}>
          <div style={{
            width: '42px', height: '42px', borderRadius: '12px',
            background: '#FEE2E2', display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <AlertTriangle size={20} color="#DC2626" />
          </div>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800, color: '#111827' }}>
              Reject Application
            </h3>
            <p style={{ margin: 0, fontSize: '0.82rem', color: '#6B7280' }}>{responderName}</p>
          </div>
        </div>

        <p style={{ fontSize: '0.875rem', color: '#374151', marginBottom: '1rem', lineHeight: 1.6 }}>
          Provide a reason for rejection. This message will be sent to the applicant so they know what to correct and can resubmit.
        </p>

        {/* Quick-select preset reasons */}
        <p style={{ fontSize: '0.7rem', fontWeight: 700, color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '0.5rem' }}>
          Quick select
        </p>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.875rem' }}>
          {presets.map(p => (
            <button
              key={p}
              onClick={() => setReason(p)}
              style={{
                padding: '0.3rem 0.7rem', borderRadius: '999px',
                border: `1px solid ${reason === p ? '#0C637E' : '#D1D5DB'}`,
                background: reason === p ? '#EEF5F8' : 'white',
                color: reason === p ? '#0C637E' : '#374151',
                fontSize: '0.75rem', fontWeight: 600,
                cursor: 'pointer', fontFamily: 'inherit', transition: 'all 0.15s',
              }}
            >
              {p}
            </button>
          ))}
        </div>

        {/* Custom reason */}
        <textarea
          value={reason}
          onChange={e => setReason(e.target.value)}
          placeholder="Or type a custom reason here…"
          rows={3}
          style={{
            width: '100%', borderRadius: '10px',
            border: '1.5px solid #D1D5DB',
            padding: '0.75rem 0.875rem',
            fontSize: '0.875rem', fontFamily: 'inherit',
            resize: 'vertical', outline: 'none',
            color: '#374151', lineHeight: 1.6,
            boxSizing: 'border-box',
          }}
        />

        {/* Buttons */}
        <div style={{ display: 'flex', gap: '0.875rem', marginTop: '1.25rem' }}>
          <button
            onClick={onCancel}
            disabled={processing}
            style={{
              flex: 1, padding: '0.8rem', borderRadius: '12px',
              border: '1px solid #D1D5DB', background: 'white',
              color: '#374151', fontWeight: 700, fontSize: '0.9rem',
              cursor: 'pointer', fontFamily: 'inherit',
            }}
          >
            Cancel
          </button>
          <button
            onClick={() => reason.trim() && onConfirm(reason.trim())}
            disabled={!reason.trim() || processing}
            style={{
              flex: 2, padding: '0.8rem', borderRadius: '12px', border: 'none',
              background: !reason.trim() || processing ? '#F3F4F6' : '#DC2626',
              color: !reason.trim() || processing ? '#9CA3AF' : 'white',
              fontWeight: 700, fontSize: '0.9rem',
              cursor: !reason.trim() || processing ? 'not-allowed' : 'pointer',
              fontFamily: 'inherit', transition: 'all 0.18s',
            }}
          >
            {processing ? 'Rejecting…' : 'Confirm Rejection'}
          </button>
        </div>
      </motion.div>
    </div>
  );
};

// ─── Main Page Component ──────────────────────────────────────────────────────

const ResponderVerification = () => {
  const [pending,           setPending]           = useState([]);
  const [loading,           setLoading]           = useState(true);
  const [selectedResponder, setSelectedResponder] = useState(null);
  const [processingId,      setProcessingId]      = useState(null);
  const [toast,             setToast]             = useState(null);
  const [error,             setError]             = useState('');
  const [showApplication,   setShowApplication]   = useState(false);
  const [showRejectModal,   setShowRejectModal]   = useState(false);

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchPending = async () => {
    setLoading(true); setError('');
    try {
      const response = await api.get('/api/admin/responders/pending');
      if (response.data.success) setPending(response.data.data);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load pending responders.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchPending(); }, []);

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

  // Lightbox state for full-screen document preview
  const [lightbox, setLightbox] = useState(null); // { url, label }

  /** Inline document card with thumbnail preview */
  const DocCard = ({ label, url, required }) => (
    <div style={{
      borderRadius: '12px', overflow: 'hidden',
      border: `1.5px solid ${url ? '#D8ECF2' : 'var(--border)'}`,
      background: url ? 'var(--surface)' : 'var(--surface-raised)',
    }}>
      {/* Header row */}
      <div style={{
        padding: '0.5rem 0.875rem',
        background: url ? '#EEF5F8' : 'var(--surface-raised)',
        borderBottom: `1px solid ${url ? '#D8ECF2' : 'var(--border)'}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-sub)' }}>{label}</span>
        <span style={{
          fontSize: '0.6rem', fontWeight: 700, padding: '0.15rem 0.5rem',
          borderRadius: '999px',
          background: url ? '#D1FAE5' : '#FEE2E2',
          color: url ? '#065F46' : '#991B1B',
        }}>
          {url ? 'UPLOADED' : required ? 'MISSING ⚠' : 'N/A'}
        </span>
      </div>

      {/* Preview area */}
      {url ? (
        <div
          style={{ position: 'relative', cursor: 'zoom-in', height: '130px', background: '#f1f5f9' }}
          onClick={() => setLightbox({ url, label })}
        >
          <img
            src={url} alt={label}
            style={{ width: '100%', height: '130px', objectFit: 'cover', display: 'block' }}
            onError={e => {
              e.target.style.display = 'none';
              e.target.nextSibling.style.display = 'flex';
            }}
          />
          {/* fallback if image can't load */}
          <div style={{
            display: 'none', height: '130px', alignItems: 'center', justifyContent: 'center',
            flexDirection: 'column', gap: '6px', color: 'var(--text-muted)', fontSize: '0.75rem',
          }}>
            <FileText size={22} style={{ opacity: 0.35 }} />
            <span>Cannot preview</span>
            <span style={{ fontSize: '0.68rem' }}>(PDF or unsupported format)</span>
          </div>
          {/* Hover overlay */}
          <div style={{
            position: 'absolute', inset: 0, background: 'rgba(12,99,126,0.45)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: 0, transition: 'opacity 0.2s',
          }}
            onMouseEnter={e => e.currentTarget.style.opacity = '1'}
            onMouseLeave={e => e.currentTarget.style.opacity = '0'}
          >
            <span style={{ color: 'white', fontWeight: 700, fontSize: '0.78rem' }}>Click to expand</span>
          </div>
        </div>
      ) : (
        <div style={{
          height: '100px', display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', gap: '6px',
          color: 'var(--text-muted)', fontSize: '0.78rem',
        }}>
          <Shield size={22} style={{ opacity: 0.2 }} />
          <span style={{ fontWeight: 600 }}>{required ? 'Required — Not Submitted' : 'Optional — Not Provided'}</span>
        </div>
      )}

      {/* Open external link */}
      {url && (
        <button
          onClick={() => window.open(url, '_blank')}
          style={{
            width: '100%', padding: '0.45rem',
            background: 'transparent', border: 'none',
            borderTop: '1px solid #D8ECF2',
            fontSize: '0.7rem', fontWeight: 700, color: 'var(--primary)',
            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '5px',
            fontFamily: 'inherit', transition: 'background 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = '#EEF5F8'}
          onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
        >
          <ExternalLink size={11} /> Open original
        </button>
      )}
    </div>
  );

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
            <motion.div
              key="toast"
              initial={{ opacity: 0, y: -16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
              style={{
                position: 'fixed', top: '5.5rem', right: '2rem', zIndex: 9999,
                padding: '0.875rem 1.375rem', borderRadius: '14px',
                fontWeight: 700, fontSize: '0.9rem',
                background: toast.type === 'error' ? 'var(--error-bg)' : 'var(--success-bg)',
                color:      toast.type === 'error' ? 'var(--error-fg)' : 'var(--success-fg)',
                border: `1px solid ${toast.type === 'error' ? 'var(--error-border)' : 'var(--success-border)'}`,
                boxShadow: 'var(--shadow-md)',
              }}
            >
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
              Audit and approve healthcare professionals joining the network.
            </p>
          </div>
          <motion.button
            whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}
            onClick={fetchPending}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.7rem 1.375rem', borderRadius: '12px',
              border: '1px solid var(--border)', background: 'var(--surface)',
              color: 'var(--text-sub)', fontWeight: 700, cursor: 'pointer',
              fontSize: '0.875rem', fontFamily: 'var(--font-sans)',
            }}
          >
            <RefreshCw size={15} /> Refresh
          </motion.button>
        </div>

        {/* ── Error Banner ── */}
        {error && (
          <div style={{
            padding: '0.875rem 1.375rem', background: 'var(--error-bg)',
            border: '1px solid var(--error-border)', borderRadius: '12px',
            color: 'var(--error-fg)', marginBottom: '1.75rem', fontWeight: 600, fontSize: '0.9rem',
          }}>
            {error}
          </div>
        )}

        {/* ── Split Layout ── */}
        <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: '1.5rem', height: 'calc(100vh - 260px)' }}>

          {/* ── Left: Queue List ── */}
          <div className="card" style={{
            overflow: 'hidden', display: 'flex', flexDirection: 'column',
            border: '1px solid var(--border)', borderRadius: 'var(--radius-md)',
            background: 'var(--surface)',
          }}>
            <div style={{
              padding: '1.25rem 1.5rem', borderBottom: '1px solid var(--border)',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            }}>
              <h3 style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-sub)', display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                Pending
                <span style={{
                  background: 'var(--s-pending-bg)', color: 'var(--s-pending)',
                  padding: '0.15rem 0.6rem', borderRadius: '100px',
                  fontSize: '0.75rem', fontWeight: 800,
                }}>
                  {pending.length}
                </span>
              </h3>
            </div>

            <div style={{ flex: 1, overflowY: 'auto' }}>
              {loading ? (
                Array(4).fill(null).map((_, i) => (
                  <div key={i} style={{
                    padding: '1.125rem 1.5rem', borderBottom: '1px solid var(--border)',
                    display: 'flex', gap: '0.875rem', alignItems: 'center',
                  }}>
                    <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'var(--surface-raised)', flexShrink: 0 }} />
                    <div style={{ flex: 1 }}>
                      <div style={{ height: '13px', background: 'var(--surface-raised)', borderRadius: '6px', marginBottom: '7px', width: '65%' }} />
                      <div style={{ height: '11px', background: 'var(--surface-raised)', borderRadius: '6px', width: '45%' }} />
                    </div>
                  </div>
                ))
              ) : pending.length === 0 ? (
                <div style={{ padding: '4rem 1.5rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <UserCheck size={44} style={{ opacity: 0.2, display: 'block', margin: '0 auto 1.25rem' }} />
                  <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>No pending applications</p>
                </div>
              ) : (
                pending.map((r) => {
                  const isSelected = selectedResponder?.userId === r.userId;
                  return (
                    <div
                      key={r.id}
                      onClick={() => setSelectedResponder(r)}
                      style={{
                        padding: '1.125rem 1.5rem',
                        display: 'flex', alignItems: 'center', gap: '0.875rem',
                        cursor: 'pointer', borderBottom: '1px solid var(--border)',
                        background: isSelected ? 'var(--primary-pale)' : 'transparent',
                        borderLeft: `3px solid ${isSelected ? 'var(--primary)' : 'transparent'}`,
                        transition: 'all 0.18s ease',
                      }}
                    >
                      <div style={{
                        width: '40px', height: '40px', borderRadius: '50%',
                        background: isSelected ? 'var(--primary)' : 'var(--surface-raised)',
                        color: isSelected ? 'white' : 'var(--primary)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontWeight: 800, fontSize: '1rem', flexShrink: 0,
                        transition: 'all 0.18s ease',
                      }}>
                        {r.user?.fullName?.charAt(0) || '?'}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 700, fontSize: '0.875rem', color: 'var(--text-sub)', marginBottom: '0.15rem' }}>
                          {r.user?.fullName}
                        </div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '0.2rem' }}>
                          {RESPONDER_TYPE_LABELS[r.responderType] || r.responderType} · {r.organization || 'Independent'}
                        </div>
                        {/* ── Wait time badge ── */}
                        <div style={{
                          display: 'inline-flex', alignItems: 'center', gap: '0.25rem',
                          fontSize: '0.68rem', fontWeight: 700,
                          color: waitColor(r.user?.createdAt),
                        }}>
                          <Clock size={10} />
                          {timeAgo(r.user?.createdAt)}
                        </div>
                      </div>
                      <ChevronRight size={15} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* ── Right: Detail Panel ── */}
          <div className="card" style={{
            border: '1px solid var(--border)', borderRadius: 'var(--radius-md)',
            overflow: 'hidden', background: 'var(--surface)',
            display: 'flex', flexDirection: 'column',
          }}>
            {selectedResponder ? (
              <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0 }}>

              {/* ── Scrollable top section (header + credentials + docs) ── */}
              <div style={{ flex: 1, overflowY: 'auto', padding: '2.25rem 2.25rem 0' }}>

                {/* Detail header */}
                <div style={{
                  display: 'flex', alignItems: 'center', gap: '1.75rem',
                  marginBottom: '2.25rem', paddingBottom: '2rem',
                  borderBottom: '1px solid var(--border)',
                }}>
                  <div style={{
                    width: '72px', height: '72px',
                    background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                    color: 'white', borderRadius: '18px',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: '1.875rem', fontWeight: 800, flexShrink: 0,
                  }}>
                    {selectedResponder.user?.fullName?.charAt(0) || '?'}
                  </div>
                  <div style={{ flex: 1 }}>
                    <h2 style={{ fontSize: '1.5rem', marginBottom: '0.375rem', color: 'var(--text-sub)', letterSpacing: '-0.03em' }}>
                      {selectedResponder.user?.fullName}
                    </h2>
                    <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                      {selectedResponder.user?.email} · {selectedResponder.user?.phoneNumber || 'N/A'}
                    </p>
                    <div style={{
                      display: 'inline-flex', alignItems: 'center', gap: '0.3rem',
                      marginTop: '0.4rem', fontSize: '0.78rem', fontWeight: 700,
                      color: waitColor(selectedResponder.user?.createdAt),
                    }}>
                      <Clock size={12} />
                      Waiting {timeAgo(selectedResponder.user?.createdAt)}
                    </div>
                  </div>

                  {/* View Full Application button */}
                  <motion.button
                    whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.97 }}
                    onClick={() => setShowApplication(true)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '0.5rem',
                      padding: '0.7rem 1.25rem', borderRadius: '12px',
                      border: '1.5px solid var(--primary)',
                      background: 'var(--primary-pale)',
                      color: 'var(--primary)', fontWeight: 700,
                      cursor: 'pointer', fontSize: '0.85rem',
                      fontFamily: 'var(--font-sans)', flexShrink: 0,
                    }}
                  >
                    <FileText size={15} /> View Full Application
                  </motion.button>
                </div>

                {/* Credentials + Documents grid */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.4fr', gap: '2rem', paddingBottom: '1.5rem' }}>

                  <div>
                    <p style={{
                      fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '0.08em',
                      color: 'var(--text-muted)', fontWeight: 700, marginBottom: '1.25rem',
                    }}>
                      Professional Credentials
                    </p>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.125rem' }}>
                      {[
                        { label: 'License Number',  value: selectedResponder.licenseNumber || '—' },
                        { label: 'Responder Type',  value: RESPONDER_TYPE_LABELS[selectedResponder.responderType] || selectedResponder.responderType || '—' },
                        { label: 'Specialization',  value: (() => {
                            const specs = Array.isArray(selectedResponder.specialization) && selectedResponder.specialization.length
                              ? selectedResponder.specialization : ['General Emergency'];
                            return specs.join(' · ');
                          })() },
                        { label: 'Vehicle Type',    value: selectedResponder.vehicleType   || 'Not specified' },
                        { label: 'Organization',    value: selectedResponder.organization  || 'Independent' },
                      ].map((item) => (
                        <div key={item.label}>
                          <span style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '0.3rem', fontWeight: 600 }}>
                            {item.label}
                          </span>
                          <strong style={{ fontSize: '0.95rem', color: 'var(--text-sub)' }}>{item.value}</strong>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* All 4 documents — inline thumbnail previews */}
                  <div>
                    <p style={{
                      fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '0.08em',
                      color: 'var(--text-muted)', fontWeight: 700, marginBottom: '1.25rem',
                    }}>
                      Identity Documents
                    </p>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                      <DocCard label="CNIC — Front"                           url={resolveFileUrl(selectedResponder.cnicImageUrl)}            required={true}  />
                      <DocCard label="CNIC — Back"                            url={resolveFileUrl(selectedResponder.cnicBackImageUrl)}        required={true}  />
                      <DocCard label="Employee ID — Front"                    url={resolveFileUrl(selectedResponder.employeeCardImageUrl)}    required={true}  />
                      <DocCard label="Employee ID — Back"                     url={resolveFileUrl(selectedResponder.employeeCardBackImageUrl)} required={false} />
                    </div>
                  </div>
                </div>

              </div>{/* end scrollable section */}

              {/* ── Action buttons — always visible, pinned at bottom ── */}
              <div style={{
                display: 'flex', gap: '1.25rem',
                padding: '1.25rem 2.25rem',
                borderTop: '1px solid var(--border)',
                background: 'var(--surface)',
                flexShrink: 0,
              }}>
                  <button
                    disabled={!!processingId}
                    onClick={() => setShowRejectModal(true)}
                    style={{
                      flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
                      gap: '0.625rem', padding: '0.9rem',
                      background: 'var(--error-bg)', border: '1px solid var(--error-border)',
                      color: 'var(--error-fg)', borderRadius: '14px',
                      fontWeight: 700, fontSize: '0.95rem',
                      cursor: processingId ? 'not-allowed' : 'pointer',
                      opacity: processingId ? 0.6 : 1,
                      fontFamily: 'var(--font-sans)', transition: 'all 0.18s ease',
                    }}
                  >
                    <X size={18} /> Reject
                  </button>
                  <button
                    disabled={!!processingId}
                    onClick={() => handleAction(selectedResponder.userId, 'VERIFY')}
                    style={{
                      flex: 2, display: 'flex', alignItems: 'center', justifyContent: 'center',
                      gap: '0.625rem', padding: '0.9rem',
                      background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                      color: 'white', border: 'none', borderRadius: '14px',
                      fontWeight: 700, fontSize: '0.95rem',
                      cursor: processingId ? 'not-allowed' : 'pointer',
                      opacity: processingId ? 0.7 : 1,
                      fontFamily: 'var(--font-sans)',
                      boxShadow: processingId ? 'none' : '0 4px 16px rgba(12,99,126,0.30)',
                      transition: 'all 0.18s ease',
                    }}
                  >
                    <Check size={18} /> {processingId ? 'Processing…' : 'Approve Responder'}
                  </button>
                </div>

              </div>
            ) : (
              <div style={{
                height: '100%', display: 'flex', flexDirection: 'column',
                alignItems: 'center', justifyContent: 'center',
                textAlign: 'center', padding: '4rem', color: 'var(--text-muted)',
              }}>
                <UserCheck size={64} style={{ opacity: 0.10, marginBottom: '2rem', color: 'var(--primary)' }} />
                <h3 style={{ fontSize: '1.375rem', marginBottom: '0.75rem', color: 'var(--text-sub)' }}>
                  Select an Application
                </h3>
                <p style={{ maxWidth: '280px', lineHeight: 1.7, fontSize: '0.95rem' }}>
                  Choose a responder from the list to review their credentials and make a decision.
                </p>
              </div>
            )}
          </div>
        </div>
      </motion.div>

      {/* ── Modals ── */}
      <AnimatePresence>
        {showApplication && selectedResponder && (
          <ApplicationModal
            responder={selectedResponder}
            onClose={() => setShowApplication(false)}
          />
        )}
      </AnimatePresence>

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

      {/* ── Document Lightbox ── */}
      <AnimatePresence>
        {lightbox && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            onClick={() => setLightbox(null)}
            style={{
              position: 'fixed', inset: 0, zIndex: 20000,
              background: 'rgba(0,0,0,0.88)', backdropFilter: 'blur(6px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              padding: '2rem', cursor: 'zoom-out',
            }}
          >
            <motion.div
              initial={{ scale: 0.85, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.85, opacity: 0 }}
              transition={{ type: 'spring', stiffness: 300, damping: 28 }}
              onClick={e => e.stopPropagation()}
              style={{ position: 'relative', maxWidth: '90vw', maxHeight: '88vh', cursor: 'default' }}
            >
              <img
                src={lightbox.url}
                alt={lightbox.label}
                style={{ maxWidth: '90vw', maxHeight: '80vh', borderRadius: '12px', display: 'block', boxShadow: '0 32px 80px rgba(0,0,0,0.7)' }}
              />
              <div style={{
                position: 'absolute', bottom: '-2.5rem', left: 0, right: 0,
                textAlign: 'center', color: 'rgba(255,255,255,0.75)',
                fontSize: '0.85rem', fontWeight: 600,
              }}>
                {lightbox.label}
              </div>
              <button
                onClick={() => setLightbox(null)}
                style={{
                  position: 'absolute', top: '-14px', right: '-14px',
                  width: '36px', height: '36px', borderRadius: '50%',
                  background: 'white', border: 'none', cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
                }}
              >
                <X size={16} color="#374151" />
              </button>
              <a
                href={lightbox.url}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  position: 'absolute', top: '-14px', right: '30px',
                  padding: '0.35rem 0.875rem', borderRadius: '20px',
                  background: '#0C637E', color: 'white',
                  fontSize: '0.75rem', fontWeight: 700, textDecoration: 'none',
                  display: 'flex', alignItems: 'center', gap: '4px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
                }}
              >
                <ExternalLink size={11} /> Open original
              </a>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

export default ResponderVerification;

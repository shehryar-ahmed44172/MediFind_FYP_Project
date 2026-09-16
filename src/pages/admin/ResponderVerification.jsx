import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import {
  UserCheck, Shield, ExternalLink, Check, X,
  FileText, Clock, Printer, Info, Maximize2,
} from 'lucide-react';
import api from '../../services/api';
import { lightTokenCss, paginate } from '../../components/uiStyles';
import { resolveFileUrl } from '../../utils/resolveFileUrl';
import {
  PageHeader, RefreshButton, ErrorBanner, StatCard, Panel, Toolbar, SearchInput, DataTable,
  TableSkeletonRows, EmptyState, Pagination, Avatar, StatusBadge, Button, Modal, Drawer,
  DetailItem, Notice, FilterPill, FormField, Textarea,
} from '../../components/ui';

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

const waitDays = (dateStr) => (dateStr ? (Date.now() - new Date(dateStr).getTime()) / 86400000 : 0);

function waitColor(dateStr) {
  if (!dateStr) return 'var(--text-muted)';
  const days = waitDays(dateStr);
  if (days >= 2) return 'var(--error-fg)';
  if (days >= 1) return 'var(--warning-fg)';
  return 'var(--text-muted)';
}

function waitTone(dateStr) {
  const days = waitDays(dateStr);
  if (days >= 2) return 'danger';
  if (days >= 1) return 'warning';
  return 'neutral';
}

const RESPONDER_TYPE_LABELS = {
  RESCUE_OFFICER:  'Rescue Officer (e.g. 1122)',
  PARAMEDIC:       'Paramedic',
  EMT:             'Emergency Medical Technician (EMT)',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER:       'Community Volunteer',
};

const shortType = (r) => RESPONDER_TYPE_LABELS[r.responderType]?.split('(')[0].trim() || r.responderType || '—';

// Full document set shown on the formal application form
const applicationDocs = (responder) => [
  { label: 'CNIC — Front',                       url: resolveFileUrl(responder.cnicImageUrl),              required: true  },
  { label: 'CNIC — Back',                         url: resolveFileUrl(responder.cnicBackImageUrl),          required: true  },
  { label: 'Employee / Professional ID — Front',  url: resolveFileUrl(responder.employeeCardImageUrl),      required: true  },
  { label: 'Employee / Professional ID — Back',   url: resolveFileUrl(responder.employeeCardBackImageUrl),  required: false },
  { label: 'Driving License',                     url: resolveFileUrl(responder.drivingLicenseUrl),         required: true  },
  { label: 'Motorbike Documents (RC Book)',        url: resolveFileUrl(responder.motorbikeDocUrl),           required: true  },
];

const missingRequired = (responder) => applicationDocs(responder).filter(d => d.required && !d.url).length;

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

  const docs = applicationDocs(responder);

  return (
    <Modal
      onClose={onClose}
      title="Emergency responder application"
      description={responder.user?.fullName || undefined}
      width={860}
      bodyStyle={{ padding: 0, background: 'var(--surface-alt)' }}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Close</Button>
          <Button variant="primary" icon={Printer} onClick={handlePrint}>Print / Save as PDF</Button>
        </>
      }
    >
      {/* Printable form — inline styles only: the print window gets markup + light tokens */}
      <div id="application-print-area" data-theme="light" style={{
        width: '100%', background: 'white', color: 'var(--text-main)',
        fontFamily: 'Arial, sans-serif',
      }}>
        {/* Banner */}
        <div style={{ background: 'var(--primary-dark)', padding: '24px 32px', color: 'white', WebkitPrintColorAdjust: 'exact', printColorAdjust: 'exact' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '16px' }}>
            <div>
              <div style={{ fontSize: '11px', letterSpacing: '0.08em', textTransform: 'uppercase', opacity: 0.75, marginBottom: '6px' }}>
                MediFind Healthcare Emergency Network · Pakistan
              </div>
              <h1 style={{ fontSize: '20px', fontWeight: 600, margin: 0, color: 'white' }}>
                Emergency Responder Application Form
              </h1>
              <p style={{ margin: '4px 0 0', opacity: 0.8, fontSize: '13px', color: 'white' }}>
                Submitted for Administrative Review &amp; Credential Verification
              </p>
            </div>
            <div style={{ textAlign: 'right', fontSize: '12px', opacity: 0.9 }}>
              <div style={{ fontWeight: 600 }}>Application ID</div>
              <div style={{ fontFamily: 'monospace', fontSize: '13px' }}>{responder.id?.slice(0, 8).toUpperCase() || 'N/A'}</div>
              <div style={{ marginTop: '8px', fontWeight: 600 }}>Date Submitted</div>
              <div>{submittedDate}</div>
            </div>
          </div>
        </div>

        <div style={{ padding: '8px 32px 28px' }}>
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

          <AppSectionTitle num="3" title="Identity & Credential Documents" />
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: '-4px 0 16px', lineHeight: 1.6 }}>
            Documents uploaded by the applicant during registration. Verify each carefully before deciding.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px', marginBottom: '24px' }}>
            {docs.map(({ label, url, required }) => (
              <div key={label} style={{ border: '1px solid var(--border)', borderRadius: '8px', overflow: 'hidden', background: 'var(--surface-alt)' }}>
                <div style={{ padding: '8px 10px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px', background: 'white' }}>
                  <span style={{ fontWeight: 600, fontSize: '12px', color: 'var(--text-sub)' }}>{label}</span>
                  <span style={{ fontSize: '10.5px', fontWeight: 600, padding: '2px 7px', borderRadius: '999px', whiteSpace: 'nowrap', background: url ? 'var(--success-bg)' : required ? 'var(--error-bg)' : 'var(--tint-slate)', color: url ? 'var(--success-fg)' : required ? 'var(--error-fg)' : 'var(--text-muted)' }}>
                    {url ? 'UPLOADED' : required ? 'MISSING' : 'NOT PROVIDED'}
                  </span>
                </div>
                {url ? (
                  <div style={{ position: 'relative' }}>
                    <img src={url} alt={label} style={{ width: '100%', height: '160px', objectFit: 'cover', display: 'block' }}
                      onError={e => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }} />
                    <div style={{ display: 'none', height: '160px', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '8px', background: 'var(--tint-slate)', color: 'var(--text-muted)', fontSize: '12px' }}>
                      <FileText size={22} style={{ opacity: 0.5 }} /><span>Cannot display</span>
                    </div>
                    <button type="button" className="no-print" onClick={() => window.open(url, '_blank')} style={{ position: 'absolute', bottom: '8px', right: '8px', background: 'rgba(15,23,42,0.7)', color: 'white', border: 'none', borderRadius: '6px', padding: '4px 8px', fontSize: '11px', fontWeight: 500, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <ExternalLink size={11} /> Open full
                    </button>
                  </div>
                ) : (
                  <div style={{ height: '160px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '8px', color: 'var(--text-muted)', fontSize: '12.5px' }}>
                    <Shield size={22} style={{ opacity: 0.35 }} />
                    <span style={{ fontWeight: 500 }}>{required ? 'Required — Not Submitted' : 'Optional — Not Provided'}</span>
                  </div>
                )}
              </div>
            ))}
          </div>

          <AppSectionTitle num="4" title="Applicant Declaration" />
          <div style={{ background: 'var(--surface-alt)', border: '1px solid var(--border)', borderRadius: '8px', padding: '16px 20px', marginBottom: '24px' }}>
            <p style={{ fontSize: '13.5px', color: 'var(--text-sub)', lineHeight: 1.7, margin: 0 }}>
              By submitting this application, <strong>{responder.user?.fullName || '[Applicant]'}</strong> hereby declares and confirms:
            </p>
            <ol style={{ margin: '10px 0 0', paddingLeft: '20px', fontSize: '13.5px', color: 'var(--text-sub)', lineHeight: 1.9 }}>
              <li>All information provided is accurate, complete, and truthful.</li>
              <li>I hold valid professional certification as a <strong>{RESPONDER_TYPE_LABELS[responder.responderType] || 'Emergency Responder'}</strong> and license <strong>{responder.licenseNumber || 'N/A'}</strong> is genuine and active.</li>
              <li>I understand I am joining the MediFind Emergency Response Network and will respond to real medical emergencies.</li>
              <li>I acknowledge that providing false information or fraudulent documents is grounds for immediate rejection and may result in legal action.</li>
              <li>I consent to credential verification with relevant healthcare and government authorities.</li>
              <li>I understand my application will be reviewed within 2–3 business days.</li>
            </ol>
          </div>

          <div className="print-page-break" style={{ paddingTop: '4px' }}>
            <AppSectionTitle num="5" title="Administrative Review — For Official Use Only" />
            <div style={{ border: '1px dashed var(--border)', borderRadius: '8px', padding: '16px 20px', marginBottom: '20px', background: 'var(--surface-alt)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
                <ReviewField label="Reviewed by (Admin Name)" value={reviewedBy} onChange={e => setReviewedBy(e.target.value)} placeholder="Enter admin name" />
                <ReviewField label="Review Date" value={reviewDate} onChange={e => setReviewDate(e.target.value)} placeholder="DD/MM/YYYY" />
              </div>
              <div style={{ marginBottom: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '10px', background: 'white', border: '1px solid var(--info-border)', borderRadius: '8px', padding: '10px 12px' }}>
                  <Info size={15} color="var(--primary)" aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }} />
                  <div>
                    <div style={{ fontSize: '12.5px', fontWeight: 600, color: 'var(--primary)', marginBottom: '2px' }}>Decision Recorded Digitally</div>
                    <div style={{ fontSize: '12.5px', color: 'var(--text-sub)', lineHeight: 1.5 }}>
                      The approval or rejection is executed via the <strong>Approve</strong> / <strong>Reject</strong> buttons in the Verification Queue. The outcome is automatically logged in the system audit trail.
                    </div>
                  </div>
                </div>
              </div>
              <div style={{ marginBottom: '16px' }}>
                <ReviewField label="Notes / Rejection Reason (if applicable)" value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="Add review notes or state reason if rejected" />
              </div>
              <SignatureStampField value={adminSig} onChange={e => setAdminSig(e.target.value)} />
            </div>
          </div>

          <div style={{ marginTop: '20px', paddingTop: '12px', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', gap: '12px', fontSize: '11px', color: 'var(--text-muted)' }}>
            <span>MediFind Healthcare Emergency Network · Pakistan · Confidential</span>
            <span>Application Ref: {responder.id?.slice(0, 16).toUpperCase() || 'N/A'}</span>
          </div>
        </div>
      </div>
    </Modal>
  );
};

// ─── Responder review drawer ─────────────────────────────────────────────────
// Opens when the admin selects an applicant in the queue.

const DOC_BADGE = (url, required) => (
  url ? <StatusBadge tone="success">Uploaded</StatusBadge>
    : required ? <StatusBadge tone="warning">Not submitted</StatusBadge>
      : <StatusBadge tone="neutral">Not provided</StatusBadge>
);

const ResponderDetailModal = ({ responder, processingId, onApprove, onReject, onViewApplication, onClose }) => {
  const [lightbox, setLightbox] = useState(null);

  const docs = [
    { label: 'CNIC — Front',       url: resolveFileUrl(responder.cnicImageUrl),             required: true  },
    { label: 'CNIC — Back',        url: resolveFileUrl(responder.cnicBackImageUrl),         required: true  },
    { label: 'Employee ID — Front',url: resolveFileUrl(responder.employeeCardImageUrl),     required: true  },
    { label: 'Employee ID — Back', url: resolveFileUrl(responder.employeeCardBackImageUrl), required: false },
  ];

  const isProcessing = processingId === responder.userId;
  const sectionLabel = { fontSize: '11.5px', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--text-muted)', margin: '0 0 10px' };

  return (
    <>
      <Drawer
        // Escape / backdrop close the lightbox first when it is open
        onClose={lightbox ? () => setLightbox(null) : onClose}
        width={640}
        title={responder.user?.fullName || 'Applicant'}
        description={`${responder.user?.email || '—'} · ${responder.user?.phoneNumber || 'No phone'}`}
        headerExtra={
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap', marginTop: '10px' }}>
            <StatusBadge tone={waitTone(responder.user?.createdAt)} icon={Clock}>
              Submitted {timeAgo(responder.user?.createdAt)}
            </StatusBadge>
            <Button size="sm" icon={FileText} onClick={onViewApplication}>View full application</Button>
          </div>
        }
        footer={
          <>
            <Button variant="danger-outline" icon={X} disabled={isProcessing} onClick={onReject}>Reject</Button>
            <Button variant="primary" icon={Check} disabled={isProcessing} onClick={onApprove}>
              {isProcessing ? 'Processing…' : 'Approve responder'}
            </Button>
          </>
        }
      >
        <div style={{ padding: '20px' }}>
          <h3 style={sectionLabel}>Professional credentials</h3>
          <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '14px 24px', margin: '0 0 24px' }}>
            <DetailItem label="Responder type">{shortType(responder)}</DetailItem>
            <DetailItem label="License #"><span className="mf-num">{responder.licenseNumber || '—'}</span></DetailItem>
            <DetailItem label="Organization">{responder.organization || 'Independent'}</DetailItem>
            <DetailItem label="Vehicle type">{responder.vehicleType === 'MOTORBIKE_AMBULANCE' ? 'Motorbike Ambulance' : (responder.vehicleType || 'Not specified')}</DetailItem>
            <DetailItem label="Motorbike reg.">{responder.motorbikeNumber || 'Not provided'}</DetailItem>
            <DetailItem label="Specializations">
              {Array.isArray(responder.specialization) && responder.specialization.length ? responder.specialization.join(', ') : 'General Emergency'}
            </DetailItem>
          </dl>

          <h3 style={sectionLabel}>Identity documents</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '12px' }}>
            {docs.map(({ label, url, required }) => (
              <div key={label} style={{ border: '1px solid var(--border)', borderRadius: '8px', overflow: 'hidden', background: 'var(--surface)' }}>
                <div style={{ padding: '8px 10px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px' }}>
                  <span style={{ fontSize: '12.5px', fontWeight: 500, color: 'var(--text-main)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</span>
                  {DOC_BADGE(url, required)}
                </div>
                {url ? (
                  <button
                    type="button"
                    onClick={() => setLightbox({ url, label })}
                    aria-label={`Expand ${label}`}
                    title="Expand"
                    style={{ display: 'block', width: '100%', padding: 0, border: 'none', cursor: 'zoom-in', height: '130px', background: 'var(--surface-alt)' }}
                  >
                    <img src={url} alt={label} style={{ width: '100%', height: '130px', objectFit: 'cover', display: 'block' }}
                      onError={e => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }} />
                    <span style={{ display: 'none', height: '130px', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '6px', color: 'var(--text-muted)', fontSize: '12px' }}>
                      <FileText size={18} style={{ opacity: 0.6 }} /><span>Cannot preview</span>
                    </span>
                  </button>
                ) : (
                  <div style={{ height: '130px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '6px', color: 'var(--text-muted)', fontSize: '12.5px', background: 'var(--surface-alt)' }}>
                    <Shield size={18} style={{ opacity: 0.5 }} aria-hidden="true" />
                    <span>{required ? 'Not submitted' : 'Not provided'}</span>
                  </div>
                )}
                {url && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid var(--border)', padding: '4px' }}>
                    <Button variant="ghost" size="sm" icon={Maximize2} onClick={() => setLightbox({ url, label })}>Expand</Button>
                    <Button variant="ghost" size="sm" icon={ExternalLink} onClick={() => window.open(url, '_blank')}>Open original</Button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </Drawer>

      {/* Document lightbox */}
      {lightbox && createPortal(
        <div
          className="mf-fade"
          role="dialog"
          aria-modal="true"
          aria-label={lightbox.label}
          onClick={() => setLightbox(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 20000, background: 'rgba(15,23,42,0.85)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '12px', padding: '24px', cursor: 'zoom-out' }}
        >
          <div onClick={e => e.stopPropagation()} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', width: 'min(90vw, 1100px)', cursor: 'default' }}>
            <span style={{ color: '#F8FAFC', fontSize: '13.5px', fontWeight: 500 }}>{lightbox.label}</span>
            <div style={{ display: 'flex', gap: '8px' }}>
              <a href={lightbox.url} target="_blank" rel="noopener noreferrer" className="mf-btn mf-btn--secondary mf-btn--sm">
                <ExternalLink size={14} aria-hidden="true" /> Open original
              </a>
              <Button size="sm" icon={X} onClick={() => setLightbox(null)}>Close</Button>
            </div>
          </div>
          <img
            src={lightbox.url}
            alt={lightbox.label}
            onClick={e => e.stopPropagation()}
            className="mf-pop"
            style={{ maxWidth: '90vw', maxHeight: '80vh', borderRadius: '8px', display: 'block', cursor: 'default', boxShadow: 'var(--shadow-lg)' }}
          />
        </div>,
        document.body,
      )}
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
    <Modal
      onClose={processing ? undefined : onCancel}
      title="Reject application"
      description={responderName}
      width={540}
      zIndex={10600}
      footer={
        <>
          <Button variant="secondary" onClick={onCancel} disabled={processing}>Cancel</Button>
          <Button variant="danger" onClick={() => reason.trim() && onConfirm(reason.trim())} disabled={!reason.trim() || processing}>
            {processing ? 'Rejecting…' : 'Confirm rejection'}
          </Button>
        </>
      }
    >
      <p style={{ fontSize: '13.5px', color: 'var(--admin-text-sub)', margin: '0 0 14px', lineHeight: 1.6 }}>
        Provide a reason. This message will be sent to the applicant so they know what to correct.
      </p>
      <p style={{ fontSize: '12.5px', fontWeight: 500, color: 'var(--text-muted)', margin: '0 0 8px' }}>Quick select</p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginBottom: '14px' }}>
        {presets.map(p => (
          <FilterPill key={p} active={reason === p} onClick={() => setReason(p)}>{p}</FilterPill>
        ))}
      </div>
      <FormField label="Reason" htmlFor="reject-reason">
        <Textarea id="reject-reason" value={reason} onChange={e => setReason(e.target.value)} placeholder="Or type a custom reason here…" rows={3} />
      </FormField>
    </Modal>
  );
};

// ─── Printable form sub-components (inline styles — used in the print window) ─

const AppSectionTitle = ({ num, title }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '12px', marginTop: '24px' }}>
    <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--primary)', whiteSpace: 'nowrap' }}>{num}.</span>
    <h3 style={{ margin: 0, fontSize: '14px', fontWeight: 600, color: 'var(--text-main)' }}>{title}</h3>
    <div style={{ flex: 1, height: '1px', background: 'var(--border)' }} />
  </div>
);

const AppFieldGrid = ({ fields }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '10px', marginBottom: '8px' }}>
    {fields.map(({ label, value }) => (
      <div key={label} style={{ background: 'var(--surface-alt)', borderRadius: '6px', padding: '8px 12px', border: '1px solid var(--border)' }}>
        <div style={{ fontSize: '11px', fontWeight: 500, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '2px' }}>{label}</div>
        <div style={{ fontSize: '13.5px', fontWeight: 500, color: 'var(--text-main)' }}>{value}</div>
      </div>
    ))}
  </div>
);

const ReviewField = ({ label, value, onChange, placeholder }) => (
  <div>
    <div style={{ fontSize: '11px', fontWeight: 500, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '6px' }}>{label}</div>
    <input type="text" value={value} onChange={onChange} placeholder={placeholder}
      style={{ width: '100%', padding: '6px 8px', border: 'none', borderBottom: '1.5px solid var(--text-muted)', fontSize: '13.5px', fontFamily: 'Arial, sans-serif', color: 'var(--text-main)', background: 'transparent', outline: 'none', fontWeight: value ? 600 : 400 }}
      onFocus={e => e.target.style.borderBottomColor = 'var(--primary)'}
      onBlur={e => e.target.style.borderBottomColor = 'var(--text-muted)'} />
  </div>
);

const SignatureStampField = ({ value, onChange }) => (
  <div>
    <div style={{ fontSize: '11px', fontWeight: 500, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '10px' }}>Admin Signature &amp; Official Stamp</div>
    <div style={{ display: 'flex', alignItems: 'center', gap: '28px' }}>
      <div style={{ flex: 1 }}>
        <div style={{ position: 'relative', background: 'white', borderRadius: '6px 6px 0 0', border: '1px solid var(--border)', borderBottom: `2px solid ${value ? 'var(--primary)' : 'var(--border)'}`, transition: 'border-color 0.2s', padding: '10px 14px 8px' }}>
          <input type="text" value={value} onChange={onChange} placeholder="Click here and sign your name…"
            style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: value ? '"Great Vibes", cursive' : 'inherit', fontSize: value ? '2rem' : '0.875rem', color: value ? 'var(--primary-dark)' : 'var(--text-muted)', lineHeight: 1.3, boxSizing: 'border-box' }}
            onFocus={e => e.currentTarget.parentElement.style.borderBottomColor = 'var(--primary)'}
            onBlur={e => e.currentTarget.parentElement.style.borderBottomColor = value ? 'var(--primary)' : 'var(--border)'} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '4px' }}>
          <span style={{ fontSize: '10px', color: 'var(--text-muted)', letterSpacing: '0.06em' }}>AUTHORIZED SIGNATURE</span>
          {value && <span style={{ fontSize: '10px', color: 'var(--primary)', fontWeight: 600, letterSpacing: '0.04em' }}>SIGNED</span>}
        </div>
      </div>
      <div style={{ flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
        <div style={{ width: '110px', height: '110px', border: '2px solid var(--primary)', borderRadius: '50%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative', opacity: value ? 1 : 0.3, transition: 'opacity 0.3s' }}>
          <div style={{ position: 'absolute', inset: '5px', border: '1px dashed var(--primary)', borderRadius: '50%' }} />
          <div style={{ textAlign: 'center', zIndex: 1, padding: '0 8px' }}>
            <div style={{ fontSize: '0.52rem', fontWeight: 700, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.12em', lineHeight: 1.4, marginBottom: '3px' }}>MediFind</div>
            <div style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--primary)', fontFamily: 'Arial, sans-serif', lineHeight: 1 }}>✦</div>
            <div style={{ fontSize: '0.42rem', fontWeight: 700, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.1em', lineHeight: 1.5, marginTop: '3px' }}>Emergency Response<br />Network · Pakistan</div>
          </div>
          <svg style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }} viewBox="0 0 110 110">
            <path id="topArc" d="M 10,55 A 45,45 0 0 1 100,55" fill="none" />
            <text fontSize="7" fontWeight="700" fill="var(--primary)" fontFamily="Arial, sans-serif" letterSpacing="2">
              <textPath href="#topArc" startOffset="8%">OFFICIAL · VERIFIED · AUTHORIZED</textPath>
            </text>
          </svg>
        </div>
        <div style={{ fontSize: '10px', color: value ? 'var(--primary)' : 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.08em', transition: 'color 0.3s' }}>OFFICIAL STAMP</div>
      </div>
    </div>
  </div>
);

const SpecializationRow = ({ specs }) => (
  <div style={{ background: 'var(--surface-alt)', borderRadius: '6px', padding: '8px 12px', border: '1px solid var(--border)', marginBottom: '8px' }}>
    <div style={{ fontSize: '11px', fontWeight: 500, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '6px' }}>Specializations ({specs.length})</div>
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
      {specs.map(spec => (
        <span key={spec} style={{ padding: '3px 10px', borderRadius: '999px', background: 'white', color: 'var(--text-sub)', fontSize: '12px', fontWeight: 500, border: '1px solid var(--border)' }}>{spec}</span>
      ))}
    </div>
  </div>
);

// ─── Main Page Component ──────────────────────────────────────────────────────

const PAGE_SIZE = 10;

const ResponderVerification = () => {
  const [pending,           setPending]           = useState([]);
  const [loading,           setLoading]           = useState(true);
  const [selectedResponder, setSelectedResponder] = useState(null); // opens review drawer
  const [processingId,      setProcessingId]      = useState(null);
  const [toast,             setToast]             = useState(null);
  const [error,             setError]             = useState('');
  const [showApplication,   setShowApplication]   = useState(false); // formal A4 form
  const [showRejectModal,   setShowRejectModal]   = useState(false);
  const [search,            setSearch]            = useState('');
  const [page,              setPage]              = useState(1);

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

  const closeDetail = () => {
    // With the rejection dialog open, Escape should only dismiss that dialog
    if (showRejectModal) {
      if (!processingId) setShowRejectModal(false);
      return;
    }
    setSelectedResponder(null);
    setShowRejectModal(false);
  };

  /* ── Derived ── */
  const q = search.trim().toLowerCase();
  const filtered = pending.filter(r => (
    !q ||
    (r.user?.fullName || '').toLowerCase().includes(q) ||
    (r.user?.email || '').toLowerCase().includes(q) ||
    (r.licenseNumber || '').toLowerCase().includes(q) ||
    (r.organization || '').toLowerCase().includes(q)
  ));
  const { page: currentPage, rows } = paginate(filtered, page, PAGE_SIZE);

  const stats = [
    { label: 'Awaiting review', value: pending.length, hint: 'Pending applications' },
    { label: 'Waiting over 24h', value: pending.filter(r => waitDays(r.user?.createdAt) >= 1).length, hint: 'Since registration' },
    { label: 'Waiting over 48h', value: pending.filter(r => waitDays(r.user?.createdAt) >= 2).length, hint: 'Past the review target' },
    { label: 'Incomplete documents', value: pending.filter(r => missingRequired(r) > 0).length, hint: 'Missing a required upload' },
  ];

  const COLS = 7;

  return (
    <>
      {/* ── Toast ── */}
      {toast && (
        <div className="mf-pop" style={{ position: 'fixed', top: '72px', right: '24px', zIndex: 9999, maxWidth: '420px' }}>
          <Notice tone={toast.type === 'error' ? 'danger' : 'success'} role="status" style={{ boxShadow: 'var(--shadow-overlay)' }}>
            {toast.msg}
          </Notice>
        </div>
      )}

      <PageHeader
        title="Verification Queue"
        description={loading ? 'Loading…' : `${pending.length} application${pending.length !== 1 ? 's' : ''} awaiting review.`}
        actions={<RefreshButton onClick={fetchPending} loading={loading} />}
      />

      <ErrorBanner onRetry={fetchPending}>{error}</ErrorBanner>

      <div className="mf-grid-stats" style={{ marginBottom: '16px' }}>
        {stats.map(s => <StatCard key={s.label} label={s.label} value={s.value} hint={s.hint} loading={loading} />)}
      </div>

      <Panel>
        <Toolbar>
          <SearchInput
            width={340}
            value={search}
            onChange={(v) => { setSearch(v); setPage(1); }}
            placeholder="Search by name, email, license or organization…"
          />
        </Toolbar>

        <DataTable minWidth="900px">
          <thead>
            <tr>
              <th scope="col">Applicant</th>
              <th scope="col">Type</th>
              <th scope="col">Organization</th>
              <th scope="col">License</th>
              <th scope="col">Documents</th>
              <th scope="col">Waiting</th>
              <th scope="col" className="actions"><span className="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={4} cols={COLS} />
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={UserCheck}
                    title={search ? 'No applicants match your search' : 'All clear'}
                    message={search ? 'Try a different name, license or organization.' : 'No pending applications at this time.'}
                    action={search && <Button size="sm" onClick={() => { setSearch(''); setPage(1); }}>Clear search</Button>}
                  />
                </td>
              </tr>
            ) : rows.map(r => {
              const missing = missingRequired(r);
              return (
                <tr key={r.id} className="mf-table-row" onClick={() => setSelectedResponder(r)} style={{ cursor: 'pointer' }}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                      <Avatar name={r.user?.fullName} />
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: 500, color: 'var(--text-main)' }}>{r.user?.fullName || '—'}</div>
                        <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{r.user?.email}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ whiteSpace: 'nowrap' }}>{shortType(r)}</td>
                  <td>{r.organization || <span style={{ color: 'var(--text-muted)' }}>Independent</span>}</td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap' }}>{r.licenseNumber || '—'}</td>
                  <td>
                    {missing === 0
                      ? <StatusBadge tone="success">Complete</StatusBadge>
                      : <StatusBadge tone="warning">{missing} missing</StatusBadge>}
                  </td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap', color: waitColor(r.user?.createdAt) }}>
                    {timeAgo(r.user?.createdAt)}
                  </td>
                  <td className="actions">
                    <Button size="sm" onClick={(e) => { e.stopPropagation(); setSelectedResponder(r); }} aria-label={`Review application from ${r.user?.fullName || 'applicant'}`}>
                      Review
                    </Button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </DataTable>

        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filtered.length} onChange={setPage} loading={loading} noun="applications" />
      </Panel>

      {/* ── Review drawer — opens when an applicant is selected ── */}
      {selectedResponder && !showApplication && (
        <ResponderDetailModal
          key={selectedResponder.id}
          responder={selectedResponder}
          processingId={processingId}
          onApprove={() => handleAction(selectedResponder.userId, 'VERIFY')}
          onReject={() => setShowRejectModal(true)}
          onViewApplication={() => setShowApplication(true)}
          onClose={closeDetail}
        />
      )}

      {/* ── Formal A4 Application Modal ── */}
      {showApplication && selectedResponder && (
        <ApplicationModal
          responder={selectedResponder}
          onClose={() => setShowApplication(false)}
        />
      )}

      {/* ── Rejection Reason Modal ── */}
      {showRejectModal && selectedResponder && (
        <RejectModal
          responderName={selectedResponder.user?.fullName}
          processing={!!processingId}
          onCancel={() => setShowRejectModal(false)}
          onConfirm={(reason) => handleAction(selectedResponder.userId, 'REJECT', reason)}
        />
      )}
    </>
  );
};

export default ResponderVerification;

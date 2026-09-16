import React, { useState, useEffect, useCallback } from 'react';
import { Search, Eye, CheckCircle, XCircle, Award } from 'lucide-react';
import { AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { resolveFileUrl } from '../../utils/resolveFileUrl';
import { PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SearchInput, ErrorBanner } from '../../components/ui';
import { thStyle, paginate, lightTokenCss } from '../../components/uiStyles';

/* ─── Theme (CSS tokens) ───────────────────────────────────────────────── */
const C = {
  accent:   'var(--admin-accent)',
  border:   'var(--admin-border)',
  white:    'var(--surface)',
  textMain: 'var(--admin-text-main)',
  textSub:  'var(--admin-text-sub)',
  textMuted:'var(--admin-text-muted)',
};

const RESPONDER_TYPE_LABELS = {
  RESCUE_OFFICER:  'Rescue Officer (1122)',
  PARAMEDIC:       'Paramedic',
  EMT:             'Emergency Medical Technician',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER:       'Community Volunteer',
};

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

// ─── Application Modal ─────────────────────────────────────────────────────

const ApplicationModal = ({ responder, onClose }) => {
  const submittedDate = responder.user?.createdAt
    ? new Date(responder.user.createdAt).toLocaleDateString('en-PK', { year: 'numeric', month: 'long', day: 'numeric' })
    : 'N/A';

  const handlePrint = () => {
    const printArea = document.getElementById('application-print-area');
    if (!printArea) return;

    const clone = printArea.cloneNode(true);
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
              .print-page-break {
                page-break-before: always !important;
                break-before: page !important;
              }
            }
            .header-banner { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            input, textarea {
              border: none; border-bottom: 1.5px solid var(--text-muted);
              width: 100%; padding: 4px 0; font-size: 0.875rem;
              font-family: Arial, sans-serif; background: transparent; outline: none;
            }
            ${lightTokenCss()}
          </style>
        </head>
        <body>${clone.innerHTML}</body>
      </html>
    `);
    win.document.close();
    win.focus();
    setTimeout(() => { win.print(); win.close(); }, 900);
  };

  const docs = [
    { label: 'CNIC — Front',                        url: resolveFileUrl(responder.cnicImageUrl),              required: true  },
    { label: 'CNIC — Back',                         url: resolveFileUrl(responder.cnicBackImageUrl),          required: true  },
    { label: 'Employee / Professional ID — Front',  url: resolveFileUrl(responder.employeeCardImageUrl),      required: true  },
    { label: 'Employee / Professional ID — Back',   url: resolveFileUrl(responder.employeeCardBackImageUrl),  required: false },
  ];

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 10000,
      background: 'rgba(0,0,0,0.65)', backdropFilter: 'blur(4px)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      overflowY: 'auto', padding: '2rem 1rem',
    }}>
      {/* Toolbar */}
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
            background: 'var(--primary)', color: 'white', border: 'none',
            fontWeight: 700, fontSize: '0.875rem', cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          📥 Download PDF
        </button>
        <button
          onClick={onClose}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.5rem',
            padding: '0.6rem 1.25rem', borderRadius: '10px',
            background: 'white', color: 'var(--text-sub)', border: '1px solid var(--border)',
            fontWeight: 700, fontSize: '0.875rem', cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          ✕ Close
        </button>
      </div>

      {/* Printable Form */}
      <div
        id="application-print-area"
        data-theme="light"
        style={{
          width: '100%', maxWidth: '820px',
          background: 'white', borderRadius: '16px',
          boxShadow: '0 24px 64px rgba(0,0,0,0.3)',
          overflow: 'hidden', fontFamily: 'Arial, sans-serif',
        }}
      >
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, var(--primary-dark) 0%, var(--primary) 100%)',
          padding: '2rem 2.5rem', color: 'white',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '0.7rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.7, marginBottom: '0.4rem' }}>
                MediFind Healthcare Emergency Network · Pakistan
              </div>
              <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: 0, color: 'white' }}>
                Emergency Responder Application Record
              </h1>
              <p style={{ margin: '0.35rem 0 0', opacity: 0.75, fontSize: '0.875rem', color: 'white' }}>
                Approved Responder Profile &amp; Verification Record
              </p>
            </div>
            <div style={{ textAlign: 'right', fontSize: '0.78rem', opacity: 0.85 }}>
              <div style={{ fontWeight: 700 }}>Application ID</div>
              <div style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                {responder.id?.slice(0, 8).toUpperCase() || 'N/A'}
              </div>
              <div style={{ marginTop: '0.5rem', fontWeight: 700 }}>Submitted</div>
              <div>{submittedDate}</div>
            </div>
          </div>
        </div>

        <div style={{ padding: '2rem 2.5rem' }}>
          {/* Personal Info */}
          <div style={{ marginBottom: '2rem' }}>
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
              1. Personal Information
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {[
                { label: 'Full Name', value: responder.user?.fullName || '—' },
                { label: 'Email', value: responder.user?.email || '—' },
                { label: 'Phone', value: responder.user?.phoneNumber || '—' },
                { label: 'City', value: responder.user?.city || '—' },
                { label: 'CNIC', value: responder.cnic || '—' },
                { label: 'DOB', value: responder.user?.dateOfBirth ? new Date(responder.user.dateOfBirth).toLocaleDateString('en-PK') : '—' },
              ].map((item) => (
                <div key={item.label}>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: '0.3rem' }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: '0.95rem', color: 'var(--text-main)', fontWeight: 500 }}>
                    {item.value}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Professional Credentials */}
          <div style={{ marginBottom: '2rem' }}>
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
              2. Professional Credentials
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {[
                { label: 'Type', value: RESPONDER_TYPE_LABELS[responder.responderType] || '—' },
                { label: 'License #', value: responder.licenseNumber || '—' },
                { label: 'Organization', value: responder.organization || 'Independent' },
                { label: 'Vehicle Type', value: responder.vehicleType || 'Not specified' },
              ].map((item) => (
                <div key={item.label}>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: '0.3rem' }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: '0.95rem', color: 'var(--text-main)', fontWeight: 500 }}>
                    {item.value}
                  </div>
                </div>
              ))}
            </div>
            {Array.isArray(responder.specialization) && responder.specialization.length > 0 && (
              <div style={{ marginTop: '1rem' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: '0.5rem' }}>
                  Specializations
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {responder.specialization.map((spec) => (
                    <span key={spec} style={{
                      background: 'var(--primary-pale)', color: 'var(--primary)',
                      padding: '0.25rem 0.75rem', borderRadius: '999px',
                      fontSize: '0.8rem', fontWeight: 600,
                    }}>
                      {spec}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Documents */}
          <div style={{ marginBottom: '2rem' }}>
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
              3. Documents Submitted
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem' }}>
              {docs.map(({ label, url }) => (
                <div key={label} style={{
                  border: '1.5px solid var(--border)', borderRadius: '10px',
                  overflow: 'hidden', background: 'var(--surface-alt)',
                }}>
                  <div style={{ padding: '0.5rem 0.75rem', background: 'var(--primary-pale)', fontSize: '0.8rem', fontWeight: 700 }}>
                    {label}
                  </div>
                  {url ? (
                    <div style={{ height: '120px', background: 'var(--surface-alt)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
                      📎 Document Uploaded
                    </div>
                  ) : (
                    <div style={{ height: '120px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--border)' }}>
                      Not provided
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Verification Status */}
          <div style={{
            background: 'var(--tint-green)', border: '1px solid var(--success-border)',
            borderRadius: '10px', padding: '1.25rem', marginTop: '2rem',
          }}>
            <div style={{ display: 'flex', gap: '1rem' }}>
              <div style={{ fontSize: '1.5rem' }}>✅</div>
              <div>
                <h4 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700, color: 'var(--success-fg)' }}>
                  Verified & Approved
                </h4>
                <p style={{ margin: '0.3rem 0 0', fontSize: '0.85rem', color: 'var(--success-fg)', lineHeight: 1.6 }}>
                  This responder has passed verification and is registered in the MediFind Emergency Response Network.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

/* ─── Main Component ───────────────────────────────────────────────────── */
const PAGE_SIZE = 10;

// Backend does not store a verification timestamp yet; prefer it when present.
const verifiedDate = (r) => r.verifiedAt || null;

export default function ResponderRecords() {
  const [responders, setResponders] = useState([]);
  const [activeById, setActiveById] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [selectedResponder, setSelectedResponder] = useState(null);

  const loadRecords = useCallback(() => (
    Promise.allSettled([
      api.get('/api/admin/responders/verified'),
      // /responders/verified does not include the account's isActive flag — join it from the users list
      api.get('/api/admin/users?role=RESPONDER'),
    ]).then(([verifiedR, usersR]) => {
      if (verifiedR.status === 'fulfilled') {
        setResponders(verifiedR.value.data?.data || []);
        setError('');
      } else {
        setResponders([]);
        setError(errorMessage(verifiedR.reason, 'Failed to load responder records.'));
      }
      if (usersR.status === 'fulfilled' && Array.isArray(usersR.value.data?.data)) {
        setActiveById(Object.fromEntries(usersR.value.data.data.map(u => [u.id, u.isActive !== false])));
      }
      setLoading(false);
    })
  ), []);

  useEffect(() => { loadRecords(); }, [loadRecords]);

  const refresh = () => { setLoading(true); loadRecords(); };

  const q = search.trim().toLowerCase();
  const filteredResponders = responders.filter((r) => (
    !q ||
    (r.user?.fullName || '').toLowerCase().includes(q) ||
    (r.user?.email || '').toLowerCase().includes(q) ||
    (r.licenseNumber || '').toLowerCase().includes(q) ||
    (r.organization || '').toLowerCase().includes(q)
  ));
  const { page: currentPage, rows } = paginate(filteredResponders, page, PAGE_SIZE);

  const hasActiveData = Object.keys(activeById).length > 0;
  const activeCount = responders.filter(r => activeById[r.userId ?? r.user?.id] !== false).length;
  const hasVerifiedDates = responders.some(verifiedDate);
  const now = new Date();
  const thisMonthCount = responders.filter(r => {
    const d = new Date(verifiedDate(r) || r.createdAt || r.user?.createdAt);
    return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
  }).length;

  const stats = [
    { label: 'Total Approved', value: responders.length, color: 'var(--primary-light)', hint: 'Responders with verified credentials' },
    { label: 'Active Accounts', value: hasActiveData ? activeCount : '—', color: 'var(--success)', hint: hasActiveData ? `${responders.length - activeCount} deactivated` : 'Account status unavailable' },
    { label: hasVerifiedDates ? 'Verified This Month' : 'Applied This Month', value: thisMonthCount, color: 'var(--warning)', hint: hasVerifiedDates ? 'By verification date' : 'By application date' },
  ];

  const COLS = 6;

  return (
    <>
      <PageHeader
        title="Responder Records"
        subtitle="Verified responder profiles and printable application records."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      {/* Stats Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1.25rem' }}>
        {stats.map((s) => (
          <div key={s.label} style={{ background: C.white, padding: '1.1rem 1.25rem', borderRadius: '14px', border: `1px solid ${C.border}` }}>
            <div style={{ fontSize: '0.74rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.4rem' }}>
              {s.label}
            </div>
            <div style={{ fontSize: '1.75rem', fontWeight: 800, color: s.color, lineHeight: 1.1 }}>
              {loading ? '—' : s.value}
            </div>
            <div style={{ fontSize: '0.74rem', color: C.textMuted, marginTop: '0.3rem' }}>{s.hint}</div>
          </div>
        ))}
      </div>

      {/* Table */}
      <div style={{ background: C.white, borderRadius: '16px', border: `1px solid ${C.border}`, overflow: 'hidden' }}>
        <div style={{ padding: '14px 20px', borderBottom: `1px solid ${C.border}`, display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <SearchInput
            icon={Search}
            width={360}
            value={search}
            onChange={(v) => { setSearch(v); setPage(1); }}
            placeholder="Search by name, email, license or organization…"
          />
        </div>
        <div className="mf-table-scroll">
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '820px' }}>
            <thead>
              <tr>
                {['Name & Email', 'Type', 'Organization', 'License', 'Account', 'Applied', ''].slice(0, COLS + 1).map((h, i) => (
                  <th key={h || i} scope="col" style={{ ...thStyle, textAlign: i === COLS ? 'right' : 'left' }}>{h || <span className="sr-only">Actions</span>}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <TableSkeletonRows rows={5} cols={COLS + 1} />
              ) : filteredResponders.length === 0 ? (
                <tr>
                  <td colSpan={COLS + 1}>
                    <EmptyState
                      icon={Award}
                      title={search ? 'No responders match your search' : 'No approved responders yet'}
                      message={search ? 'Try a different name, license or organization.' : 'Approved responders from the Verification Queue will appear here.'}
                    />
                  </td>
                </tr>
              ) : rows.map((r) => {
                const isActive = activeById[r.userId ?? r.user?.id];
                return (
                  <tr key={r.id} className="mf-table-row" style={{ borderBottom: `1px solid ${C.border}` }}>
                    <td style={{ padding: '12px 20px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{ width: '34px', height: '34px', borderRadius: '9px', background: 'linear-gradient(135deg,var(--primary),var(--primary-mid))', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: '0.8rem', fontWeight: 700, flexShrink: 0 }}>
                          {r.user?.fullName?.charAt(0).toUpperCase() || '?'}
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontSize: '0.88rem', fontWeight: 700, color: C.textMain }}>{r.user?.fullName || '—'}</div>
                          <div style={{ fontSize: '0.78rem', color: C.textMuted, marginTop: '0.1rem' }}>{r.user?.email || '—'}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '12px 20px' }}>
                      <span style={{ background: 'var(--tint-teal)', color: C.accent, padding: '0.25rem 0.6rem', borderRadius: '6px', fontSize: '0.76rem', fontWeight: 700, whiteSpace: 'nowrap' }}>
                        {RESPONDER_TYPE_LABELS[r.responderType]?.split('(')[0].trim() || '—'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 20px', fontSize: '0.86rem', color: C.textSub }}>{r.organization || 'Independent'}</td>
                    <td style={{ padding: '12px 20px', fontSize: '0.82rem', color: C.textSub, fontFamily: 'monospace' }}>{r.licenseNumber || '—'}</td>
                    <td style={{ padding: '12px 20px' }}>
                      {isActive === undefined ? (
                        <span style={{ fontSize: '0.8rem', color: C.textMuted }}>—</span>
                      ) : (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '0.74rem', fontWeight: 700, padding: '3px 9px', borderRadius: '6px', background: isActive ? 'var(--tint-green)' : 'var(--tint-red)', color: isActive ? 'var(--success-fg)' : 'var(--error-fg)' }}>
                          {isActive ? <CheckCircle size={11} /> : <XCircle size={11} />} {isActive ? 'Active' : 'Deactivated'}
                        </span>
                      )}
                    </td>
                    <td style={{ padding: '12px 20px', fontSize: '0.84rem', color: C.textSub, whiteSpace: 'nowrap' }}>{formatDate(r.createdAt || r.user?.createdAt)}</td>
                    <td style={{ padding: '12px 20px', textAlign: 'right' }}>
                      <button
                        type="button"
                        onClick={() => setSelectedResponder(r)}
                        aria-label={`View application record for ${r.user?.fullName || 'responder'}`}
                        style={{
                          display: 'inline-flex', alignItems: 'center', gap: '0.4rem',
                          padding: '0.45rem 0.85rem', borderRadius: '8px',
                          background: 'var(--primary-light)', color: 'white',
                          border: 'none', cursor: 'pointer',
                          fontSize: '0.8rem', fontWeight: 700, fontFamily: 'inherit',
                        }}
                      >
                        <Eye size={14} /> View record
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filteredResponders.length} onChange={setPage} loading={loading} />
      </div>

      {/* Modal */}
      <AnimatePresence>
        {selectedResponder && (
          <ApplicationModal
            responder={selectedResponder}
            onClose={() => setSelectedResponder(null)}
          />
        )}
      </AnimatePresence>
    </>
  );
}

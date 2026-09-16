import React, { useState, useEffect, useCallback } from 'react';
import { Eye, Award, Printer, Paperclip, CheckCircle2 } from 'lucide-react';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { resolveFileUrl } from '../../utils/resolveFileUrl';
import {
  PageHeader, RefreshButton, Pagination, EmptyState, TableSkeletonRows, SearchInput, ErrorBanner,
  StatCard, Panel, Toolbar, DataTable, Avatar, StatusBadge, IconButton, Button, Modal,
} from '../../components/ui';
import { paginate, lightTokenCss } from '../../components/uiStyles';

const RESPONDER_TYPE_LABELS = {
  RESCUE_OFFICER:  'Rescue Officer (1122)',
  PARAMEDIC:       'Paramedic',
  EMT:             'Emergency Medical Technician',
  FIRST_RESPONDER: 'First Responder',
  VOLUNTEER:       'Community Volunteer',
};

const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString('en-PK', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

/* Printable record styles. These are inline on purpose: the print window only
   receives the element's markup plus the light token rule (lightTokenCss). */
const P = {
  section: { marginBottom: '28px' },
  h3: { fontSize: '13px', fontWeight: 600, color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.04em', margin: '0 0 12px', paddingBottom: '8px', borderBottom: '1px solid var(--border)' },
  grid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px 24px' },
  label: { fontSize: '12px', color: 'var(--text-muted)', fontWeight: 500, marginBottom: '3px' },
  value: { fontSize: '14px', color: 'var(--text-main)', fontWeight: 500 },
};

// ─── Application record (printable) ────────────────────────────────────────

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
    <Modal
      onClose={onClose}
      title="Application record"
      description={responder.user?.fullName || undefined}
      width={860}
      bodyStyle={{ padding: 0, background: 'var(--surface-alt)' }}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Close</Button>
          <Button variant="primary" icon={Printer} onClick={handlePrint}>Download PDF</Button>
        </>
      }
    >
      {/* Printable document */}
      <div
        id="application-print-area"
        data-theme="light"
        style={{ width: '100%', background: 'white', fontFamily: 'Arial, sans-serif', color: 'var(--text-main)' }}
      >
        {/* Header */}
        <div className="header-banner" style={{ background: 'var(--primary-dark)', padding: '24px 32px', color: 'white' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '16px' }}>
            <div>
              <div style={{ fontSize: '11px', letterSpacing: '0.08em', textTransform: 'uppercase', opacity: 0.75, marginBottom: '6px' }}>
                MediFind Healthcare Emergency Network · Pakistan
              </div>
              <h1 style={{ fontSize: '20px', fontWeight: 600, margin: 0, color: 'white' }}>
                Emergency Responder Application Record
              </h1>
              <p style={{ margin: '4px 0 0', opacity: 0.8, fontSize: '13px', color: 'white' }}>
                Approved Responder Profile &amp; Verification Record
              </p>
            </div>
            <div style={{ textAlign: 'right', fontSize: '12px', opacity: 0.9 }}>
              <div style={{ fontWeight: 600 }}>Application ID</div>
              <div style={{ fontFamily: 'monospace', fontSize: '13px' }}>
                {responder.id?.slice(0, 8).toUpperCase() || 'N/A'}
              </div>
              <div style={{ marginTop: '8px', fontWeight: 600 }}>Submitted</div>
              <div>{submittedDate}</div>
            </div>
          </div>
        </div>

        <div style={{ padding: '28px 32px' }}>
          {/* Personal Info */}
          <div style={P.section}>
            <h3 style={P.h3}>1. Personal Information</h3>
            <div style={P.grid}>
              {[
                { label: 'Full Name', value: responder.user?.fullName || '—' },
                { label: 'Email', value: responder.user?.email || '—' },
                { label: 'Phone', value: responder.user?.phoneNumber || '—' },
                { label: 'City', value: responder.user?.city || '—' },
                { label: 'CNIC', value: responder.cnic || '—' },
                { label: 'DOB', value: responder.user?.dateOfBirth ? new Date(responder.user.dateOfBirth).toLocaleDateString('en-PK') : '—' },
              ].map((item) => (
                <div key={item.label}>
                  <div style={P.label}>{item.label}</div>
                  <div style={P.value}>{item.value}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Professional Credentials */}
          <div style={P.section}>
            <h3 style={P.h3}>2. Professional Credentials</h3>
            <div style={P.grid}>
              {[
                { label: 'Type', value: RESPONDER_TYPE_LABELS[responder.responderType] || '—' },
                { label: 'License #', value: responder.licenseNumber || '—' },
                { label: 'Organization', value: responder.organization || 'Independent' },
                { label: 'Vehicle Type', value: responder.vehicleType || 'Not specified' },
              ].map((item) => (
                <div key={item.label}>
                  <div style={P.label}>{item.label}</div>
                  <div style={P.value}>{item.value}</div>
                </div>
              ))}
            </div>
            {Array.isArray(responder.specialization) && responder.specialization.length > 0 && (
              <div style={{ marginTop: '14px' }}>
                <div style={{ ...P.label, marginBottom: '6px' }}>Specializations</div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  {responder.specialization.map((spec) => (
                    <span key={spec} style={{
                      background: 'var(--surface-alt)', color: 'var(--text-sub)', border: '1px solid var(--border)',
                      padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 500,
                    }}>
                      {spec}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Documents */}
          <div style={P.section}>
            <h3 style={P.h3}>3. Documents Submitted</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '12px' }}>
              {docs.map(({ label, url }) => (
                <div key={label} style={{ border: '1px solid var(--border)', borderRadius: '8px', overflow: 'hidden' }}>
                  <div style={{ padding: '8px 12px', background: 'var(--surface-alt)', borderBottom: '1px solid var(--border)', fontSize: '12.5px', fontWeight: 600, color: 'var(--text-sub)' }}>
                    {label}
                  </div>
                  <div style={{ height: '96px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', fontSize: '13px', color: 'var(--text-muted)' }}>
                    {url ? <><Paperclip size={14} aria-hidden="true" /> Document uploaded</> : 'Not provided'}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Verification Status */}
          <div style={{
            background: 'var(--success-bg)', border: '1px solid var(--success-border)',
            borderRadius: '8px', padding: '14px 16px', display: 'flex', gap: '12px', alignItems: 'flex-start',
          }}>
            <CheckCircle2 size={18} color="var(--success-fg)" aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }} />
            <div>
              <h4 style={{ margin: 0, fontSize: '14px', fontWeight: 600, color: 'var(--success-fg)' }}>
                Verified &amp; Approved
              </h4>
              <p style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--success-fg)', lineHeight: 1.6 }}>
                This responder has passed verification and is registered in the MediFind Emergency Response Network.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Modal>
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
    { label: 'Total approved', value: responders.length, hint: 'Responders with verified credentials' },
    { label: 'Active accounts', value: hasActiveData ? activeCount : '—', hint: hasActiveData ? `${responders.length - activeCount} deactivated` : 'Account status unavailable' },
    { label: hasVerifiedDates ? 'Verified this month' : 'Applied this month', value: thisMonthCount, hint: hasVerifiedDates ? 'By verification date' : 'By application date' },
  ];

  const COLS = 7;

  return (
    <>
      <PageHeader
        title="Responder Records"
        description="Verified responder profiles and printable application records."
        actions={<RefreshButton onClick={refresh} loading={loading} />}
      />

      <ErrorBanner onRetry={refresh}>{error}</ErrorBanner>

      <div className="mf-grid-stats" style={{ marginBottom: '16px' }}>
        {stats.map((s) => (
          <StatCard key={s.label} label={s.label} value={s.value} hint={s.hint} loading={loading} />
        ))}
      </div>

      <Panel>
        <Toolbar>
          <SearchInput
            width={360}
            value={search}
            onChange={(v) => { setSearch(v); setPage(1); }}
            placeholder="Search by name, email, license or organization…"
          />
        </Toolbar>

        <DataTable minWidth="860px">
          <thead>
            <tr>
              <th scope="col">Responder</th>
              <th scope="col">Type</th>
              <th scope="col">Organization</th>
              <th scope="col">License</th>
              <th scope="col">Account</th>
              <th scope="col">Applied</th>
              <th scope="col" className="actions"><span className="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSkeletonRows rows={5} cols={COLS} />
            ) : filteredResponders.length === 0 ? (
              <tr>
                <td colSpan={COLS}>
                  <EmptyState
                    icon={Award}
                    title={search ? 'No responders match your search' : 'No approved responders yet'}
                    message={search ? 'Try a different name, license or organization.' : 'Approved responders from the Verification Queue will appear here.'}
                    action={search && <Button size="sm" onClick={() => { setSearch(''); setPage(1); }}>Clear search</Button>}
                  />
                </td>
              </tr>
            ) : rows.map((r) => {
              const isActive = activeById[r.userId ?? r.user?.id];
              return (
                <tr key={r.id} className="mf-table-row">
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                      <Avatar name={r.user?.fullName} />
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: 500, color: 'var(--text-main)' }}>{r.user?.fullName || '—'}</div>
                        <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{r.user?.email || '—'}</div>
                      </div>
                    </div>
                  </td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    {RESPONDER_TYPE_LABELS[r.responderType]?.split('(')[0].trim() || '—'}
                  </td>
                  <td>{r.organization || 'Independent'}</td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap' }}>{r.licenseNumber || '—'}</td>
                  <td>
                    {isActive === undefined ? (
                      <span style={{ color: 'var(--text-muted)' }}>—</span>
                    ) : (
                      <StatusBadge tone={isActive ? 'success' : 'neutral'}>{isActive ? 'Active' : 'Deactivated'}</StatusBadge>
                    )}
                  </td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap', color: 'var(--text-muted)' }}>{formatDate(r.createdAt || r.user?.createdAt)}</td>
                  <td className="actions">
                    <IconButton
                      icon={Eye}
                      label="View record"
                      aria-label={`View application record for ${r.user?.fullName || 'responder'}`}
                      onClick={() => setSelectedResponder(r)}
                    />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </DataTable>

        <Pagination page={currentPage} pageSize={PAGE_SIZE} total={filteredResponders.length} onChange={setPage} loading={loading} noun="responders" />
      </Panel>

      {selectedResponder && (
        <ApplicationModal
          responder={selectedResponder}
          onClose={() => setSelectedResponder(null)}
        />
      )}
    </>
  );
}

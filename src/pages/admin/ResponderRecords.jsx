import React, { useState, useEffect, useCallback } from 'react';
import { FileText, Search, Download, Eye, RefreshCw, CheckCircle, Award, Calendar, Phone, Mail, Printer } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api from '../../services/api';
import { resolveFileUrl } from '../../utils/resolveFileUrl';

/* ─── Theme ────────────────────────────────────────────────────────────── */
const C = {
  accent:   '#2891C2',
  border:   '#E4EEF3',
  bg:       '#F3F7FA',
  white:    '#FFFFFF',
  textMain: '#0F1A22',
  textSub:  '#3D5360',
  textMuted:'#7A96A3',
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
            background: '#0C637E', color: 'white', border: 'none',
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
            background: 'white', color: '#374151', border: '1px solid #d1d5db',
            fontWeight: 700, fontSize: '0.875rem', cursor: 'pointer', fontFamily: 'inherit',
          }}
        >
          ✕ Close
        </button>
      </div>

      {/* Printable Form */}
      <div
        id="application-print-area"
        style={{
          width: '100%', maxWidth: '820px',
          background: 'white', borderRadius: '16px',
          boxShadow: '0 24px 64px rgba(0,0,0,0.3)',
          overflow: 'hidden', fontFamily: 'Arial, sans-serif',
        }}
      >
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #03293C 0%, #0C637E 100%)',
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
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: '#0C637E', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
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
                  <div style={{ fontSize: '0.75rem', color: '#6B7280', fontWeight: 600, marginBottom: '0.3rem' }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: '0.95rem', color: '#111827', fontWeight: 500 }}>
                    {item.value}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Professional Credentials */}
          <div style={{ marginBottom: '2rem' }}>
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: '#0C637E', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
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
                  <div style={{ fontSize: '0.75rem', color: '#6B7280', fontWeight: 600, marginBottom: '0.3rem' }}>
                    {item.label}
                  </div>
                  <div style={{ fontSize: '0.95rem', color: '#111827', fontWeight: 500 }}>
                    {item.value}
                  </div>
                </div>
              ))}
            </div>
            {Array.isArray(responder.specialization) && responder.specialization.length > 0 && (
              <div style={{ marginTop: '1rem' }}>
                <div style={{ fontSize: '0.75rem', color: '#6B7280', fontWeight: 600, marginBottom: '0.5rem' }}>
                  Specializations
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {responder.specialization.map((spec) => (
                    <span key={spec} style={{
                      background: '#EEF5F8', color: '#0C637E',
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
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: '#0C637E', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '1rem' }}>
              3. Documents Submitted
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem' }}>
              {docs.map(({ label, url }) => (
                <div key={label} style={{
                  border: '1.5px solid #D8ECF2', borderRadius: '10px',
                  overflow: 'hidden', background: '#F7FAFB',
                }}>
                  <div style={{ padding: '0.5rem 0.75rem', background: '#EEF5F8', fontSize: '0.8rem', fontWeight: 700 }}>
                    {label}
                  </div>
                  {url ? (
                    <div style={{ height: '120px', background: '#f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#9CA3AF' }}>
                      📎 Document Uploaded
                    </div>
                  ) : (
                    <div style={{ height: '120px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#D1D5DB' }}>
                      Not provided
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Verification Status */}
          <div style={{
            background: '#D1FAE5', border: '1px solid #6EE7B7',
            borderRadius: '10px', padding: '1.25rem', marginTop: '2rem',
          }}>
            <div style={{ display: 'flex', gap: '1rem' }}>
              <div style={{ fontSize: '1.5rem' }}>✅</div>
              <div>
                <h4 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700, color: '#065F46' }}>
                  Verified & Approved
                </h4>
                <p style={{ margin: '0.3rem 0 0', fontSize: '0.85rem', color: '#047857', lineHeight: 1.6 }}>
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
export default function ResponderRecords() {
  const [responders, setResponders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedResponder, setSelectedResponder] = useState(null);
  const [showModal, setShowModal] = useState(false);

  const fetchApprovedResponders = useCallback(async () => {
    try {
      setLoading(true);
      const response = await api.get('/api/admin/responders/verified');
      setResponders(response.data.data || []);
    } catch (error) {
      console.error('Failed to fetch verified responders:', error);
      setResponders([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchApprovedResponders();
  }, [fetchApprovedResponders]);

  const filteredResponders = responders.filter((r) => {
    const q = search.toLowerCase();
    return (
      (r.user?.fullName || '').toLowerCase().includes(q) ||
      (r.user?.email || '').toLowerCase().includes(q) ||
      (r.licenseNumber || '').toLowerCase().includes(q) ||
      (r.organization || '').toLowerCase().includes(q)
    );
  });

  const handleViewApplication = (responder) => {
    setSelectedResponder(responder);
    setShowModal(true);
  };

  return (
    <>
      {/* Header */}
      <div style={{ marginBottom: '1.5rem' }}>
        <h2 style={{ margin: '0 0 0.5rem', fontSize: '1.5rem', fontWeight: 800, color: C.textMain }}>
          Responder Records
        </h2>
        <p style={{ margin: 0, fontSize: '0.95rem', color: C.textMuted }}>
          Complete verified responder records and credentials
        </p>
      </div>

      {/* Search + Refresh */}
      <div style={{
        display: 'flex', gap: '0.75rem', marginBottom: '1.5rem',
        background: C.white, padding: '1rem', borderRadius: '10px',
        border: `1px solid ${C.border}`,
      }}>
        <Search size={18} style={{ color: C.textMuted, flexShrink: 0, marginTop: '0.25rem' }} />
        <input
          type="text"
          placeholder="Search by name, email, license, or organization..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            flex: 1, border: 'none', outline: 'none', fontSize: '0.9rem',
            fontFamily: 'inherit', background: 'transparent', color: C.textMain,
          }}
        />
        <button
          onClick={() => fetchApprovedResponders()}
          title="Refresh"
          style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: C.accent, padding: '0.5rem', flexShrink: 0,
          }}
        >
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Stats Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem', marginBottom: '1.5rem' }}>
        {[
          { label: 'Total Approved', value: responders.length, color: C.accent },
          { label: 'Active', value: responders.filter(r => r.isVerified).length, color: '#10B981' },
          { label: 'This Month', value: responders.filter(r => {
            const d = new Date(r.user?.createdAt);
            const n = new Date();
            return d.getMonth() === n.getMonth() && d.getFullYear() === n.getFullYear();
          }).length, color: '#F59E0B' },
        ].map((s) => (
          <div key={s.label} style={{
            background: C.white, padding: '1.25rem', borderRadius: '10px',
            border: `1px solid ${C.border}`,
          }}>
            <div style={{ fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.5rem' }}>
              {s.label}
            </div>
            <div style={{ fontSize: '1.875rem', fontWeight: 800, color: s.color }}>
              {s.value}
            </div>
          </div>
        ))}
      </div>

      {/* Table */}
      <div style={{ background: C.white, borderRadius: '10px', border: `1px solid ${C.border}`, overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '2rem', textAlign: 'center', color: C.textMuted }}>
            Loading responder records...
          </div>
        ) : filteredResponders.length === 0 ? (
          <div style={{ padding: '2rem', textAlign: 'center', color: C.textMuted }}>
            {search ? 'No responders match your search' : 'No approved responders yet'}
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ borderBottom: `1px solid ${C.border}`, background: C.bg }}>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Name & Email</th>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Type</th>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Organization</th>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>License</th>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Verified</th>
                  <th style={{ padding: '1rem', textAlign: 'left', fontSize: '0.75rem', fontWeight: 700, color: C.textMuted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredResponders.map((r) => (
                  <tr
                    key={r.id}
                    style={{
                      borderBottom: `1px solid ${C.border}`,
                      transition: 'background 0.15s',
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = C.bg}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                  >
                    <td style={{ padding: '1rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{ width: '32px', height: '32px', borderRadius: '6px', background: C.accent, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: '0.75rem', fontWeight: 700, flexShrink: 0 }}>
                          {r.user?.fullName?.charAt(0).toUpperCase() || '?'}
                        </div>
                        <div>
                          <div style={{ fontSize: '0.9rem', fontWeight: 600, color: C.textMain }}>{r.user?.fullName || '—'}</div>
                          <div style={{ fontSize: '0.8rem', color: C.textMuted, marginTop: '0.2rem' }}>{r.user?.email || '—'}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '1rem', fontSize: '0.9rem', color: C.textMain }}>
                      <span style={{ background: '#EEF5F8', color: '#0C637E', padding: '0.3rem 0.6rem', borderRadius: '4px', fontSize: '0.8rem', fontWeight: 600 }}>
                        {RESPONDER_TYPE_LABELS[r.responderType]?.split('(')[0].trim() || '—'}
                      </span>
                    </td>
                    <td style={{ padding: '1rem', fontSize: '0.9rem', color: C.textSub }}>{r.organization || 'Independent'}</td>
                    <td style={{ padding: '1rem', fontSize: '0.85rem', color: C.textSub, fontFamily: 'monospace' }}>{r.licenseNumber || '—'}</td>
                    <td style={{ padding: '1rem', fontSize: '0.9rem', color: C.textSub }}>{formatDate(r.user?.createdAt)}</td>
                    <td style={{ padding: '1rem' }}>
                      <button
                        onClick={() => handleViewApplication(r)}
                        style={{
                          display: 'inline-flex', alignItems: 'center', gap: '0.4rem',
                          padding: '0.5rem 0.875rem', borderRadius: '6px',
                          background: C.accent, color: 'white',
                          border: 'none', cursor: 'pointer',
                          fontSize: '0.8rem', fontWeight: 600,
                          fontFamily: 'inherit', transition: 'opacity 0.15s',
                        }}
                        onMouseEnter={(e) => e.currentTarget.style.opacity = '0.8'}
                        onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
                      >
                        <Eye size={14} /> View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal */}
      <AnimatePresence>
        {showModal && selectedResponder && (
          <ApplicationModal
            responder={selectedResponder}
            onClose={() => setShowModal(false)}
          />
        )}
      </AnimatePresence>
    </>
  );
}

import React, { useState, useEffect, useCallback } from 'react';
import {
  Bell, Send, Shield, Clock, AlertTriangle,
  CheckCircle, Search,
  Eye, Smartphone, Mail, Zap, RotateCcw, X,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAlert } from '../../context/hooks';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import { PageHeader, Pagination, EmptyState, TableSkeletonRows } from '../../components/ui';
import { paginate } from '../../components/uiStyles';

// Uses CSS vars so badges adapt automatically in dark mode
const PRIORITY_COLORS = {
  NORMAL:   'var(--s-resolved)',
  HIGH:     'var(--s-pending)',
  CRITICAL: 'var(--s-active)',
};

const inputStyle = {
  width: '100%',
  padding: '0.875rem 1.25rem',
  borderRadius: '12px',
  border: '1px solid var(--input-border)',
  background: 'var(--input-bg)',
  color: 'var(--text-main)',
  fontSize: '0.95rem',
  outline: 'none',
  fontFamily: 'var(--font-sans)',
  transition: 'border-color 0.2s, box-shadow 0.2s',
};

const RECIPIENT_LABELS = { ALL: 'all users', PATIENTS: 'all patients', RESPONDERS: 'all responders', CAREGIVERS: 'all caregivers' };
const CHANNEL_LABELS = { IN_APP: 'in-app', PUSH: 'push', EMAIL: 'email' };

const SystemNotifications = () => {
  const { showAlert, showConfirm } = useAlert();
  const [sending, setSending] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [aiPrompt, setAiPrompt] = useState('');
  const [activeTab, setActiveTab] = useState('COMPOSE');

  const [formData, setFormData] = useState({
    recipientType: 'ALL',
    targetId: '',
    title: '',
    body: '',
    priority: 'NORMAL',
    channels: ['IN_APP'],
  });

  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [historySearch, setHistorySearch] = useState('');
  const [selectedHistoryDetail, setSelectedHistoryDetail] = useState(null);

  // Pagination state (Broadcast History)
  const [page, setPage] = useState(1);
  const itemsPerPage = 10;

  const handleChannelToggle = (channel) => {
    setFormData(prev => ({
      ...prev,
      channels: prev.channels.includes(channel)
        ? prev.channels.filter(c => c !== channel)
        : [...prev.channels, channel],
    }));
  };

  const handleAIGenerate = async () => {
    if (!aiPrompt.trim()) { showAlert('Please enter a prompt for the AI', 'warning'); return; }
    setIsGenerating(true);
    try {
      const res = await api.post('/api/admin/generate-draft', { prompt: aiPrompt });
      if (res.data.success) {
        setFormData(prev => ({ ...prev, title: res.data.data.title, body: res.data.data.body }));
        showAlert('Draft generated successfully', 'success');
        setAiPrompt('');
      }
    } catch {
      showAlert('Failed to generate AI draft. Ensure API key is configured.', 'error');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleSend = async (e) => {
    e.preventDefault();
    if (!formData.title || !formData.body) { showAlert('Title and body are required', 'error'); return; }
    if (formData.channels.length === 0) { showAlert('Select at least one notification channel', 'error'); return; }
    if (formData.recipientType === 'INDIVIDUAL' && !formData.targetId.trim()) {
      showAlert('Please enter the target email address for individual notification', 'error');
      return;
    }

    setSending(true);
    try {
      const res = await api.post('/api/notifications/broadcast', formData);
      if (res.data.success) {
        showAlert('Notification broadcasted successfully', 'success');
        setFormData({ recipientType: 'ALL', targetId: '', title: '', body: '', priority: 'NORMAL', channels: ['IN_APP'] });
        setActiveTab('HISTORY');
        fetchHistory();
      }
    } catch (err) {
      showAlert(errorMessage(err, 'Failed to send notification'), 'error');
    } finally {
      setSending(false);
    }
  };

  const confirmAndSend = (e) => {
    e.preventDefault();
    if (!formData.title || !formData.body) { showAlert('Title and body are required', 'error'); return; }
    if (formData.channels.length === 0) { showAlert('Select at least one notification channel', 'error'); return; }
    if (formData.recipientType === 'INDIVIDUAL' && !formData.targetId.trim()) {
      showAlert('Please enter the target email address for individual notification', 'error');
      return;
    }
    const audience = formData.recipientType === 'INDIVIDUAL'
      ? formData.targetId.trim()
      : RECIPIENT_LABELS[formData.recipientType] || formData.recipientType;
    showConfirm({
      title: 'Send this broadcast?',
      message: `"${formData.title}" will be sent to ${audience} via ${formData.channels.map(c => CHANNEL_LABELS[c] || c).join(', ')}. Sent notifications cannot be recalled.`,
      type: formData.priority === 'CRITICAL' ? 'warning' : 'info',
      confirmLabel: 'Send now',
      onConfirm: () => handleSend(e),
    });
  };

  const fetchHistory = useCallback(async () => {
    try {
      const res = await api.get('/api/notifications/admin-history?limit=100');
      if (res.data.success) {
        const mapped = res.data.data.map((n) => {
          const group = n.recipientGroup || 'ALL';
          let recipientLabel = group;
          if (group.startsWith('individual:')) {
            recipientLabel = group.replace('individual:', '');
          } else {
            const labelMap = { ALL: 'All Users', PATIENT: 'All Patients', RESPONDER: 'All Responders', CAREGIVER: 'All Caregivers' };
            recipientLabel = labelMap[group] || group;
          }
          return { id: n.id, title: n.title, body: n.body, recipient: recipientLabel, timestamp: n.createdAt, status: n.status, priority: n.priority || 'NORMAL' };
        });
        setHistory(mapped);
      }
    } catch (err) {
      console.error('Failed to fetch admin broadcast history:', err);
    } finally {
      setHistoryLoading(false);
    }
  }, []);

  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  const hq = historySearch.trim().toLowerCase();
  const filteredHistory = history.filter(item =>
    !hq ||
    String(item.title || '').toLowerCase().includes(hq) ||
    String(item.recipient || '').toLowerCase().includes(hq) ||
    String(item.body || '').toLowerCase().includes(hq)
  );

  const { page: currentPage, rows: historyRows } = paginate(filteredHistory, page, itemsPerPage);
  const setCurrentPage = setPage;
  const lastBroadcast = history[0]?.timestamp;

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
    >
      {/* ── Header ── */}
      <PageHeader
        title="System Notifications"
        subtitle="Broadcast alerts to users and review what has been sent."
        actions={(
        <div role="tablist" aria-label="Notification views" style={{
          display: 'flex', gap: '0.375rem',
          background: 'var(--surface-raised)',
          border: '1px solid var(--border)',
          padding: '0.35rem', borderRadius: '12px',
        }}>
          {[
            { id: 'COMPOSE', label: 'Compose', Icon: Send },
            { id: 'HISTORY', label: `History${history.length ? ` (${history.length})` : ''}`, Icon: Clock },
          ].map(tab => (
            <button
              key={tab.id}
              type="button"
              role="tab"
              aria-selected={activeTab === tab.id}
              onClick={() => { setActiveTab(tab.id); setPage(1); }}
              style={{
                display: 'flex', alignItems: 'center', gap: '0.5rem',
                padding: '0.55rem 1.125rem', borderRadius: '8px', border: 'none',
                background: activeTab === tab.id ? 'var(--surface)' : 'transparent',
                color: activeTab === tab.id ? 'var(--primary)' : 'var(--text-muted)',
                fontWeight: 700, fontSize: '0.84rem', cursor: 'pointer',
                fontFamily: 'var(--font-sans)',
                boxShadow: activeTab === tab.id ? 'var(--shadow-soft)' : 'none',
                transition: 'all 0.2s',
              }}
            >
              <tab.Icon size={15} /> {tab.label}
            </button>
          ))}
        </div>
        )}
      />

      <div className={activeTab === 'COMPOSE' ? 'mf-grid-main-side mf-compose-grid' : undefined} style={{ gap: '1.5rem' }}>

        {/* ── Main Area ── */}
        <AnimatePresence mode="wait">

          {/* COMPOSE TAB */}
          {activeTab === 'COMPOSE' && (
            <motion.div
              key="compose"
              initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }}
              className="card"
              style={{ padding: '2.25rem', border: '1px solid var(--border)', background: 'var(--surface)' }}
            >
              <h2 style={{ fontSize: '1.1rem', fontWeight: 700, color: 'var(--text-sub)', marginBottom: '1.75rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <Send size={18} style={{ color: 'var(--primary)' }} /> Broadcast New Alert
              </h2>

              {/* AI Drafter */}
              <div style={{
                background: 'var(--surface-raised)',
                border: '1px dashed var(--border)',
                padding: '1.375rem', borderRadius: '14px', marginBottom: '1.75rem',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.875rem' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.875rem', fontWeight: 700, color: 'var(--text-sub)' }}>
                    <Zap size={15} style={{ color: 'var(--primary)' }} /> AI Assistant Drafter
                  </label>
                  <span style={{
                    fontSize: '0.7rem', color: 'var(--text-muted)',
                    background: 'var(--input-bg-alt)', border: '1px solid var(--border)',
                    padding: '0.2rem 0.6rem', borderRadius: '6px', fontWeight: 600,
                  }}>
                    Human-in-the-Loop
                  </span>
                </div>
                <div style={{ display: 'flex', gap: '0.875rem' }}>
                  <input
                    type="text"
                    placeholder="e.g. 'Remind responders to renew licenses by Friday'"
                    value={aiPrompt}
                    onChange={(e) => setAiPrompt(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleAIGenerate())}
                    style={{ ...inputStyle, padding: '0.8rem 1.125rem' }}
                  />
                  <button
                    type="button" onClick={handleAIGenerate} disabled={isGenerating}
                    style={{
                      padding: '0 1.25rem', borderRadius: '10px',
                      background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                      color: 'white', fontWeight: 700, fontSize: '0.875rem',
                      border: 'none', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', gap: '0.5rem',
                      opacity: isGenerating ? 0.72 : 1, whiteSpace: 'nowrap',
                      fontFamily: 'var(--font-sans)',
                    }}
                  >
                    {isGenerating ? <RotateCcw size={15} /> : '✨'} Generate
                  </button>
                </div>
                <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.75rem' }}>
                  AI drafts a professional title and body. Review before broadcasting.
                </p>
              </div>

              <form onSubmit={confirmAndSend}>
                {/* Recipient + Priority */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.25rem', marginBottom: '1.25rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Recipient Group
                    </label>
                    <select
                      value={formData.recipientType}
                      onChange={(e) => setFormData({ ...formData, recipientType: e.target.value })}
                      style={inputStyle}
                    >
                      <option value="ALL">All Users</option>
                      <option value="PATIENTS">All Patients</option>
                      <option value="RESPONDERS">All Responders</option>
                      <option value="CAREGIVERS">All Caregivers</option>
                      <option value="INDIVIDUAL">Specific User (Email or ID)</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Priority Level
                    </label>
                    <select
                      value={formData.priority}
                      onChange={(e) => setFormData({ ...formData, priority: e.target.value })}
                      style={inputStyle}
                    >
                      <option value="NORMAL">Normal</option>
                      <option value="HIGH">High</option>
                      <option value="CRITICAL">Critical</option>
                    </select>
                  </div>
                </div>

                {/* Target User (INDIVIDUAL) */}
                {formData.recipientType === 'INDIVIDUAL' && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} style={{ marginBottom: '1.25rem' }}>
                    <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Target User Email or ID
                    </label>
                    <input
                      type="text"
                      placeholder="user@example.com or cuid..."
                      value={formData.targetId}
                      onChange={(e) => setFormData({ ...formData, targetId: e.target.value })}
                      style={inputStyle}
                    />
                  </motion.div>
                )}

                {/* Title */}
                <div style={{ marginBottom: '1.25rem' }}>
                  <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Notification Title
                  </label>
                  <input
                    type="text"
                    placeholder="Brief headline..."
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    style={inputStyle}
                  />
                </div>

                {/* Body */}
                <div style={{ marginBottom: '1.75rem' }}>
                  <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.625rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Message Body
                  </label>
                  <textarea
                    placeholder="Full details of the alert..."
                    rows={4}
                    value={formData.body}
                    onChange={(e) => setFormData({ ...formData, body: e.target.value })}
                    style={{ ...inputStyle, resize: 'vertical' }}
                  />
                </div>

                {/* Channels */}
                <div style={{ marginBottom: '2rem' }}>
                  <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '0.875rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Dispatch Channels
                  </label>
                  <div style={{ display: 'flex', gap: '0.875rem' }}>
                    {[
                      { id: 'IN_APP', label: 'In-App', Icon: Bell, color: 'var(--primary)' },
                      { id: 'PUSH', label: 'Push', Icon: Smartphone, color: 'var(--primary-mid)' },
                      { id: 'EMAIL', label: 'Email Copy', Icon: Mail, color: 'var(--s-pending)' },
                    ].map(ch => {
                      const active = formData.channels.includes(ch.id);
                      return (
                        <button
                          key={ch.id}
                          type="button"
                          onClick={() => handleChannelToggle(ch.id)}
                          style={{
                            flex: 1, display: 'flex', alignItems: 'center', gap: '0.625rem',
                            padding: '0.875rem', borderRadius: '12px',
                            border: `1.5px solid ${active ? ch.color : 'var(--border)'}`,
                            background: active ? 'var(--primary-pale)' : 'var(--surface-raised)',
                            cursor: 'pointer', transition: 'all 0.18s ease',
                            fontFamily: 'var(--font-sans)',
                          }}
                        >
                          <ch.Icon size={18} style={{ color: active ? ch.color : 'var(--text-muted)', flexShrink: 0 }} />
                          <span style={{ fontSize: '0.82rem', fontWeight: 700, color: active ? 'var(--text-sub)' : 'var(--text-muted)' }}>
                            {ch.label}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Submit */}
                <button
                  type="submit" disabled={sending}
                  style={{
                    width: '100%', padding: '1rem', borderRadius: '14px',
                    background: 'linear-gradient(135deg, var(--grad-start), var(--grad-end))',
                    color: 'white', fontWeight: 800, fontSize: '0.95rem',
                    border: 'none', cursor: sending ? 'not-allowed' : 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.625rem',
                    opacity: sending ? 0.72 : 1, transition: 'all 0.2s',
                    fontFamily: 'var(--font-sans)',
                    boxShadow: sending ? 'none' : '0 4px 16px rgba(12,99,126,0.28)',
                  }}
                >
                  {sending ? <RotateCcw size={18} /> : <Zap size={18} />}
                  {sending ? 'Dispatching…' : 'Broadcast Notification Now'}
                </button>
              </form>
            </motion.div>
          )}

          {/* HISTORY TAB */}
          {activeTab === 'HISTORY' && (
            <motion.div
              key="history"
              initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 20 }}
              className="card"
              style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border)', background: 'var(--surface)' }}
            >
              <div style={{
                padding: '1.25rem 1.75rem',
                borderBottom: '1px solid var(--border)',
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              }}>
                <h2 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-sub)' }}>
                  Broadcast History
                </h2>
                <div style={{ position: 'relative' }}>
                  <Search size={13} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    placeholder="Search logs..."
                    value={historySearch}
                    onChange={(e) => { setHistorySearch(e.target.value); setPage(1); }}
                    style={{ ...inputStyle, width: '200px', padding: '0.45rem 1rem 0.45rem 2.125rem', fontSize: '0.8rem', borderRadius: '8px' }}
                  />
                </div>
              </div>

              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                  <thead>
                    <tr style={{ background: 'var(--surface-raised)', borderBottom: '1px solid var(--border)' }}>
                      {['Alert Title', 'Recipients', 'Priority', 'Status', 'Sent At', ''].map(h => (
                        <th key={h} style={{ padding: '0.875rem 1.5rem', fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.06em', whiteSpace: 'nowrap' }}>
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {historyLoading ? (
                      <TableSkeletonRows rows={4} cols={6} />
                    ) : filteredHistory.length === 0 ? (
                      <tr>
                        <td colSpan={6}>
                          <EmptyState
                            icon={Bell}
                            title={historySearch ? 'No broadcasts match your search' : 'No broadcasts yet'}
                            message={historySearch ? undefined : 'Messages you send from the Compose tab will appear here.'}
                          />
                        </td>
                      </tr>
                    ) : historyRows.map((item) => (
                      <tr
                        key={item.id}
                        className="mf-table-row"
                        style={{ borderBottom: '1px solid var(--border)' }}
                      >
                        <td style={{ padding: '1.125rem 1.5rem' }}>
                          <p style={{ fontSize: '0.875rem', fontWeight: 700, color: 'var(--text-sub)', margin: 0, marginBottom: '0.2rem' }}>{item.title}</p>
                          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', margin: 0, maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {item.body}
                          </p>
                        </td>
                        <td style={{ padding: '1.125rem 1.5rem' }}>
                          <span style={{
                            fontSize: '0.72rem', fontWeight: 700,
                            color: 'var(--primary)',
                            background: 'var(--primary-pale)',
                            padding: '0.3rem 0.75rem', borderRadius: '6px',
                            whiteSpace: 'nowrap',
                          }}>
                            {item.recipient}
                          </span>
                        </td>
                        <td style={{ padding: '1.125rem 1.5rem' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', color: PRIORITY_COLORS[item.priority] }}>
                            <AlertTriangle size={13} />
                            <span style={{ fontSize: '0.72rem', fontWeight: 700 }}>{item.priority}</span>
                          </div>
                        </td>
                        <td style={{ padding: '1.125rem 1.5rem' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', color: 'var(--s-resolved)' }}>
                            <CheckCircle size={13} />
                            <span style={{ fontSize: '0.72rem', fontWeight: 700 }}>{item.status}</span>
                          </div>
                        </td>
                        <td style={{ padding: '1.125rem 1.5rem', fontSize: '0.78rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                          {new Date(item.timestamp).toLocaleDateString()}
                          <br />
                          <span style={{ opacity: 0.65 }}>{new Date(item.timestamp).toLocaleTimeString()}</span>
                        </td>
                        <td style={{ padding: '1.125rem 1.5rem' }}>
                          <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
                            <button
                              type="button"
                              onClick={() => setSelectedHistoryDetail(item)}
                              aria-label={`View broadcast "${item.title}"`}
                              title="View details"
                              style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '0.4rem 0.7rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--surface-raised)', color: 'var(--text-sub)', cursor: 'pointer', fontSize: '0.76rem', fontWeight: 700, fontFamily: 'inherit' }}
                            >
                              <Eye size={13} /> View
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <Pagination page={currentPage} pageSize={itemsPerPage} total={filteredHistory.length} onChange={setCurrentPage} loading={historyLoading} />
            </motion.div>
          )}

          {/* TEMPLATES TAB REMOVED */}
        </AnimatePresence>

        {/* ── Compose Sidebar ── */}
        {activeTab === 'COMPOSE' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.375rem' }}>
            {/* Network Safety Card */}
            <div className="card" style={{
              padding: '1.75rem',
              border: '1px solid var(--border)',
              background: 'linear-gradient(135deg, var(--primary), var(--primary-mid))',
              color: 'white',
            }}>
              <h3 style={{ fontSize: '0.975rem', fontWeight: 700, marginBottom: '0.875rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Shield size={17} /> Network Safety
              </h3>
              <p style={{ fontSize: '0.82rem', opacity: 0.88, lineHeight: 1.6, marginBottom: '1.25rem' }}>
                All notifications are logged for HIPAA compliance auditing. Ensure messages containing PHI are sent via secure channels only.
              </p>
              <div style={{ display: 'flex', gap: '0.75rem' }}>
                {[
                  { label: 'Broadcasts sent', val: historyLoading ? '—' : history.length },
                  { label: 'Last broadcast', val: historyLoading ? '—' : (lastBroadcast ? new Date(lastBroadcast).toLocaleDateString('en-PK', { day: '2-digit', month: 'short' }) : 'Never') },
                ].map(s => (
                  <div key={s.label} style={{ flex: 1, padding: '0.75rem', background: 'rgba(255,255,255,0.12)', borderRadius: '10px', textAlign: 'center' }}>
                    <p style={{ fontSize: '0.62rem', fontWeight: 800, textTransform: 'uppercase', opacity: 0.72, marginBottom: '2px' }}>{s.label}</p>
                    <p style={{ fontSize: '1.25rem', fontWeight: 800 }}>{s.val}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Smart Presets */}
            <div className="card" style={{ padding: '1.75rem', border: '1px solid var(--border)', background: 'var(--surface)' }}>
              <h3 style={{ fontSize: '0.975rem', fontWeight: 700, color: 'var(--text-sub)', marginBottom: '1.125rem' }}>
                Smart Presets
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.625rem' }}>
                {[
                  { label: 'System Downtime Alert', group: 'ALL', priority: 'HIGH' },
                  { label: 'Verify Documents Reminder', group: 'RESPONDERS', priority: 'NORMAL' },
                  { label: 'Emergency Zone Warning', group: 'ALL', priority: 'CRITICAL' },
                ].map((p, i) => (
                  <button
                    key={i}
                    onClick={() => { setFormData({ ...formData, title: p.label, recipientType: p.group, priority: p.priority }); showAlert('Preset loaded', 'info'); }}
                    style={{
                      width: '100%', padding: '0.875rem 1rem', borderRadius: '11px',
                      border: '1px solid var(--border)',
                      background: 'var(--surface-raised)',
                      textAlign: 'left', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', gap: '0.75rem',
                      fontFamily: 'var(--font-sans)',
                      transition: 'all 0.18s ease',
                    }}
                    onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--primary-mid)'; e.currentTarget.style.background = 'var(--primary-pale)'; }}
                    onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; e.currentTarget.style.background = 'var(--surface-raised)'; }}
                  >
                    <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: PRIORITY_COLORS[p.priority], flexShrink: 0 }} />
                    <span style={{ fontSize: '0.84rem', fontWeight: 600, color: 'var(--text-sub)' }}>{p.label}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* History Detail Modal */}
      {selectedHistoryDetail && (
        <div
          onClick={() => setSelectedHistoryDetail(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem' }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            onClick={e => e.stopPropagation()}
            style={{ background: 'var(--surface)', borderRadius: '20px', padding: '2.5rem', maxWidth: '560px', width: '100%', border: '1px solid var(--border)', boxShadow: '0 20px 60px rgba(0,0,0,0.2)' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.5rem' }}>
              <div>
                <h2 style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--text-sub)', marginBottom: '0.375rem' }}>
                  {selectedHistoryDetail.title}
                </h2>
                <div style={{ display: 'flex', gap: '0.625rem', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '0.72rem', fontWeight: 700, padding: '0.25rem 0.625rem', borderRadius: '6px', background: 'var(--primary-pale)', color: 'var(--primary)' }}>
                    {selectedHistoryDetail.recipient}
                  </span>
                  <span style={{ fontSize: '0.72rem', fontWeight: 700, padding: '0.25rem 0.625rem', borderRadius: '6px', background: 'var(--surface-raised)', color: PRIORITY_COLORS[selectedHistoryDetail.priority] }}>
                    {selectedHistoryDetail.priority}
                  </span>
                </div>
              </div>
              <button
                onClick={() => setSelectedHistoryDetail(null)}
                style={{ padding: '0.375rem', borderRadius: '8px', border: '1px solid var(--border)', background: 'var(--surface-raised)', cursor: 'pointer', color: 'var(--text-muted)', lineHeight: 0 }}
              >
                <X size={16} />
              </button>
            </div>
            <div style={{ background: 'var(--surface-raised)', borderRadius: '14px', padding: '1.5rem', marginBottom: '1.5rem', border: '1px solid var(--border)' }}>
              <p style={{ fontSize: '0.95rem', color: 'var(--secondary)', lineHeight: 1.65, whiteSpace: 'pre-wrap', margin: 0 }}>
                {selectedHistoryDetail.body}
              </p>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
              <span>Sent: {new Date(selectedHistoryDetail.timestamp).toLocaleString()}</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: 'var(--s-resolved)' }}>
                <CheckCircle size={13} /> {selectedHistoryDetail.status}
              </span>
            </div>
          </motion.div>
        </div>
      )}
    </motion.div>
  );
};

export default SystemNotifications;

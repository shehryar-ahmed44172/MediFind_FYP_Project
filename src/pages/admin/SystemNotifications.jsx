import React, { useState, useEffect } from 'react';
import {
  Bell, Send, Users, User, Shield, Clock, AlertTriangle,
  CheckCircle, Search, Trash2,
  Eye, Smartphone, Mail, Zap, RotateCcw, X, ChevronLeft, ChevronRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAlert } from '../../context/AlertContext';
import api from '../../services/api';

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

const SystemNotifications = () => {
  const { showAlert } = useAlert();
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
  const [historySearch, setHistorySearch] = useState('');
  const [selectedHistoryDetail, setSelectedHistoryDetail] = useState(null);

  // Pagination state (Broadcast History)
  const [currentPage, setCurrentPage] = useState(1);
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
    } catch {
      showAlert('Failed to send notification', 'error');
    } finally {
      setSending(false);
    }
  };

  const fetchHistory = async () => {
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
    }
  };

  useEffect(() => { fetchHistory(); }, []);

  const filteredHistory = history.filter(item =>
    !historySearch ||
    item.title.toLowerCase().includes(historySearch.toLowerCase()) ||
    item.recipient.toLowerCase().includes(historySearch.toLowerCase()) ||
    item.body.toLowerCase().includes(historySearch.toLowerCase())
  );

  // Reset pagination to page 1 on search or tab changes
  useEffect(() => {
    setCurrentPage(1);
  }, [historySearch, activeTab]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4 }}
    >
      {/* ── Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-sub)', letterSpacing: '-0.03em', marginBottom: '0.375rem' }}>
            System Notifications
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Broadcast alerts and manage communications across the network.
          </p>
        </div>

        {/* Tab Switcher */}
        <div style={{
          display: 'flex', gap: '0.375rem',
          background: 'var(--surface-raised)',
          border: '1px solid var(--border)',
          padding: '0.35rem', borderRadius: '12px',
        }}>
          {[
            { id: 'COMPOSE', label: 'Compose', Icon: Send },
            { id: 'HISTORY', label: 'History', Icon: Clock },
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
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
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: activeTab === 'COMPOSE' ? '1.2fr 0.8fr' : '1fr', gap: '1.75rem' }}>

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

              <form onSubmit={handleSend}>
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
                      { id: 'PUSH', label: 'Push', Icon: Smartphone, color: '#8b5cf6' },
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
                    onChange={(e) => setHistorySearch(e.target.value)}
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
                    {filteredHistory.length === 0 ? (
                      <tr>
                        <td colSpan={6} style={{ padding: '4rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                          <Bell size={40} style={{ opacity: 0.15, display: 'block', margin: '0 auto 1rem' }} />
                          <p style={{ fontWeight: 600 }}>{historySearch ? 'No results found' : 'No broadcasts yet'}</p>
                        </td>
                      </tr>
                    ) : filteredHistory.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((item) => (
                      <tr
                        key={item.id}
                        style={{ borderBottom: '1px solid var(--border)', transition: 'background 0.15s' }}
                        onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-raised)'}
                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
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
                              onClick={() => setSelectedHistoryDetail(item)}
                              style={{ padding: '0.35rem', borderRadius: '6px', border: '1px solid var(--border)', background: 'var(--surface-raised)', color: 'var(--text-muted)', cursor: 'pointer' }}
                            >
                              <Eye size={13} />
                            </button>
                            <button
                              onClick={() => setHistory(h => h.filter(i => i.id !== item.id))}
                              style={{ padding: '0.35rem', borderRadius: '6px', border: '1px solid var(--error-border)', background: 'var(--error-bg)', color: 'var(--error-fg)', cursor: 'pointer' }}
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Footer & Pagination */}
              <div style={{ padding: '1.25rem 2rem', background: 'var(--surface-raised)', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
                <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)', fontWeight: 500 }}>
                  {filteredHistory.length === 0 
                    ? 'Showing 0 of 0 entries'
                    : `Showing ${((currentPage - 1) * itemsPerPage) + 1}–${Math.min(currentPage * itemsPerPage, filteredHistory.length)} of ${filteredHistory.length} entries`
                  }
                </span>

                {Math.ceil(filteredHistory.length / itemsPerPage) > 1 && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                    {/* Previous Button */}
                    <button
                      onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                      disabled={currentPage === 1}
                      style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        width: '32px', height: '32px', borderRadius: '8px',
                        border: '1px solid var(--border)', background: 'var(--surface)',
                        color: currentPage === 1 ? 'var(--text-muted)' : 'var(--text-sub)',
                        cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
                        opacity: currentPage === 1 ? 0.5 : 1,
                        transition: 'all 0.2s ease',
                      }}
                      onMouseEnter={e => { if (currentPage !== 1) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                      onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; }}
                    >
                      <ChevronLeft size={16} />
                    </button>

                    {/* Page Numbers */}
                    {Array.from({ length: Math.ceil(filteredHistory.length / itemsPerPage) }, (_, i) => i + 1).map(page => {
                      const isCurrent = page === currentPage;
                      return (
                        <button
                          key={page}
                          onClick={() => setCurrentPage(page)}
                          style={{
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            minWidth: '32px', height: '32px', padding: '0 6px', borderRadius: '8px',
                            border: isCurrent ? '1px solid var(--primary)' : '1px solid var(--border)',
                            background: isCurrent ? 'var(--primary)' : 'var(--surface)',
                            color: isCurrent ? 'white' : 'var(--text-sub)',
                            fontWeight: isCurrent ? 700 : 600,
                            fontSize: '0.82rem', cursor: 'pointer',
                            transition: 'all 0.2s ease',
                          }}
                          onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                          onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.borderColor = 'var(--border)'; }}
                        >
                          {page}
                        </button>
                      );
                    })}

                    {/* Next Button */}
                    <button
                      onClick={() => setCurrentPage(prev => Math.min(prev + 1, Math.ceil(filteredHistory.length / itemsPerPage)))}
                      disabled={currentPage === Math.ceil(filteredHistory.length / itemsPerPage)}
                      style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        width: '32px', height: '32px', borderRadius: '8px',
                        border: '1px solid var(--border)', background: 'var(--surface)',
                        color: currentPage === Math.ceil(filteredHistory.length / itemsPerPage) ? 'var(--text-muted)' : 'var(--text-sub)',
                        cursor: currentPage === Math.ceil(filteredHistory.length / itemsPerPage) ? 'not-allowed' : 'pointer',
                        opacity: currentPage === Math.ceil(filteredHistory.length / itemsPerPage) ? 0.5 : 1,
                        transition: 'all 0.2s ease',
                      }}
                      onMouseEnter={e => { if (currentPage !== Math.ceil(filteredHistory.length / itemsPerPage)) e.currentTarget.style.borderColor = 'var(--primary)'; }}
                      onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; }}
                    >
                      <ChevronRight size={16} />
                    </button>
                  </div>
                )}
              </div>
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
              background: 'linear-gradient(135deg, #0C637E, #2496A7)',
              color: 'white',
            }}>
              <h3 style={{ fontSize: '0.975rem', fontWeight: 700, marginBottom: '0.875rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Shield size={17} /> Network Safety
              </h3>
              <p style={{ fontSize: '0.82rem', opacity: 0.88, lineHeight: 1.6, marginBottom: '1.25rem' }}>
                All notifications are logged for HIPAA compliance auditing. Ensure messages containing PHI are sent via secure channels only.
              </p>
              <div style={{ display: 'flex', gap: '0.75rem' }}>
                {[{ label: 'Total Reach', val: '12.4K' }, { label: 'Delivery', val: '99.9%' }].map(s => (
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

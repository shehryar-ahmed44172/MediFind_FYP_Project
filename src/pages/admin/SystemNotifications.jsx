import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Bell, Send, Eye, Smartphone, Mail, Sparkles, Shield } from 'lucide-react';
import { useAlert } from '../../context/hooks';
import api from '../../services/api';
import { errorMessage } from '../../services/adminApi';
import {
  PageHeader, Pagination, EmptyState, TableSkeletonRows, Panel, Toolbar, DataTable, SearchInput, StatusBadge,
  FormField, Input, Select, Textarea, Button, IconButton, FilterPill, Modal, DetailItem, RefreshButton,
} from '../../components/ui';
import { paginate, toneFor, humanize } from '../../components/uiStyles';

const PRIORITY_TONE = { NORMAL: 'neutral', HIGH: 'warning', CRITICAL: 'danger' };

const RECIPIENT_LABELS = { ALL: 'all users', PATIENTS: 'all patients', RESPONDERS: 'all responders', CAREGIVERS: 'all caregivers' };
const RECIPIENT_OPTIONS = [
  { value: 'ALL', label: 'All Users' },
  { value: 'PATIENTS', label: 'All Patients' },
  { value: 'RESPONDERS', label: 'All Responders' },
  { value: 'CAREGIVERS', label: 'All Caregivers' },
  { value: 'INDIVIDUAL', label: 'Specific User (Email or ID)' },
];
const CHANNEL_LABELS = { IN_APP: 'in-app', PUSH: 'push', EMAIL: 'email' };
const CHANNELS = [
  { id: 'IN_APP', label: 'In-app', Icon: Bell },
  { id: 'PUSH', label: 'Push', Icon: Smartphone },
  { id: 'EMAIL', label: 'Email copy', Icon: Mail },
];
const PRESETS = [
  { label: 'System Downtime Alert', group: 'ALL', priority: 'HIGH' },
  { label: 'Verify Documents Reminder', group: 'RESPONDERS', priority: 'NORMAL' },
  { label: 'Emergency Zone Warning', group: 'ALL', priority: 'CRITICAL' },
];

const fmtDate = (iso) => new Date(iso).toLocaleDateString();
const fmtTime = (iso) => new Date(iso).toLocaleTimeString();

const SystemNotifications = () => {
  const { showAlert, showConfirm } = useAlert();
  const [sending, setSending] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [aiPrompt, setAiPrompt] = useState('');
  const historyRef = useRef(null);

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
        setPage(1);
        historyRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
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

  const refreshHistory = () => { setHistoryLoading(true); fetchHistory(); };

  const hq = historySearch.trim().toLowerCase();
  const filteredHistory = history.filter(item =>
    !hq ||
    String(item.title || '').toLowerCase().includes(hq) ||
    String(item.recipient || '').toLowerCase().includes(hq) ||
    String(item.body || '').toLowerCase().includes(hq)
  );

  const { page: currentPage, rows: historyRows } = paginate(filteredHistory, page, itemsPerPage);
  const lastBroadcast = history[0]?.timestamp;

  const previewAudience = formData.recipientType === 'INDIVIDUAL'
    ? (formData.targetId.trim() || 'Specific user')
    : RECIPIENT_OPTIONS.find(o => o.value === formData.recipientType)?.label;

  return (
    <div>
      <PageHeader
        title="System Notifications"
        description="Broadcast alerts to users and review what has been sent."
      />

      <div className="mf-stack">
      <div className="mf-compose-grid">
        {/* ── Compose ── */}
        <Panel
          title="Broadcast new alert"
          description="Every broadcast is confirmed before it is sent."
          footer={(
            <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '12px' }}>
              <Button type="submit" form="mf-broadcast-form" variant="primary" icon={Send} disabled={sending}>
                {sending ? 'Dispatching…' : 'Send broadcast'}
              </Button>
            </div>
          )}
        >
          {/* AI drafter (outside the form so Enter never submits the broadcast) */}
          <div style={{ padding: '16px', borderBottom: '1px solid var(--border)', background: 'var(--surface-alt)' }}>
            <FormField
              label="AI draft assistant"
              htmlFor="mf-ai-prompt"
              help="AI drafts a professional title and body. Review before broadcasting."
              right={<StatusBadge tone="neutral" dot={false}>Human-in-the-loop</StatusBadge>}
            >
              <div style={{ display: 'flex', gap: '8px' }}>
                <Input
                  id="mf-ai-prompt"
                  type="text"
                  placeholder="e.g. 'Remind responders to renew licenses by Friday'"
                  value={aiPrompt}
                  onChange={(e) => setAiPrompt(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleAIGenerate())}
                />
                <Button icon={Sparkles} onClick={handleAIGenerate} disabled={isGenerating}>
                  {isGenerating ? 'Generating…' : 'Generate'}
                </Button>
              </div>
            </FormField>
          </div>

          <form id="mf-broadcast-form" onSubmit={confirmAndSend} style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="mf-grid-2">
              <FormField label="Recipient group" htmlFor="mf-recipient">
                <Select id="mf-recipient" value={formData.recipientType} onChange={(e) => setFormData({ ...formData, recipientType: e.target.value })}>
                  {RECIPIENT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </Select>
              </FormField>
              <FormField label="Priority" htmlFor="mf-priority">
                <Select id="mf-priority" value={formData.priority} onChange={(e) => setFormData({ ...formData, priority: e.target.value })}>
                  <option value="NORMAL">Normal</option>
                  <option value="HIGH">High</option>
                  <option value="CRITICAL">Critical</option>
                </Select>
              </FormField>
            </div>

            {formData.recipientType === 'INDIVIDUAL' && (
              <FormField label="Target user email or ID" htmlFor="mf-target">
                <Input
                  id="mf-target"
                  type="text"
                  placeholder="user@example.com or cuid..."
                  value={formData.targetId}
                  onChange={(e) => setFormData({ ...formData, targetId: e.target.value })}
                />
              </FormField>
            )}

            <FormField label="Title" htmlFor="mf-title">
              <Input
                id="mf-title"
                type="text"
                placeholder="Brief headline..."
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              />
            </FormField>

            <FormField label="Message" htmlFor="mf-body">
              <Textarea
                id="mf-body"
                placeholder="Full details of the alert..."
                rows={4}
                value={formData.body}
                onChange={(e) => setFormData({ ...formData, body: e.target.value })}
              />
            </FormField>

            <FormField label="Channels" help="Select at least one channel.">
              <div role="group" aria-label="Dispatch channels" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {CHANNELS.map(ch => (
                  <FilterPill key={ch.id} active={formData.channels.includes(ch.id)} onClick={() => handleChannelToggle(ch.id)}>
                    <ch.Icon size={14} aria-hidden="true" /> {ch.label}
                  </FilterPill>
                ))}
              </div>
            </FormField>
          </form>
        </Panel>

        {/* ── Side column: preview, presets, audit info ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', minWidth: 0 }}>
          <Panel title="Preview" padded>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap', marginBottom: '10px' }}>
              <StatusBadge tone={PRIORITY_TONE[formData.priority]}>{humanize(formData.priority)}</StatusBadge>
              <StatusBadge tone="neutral" dot={false}>{previewAudience}</StatusBadge>
            </div>
            <div style={{ padding: '12px', border: '1px solid var(--border)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface-alt)' }}>
              <p style={{ fontSize: '13.5px', fontWeight: 600, color: formData.title ? 'var(--text-main)' : 'var(--text-muted)', margin: '0 0 4px' }}>
                {formData.title || 'Notification title'}
              </p>
              <p style={{ fontSize: '13px', lineHeight: '19px', color: 'var(--text-muted)', margin: 0, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                {formData.body || 'The message body will appear here.'}
              </p>
            </div>
            <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', margin: '10px 0 0' }}>
              Via {formData.channels.length ? formData.channels.map(c => CHANNEL_LABELS[c] || c).join(', ') : 'no channel selected'}
            </p>
          </Panel>

          <Panel title="Presets" description="Loads a title, audience and priority.">
            <ul style={{ listStyle: 'none', margin: 0, padding: '4px 0' }}>
              {PRESETS.map((p) => (
                <li key={p.label}>
                  <button
                    type="button"
                    className="mf-menu-item"
                    onClick={() => { setFormData({ ...formData, title: p.label, recipientType: p.group, priority: p.priority }); showAlert('Preset loaded', 'info'); }}
                    style={{ justifyContent: 'space-between', padding: '6px 16px' }}
                  >
                    <span>{p.label}</span>
                    <StatusBadge tone={PRIORITY_TONE[p.priority]}>{humanize(p.priority)}</StatusBadge>
                  </button>
                </li>
              ))}
            </ul>
          </Panel>

          <Panel title="Network safety" icon={Shield} padded>
            <p style={{ fontSize: '13px', lineHeight: '19px', color: 'var(--text-muted)', margin: '0 0 12px' }}>
              All notifications are logged for HIPAA compliance auditing. Ensure messages containing PHI are sent via secure channels only.
            </p>
            <dl style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', margin: 0 }}>
              <DetailItem label="Broadcasts sent"><span className="mf-num">{historyLoading ? '—' : history.length}</span></DetailItem>
              <DetailItem label="Last broadcast">
                <span className="mf-num">{historyLoading ? '—' : (lastBroadcast ? new Date(lastBroadcast).toLocaleDateString('en-PK', { day: '2-digit', month: 'short' }) : 'Never')}</span>
              </DetailItem>
            </dl>
          </Panel>
        </div>
      </div>

      {/* ── History ── */}
      <div ref={historyRef} style={{ scrollMarginTop: '16px' }}>
        <Panel
          title="Broadcast history"
          description={historyLoading ? undefined : `${history.length.toLocaleString()} broadcasts on record`}
          actions={<RefreshButton onClick={refreshHistory} loading={historyLoading} iconOnly />}
        >
          <Toolbar>
            <SearchInput
              width={260}
              value={historySearch}
              onChange={(v) => { setHistorySearch(v); setPage(1); }}
              placeholder="Search title, recipient or message…"
            />
          </Toolbar>

          <DataTable minWidth="760px">
            <thead>
              <tr>
                <th scope="col">Alert</th>
                <th scope="col">Recipients</th>
                <th scope="col">Priority</th>
                <th scope="col">Status</th>
                <th scope="col">Sent at</th>
                <th scope="col" className="actions"><span className="sr-only">Actions</span></th>
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
                      message={historySearch ? undefined : 'Messages you send from the compose form will appear here.'}
                      action={historySearch ? <Button size="sm" onClick={() => { setHistorySearch(''); setPage(1); }}>Clear filters</Button> : undefined}
                    />
                  </td>
                </tr>
              ) : historyRows.map((item) => (
                <tr key={item.id} className="mf-table-row">
                  <td style={{ maxWidth: '320px' }}>
                    <div style={{ fontWeight: 500, color: 'var(--text-main)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.title}</div>
                    <div style={{ fontSize: '12.5px', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.body}</div>
                  </td>
                  <td style={{ whiteSpace: 'nowrap' }}>{item.recipient}</td>
                  <td><StatusBadge tone={PRIORITY_TONE[item.priority] || 'neutral'}>{humanize(item.priority)}</StatusBadge></td>
                  <td><StatusBadge tone={toneFor(item.status)}>{humanize(item.status)}</StatusBadge></td>
                  <td className="mf-num" style={{ whiteSpace: 'nowrap' }}>
                    <div style={{ color: 'var(--admin-text-sub)' }}>{fmtDate(item.timestamp)}</div>
                    <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>{fmtTime(item.timestamp)}</div>
                  </td>
                  <td className="actions">
                    <IconButton label={`View broadcast "${item.title}"`} icon={Eye} onClick={() => setSelectedHistoryDetail(item)} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>

          <Pagination page={currentPage} pageSize={itemsPerPage} total={filteredHistory.length} onChange={setPage} loading={historyLoading} noun="broadcasts" />
        </Panel>
      </div>
      </div>

      {/* History detail */}
      {selectedHistoryDetail && (
        <Modal
          onClose={() => setSelectedHistoryDetail(null)}
          title={selectedHistoryDetail.title}
          width={560}
          footer={<Button onClick={() => setSelectedHistoryDetail(null)}>Close</Button>}
        >
          <dl style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '12px', margin: '0 0 16px' }}>
            <DetailItem label="Recipients">{selectedHistoryDetail.recipient}</DetailItem>
            <DetailItem label="Sent"><span className="mf-num">{new Date(selectedHistoryDetail.timestamp).toLocaleString()}</span></DetailItem>
            <DetailItem label="Priority">
              <StatusBadge tone={PRIORITY_TONE[selectedHistoryDetail.priority] || 'neutral'}>{humanize(selectedHistoryDetail.priority)}</StatusBadge>
            </DetailItem>
            <DetailItem label="Status">
              <StatusBadge tone={toneFor(selectedHistoryDetail.status)}>{humanize(selectedHistoryDetail.status)}</StatusBadge>
            </DetailItem>
          </dl>
          <div style={{ padding: '12px 14px', border: '1px solid var(--border)', borderRadius: 'var(--radius-control, 8px)', background: 'var(--surface-alt)' }}>
            <p style={{ fontSize: '13.5px', lineHeight: '21px', color: 'var(--text-main)', whiteSpace: 'pre-wrap', margin: 0 }}>
              {selectedHistoryDetail.body}
            </p>
          </div>
        </Modal>
      )}
    </div>
  );
};

export default SystemNotifications;

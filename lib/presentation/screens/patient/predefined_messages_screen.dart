import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

// ── Local cache key ───────────────────────────────────────────────────────────
const _kPredefinedMessages = 'predefined_messages';

// ── Default messages for deaf patients ───────────────────────────────────────
const _defaultMessages = [
  'I need immediate medical help!',
  'I am deaf. Please communicate via text.',
  'I have chest pain.',
  'I cannot breathe properly.',
  'I am having a seizure.',
  'Please call an ambulance.',
  'I am diabetic and feeling faint.',
  'I am allergic to penicillin.',
];

const _maxPhraseLength = 100;

// ── Provider ──────────────────────────────────────────────────────────────────
final predefinedMessagesProvider =
    StateNotifierProvider<PredefinedMessagesNotifier, List<String>>(
  (ref) => PredefinedMessagesNotifier(),
);

class PredefinedMessagesNotifier extends StateNotifier<List<String>> {
  PredefinedMessagesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPredefinedMessages);
    if (raw != null) {
      final decoded = List<String>.from(jsonDecode(raw) as List);
      state = decoded;
    } else {
      state = List.from(_defaultMessages);
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPredefinedMessages, jsonEncode(state));
  }

  Future<void> add(String message) async {
    if (message.trim().isEmpty || state.contains(message.trim())) return;
    state = [...state, message.trim()];
    await _persist();
  }

  /// Replaces the phrase at [index]. Ignored when empty or a duplicate.
  Future<void> update(int index, String message) async {
    final text = message.trim();
    if (index < 0 || index >= state.length || text.isEmpty) return;
    if (state.asMap().entries.any((e) => e.key != index && e.value == text)) return;
    final list = [...state];
    list[index] = text;
    state = list;
    await _persist();
  }

  Future<void> remove(String message) async {
    state = state.where((m) => m != message).toList();
    await _persist();
  }

  /// Puts back a phrase removed with [remove] (undo).
  Future<void> insertAt(int index, String message) async {
    if (state.contains(message)) return;
    final list = [...state];
    list.insert(index.clamp(0, list.length), message);
    state = list;
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _persist();
  }

  Future<void> reset() async {
    state = List.from(_defaultMessages);
    await _persist();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class PredefinedMessagesScreen extends ConsumerStatefulWidget {
  const PredefinedMessagesScreen({super.key});

  @override
  ConsumerState<PredefinedMessagesScreen> createState() => _PredefinedMessagesScreenState();
}

class _PredefinedMessagesScreenState extends ConsumerState<PredefinedMessagesScreen> {
  final _controller = TextEditingController();
  bool _isSyncing = false;
  String? _syncError;
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncToServer() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });
    try {
      final messages = ref.read(predefinedMessagesProvider);
      final apiClient = ref.read(apiClientProvider);
      // GET current profile first to merge other fields
      final profile = await apiClient.getMedicalProfile();
      final current = profile.toJson();

      await apiClient.updateMedicalProfile({
        'bloodType':         current['bloodType']         ?? '',
        'chronicDiseases':   current['chronicDiseases']   ?? [],
        'allergies':         current['allergies']          ?? [],
        'medications':       current['medications']        ?? [],
        'emergencyContacts': current['emergencyContacts']  ?? [],
        'medicalHistory':    current['medicalHistory'],
        'patientType':       current['patientType']        ?? 'DEAF',
        'predefinedMessages': messages,
      });

      if (mounted) {
        setState(() => _dirty = false);
        showMfSnackBar(context, 'Quick phrases saved to your medical profile.', tone: MfTone.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncError = e.toString().replaceAll('Exception:', '').trim());
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _addMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (ref.read(predefinedMessagesProvider).contains(text)) {
      showMfSnackBar(context, 'That phrase is already in your list.', tone: MfTone.warning);
      return;
    }
    ref.read(predefinedMessagesProvider.notifier).add(text);
    _controller.clear();
    setState(() => _dirty = true);
  }

  Future<void> _editMessage(int index, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit phrase'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: _maxPhraseLength,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Phrase'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(MfSpace.md, 0, MfSpace.md, MfSpace.md),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || result.trim() == current) return;
    await ref.read(predefinedMessagesProvider.notifier).update(index, result);
    if (mounted) setState(() => _dirty = true);
  }

  Future<void> _deleteMessage(int index, String msg) async {
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Delete this phrase?',
      message: '"$msg"',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    await ref.read(predefinedMessagesProvider.notifier).remove(msg);
    if (!mounted) return;
    setState(() => _dirty = true);
    showMfSnackBar(
      context,
      'Phrase deleted',
      actionLabel: 'Undo',
      onAction: () => ref.read(predefinedMessagesProvider.notifier).insertAt(index, msg),
    );
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    final length = ref.read(predefinedMessagesProvider).length;
    if (target < 0 || target >= length) return;
    // ReorderableList semantics: newIndex is the slot before removal.
    await ref.read(predefinedMessagesProvider.notifier).reorder(index, delta > 0 ? target + 1 : target);
    if (mounted) setState(() => _dirty = true);
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showMfConfirmDialog(
      context,
      title: 'Reset to default phrases?',
      message: 'This will replace all your custom phrases with the default set.',
      confirmLabel: 'Reset',
      destructive: true,
      icon: Icons.restart_alt_rounded,
    );
    if (confirmed) {
      await ref.read(predefinedMessagesProvider.notifier).reset();
      if (mounted) setState(() => _dirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(predefinedMessagesProvider);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return MfScaffold(
      title: 'Quick phrases',
      subtitle: 'One-tap messages for text-only communication',
      actions: [
        MfIconButton(
          icon: Icons.restart_alt_rounded,
          tooltip: 'Reset to default phrases',
          onPressed: _resetDefaults,
        ),
      ],
      bottomBar: MfPrimaryButton(
        label: _isSyncing
            ? 'Saving to profile'
            : (_dirty ? 'Save changes to medical profile' : 'Save to medical profile'),
        icon: Icons.cloud_upload_outlined,
        loading: _isSyncing,
        onPressed: _syncToServer,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(MfSpace.gutter, MfSpace.md, MfSpace.gutter, 0),
            sliver: SliverList.list(
              children: [
                const MfInfoBanner(
                  icon: Icons.quickreply_outlined,
                  tone: MfTone.primary,
                  title: 'Sent instantly from chat',
                  message: 'These phrases appear above the chat input and on your home screen. '
                      'Put the most important ones first.',
                ),
                if (_syncError != null) ...[
                  const SizedBox(height: MfSpace.sm),
                  MfInfoBanner(
                    icon: Icons.cloud_off_outlined,
                    tone: MfTone.danger,
                    title: 'Could not save to your profile',
                    message: _syncError,
                    actionLabel: 'Try again',
                    onAction: _syncToServer,
                  ),
                ],
                const SizedBox(height: MfSpace.lg),
                const MfSectionTitle('Add a phrase'),
                const SizedBox(height: MfSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: _maxPhraseLength,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'New phrase',
                          hintText: 'e.g. Please write it down for me',
                        ),
                        onSubmitted: (_) => _addMessage(),
                      ),
                    ),
                    const SizedBox(width: MfSpace.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: MfSpace.xxs),
                      child: MfPrimaryButton(
                        label: 'Add',
                        icon: Icons.add_rounded,
                        expanded: false,
                        height: MfSize.minTouch + MfSpace.xs,
                        onPressed: _addMessage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MfSpace.sm),
                MfSectionTitle(
                  'Your phrases',
                  subtitle: messages.isEmpty
                      ? null
                      : '${messages.length} phrase${messages.length == 1 ? '' : 's'}. Drag the handle or use the arrows to reorder.',
                ),
                const SizedBox(height: MfSpace.xs),
              ],
            ),
          ),
          if (messages.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: MfEmptyState(
                compact: true,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No phrases yet',
                message: 'Add a phrase above, or reset to the default set.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(MfSpace.gutter, 0, MfSpace.gutter, MfSpace.xl),
              sliver: SliverReorderableList(
                itemCount: messages.length,
                onReorder: (oldIndex, newIndex) {
                  ref.read(predefinedMessagesProvider.notifier).reorder(oldIndex, newIndex);
                  setState(() => _dirty = true);
                },
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Padding(
                    key: ValueKey('phrase_$msg'),
                    padding: const EdgeInsets.only(bottom: MfSpace.xs),
                    child: MfCard(
                      padding: const EdgeInsets.fromLTRB(MfSpace.xxs, MfSpace.xxs, MfSpace.xxs, MfSpace.xxs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: Semantics(
                                  label: 'Reorder handle for phrase ${index + 1}',
                                  child: SizedBox(
                                    width: MfSize.minTouch,
                                    height: MfSize.minTouch,
                                    child: Icon(Icons.drag_indicator_rounded, color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: MfColors.tone(context, MfTone.primary).container,
                                  borderRadius: MfRadius.smAll,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: text.labelMedium?.copyWith(
                                    color: MfColors.tone(context, MfTone.primary).foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(width: MfSpace.sm),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: MfSpace.xs),
                                  child: Text(msg, style: text.bodyLarge),
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              MfIconButton(
                                icon: Icons.arrow_upward_rounded,
                                tooltip: 'Move up',
                                onPressed: index == 0 ? null : () => _move(index, -1),
                              ),
                              MfIconButton(
                                icon: Icons.arrow_downward_rounded,
                                tooltip: 'Move down',
                                onPressed: index == messages.length - 1 ? null : () => _move(index, 1),
                              ),
                              MfTextButton(
                                label: 'Edit',
                                icon: Icons.edit_outlined,
                                onPressed: () => _editMessage(index, msg),
                              ),
                              MfTextButton(
                                label: 'Delete',
                                icon: Icons.delete_outline_rounded,
                                tone: MfTone.danger,
                                onPressed: () => _deleteMessage(index, msg),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

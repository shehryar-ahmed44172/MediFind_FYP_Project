import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../data/datasources/remote/medifind_api_client.dart'; // needed for apiClientProvider

// ── Local cache key ───────────────────────────────────────────────────────────
const _kPredefinedMessages = 'predefined_messages';

// ── Default messages for deaf patients ───────────────────────────────────────
const _defaultMessages = [
  'I need immediate medical help!',
  'I am deaf — please communicate via text.',
  'I have chest pain.',
  'I cannot breathe properly.',
  'I am having a seizure.',
  'Please call an ambulance.',
  'I am diabetic and feeling faint.',
  'I am allergic to penicillin.',
];

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

  Future<void> remove(String message) async {
    state = state.where((m) => m != message).toList();
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
  ConsumerState<PredefinedMessagesScreen> createState() =>
      _PredefinedMessagesScreenState();
}

class _PredefinedMessagesScreenState
    extends ConsumerState<PredefinedMessagesScreen> {
  final _controller = TextEditingController();
  bool _isSyncing = false;
  String? _syncError;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages synced to your profile ✓'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _syncError = 'Sync failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _addMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(predefinedMessagesProvider.notifier).add(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(predefinedMessagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Predefined Messages'),
        centerTitle: true,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Save to Profile',
              onPressed: _syncToServer,
            ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C637E), Color(0xFF2496A7)],
              ),
              boxShadow: AppShadows.neumorphicOut,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hearing_disabled, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Communication Phrases',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Tap any phrase during an emergency to send instantly.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_syncError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_syncError!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),

          // Add New Message
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppShadows.neumorphicOut,
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        hintText: 'Type a new phrase...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _addMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _addMessage,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0C637E), Color(0xFF2496A7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppShadows.neumorphicOut,
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),

          // Hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  'Long-press to reorder • Swipe left to delete',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Reset to Defaults?'),
                        content: const Text('This will replace all your custom phrases with the default set.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref.read(predefinedMessagesProvider.notifier).reset();
                    }
                  },
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Messages List
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No phrases yet. Add one above!',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: messages.length,
                    onReorder: (oldIndex, newIndex) =>
                        ref.read(predefinedMessagesProvider.notifier).reorder(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return Dismissible(
                        key: ValueKey(msg),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        onDismissed: (_) =>
                            ref.read(predefinedMessagesProvider.notifier).remove(msg),
                        child: Container(
                          key: ValueKey('card_$msg'),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.neumorphicOut,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C637E).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0C637E),
                                ),
                              ),
                            ),
                            title: Text(
                              msg,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            trailing: const Icon(Icons.drag_indicator, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Save Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncToServer,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Save to Medical Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C637E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import '../../widgets/call/call_launcher.dart';
import '../../../services/call/call_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/exceptions.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../services/audio/voice_recorder_service.dart';
import '../../../services/location/location_service.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/design_system/design_system.dart';
import '../patient/predefined_messages_screen.dart';
import 'chat_list_screen.dart' show chatRoomDisplayName, chatRoomIsEmergency, chatRoomOtherUser;

final RegExp _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

/// Names callers pass when they do not know the real name yet.
const _genericNames = {'patient', 'responder', 'user', 'chat', 'caregiver', 'sender'};

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? otherUserName;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    this.otherUserName,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceRecorderService _recorderService = VoiceRecorderService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isSending = false;

  /// Text currently being sent (shown as a "Sending" bubble).
  String? _pendingText;
  String? _playingMessageId;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String _recordingDuration = '0:00';
  StreamSubscription<PlayerState>? _playerStateSub;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Single subscription for the lifetime of the screen (previously a new
    // listener was added on every play).
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingMessageId = null);
      }
    });
    // A room opened from an emergency may be brand new: refresh the room list so the
    // header (name, call button) and the lock state are known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final known = ref.read(chatRoomsProvider).valueOrNull?.any((r) => r.id == widget.roomId) ?? false;
      if (!known) ref.invalidate(chatRoomsProvider);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _recorderService.stopRecording();
    }
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false, String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    // A failed send may mean the emergency just ended: refresh so the lock shows
    if (isError) ref.invalidate(chatRoomsProvider);
    showMfSnackBar(
      context,
      message,
      tone: isError ? MfTone.danger : MfTone.neutral,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: MfMotion.of(context, const Duration(milliseconds: 300)),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Participant ──────────────────────────────────────────────────────────
  /// Resolves the real participant name from the rooms list when the caller
  /// only passed a generic label ("Patient", "Responder").
  ({String name, String? imageUrl, bool emergency}) _participant() {
    final passed = widget.otherUserName?.trim();
    final role = ref.watch(currentUserProvider).valueOrNull?.role;
    final rooms = ref.watch(chatRoomsProvider).valueOrNull;
    final room = rooms?.where((r) => r.id == widget.roomId).firstOrNull;
    if (room == null) {
      return (name: (passed == null || passed.isEmpty) ? 'Chat' : passed, imageUrl: null, emergency: false);
    }
    final resolved = chatRoomDisplayName(room, role);
    final useResolved = passed == null || passed.isEmpty || _genericNames.contains(passed.toLowerCase());
    return (
      name: useResolved ? resolved : passed,
      imageUrl: chatRoomOtherUser(room, role)?['profileImageUrl'] as String?,
      emergency: chatRoomIsEmergency(room),
    );
  }

  /// The other participant as a call target, when a call is allowed from this chat:
  /// not in a locked (ended) emergency chat. [deaf] = the patient in this room is Deaf,
  /// so only video calls are offered. The server enforces the same rules.
  ({CallPeer peer, bool deaf})? _callTarget() {
    final role = ref.watch(currentUserProvider).valueOrNull?.role;
    final room = ref.watch(chatRoomsProvider).valueOrNull?.where((r) => r.id == widget.roomId).firstOrNull;
    if (room == null || room.isLocked) return null;
    final patient = ref.watch(userProfileProvider(room.patientId)).valueOrNull;
    if (patient == null) return null;
    final otherId = (role ?? '').toUpperCase() == 'PATIENT' ? (room.responderId ?? room.caregiverId) : room.patientId;
    if (otherId == null) return null;
    final other = ref.watch(userProfileProvider(otherId)).valueOrNull;
    final participant = _participant();
    final phone = other?.phoneNumber.trim() ?? '';
    return (
      peer: CallPeer(
        id: otherId,
        name: participant.name,
        imageUrl: participant.imageUrl,
        phoneNumber: phone.isEmpty ? null : phone,
      ),
      deaf: (patient.patientType ?? '').toUpperCase() == 'DEAF',
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));
    final currentUserId = ref.watch(currentUserIdProvider).value;
    final participant = _participant();
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MfHeader(
        title: participant.name,
        subtitle: participant.emergency ? 'Emergency chat' : null,
        actions: [
          if (_callTarget() case final target?) ...[
            MfIconButton(
              icon: Icons.videocam_outlined,
              tooltip: 'Video call ${participant.name}',
              onPressed: () => startInAppCall(context, target.peer, CallMedia.video),
            ),
            if (!target.deaf)
              MfIconButton(
                icon: Icons.call_outlined,
                tooltip: 'Voice call ${participant.name}',
                onPressed: () => startInAppCall(context, target.peer, CallMedia.audio),
              ),
          ],
          MfIconButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'Chat info',
            onPressed: () => showMfBottomSheet<void>(
              context,
              builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MfAvatar(imageUrl: participant.imageUrl, name: participant.name, size: 64),
                  const SizedBox(height: MfSpace.sm),
                  Text(participant.name, style: text.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: MfSpace.xxs),
                  Text(
                    participant.emergency
                        ? 'Emergency conversation. Messages are shared with the assigned responder.'
                        : 'Private conversation',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: MfSpace.lg),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                if (messages.isEmpty && _pendingText == null) {
                  return MfEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message: 'Send a message to start the conversation with ${participant.name}.',
                  );
                }

                final itemCount = messages.length + (_pendingText != null ? 1 : 0);
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(MfSpace.sm, MfSpace.md, MfSpace.sm, MfSpace.md),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return _PendingBubble(text: _pendingText!);
                    }
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final prev = index > 0 ? messages[index - 1] : null;
                    final showDay = prev == null || !_sameDay(prev.createdAt, message.createdAt);
                    final grouped = !showDay && prev.senderId == message.senderId;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDay) _DaySeparator(date: message.createdAt),
                        _buildMessageBubble(message, isMe, grouped: grouped, senderName: participant.name),
                      ],
                    );
                  },
                );
              },
              loading: () => const MfLoading(label: 'Loading messages'),
              error: (e, _) => MfErrorState(
                title: 'Unable to load messages',
                message: 'Check your connection and try again.',
                onRetry: () => ref.read(chatMessagesProvider(widget.roomId).notifier).fetchMessages(),
              ),
            ),
          ),
          if (_roomLocked()) _buildClosedNotice() else _buildMessageInput(),
        ],
      ),
    );
  }

  bool _roomLocked() =>
      ref.watch(chatRoomsProvider).valueOrNull?.where((r) => r.id == widget.roomId).firstOrNull?.isLocked ?? false;

  /// Shown instead of the composer once the emergency behind this chat is over.
  Widget _buildClosedNotice() {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MfSpace.md),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: cs.onSurfaceVariant),
              const SizedBox(width: MfSpace.sm),
              Expanded(
                child: Text(
                  'This emergency has ended. Chat and calls with the responder are closed.',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  // ── Bubbles ──────────────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage message, bool isMe, {required bool grouped, required String senderName}) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = isMe ? cs.onPrimary : cs.onSurface;
    final meta = isMe ? cs.onPrimary.withValues(alpha: 0.8) : cs.onSurfaceVariant;
    final time = DateFormat('h:mm a').format(message.createdAt.toLocal());

    Widget content;
    String semanticsContent;
    switch (message.messageType) {
      case MessageType.AUDIO:
      case MessageType.VOICE_ALERT:
        final playing = _playingMessageId == message.id;
        semanticsContent = 'Voice message';
        content = InkWell(
          onTap: () => _playVoiceNote(message.id, message.mediaUrl),
          borderRadius: MfRadius.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MfSize.minTouch),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: fg, size: 36),
                const SizedBox(width: MfSpace.xs),
                Flexible(
                  child: Text(
                    playing ? 'Playing voice message' : 'Voice message',
                    style: text.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case MessageType.DOCUMENT:
        semanticsContent = 'Document ${message.content}';
        content = InkWell(
          onTap: message.mediaUrl == null ? null : () => _openLink(mfResolveImageUrl(message.mediaUrl) ?? message.mediaUrl!),
          borderRadius: MfRadius.smAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MfSize.minTouch),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, color: fg, size: 28),
                const SizedBox(width: MfSpace.xs),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.content,
                        style: text.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.mediaUrl != null)
                        Text('Tap to open', style: text.labelSmall?.copyWith(color: meta)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case MessageType.IMAGE:
        semanticsContent = 'Photo';
        content = message.mediaUrl == null
            ? Text('Photo unavailable', style: text.bodyMedium?.copyWith(color: fg))
            : InkWell(
                onTap: () => _openLink(mfResolveImageUrl(message.mediaUrl) ?? message.mediaUrl!),
                child: ClipRRect(
                  borderRadius: MfRadius.smAll,
                  child: Image.network(
                    mfResolveImageUrl(message.mediaUrl) ?? message.mediaUrl!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const SizedBox(width: 220, height: 220, child: MfLoading()),
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 220,
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: meta, size: 32)),
                    ),
                  ),
                ),
              );
        break;
      case MessageType.TEXT:
        semanticsContent = message.content;
        content = _buildTextContent(message.content, isMe);
        break;
    }

    const radius = Radius.circular(MfRadius.lg);
    const tail = Radius.circular(MfRadius.sm / 2);
    final status = isMe ? (message.isRead ? 'Read' : 'Delivered') : null;

    return Semantics(
      container: true,
      label: '${isMe ? 'You' : senderName}: $semanticsContent. $time${status != null ? '. $status' : ''}',
      excludeSemantics: message.messageType == MessageType.TEXT && !_urlRegex.hasMatch(message.content),
      child: Padding(
        padding: EdgeInsets.only(top: grouped ? 2 : MfSpace.xs),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isMe ? cs.primary : cs.surface,
                border: isMe ? null : Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: isMe ? radius : tail,
                  bottomRight: isMe ? tail : radius,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(MfSpace.sm, MfSpace.xs, MfSpace.sm, MfSpace.xs),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    content,
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: text.labelSmall?.copyWith(color: meta)),
                        if (isMe) ...[
                          const SizedBox(width: MfSpace.xxs),
                          Icon(
                            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 16,
                            color: meta,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(String content, bool isMe) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = isMe ? cs.onPrimary : cs.onSurface;
    final match = _urlRegex.firstMatch(content);
    if (match == null) {
      return Text(content, style: text.bodyLarge?.copyWith(color: color));
    }
    final url = match.group(0)!;

    // Shared location: show a labeled card with an explicit action.
    if (url.contains('google.com/maps')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, color: color, size: 22),
              const SizedBox(width: MfSpace.xxs),
              Flexible(
                child: Text('Shared location', style: text.titleSmall?.copyWith(color: color)),
              ),
            ],
          ),
          const SizedBox(height: MfSpace.xxs),
          TextButton.icon(
            onPressed: () => _openLink(url),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: MfSpace.xs),
              minimumSize: const Size(MfSize.minTouch, MfSize.minTouch),
              side: BorderSide(color: color.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open in Maps'),
          ),
        ],
      );
    }

    return Semantics(
      link: true,
      label: 'Open link',
      child: InkWell(
        onTap: () => _openLink(url),
        child: Text.rich(
          TextSpan(
            style: text.bodyLarge?.copyWith(color: color),
            children: [
              TextSpan(text: content.substring(0, match.start)),
              TextSpan(
                text: url,
                style: TextStyle(
                  color: isMe ? cs.onPrimary : cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: isMe ? cs.onPrimary : cs.primary,
                ),
              ),
              TextSpan(text: content.substring(match.end)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not open link: $e');
      }
    }
    if (!opened) _showSnack('Could not open link', isError: true);
  }

  // ── Quick phrases (deaf patients) ────────────────────────────────────────
  /// Sends a quick phrase immediately. On failure the phrase is placed in the
  /// input so the user can retry.
  Future<void> _sendQuickPhrase(String phrase) async {
    if (_isSending) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSending = true;
      _pendingText = phrase;
    });
    try {
      final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(phrase);
      if (!mounted) return;
      if (!ok) {
        _messageController.text = phrase;
        _messageController.selection = TextSelection.collapsed(offset: phrase.length);
        _showSnack('Message not sent. It is in the text box so you can try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _pendingText = null;
        });
      }
    }
  }

  void _showQuickPhrases() {
    showMfBottomSheet<void>(
      context,
      title: 'Quick phrases',
      subtitle: 'Tap a phrase to send it now',
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final messages = ref.watch(predefinedMessagesProvider);
          final text = Theme.of(ctx).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (messages.isEmpty)
                const MfEmptyState(
                  compact: true,
                  icon: Icons.quickreply_outlined,
                  title: 'No phrases saved',
                  message: 'Add phrases you use often so you can send them with one tap.',
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
                  child: MfCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: MfSpace.md, endIndent: MfSpace.md),
                      itemBuilder: (_, i) => ListTile(
                        minVerticalPadding: MfSpace.sm,
                        title: Text(messages[i], style: text.bodyLarge),
                        trailing: const Icon(Icons.send_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendQuickPhrase(messages[i]);
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: MfSpace.sm),
              MfSecondaryButton(
                label: 'Edit quick phrases',
                icon: Icons.edit_outlined,
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/predefined-messages');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Composer ─────────────────────────────────────────────────────────────
  Widget _buildMessageInput() {
    if (_isRecording) {
      return _buildRecordingOverlay();
    }

    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(accessibilityProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isPatient = (user?.role ?? '').toUpperCase() == 'PATIENT';
    final isDeafPatient = isPatient && ((user?.patientType ?? '').toUpperCase() == 'DEAF' || settings.textOnlyMode);
    // Text-only users never see the microphone.
    final hideMic = isDeafPatient || settings.textOnlyMode;
    final phrases = isDeafPatient ? ref.watch(predefinedMessagesProvider) : const <String>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MfSpace.xs, MfSpace.xs, MfSpace.xs, MfSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDeafPatient && phrases.isNotEmpty) ...[
                // Deaf mode: one-tap quick phrases (send instantly)
                SizedBox(
                  height: MfSize.minTouch,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: MfSpace.xxs),
                    itemCount: phrases.take(6).length,
                    separatorBuilder: (_, __) => const SizedBox(width: MfSpace.xs),
                    itemBuilder: (_, i) {
                      final msg = phrases[i];
                      return Center(
                        child: ActionChip(
                          avatar: const Icon(Icons.send_rounded, size: 16),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          tooltip: 'Send "$msg"',
                          onPressed: _isSending ? null : () => _sendQuickPhrase(msg),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: MfSpace.xxs),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MfIconButton(
                    icon: Icons.add_circle_outline_rounded,
                    tooltip: 'Attach photo, document or location',
                    color: cs.primary,
                    onPressed: _isSending ? null : _showAttachmentOptions,
                  ),
                  if (isDeafPatient)
                    MfIconButton(
                      icon: Icons.quickreply_outlined,
                      tooltip: 'Quick phrases',
                      color: cs.primary,
                      onPressed: _showQuickPhrases,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.sm),
                        border: const OutlineInputBorder(borderRadius: MfRadius.lgAll),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: MfRadius.lgAll,
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MfSpace.xs),
                  _isSending
                      ? const SizedBox(
                          width: MfSize.minTouch,
                          height: MfSize.minTouch,
                          child: Center(
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, child) {
                            final hasText = value.text.trim().isNotEmpty;
                            // Mic only for hearing users with an empty input;
                            // deaf / text-only users always get the send button.
                            final showMic = !hasText && !hideMic;
                            return IconButton.filled(
                              tooltip: showMic ? 'Record voice message' : 'Send message',
                              style: IconButton.styleFrom(
                                minimumSize: const Size(MfSize.minTouch, MfSize.minTouch),
                              ),
                              onPressed: showMic ? _startVoiceRecording : (hasText ? _sendMessage : null),
                              icon: Icon(showMic ? Icons.mic_none_rounded : Icons.send_rounded),
                            );
                          },
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showMfBottomSheet<void>(
      context,
      title: 'Share',
      builder: (ctx) => MfListGroup(
        children: [
          MfIconTile(
            icon: Icons.photo_outlined,
            label: 'Photo',
            subtitle: 'Choose an image from your gallery',
            onTap: _pickImage,
          ),
          MfIconTile(
            icon: Icons.description_outlined,
            label: 'Document',
            subtitle: 'Send a file such as a report or prescription',
            onTap: _pickDocument,
          ),
          MfIconTile(
            icon: Icons.location_on_outlined,
            label: 'Current location',
            subtitle: 'Send a map link to where you are now',
            onTap: _shareLocation,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _isSending = true);
      try {
        final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendFileMessage(File(image.path), MessageType.IMAGE);
        if (!ok) _showSnack('Failed to send image. Please try again.', isError: true);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null && mounted) {
      setState(() => _isSending = true);
      try {
        final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendFileMessage(File(result.files.single.path!), MessageType.DOCUMENT);
        if (!ok) _showSnack('Failed to send document. Please try again.', isError: true);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  /// Shares the current position as a normal TEXT message with a Maps link
  /// (backend MessageType has no LOCATION value).
  Future<void> _shareLocation() async {
    Navigator.pop(context);
    setState(() => _isSending = true);
    try {
      final position = await LocationService().getCurrentLocation();
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      final content = 'My location: https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(content);
      if (!ok) {
        _showSnack('Failed to send location. Please try again.', isError: true);
      } else {
        _scrollToBottom();
      }
    } on LocationException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      debugPrint('Share location failed: $e');
      _showSnack('Could not get your location. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildRecordingOverlay() {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MfSpace.md, vertical: MfSpace.xs),
          child: Semantics(
            liveRegion: true,
            label: 'Recording voice message, $_recordingDuration',
            child: Row(
              children: [
                Icon(Icons.mic_rounded, color: cs.primary),
                const SizedBox(width: MfSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recording', style: text.titleSmall),
                      Text(_recordingDuration, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                MfTextButton(
                  label: 'Discard',
                  icon: Icons.delete_outline_rounded,
                  tone: MfTone.neutral,
                  onPressed: _cancelRecording,
                ),
                const SizedBox(width: MfSpace.xs),
                FilledButton.icon(
                  onPressed: _stopRecording,
                  style: FilledButton.styleFrom(minimumSize: const Size(MfSize.minTouch, MfSize.minTouch)),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startVoiceRecording() async {
    final permission = await _recorderService.requestMicrophonePermission();
    if (!mounted) return;
    if (permission == MicPermissionResult.permanentlyDenied) {
      _showSnack(
        'Microphone access is blocked. Enable it in Settings to send voice messages.',
        isError: true,
        actionLabel: 'Open settings',
        onAction: openAppSettings,
      );
      return;
    }
    if (permission == MicPermissionResult.denied) {
      _showSnack('Microphone permission is required to record a voice message.', isError: true);
      return;
    }

    final success = await _recorderService.startRecording();
    if (!mounted) return;
    if (success) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = '0:00';
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final duration = DateTime.now().difference(_recordingStartTime!);
        setState(() {
          _recordingDuration = '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      });
    } else {
      _showSnack('Could not start recording. Please try again.', isError: true);
    }
  }

  void _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorderService.stopRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isSending = true;
    });
    if (path != null) {
      try {
        final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendVoiceMessage(path);
        if (!ok) _showSnack('Failed to send voice message. Please try again.', isError: true);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      setState(() => _isSending = false);
      _showSnack('Recording failed. Please try again.', isError: true);
    }
  }

  void _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorderService.stopRecording(); // Stop but don't send
    if (mounted) setState(() => _isRecording = false);
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isSending = true;
      _pendingText = content;
    });
    try {
      final ok = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(content);
      if (!mounted) return;
      if (ok) {
        // Only clear the input once the server accepted the message, and only
        // if the user hasn't typed something new meanwhile.
        if (_messageController.text.trim() == content) _messageController.clear();
        _scrollToBottom();
      } else {
        _showSnack('Message not sent. Please check your connection and try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _pendingText = null;
        });
      }
    }
  }

  void _playVoiceNote(String messageId, String? url) async {
    if (url == null) return;

    if (_playingMessageId == messageId) {
      await _audioPlayer.pause();
      setState(() => _playingMessageId = null);
      return;
    }

    try {
      setState(() => _playingMessageId = messageId);
      await _audioPlayer.stop();
      // Server uploads are re-rooted on the current server (tunnel / LAN address may change)
      await _audioPlayer.setUrl(mfResolveImageUrl(url) ?? url);
      // play() completes when playback finishes/pauses; don't block on it.
      unawaited(_audioPlayer.play());
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        setState(() => _playingMessageId = null);
        _showSnack('Could not play voice message', isError: true);
      }
    }
  }
}

/// Outgoing message that has not been confirmed by the server yet.
class _PendingBubble extends StatelessWidget {
  final String text;
  const _PendingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = cs.onPrimary;
    return Semantics(
      liveRegion: true,
      label: 'Sending: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: MfSpace.xs),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(MfRadius.lg),
                  topRight: Radius.circular(MfRadius.lg),
                  bottomLeft: Radius.circular(MfRadius.lg),
                  bottomRight: Radius.circular(MfRadius.sm / 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(MfSpace.sm, MfSpace.xs, MfSpace.sm, MfSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(text, style: t.bodyLarge?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Sending', style: t.labelSmall?.copyWith(color: fg)),
                        const SizedBox(width: MfSpace.xxs),
                        Icon(Icons.schedule_rounded, size: 14, color: fg),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  const _DaySeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : DateFormat('EEE, d MMM yyyy').format(local);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MfSpace.sm),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MfSpace.sm),
            child: Semantics(
              header: true,
              child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

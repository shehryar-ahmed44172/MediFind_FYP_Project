import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';
import '../../../domain/entities/chat_message.dart';
import '../patient/predefined_messages_screen.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../../services/audio/voice_recorder_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../../core/utils/exceptions.dart';
import '../../../services/location/location_service.dart';

final RegExp _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

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
  String? _playingMessageId;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String _recordingDuration = '0:00';
  StreamSubscription<PlayerState>? _playerStateSub;

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

  void _showSnack(String message, {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider).value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.otherUserName ?? 'Chat', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Chat info',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
                      const SizedBox(height: 12),
                      Text(
                        widget.otherUserName ?? 'Chat',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Room: ${widget.roomId}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                
                if (messages.isEmpty) {
                  return const Center(child: Text('Start your conversation...'));
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return _buildMessageBubble(message, isMe, theme);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 56),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load messages',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(chatMessagesProvider(widget.roomId).notifier).fetchMessages(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildMessageInput(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                widget.otherUserName ?? 'Sender',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              boxShadow: isMe 
                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] 
                  : [],
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.messageType == MessageType.TEXT)
                  _buildTextContent(message.content, isMe)
                else if (message.messageType == MessageType.AUDIO)
                  GestureDetector(
                    onTap: () => _playVoiceNote(message.id, message.mediaUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _playingMessageId == message.id ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, 
                          color: isMe ? Colors.white : AppColors.primary, 
                          size: 32
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _playingMessageId == message.id ? 'Playing...' : 'Voice Message', 
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white : Colors.black87
                          )
                        ),
                      ],
                    ),
                  )
                else if (message.messageType == MessageType.DOCUMENT)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : Colors.grey, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.content,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else if (message.messageType == MessageType.IMAGE && message.mediaUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(message.mediaUrl!, width: 200, height: 200, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.createdAt),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(String content, bool isMe) {
    final color = isMe ? Colors.white : Colors.black87;
    final match = _urlRegex.firstMatch(content);
    if (match == null) {
      return Text(content, style: TextStyle(color: color, fontSize: 15));
    }
    final url = match.group(0)!;
    return Semantics(
      link: true,
      label: 'Open link',
      child: InkWell(
        onTap: () => _openLink(url),
        child: Text.rich(
          TextSpan(
            style: TextStyle(color: color, fontSize: 15),
            children: [
              TextSpan(text: content.substring(0, match.start)),
              TextSpan(
                text: url,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: isMe ? Colors.white : AppColors.primary,
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

  void _showQuickPhrases() {
    final messages = ref.read(predefinedMessagesProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hearing_disabled, color: Color(0xFF0C637E)),
                const SizedBox(width: 8),
                const Text('Quick Phrases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (messages.isEmpty)
              const Center(
                child: Text('No phrases saved. Go to Settings → Quick Phrases to add them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C637E).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF0C637E), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Text(messages[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _messageController.text = messages[i];
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: messages[i].length),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF0C637E), size: 20),
                      tooltip: 'Send phrase',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(chatMessagesProvider(widget.roomId).notifier)
                            .sendMessage(messages[i]);
                        if (!ok) _showSnack('Failed to send message. Please try again.', isError: true);
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    if (_isRecording) {
      return _buildRecordingOverlay(theme);
    }

    final settings = ref.watch(accessibilityProvider);
    final isDeaf = settings.textOnlyMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDeaf) ...[
            // Deaf mode: quick phrases shortcut bar
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: ref.watch(predefinedMessagesProvider).take(5).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final msg = ref.watch(predefinedMessagesProvider)[i];
                  return GestureDetector(
                    onTap: () {
                      _messageController.text = msg;
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: msg.length),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C637E).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0C637E).withOpacity(0.2)),
                      ),
                      child: Text(
                        msg.length > 25 ? '${msg.substring(0, 25)}…' : msg,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF0C637E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            tooltip: 'Attach',
            onPressed: _isSending ? null : _showAttachmentOptions,
          ),
          if (isDeaf)
            IconButton(
              icon: const Icon(Icons.hearing_disabled_rounded, color: Color(0xFF2496A7)),
              tooltip: 'Quick Phrases',
              onPressed: _showQuickPhrases,
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  // Deaf/text-only patients cannot use voice recording
                  final canSend = hasText || isDeaf;
                  return Semantics(
                    button: true,
                    label: (hasText || isDeaf) ? 'Send message' : 'Record voice message',
                    child: GestureDetector(
                    onTap: canSend ? (hasText ? _sendMessage : null) : _startVoiceRecording,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (canSend && !hasText)
                            ? AppColors.primary.withOpacity(0.35)
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        // Always show send icon for deaf users; mic only for hearing users
                        (hasText || isDeaf) ? Icons.send_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    ),
                  );
                },
              ),
        ],
      ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentItem(Icons.image_rounded, 'Gallery', Colors.purple, _pickImage),
                _buildAttachmentItem(Icons.description_rounded, 'Document', AppColors.primary, _pickDocument),
                _buildAttachmentItem(Icons.location_on_rounded, 'Location', AppColors.success, _shareLocation),
              ],
            ),
          ],
        ),
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
      final content = '📍 My location: https://www.google.com/maps/search/?api=1&query=$lat,$lng';
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

  Widget _buildRecordingOverlay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Text(_recordingDuration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton(
            onPressed: _cancelRecording,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Send voice message',
            child: GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white),
              ),
            ),
          ),
        ],
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
        action: const SnackBarAction(
          label: 'Open settings',
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
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
    setState(() => _isSending = true);
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
      if (mounted) setState(() => _isSending = false);
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
      await _audioPlayer.setUrl(url);
      // play() completes when playback finishes/pauses; don't block on it.
      unawaited(_audioPlayer.play());
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      if (mounted) {
        setState(() => _playingMessageId = null);
        _showSnack('Could not play voice message', isError: true);
      }
    }
  }

  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
      ),
    );
  }
}

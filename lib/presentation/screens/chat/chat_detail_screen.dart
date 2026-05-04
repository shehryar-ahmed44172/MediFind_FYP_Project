import 'dart:async';
import 'package:flutter/material.dart';
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
import 'dart:io';

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
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
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
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
              error: (e, _) => Center(child: Text('Error: $e')),
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
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  )
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
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(chatMessagesProvider(widget.roomId).notifier)
                            .sendMessage(messages[i]);
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
            onPressed: _showAttachmentOptions,
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
                  return GestureDetector(
                    onTap: hasText ? _sendMessage : _startVoiceRecording,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 24,
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
                _buildAttachmentItem(Icons.description_rounded, 'Document', Colors.blue, _pickDocument),
                _buildAttachmentItem(Icons.location_on_rounded, 'Location', Colors.green, () {}),
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
    if (image != null) {
      setState(() => _isSending = true);
      try {
        await ref.read(chatMessagesProvider(widget.roomId).notifier).sendFileMessage(File(image.path), MessageType.IMAGE);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _isSending = true);
      try {
        await ref.read(chatMessagesProvider(widget.roomId).notifier).sendFileMessage(File(result.files.single.path!), MessageType.DOCUMENT);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    }
  }

  Widget _buildRecordingOverlay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Text(_recordingDuration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          TextButton(
            onPressed: _cancelRecording,
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _startVoiceRecording() async {
    final success = await _recorderService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _recordingDuration = '0:00';
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        setState(() {
          _recordingDuration = '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      });
    }
  }

  void _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorderService.stopRecording();
    setState(() {
      _isRecording = false;
      _isSending = true;
    });
    if (path != null) {
      try {
        await ref.read(chatMessagesProvider(widget.roomId).notifier).sendVoiceMessage(path);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      setState(() => _isSending = false);
    }
  }

  void _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorderService.stopRecording(); // Stop but don't send
    setState(() => _isRecording = false);
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(content);
      _messageController.clear();
      _scrollToBottom();
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
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingMessageId = null);
        }
      });
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      if (mounted) setState(() => _playingMessageId = null);
    }
  }

  Widget _buildAttachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
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
    );
  }
}

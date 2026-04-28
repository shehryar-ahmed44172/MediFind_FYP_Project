import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../services/socket/socket_service.dart';
import 'auth_provider.dart';
import 'emergency_provider.dart';
import '../../presentation/services/haptic_feedback_service.dart';

// Repository Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepositoryImpl(apiClient: apiClient);
});

// Chat Rooms Provider
final chatRoomsProvider = FutureProvider.autoDispose<List<ChatRoom>>((ref) async {
  // Ensure auth is initialized
  await ref.watch(authRepositoryProvider.future);
  
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getChatRooms();
});

// Messages Provider
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>((ref, roomId) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatMessagesNotifier(repo, roomId, ref);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repo;
  final String _roomId;
  final Ref _ref;

  ChatMessagesNotifier(this._repo, this._roomId, this._ref) : super(const AsyncValue.loading()) {
    fetchMessages();
    _listenToSocket();
  }

  Future<void> fetchMessages() async {
    try {
      // Ensure auth is initialized before fetching (prevents race condition on startup)
      await _ref.read(authRepositoryProvider.future);
      
      final messages = await _repo.getChatMessages(_roomId);
      state = AsyncValue.data(messages);
      
      // Join room via socket
      SocketService.instance.joinChatRoom(_roomId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void _listenToSocket() {
    // Listen to global socket stream via another provider or service
    _ref.listen<AsyncValue<SocketMessage>>(socketStreamProvider, (prev, next) {
      next.whenData((message) {
        if (message.event == SocketEvent.newMessage) {
          final data = message.data;
          if (data['roomId'] == _roomId) {
            final newMessage = ChatMessage.fromJson(data);
            
            // Check if already exists to avoid duplicates
            final currentMessages = state.value ?? [];
            if (!currentMessages.any((m) => m.id == newMessage.id)) {
              state = AsyncValue.data([...currentMessages, newMessage]);
              
              // Haptic feedback for incoming message
              if (newMessage.senderId != _ref.read(currentUserIdProvider).value) {
                HapticFeedbackService.light();
              }
            }
          }
        }
      });
    });
  }
  Future<void> sendMessage(String content, {MessageType type = MessageType.TEXT}) async {
    try {
      final message = await _repo.sendMessage(_roomId, content, type: type);
      
      final currentMessages = state.value ?? [];
      if (!currentMessages.any((m) => m.id == message.id)) {
        state = AsyncValue.data([...currentMessages, message]);
      }
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
    }
  }

  Future<void> sendVoiceMessage(String filePath) async {
    try {
      final mediaUrl = await _repo.uploadFile(File(filePath));
      final message = await _repo.sendMessage(_roomId, 'Voice Message', type: MessageType.AUDIO, mediaUrl: mediaUrl);
      
      final currentMessages = state.value ?? [];
      if (!currentMessages.any((m) => m.id == message.id)) {
        state = AsyncValue.data([...currentMessages, message]);
      }
    } catch (e) {
      debugPrint('❌ Error sending voice message: $e');
    }
  }

  Future<void> sendFileMessage(File file, MessageType type) async {
    try {
      final mediaUrl = await _repo.uploadFile(file);
      final filename = file.path.split('/').last;
      final message = await _repo.sendMessage(_roomId, filename, type: type, mediaUrl: mediaUrl);
      
      final currentMessages = state.value ?? [];
      if (!currentMessages.any((m) => m.id == message.id)) {
        state = AsyncValue.data([...currentMessages, message]);
      }
    } catch (e) {
      debugPrint('❌ Error sending file message: $e');
    }
  }

  @override
  void dispose() {
    SocketService.instance.leaveChatRoom(_roomId);
    super.dispose();
  }
}

// Provider to get/create a room for a specific caregiver/patient
final getChatRoomForUserProvider = FutureProvider.family<ChatRoom, String>((ref, targetUserId) async {
  // Ensure auth is initialized
  await ref.watch(authRepositoryProvider.future);
  
  final repo = ref.watch(chatRepositoryProvider);
  return repo.createOrGetChatRoom(targetUserId);
});

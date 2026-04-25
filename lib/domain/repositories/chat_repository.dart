import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getChatRooms();
  Future<List<ChatMessage>> getChatMessages(String roomId);
  Future<ChatMessage> sendMessage(String roomId, String content, {MessageType type = MessageType.TEXT, String? mediaUrl});
  Future<ChatRoom> createOrGetChatRoom(String targetUserId);
}

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/remote/medifind_api_client.dart';

class ChatRepositoryImpl implements ChatRepository {
  final MediFindApiClient apiClient;

  ChatRepositoryImpl({required this.apiClient});

  @override
  Future<List<ChatRoom>> getChatRooms() async {
    final response = await apiClient.getChatRooms();
    return response.map((e) => ChatRoom.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String roomId) async {
    final response = await apiClient.getChatMessages(roomId);
    return response.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChatMessage> sendMessage(String roomId, String content, {MessageType type = MessageType.TEXT, String? mediaUrl}) async {
    final response = await apiClient.sendMessage({
      'roomId': roomId,
      'content': content,
      'messageType': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
    });
    return ChatMessage.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<ChatRoom> createOrGetChatRoom(String targetUserId) async {
    final response = await apiClient.createOrGetChatRoom(targetUserId);
    return ChatRoom.fromJson(response as Map<String, dynamic>);
  }
}

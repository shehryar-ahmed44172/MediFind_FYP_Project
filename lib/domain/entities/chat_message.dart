import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

enum MessageType {
  @JsonValue('TEXT') TEXT,
  @JsonValue('IMAGE') IMAGE,
  @JsonValue('AUDIO') AUDIO,
  @JsonValue('VOICE_ALERT') VOICE_ALERT
}

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String roomId,
    required String senderId,
    required String content,
    @Default(MessageType.TEXT) MessageType messageType,
    String? mediaUrl,
    @Default(false) bool isRead,
    required DateTime createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

@freezed
class ChatRoom with _$ChatRoom {
  const factory ChatRoom({
    required String id,
    required String patientId,
    required String caregiverId,
    required DateTime createdAt,
    required DateTime updatedAt,
    Map<String, dynamic>? patient,
    Map<String, dynamic>? caregiver,
    List<ChatMessage>? messages,
  }) = _ChatRoom;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => _$ChatRoomFromJson(json);
}

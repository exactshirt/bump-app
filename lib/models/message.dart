/// Message Model
///
/// Represents a chat message in a conversation
class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final String messageType; // text, image, location
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatRoomId: json['chat_room_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isFromUser(String userId) => senderId == userId;

  Message copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? content,
    String? messageType,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

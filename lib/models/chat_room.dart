/// Chat Room Model
///
/// Represents a chat conversation between two users
class ChatRoom {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  ChatRoom({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    this.lastMessageAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  /// Get the other user's ID (not the current user)
  String getOtherUserId(String currentUserId) {
    return user1Id == currentUserId ? user2Id : user1Id;
  }
}

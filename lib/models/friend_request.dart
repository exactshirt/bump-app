import 'user_profile.dart';

/// Friend Request Model
///
/// Represents a friend request between two users
class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}

/// Extended Friend Request with Profile Information
class FriendRequestWithProfile {
  final FriendRequest request;
  final UserProfile profile;

  FriendRequestWithProfile({
    required this.request,
    required this.profile,
  });
}

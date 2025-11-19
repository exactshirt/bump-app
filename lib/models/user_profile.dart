/// User Profile Model
///
/// Represents a user's profile with display information and interests
class UserProfile {
  final String id;
  final String userId;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final List<String> interests;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    required this.interests,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'interests': interests,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
    List<String>? interests,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      interests: interests ?? this.interests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

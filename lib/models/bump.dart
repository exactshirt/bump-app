class Bump {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime bumpedAt;

  Bump({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.bumpedAt,
  });

  factory Bump.fromJson(Map<String, dynamic> json) {
    return Bump(
      id: json['id'],
      user1Id: json['user1_id'],
      user2Id: json['user2_id'],
      bumpedAt: DateTime.parse(json['bumped_at']),
    );
  }
}

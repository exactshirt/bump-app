class Bump {
  final String id;
  final String userAId;
  final String userBId;
  final DateTime bumpedAt;

  Bump({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.bumpedAt,
  });

  factory Bump.fromJson(Map<String, dynamic> json) {
    return Bump(
      id: json['bump_id'],
      userAId: json['user_a_id'],
      userBId: json['user_b_id'],
      bumpedAt: DateTime.parse(json['bumped_at']),
    );
  }
}

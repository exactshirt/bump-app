class Bump {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime timestamp;

  Bump({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.timestamp,
  });

  factory Bump.fromJson(Map<String, dynamic> json) {
    return Bump(
      id: json['id'],
      user1Id: json['user1_id'],
      user2Id: json['user2_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

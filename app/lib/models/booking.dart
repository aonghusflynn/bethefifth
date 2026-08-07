class Booking {
  final String id;
  final String gameId;
  final String playerId;
  final String status;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.gameId,
    required this.playerId,
    this.status = 'confirmed',
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      playerId: json['player_id'] as String,
      status: json['status'] as String? ?? 'confirmed',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'game_id': gameId,
        'player_id': playerId,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

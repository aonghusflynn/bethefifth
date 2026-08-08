class Game {
  final String id;
  final String organiserId;
  final String venueId;

  /// Set when this game was materialised from a recurring series; null for
  /// one-offs.
  final String? seriesId;

  final String title;
  final String? description;
  final DateTime startsAt;
  final int durationMinutes;
  final int maxPlayers;
  final int currentPlayers;
  final int skillLevel;
  final String status;
  final bool isRecurring;
  final bool isPrivate;

  /// `squad_only` games are reserved for the organiser's squad and hidden from
  /// marketplace discovery; `public` games are open to anyone.
  final String visibility;

  /// When the game reached the marketplace, whether opened by the organiser or
  /// automatically because it was still short close to kick-off.
  final DateTime? marketplaceOpenedAt;

  /// Set once the "still needs players" push has gone out.
  final DateTime? marketplaceNotifiedAt;

  final int? costPerPlayer;
  final String? currency;

  const Game({
    required this.id,
    required this.organiserId,
    required this.venueId,
    this.seriesId,
    required this.title,
    this.description,
    required this.startsAt,
    this.durationMinutes = 60,
    this.maxPlayers = 10,
    this.currentPlayers = 0,
    this.skillLevel = 3,
    this.status = 'open',
    this.isRecurring = false,
    this.isPrivate = false,
    this.visibility = 'public',
    this.marketplaceOpenedAt,
    this.marketplaceNotifiedAt,
    this.costPerPlayer,
    this.currency,
  });

  bool get isSquadOnly => visibility == 'squad_only';
  bool get isFull => currentPlayers >= maxPlayers;
  int get slotsLeft => (maxPlayers - currentPlayers).clamp(0, maxPlayers);

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      organiserId: json['organiser_id'] as String,
      venueId: json['venue_id'] as String,
      seriesId: json['series_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      maxPlayers: json['max_players'] as int? ?? 10,
      currentPlayers: json['current_players'] as int? ?? 0,
      skillLevel: json['skill_level'] as int? ?? 3,
      status: json['status'] as String? ?? 'open',
      isRecurring: json['is_recurring'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'public',
      marketplaceOpenedAt: json['marketplace_opened_at'] == null
          ? null
          : DateTime.parse(json['marketplace_opened_at'] as String),
      marketplaceNotifiedAt: json['marketplace_notified_at'] == null
          ? null
          : DateTime.parse(json['marketplace_notified_at'] as String),
      costPerPlayer: json['cost_per_player'] as int?,
      currency: json['currency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organiser_id': organiserId,
        'venue_id': venueId,
        'series_id': seriesId,
        'title': title,
        'description': description,
        'starts_at': startsAt.toIso8601String(),
        'duration_minutes': durationMinutes,
        'max_players': maxPlayers,
        'current_players': currentPlayers,
        'skill_level': skillLevel,
        'status': status,
        'is_recurring': isRecurring,
        'is_private': isPrivate,
        'visibility': visibility,
        'marketplace_opened_at': marketplaceOpenedAt?.toIso8601String(),
        'marketplace_notified_at': marketplaceNotifiedAt?.toIso8601String(),
        'cost_per_player': costPerPlayer,
        'currency': currency,
      };
}

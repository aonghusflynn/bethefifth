/// A recurring fixture definition — "Tuesdays 7pm at Irishtown".
///
/// Nobody books a series. The backend materialises individual [Game] rows from
/// it ahead of time, and those are what players respond to.
class GameSeries {
  final String id;
  final String organiserId;
  final String venueId;
  final String? squadId;
  final String title;
  final String? description;

  /// First occurrence. Also supplies the time of day for every later instance.
  final DateTime startsAt;

  /// iCalendar RRULE, e.g. `FREQ=WEEKLY;BYDAY=TU`.
  final String rrule;

  final int durationMinutes;
  final int maxPlayers;
  final int skillLevel;
  final bool isActive;

  const GameSeries({
    required this.id,
    required this.organiserId,
    required this.venueId,
    this.squadId,
    required this.title,
    this.description,
    required this.startsAt,
    required this.rrule,
    this.durationMinutes = 60,
    this.maxPlayers = 10,
    this.skillLevel = 3,
    this.isActive = true,
  });

  factory GameSeries.fromJson(Map<String, dynamic> json) {
    return GameSeries(
      id: json['id'] as String,
      organiserId: json['organiser_id'] as String,
      venueId: json['venue_id'] as String,
      squadId: json['squad_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      rrule: json['rrule'] as String,
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      maxPlayers: json['max_players'] as int? ?? 10,
      skillLevel: json['skill_level'] as int? ?? 3,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// The recurrence patterns the create-series UI offers.
///
/// Kept to a small set on purpose — arbitrary RRULE authoring is a power-user
/// feature, and weekly five-a-side covers nearly every real case.
enum RecurrencePattern {
  weekly('FREQ=WEEKLY'),
  fortnightly('FREQ=WEEKLY;INTERVAL=2'),
  monthly('FREQ=MONTHLY');

  const RecurrencePattern(this.rrule);
  final String rrule;

  static RecurrencePattern fromRrule(String rrule) {
    return RecurrencePattern.values.firstWhere(
      (p) => p.rrule == rrule,
      orElse: () => RecurrencePattern.weekly,
    );
  }
}

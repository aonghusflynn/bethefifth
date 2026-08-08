/// One player's membership of a squad.
///
/// [userId] is null for someone the organiser invited by email who hasn't
/// registered yet — the backend links them to a real account on sign-up.
class SquadMember {
  final String id;
  final String squadId;
  final String? userId;
  final String displayName;
  final String? inviteEmail;
  final String? invitePhone;
  final String status; // invited, active
  final DateTime createdAt;

  const SquadMember({
    required this.id,
    required this.squadId,
    this.userId,
    required this.displayName,
    this.inviteEmail,
    this.invitePhone,
    this.status = 'invited',
    required this.createdAt,
  });

  /// True while this member has no BeTheFifth account yet. They can't be
  /// invited to individual matches until they register.
  bool get isPending => userId == null;

  factory SquadMember.fromJson(Map<String, dynamic> json) {
    return SquadMember(
      id: json['id'] as String,
      squadId: json['squad_id'] as String,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String,
      inviteEmail: json['invite_email'] as String?,
      invitePhone: json['invite_phone'] as String?,
      status: json['status'] as String? ?? 'invited',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// An organiser's persistent pool of regular players.
///
/// Deliberately allowed to be larger than a game's capacity — everyone is
/// invited to each match and slots go first-come-first-served.
class Squad {
  final String id;
  final String organiserId;
  final String name;
  final DateTime createdAt;

  /// Only populated by the detail endpoint. The list endpoint omits members
  /// and sends counts instead, so never derive counts from this — use
  /// [activeCount] / [pendingCount].
  final List<SquadMember> members;

  final int activeCount;
  final int pendingCount;

  const Squad({
    required this.id,
    required this.organiserId,
    required this.name,
    required this.createdAt,
    this.members = const [],
    this.activeCount = 0,
    this.pendingCount = 0,
  });

  factory Squad.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>?;
    final members = rawMembers == null
        ? const <SquadMember>[]
        : rawMembers
            .map((e) => SquadMember.fromJson(e as Map<String, dynamic>))
            .toList();

    return Squad(
      id: json['id'] as String,
      organiserId: json['organiser_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      members: members,
      activeCount: json['active_member_count'] as int? ??
          members.where((m) => !m.isPending).length,
      pendingCount: json['pending_member_count'] as int? ??
          members.where((m) => m.isPending).length,
    );
  }
}

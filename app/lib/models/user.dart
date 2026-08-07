class BtfUser {
  final String id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? position;
  final int skillLevel;
  final double reliabilityScore;
  final bool isOrganiser;
  final String locale;
  final String plan;

  const BtfUser({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.position,
    this.skillLevel = 3,
    this.reliabilityScore = 5.0,
    this.isOrganiser = false,
    this.locale = 'en',
    this.plan = 'free',
  });

  factory BtfUser.fromJson(Map<String, dynamic> json) {
    return BtfUser(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      position: json['position'] as String?,
      skillLevel: json['skill_level'] as int? ?? 3,
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble() ?? 5.0,
      isOrganiser: json['is_organiser'] as bool? ?? false,
      locale: json['locale'] as String? ?? 'en',
      plan: json['plan'] as String? ?? 'free',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firebase_uid': firebaseUid,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'position': position,
        'skill_level': skillLevel,
        'reliability_score': reliabilityScore,
        'is_organiser': isOrganiser,
        'locale': locale,
        'plan': plan,
      };
}

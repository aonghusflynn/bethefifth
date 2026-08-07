class Venue {
  final String id;
  final String name;
  final String address;
  final String city;
  final String country;
  final double lat;
  final double lng;
  final String? surface;
  final String? pitchSize;
  final bool? parking;
  final String? photoUrl;

  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.country = 'Ireland',
    required this.lat,
    required this.lng,
    this.surface,
    this.pitchSize,
    this.parking,
    this.photoUrl,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      country: json['country'] as String? ?? 'Ireland',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      surface: json['surface'] as String?,
      pitchSize: json['pitch_size'] as String?,
      parking: json['parking'] as bool?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'country': country,
        'lat': lat,
        'lng': lng,
        'surface': surface,
        'pitch_size': pitchSize,
        'parking': parking,
        'photo_url': photoUrl,
      };
}

class MatchingPreferences {
  const MatchingPreferences({
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.distanceKm,
    required this.purpose,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String lookingFor;
  final double minAge;
  final double maxAge;
  final int distanceKm;
  final String purpose;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return hasLocation ? 'Konum alındı' : 'Konum yok';
  }

  String get distanceLabel =>
      distanceKm == 100 ? 'Mesafe fark etmez' : '$distanceKm km';

  String get ageLabel => '${minAge.round()}–${maxAge.round()} yaş';

  String get compactSummary => '$lookingFor · $ageLabel · $distanceLabel';

  MatchingPreferences copyWith({
    String? lookingFor,
    double? minAge,
    double? maxAge,
    int? distanceKm,
    String? purpose,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return MatchingPreferences(
      lookingFor: lookingFor ?? this.lookingFor,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      distanceKm: distanceKm ?? this.distanceKm,
      purpose: purpose ?? this.purpose,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

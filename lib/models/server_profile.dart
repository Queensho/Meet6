import 'matching_preferences.dart';

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.bio,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.prompt,
    required this.promptAnswer,
    required this.interests,
    required this.photoUrls,
    required this.profileCompleted,
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.distanceKm,
    required this.purpose,
  });

  final String id;
  final String name;
  final String birthDate;
  final String gender;
  final String bio;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final String prompt;
  final String promptAnswer;
  final List<String> interests;
  final List<String> photoUrls;
  final bool profileCompleted;
  final String lookingFor;
  final double minAge;
  final double maxAge;
  final int distanceKm;
  final String purpose;

  int get age {
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return 0;
    final now = DateTime.now();
    var value = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      value--;
    }
    return value < 0 ? 0 : value;
  }

  MatchingPreferences get preferences => MatchingPreferences(
        lookingFor: lookingFor,
        minAge: minAge,
        maxAge: maxAge,
        distanceKm: distanceKm,
        purpose: purpose,
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );

  factory ServerProfile.fromUser(Map<String, dynamic> user) {
    double toDouble(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList(growable: false);
      }
      return const [];
    }

    return ServerProfile(
      id: user['id']?.toString() ?? '',
      name: user['display_name']?.toString() ?? '',
      birthDate: user['birth_date']?.toString() ?? '',
      gender: user['gender']?.toString() ?? '',
      bio: user['bio']?.toString() ?? '',
      city: user['city']?.toString() ?? '',
      country: user['country']?.toString() ?? '',
      latitude: user['latitude'] == null
          ? null
          : toDouble(user['latitude'], 0),
      longitude: user['longitude'] == null
          ? null
          : toDouble(user['longitude'], 0),
      prompt: user['profile_prompt']?.toString() ?? '',
      promptAnswer: user['profile_answer']?.toString() ?? '',
      interests: toStringList(user['interests']),
      photoUrls: toStringList(user['photo_urls']),
      profileCompleted: user['profile_completed'] == true,
      lookingFor: user['looking_for']?.toString() ?? 'Herkes',
      minAge: toDouble(user['min_age'], 20),
      maxAge: toDouble(user['max_age'], 35),
      distanceKm: toDouble(user['distance_km'], 25).round(),
      purpose: user['purpose']?.toString() ?? 'Yeni insanlarla tanışma',
    );
  }
}

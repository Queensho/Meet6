import 'package:shared_preferences/shared_preferences.dart';

class SavedSession {
  const SavedSession({
    required this.profileName,
    required this.city,
    required this.country,
    required this.distanceKm,
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.purpose,
    this.latitude,
    this.longitude,
  });

  final String profileName;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final int distanceKm;
  final String lookingFor;
  final double minAge;
  final double maxAge;
  final String purpose;
}

class SessionService {
  const SessionService._();

  static const _completedKey = 'meet6_profile_completed';
  static const _nameKey = 'meet6_profile_name';
  static const _cityKey = 'meet6_city';
  static const _countryKey = 'meet6_country';
  static const _latitudeKey = 'meet6_latitude';
  static const _longitudeKey = 'meet6_longitude';
  static const _distanceKey = 'meet6_distance_km';
  static const _lookingForKey = 'meet6_looking_for';
  static const _minAgeKey = 'meet6_min_age';
  static const _maxAgeKey = 'meet6_max_age';
  static const _purposeKey = 'meet6_purpose';

  static Future<void> saveProfile({
    required String profileName,
    required String city,
    required String country,
    required double? latitude,
    required double? longitude,
    required int distanceKm,
    required String lookingFor,
    required double minAge,
    required double maxAge,
    required String purpose,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_nameKey, profileName);
    await prefs.setString(_cityKey, city);
    await prefs.setString(_countryKey, country);
    await prefs.setInt(_distanceKey, distanceKm);
    await prefs.setString(_lookingForKey, lookingFor);
    await prefs.setDouble(_minAgeKey, minAge);
    await prefs.setDouble(_maxAgeKey, maxAge);
    await prefs.setString(_purposeKey, purpose);

    if (latitude == null) {
      await prefs.remove(_latitudeKey);
    } else {
      await prefs.setDouble(_latitudeKey, latitude);
    }

    if (longitude == null) {
      await prefs.remove(_longitudeKey);
    } else {
      await prefs.setDouble(_longitudeKey, longitude);
    }

    await prefs.setBool(_completedKey, true);
  }

  static Future<SavedSession?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_completedKey) ?? false)) return null;

    final name = prefs.getString(_nameKey)?.trim() ?? '';
    if (name.isEmpty) return null;

    return SavedSession(
      profileName: name,
      city: prefs.getString(_cityKey) ?? '',
      country: prefs.getString(_countryKey) ?? '',
      latitude: prefs.getDouble(_latitudeKey),
      longitude: prefs.getDouble(_longitudeKey),
      distanceKm: prefs.getInt(_distanceKey) ?? 25,
      lookingFor: prefs.getString(_lookingForKey) ?? 'Herkes',
      minAge: prefs.getDouble(_minAgeKey) ?? 20,
      maxAge: prefs.getDouble(_maxAgeKey) ?? 35,
      purpose: prefs.getString(_purposeKey) ?? 'Yeni insanlarla tanışma',
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_countryKey);
    await prefs.remove(_latitudeKey);
    await prefs.remove(_longitudeKey);
    await prefs.remove(_distanceKey);
    await prefs.remove(_lookingForKey);
    await prefs.remove(_minAgeKey);
    await prefs.remove(_maxAgeKey);
    await prefs.remove(_purposeKey);
  }
}

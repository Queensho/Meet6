import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;

  String get label {
    if (city.isEmpty && country.isEmpty) return 'Konum alındı';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  const LocationService();

  Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Konum servisi kapalı. Devam etmek için cihaz konumunu aç.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Meet6 yakınındaki odaları bulmak için konum iznine ihtiyaç duyuyor.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Konum izni kalıcı olarak kapalı. Tarayıcı veya cihaz ayarlarından Meet6 için konumu aç.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    final address = await _reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: address.$1,
      country: address.$2,
    );
  }

  Future<(String, String)> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '10',
          'addressdetails': '1',
          'accept-language': 'tr',
        },
      );

      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return ('', '');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (json['address'] as Map<String, dynamic>?) ?? const {};

      final city = _firstNonEmpty([
        address['city'],
        address['town'],
        address['municipality'],
        address['village'],
        address['county'],
        address['state_district'],
        address['state'],
      ]);
      final country = _firstNonEmpty([address['country']]);

      return (city, country);
    } catch (_) {
      return ('', '');
    }
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

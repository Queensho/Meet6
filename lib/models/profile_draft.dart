class ProfileDraft {
  String name = '';
  String birthDate = '';
  String? gender;
  bool mainPhotoSelected = false;

  String? lookingFor;
  double minAge = 20;
  double maxAge = 35;
  String city = '';
  String country = '';
  double? latitude;
  double? longitude;
  int distanceKm = 25;
  String? purpose;

  String bio = '';
  int extraPhotoCount = 0;
  final Set<String> interests = <String>{};
  String prompt = 'Benimle iyi anlaşmanın yolu...';
  String promptAnswer = '';

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel {
    if (city.isEmpty && country.isEmpty) {
      return hasLocation ? 'Konum alındı' : '';
    }
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }
}

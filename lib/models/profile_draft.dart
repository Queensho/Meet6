class ProfileDraft {
  String name = '';
  String birthDate = '';
  String? gender;
  bool mainPhotoSelected = false;

  String? lookingFor;
  double minAge = 20;
  double maxAge = 35;
  String city = '';
  int distanceKm = 25;
  String? purpose;

  String bio = '';
  int extraPhotoCount = 0;
  final Set<String> interests = <String>{};
  String prompt = 'Benimle iyi anlaşmanın yolu...';
  String promptAnswer = '';
}

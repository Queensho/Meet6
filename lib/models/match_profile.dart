class MatchProfile {
  const MatchProfile({
    required this.name,
    required this.age,
    required this.city,
    required this.initial,
    required this.bio,
    required this.interests,
    required this.prompt,
    required this.promptAnswer,
    required this.matchedAt,
    this.isOnline = false,
  });

  final String name;
  final int age;
  final String city;
  final String initial;
  final String bio;
  final List<String> interests;
  final String prompt;
  final String promptAnswer;
  final String matchedAt;
  final bool isOnline;
}

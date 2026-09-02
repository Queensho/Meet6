import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';
import '../../widgets/phone_frame.dart';

class EditProfileResult {
  const EditProfileResult({
    required this.name,
    required this.age,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.bio,
    required this.interests,
    required this.prompt,
    required this.promptAnswer,
    required this.lookingFor,
    required this.distanceKm,
    required this.purpose,
  });

  final String name;
  final int age;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final String bio;
  final List<String> interests;
  final String prompt;
  final String promptAnswer;
  final String lookingFor;
  final int distanceKm;
  final String purpose;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initial,
  });

  final EditProfileResult initial;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final locationService = const LocationService();

  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController bioController;
  late final TextEditingController answerController;
  late Set<String> interests;
  late String prompt;
  late String lookingFor;
  late int distanceKm;
  late String purpose;
  late String city;
  late String country;
  late double? latitude;
  late double? longitude;
  bool locationLoading = false;
  String? locationError;

  static const interestOptions = [
    'Kahve',
    'Spor',
    'Seyahat',
    'Müzik',
    'Sinema',
    'Oyun',
    'Yemek',
    'Doğa',
    'Teknoloji',
    'Kitap',
  ];

  static const promptOptions = [
    'Benimle iyi anlaşmanın yolu...',
    'Birlikte kesin yapmalıyız...',
    'Beni en çok güldüren şey...',
    'İlk buluşmada ideal planım...',
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    nameController = TextEditingController(text: i.name);
    ageController = TextEditingController(text: '${i.age}');
    bioController = TextEditingController(text: i.bio);
    answerController = TextEditingController(text: i.promptAnswer);
    interests = i.interests.toSet();
    prompt = i.prompt;
    lookingFor = i.lookingFor;
    distanceKm = i.distanceKm;
    purpose = i.purpose;
    city = i.city;
    country = i.country;
    latitude = i.latitude;
    longitude = i.longitude;
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    answerController.dispose();
    super.dispose();
  }

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return hasLocation ? 'Konum alındı' : 'Konum yok';
  }

  bool get canSave =>
      nameController.text.trim().length >= 2 &&
      int.tryParse(ageController.text) != null &&
      hasLocation &&
      bioController.text.trim().length >= 3 &&
      interests.isNotEmpty &&
      answerController.text.trim().length >= 3;

  Future<void> _refreshLocation() async {
    if (locationLoading) return;
    setState(() {
      locationLoading = true;
      locationError = null;
    });

    try {
      final location = await locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        city = location.city;
        country = location.country;
        latitude = location.latitude;
        longitude = location.longitude;
        locationLoading = false;
      });
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        locationLoading = false;
        locationError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationLoading = false;
        locationError = 'Konum güncellenemedi. Tekrar dene.';
      });
    }
  }

  void _save() {
    if (!canSave) return;
    Navigator.of(context).pop(
      EditProfileResult(
        name: nameController.text.trim(),
        age: int.parse(ageController.text),
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
        bio: bioController.text.trim(),
        interests: interests.toList(),
        prompt: prompt,
        promptAnswer: answerController.text.trim(),
        lookingFor: lookingFor,
        distanceKm: distanceKm,
        purpose: purpose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: PhoneFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Profili düzenle',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: canSave ? _save : null,
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              nameController.text.trim().isEmpty
                                  ? 'M'
                                  : nameController.text.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.lime,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: InkWell(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fotoğraf seçici backend aşamasında bağlanacak.'),
                                ),
                              ),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.lime,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const FieldLabel('Ad'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: 'Adın',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Yaş'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: '28',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Konum'),
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withOpacity(.28),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: AppColors.navy.withOpacity(.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                            child: locationLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.navy,
                                  ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locationLabel,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  locationError ??
                                      'Şehir elle değiştirilemez. Güncel konumundan otomatik alınır.',
                                  style: TextStyle(
                                    color: locationError == null
                                        ? AppColors.muted
                                        : const Color(0xFFD34B42),
                                    fontSize: 10.8,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: locationLoading ? null : _refreshLocation,
                            child: const Text(
                              'Güncelle',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Hakkımda'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: bioController,
                      maxLength: 120,
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: 'Kendini anlat...',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const FieldLabel('İlgi alanları'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in interestOptions)
                          SelectChip(
                            label: item,
                            selected: interests.contains(item),
                            onTap: () => setState(() {
                              if (interests.contains(item)) {
                                interests.remove(item);
                              } else if (interests.length < 5) {
                                interests.add(item);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Profil sorusu'),
                    const SizedBox(height: 7),
                    DropdownButtonFormField<String>(
                      value: prompt,
                      isExpanded: true,
                      decoration: meet6InputDecoration(
                        hint: 'Soru seç',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      items: promptOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => prompt = value ?? prompt),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerController,
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: 'Cevabın',
                        icon: Icons.edit_note_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('Kimlerle tanışmak istiyorsun?'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const ['Kadınlar', 'Erkekler', 'Herkes'])
                          SelectChip(
                            label: item,
                            selected: lookingFor == item,
                            onTap: () => setState(() => lookingFor = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const FieldLabel('Konumuna göre maksimum mesafe'),
                        const Spacer(),
                        Text(
                          distanceKm == 100 ? 'Fark etmez' : '$distanceKm km',
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: distanceKm.toDouble(),
                      min: 5,
                      max: 100,
                      divisions: 19,
                      onChanged: (value) =>
                          setState(() => distanceKm = value.round()),
                    ),
                    const FieldLabel('Tanışma amacı'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const [
                          'Ciddi ilişki',
                          'Flört',
                          'Yeni insanlarla tanışma',
                          'Akışına bırakıyorum',
                        ])
                          SelectChip(
                            label: item,
                            selected: purpose == item,
                            onTap: () => setState(() => purpose = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Değişiklikleri kaydet',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

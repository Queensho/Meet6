import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';
import '../../widgets/phone_frame.dart';

class MatchingPreferencesScreen extends StatefulWidget {
  const MatchingPreferencesScreen({
    super.key,
    required this.initial,
  });

  final MatchingPreferences initial;

  @override
  State<MatchingPreferencesScreen> createState() =>
      _MatchingPreferencesScreenState();
}

class _MatchingPreferencesScreenState extends State<MatchingPreferencesScreen> {
  final locationService = const LocationService();

  late String lookingFor;
  late double minAge;
  late double maxAge;
  late int distanceKm;
  late String purpose;
  late String city;
  late String country;
  late double? latitude;
  late double? longitude;

  bool locationLoading = false;
  String? locationError;

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel {
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (city.isNotEmpty) return city;
    if (country.isNotEmpty) return country;
    return hasLocation ? 'Konum alındı' : 'Konum yok';
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    lookingFor = p.lookingFor;
    minAge = p.minAge;
    maxAge = p.maxAge;
    distanceKm = p.distanceKm;
    purpose = p.purpose;
    city = p.city;
    country = p.country;
    latitude = p.latitude;
    longitude = p.longitude;
  }

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
    if (!hasLocation) return;
    Navigator.of(context).pop(
      MatchingPreferences(
        lookingFor: lookingFor,
        minAge: minAge,
        maxAge: maxAge,
        distanceKm: distanceKm,
        purpose: purpose,
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                      'Eşleşme tercihleri',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withOpacity(.36),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.navy.withOpacity(.08),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppColors.blue,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Odaya gireceğin kişiler bu tercihlere ve gerçek konumuna göre seçilir.',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const FieldLabel('Konumun'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                            child: locationLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: AppColors.navy,
                                    ),
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
                                      'Şehir ve ülke konum izninden otomatik alınır.',
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
                    const SizedBox(height: 22),
                    const FieldLabel('Kimlerle tanışmak istiyorsun?'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const [
                          'Kadınlar',
                          'Erkekler',
                          'Herkes',
                        ])
                          SelectChip(
                            label: item,
                            selected: lookingFor == item,
                            onTap: () => setState(() => lookingFor = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const FieldLabel('Yaş aralığı'),
                        const Spacer(),
                        Text(
                          '${minAge.round()} – ${maxAge.round()}',
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(minAge, maxAge),
                      min: 18,
                      max: 65,
                      divisions: 47,
                      activeColor: AppColors.blue,
                      inactiveColor: AppColors.border,
                      labels: RangeLabels(
                        '${minAge.round()}',
                        '${maxAge.round()}',
                      ),
                      onChanged: (values) => setState(() {
                        minAge = values.start;
                        maxAge = values.end;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const FieldLabel('Maksimum mesafe'),
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
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in const [10, 25, 50, 100])
                          SelectChip(
                            label: value == 100 ? 'Fark etmez' : '$value km',
                            selected: distanceKm == value,
                            onTap: () => setState(() => distanceKm = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const FieldLabel('Tanışma amacı'),
                    const SizedBox(height: 9),
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
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: hasLocation ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Tercihleri kaydet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
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

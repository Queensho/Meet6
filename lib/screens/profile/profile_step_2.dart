import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepTwo extends StatelessWidget {
  const ProfileStepTwo({
    super.key,
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.locationLabel,
    required this.locationLoading,
    required this.locationError,
    required this.distanceKm,
    required this.purpose,
    required this.onLookingForChanged,
    required this.onAgeChanged,
    required this.onRequestLocation,
    required this.onDistanceChanged,
    required this.onPurposeChanged,
  });

  final String? lookingFor;
  final double minAge;
  final double maxAge;
  final String locationLabel;
  final bool locationLoading;
  final String? locationError;
  final int distanceKm;
  final String? purpose;
  final ValueChanged<String> onLookingForChanged;
  final ValueChanged<RangeValues> onAgeChanged;
  final VoidCallback onRequestLocation;
  final ValueChanged<int> onDistanceChanged;
  final ValueChanged<String> onPurposeChanged;

  @override
  Widget build(BuildContext context) {
    final hasLocation = locationLabel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Kimlerle\ntanışmak istersin?',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 33,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Sana daha uygun 6 kişilik odalar oluşturmak için tercihlerini seç.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        const FieldLabel('Kimlerle tanışmak istiyorsun?'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const ['Kadınlar', 'Erkekler', 'Herkes'])
              SelectChip(
                label: item,
                selected: lookingFor == item,
                onTap: () => onLookingForChanged(item),
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
                fontSize: 13,
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
          labels: RangeLabels('${minAge.round()}', '${maxAge.round()}'),
          onChanged: onAgeChanged,
        ),
        const SizedBox(height: 8),
        const FieldLabel('Konumun'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasLocation
                ? AppColors.lime.withOpacity(.3)
                : Colors.white.withOpacity(.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasLocation ? AppColors.navy.withOpacity(.18) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasLocation ? AppColors.lime : AppColors.softSurface,
                  shape: BoxShape.circle,
                ),
                child: locationLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(
                        hasLocation
                            ? Icons.my_location_rounded
                            : Icons.location_on_outlined,
                        color: AppColors.navy,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationLoading
                          ? 'Konumun bulunuyor...'
                          : hasLocation
                              ? locationLabel
                              : 'Konum izni gerekli',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      locationError ??
                          (hasLocation
                              ? 'Ülke ve şehir otomatik alındı. Mesafe filtresi bu konuma göre çalışacak.'
                              : 'Meet6 yakınındaki odaları bulmak için konumunu kullanır.'),
                      style: TextStyle(
                        color: locationError == null
                            ? AppColors.muted
                            : const Color(0xFFD34B42),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: locationLoading ? null : onRequestLocation,
                child: Text(
                  hasLocation ? 'Yenile' : 'İzin ver',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
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
                fontSize: 12.5,
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
                onTap: () => onDistanceChanged(value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const FieldLabel('Tanışma amacı'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              'Ciddi ilişki',
              'Flört',
              'Yeni insanlar',
              'Akışına bırakıyorum',
            ])
              SelectChip(
                label: item,
                selected: purpose == item,
                onTap: () => onPurposeChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}

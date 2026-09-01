import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepTwo extends StatelessWidget {
  const ProfileStepTwo({
    super.key,
    required this.lookingFor,
    required this.minAge,
    required this.maxAge,
    required this.cityController,
    required this.distanceKm,
    required this.purpose,
    required this.onLookingForChanged,
    required this.onAgeChanged,
    required this.onDistanceChanged,
    required this.onPurposeChanged,
    required this.onChanged,
  });

  final String? lookingFor;
  final double minAge;
  final double maxAge;
  final TextEditingController cityController;
  final int distanceKm;
  final String? purpose;
  final ValueChanged<String> onLookingForChanged;
  final ValueChanged<RangeValues> onAgeChanged;
  final ValueChanged<int> onDistanceChanged;
  final ValueChanged<String> onPurposeChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
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
        const FieldLabel('Şehir'),
        const SizedBox(height: 7),
        TextField(
          controller: cityController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          decoration: meet6InputDecoration(
            hint: 'Örn. İstanbul',
            icon: Icons.location_city_rounded,
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Maksimum mesafe'),
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

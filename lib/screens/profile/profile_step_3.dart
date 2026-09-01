import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepThree extends StatelessWidget {
  const ProfileStepThree({
    super.key,
    required this.bioController,
    required this.promptAnswerController,
    required this.extraPhotoCount,
    required this.interests,
    required this.onBioChanged,
    required this.onPromptChanged,
    required this.onExtraPhotoCountChanged,
    required this.onInterestToggle,
  });

  final TextEditingController bioController;
  final TextEditingController promptAnswerController;
  final int extraPhotoCount;
  final Set<String> interests;
  final VoidCallback onBioChanged;
  final VoidCallback onPromptChanged;
  final ValueChanged<int> onExtraPhotoCountChanged;
  final ValueChanged<String> onInterestToggle;

  @override
  Widget build(BuildContext context) {
    const interestOptions = [
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Profiline\nkarakter kat',
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
          'Odada ilk izlenimi bu detaylar oluşturacak.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        const FieldLabel('Ek fotoğraflar'),
        const SizedBox(height: 9),
        Row(
          children: List.generate(3, (index) {
            final selected = index < extraPhotoCount;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final next = selected && index == extraPhotoCount - 1
                      ? extraPhotoCount - 1
                      : index + 1;
                  onExtraPhotoCountChanged(next.clamp(0, 3));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 96,
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.lime
                        : Colors.white.withOpacity(.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppColors.navy : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.person_rounded
                        : Icons.add_a_photo_outlined,
                    color: selected ? AppColors.navy : AppColors.muted,
                    size: 30,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        const Text(
          'En az 2 ek fotoğraf seç.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Kısa bio'),
        const SizedBox(height: 7),
        TextField(
          controller: bioController,
          maxLength: 120,
          minLines: 3,
          maxLines: 4,
          onChanged: (_) => onBioChanged(),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: meet6InputDecoration(
            hint: 'Kendini birkaç cümleyle anlat...',
            icon: Icons.notes_rounded,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const FieldLabel('İlgi alanları'),
            const Spacer(),
            Text(
              '${interests.length}/5',
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 12,
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
            for (final item in interestOptions)
              SelectChip(
                label: item,
                selected: interests.contains(item),
                onTap: () => onInterestToggle(item),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const FieldLabel('Profil sorusu'),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.softSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'Benimle iyi anlaşmanın yolu...',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: promptAnswerController,
          maxLength: 80,
          onChanged: (_) => onPromptChanged(),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: meet6InputDecoration(
            hint: 'Cevabını yaz...',
            icon: Icons.chat_bubble_outline_rounded,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepOne extends StatelessWidget {
  const ProfileStepOne({
    super.key,
    required this.nameController,
    required this.birthDateController,
    required this.gender,
    required this.photoSelected,
    required this.onChanged,
    required this.onPickBirthDate,
    required this.onGenderChanged,
    required this.onPhotoToggle,
  });

  final TextEditingController nameController;
  final TextEditingController birthDateController;
  final String? gender;
  final bool photoSelected;
  final VoidCallback onChanged;
  final VoidCallback onPickBirthDate;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onPhotoToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Seni biraz\ntanıyalım',
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
          'Diğer kişiler seni odada bu bilgilerle görecek.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: onPhotoToggle,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    color: photoSelected
                        ? AppColors.lime
                        : const Color(0xFFF0F2F8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: photoSelected ? AppColors.navy : AppColors.border,
                      width: photoSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    photoSelected
                        ? Icons.person_rounded
                        : Icons.add_a_photo_rounded,
                    color: photoSelected ? AppColors.navy : AppColors.muted,
                    size: 46,
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 3,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            photoSelected ? 'Fotoğraf eklendi' : 'Profil fotoğrafı ekle',
            style: TextStyle(
              color: photoSelected ? AppColors.blue : AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const FieldLabel('Adın'),
        const SizedBox(height: 7),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          decoration: meet6InputDecoration(
            hint: 'Sana nasıl hitap edelim?',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Doğum tarihi'),
        const SizedBox(height: 7),
        TextField(
          controller: birthDateController,
          readOnly: true,
          onTap: onPickBirthDate,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          decoration: meet6InputDecoration(
            hint: 'GG.AA.YYYY',
            icon: Icons.calendar_today_outlined,
            suffix: Icons.keyboard_arrow_down_rounded,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 17),
        const FieldLabel('Cinsiyet'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              'Kadın',
              'Erkek',
              'Diğer',
              'Belirtmek istemiyorum',
            ])
              SelectChip(
                label: item,
                selected: gender == item,
                onTap: () => onGenderChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}

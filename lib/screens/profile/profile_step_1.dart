import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepOne extends StatelessWidget {
  const ProfileStepOne({
    super.key,
    required this.nameController,
    required this.birthDateController,
    required this.gender,
    required this.photoBytes,
    required this.onChanged,
    required this.onPickBirthDate,
    required this.onGenderChanged,
    required this.onPickPhoto,
  });

  final TextEditingController nameController;
  final TextEditingController birthDateController;
  final String? gender;
  final Uint8List? photoBytes;
  final VoidCallback onChanged;
  final VoidCallback onPickBirthDate;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = photoBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Seni biraz\ntanıyalım',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 33,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Diğer kişiler seni odada bu bilgilerle görecek.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: onPickPhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 122,
                  height: 122,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: hasPhoto ? AppColors.lime : scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPhoto ? AppColors.lime : scheme.outlineVariant,
                      width: hasPhoto ? 3 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: hasPhoto
                      ? Image.memory(
                          photoBytes!,
                          width: 122,
                          height: 122,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.add_a_photo_rounded,
                          color: scheme.onSurfaceVariant,
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
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                    child: Icon(
                      hasPhoto ? Icons.edit_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
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
            hasPhoto ? 'Fotoğrafı değiştir' : 'Profil fotoğrafı ekle',
            style: TextStyle(
              color: hasPhoto ? AppColors.blue : scheme.onSurfaceVariant,
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
          style: TextStyle(
            color: scheme.onSurface,
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
          style: TextStyle(
            color: scheme.onSurface,
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
        Text(
          'Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
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

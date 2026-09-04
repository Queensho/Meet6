import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';

class ProfileStepThree extends StatelessWidget {
  const ProfileStepThree({
    super.key,
    required this.bioController,
    required this.promptAnswerController,
    required this.extraPhotoBytes,
    required this.interests,
    required this.selectedPrompt,
    required this.onBioChanged,
    required this.onPromptChanged,
    required this.onPromptSelected,
    required this.onPickExtraPhoto,
    required this.onRemoveExtraPhoto,
    required this.onInterestToggle,
  });

  final TextEditingController bioController;
  final TextEditingController promptAnswerController;
  final List<Uint8List?> extraPhotoBytes;
  final Set<String> interests;
  final String selectedPrompt;
  final VoidCallback onBioChanged;
  final VoidCallback onPromptChanged;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<int> onPickExtraPhoto;
  final ValueChanged<int> onRemoveExtraPhoto;
  final ValueChanged<String> onInterestToggle;

  static const promptOptions = [
    'Benimle iyi anlaşmanın yolu...',
    'Beni en çok güldüren şey...',
    'Birlikte mutlaka yapmalıyız...',
    'Hafta sonu beni genelde...',
    'Bende ilk fark edeceğin şey...',
    'Hayalimdeki ilk buluşma...',
  ];

  Future<void> _selectPrompt(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final scheme = Theme.of(context).colorScheme;
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        final localScheme = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil sorusu seç',
                  style: TextStyle(
                    color: localScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 14),
                for (final prompt in promptOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(prompt),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: prompt == selectedPrompt
                              ? AppColors.lime
                              : localScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: prompt == selectedPrompt
                                ? AppColors.navy
                                : localScheme.outlineVariant,
                            width: prompt == selectedPrompt ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                prompt,
                                style: TextStyle(
                                  color: prompt == selectedPrompt
                                      ? AppColors.navy
                                      : localScheme.onSurface,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (prompt == selectedPrompt)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.navy,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (value != null) onPromptSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        Text(
          'Profiline\nkarakter kat',
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
          'Odada ilk izlenimi bu detaylar oluşturacak.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
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
            final bytes = index < extraPhotoBytes.length
                ? extraPhotoBytes[index]
                : null;
            final selected = bytes != null;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => onPickExtraPhoto(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 106,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lime
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppColors.lime
                                : scheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: selected
                            ? Image.memory(
                                bytes!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.add_a_photo_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 30,
                              ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: -7,
                        right: -5,
                        child: InkWell(
                          onTap: () => onRemoveExtraPhoto(index),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: scheme.onSurface,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 7),
        Text(
          'Ek fotoğraflar isteğe bağlı. İstersen tek seferde birden fazla seçip toplam 4 fotoğrafa tamamlayabilirsin.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
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
          style: TextStyle(
            color: scheme.onSurface,
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
        InkWell(
          onTap: () => _selectPrompt(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedPrompt,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: promptAnswerController,
          maxLength: 80,
          onChanged: (_) => onPromptChanged(),
          style: TextStyle(
            color: scheme.onSurface,
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

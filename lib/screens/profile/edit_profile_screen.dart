import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';
import '../../widgets/phone_frame.dart';

class EditProfileResult {
  const EditProfileResult({
    required this.name,
    required this.age,
    required this.bio,
    required this.interests,
    required this.prompt,
    required this.promptAnswer,
  });

  final String name;
  final int age;
  final String bio;
  final List<String> interests;
  final String prompt;
  final String promptAnswer;
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
  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController bioController;
  late final TextEditingController answerController;
  late Set<String> interests;
  late String prompt;

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
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    answerController.dispose();
    super.dispose();
  }

  bool get canSave =>
      nameController.text.trim().length >= 2 &&
      int.tryParse(ageController.text) != null &&
      bioController.text.trim().length >= 3 &&
      interests.isNotEmpty &&
      answerController.text.trim().length >= 3;

  void _save() {
    if (!canSave) return;
    Navigator.of(context).pop(
      EditProfileResult(
        name: nameController.text.trim(),
        age: int.parse(ageController.text),
        bio: bioController.text.trim(),
        interests: interests.toList(),
        prompt: prompt,
        promptAnswer: answerController.text.trim(),
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
                                  content: Text(
                                    'Fotoğraf seçici backend aşamasında bağlanacak.',
                                  ),
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
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.blue.withOpacity(.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppColors.blue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kimlerle tanışacağın, yaş aralığı ve mesafe artık Eşleşme tercihleri bölümünden yönetilir.',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
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

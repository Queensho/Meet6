import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/picked_profile_photo.dart';
import '../../models/server_profile.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';
import '../../widgets/phone_frame.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initial,
  });

  final ServerProfile initial;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final imagePicker = ImagePicker();
  late final TextEditingController nameController;
  late final TextEditingController birthDateController;
  late final TextEditingController bioController;
  late final TextEditingController answerController;
  late Set<String> interests;
  late String prompt;
  late String gender;
  late String birthDateIso;
  late List<String?> existingPhotoSlots;
  final replacementPhotos = List<PickedProfilePhoto?>.filled(4, null);

  bool saving = false;
  bool photoPicking = false;

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
    birthDateIso = i.birthDate;
    birthDateController = TextEditingController(text: _displayDate(i.birthDate));
    bioController = TextEditingController(text: i.bio);
    answerController = TextEditingController(text: i.promptAnswer);
    interests = i.interests.toSet();
    prompt = promptOptions.contains(i.prompt) ? i.prompt : promptOptions.first;
    gender = i.gender;
    existingPhotoSlots = List<String?>.filled(4, null);
    for (var index = 0; index < i.photoUrls.length && index < 4; index++) {
      existingPhotoSlots[index] = i.photoUrls[index];
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    birthDateController.dispose();
    bioController.dispose();
    answerController.dispose();
    super.dispose();
  }

  int get photoCount {
    var count = 0;
    for (var index = 0; index < 4; index++) {
      if (replacementPhotos[index] != null || existingPhotoSlots[index] != null) {
        count++;
      }
    }
    return count;
  }

  bool get canSave =>
      !saving &&
      !photoPicking &&
      nameController.text.trim().length >= 2 &&
      DateTime.tryParse(birthDateIso) != null &&
      gender.isNotEmpty &&
      bioController.text.trim().length >= 3 &&
      interests.isNotEmpty &&
      answerController.text.trim().length >= 3 &&
      photoCount >= 3;

  String _displayDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  Future<void> _pickBirthDate() async {
    if (saving) return;
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final current = DateTime.tryParse(birthDateIso);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(latest.year - 7, latest.month, latest.day),
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Doğum tarihini seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked == null || !mounted) return;
    setState(() {
      birthDateIso =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      birthDateController.text = _displayDate(birthDateIso);
    });
  }

  Future<void> _pickPhoto(int index) async {
    if (photoPicking || saving) return;
    setState(() => photoPicking = true);
    try {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf en fazla 8 MB olabilir.')),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        replacementPhotos[index] = PickedProfilePhoto(
          bytes: bytes,
          fileName: picked.name,
          mimeType: _mimeForName(picked.name),
        );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf seçilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => photoPicking = false);
    }
  }

  void _removePhoto(int index) {
    if (saving) return;
    setState(() {
      replacementPhotos[index] = null;
      existingPhotoSlots[index] = null;
    });
  }

  Future<void> _save() async {
    if (!canSave) return;
    setState(() => saving = true);
    try {
      final replacementIndexes = <int>[];
      final files = <PickedProfilePhoto>[];
      for (var index = 0; index < replacementPhotos.length; index++) {
        final photo = replacementPhotos[index];
        if (photo != null) {
          replacementIndexes.add(index);
          files.add(photo);
        }
      }

      if (files.isNotEmpty) {
        final uploadedUrls = await ApiService.uploadProfilePhotos(files);
        for (var i = 0; i < replacementIndexes.length; i++) {
          existingPhotoSlots[replacementIndexes[i]] = uploadedUrls[i];
          replacementPhotos[replacementIndexes[i]] = null;
        }
      }

      final photoUrls = existingPhotoSlots.whereType<String>().toList();
      await ApiService.updateProfile(
        displayName: nameController.text.trim(),
        birthDate: birthDateIso,
        gender: gender,
        bio: bioController.text.trim(),
        city: widget.initial.city,
        country: widget.initial.country,
        latitude: widget.initial.latitude,
        longitude: widget.initial.longitude,
        profilePrompt: prompt,
        profileAnswer: answerController.text.trim(),
        interests: interests.toList(),
        photoUrls: photoUrls,
        profileCompleted: true,
      );

      final response = await ApiService.getMe();
      final raw = response['user'];
      if (raw is! Map) {
        throw const ApiException('Güncel profil sunucudan alınamadı.');
      }
      final updated = ServerProfile.fromUser(Map<String, dynamic>.from(raw));
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellenemedi. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _photoSlot(int index, {bool main = false}) {
    final scheme = Theme.of(context).colorScheme;
    final replacement = replacementPhotos[index];
    final existing = existingPhotoSlots[index];
    final hasPhoto = replacement != null || existing != null;
    final size = main ? 110.0 : 92.0;

    Widget child;
    if (replacement != null) {
      child = Image.memory(replacement.bytes, fit: BoxFit.cover);
    } else if (existing != null) {
      child = Image.network(
        ApiService.absoluteMediaUrl(existing),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      child = Icon(
        Icons.add_a_photo_outlined,
        color: scheme.onSurfaceVariant,
        size: main ? 36 : 28,
      );
    }

    final imageBox = InkWell(
      onTap: () => _pickPhoto(index),
      borderRadius: BorderRadius.circular(main ? 55 : 18),
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: main ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: main ? null : BorderRadius.circular(18),
          border: Border.all(
            color: hasPhoto ? AppColors.lime : scheme.outlineVariant,
            width: hasPhoto ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        imageBox,
        if (hasPhoto)
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: () => _removePhoto(index),
              customBorder: const CircleBorder(),
              child: Container(
                width: 27,
                height: 27,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: PhoneFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: saving ? null : () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: scheme.surface),
                    icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Profili düzenle',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: canSave ? _save : null,
                    child: Text(
                      saving ? 'Kaydediliyor' : 'Kaydet',
                      style: TextStyle(
                        color: canSave ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _photoSlot(0, main: true)),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Ana fotoğraf · dokunarak değiştir',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var index = 1; index < 4; index++) _photoSlot(index),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$photoCount/4 fotoğraf · profil için en az 3 gerekli',
                      style: TextStyle(
                        color: photoCount >= 3
                            ? scheme.onSurfaceVariant
                            : const Color(0xFFE76A60),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const FieldLabel('Ad'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: scheme.onSurface),
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: 'Adın',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Doğum tarihi'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: birthDateController,
                      readOnly: true,
                      onTap: _pickBirthDate,
                      style: TextStyle(color: scheme.onSurface),
                      decoration: meet6InputDecoration(
                        hint: 'GG.AA.YYYY',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Cinsiyet'),
                    const SizedBox(height: 8),
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
                            onTap: () => setState(() => gender = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Hakkımda'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: bioController,
                      style: TextStyle(color: scheme.onSurface),
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
                      dropdownColor: scheme.surface,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: meet6InputDecoration(
                        hint: 'Soru seç',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      items: promptOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => prompt = value ?? prompt),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerController,
                      style: TextStyle(color: scheme.onSurface),
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      decoration: meet6InputDecoration(
                        hint: 'Cevabın',
                        icon: Icons.edit_note_rounded,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: dark ? AppColors.lime : AppColors.navy,
                          foregroundColor: dark ? AppColors.navy : Colors.white,
                          disabledBackgroundColor: scheme.surfaceContainerHigh,
                          disabledForegroundColor: scheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          saving
                              ? 'Sunucuya kaydediliyor...'
                              : photoPicking
                                  ? 'Fotoğraf hazırlanıyor...'
                                  : 'Değişiklikleri kaydet',
                          style: const TextStyle(fontWeight: FontWeight.w900),
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

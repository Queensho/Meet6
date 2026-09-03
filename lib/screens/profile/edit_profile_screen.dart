import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/picked_profile_photo.dart';
import '../../models/server_profile.dart';
import '../../services/api_service.dart';
import '../../services/profile_photo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/form_components.dart';
import '../../widgets/phone_frame.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.initial});

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
  late List<_EditablePhoto> photos;

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
    final initial = widget.initial;
    nameController = TextEditingController(text: initial.name);
    birthDateIso = initial.birthDate;
    birthDateController = TextEditingController(text: _displayDate(initial.birthDate));
    bioController = TextEditingController(text: initial.bio);
    answerController = TextEditingController(text: initial.promptAnswer);
    interests = initial.interests.toSet();
    prompt = promptOptions.contains(initial.prompt) ? initial.prompt : promptOptions.first;
    gender = initial.gender;
    final seed = DateTime.now().microsecondsSinceEpoch;
    photos = List.generate(
      4,
      (index) => _EditablePhoto(
        id: 'profile-photo-$seed-$index',
        existingUrl: index < initial.photoUrls.length ? initial.photoUrls[index] : null,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    birthDateController.dispose();
    bioController.dispose();
    answerController.dispose();
    super.dispose();
  }

  int get photoCount => photos.where((photo) => photo.hasPhoto).length;

  int get completionPercent {
    var score = 0;
    if (nameController.text.trim().length >= 2) score += 10;
    if (DateTime.tryParse(birthDateIso) != null) score += 10;
    if (gender.trim().isNotEmpty) score += 10;
    if (bioController.text.trim().length >= 3) score += 10;
    if (widget.initial.latitude != null && widget.initial.longitude != null) score += 10;
    if (interests.isNotEmpty) score += 10;
    if (prompt.trim().isNotEmpty && answerController.text.trim().length >= 3) score += 10;
    score += (photoCount > 3 ? 3 : photoCount) * 10;
    return score > 100 ? 100 : score;
  }

  String get completionHint {
    if (completionPercent == 100) return 'Profilin eşleşmeye hazır.';
    if (photoCount < 3) return 'En az ${3 - photoCount} fotoğraf daha ekle.';
    if (nameController.text.trim().length < 2) return 'Adını tamamla.';
    if (DateTime.tryParse(birthDateIso) == null) return 'Doğum tarihini seç.';
    if (gender.trim().isEmpty) return 'Cinsiyet seçimini tamamla.';
    if (bioController.text.trim().length < 3) return 'Kısa bir bio ekle.';
    if (widget.initial.latitude == null || widget.initial.longitude == null) return 'Konum bilgisini tamamla.';
    if (interests.isEmpty) return 'En az 1 ilgi alanı seç.';
    if (answerController.text.trim().length < 3) return 'Profil sorusunu cevapla.';
    return 'Eksik alanları tamamla.';
  }

  bool get canSave =>
      !saving && !photoPicking && completionPercent == 100 && photoCount >= 3;

  String _displayDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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
    if (photoPicking || saving || index < 0 || index >= photos.length) return;
    setState(() => photoPicking = true);
    try {
      final picked = await ProfilePhotoService.pickAndPrepare(context, imagePicker);
      if (picked == null || !mounted) return;
      setState(() {
        photos[index]
          ..picked = picked
          ..existingUrl = null;
        _compactPhotos();
      });
    } on ProfilePhotoException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf hazırlanamadı. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => photoPicking = false);
    }
  }

  void _compactPhotos() {
    final filled = photos.where((photo) => photo.hasPhoto).toList(growable: false);
    final empty = photos.where((photo) => !photo.hasPhoto).toList(growable: false);
    photos = [...filled, ...empty];
  }

  void _removePhoto(int index) {
    if (saving || index < 0 || index >= photos.length) return;
    setState(() {
      photos[index]
        ..picked = null
        ..existingUrl = null;
      _compactPhotos();
    });
  }

  void _makeMainPhoto(int index) {
    if (saving || index <= 0 || index >= photos.length || !photos[index].hasPhoto) return;
    setState(() {
      final photo = photos.removeAt(index);
      photos.insert(0, photo);
      _compactPhotos();
    });
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    if (saving || oldIndex < 0 || oldIndex >= photos.length || !photos[oldIndex].hasPhoto) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    final lastFilledIndex = photoCount - 1;
    if (lastFilledIndex < 0) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > lastFilledIndex) newIndex = lastFilledIndex;
    if (oldIndex == newIndex) return;

    setState(() {
      final photo = photos.removeAt(oldIndex);
      photos.insert(newIndex, photo);
      _compactPhotos();
    });
  }

  Future<void> _save() async {
    if (!canSave) return;
    setState(() => saving = true);
    try {
      final pending = photos.where((photo) => photo.picked != null).toList(growable: false);
      if (pending.isNotEmpty) {
        final uploadedUrls = await ApiService.uploadProfilePhotos(
          pending.map((photo) => photo.picked!).toList(growable: false),
        );
        for (var index = 0; index < pending.length; index++) {
          pending[index]
            ..existingUrl = uploadedUrls[index]
            ..picked = null;
        }
      }

      final photoUrls = photos
          .where((photo) => photo.hasPhoto)
          .map((photo) => photo.existingUrl!)
          .toList(growable: false);

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
        interests: interests.toList(growable: false),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellenemedi. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _completionCard() {
    final scheme = Theme.of(context).colorScheme;
    final complete = completionPercent == 100;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: complete ? AppColors.lime : scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  complete ? Icons.check_rounded : Icons.auto_awesome_rounded,
                  color: complete ? AppColors.navy : AppColors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profilin %$completionPercent tamamlandı',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completionHint,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: completionPercent / 100,
              backgroundColor: scheme.surfaceContainerHigh,
              color: complete ? AppColors.lime : AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(int index) {
    final scheme = Theme.of(context).colorScheme;
    final photo = photos[index];
    final hasPhoto = photo.hasPhoto;

    Widget preview;
    if (photo.picked != null) {
      preview = Image.memory(photo.picked!.bytes, fit: BoxFit.cover);
    } else if (photo.existingUrl != null) {
      preview = Image.network(
        ApiService.absoluteMediaUrl(photo.existingUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      preview = Icon(Icons.add_a_photo_outlined, color: scheme.onSurfaceVariant, size: 30);
    }

    final tile = Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _pickPhoto(index),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 92,
            height: 112,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: index == 0 && hasPhoto ? AppColors.lime : scheme.outlineVariant,
                width: index == 0 && hasPhoto ? 2.5 : 1,
              ),
            ),
            child: preview,
          ),
        ),
        if (index == 0 && hasPhoto)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ANA',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        if (hasPhoto)
          Positioned(
            right: -5,
            top: -5,
            child: InkWell(
              onTap: () => _removePhoto(index),
              customBorder: const CircleBorder(),
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(Icons.close_rounded, color: scheme.onSurface, size: 16),
              ),
            ),
          ),
        if (hasPhoto && index > 0)
          Positioned(
            left: 5,
            bottom: 5,
            child: InkWell(
              onTap: () => _makeMainPhoto(index),
              customBorder: const CircleBorder(),
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: AppColors.blue, size: 17),
              ),
            ),
          ),
        if (hasPhoto)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(.92),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: scheme.onSurfaceVariant,
                size: 17,
              ),
            ),
          ),
      ],
    );

    if (!hasPhoto) return tile;
    return ReorderableDragStartListener(index: index, child: tile);
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
                    child: Text(saving ? 'Kaydediliyor' : 'Kaydet'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _completionCard(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const FieldLabel('Fotoğraflar'),
                        const Spacer(),
                        Text(
                          '$photoCount/4',
                          style: TextStyle(
                            color: photoCount >= 3 ? AppColors.blue : const Color(0xFFE76A60),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Basılı tutup sürükleyerek sırala. Yıldız ile ana fotoğrafı değiştir.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 124,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        itemCount: photos.length,
                        onReorder: _reorderPhoto,
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.transparent,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(18),
                          child: child,
                        ),
                        itemBuilder: (context, index) => Padding(
                          key: ValueKey(photos[index].id),
                          padding: const EdgeInsets.only(right: 10),
                          child: _photoTile(index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const FieldLabel('Ad'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: scheme.onSurface),
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
                      maxLength: 120,
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: scheme.onSurface),
                      decoration: meet6InputDecoration(
                        hint: 'Kendini anlat...',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const FieldLabel('İlgi alanları'),
                        const Spacer(),
                        Text(
                          '${interests.length}/5',
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontSize: 11.5,
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
                      decoration: meet6InputDecoration(
                        hint: 'Soru seç',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      items: promptOptions
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(growable: false),
                      onChanged: (value) => setState(() => prompt = value ?? prompt),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerController,
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: scheme.onSurface),
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

class _EditablePhoto {
  _EditablePhoto({required this.id, this.existingUrl, this.picked});

  final String id;
  String? existingUrl;
  PickedProfilePhoto? picked;

  bool get hasPhoto => picked != null || (existingUrl?.isNotEmpty ?? false);
}

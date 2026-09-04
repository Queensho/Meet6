import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_profile_photo.dart';
import '../screens/profile/profile_photo_crop_screen.dart';

class ProfilePhotoService {
  const ProfilePhotoService._();

  static const int _maxInputBytes = 12 * 1024 * 1024;
  static const int _targetLongEdge = 1200;

  static Future<PickedProfilePhoto?> Function(
    BuildContext context,
    ImagePicker picker,
  )? debugPickOverride;

  static Future<List<PickedProfilePhoto>> Function(
    BuildContext context,
    ImagePicker picker,
    int maxCount,
  )? debugPickManyOverride;

  static void debugResetTestHooks() {
    debugPickOverride = null;
    debugPickManyOverride = null;
  }

  static Future<PickedProfilePhoto?> pickAndPrepare(
    BuildContext context,
    ImagePicker picker,
  ) async {
    final fake = debugPickOverride;
    if (fake != null) return fake(context, picker);

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return _preparePickedFile(context, picked);
  }

  static Future<List<PickedProfilePhoto>> pickAndPrepareMany(
    BuildContext context,
    ImagePicker picker, {
    int maxCount = 4,
  }) async {
    if (maxCount <= 0) return const [];

    final fake = debugPickManyOverride;
    if (fake != null) return fake(context, picker, maxCount);

    final pickedFiles = await picker.pickMultiImage(imageQuality: 100);
    if (pickedFiles.isEmpty) return const [];

    final prepared = <PickedProfilePhoto>[];
    for (final picked in pickedFiles.take(maxCount)) {
      if (!context.mounted) break;
      final photo = await _preparePickedFile(context, picked);
      if (photo != null) prepared.add(photo);
    }
    return prepared;
  }

  static Future<PickedProfilePhoto?> _preparePickedFile(
    BuildContext context,
    XFile picked,
  ) async {
    final originalBytes = await picked.readAsBytes();
    if (originalBytes.isEmpty) {
      throw const ProfilePhotoException('Fotoğraf okunamadı.');
    }
    if (originalBytes.length > _maxInputBytes) {
      throw const ProfilePhotoException('Fotoğraf en fazla 12 MB olabilir.');
    }
    if (!context.mounted) return null;

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProfilePhotoCropScreen(imageBytes: originalBytes),
      ),
    );
    if (cropped == null || cropped.isEmpty) return null;

    var compressed = await FlutterImageCompress.compressWithList(
      cropped,
      minWidth: _targetLongEdge,
      minHeight: _targetLongEdge,
      quality: 84,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressed.length > 1500 * 1024) {
      compressed = await FlutterImageCompress.compressWithList(
        Uint8List.fromList(compressed),
        minWidth: _targetLongEdge,
        minHeight: _targetLongEdge,
        quality: 72,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
    }

    if (compressed.isEmpty) {
      throw const ProfilePhotoException('Fotoğraf sıkıştırılamadı.');
    }
    if (compressed.length > 8 * 1024 * 1024) {
      throw const ProfilePhotoException('Hazırlanan fotoğraf 8 MB sınırını aşıyor.');
    }

    return PickedProfilePhoto(
      bytes: Uint8List.fromList(compressed),
      fileName: 'meet6-profile-${DateTime.now().microsecondsSinceEpoch}.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

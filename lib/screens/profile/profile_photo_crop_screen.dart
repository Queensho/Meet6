import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';

class ProfilePhotoCropScreen extends StatefulWidget {
  const ProfilePhotoCropScreen({
    super.key,
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  final cropController = CropController();
  bool cropping = false;

  void _crop() {
    if (cropping) return;
    setState(() => cropping = true);
    cropController.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(Uint8List.fromList(croppedImage));
      case CropFailure(:final cause):
        setState(() => cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf kırpılamadı: $cause')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: cropping ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fotoğrafı kırp',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Yakınlaştır, sürükle ve kadrajı ayarla.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: cropping ? null : _crop,
                      child: Text(cropping ? 'Hazırlanıyor' : 'Kullan'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Crop(
                      image: widget.imageBytes,
                      controller: cropController,
                      onCropped: _onCropped,
                      aspectRatio: 1,
                      initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                        size: .86,
                        aspectRatio: 1,
                      ),
                      interactive: true,
                      fixCropRect: true,
                      radius: 24,
                      baseColor: AppColors.navy,
                      maskColor: Colors.black.withOpacity(.58),
                      progressIndicator: const Center(
                        child: CircularProgressIndicator(color: AppColors.lime),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_in_rounded, color: AppColors.blue, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fotoğraf kare olarak hazırlanır ve yüklemeden önce otomatik sıkıştırılır.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

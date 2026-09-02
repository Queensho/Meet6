import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    this.imageUrl = '',
  });

  final String name;
  final String imageUrl;

  String get initial {
    final value = name.trim();
    return value.isEmpty ? 'S' : value.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImage = ApiService.absoluteMediaUrl(imageUrl);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 184,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(34),
              bottomRight: Radius.circular(34),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -55,
                right: -48,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.navy.withOpacity(.08),
                      width: 26,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -38,
                bottom: -64,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blue.withOpacity(.08),
                      width: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 116,
                height: 116,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: resolvedImage.isNotEmpty
                      ? Image.network(
                          resolvedImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _Fallback(initial: initial),
                        )
                      : _Fallback(initial: initial),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.lime,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

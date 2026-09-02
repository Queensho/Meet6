import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class ParticipantStrip extends StatelessWidget {
  const ParticipantStrip({super.key});

  static const _participants = [
    ('A', 'Aslı'),
    ('M', 'Mert'),
    ('E', 'Ece'),
    ('B', 'Bora'),
    ('S', 'Selin'),
    ('T', 'Sen'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 68,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _participants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = _participants[index];
          final isMe = index == _participants.length - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.lime : scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isMe ? AppColors.lime : scheme.outlineVariant,
                        width: isMe ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: isMe ? AppColors.navy : scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: TextStyle(
                  color: isMe ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

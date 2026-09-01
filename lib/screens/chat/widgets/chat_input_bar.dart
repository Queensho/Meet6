import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.canSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Mesajını yaz...',
                  hintStyle: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: AppColors.softSurface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        const BorderSide(color: AppColors.blue, width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: canSend ? AppColors.lime : AppColors.softSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: canSend ? AppColors.navy : AppColors.border,
                ),
              ),
              child: IconButton(
                onPressed: canSend ? onSend : null,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: canSend ? AppColors.navy : AppColors.muted,
                  size: 23,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

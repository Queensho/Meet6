import 'package:flutter/material.dart';

import '../../models/match_profile.dart';
import '../../services/blocked_accounts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../messages/private_chat_screen.dart';

class MatchProfileDetailScreen extends StatelessWidget {
  const MatchProfileDetailScreen({
    super.key,
    required this.profile,
  });

  final MatchProfile profile;

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          name: profile.name,
          initial: profile.initial,
          isOnline: profile.isOnline,
          fromNewMatch: true,
        ),
      ),
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x33E24A4A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFE24A4A),
                    size: 31,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${profile.name} engellensin mi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu kişi eşleşmelerinden kaldırılır, sana mesaj gönderemez ve aynı odalarda sana gösterilmez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(color: scheme.outlineVariant),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE24A4A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          'Engelle',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (approved != true || !context.mounted) return;

    await BlockedAccountsService.block(
      name: profile.name,
      initial: profile.initial,
    );
    if (!context.mounted) return;

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${profile.name} engellendi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFE24A4A),
                  ),
                  title: Text(
                    '${profile.name} kişisini engelle',
                    style: const TextStyle(
                      color: Color(0xFFE24A4A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'Eşleşmelerden ve mesajlardan kaldır',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _blockUser(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 88, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.lime, width: 6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              profile.initial,
                              style: const TextStyle(
                                color: AppColors.lime,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (profile.isOnline)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF36C76C),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.surface, width: 3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        '${profile.name}, ${profile.age}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: scheme.primary,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profile.city,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text('•', style: TextStyle(color: scheme.outlineVariant)),
                          const SizedBox(width: 7),
                          Text(
                            profile.isOnline ? 'Şimdi aktif' : profile.matchedAt,
                            style: TextStyle(
                              color: profile.isOnline
                                  ? const Color(0xFF36C76C)
                                  : scheme.onSurfaceVariant,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => _openChat(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: dark ? AppColors.lime : AppColors.navy,
                          foregroundColor: dark ? AppColors.navy : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: const Text(
                          'Mesaj gönder',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DetailCard(
                      title: 'Hakkında',
                      child: Text(
                        profile.bio,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      title: 'İlgi alanları',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interest in profile.interests)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lime.withOpacity(dark ? .92 : .5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                interest,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      title: 'Profil sorusu',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.prompt,
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            profile.promptAnswer,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${profile.matchedAt} karşılıklı seçim yaptınız.',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
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
            Positioned(
              top: 12,
              left: 12,
              child: _CircleAction(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _CircleAction(
                icon: Icons.more_horiz_rounded,
                onTap: () => _openMenu(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withOpacity(.95),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: scheme.onSurface),
        ),
      ),
    );
  }
}

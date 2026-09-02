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
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEEEE),
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
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu kişi eşleşmelerinden kaldırılır, sana mesaj gönderemez ve aynı odalarda sana gösterilmez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
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
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: AppColors.border),
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
      ),
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
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
                subtitle: const Text(
                  'Eşleşmelerden ve mesajlardan kaldır',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                                  border: Border.all(color: Colors.white, width: 3),
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
                        style: const TextStyle(
                          color: AppColors.navy,
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
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.blue,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profile.city,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text('•', style: TextStyle(color: AppColors.border)),
                          const SizedBox(width: 7),
                          Text(
                            profile.isOnline ? 'Şimdi aktif' : profile.matchedAt,
                            style: TextStyle(
                              color: profile.isOnline
                                  ? const Color(0xFF28A745)
                                  : AppColors.muted,
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
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
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
                        style: const TextStyle(
                          color: AppColors.navy,
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
                                color: AppColors.lime.withOpacity(.5),
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
                            style: const TextStyle(
                              color: AppColors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            profile.promptAnswer,
                            style: const TextStyle(
                              color: AppColors.navy,
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
                        color: AppColors.blue.withOpacity(.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.blue.withOpacity(.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${profile.matchedAt} karşılıklı seçim yaptınız.',
                              style: const TextStyle(
                                color: AppColors.navy,
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
              child: Material(
                color: Colors.white.withOpacity(.92),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white.withOpacity(.92),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => _openMenu(context),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.more_horiz_rounded, color: AppColors.navy),
                  ),
                ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
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

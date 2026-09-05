import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/gift_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../../widgets/xp_level_ring.dart';
import '../messages/private_chat_screen.dart';

class MatchProfileDetailScreen extends StatefulWidget {
  const MatchProfileDetailScreen({
    super.key,
    required this.matchId,
    required this.profileName,
    required this.preferences,
  });

  final String matchId;
  final String profileName;
  final MatchingPreferences preferences;

  @override
  State<MatchProfileDetailScreen> createState() =>
      _MatchProfileDetailScreenState();
}

class _MatchProfileDetailScreenState extends State<MatchProfileDetailScreen> {
  Map<String, dynamic>? profile;
  Map<String, dynamic>? socialSummary;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await LiveService.matchDetail(widget.matchId);
      final raw = data['profile'];
      final nextProfile = raw is Map ? Map<String, dynamic>.from(raw) : null;
      Map<String, dynamic>? nextSummary;

      final targetUserId = nextProfile?['user_id']?.toString() ?? '';
      if (targetUserId.isNotEmpty) {
        try {
          final giftData = await GiftService.userSummary(targetUserId);
          final rawSummary = giftData['summary'];
          if (rawSummary is Map) {
            nextSummary = Map<String, dynamic>.from(rawSummary);
          }
        } catch (_) {
          // Profil seviye özeti alınamasa da detay ekranı açılmaya devam eder.
        }
      }

      if (!mounted) return;
      setState(() {
        profile = nextProfile;
        socialSummary = nextSummary;
        loading = false;
        error = profile == null ? 'Profil bulunamadı.' : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  List<String> get photos {
    final raw = profile?['photo_urls'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> get interests {
    final raw = profile?['interests'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String get name => profile?['display_name']?.toString() ?? 'Meet6';
  String get userId => profile?['user_id']?.toString() ?? '';
  int get profileLevel =>
      (socialSummary?['profileLevel'] as num?)?.toInt() ?? 1;
  int get profileXp => (socialSummary?['profileXp'] as num?)?.toInt() ?? 0;
  bool get isOnline => profile?['online'] == true;
  bool get isPremium =>
      profile?['premium'] == true ||
      profile?['is_premium'] == true ||
      profile?['premium_active'] == true;

  String get locationText => [profile?['city'], profile?['country']]
      .where((value) =>
          value != null && value.toString().trim().isNotEmpty)
      .map((value) => value.toString().trim())
      .join(', ');

  void _message() {
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: widget.matchId,
          name: name,
          userId: userId,
          photoUrl: photos.isEmpty ? '' : photos.first,
          isOnline: isOnline,
        ),
      ),
    );
  }

  Future<void> _block() async {
    final approved = await _confirm(
      'Kullanıcı engellensin mi?',
      'Bu eşleşme kapanır ve bu kişiyle gelecekte aynı Meet6 odasına düşmezsin.',
    );
    if (approved != true || userId.isEmpty) return;
    try {
      await LiveService.blockUser(userId);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _unmatch() async {
    final approved = await _confirm(
      'Eşleşme kaldırılsın mı?',
      'Özel sohbet kapanır. Kullanıcı engellenmez.',
    );
    if (approved != true) return;
    await LiveService.unmatch(widget.matchId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _report() async {
    if (userId.isEmpty) return;
    final detail = TextEditingController();
    String reason = 'Rahatsız edici davranış';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Şikâyet et'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                isExpanded: true,
                items: const [
                  'Rahatsız edici davranış',
                  'Taciz / hakaret',
                  'Sahte profil',
                  'Spam',
                  'Diğer',
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detail,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ayrıntı ekle (isteğe bağlı)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );

    if (approved == true) {
      await LiveService.reportUser(
        userId,
        reason: reason,
        detail: detail.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şikâyetin inceleme kuyruğuna alındı.'),
          ),
        );
      }
    }
    detail.dispose();
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  Future<void> _more() async {
    final action = await showModalBottomSheet<String>(
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
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Şikâyet et'),
                  onTap: () => Navigator.pop(sheetContext, 'report'),
                ),
                ListTile(
                  leading: const Icon(Icons.heart_broken_outlined),
                  title: const Text('Eşleşmeyi kaldır'),
                  onTap: () => Navigator.pop(sheetContext, 'unmatch'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFE24A4A),
                  ),
                  title: const Text(
                    'Kullanıcıyı engelle',
                    style: TextStyle(color: Color(0xFFE24A4A)),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'block'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'report') await _report();
    if (action == 'unmatch') await _unmatch();
    if (action == 'block') await _block();
  }

  Widget _heroPhoto(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: Colors.white, width: 7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: photos.isEmpty
                ? Container(
                    color: AppColors.lime,
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 78,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : PageView.builder(
                    itemCount: photos.length,
                    itemBuilder: (_, index) => Image.network(
                      ApiService.absoluteMediaUrl(photos[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.navy,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.lime,
                          size: 76,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (isPremium)
          const Positioned(
            left: 8,
            bottom: -12,
            child: _StatusPill(
              icon: Icons.workspace_premium_rounded,
              label: 'Premium',
              foreground: Colors.white,
              background: AppColors.navy,
              iconColor: AppColors.lime,
              outlined: true,
            ),
          ),
        Positioned(
          right: -10,
          bottom: -28,
          child: XpLevelRing(
            level: profileLevel,
            totalXp: profileXp,
            size: 62,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final age = (profile?['age'] as num?)?.toInt();
    final bio = profile?['bio']?.toString().trim() ?? '';
    final prompt = profile?['profile_prompt']?.toString().trim() ?? '';
    final answer = profile?['profile_answer']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.lime),
              )
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 28,
                        right: -42,
                        child: _DecorCircle(
                          size: 156,
                          color: AppColors.lime.withValues(alpha: .22),
                        ),
                      ),
                      Positioned(
                        top: 245,
                        left: -66,
                        child: _DecorCircle(
                          size: 168,
                          color: AppColors.lime.withValues(alpha: .11),
                        ),
                      ),
                      Positioned(
                        top: 500,
                        right: -76,
                        child: _DecorCircle(
                          size: 190,
                          color: AppColors.navy.withValues(alpha: .035),
                        ),
                      ),
                      Positioned.fill(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 92, 22, 112),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 34),
                                child: _heroPhoto(context),
                              ),
                              const SizedBox(height: 48),
                              Text(
                                age == null ? name : '$name, $age',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 30,
                                  height: 1.05,
                                  letterSpacing: -1.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (isPremium)
                                    const _StatusPill(
                                      icon: Icons.workspace_premium_rounded,
                                      label: 'Premium',
                                      foreground: Colors.white,
                                      background: AppColors.navy,
                                      iconColor: AppColors.lime,
                                    ),
                                  _StatusPill(
                                    label: 'Lv $profileLevel',
                                    foreground: AppColors.lime,
                                    background: AppColors.navy,
                                  ),
                                  if (isOnline)
                                    const _StatusPill(
                                      icon: Icons.circle,
                                      label: 'Şimdi aktif',
                                      foreground: Color(0xFF167A3D),
                                      background: Color(0xFFE8F9DF),
                                      iconColor: Color(0xFF18BF55),
                                    ),
                                ],
                              ),
                              if (locationText.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: scheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        locationText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),
                              _ProfileSection(
                                icon: Icons.article_outlined,
                                title: 'Hakkında',
                                child: Text(
                                  bio.isEmpty
                                      ? 'Henüz hakkında bilgisi eklenmemiş.'
                                      : bio,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13.5,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (interests.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _ProfileSection(
                                  icon: Icons.favorite_border_rounded,
                                  title: 'İlgi alanları',
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests
                                        .map(
                                          (item) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 13,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  scheme.surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item,
                                              style: TextStyle(
                                                color: scheme.onSurface,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                              if (prompt.isNotEmpty || answer.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _ProfileSection(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: prompt.isEmpty ? 'Profil sorusu' : prompt,
                                  child: Text(
                                    answer,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 13.5,
                                      height: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: SafeArea(
                          child: _CircleActionButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icons.arrow_back_ios_new_rounded,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: SafeArea(
                          child: _CircleActionButton(
                            onPressed: _more,
                            icon: Icons.more_vert_rounded,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: SafeArea(
                          top: false,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _message,
                              borderRadius: BorderRadius.circular(28),
                              child: Ink(
                                height: 62,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD8FF2F),
                                      Color(0xFFBFFF24),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.lime
                                          .withValues(alpha: .26),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      color: AppColors.navy,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Mesaj gönder',
                                      style: TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: AppColors.navy,
        minimumSize: const Size(54, 54),
        shape: const CircleBorder(),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .65),
        ),
        elevation: 2,
      ),
      icon: Icon(icon, size: 24),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.iconColor,
    this.outlined = false,
  });

  final IconData? icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color? iconColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: outlined ? Border.all(color: Colors.white, width: 3) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? foreground, size: 17),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.navy, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 28),
      ),
    );
  }
}

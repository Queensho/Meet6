import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
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
  State<MatchProfileDetailScreen> createState() => _MatchProfileDetailScreenState();
}

class _MatchProfileDetailScreenState extends State<MatchProfileDetailScreen> {
  Map<String, dynamic>? profile;
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
      if (!mounted) return;
      setState(() {
        profile = raw is Map ? Map<String, dynamic>.from(raw) : null;
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
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  List<String> get interests {
    final raw = profile?['interests'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String get name => profile?['display_name']?.toString() ?? 'Meet6';
  String get userId => profile?['user_id']?.toString() ?? '';

  void _message() {
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: widget.matchId,
          name: name,
          userId: userId,
          photoUrl: photos.isEmpty ? '' : photos.first,
          isOnline: profile?['online'] == true,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setDialogState(() => reason = value ?? reason),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detail,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Ayrıntı ekle (isteğe bağlı)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Gönder')),
          ],
        ),
      ),
    );
    if (approved == true) {
      await LiveService.reportUser(userId, reason: reason, detail: detail.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şikâyetin inceleme kuyruğuna alındı.')));
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Onayla')),
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
                  leading: const Icon(Icons.block_rounded, color: Color(0xFFE24A4A)),
                  title: const Text('Kullanıcıyı engelle', style: TextStyle(color: Color(0xFFE24A4A))),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 430,
                                child: photos.isEmpty
                                    ? Container(
                                        color: AppColors.navy,
                                        alignment: Alignment.center,
                                        child: Text(
                                          name.characters.first.toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.lime,
                                            fontSize: 76,
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
                                            child: const Icon(Icons.person_rounded, color: AppColors.lime, size: 70),
                                          ),
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$name, ${(profile?['age'] as num?)?.toInt() ?? ''}',
                                            style: TextStyle(
                                              color: scheme.onSurface,
                                              fontSize: 29,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ),
                                        if (profile?['online'] == true)
                                          const Icon(Icons.circle, size: 12, color: Color(0xFF36C76C)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, color: scheme.primary, size: 17),
                                        const SizedBox(width: 4),
                                        Text(
                                          [profile?['city'], profile?['country']]
                                              .where((e) => e != null && e.toString().isNotEmpty)
                                              .join(', '),
                                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _Section(
                                      title: 'Hakkında',
                                      child: Text(
                                        profile?['bio']?.toString() ?? '',
                                        style: TextStyle(color: scheme.onSurface, fontSize: 13.5, height: 1.45),
                                      ),
                                    ),
                                    if (interests.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      _Section(
                                        title: 'İlgi alanları',
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: interests
                                              .map(
                                                (item) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                                  decoration: BoxDecoration(
                                                    color: scheme.surfaceContainerHigh,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(item, style: TextStyle(color: scheme.onSurface, fontSize: 11, fontWeight: FontWeight.w800)),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    _Section(
                                      title: profile?['profile_prompt']?.toString() ?? 'Profil sorusu',
                                      child: Text(
                                        profile?['profile_answer']?.toString() ?? '',
                                        style: TextStyle(color: scheme.onSurface, fontSize: 14, height: 1.4, fontWeight: FontWeight.w800),
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
                        child: SafeArea(
                          child: IconButton.filled(
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: SafeArea(
                          child: IconButton.filled(
                            onPressed: _more,
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            height: 58,
                            child: FilledButton.icon(
                              onPressed: _message,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.lime,
                                foregroundColor: AppColors.navy,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.chat_bubble_rounded),
                              label: const Text('Mesaj gönder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: scheme.primary, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

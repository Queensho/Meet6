import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/live_service.dart';
import '../../../theme/app_colors.dart';
import 'widgets/settings_page_shell.dart';

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List<Map<String, dynamic>> blocked = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await LiveService.blocks();
      if (!mounted) return;
      setState(() {
        blocked = data;
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsPageShell(
      title: 'Engellenen hesaplar',
      child: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                    ],
                  ),
                )
              : blocked.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                        itemCount: blocked.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = blocked[index];
                          final name = user['display_name']?.toString() ?? 'Meet6';
                          final photos = user['photo_urls'];
                          final photo = photos is List && photos.isNotEmpty ? photos.first.toString() : '';
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                                  child: photo.isEmpty
                                      ? Center(
                                          child: Text(
                                            name.characters.first.toUpperCase(),
                                            style: const TextStyle(color: AppColors.lime, fontSize: 18, fontWeight: FontWeight.w900),
                                          ),
                                        )
                                      : Image.network(
                                          ApiService.absoluteMediaUrl(photo),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.lime),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Odalar ve mesajlaşmadan engellendi',
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _unblock(user),
                                  child: const Text('Engeli kaldır', style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final name = user['display_name']?.toString() ?? 'Bu kullanıcı';
    final id = user['user_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$name için engeli kaldır?'),
        content: const Text('Engeli kaldırırsan gelecekte tekrar aynı odada karşılaşabilirsiniz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Engeli kaldır')),
        ],
      ),
    );
    if (approved == true) {
      await LiveService.unblockUser(id);
      if (!mounted) return;
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name için engel kaldırıldı.')));
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
              child: const Icon(Icons.block_rounded, color: AppColors.navy, size: 34),
            ),
            const SizedBox(height: 16),
            Text('Engellenen hesap yok', style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(
              'Engellediğin kişiler sana mesaj gönderemez ve eşleştirme motoru sizi aynı odaya koymaz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

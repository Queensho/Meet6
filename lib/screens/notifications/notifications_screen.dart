import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/notification_api_service.dart';
import '../../theme/app_colors.dart';
import '../push/push_target_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  bool _isTestNotification(Map<String, dynamic> item) {
    if (item['type']?.toString() == 'push_test') return true;
    final rawData = item['data'];
    if (rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      return data['test'] == true || data['test']?.toString() == 'true';
    }
    return false;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await NotificationApiService.list();
      final raw = response['notifications'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .where((item) => !_isTestNotification(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

      if (items.any((item) => item['read_at'] == null)) {
        unawaited(NotificationApiService.markAllRead().catchError((_) {}));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> item) {
    final raw = item['data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  bool _actionable(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    final data = _data(item);
    if (type == 'room_found') {
      return (data['roomId']?.toString() ?? '').isNotEmpty;
    }
    if (type == 'match' || type == 'message' || type == 'private_message') {
      return (data['matchId']?.toString() ?? '').isNotEmpty;
    }
    return false;
  }

  void _open(Map<String, dynamic> item) {
    if (!_actionable(item)) return;
    final data = <String, dynamic>{
      ..._data(item),
      'type': item['type']?.toString() ?? '',
      'notificationId': item['id']?.toString() ?? '',
    };
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PushTargetScreen(data: data)),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'room_found':
        return Icons.groups_2_rounded;
      case 'match':
        return Icons.favorite_rounded;
      case 'message':
      case 'private_message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inHours < 48) return 'Dün';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Bildirimler yüklenemedi',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 150),
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: AppColors.navy,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Henüz bildirimin yok',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Oda, eşleşme ve mesaj bildirimlerin burada görünecek.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final type = item['type']?.toString() ?? '';
                          final unread = item['read_at'] == null;
                          final actionable = _actionable(item);

                          return Material(
                            color: unread
                                ? AppColors.lime.withValues(alpha: .16)
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: actionable ? () => _open(item) : null,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(alpha: .65),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.lime,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        _iconFor(type),
                                        color: AppColors.navy,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['title']?.toString() ?? 'Meet6',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _timeLabel(item['created_at']),
                                                style: TextStyle(
                                                  color: scheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['body']?.toString() ?? '',
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.3,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (actionable) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

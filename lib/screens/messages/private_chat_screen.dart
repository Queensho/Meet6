import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../services/realtime_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.matchId,
    required this.name,
    required this.userId,
    this.photoUrl = '',
    this.isOnline = false,
    this.fromNewMatch = false,
  });

  final String matchId;
  final String name;
  final String userId;
  final String photoUrl;
  final bool isOnline;
  final bool fromNewMatch;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <Map<String, dynamic>>[];
  final deletingMessageIds = <String>{};

  StreamSubscription<RealtimeEvent>? realtimeSub;
  Timer? typingTimer;
  String? myUserId;
  int lastMessageId = 0;
  bool loading = true;
  bool sending = false;
  bool peerTyping = false;
  late bool peerOnline;
  DateTime? peerLastSeenAt;
  String? error;

  @override
  void initState() {
    super.initState();
    peerOnline = widget.isOnline;
    _start();
  }

  Future<void> _start() async {
    myUserId = await SessionService.loadAuthUserId();
    realtimeSub = RealtimeService.events.listen(_onRealtimeEvent);
    try {
      await RealtimeService.connect();
      final detail = await RealtimeService.joinMatch(widget.matchId);
      _applyMatchDetail(detail);
      await _loadNewMessages();
      await RealtimeService.markMatchRead(widget.matchId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  void _applyMatchDetail(Map<String, dynamic> detail) {
    final raw = detail['profile'];
    if (raw is! Map || !mounted) return;
    final profile = Map<String, dynamic>.from(raw);
    final lastSeen = DateTime.tryParse(profile['last_seen_at']?.toString() ?? '')?.toLocal();
    setState(() {
      peerOnline = profile['online'] == true;
      peerLastSeenAt = lastSeen;
    });
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted) return;
    if (event.type == 'connection:connected') {
      unawaited(_rejoinAfterReconnect());
      return;
    }

    if (event.type == 'match:message' &&
        event.data['matchId']?.toString() == widget.matchId) {
      final raw = event.data['message'];
      if (raw is Map) {
        final message = Map<String, dynamic>.from(raw);
        _appendMessage(message);
        if (message['sender_user_id']?.toString() != myUserId) {
          unawaited(
            RealtimeService.markMatchRead(widget.matchId)
                .catchError((_) => <String, dynamic>{}),
          );
        }
      }
      return;
    }

    if (event.type == 'match:delivered' &&
        event.data['matchId']?.toString() == widget.matchId) {
      final messageId = event.data['messageId']?.toString() ?? '';
      final deliveredAt = event.data['deliveredAt']?.toString();
      if (messageId.isEmpty) return;
      setState(() {
        for (final message in messages) {
          if (message['id']?.toString() == messageId &&
              message['sender_user_id']?.toString() == myUserId) {
            message['delivered_at'] ??= deliveredAt;
          }
        }
      });
      return;
    }

    if (event.type == 'match:read' &&
        event.data['matchId']?.toString() == widget.matchId) {
      final reader = event.data['readerUserId']?.toString();
      if (reader != null && reader != myUserId) {
        final readAt = event.data['readAt']?.toString();
        setState(() {
          for (final message in messages) {
            if (message['sender_user_id']?.toString() == myUserId &&
                message['read_at'] == null) {
              message['delivered_at'] ??= readAt;
              message['read_at'] = readAt;
            }
          }
        });
      }
      return;
    }

    if (event.type == 'match:message-deleted' &&
        event.data['matchId']?.toString() == widget.matchId) {
      final messageId = event.data['messageId']?.toString() ?? '';
      if (messageId.isEmpty) return;
      setState(() {
        messages.removeWhere((item) => item['id']?.toString() == messageId);
        deletingMessageIds.remove(messageId);
      });
      return;
    }

    if (event.type == 'match:typing' &&
        event.data['matchId']?.toString() == widget.matchId) {
      if (event.data['userId']?.toString() == widget.userId) {
        setState(() => peerTyping = event.data['typing'] == true);
      }
      return;
    }

    if (event.type == 'presence:update' &&
        event.data['userId']?.toString() == widget.userId) {
      final online = event.data['online'] == true;
      setState(() {
        // Daha önce görünür biçimde çevrimiçi olan kişi çevrimdışı olduysa
        // bu an güvenli biçimde son görülme kabul edilebilir. show_online kapalı
        // kullanıcılarda peerOnline hiçbir zaman true olmadığı için gizlilik bozulmaz.
        if (peerOnline && !online) peerLastSeenAt = DateTime.now();
        peerOnline = online;
        if (online) peerTyping = false;
      });
    }
  }

  Future<void> _rejoinAfterReconnect() async {
    try {
      final detail = await RealtimeService.joinMatch(widget.matchId);
      _applyMatchDetail(detail);
      await _loadNewMessages();
      await RealtimeService.markMatchRead(widget.matchId);
    } catch (_) {}
  }

  Future<void> _loadNewMessages() async {
    try {
      final incoming = await LiveService.privateMessages(
        widget.matchId,
        after: lastMessageId,
      );
      if (!mounted) return;
      for (final message in incoming) {
        _appendMessage(message, rebuild: false);
      }
      setState(() {
        loading = false;
        error = null;
      });
      if (incoming.isNotEmpty) _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  void _appendMessage(Map<String, dynamic> message, {bool rebuild = true}) {
    final id = int.tryParse(message['id']?.toString() ?? '') ?? 0;
    if (id > 0 && messages.any((item) => item['id']?.toString() == '$id')) return;
    if (id > lastMessageId) lastMessageId = id;
    messages.add(message);
    if (rebuild && mounted) setState(() {});
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    RealtimeService.setTyping(widget.matchId, false);
    typingTimer?.cancel();
    try {
      await RealtimeService.sendPrivateMessage(widget.matchId, text);
      controller.clear();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _onTypingChanged(String value) {
    final typing = value.trim().isNotEmpty;
    RealtimeService.setTyping(widget.matchId, typing);
    typingTimer?.cancel();
    if (typing) {
      typingTimer = Timer(const Duration(milliseconds: 1400), () {
        RealtimeService.setTyping(widget.matchId, false);
      });
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> item) async {
    if (item['sender_user_id']?.toString() != myUserId) return;
    final messageId = item['id']?.toString() ?? '';
    if (messageId.isEmpty || deletingMessageIds.contains(messageId)) return;

    final approved = await showModalBottomSheet<bool>(
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
            child: ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE24A4A)),
              title: const Text(
                'Mesajı sil',
                style: TextStyle(color: Color(0xFFE24A4A), fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Her iki taraftan da kaldırılır.'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ),
        );
      },
    );
    if (approved != true || !mounted) return;

    setState(() => deletingMessageIds.add(messageId));
    try {
      await RealtimeService.deletePrivateMessage(widget.matchId, messageId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => deletingMessageIds.remove(messageId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _presenceText() {
    if (peerTyping) return 'yazıyor...';
    if (peerOnline) return 'Çevrimiçi';
    final lastSeen = peerLastSeenAt;
    if (lastSeen == null) return 'Meet6 eşleşmesi';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    if (difference.inMinutes < 1) return 'Az önce çevrimiçiydi';
    if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce çevrimiçiydi';
    if (difference.inHours < 24 &&
        now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day) {
      return 'Son görülme ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    if (lastSeen.year == yesterday.year &&
        lastSeen.month == yesterday.month &&
        lastSeen.day == yesterday.day) {
      return 'Dün ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
    }
    return 'Son görülme ${lastSeen.day.toString().padLeft(2, '0')}.${lastSeen.month.toString().padLeft(2, '0')} ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
  }

  Widget _receipt(Map<String, dynamic> item, ColorScheme scheme) {
    final read = item['read_at'] != null;
    final delivered = item['delivered_at'] != null;
    final deleting = deletingMessageIds.contains(item['id']?.toString());

    if (deleting) {
      return Text(
        'Siliniyor...',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final text = read ? 'Okundu' : delivered ? 'Teslim edildi' : 'Gönderildi';
    final icon = read || delivered ? Icons.done_all_rounded : Icons.done_rounded;
    final color = read ? AppColors.blue : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _openMenu() async {
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
                  leading: const Icon(Icons.block_rounded, color: Color(0xFFE24A4A)),
                  title: const Text('Engelle', style: TextStyle(color: Color(0xFFE24A4A))),
                  onTap: () => Navigator.pop(sheetContext, 'block'),
                ),
                ListTile(
                  leading: const Icon(Icons.heart_broken_outlined),
                  title: const Text('Eşleşmeyi kaldır'),
                  onTap: () => Navigator.pop(sheetContext, 'unmatch'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await _report();
    } else if (action == 'block') {
      final ok = await _confirm(
        'Kullanıcı engellensin mi?',
        'Bir daha aynı odada eşleştirilmezsiniz ve bu sohbet kapanır.',
      );
      if (ok == true) {
        await LiveService.blockUser(widget.userId);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (action == 'unmatch') {
      final ok = await _confirm('Eşleşme kaldırılsın mı?', 'Bu özel sohbet kapanır.');
      if (ok == true) {
        await LiveService.unmatch(widget.matchId);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
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

  Future<void> _report() async {
    final detail = TextEditingController();
    String reason = 'Rahatsız edici davranış';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kullanıcıyı şikâyet et'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
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
                decoration: const InputDecoration(hintText: 'İstersen ayrıntı ekle...'),
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
      await LiveService.reportUser(widget.userId, reason: reason, detail: detail.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikâyetin alındı.')),
        );
      }
    }
    detail.dispose();
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    realtimeSub?.cancel();
    RealtimeService.setTyping(widget.matchId, false);
    unawaited(RealtimeService.leaveMatch(widget.matchId));
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final outgoingBubble = dark ? AppColors.lime : AppColors.navy;
    final outgoingText = dark ? AppColors.navy : Colors.white;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(backgroundColor: scheme.surface),
                      icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                    ),
                    const SizedBox(width: 7),
                    _Avatar(name: widget.name, photoUrl: widget.photoUrl, size: 44),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Text(
                              _presenceText(),
                              key: ValueKey('$peerTyping-$peerOnline-${peerLastSeenAt?.millisecondsSinceEpoch}'),
                              style: TextStyle(
                                color: peerTyping || peerOnline
                                    ? const Color(0xFF36C76C)
                                    : scheme.onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openMenu,
                      icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: loading && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
                  : error != null && messages.isEmpty
                      ? Center(
                          child: Text(
                            error!,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                          itemCount: messages.length +
                              (widget.fromNewMatch && messages.isEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (widget.fromNewMatch && messages.isEmpty) {
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Karşılıklı seçim yaptınız. İlk mesajı gönderebilirsin 👋',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = messages[index];
                            final mine = item['sender_user_id']?.toString() == myUserId;
                            final deleting = deletingMessageIds.contains(item['id']?.toString());
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment:
                                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onLongPress: mine ? () => _deleteMessage(item) : null,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 150),
                                      opacity: deleting ? .45 : 1,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 286),
                                        margin: const EdgeInsets.only(bottom: 3),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mine ? outgoingBubble : scheme.surface,
                                          borderRadius: BorderRadius.circular(17),
                                          border: mine
                                              ? null
                                              : Border.all(color: scheme.outlineVariant),
                                        ),
                                        child: Text(
                                          item['body']?.toString() ?? '',
                                          style: TextStyle(
                                            color: mine ? outgoingText : scheme.onSurface,
                                            fontSize: 13.5,
                                            height: 1.32,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (mine)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5, bottom: 6),
                                      child: _receipt(item, scheme),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: _onTypingChanged,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size(50, 50),
                      ),
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: AppColors.navy,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl, required this.size});

  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
      ),
      child: photoUrl.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '6' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              ApiService.absoluteMediaUrl(photoUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_rounded, color: AppColors.lime),
            ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/gift_service.dart';
import '../../services/live_service.dart';
import '../../services/realtime_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import 'room_force_selection_button.dart';
import 'room_gift_sheet.dart';
import 'room_selection_screen.dart';

class RoomChatScreen extends StatefulWidget {
  const RoomChatScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <Map<String, dynamic>>[];

  StreamSubscription<RealtimeEvent>? realtimeSub;
  Timer? countdownTimer;
  String? myUserId;
  Map<String, dynamic>? room;
  int lastMessageId = 0;
  int lastGiftId = 0;
  bool sending = false;
  bool loading = true;
  bool navigating = false;
  bool extensionSheetOpen = false;
  bool giftSheetOpen = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    myUserId = await SessionService.loadAuthUserId();
    realtimeSub = RealtimeService.events.listen(_onRealtimeEvent);
    try {
      await RealtimeService.connect();
      await _refreshSnapshot();
      await RealtimeService.joinRoom(widget.roomId);
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || navigating) return;
    if (event.type == 'connection:connected') {
      unawaited(_rejoinAfterReconnect());
      return;
    }
    if (event.type == 'room:update' && event.data['roomId']?.toString() == widget.roomId) {
      final raw = event.data['room'];
      if (raw is Map) {
        final latest = Map<String, dynamic>.from(raw);
        setState(() {
          room = latest;
          error = null;
        });
        _handleRoomState(latest);
      }
      return;
    }
    if (event.type == 'room:message' && event.data['roomId']?.toString() == widget.roomId) {
      final raw = event.data['message'];
      if (raw is Map) {
        final message = Map<String, dynamic>.from(raw);
        if (message['_kind']?.toString() == 'gift') {
          _appendGift(message);
        } else {
          _appendMessage(message);
        }
      }
      return;
    }
    if (event.type == 'room:sync-messages' && event.data['roomId']?.toString() == widget.roomId) {
      unawaited(_loadTimeline());
    }
  }

  Future<void> _rejoinAfterReconnect() async {
    try {
      await RealtimeService.joinRoom(widget.roomId);
      await _refreshSnapshot();
    } catch (_) {}
  }

  Future<void> _refreshSnapshot() async {
    if (!mounted || navigating) return;
    try {
      final roomData = await LiveService.room(widget.roomId);
      await _loadTimeline();
      if (!mounted) return;
      setState(() {
        room = roomData;
        loading = false;
        error = null;
      });
      _handleRoomState(roomData);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    }
  }

  Future<void> _loadTimeline() async {
    await Future.wait([
      _loadNewMessages(),
      _loadNewGifts(),
    ]);
  }

  Future<void> _loadNewMessages() async {
    try {
      final incoming = await LiveService.roomMessages(widget.roomId, after: lastMessageId);
      if (!mounted) return;
      for (final message in incoming) {
        _appendMessage(message, rebuild: false, scroll: false);
      }
      if (incoming.isNotEmpty) {
        _sortTimeline();
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _loadNewGifts() async {
    try {
      final incoming = await GiftService.roomHistory(widget.roomId, after: lastGiftId);
      if (!mounted) return;
      for (final gift in incoming) {
        _appendGift(gift, rebuild: false, scroll: false);
      }
      if (incoming.isNotEmpty) {
        _sortTimeline();
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {
      // Hediye geçmişi geçici olarak alınamazsa normal sohbet çalışmaya devam eder.
    }
  }

  void _appendMessage(
    Map<String, dynamic> message, {
    bool rebuild = true,
    bool scroll = true,
  }) {
    final id = int.tryParse(message['id']?.toString() ?? '') ?? 0;
    if (id > 0 && messages.any((item) => item['_kind'] != 'gift' && item['id']?.toString() == '$id')) {
      return;
    }
    if (id > lastMessageId) lastMessageId = id;
    messages.add({...message, '_kind': message['_kind'] ?? 'text'});
    _sortTimeline();
    if (rebuild && mounted) setState(() {});
    if (scroll) _scrollToBottom();
  }

  void _appendGift(
    Map<String, dynamic> gift, {
    bool rebuild = true,
    bool scroll = true,
  }) {
    final giftId = int.tryParse(gift['gift_id']?.toString() ?? '') ?? 0;
    if (giftId > 0 && messages.any((item) => item['_kind'] == 'gift' && item['gift_id']?.toString() == '$giftId')) {
      return;
    }
    if (giftId > lastGiftId) lastGiftId = giftId;
    messages.add({...gift, '_kind': 'gift'});
    _sortTimeline();
    if (rebuild && mounted) setState(() {});
    if (scroll) _scrollToBottom();

    if (gift['recipient_user_id']?.toString() == myUserId &&
        gift['sender_user_id']?.toString() != myUserId &&
        rebuild &&
        mounted) {
      final sender = gift['display_name']?.toString() ?? 'Biri';
      final emoji = gift['emoji']?.toString() ?? '🎁';
      final name = gift['gift_name']?.toString() ?? 'hediye';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text('$sender sana $emoji $name gönderdi.'),
        ),
      );
    }
  }

  void _sortTimeline() {
    messages.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      if (aTime != bTime) return aTime.compareTo(bTime);
      final aGift = a['_kind'] == 'gift';
      final bGift = b['_kind'] == 'gift';
      if (aGift != bGift) return aGift ? 1 : -1;
      final aId = int.tryParse((aGift ? a['gift_id'] : a['id'])?.toString() ?? '') ?? 0;
      final bId = int.tryParse((bGift ? b['gift_id'] : b['id'])?.toString() ?? '') ?? 0;
      return aId.compareTo(bId);
    });
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || room?['status'] != 'active') return;
      final current = (room?['secondsLeft'] as num?)?.toInt() ?? 0;
      if (current <= 0) return;
      setState(() => room = {...?room, 'secondsLeft': current - 1});
    });
  }

  void _handleRoomState(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    if (status == 'selection' && !navigating) {
      navigating = true;
      countdownTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomSelectionScreen(
            roomId: widget.roomId,
            profileName: widget.profileName,
          ),
        ),
      );
      return;
    }
    if (status == 'closed' && !navigating) {
      navigating = true;
      countdownTimer?.cancel();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final canVote = data['canVoteExtension'] == true;
    final myVote = data['myExtensionVote'];
    if (canVote && myVote == null && !extensionSheetOpen) {
      extensionSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showExtensionVote());
    }
  }

  Future<void> _showExtensionVote() async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final vote = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_rounded, color: AppColors.lime, size: 38),
              const SizedBox(height: 10),
              Text(
                'Sohbeti +5 dakika uzatalım mı?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'En az 4 kişi evet derse oda 5 dakika uzar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Hayır'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.navy,
                      ),
                      child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (vote != null) {
      try {
        await RealtimeService.voteRoomExtension(widget.roomId, vote);
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    extensionSheetOpen = false;
  }

  Future<void> _openGiftSheet() async {
    final userId = myUserId;
    if (userId == null || userId.isEmpty || giftSheetOpen || room?['status'] != 'active') return;
    if (members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hediye gönderebileceğin başka biri odada değil.')),
      );
      return;
    }

    giftSheetOpen = true;
    final result = await RoomGiftSheet.show(
      context,
      roomId: widget.roomId,
      members: members,
      myUserId: userId,
    );
    giftSheetOpen = false;
    if (!mounted || result == null) return;
    final rawGift = result['gift'];
    if (rawGift is Map) {
      _appendGift(Map<String, dynamic>.from(rawGift));
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending || room?['status'] != 'active') return;
    setState(() => sending = true);
    try {
      await RealtimeService.sendRoomMessage(widget.roomId, text);
      messageController.clear();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => sending = false);
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

  String _timerText() {
    final seconds = (room?['secondsLeft'] as num?)?.toInt() ?? 0;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> get members {
    final raw = room?['members'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Widget _avatar(Map<String, dynamic> member, {double size = 44}) {
    final scheme = Theme.of(context).colorScheme;
    final photos = member['photo_urls'];
    final path = photos is List && photos.isNotEmpty ? photos.first.toString() : '';
    final name = member['display_name']?.toString().trim() ?? '';
    final mine = member['user_id']?.toString() == myUserId;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navy,
        border: Border.all(
          color: mine ? AppColors.lime : scheme.outlineVariant,
          width: mine ? 2.5 : 1.5,
        ),
      ),
      child: path.isEmpty
          ? Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900),
              ),
            )
          : Image.network(
              ApiService.absoluteMediaUrl(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: AppColors.lime),
            ),
    );
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    countdownTimer?.cancel();
    unawaited(RealtimeService.leaveRoom(widget.roomId));
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: PhoneFrame(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _showLeaveInfo(context),
                      style: IconButton.styleFrom(backgroundColor: scheme.surface),
                      icon: Icon(Icons.close_rounded, color: scheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meet6 odası',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${members.length}/6 kişi · canlı',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RoomForceSelectionButton(
                      roomId: widget.roomId,
                      profileName: widget.profileName,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.lime : AppColors.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _timerText(),
                        style: TextStyle(
                          color: dark ? AppColors.navy : AppColors.lime,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final name = member['display_name']?.toString() ?? 'Meet6';
                  final mine = member['user_id']?.toString() == myUserId;
                  return SizedBox(
                    width: 56,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _avatar(member),
                        const SizedBox(height: 3),
                        Text(
                          mine ? 'Sen' : name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9.5,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: loading && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
                  : error != null && messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            if (message['_kind']?.toString() == 'gift') {
                              return RoomGiftMessageCard(gift: message, myUserId: myUserId);
                            }

                            final senderId = message['sender_user_id']?.toString();
                            final system = senderId == null || senderId == 'null';
                            if (system) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      message['body']?.toString() ?? '',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final mine = senderId == myUserId;
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 285),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? (dark ? AppColors.lime : AppColors.navy)
                                      : scheme.surface,
                                  borderRadius: BorderRadius.circular(17),
                                  border: mine ? null : Border.all(color: scheme.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!mine)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          message['display_name']?.toString() ?? '',
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      message['body']?.toString() ?? '',
                                      style: TextStyle(
                                        color: mine
                                            ? (dark ? AppColors.navy : Colors.white)
                                            : scheme.onSurface,
                                        fontSize: 13.5,
                                        height: 1.32,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
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
                        controller: messageController,
                        enabled: room?['status'] == 'active',
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Hediye gönder',
                      onPressed: room?['status'] == 'active' ? _openGiftSheet : null,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHigh,
                        foregroundColor: scheme.onSurface,
                        minimumSize: const Size(46, 46),
                      ),
                      icon: const Icon(Icons.card_giftcard_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size(50, 50),
                      ),
                      icon: sending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
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

  Future<void> _showLeaveInfo(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('Oda devam ediyor'),
        content: const Text(
          'Ana ekrana dönsen bile aktif odan sunucuda korunur. Tekrar açtığında odaya yeniden bağlanabilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Ana ekrana dön'),
          ),
        ],
      ),
    );
  }
}

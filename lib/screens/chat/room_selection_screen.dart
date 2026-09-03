import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../services/realtime_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../matches/match_success_screen.dart';

class RoomSelectionScreen extends StatefulWidget {
  const RoomSelectionScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<RoomSelectionScreen> createState() => _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends State<RoomSelectionScreen> {
  String? myUserId;
  Map<String, dynamic>? room;
  String? selectedUserId;
  bool submitted = false;
  bool submitting = false;
  bool openingMatch = false;
  String? error;
  int selectionSecondsLeft = 0;
  Timer? countdownTimer;
  StreamSubscription<RealtimeEvent>? realtimeSub;

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
      await RealtimeService.joinRoom(widget.roomId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || openingMatch) return;

    if (event.type == 'connection:connected') {
      unawaited(_rejoin());
      return;
    }

    if (event.type == 'room:update' &&
        event.data['roomId']?.toString() == widget.roomId) {
      final raw = event.data['room'];
      if (raw is Map) {
        final latest = Map<String, dynamic>.from(raw);
        _applyRoom(latest);
        if (latest['status'] == 'closed') {
          unawaited(_checkSelectionResult());
        }
      }
      return;
    }

    if (event.type == 'room:selection-status' &&
        event.data['roomId']?.toString() == widget.roomId &&
        event.data['matched'] == true &&
        event.data['matchId'] != null) {
      unawaited(_openMatch(event.data['matchId'].toString()));
      return;
    }

    if (event.type == 'match:created' &&
        event.data['roomId']?.toString() == widget.roomId &&
        event.data['matchId'] != null) {
      unawaited(_openMatch(event.data['matchId'].toString()));
    }
  }

  Future<void> _rejoin() async {
    try {
      await RealtimeService.joinRoom(widget.roomId);
      await _load();
      await _checkSelectionResult();
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final data = await LiveService.room(widget.roomId);
      if (!mounted) return;
      _applyRoom(data);
      final chosen = data['mySelectionUserId']?.toString();
      if ((chosen != null && chosen.isNotEmpty && chosen != 'null') ||
          data['status'] == 'closed') {
        unawaited(_checkSelectionResult());
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  void _applyRoom(Map<String, dynamic> data) {
    if (!mounted) return;
    final seconds = (data['selectionSecondsLeft'] as num?)?.toInt() ?? 0;
    final chosen = data['mySelectionUserId']?.toString();
    setState(() {
      room = data;
      selectionSecondsLeft = seconds;
      if (chosen != null && chosen.isNotEmpty && chosen != 'null') {
        selectedUserId = chosen;
        submitted = true;
      }
      error = null;
    });
    _startCountdown();
  }

  int get selectionDurationSeconds {
    final config = room?['config'];
    if (config is Map) {
      final raw = (config['selectionSeconds'] as num?)?.toInt() ?? 10;
      return raw.clamp(1, 120).toInt();
    }
    return 10;
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    if (selectionSecondsLeft <= 0 || room?['status'] != 'selection') return;
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (selectionSecondsLeft <= 1) {
        timer.cancel();
        setState(() => selectionSecondsLeft = 0);
        unawaited(_syncAfterExpiry());
      } else {
        setState(() => selectionSecondsLeft--);
      }
    });
  }

  Future<void> _syncAfterExpiry() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    try {
      final latest = await LiveService.room(widget.roomId);
      if (mounted) _applyRoom(latest);
    } catch (_) {}
    await _checkSelectionResult();
  }

  Future<void> _checkSelectionResult() async {
    if (openingMatch) return;
    try {
      final result = await LiveService.roomSelectionResult(widget.roomId);
      if (!mounted) return;

      final resultSelected = result['selectedUserId']?.toString();
      if (result['submitted'] == true) {
        setState(() {
          submitted = true;
          if (resultSelected != null &&
              resultSelected.isNotEmpty &&
              resultSelected != 'null') {
            selectedUserId = resultSelected;
          }
        });
      }

      if (result['matched'] == true && result['matchId'] != null) {
        await _openMatch(result['matchId'].toString());
      }
    } catch (_) {
      // Realtime event ana yol; bu istek yalnızca kaçırılan eventi telafi eder.
    }
  }

  List<Map<String, dynamic>> get candidates {
    final raw = room?['members'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['user_id']?.toString() != myUserId)
        .toList();
  }

  bool get selectionExpired {
    if (room == null) return false;
    return room?['status'] == 'closed' ||
        (room?['status'] == 'selection' && selectionSecondsLeft <= 0);
  }

  Future<void> _submitChoice(String userId) async {
    if (userId.isEmpty || submitting || submitted || selectionExpired) return;

    setState(() {
      selectedUserId = userId;
      submitting = true;
      error = null;
    });

    try {
      final result = await RealtimeService.submitRoomSelection(
        widget.roomId,
        userId,
      );
      if (!mounted) return;

      setState(() {
        submitted = true;
        submitting = false;
      });

      if (result['matched'] == true && result['matchId'] != null) {
        await _openMatch(result['matchId'].toString());
      } else {
        // Karşı taraf birkaç ms sonra seçerse realtime eventi açar.
        // Event kaçarsa seçim sonunda REST sonucu tekrar kontrol edilir.
        unawaited(_checkSelectionResult());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        selectedUserId = null;
        error = e.message;
      });
    }
  }

  Future<void> _openMatch(String matchId) async {
    if (openingMatch) return;
    openingMatch = true;
    countdownTimer?.cancel();
    try {
      final detail = await LiveService.matchDetail(matchId);
      if (!mounted) return;
      final raw = detail['profile'];
      final profile = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MatchSuccessScreen(
            matchId: matchId,
            profileName: widget.profileName,
            matchProfile: profile,
          ),
        ),
      );
    } catch (_) {
      openingMatch = false;
    }
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    countdownTimer?.cancel();
    unawaited(RealtimeService.leaveRoom(widget.roomId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final closed = selectionExpired;
    final duration = selectionDurationSeconds;
    final seconds = selectionSecondsLeft.clamp(0, duration).toInt();
    final progress = duration <= 0 ? 0.0 : seconds / duration;
    final urgent = seconds <= 3 && !closed;

    String title;
    String subtitle;
    if (closed && submitted) {
      title = 'Seçim tamamlandı';
      subtitle = 'Karşılıklı seçim varsa eşleşme otomatik açılır.';
    } else if (closed) {
      title = 'Seçim süresi\ndoldu';
      subtitle = '$duration saniyelik gizli seçim penceresi kapandı.';
    } else if (submitted) {
      title = 'Seçimin gizlice\nkaydedildi';
      subtitle = 'Karşı taraf da seni seçerse eşleşme anında açılır.';
    } else {
      title = 'Kiminle devam\netmek istersin?';
      subtitle = 'Bir kişiye dokun. Seçimin anında ve gizlice kaydedilir.';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: CircularProgressIndicator(
                          value: closed ? 0 : progress,
                          strokeWidth: 4,
                          backgroundColor: scheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            urgent ? const Color(0xFFE76A60) : AppColors.blue,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: urgent
                              ? const Color(0xFFFFE7DF)
                              : AppColors.lime,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (urgent
                                      ? const Color(0xFFE76A60)
                                      : AppColors.lime)
                                  .withOpacity(.24),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          closed ? '0' : '$seconds',
                          style: TextStyle(
                            color: urgent
                                ? const Color(0xFFE76A60)
                                : AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 31,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFE76A60),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: candidates.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.lime,
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final person = candidates[index];
                            final id = person['user_id']?.toString() ?? '';
                            final selected = selectedUserId == id;
                            final name =
                                person['display_name']?.toString() ?? 'Meet6';
                            final age = (person['age'] as num?)?.toInt();
                            final photos = person['photo_urls'];
                            final photo = photos is List && photos.isNotEmpty
                                ? photos.first.toString()
                                : '';
                            final trimmedName = name.trim();
                            final initial = trimmedName.isEmpty
                                ? '6'
                                : trimmedName.characters.first.toUpperCase();

                            return InkWell(
                              onTap: submitted || closed || submitting
                                  ? null
                                  : () => unawaited(_submitChoice(id)),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.lime
                                      : scheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.navy
                                        : scheme.outlineVariant,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(
                                        color: AppColors.navy,
                                        shape: BoxShape.circle,
                                      ),
                                      child: photo.isEmpty
                                          ? Center(
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  color: AppColors.lime,
                                                  fontSize: 21,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            )
                                          : Image.network(
                                              ApiService.absoluteMediaUrl(photo),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Center(
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    color: AppColors.lime,
                                                    fontSize: 21,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        age == null ? name : '$name, $age',
                                        style: TextStyle(
                                          color: selected
                                              ? AppColors.navy
                                              : scheme.onSurface,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (submitting && selected)
                                      const SizedBox(
                                        width: 23,
                                        height: 23,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.navy,
                                        ),
                                      )
                                    else
                                      Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: selected
                                            ? AppColors.navy
                                            : scheme.onSurfaceVariant,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: closed
                      ? OutlinedButton.icon(
                          onPressed: openingMatch
                              ? null
                              : () => Navigator.of(context)
                                  .popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text(
                            'Ana ekrana dön',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        )
                      : submitted
                          ? OutlinedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                ),
                              ),
                              label: const Text(
                                'Karşılıklı seçim bekleniyor...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: dark
                                    ? scheme.surfaceContainerHigh
                                    : AppColors.softSurface,
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                submitting
                                    ? 'Seçimin kaydediliyor...'
                                    : 'Bir kişiye dokunman yeterli',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

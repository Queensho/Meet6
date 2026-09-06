import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../services/room_queue_api_service.dart';
import '../../services/voice_room_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';
import '../chat/room_chat_screen.dart';
import '../chat/voice_room_screen.dart';
import 'game_test_room_screen.dart';

class RoomSearchingScreen extends StatefulWidget {
  const RoomSearchingScreen({
    super.key,
    this.profileName = '',
    this.roomDurationMinutes = 15,
    this.roomMode = 'text',
  });

  final String profileName;
  final int roomDurationMinutes;
  final String roomMode;

  bool get voiceMode => roomMode == 'voice';
  bool get gameMode => roomMode == 'game';

  @override
  State<RoomSearchingScreen> createState() => _RoomSearchingScreenState();
}

class _RoomSearchingScreenState extends State<RoomSearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  StreamSubscription<RealtimeEvent>? realtimeSub;
  Timer? searchCycleTimer;

  bool leavingForRoom = false;
  bool loading = true;
  bool firstConnectionSeen = false;
  bool joining = false;
  bool cycleRestarting = false;
  String? error;
  int queueTotal = 0;
  int queuePosition = 0;
  int searchCycle = 1;
  int cycleDurationSeconds = 15;
  int cycleSecondsLeft = 15;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    if (widget.gameMode) {
      loading = false;
      leavingForRoom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameTestRoomScreen(profileName: widget.profileName),
          ),
        );
      });
    } else {
      _startRealtime();
    }
  }

  Future<void> _startRealtime() async {
    await realtimeSub?.cancel();
    realtimeSub = RealtimeService.events.listen(_onRealtimeEvent);
    try {
      await RealtimeService.connect();
      if (!mounted) return;
      await _joinQueue();
    } on ApiException catch (e) {
      if (!mounted) return;
      searchCycleTimer?.cancel();
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      searchCycleTimer?.cancel();
      setState(() {
        loading = false;
        error = widget.voiceMode
            ? 'Premium birebir sesli eşleşme servisine bağlanılamadı. Tekrar dene.'
            : 'Oda servisine bağlanılamadı. Tekrar dene.';
      });
    }
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || leavingForRoom) return;
    if (event.type == 'connection:connected') {
      if (firstConnectionSeen) {
        unawaited(_joinQueue());
      } else {
        firstConnectionSeen = true;
      }
      return;
    }
    if (event.type == 'connection:disconnected') {
      setState(() => error = 'Bağlantı yenileniyor...');
      return;
    }
    if (!widget.voiceMode &&
        (event.type == 'queue:status' || event.type == 'queue:matched')) {
      unawaited(_handleStatus(event.data));
    }
  }

  Future<void> _joinQueue({bool newCycle = false}) async {
    if (joining || leavingForRoom || widget.gameMode) return;
    joining = true;
    try {
      final Map<String, dynamic> data;
      if (widget.voiceMode) {
        data = await VoiceRoomService.joinQueue();
      } else if (RealtimeService.debugAckOverride != null) {
        data = await RealtimeService.joinQueue();
      } else {
        data = await RoomQueueApiService.joinQueue(
          roomDurationMinutes: widget.roomDurationMinutes,
        );
      }
      if (!mounted) return;
      await _handleStatus(data);
      if (!leavingForRoom && data['state']?.toString() != 'room') {
        _startSearchCycle(data, increment: newCycle);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      searchCycleTimer?.cancel();
      setState(() {
        loading = false;
        error = e.message;
      });
    } finally {
      joining = false;
    }
  }

  void _startSearchCycle(Map<String, dynamic> data, {required bool increment}) {
    if (!mounted || leavingForRoom) return;
    searchCycleTimer?.cancel();
    final rawSeconds = (data['nextRetrySeconds'] as num?)?.toInt() ?? 15;
    final seconds = rawSeconds.clamp(5, 120).toInt();
    setState(() {
      if (increment) searchCycle++;
      cycleDurationSeconds = seconds;
      cycleSecondsLeft = seconds;
      error = null;
    });
    searchCycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || leavingForRoom) {
        timer.cancel();
        return;
      }
      if (cycleSecondsLeft <= 1) {
        timer.cancel();
        setState(() => cycleSecondsLeft = 0);
        unawaited(_restartSearchCycle());
      } else {
        setState(() => cycleSecondsLeft--);
      }
    });
  }

  Future<void> _restartSearchCycle() async {
    if (cycleRestarting || leavingForRoom || !mounted) return;
    cycleRestarting = true;
    try {
      await _joinQueue(newCycle: true);
    } finally {
      cycleRestarting = false;
    }
  }

  Future<void> _handleStatus(Map<String, dynamic> data) async {
    final state = data['state']?.toString();
    if (state == 'room') {
      final rawRoom = data['room'];
      if (rawRoom is! Map) return;
      final room = Map<String, dynamic>.from(rawRoom);
      final roomId = room['id']?.toString() ?? '';
      if (roomId.isEmpty || leavingForRoom) return;
      leavingForRoom = true;
      searchCycleTimer?.cancel();
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
          queueTotal = widget.voiceMode ? 2 : 6;
          queuePosition = 1;
          cycleSecondsLeft = 0;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.voiceMode
              ? VoiceRoomScreen(roomId: roomId, profileName: widget.profileName)
              : RoomChatScreen(roomId: roomId, profileName: widget.profileName),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      error = null;
      queueTotal = (data['total'] as num?)?.toInt() ?? 0;
      queuePosition = (data['position'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _cancel() async {
    searchCycleTimer?.cancel();
    try {
      if (widget.voiceMode) {
        await VoiceRoomService.cancelQueue();
      } else {
        await RealtimeService.cancelQueue();
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  double get _cycleProgress {
    if (cycleDurationSeconds <= 0) return 0;
    return cycleSecondsLeft.clamp(0, cycleDurationSeconds) / cycleDurationSeconds;
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    searchCycleTimer?.cancel();
    pulse.dispose();
    if (!leavingForRoom && !widget.gameMode) {
      if (widget.voiceMode) {
        unawaited(VoiceRoomService.cancelQueue().catchError((_) {}));
      } else {
        unawaited(RealtimeService.cancelQueue().catchError((_) => <String, dynamic>{}));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final connectionOkay = error == null || error == 'Bağlantı yenileniyor...';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF101D16), Color(0xFF071022)]
                  : const [Color(0xFFD8FF32), Color(0xFFAECB18)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Meet6MiniBrand(height: 29),
                      const Spacer(),
                      if (widget.voiceMode || widget.roomDurationMinutes == 30)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            widget.voiceMode ? '1’E 1 PREMIUM' : '30 DK PREMIUM',
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: _cancel,
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            color: dark ? Colors.white70 : AppColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (context, _) {
                      final orbSize = 170 + pulse.value * 18;
                      return SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: orbSize + 22,
                              height: orbSize + 22,
                              child: CircularProgressIndicator(
                                value: leavingForRoom ? 1 : _cycleProgress,
                                strokeWidth: 7,
                                backgroundColor: (dark ? Colors.white : AppColors.navy).withOpacity(.14),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  dark ? AppColors.lime : AppColors.navy,
                                ),
                              ),
                            ),
                            Container(
                              width: orbSize,
                              height: orbSize,
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.navy, width: 2.5),
                              ),
                              alignment: Alignment.center,
                              child: widget.voiceMode
                                  ? const Icon(Icons.mic_rounded, color: AppColors.navy, size: 58)
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          leavingForRoom ? '6' : '${cycleSecondsLeft.clamp(0, 999)}',
                                          style: const TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 70,
                                            fontWeight: FontWeight.w900,
                                            height: .9,
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        const Text(
                                          '6 kişilik oda',
                                          style: TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    error != null && error != 'Bağlantı yenileniyor...'
                        ? 'Bağlantı sorunu'
                        : leavingForRoom
                            ? (widget.voiceMode ? 'Birebir eşleşme bulundu!' : 'Uygun oda bulundu!')
                            : (widget.voiceMode ? 'Premium 1’e 1 eşleşme aranıyor...' : 'Oda aranıyor...'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error ??
                        (leavingForRoom
                            ? (widget.voiceMode
                                ? '2 kişi hazır. Sesli görüşmeye bağlanıyorsun.'
                                : '6 kişi hazır. Odaya bağlanıyorsun.')
                            : queueTotal > 0
                                ? (widget.voiceMode
                                    ? 'Birebir Premium havuzunda $queueTotal kişi var. Sıra konumun: $queuePosition'
                                    : '${widget.roomDurationMinutes} dk havuzunda $queueTotal kişi var. Sıra konumun: $queuePosition')
                                : (widget.voiceMode
                                    ? 'Tercihlerine uyan bir Premium kullanıcı bekleniyor.'
                                    : '${widget.roomDurationMinutes} dk oda için tercihlerine uyan kullanıcılar bekleniyor.')),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white70 : AppColors.navy.withOpacity(.66),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!leavingForRoom && connectionOkay) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Süre dolarsa sıranı kaybetmeden otomatik yeni oda aranır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? Colors.white54 : AppColors.navy.withOpacity(.52),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (error != null && error != 'Bağlantı yenileniyor...')
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          loading = true;
                          error = null;
                          searchCycle = 1;
                        });
                        _startRealtime();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar dene'),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surface.withOpacity(dark ? .72 : .52),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.voiceMode
                                  ? 'Premium kontrolü ve eşleşme filtreleri sunucuda uygulanıyor.'
                                  : 'Canlı bağlantı açık. Eşleşme filtreleri sunucuda uygulanıyor.',
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    widget.voiceMode
                        ? 'Sesli oda yalnızca uygun Premium kullanıcı hazır olduğunda başlar.'
                        : '${widget.roomDurationMinutes} dakikalık oda yalnızca 6 uygun kullanıcı hazır olduğunda başlar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white54 : AppColors.navy.withOpacity(.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

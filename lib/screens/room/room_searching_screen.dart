import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/realtime_service.dart';
import '../../services/room_queue_api_service.dart';
import '../../services/voice_room_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../chat/room_chat_screen.dart';
import '../chat/voice_room_screen.dart';
import 'mini_game_room_screen.dart';
import 'tabu_room_screen.dart';

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
  Timer? pollTimer;

  bool joining = false;
  bool leavingForRoom = false;
  bool loading = true;
  bool firstConnectionSeen = false;
  String? error;
  int queueTotal = 0;
  int queuePosition = 0;
  int secondsLeft = 2;

  String get _gameKey => MiniGameSelectionService.selectedGameKey;
  bool get _tabu => widget.gameMode && _gameKey == 'tabu';

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    if (widget.gameMode) {
      unawaited(_joinGameQueue());
    } else {
      unawaited(_startRealtime());
    }
  }

  Future<void> _startRealtime() async {
    await realtimeSub?.cancel();
    realtimeSub = RealtimeService.events.listen(_onRealtimeEvent);
    try {
      await RealtimeService.connect();
      if (!mounted) return;
      await _joinStandardQueue();
    } on ApiException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = widget.voiceMode
              ? 'Premium birebir eşleşme servisine bağlanılamadı. Tekrar dene.'
              : 'Oda servisine bağlanılamadı. Tekrar dene.';
        });
      }
    }
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || leavingForRoom || widget.gameMode) return;
    if (event.type == 'connection:connected') {
      if (firstConnectionSeen) {
        unawaited(_joinStandardQueue());
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

  Future<void> _joinStandardQueue() async {
    if (joining || leavingForRoom) return;
    joining = true;
    try {
      final data = widget.voiceMode
          ? await VoiceRoomService.joinQueue()
          : RealtimeService.debugAckOverride != null
              ? await RealtimeService.joinQueue()
              : await RoomQueueApiService.joinQueue(
                  roomDurationMinutes: widget.roomDurationMinutes,
                );
      if (mounted) await _handleStatus(data);
    } on ApiException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    } finally {
      joining = false;
    }
  }

  Future<void> _joinGameQueue({bool statusOnly = false}) async {
    if (joining || leavingForRoom || !mounted) return;
    joining = true;
    try {
      final Map<String, dynamic> data;
      if (_tabu) {
        data = statusOnly
            ? await RoomQueueApiService.tabuQueueStatus()
            : await RoomQueueApiService.joinTabuQueue();
      } else {
        data = statusOnly
            ? await RoomQueueApiService.miniGameQueueStatus(gameKey: _gameKey)
            : await RoomQueueApiService.joinMiniGameQueue(gameKey: _gameKey);
      }
      if (!mounted) return;
      await _handleStatus(data);
      if (!leavingForRoom && data['state']?.toString() != 'room') {
        _scheduleGamePoll((data['nextRetrySeconds'] as num?)?.toInt() ?? 2);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { loading = false; error = e.message; });
    } finally {
      joining = false;
    }
  }

  void _scheduleGamePoll(int seconds) {
    pollTimer?.cancel();
    final wait = seconds.clamp(2, 10).toInt();
    setState(() => secondsLeft = wait);
    pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || leavingForRoom) {
        timer.cancel();
        return;
      }
      if (secondsLeft <= 1) {
        timer.cancel();
        setState(() => secondsLeft = 0);
        unawaited(_joinGameQueue(statusOnly: true));
      } else {
        setState(() => secondsLeft--);
      }
    });
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
      pollTimer?.cancel();
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
          queueTotal = widget.voiceMode ? 2 : 6;
          queuePosition = 1;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.voiceMode
              ? VoiceRoomScreen(roomId: roomId, profileName: widget.profileName)
              : widget.gameMode
                  ? (_tabu
                      ? TabuRoomScreen(roomId: roomId, profileName: widget.profileName)
                      : MiniGameRoomScreen(roomId: roomId, profileName: widget.profileName))
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
    pollTimer?.cancel();
    try {
      if (widget.gameMode) {
        if (_tabu) {
          await RoomQueueApiService.cancelTabuQueue();
        } else {
          await RoomQueueApiService.cancelMiniGameQueue();
        }
      } else if (widget.voiceMode) {
        await VoiceRoomService.cancelQueue();
      } else {
        await RealtimeService.cancelQueue();
      }
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  String get _gameName {
    switch (_gameKey) {
      case 'red_flag_green_flag':
        return 'Red Flag / Green Flag';
      case 'two_truths_one_lie':
        return '2 Doğru 1 Yanlış';
      case 'tabu':
        return 'Tabu';
      default:
        return 'Mini oyun';
    }
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    pollTimer?.cancel();
    pulse.dispose();
    if (!leavingForRoom) {
      if (widget.gameMode) {
        if (_tabu) {
          unawaited(RoomQueueApiService.cancelTabuQueue().catchError((_) => <String, dynamic>{}));
        } else {
          unawaited(RoomQueueApiService.cancelMiniGameQueue().catchError((_) => <String, dynamic>{}));
        }
      } else if (widget.voiceMode) {
        unawaited(VoiceRoomService.cancelQueue().catchError((_) {}));
      } else {
        unawaited(RealtimeService.cancelQueue().catchError((_) => <String, dynamic>{}));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0D1220) : const Color(0xFFF7F8FC);
    final text = dark ? Colors.white : AppColors.navy;

    String title;
    String subtitle;
    if (error != null && error != 'Bağlantı yenileniyor...') {
      title = 'Bağlantı sorunu';
      subtitle = error!;
    } else if (leavingForRoom) {
      title = widget.gameMode ? '$_gameName odası hazır!' : 'Eşleşme bulundu!';
      subtitle = widget.gameMode
          ? '6 oyuncu hazır. Oyun başlıyor.'
          : widget.voiceMode
              ? '2 kişi hazır. Sesli görüşmeye bağlanıyorsun.'
              : '6 kişi hazır. Odaya bağlanıyorsun.';
    } else if (widget.gameMode) {
      title = '$_gameName için 6 oyuncu aranıyor...';
      subtitle = queueTotal > 0
          ? 'Havuzda $queueTotal kişi var. Sıra konumun: $queuePosition'
          : '6 gerçek oyuncu hazır olduğunda oyun otomatik başlayacak.';
    } else if (widget.voiceMode) {
      title = 'Premium 1’e 1 eşleşme aranıyor...';
      subtitle = queueTotal > 0
          ? 'Havuzda $queueTotal kişi var. Sıra konumun: $queuePosition'
          : 'Tercihlerine uygun kullanıcı bekleniyor.';
    } else {
      title = 'Oda aranıyor...';
      subtitle = queueTotal > 0
          ? '${widget.roomDurationMinutes} dk havuzunda $queueTotal kişi var. Sıra konumun: $queuePosition'
          : 'Uygun kullanıcılar aranıyor.';
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _cancel,
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: text),
                  ),
                  const Spacer(),
                  const Meet6MiniBrand(),
                ],
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  width: 178 + pulse.value * 14,
                  height: 178 + pulse.value * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lime,
                    border: Border.all(color: AppColors.navy, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lime.withOpacity(.25),
                        blurRadius: 34,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: widget.gameMode
                      ? const Icon(Icons.sports_esports_rounded, color: AppColors.navy, size: 66)
                      : widget.voiceMode
                          ? const Icon(Icons.mic_rounded, color: AppColors.navy, size: 66)
                          : const Text(
                              '6',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 74,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text.withOpacity(.62),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: AppColors.lime),
              ],
              if (widget.gameMode && !leavingForRoom && error == null) ...[
                const SizedBox(height: 18),
                Text(
                  'Yeni kontrol: ${secondsLeft.clamp(0, 9)} sn',
                  style: TextStyle(
                    color: text.withOpacity(.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: text,
                    side: BorderSide(color: text.withOpacity(.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text(
                    'Aramayı iptal et',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

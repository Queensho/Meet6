import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/party_invite_link_service.dart';
import '../../services/party_matchmaking_service.dart';
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
    this.partyCode,
  });

  final String profileName;
  final int roomDurationMinutes;
  final String roomMode;
  final String? partyCode;

  bool get voiceMode => roomMode == 'voice';
  bool get gameMode => roomMode == 'game';
  bool get partyMode => partyCode != null && partyCode!.trim().isNotEmpty;

  @override
  State<RoomSearchingScreen> createState() => _RoomSearchingScreenState();
}

class _RoomSearchingScreenState extends State<RoomSearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  StreamSubscription<RealtimeEvent>? realtimeSub;
  Timer? pollTimer;
  Timer? visualCountdownTimer;

  bool joining = false;
  bool leavingForRoom = false;
  bool loading = true;
  bool firstConnectionSeen = false;
  bool waitingFriend = false;
  bool sharing = false;
  String? friendName;
  String? error;
  int queueTotal = 0;
  int queuePosition = 0;
  int secondsLeft = 15;
  int cycleDurationSeconds = 15;
  int searchCycle = 1;

  String get _gameKey => MiniGameSelectionService.selectedGameKey;
  bool get _tabu => widget.gameMode && _gameKey == 'tabu';
  String get _partyCode => widget.partyCode?.trim().toUpperCase() ?? '';
  String get _inviteUrl => PartyInviteLinkService.buildInviteUrl(_partyCode);

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _startVisualCountdown();
    if (widget.partyMode) {
      unawaited(_joinParty());
    } else if (widget.gameMode) {
      unawaited(_joinGameQueue());
    } else {
      unawaited(_startRealtime());
    }
  }

  void _startVisualCountdown() {
    visualCountdownTimer?.cancel();
    if (widget.gameMode || widget.partyMode) return;
    cycleDurationSeconds = 15;
    secondsLeft = 15;
    visualCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || leavingForRoom) return;
      setState(() {
        if (secondsLeft <= 1) {
          secondsLeft = cycleDurationSeconds;
          searchCycle += 1;
        } else {
          secondsLeft -= 1;
        }
      });
    });
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
    if (!mounted || leavingForRoom || widget.gameMode || widget.partyMode) return;
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

  Future<void> _joinParty({bool statusOnly = false}) async {
    if (joining || leavingForRoom || !mounted) return;
    joining = true;
    try {
      final data = statusOnly
          ? await PartyMatchmakingService.status(_partyCode)
          : await PartyMatchmakingService.search(_partyCode);
      if (!mounted) return;
      final rawParty = data['party'];
      final party = rawParty is Map
          ? Map<String, dynamic>.from(rawParty)
          : <String, dynamic>{};
      setState(() {
        waitingFriend = data['state']?.toString() == 'waiting_friend';
        friendName = party['guestName']?.toString();
      });
      await _handleStatus(data);
      if (!leavingForRoom &&
          data['state']?.toString() != 'room' &&
          data['state']?.toString() != 'idle') {
        _schedulePartyPoll((data['nextRetrySeconds'] as num?)?.toInt() ?? 2);
      }
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

  void _schedulePartyPoll(int seconds) {
    pollTimer?.cancel();
    final wait = seconds.clamp(2, 10).toInt();
    setState(() {
      cycleDurationSeconds = wait;
      secondsLeft = wait;
    });
    pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || leavingForRoom) {
        timer.cancel();
        return;
      }
      if (secondsLeft <= 1) {
        timer.cancel();
        setState(() => secondsLeft = 0);
        unawaited(_joinParty());
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _scheduleGamePoll(int seconds) {
    pollTimer?.cancel();
    final wait = seconds.clamp(2, 10).toInt();
    setState(() {
      cycleDurationSeconds = wait;
      secondsLeft = wait;
    });
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
      visualCountdownTimer?.cancel();
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
          queueTotal = widget.voiceMode ? 2 : 6;
          queuePosition = 1;
          secondsLeft = 0;
        });
      }

      if (widget.gameMode) {
        final enrichedRoom = <String, dynamic>{
          ...room,
          'roomMode': 'game',
          'gameKey': data['gameKey']?.toString() ?? _gameKey,
        };
        RealtimeService.publishActiveRoom(enrichedRoom);
        try {
          await RealtimeService.connect();
          await RealtimeService.joinQueue();
          RealtimeService.publishActiveRoom(enrichedRoom);
        } catch (_) {}
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
      error = state == 'idle' ? 'Davet sona erdi.' : null;
      queueTotal = (data['total'] as num?)?.toInt() ??
          (widget.partyMode ? (waitingFriend ? 1 : 2) : 0);
      queuePosition = (data['position'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _shareWhatsApp() async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      final opened = await PartyInviteLinkService.shareWhatsApp(_partyCode);
      if (!opened && mounted) {
        await _copyInviteLink();
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  Future<void> _shareSms() async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      final opened = await PartyInviteLinkService.shareSms(_partyCode);
      if (!opened && mounted) {
        await _copyInviteLink();
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  Future<void> _copyInviteLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Davet linki panoya kopyalandı.')),
    );
  }

  Future<void> _cancel() async {
    pollTimer?.cancel();
    visualCountdownTimer?.cancel();
    try {
      if (widget.partyMode) {
        await PartyMatchmakingService.cancel(_partyCode);
      } else if (widget.gameMode) {
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

  double get _cycleProgress {
    if (cycleDurationSeconds <= 0) return 0;
    return secondsLeft.clamp(0, cycleDurationSeconds) / cycleDurationSeconds;
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    pollTimer?.cancel();
    visualCountdownTimer?.cancel();
    pulse.dispose();
    if (!leavingForRoom) {
      if (widget.partyMode) {
        unawaited(
          PartyMatchmakingService.cancel(_partyCode)
              .catchError((_) => <String, dynamic>{}),
        );
      } else if (widget.gameMode) {
        if (_tabu) {
          unawaited(
            RoomQueueApiService.cancelTabuQueue()
                .catchError((_) => <String, dynamic>{}),
          );
        } else {
          unawaited(
            RoomQueueApiService.cancelMiniGameQueue()
                .catchError((_) => <String, dynamic>{}),
          );
        }
      } else if (widget.voiceMode) {
        unawaited(VoiceRoomService.cancelQueue().catchError((_) {}));
      } else {
        unawaited(
          RealtimeService.cancelQueue()
              .catchError((_) => <String, dynamic>{}),
        );
      }
    }
    super.dispose();
  }

  Widget _searchOrb(bool dark) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final orbSize = 170 + pulse.value * 18;
        final ringColor = dark ? AppColors.lime : AppColors.navy;
        final softRing = dark ? Colors.white : AppColors.navy;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final factor in const [.95, .73, .52])
                Container(
                  width: 280 * factor + pulse.value * 12,
                  height: 280 * factor + pulse.value * 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: softRing.withValues(alpha: .10 + factor * .10),
                    ),
                  ),
                ),
              SizedBox(
                width: orbSize + 22,
                height: orbSize + 22,
                child: CircularProgressIndicator(
                  value: leavingForRoom ? 1 : _cycleProgress,
                  strokeWidth: 7,
                  backgroundColor: softRing.withValues(alpha: .14),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: .28),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.partyMode)
                      Text(
                        '${queueTotal.clamp(1, 6)}/6',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: .95,
                          letterSpacing: -2,
                        ),
                      )
                    else if (widget.voiceMode)
                      const Icon(Icons.mic_rounded, color: AppColors.navy, size: 46)
                    else if (widget.gameMode)
                      const Icon(Icons.sports_esports_rounded, color: AppColors.navy, size: 48)
                    else
                      Text(
                        leavingForRoom ? '6' : '${secondsLeft.clamp(0, 999)}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 70,
                          fontWeight: FontWeight.w900,
                          height: .9,
                          letterSpacing: -3,
                        ),
                      ),
                    if (!widget.partyMode && (widget.voiceMode || widget.gameMode)) ...[
                      const SizedBox(height: 5),
                      Text(
                        leavingForRoom ? 'Hazır' : '${secondsLeft.clamp(0, 999)} sn',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      widget.partyMode
                          ? (waitingFriend ? 'arkadaş bekleniyor' : '2 arkadaş + sistem')
                          : widget.voiceMode
                              ? '1’e 1 eşleşme'
                              : widget.gameMode
                                  ? '6 kişilik oyun'
                                  : '6 kişilik oda',
                      style: const TextStyle(
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
    );
  }

  Widget _partySharePanel(Color text) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: text.withValues(alpha: .075),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                _inviteUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: sharing ? null : _shareWhatsApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sharing ? null : _shareSms,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: text,
                        side: BorderSide(color: text.withValues(alpha: .28)),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.sms_rounded, size: 20),
                      label: const Text('Mesaj', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: sharing ? null : _copyInviteLink,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Davet linkini kopyala'),
                style: TextButton.styleFrom(foregroundColor: text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0D1220) : AppColors.lime;
    final text = dark ? Colors.white : AppColors.navy;

    String title;
    String subtitle;
    if (error != null && error != 'Bağlantı yenileniyor...') {
      title = 'Bağlantı sorunu';
      subtitle = error!;
    } else if (leavingForRoom) {
      title = widget.gameMode ? '$_gameName odası hazır!' : 'Eşleşme bulundu!';
      subtitle = widget.partyMode
          ? 'Sen, arkadaşın ve 4 Meet6 kullanıcısı hazır.'
          : widget.gameMode
              ? '6 oyuncu hazır. Oyun başlıyor.'
              : widget.voiceMode
                  ? '2 kişi hazır. Sesli görüşmeye bağlanıyorsun.'
                  : '6 kişi hazır. Odaya bağlanıyorsun.';
    } else if (widget.partyMode && waitingFriend) {
      title = 'Arkadaşın bekleniyor...';
      subtitle = 'Davet linkini WhatsApp veya mesaj ile gönder. Arkadaşın katılınca kalan 4 kişiyi Meet6 bulacak.';
    } else if (widget.partyMode) {
      title = friendName?.trim().isNotEmpty == true
          ? '${friendName!} katıldı · 4 kişi aranıyor...'
          : 'Arkadaşın katıldı · 4 kişi aranıyor...';
      subtitle = '${queueTotal.clamp(2, 6)}/6 hazır. Siz aynı odada kalırsınız; kalan kişileri sistem eşleştirir.';
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
              _searchOrb(dark),
              const SizedBox(height: 22),
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
                  color: text.withValues(alpha: .68),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!leavingForRoom && error == null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: text.withValues(alpha: .075),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.partyMode
                        ? (waitingFriend
                            ? 'Kod: $_partyCode'
                            : 'Yeni kontrol ${secondsLeft.clamp(0, 999)} sn sonra')
                        : widget.gameMode
                            ? 'Yeni kontrol ${secondsLeft.clamp(0, 999)} sn sonra'
                            : 'Arama turu $searchCycle',
                    style: TextStyle(
                      color: text.withValues(alpha: .62),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (widget.partyMode && waitingFriend && !leavingForRoom && error == null) ...[
                const SizedBox(height: 14),
                _partySharePanel(text),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: text,
                    side: BorderSide(color: text.withValues(alpha: .24)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    widget.partyMode ? 'Davet / aramayı iptal et' : 'Aramayı iptal et',
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

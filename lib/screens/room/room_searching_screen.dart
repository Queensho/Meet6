import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../chat/room_chat_screen.dart';

class RoomSearchingScreen extends StatefulWidget {
  const RoomSearchingScreen({super.key, this.profileName = ''});

  final String profileName;

  @override
  State<RoomSearchingScreen> createState() => _RoomSearchingScreenState();
}

class _RoomSearchingScreenState extends State<RoomSearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  StreamSubscription<RealtimeEvent>? realtimeSub;
  bool leavingForRoom = false;
  bool loading = true;
  bool firstConnectionSeen = false;
  bool joining = false;
  String? error;
  int queueTotal = 0;
  int queuePosition = 0;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _startRealtime();
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
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Oda servisine bağlanılamadı. Tekrar dene.';
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
    if (event.type == 'queue:status' || event.type == 'queue:matched') {
      unawaited(_handleStatus(event.data));
    }
  }

  Future<void> _joinQueue() async {
    if (joining || leavingForRoom) return;
    joining = true;
    try {
      final data = await RealtimeService.joinQueue();
      if (!mounted) return;
      await _handleStatus(data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } finally {
      joining = false;
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
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
          queueTotal = 6;
          queuePosition = 1;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomChatScreen(
            roomId: roomId,
            profileName: widget.profileName,
          ),
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
    try {
      await RealtimeService.cancelQueue();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    pulse.dispose();
    if (!leavingForRoom) {
      unawaited(RealtimeService.cancelQueue().catchError((_) => <String, dynamic>{}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

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
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.8,
                          ),
                          children: [
                            TextSpan(
                              text: 'meet',
                              style: TextStyle(color: dark ? Colors.white : AppColors.navy),
                            ),
                            const TextSpan(text: '6', style: TextStyle(color: AppColors.blue)),
                          ],
                        ),
                      ),
                      const Spacer(),
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
                      final size = 164 + pulse.value * 22;
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
                                    color: (dark ? Colors.white : AppColors.navy)
                                        .withOpacity(.10 + factor * .10),
                                  ),
                                ),
                              ),
                            Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.navy, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime.withOpacity(.28),
                                    blurRadius: 34,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '6',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 82,
                                  fontWeight: FontWeight.w900,
                                  height: .9,
                                  letterSpacing: -5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    error != null && error != 'Bağlantı yenileniyor...'
                        ? 'Bağlantı sorunu'
                        : leavingForRoom
                            ? 'Uygun oda bulundu!'
                            : 'Oda aranıyor...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error ??
                        (leavingForRoom
                            ? '6 kişi hazır. Odaya bağlanıyorsun.'
                            : queueTotal > 0
                                ? 'Kuyrukta $queueTotal kişi var. Sıra konumun: $queuePosition'
                                : 'Tercihlerine uyan kullanıcılar bekleniyor.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white70 : AppColors.navy.withOpacity(.66),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (error != null && error != 'Bağlantı yenileniyor...')
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          loading = true;
                          error = null;
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
                        border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
                      ),
                      child: Row(
                        children: [
                          if (loading || !leavingForRoom)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.blue,
                              ),
                            )
                          else
                            const Icon(Icons.check_circle_rounded, color: AppColors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              leavingForRoom
                                  ? 'Oda sunucuda oluşturuldu.'
                                  : 'Canlı bağlantı açık. Yaş, tercih, mesafe ve engel filtreleri uygulanıyor.',
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
                    'Oda yalnızca 6 gerçek kullanıcı hazır olduğunda başlar.',
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

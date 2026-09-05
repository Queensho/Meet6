import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';

import '../../services/api_service.dart';
import '../../services/live_service.dart';
import '../../services/realtime_service.dart';
import '../../services/session_service.dart';
import '../../services/voice_room_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';
import 'room_selection_screen.dart';

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  StreamSubscription<RealtimeEvent>? realtimeSub;
  Timer? countdownTimer;
  Room? audioRoom;
  Map<String, dynamic>? room;
  String? myUserId;
  String? error;
  String? audioError;
  bool loading = true;
  bool audioConnecting = true;
  bool muted = false;
  bool navigating = false;
  bool extensionSheetOpen = false;
  bool previewDecisionSheetOpen = false;
  bool previewDecisionSending = false;
  String voicePhase = 'preview';
  bool? myPreviewDecision;

  bool get isPreview => voicePhase == 'preview';
  bool get previewDecisionOpen => isPreview && room?['status'] == 'selection';

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
      await _refreshPreviewState();
      await _refreshSnapshot();
      if (!mounted || navigating) return;
      if (room?['status'] == 'active') {
        await _connectAudio();
      } else {
        audioConnecting = false;
      }
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        audioConnecting = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        audioConnecting = false;
        error = 'Birebir sesli görüşmeye bağlanılamadı.';
      });
    }
  }

  Future<void> _refreshPreviewState() async {
    final data = await VoiceRoomService.previewStatus(widget.roomId);
    if (!mounted) return;
    setState(() {
      voicePhase = data['phase']?.toString() == 'main' ? 'main' : 'preview';
      final rawDecision = data['myDecision'];
      myPreviewDecision = rawDecision is bool ? rawDecision : null;
    });
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (!mounted || navigating) return;
    if (event.type == 'connection:connected') {
      unawaited(_rejoinAfterReconnect());
      return;
    }
    if (event.type == 'room:update' &&
        event.data['roomId']?.toString() == widget.roomId) {
      final raw = event.data['room'];
      if (raw is Map) {
        final latest = Map<String, dynamic>.from(raw);
        final previousStatus = room?['status']?.toString();
        final latestStatus = latest['status']?.toString();
        final mainJustStarted = isPreview &&
            myPreviewDecision == true &&
            previousStatus == 'selection' &&
            latestStatus == 'active';

        setState(() {
          room = latest;
          error = null;
          if (mainJustStarted) voicePhase = 'main';
        });

        if (mainJustStarted) {
          previewDecisionSheetOpen = false;
          _startCountdown();
          unawaited(_connectAudio());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İkiniz de devam ettiniz · 15 dakika başladı.')),
          );
        }
        _handleRoomState(latest);
      }
    }
  }

  Future<void> _rejoinAfterReconnect() async {
    try {
      await _refreshPreviewState();
      await _refreshSnapshot();
      if (room?['status'] == 'active' &&
          (audioRoom == null || audioRoom!.connectionState == ConnectionState.disconnected)) {
        await _connectAudio();
      }
    } catch (_) {}
  }

  Future<void> _refreshSnapshot() async {
    final latest = await LiveService.room(widget.roomId);
    if (!mounted) return;
    setState(() {
      room = latest;
      loading = false;
      error = null;
    });
    _handleRoomState(latest);
  }

  Future<void> _connectAudio() async {
    if (navigating || room?['status'] != 'active') return;
    if (mounted) {
      setState(() {
        audioConnecting = true;
        audioError = null;
      });
    }

    final credentials = await VoiceRoomService.connection(widget.roomId);
    await LiveKitClient.initialize();
    final current = audioRoom;
    if (current != null) {
      current.removeListener(_onAudioChanged);
      await current.disconnect().catchError((_) {});
      await current.dispose().catchError((_) => false);
    }

    final next = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    await next.connect(credentials.url, credentials.token);
    next.addListener(_onAudioChanged);
    audioRoom = next;

    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    } catch (_) {}

    try {
      await next.localParticipant?.setMicrophoneEnabled(true);
      muted = false;
    } catch (_) {
      muted = true;
      audioError = 'Mikrofon izni olmadan konuşamazsın. Mikrofon düğmesine dokunup tekrar deneyebilirsin.';
    }

    if (!mounted) return;
    setState(() => audioConnecting = false);
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final status = room?['status']?.toString();
      if (status == 'active') {
        final current = (room?['secondsLeft'] as num?)?.toInt() ?? 0;
        if (current <= 0) return;
        setState(() => room = {...?room, 'secondsLeft': current - 1});
        return;
      }
      if (isPreview && status == 'selection') {
        final current = (room?['selectionSecondsLeft'] as num?)?.toInt() ?? 0;
        if (current <= 0) return;
        setState(() => room = {...?room, 'selectionSecondsLeft': current - 1});
      }
    });
  }

  void _handleRoomState(Map<String, dynamic> data) {
    final status = data['status']?.toString();

    if (status == 'closed' && !navigating) {
      navigating = true;
      countdownTimer?.cancel();
      unawaited(_disconnectAudio());
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (isPreview) {
      if (status == 'selection') {
        unawaited(_disconnectAudio());
        if (myPreviewDecision == null && !previewDecisionSheetOpen) {
          previewDecisionSheetOpen = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showPreviewDecision());
        }
      }
      return;
    }

    if (status == 'selection' && !navigating) {
      navigating = true;
      countdownTimer?.cancel();
      unawaited(_disconnectAudio());
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

    final canVote = data['canVoteExtension'] == true;
    final myVote = data['myExtensionVote'];
    if (canVote && myVote == null && !extensionSheetOpen) {
      extensionSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showExtensionVote());
    }
  }

  Future<void> _showPreviewDecision() async {
    if (!mounted || !previewDecisionOpen || myPreviewDecision != null) {
      previewDecisionSheetOpen = false;
      return;
    }
    final decision = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_rounded, color: AppColors.lime, size: 30),
              ),
              const SizedBox(height: 14),
              const Text(
                '45 saniye tamamlandı',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                'Devam etmek ister misin? Kararın gizli. İkiniz de Devam et derseniz 15 dakikalık görüşme başlar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Geç', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('Devam et', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    previewDecisionSheetOpen = false;
    if (decision == null || !mounted) return;
    await _submitPreviewDecision(decision);
  }

  Future<void> _submitPreviewDecision(bool shouldContinue) async {
    if (previewDecisionSending || navigating) return;
    setState(() => previewDecisionSending = true);
    try {
      final result = await VoiceRoomService.previewDecision(widget.roomId, shouldContinue);
      if (!mounted) return;
      final outcome = result['outcome']?.toString();
      setState(() {
        previewDecisionSending = false;
        myPreviewDecision = shouldContinue;
      });

      if (!shouldContinue || outcome == 'ended') {
        navigating = true;
        countdownTimer?.cancel();
        await _disconnectAudio();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      if (outcome == 'continued') {
        setState(() => voicePhase = 'main');
        await _refreshSnapshot();
        if (!mounted || navigating) return;
        await _connectAudio();
        _startCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İkiniz de devam ettiniz · 15 dakika başladı.')),
          );
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => previewDecisionSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      if (previewDecisionOpen && myPreviewDecision == null && !previewDecisionSheetOpen) {
        previewDecisionSheetOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showPreviewDecision());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => previewDecisionSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kararın gönderilemedi. Tekrar dene.')),
      );
    }
  }

  Future<void> _showExtensionVote() async {
    if (!mounted || isPreview) {
      extensionSheetOpen = false;
      return;
    }
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_rounded, color: AppColors.lime, size: 38),
              const SizedBox(height: 10),
              const Text(
                'Birebir görüşmeyi +5 dakika uzatalım mı?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
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
    extensionSheetOpen = false;
    if (vote == null) return;
    try {
      await RealtimeService.voteRoomExtension(widget.roomId, vote);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggleMicrophone() async {
    final local = audioRoom?.localParticipant;
    if (local == null) return;
    try {
      final nextMuted = !muted;
      await local.setMicrophoneEnabled(!nextMuted);
      if (!mounted) return;
      setState(() {
        muted = nextMuted;
        audioError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        muted = true;
        audioError = 'Mikrofon açılamadı. Meet6 için mikrofon iznini kontrol et.';
      });
    }
  }

  Future<void> _disconnectAudio() async {
    final current = audioRoom;
    audioRoom = null;
    if (current == null) return;
    current.removeListener(_onAudioChanged);
    await current.disconnect().catchError((_) {});
    await current.dispose().catchError((_) => false);
  }

  bool _isSpeaking(String userId) {
    if (userId == myUserId) return audioRoom?.localParticipant?.isSpeaking ?? false;
    return audioRoom?.remoteParticipants[userId]?.isSpeaking ?? false;
  }

  bool _isMuted(String userId) {
    if (userId == myUserId) return muted;
    return audioRoom?.remoteParticipants[userId]?.isMuted ?? true;
  }

  bool _isConnected(String userId) {
    if (userId == myUserId) return audioRoom?.localParticipant != null;
    return audioRoom?.remoteParticipants.containsKey(userId) ?? false;
  }

  String _timerText() {
    final status = room?['status']?.toString();
    final raw = isPreview && status == 'selection'
        ? room?['selectionSecondsLeft']
        : room?['secondsLeft'];
    final seconds = ((raw as num?)?.toInt() ?? 0).clamp(0, 60 * 60);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _subtitle() {
    if (!isPreview) return '1’e 1 sesli sohbet · 15 dakika';
    if (room?['status'] == 'selection') {
      return myPreviewDecision == true
          ? 'Kararın gizli · karşı taraf bekleniyor'
          : 'Gizli karar · Devam et veya Geç';
    }
    return '45 sn ön görüşme · kararınız gizli';
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    countdownTimer?.cancel();
    unawaited(_disconnectAudio());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rawMembers = room?['members'];
    final members = rawMembers is List
        ? rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    const Meet6MiniBrand(height: 28, forceLogo2: true),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPreview ? Icons.bolt_rounded : Icons.mic_rounded,
                            size: 13,
                            color: AppColors.lime,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPreview ? 'ÖN GÖRÜŞME' : 'PREMIUM 1’E 1',
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _timerText(),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                _subtitle(),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (isPreview && room?['status'] == 'active')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lime.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'İlk izlenim için 45 saniye. Süre bitince ikinize de gizlice Devam et / Geç sorulacak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.8, height: 1.3, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (isPreview && room?['status'] == 'selection' && myPreviewDecision == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime),
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Kararın gönderildi · diğer kişinin kararı bekleniyor',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              if (error != null || audioError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0x18E76A60),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      error ?? audioError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE76A60),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.08,
                        ),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final userId = member['user_id']?.toString() ?? '';
                          final rawPhotos = member['photo_urls'];
                          final photos = rawPhotos is List ? rawPhotos : const [];
                          final photo = photos.isEmpty ? '' : photos.first.toString();
                          return _VoiceMemberCard(
                            name: member['display_name']?.toString() ?? 'Meet6',
                            photoUrl: photo,
                            connected: _isConnected(userId),
                            speaking: _isSpeaking(userId),
                            muted: _isMuted(userId),
                            me: userId == myUserId,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  children: [
                    if (!previewDecisionOpen) ...[
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: FilledButton(
                          onPressed: audioConnecting ? null : _toggleMicrophone,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                            backgroundColor: muted ? const Color(0xFFE76A60) : AppColors.lime,
                            foregroundColor: muted ? Colors.white : AppColors.navy,
                          ),
                          child: audioConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                )
                              : Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 31),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        audioConnecting
                            ? 'Ses bağlantısı kuruluyor...'
                            : muted
                                ? 'Mikrofon kapalı'
                                : 'Mikrofon açık',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (isPreview && room?['status'] == 'active') ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: previewDecisionSending ? null : () => _submitPreviewDecision(false),
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Şimdi geç'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE76A60),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceMemberCard extends StatelessWidget {
  const _VoiceMemberCard({
    required this.name,
    required this.photoUrl,
    required this.connected,
    required this.speaking,
    required this.muted,
    required this.me,
  });

  final String name;
  final String photoUrl;
  final bool connected;
  final bool speaking;
  final bool muted;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ApiService.absoluteMediaUrl(photoUrl);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: speaking ? AppColors.lime : scheme.outlineVariant,
          width: speaking ? 2.5 : 1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: .22),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.navy,
                backgroundImage: resolved.isEmpty ? null : NetworkImage(resolved),
                child: resolved.isEmpty
                    ? Text(
                        name.trim().isEmpty ? '6' : name.trim().characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: !connected
                        ? scheme.surfaceContainerHighest
                        : muted
                            ? const Color(0xFFE76A60)
                            : AppColors.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                  ),
                  child: Icon(
                    !connected
                        ? Icons.hourglass_bottom_rounded
                        : muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                    size: 13,
                    color: !connected
                        ? scheme.onSurfaceVariant
                        : muted
                            ? Colors.white
                            : AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            me ? '$name · Sen' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            speaking
                ? 'Konuşuyor'
                : connected
                    ? 'Odada'
                    : 'Bağlanıyor',
            style: TextStyle(
              color: speaking ? const Color(0xFF36C76C) : scheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/mini_game_api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/red_flag_game_api_service.dart';
import '../../theme/app_colors.dart';
import '../messages/private_chat_screen.dart';
import 'red_flag_green_flag_room_screen_v2.dart';
import 'tabu_room_screen.dart';
import 'two_truths_one_lie_room_screen.dart' as truths;

class MiniGameRoomScreen extends StatefulWidget {
  const MiniGameRoomScreen({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<MiniGameRoomScreen> createState() => _MiniGameRoomScreenState();
}

class _MiniGameRoomScreenState extends State<MiniGameRoomScreen>
    with WidgetsBindingObserver {
  late Future<String> _gameKeyFuture;
  Timer? _finalWatchTimer;
  bool _leaving = false;
  bool _finishing = false;
  bool _finalChoosing = false;
  bool _checkingFinal = false;
  int _resumeEpoch = 0;
  Map<String, dynamic>? _forcedResult;
  String? _forcedGameKey;
  String? _resolvedGameKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameKeyFuture = _resolveAndRememberGameKey();
    _finalWatchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkForNaturalFinal(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finalWatchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || _forcedResult != null) return;
    setState(() {
      _resumeEpoch += 1;
      _gameKeyFuture = _resolveAndRememberGameKey();
    });
    _checkForNaturalFinal();
  }

  Future<String> _resolveAndRememberGameKey() async {
    final key = await _resolveGameKey();
    _resolvedGameKey = key;
    return key;
  }

  Future<String> _resolveGameKey() async {
    final selected = MiniGameSelectionService.selectedGameKey;
    if (selected == 'red_flag_green_flag' || selected == 'tabu') return selected;

    try {
      final state = await RedFlagGameApiService.state(widget.roomId);
      if (state['game']?.toString() == 'red_flag_green_flag') {
        MiniGameSelectionService.select('red_flag_green_flag');
        return 'red_flag_green_flag';
      }
    } catch (_) {}

    return selected;
  }

  Future<void> _checkForNaturalFinal() async {
    if (!mounted ||
        _forcedResult != null ||
        _finishing ||
        _checkingFinal ||
        _resolvedGameKey == null ||
        _resolvedGameKey == 'tabu') {
      return;
    }
    _checkingFinal = true;
    try {
      final key = _resolvedGameKey!;
      final result = key == 'red_flag_green_flag'
          ? await RedFlagGameApiService.state(widget.roomId)
          : await MiniGameApiService.state(widget.roomId);
      if (!mounted) return;
      if (result['phase']?.toString() == 'final') {
        setState(() {
          _forcedResult = result;
          _forcedGameKey = key;
        });
      }
    } catch (_) {
      // Child game screen owns transient room errors. The watcher only promotes
      // a confirmed server final state to the shared result UI.
    } finally {
      _checkingFinal = false;
    }
  }

  Future<void> _goHome() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _leaving = false;
  }

  Future<void> _forceFinish(String gameKey) async {
    if (_finishing || !mounted) return;
    setState(() => _finishing = true);
    try {
      final result = await MiniGameApiService.forceFinish(
        widget.roomId,
        gameKey: gameKey,
      );
      if (!mounted) return;
      setState(() {
        _forcedResult = result;
        _forcedGameKey = gameKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun test için bitirildi.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun bitirilemedi.')),
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _forcedFinalChoice(bool match) async {
    final gameKey = _forcedGameKey;
    if (gameKey == null || _finalChoosing || !mounted) return;
    setState(() => _finalChoosing = true);
    try {
      final data = gameKey == 'red_flag_green_flag'
          ? await RedFlagGameApiService.finalChoice(widget.roomId, match: match)
          : await MiniGameApiService.finalChoice(widget.roomId, match: match);
      if (!mounted) return;
      setState(() => _forcedResult = data);
      if (!match) await _goHome();
      if (data['finalDecision'] is Map &&
          (data['finalDecision'] as Map)['status']?.toString() == 'matched') {
        _openForcedChat();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _finalChoosing = false);
    }
  }

  String _photo(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    return '${AppConfig.apiBaseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  void _openForcedChat() {
    final result = _forcedResult;
    if (result == null) return;
    final recRaw = result['recommendation'];
    final decisionRaw = result['finalDecision'];
    if (recRaw is! Map || decisionRaw is! Map) return;
    final rec = Map<String, dynamic>.from(recRaw);
    final decision = Map<String, dynamic>.from(decisionRaw);
    final matchId = decision['matchId']?.toString() ?? '';
    if (matchId.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: matchId,
          name: rec['partnerName']?.toString() ?? 'Meet6',
          userId: rec['partnerUserId']?.toString() ?? '',
          photoUrl: _photo(rec['partnerPhotoUrl']?.toString()),
          fromNewMatch: true,
        ),
      ),
    );
  }

  Map<String, dynamic>? _meFromResult(Map<String, dynamic> result, String partnerId) {
    final raw = result['players'];
    if (raw is! List) return null;
    final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (widget.profileName.trim().isNotEmpty) {
      for (final p in list) {
        if (p['name']?.toString().trim() == widget.profileName.trim()) return p;
      }
    }
    for (final p in list) {
      if (p['id']?.toString() != partnerId) return p;
    }
    return list.isEmpty ? null : list.first;
  }

  Widget _avatarCard({
    required String name,
    required String photo,
    required Color accent,
  }) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: photo.isEmpty
                ? Container(
                    color: accent.withOpacity(.18),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: accent.withOpacity(.18),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(IconData icon, Color iconColor, String title, String subtitle) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22305A).withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8B92A9),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forceFinishedScreen() {
    final result = _forcedResult ?? const <String, dynamic>{};
    final recRaw = result['recommendation'];
    final decisionRaw = result['finalDecision'];
    final rec = recRaw is Map ? Map<String, dynamic>.from(recRaw) : <String, dynamic>{};
    final decision = decisionRaw is Map ? Map<String, dynamic>.from(decisionRaw) : <String, dynamic>{};
    final partnerName = rec['partnerName']?.toString() ?? '';
    final partnerId = rec['partnerUserId']?.toString() ?? '';
    final partnerPhoto = _photo(rec['partnerPhotoUrl']?.toString());
    final compatibility = (rec['compatibility'] as num?)?.toInt() ?? 0;
    final status = decision['status']?.toString() ?? 'pending';
    final same = (rec['sameAnswers'] as num?)?.toInt();
    final different = (rec['differentAnswers'] as num?)?.toInt();
    final isRedFlag = (_forcedGameKey ?? result['game']?.toString()) == 'red_flag_green_flag';
    final me = _meFromResult(result, partnerId);
    final myName = me?['name']?.toString() ?? widget.profileName.trim();
    final myPhoto = _photo(me?['photoUrl']?.toString());
    final total = isRedFlag ? 6 : ((result['totalRounds'] as num?)?.toInt() ?? 10);
    final subtitle = isRedFlag
        ? '$total soru tamamlandı · En yakın görüş uyumun bulundu'
        : '$total tur tamamlandı · En yakın oyun uyumun bulundu';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -70,
              top: 12,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime.withOpacity(.12),
                ),
              ),
            ),
            Positioned(
              left: -70,
              bottom: 80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2856FF).withOpacity(.08),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 0,
                        child: IconButton(
                          onPressed: _goHome,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.navy,
                            size: 24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                          children: [
                            TextSpan(text: 'meet', style: TextStyle(color: AppColors.navy)),
                            TextSpan(text: '6', style: TextStyle(color: Color(0xFF2454FF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppColors.navy, Color(0xFF2454FF)],
                    ).createShader(rect),
                    child: const Text(
                      'Oyun sonucu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 43,
                        height: 1,
                        letterSpacing: -1.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A90AB),
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (partnerName.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF20305B).withOpacity(.06),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _avatarCard(
                              name: myName.isEmpty ? 'Sen' : myName,
                              photo: myPhoto,
                              accent: const Color(0xFF2856FF),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Column(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.lime.withOpacity(.14),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFF8DD414),
                                    size: 31,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Uyum',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '%$compatibility',
                                  style: const TextStyle(
                                    color: Color(0xFF2454FF),
                                    fontSize: 38,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.lime.withOpacity(.18),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    compatibility >= 80
                                        ? 'Harika!'
                                        : compatibility >= 60
                                            ? 'İyi uyum'
                                            : 'Yakın uyum',
                                    style: const TextStyle(
                                      color: Color(0xFF416913),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _avatarCard(
                              name: partnerName,
                              photo: partnerPhoto,
                              accent: AppColors.lime,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _metricCard(
                          Icons.flag_rounded,
                          const Color(0xFF6BD33A),
                          same == null ? '$compatibility% uyum' : '$same aynı seçim',
                          same == null ? 'Benzer oyun tarzı' : 'Aynı fikirdesiniz',
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          Icons.flag_rounded,
                          const Color(0xFFFF5A60),
                          different == null ? '${100 - compatibility}% fark' : '$different farklı seçim',
                          different == null ? 'Farklı yaklaşım' : 'Farklı bakış açıları',
                        ),
                        const SizedBox(width: 8),
                        _metricCard(
                          Icons.access_time_rounded,
                          const Color(0xFF2454FF),
                          isRedFlag ? '12 dk tartışma' : '$total tur oyun',
                          isRedFlag ? 'Güzel sohbet!' : 'Oyun tamamlandı',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.lime.withOpacity(.28),
                            AppColors.lime.withOpacity(.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white,
                            backgroundImage: partnerPhoto.isEmpty ? null : NetworkImage(partnerPhoto),
                            child: partnerPhoto.isEmpty
                                ? Text(
                                    partnerName.isEmpty ? '?' : partnerName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 20,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Sistem sana\n'),
                                      TextSpan(
                                        text: "$partnerName'yu öneriyor",
                                        style: const TextStyle(color: Color(0xFF2454FF)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '$partnerName da seni seçerse özel sohbete geçersiniz.',
                                  style: const TextStyle(
                                    color: Color(0xFF7C839D),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.favorite_border_rounded,
                            color: Color(0xFF91D71B),
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (status == 'matched')
                      SizedBox(
                        height: 62,
                        child: FilledButton.icon(
                          onPressed: _openForcedChat,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: const Text(
                            'Eşleştiniz · Özel mesaja geç',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      )
                    else if (status == 'waiting')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Seçimin kaydedildi. Karşı tarafın seçimi bekleniyor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 62,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDFFF29), Color(0xFFB9FF22)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: FilledButton(
                            onPressed: _finalChoosing ? null : () => _forcedFinalChoice(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: AppColors.navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$partnerName ile eşleş',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Icon(Icons.arrow_forward_rounded, size: 26),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 58,
                        child: OutlinedButton(
                          onPressed: _finalChoosing ? null : () => _forcedFinalChoice(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: Color(0xFFBEC5D8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text(
                            'Odaya devam et',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Color(0xFF6674E8), size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Seçimin gizlidir. Karşılıklı olursa eşleşme gerçekleşir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8A90AB),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.favorite_border_rounded, color: Color(0xFF8A90AB), size: 42),
                          SizedBox(height: 10),
                          Text(
                            'Eşleşme önerisi oluşturulamadı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: _goHome, child: const Text('Ana sayfaya dön')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_forcedResult != null) return _forceFinishedScreen();

    return FutureBuilder<String>(
      future: _gameKeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameKey = snapshot.data ?? MiniGameSelectionService.selectedGameKey;
        _resolvedGameKey ??= gameKey;
        final Widget game;
        final childKey = ValueKey('${widget.roomId}:$_resumeEpoch:$gameKey');
        if (gameKey == 'red_flag_green_flag') {
          game = RedFlagGreenFlagRoomScreenV2(
            key: childKey,
            roomId: widget.roomId,
            profileName: widget.profileName,
          );
        } else if (gameKey == 'tabu') {
          game = TabuRoomScreen(
            key: childKey,
            roomId: widget.roomId,
            profileName: widget.profileName,
          );
        } else {
          game = PopScope(
            canPop: false,
            onPopInvokedWithResult: (_, __) => _goHome(),
            child: truths.MiniGameRoomScreen(
              key: childKey,
              roomId: widget.roomId,
              profileName: widget.profileName,
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: game),
            if (gameKey != 'tabu')
              Positioned(
                right: 14,
                bottom: 18,
                child: SafeArea(
                  child: FilledButton.icon(
                    onPressed: _finishing ? null : () => _forceFinish(gameKey),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111A2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    icon: _finishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.fast_forward_rounded, size: 20),
                    label: const Text(
                      'Test: Oyunu bitir',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

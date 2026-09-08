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
  Map<String, dynamic>? _finalResult;
  String? _finalGameKey;
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
    if (state != AppLifecycleState.resumed || !mounted || _finalResult != null) {
      return;
    }
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
    if (selected == 'red_flag_green_flag' || selected == 'tabu') {
      return selected;
    }

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
        _finalResult != null ||
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
          _finalResult = result;
          _finalGameKey = key;
        });
      }
    } catch (_) {
      // Çocuk oyun ekranı geçici bağlantı hatalarını kendi yönetir.
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
        _finalResult = result;
        _finalGameKey = gameKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oyun test için bitirildi.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oyun bitirilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _finalChoice(bool match) async {
    final gameKey = _finalGameKey;
    if (gameKey == null || _finalChoosing || !mounted) return;
    setState(() => _finalChoosing = true);
    try {
      final data = gameKey == 'red_flag_green_flag'
          ? await RedFlagGameApiService.finalChoice(widget.roomId, match: match)
          : await MiniGameApiService.finalChoice(widget.roomId, match: match);
      if (!mounted) return;
      setState(() => _finalResult = data);
      if (!match) {
        await _goHome();
        return;
      }
      final decision = data['finalDecision'];
      if (decision is Map && decision['status']?.toString() == 'matched') {
        _openChat();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
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

  void _openChat() {
    final result = _finalResult;
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

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _myPlayer(
    Map<String, dynamic> result,
    String partnerId,
  ) {
    final players = _maps(result['players']);
    final wantedName = widget.profileName.trim();
    if (wantedName.isNotEmpty) {
      for (final player in players) {
        if (player['name']?.toString().trim() == wantedName) return player;
      }
    }
    for (final player in players) {
      if (player['id']?.toString() != partnerId) return player;
    }
    return players.isEmpty ? null : players.first;
  }

  Widget _avatar({
    required String name,
    required String photo,
    required Color accent,
  }) {
    Widget fallback() => Container(
          color: accent.withOpacity(.18),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: photo.isEmpty
                ? fallback()
                : Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback(),
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
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _metric(
    IconData icon,
    Color iconColor,
    String title,
    String subtitle,
  ) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            Icon(icon, color: iconColor, size: 23),
            const SizedBox(height: 5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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

  Widget _finalScreen() {
    final result = _finalResult ?? const <String, dynamic>{};
    final recRaw = result['recommendation'];
    final decisionRaw = result['finalDecision'];
    final rec = recRaw is Map
        ? Map<String, dynamic>.from(recRaw)
        : <String, dynamic>{};
    final decision = decisionRaw is Map
        ? Map<String, dynamic>.from(decisionRaw)
        : <String, dynamic>{};

    final partnerName = rec['partnerName']?.toString() ?? '';
    final partnerId = rec['partnerUserId']?.toString() ?? '';
    final partnerPhoto = _photo(rec['partnerPhotoUrl']?.toString());
    final compatibility = (rec['compatibility'] as num?)?.toInt() ?? 0;
    final status = decision['status']?.toString() ?? 'pending';
    final same = (rec['sameAnswers'] as num?)?.toInt();
    final different = (rec['differentAnswers'] as num?)?.toInt();
    final isRedFlag =
        (_finalGameKey ?? result['game']?.toString()) == 'red_flag_green_flag';
    final me = _myPlayer(result, partnerId);
    final myName = me?['name']?.toString() ?? widget.profileName.trim();
    final myPhoto = _photo(me?['photoUrl']?.toString());
    final total = isRedFlag
        ? 6
        : ((result['totalRounds'] as num?)?.toInt() ?? 10);

    if (partnerName.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    color: Color(0xFF8A90AB),
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Oyun tamamlandı',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu oyun için eşleşme önerisi oluşturulamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8A90AB)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _goHome,
                    child: const Text('Ana sayfaya dön'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -75,
              top: 8,
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
              left: -75,
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
                        child: IconButton(
                          onPressed: _goHome,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                          children: [
                            TextSpan(
                              text: 'meet',
                              style: TextStyle(color: AppColors.navy),
                            ),
                            TextSpan(
                              text: '6',
                              style: TextStyle(color: Color(0xFF2454FF)),
                            ),
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
                        fontSize: 42,
                        height: 1,
                        letterSpacing: -1.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRedFlag
                        ? '$total soru tamamlandı · En yakın görüş uyumun bulundu'
                        : '$total tur tamamlandı · En yakın oyun uyumun bulundu',
                    style: const TextStyle(
                      color: Color(0xFF8A90AB),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
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
                      children: [
                        Expanded(
                          child: _avatar(
                            name: myName.isEmpty ? 'Sen' : myName,
                            photo: myPhoto,
                            accent: const Color(0xFF2856FF),
                          ),
                        ),
                        SizedBox(
                          width: 94,
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.lime.withOpacity(.14),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFF8DD414),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Uyum',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '%$compatibility',
                                style: const TextStyle(
                                  color: Color(0xFF2454FF),
                                  fontSize: 34,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _avatar(
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
                      _metric(
                        Icons.flag_rounded,
                        const Color(0xFF6BD33A),
                        same == null ? '$compatibility% uyum' : '$same aynı seçim',
                        same == null ? 'Benzer oyun tarzı' : 'Aynı fikirdesiniz',
                      ),
                      const SizedBox(width: 8),
                      _metric(
                        Icons.flag_rounded,
                        const Color(0xFFFF5A60),
                        different == null
                            ? '${100 - compatibility}% fark'
                            : '$different farklı seçim',
                        different == null
                            ? 'Farklı yaklaşım'
                            : 'Farklı bakış açıları',
                      ),
                      const SizedBox(width: 8),
                      _metric(
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
                      color: AppColors.lime.withOpacity(.18),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          backgroundImage: partnerPhoto.isEmpty
                              ? null
                              : NetworkImage(partnerPhoto),
                          child: partnerPhoto.isEmpty
                              ? Text(
                                  partnerName[0].toUpperCase(),
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
                              Text(
                                'Sistem sana $partnerName adlı oyuncuyu öneriyor',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$partnerName da seni seçerse özel sohbete geçersiniz.',
                                style: const TextStyle(
                                  color: Color(0xFF7C839D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.favorite_border_rounded,
                          color: Color(0xFF91D71B),
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (status == 'matched')
                    SizedBox(
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _openChat,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text(
                          'Eşleştiniz · Özel mesaja geç',
                          style: TextStyle(fontWeight: FontWeight.w900),
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
                      child: FilledButton(
                        onPressed: _finalChoosing
                            ? null
                            : () => _finalChoice(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          '$partnerName ile eşleş →',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        onPressed: _finalChoosing
                            ? null
                            : () => _finalChoice(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: Color(0xFFBEC5D8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'Odaya devam et',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF6674E8),
                        size: 18,
                      ),
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
    if (_finalResult != null) return _finalScreen();

    return FutureBuilder<String>(
      future: _gameKeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameKey =
            snapshot.data ?? MiniGameSelectionService.selectedGameKey;
        _resolvedGameKey ??= gameKey;
        final childKey = ValueKey('${widget.roomId}:$_resumeEpoch:$gameKey');

        late final Widget game;
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
                    onPressed: _finishing
                        ? null
                        : () => _forceFinish(gameKey),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111A2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
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

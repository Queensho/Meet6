import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/live_service.dart';
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
  bool popupShown = false;
  String? error;
  int selectionSecondsLeft = 0;
  Timer? resultTimer;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    myUserId = await SessionService.loadAuthUserId();
    try {
      final data = await LiveService.room(widget.roomId);
      if (!mounted) return;
      setState(() {
        room = data;
        selectionSecondsLeft =
            (data['selectionSecondsLeft'] as num?)?.toInt() ?? 0;
        selectedUserId = data['mySelectionUserId']?.toString();
        submitted = selectedUserId != null &&
            selectedUserId!.isNotEmpty &&
            selectedUserId != 'null';
      });
      _startCountdown();
      if (!submitted && data['status'] == 'selection') {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showTimedSelectionPopup());
      }
      if (submitted) _startResultPolling();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    if (selectionSecondsLeft <= 0) return;
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (selectionSecondsLeft <= 1) {
        timer.cancel();
        setState(() => selectionSecondsLeft = 0);
        await _syncExpiredSelection();
      } else {
        setState(() => selectionSecondsLeft--);
      }
    });
  }

  Future<void> _syncExpiredSelection() async {
    try {
      final latest = await LiveService.room(widget.roomId);
      if (!mounted) return;
      setState(() {
        room = latest;
        selectionSecondsLeft =
            (latest['selectionSecondsLeft'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _showTimedSelectionPopup() async {
    if (!mounted || popupShown || submitted || selectionSecondsLeft <= 0) return;
    popupShown = true;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
        contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '10',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gizli seçim süreli',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bir kişiyi seçmek için 10 saniyen var. Süre dolunca seçim kapanır ve sonradan seçim yapılamaz.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: dark ? AppColors.lime : AppColors.navy,
                foregroundColor: dark ? AppColors.navy : Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Anladım',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _submit() async {
    if (selectedUserId == null ||
        submitting ||
        submitted ||
        selectionExpired) {
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await LiveService.submitRoomSelection(
        widget.roomId,
        selectedUserId!,
      );
      if (!mounted) return;
      setState(() {
        submitted = true;
        submitting = false;
      });
      if (result['matched'] == true && result['matchId'] != null) {
        await _openMatch(result['matchId'].toString());
      } else {
        _startResultPolling();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        error = e.message;
      });
    }
  }

  void _startResultPolling() {
    resultTimer?.cancel();
    resultTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _checkResult());
    _checkResult();
  }

  Future<void> _checkResult() async {
    if (!mounted || openingMatch) return;
    try {
      final result = await LiveService.roomSelectionResult(widget.roomId);
      if (result['matched'] == true && result['matchId'] != null) {
        await _openMatch(result['matchId'].toString());
        return;
      }
      final latestRoom = await LiveService.room(widget.roomId);
      if (!mounted) return;
      final latestSeconds =
          (latestRoom['selectionSecondsLeft'] as num?)?.toInt() ?? 0;
      setState(() {
        room = latestRoom;
        selectionSecondsLeft = latestSeconds;
      });
      if (latestRoom['status'] == 'closed') {
        resultTimer?.cancel();
        countdownTimer?.cancel();
      }
    } catch (_) {}
  }

  Future<void> _openMatch(String matchId) async {
    if (openingMatch) return;
    openingMatch = true;
    resultTimer?.cancel();
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
    resultTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final closed = selectionExpired;
    final remaining = selectionSecondsLeft.clamp(0, 10);
    final urgent = remaining <= 3;
    final progress = remaining / 10;

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
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: closed ? 0 : progress,
                          strokeWidth: 4,
                          backgroundColor: dark
                              ? const Color(0xFF263152)
                              : const Color(0xFFDCE3F8),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            urgent
                                ? const Color(0xFFE76A60)
                                : AppColors.blue,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 49,
                        height: 49,
                        decoration: BoxDecoration(
                          color: closed
                              ? const Color(0xFFFFE7DF)
                              : AppColors.lime,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$remaining',
                              style: TextStyle(
                                color: closed || urgent
                                    ? const Color(0xFFE76A60)
                                    : AppColors.navy,
                                fontSize: 20,
                                height: 0.95,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'sn',
                              style: TextStyle(
                                color: closed || urgent
                                    ? const Color(0xFFE76A60)
                                    : AppColors.navy,
                                fontSize: 8,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  submitted
                      ? 'Seçimin gizlice\nkaydedildi'
                      : closed
                          ? 'Seçim süresi\ndoldu'
                          : 'Kiminle devam\netmek istersin?',
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
                  submitted
                      ? 'Karşı taraf da seni seçerse eşleşme otomatik açılır.'
                      : closed
                          ? '10 saniyelik gizli seçim penceresi kapandı.'
                          : '10 saniye içinde sadece bir kişiyi seçebilirsin. Seçimin diğer kişiler tarafından görülmez.',
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
                            return InkWell(
                              onTap: submitted || closed
                                  ? null
                                  : () =>
                                      setState(() => selectedUserId = id),
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
                                                name.characters.first
                                                    .toUpperCase(),
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
                if (!submitted && !closed)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed:
                          selectedUserId == null || submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            dark ? AppColors.lime : AppColors.navy,
                        foregroundColor:
                            dark ? AppColors.navy : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                              ),
                            )
                          : const Icon(Icons.favorite_rounded),
                      label: const Text(
                        'Seçimimi kaydet',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: closed
                          ? () => Navigator.of(context)
                              .popUntil((route) => route.isFirst)
                          : null,
                      icon: closed
                          ? const Icon(Icons.home_outlined)
                          : const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                              ),
                            ),
                      label: Text(
                        closed
                            ? 'Ana ekrana dön'
                            : 'Karşılıklı seçim bekleniyor...',
                        style: const TextStyle(
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

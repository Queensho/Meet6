import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/gift_service.dart';
import '../../services/live_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/xp_level_ring.dart';
import 'room_selection_screen.dart';

class RoomForceSelectionButton extends StatefulWidget {
  const RoomForceSelectionButton({
    super.key,
    required this.roomId,
    this.profileName = '',
  });

  final String roomId;
  final String profileName;

  @override
  State<RoomForceSelectionButton> createState() => _RoomForceSelectionButtonState();
}

class _RoomForceSelectionButtonState extends State<RoomForceSelectionButton> {
  bool allowed = false;
  bool loading = true;
  bool ending = false;
  OverlayEntry? eliteOverlay;

  @override
  void initState() {
    super.initState();
    _loadCapability();
    _loadEliteRoomEffect();
  }

  Future<void> _loadEliteRoomEffect() async {
    try {
      final result = await GiftService.me();
      final raw = result['summary'];
      final summary = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      final level = (summary['profileLevel'] as num?)?.toInt() ?? 1;
      if (!mounted || level < 30) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || eliteOverlay != null) return;
        final overlay = Overlay.maybeOf(context);
        if (overlay == null) return;
        eliteOverlay = OverlayEntry(
          builder: (_) => const Positioned.fill(
            child: IgnorePointer(
              child: SafeArea(
                child: EliteRoomAura(
                  active: true,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        overlay.insert(eliteOverlay!);
      });
    } catch (_) {
      // XP özeti alınamazsa oda normal görünümle çalışmaya devam eder.
    }
  }

  Future<void> _loadCapability() async {
    try {
      final result =
          await LiveService.roomForceSelectionCapability(widget.roomId);
      if (!mounted) return;
      setState(() {
        allowed = result['allowed'] == true;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _endChat() async {
    if (ending) return;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('Sohbeti bitir?'),
        content: const Text(
          'Oda tüm kullanıcılar için hemen kapanacak ve 10 saniyelik gizli seçim başlayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.navy,
            ),
            child: const Text('Seçime geç'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => ending = true);
    try {
      await LiveService.forceRoomSelection(widget.roomId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomSelectionScreen(
            roomId: widget.roomId,
            profileName: widget.profileName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => ending = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet bitirilemedi. Tekrar dene.')),
      );
      setState(() => ending = false);
    }
  }

  @override
  void dispose() {
    eliteOverlay?.remove();
    eliteOverlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || !allowed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 38,
        child: FilledButton.icon(
          onPressed: ending ? null : _endChat,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.navy,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          icon: ending
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.navy,
                  ),
                )
              : const Icon(Icons.fast_forward_rounded, size: 18),
          label: const Text(
            'Bitir',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

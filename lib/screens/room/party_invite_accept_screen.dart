import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/mini_game_selection_service.dart';
import '../../services/party_invite_link_service.dart';
import '../../services/party_matchmaking_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../home/home_screen.dart';
import 'room_searching_screen.dart';

class PartyInviteAcceptScreen extends StatefulWidget {
  const PartyInviteAcceptScreen({
    super.key,
    required this.code,
    required this.profileName,
  });

  final String code;
  final String profileName;

  @override
  State<PartyInviteAcceptScreen> createState() => _PartyInviteAcceptScreenState();
}

class _PartyInviteAcceptScreenState extends State<PartyInviteAcceptScreen> {
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _accept());
  }

  Future<void> _accept() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await PartyMatchmakingService.accept(widget.code);
      final raw = result['party'];
      final party = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final roomMode = party['roomMode']?.toString() == 'game' ? 'game' : 'text';
      final gameKey = party['gameKey']?.toString();
      final duration = (party['roomDurationMinutes'] as num?)?.toInt() ?? 15;

      if (roomMode == 'game' && gameKey != null && gameKey.isNotEmpty) {
        MiniGameSelectionService.select(gameKey);
      }
      await PartyInviteLinkService.clearPendingCode();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomSearchingScreen(
            profileName: widget.profileName,
            roomDurationMinutes: duration,
            roomMode: roomMode,
            partyCode: widget.code,
          ),
        ),
      );
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
        error = 'Davet açılamadı. Lütfen tekrar dene.';
      });
    }
  }

  Future<void> _dismiss() async {
    await PartyInviteLinkService.clearPendingCode();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profileName: widget.profileName,
          city: '',
          country: '',
          distanceKm: 25,
          lookingFor: 'Herkes',
          minAge: 20,
          maxAge: 35,
          purpose: 'Yeni insanlarla tanışma',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF071022) : AppColors.lime;
    final text = dark ? Colors.white : AppColors.navy;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.topRight,
                child: Meet6MiniBrand(height: 26, forceLogo2: true),
              ),
              const Spacer(),
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_add_rounded, color: AppColors.lime, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Arkadaş daveti',
                textAlign: TextAlign.center,
                style: TextStyle(color: text, fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                'Davet ${widget.code} açılıyor. Sen ve arkadaşın aynı 6 kişilik odada olacaksınız; kalan 4 kişiyi Meet6 bulacak.',
                textAlign: TextAlign.center,
                style: TextStyle(color: text.withValues(alpha: .68), fontSize: 14, height: 1.45, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 28),
              if (loading)
                const CircularProgressIndicator(color: AppColors.navy)
              else ...[
                Text(
                  error ?? 'Davet açılamadı.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE04848), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _accept,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                    child: const Text('Tekrar dene', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: _dismiss, child: Text('Daveti kapat', style: TextStyle(color: text))),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

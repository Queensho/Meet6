import 'package:flutter/material.dart';

import '../../services/premium_subscription_service.dart';
import '../../services/runtime_app_config_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../premium/premium_screen.dart';
import 'room_searching_screen.dart';

class RoomRulesScreen extends StatefulWidget {
  const RoomRulesScreen({
    super.key,
    this.profileName = '',
  });

  final String profileName;

  @override
  State<RoomRulesScreen> createState() => _RoomRulesScreenState();
}

class _RoomRulesScreenState extends State<RoomRulesScreen> {
  bool premium = false;
  bool premiumLoading = true;
  int roomDurationMinutes = 15;
  String roomMode = 'text';

  bool get voiceMode => roomMode == 'voice';

  @override
  void initState() {
    super.initState();
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    try {
      final value = await PremiumSubscriptionService.status();
      if (!mounted) return;
      setState(() {
        premium = value.premium;
        premiumLoading = false;
        if (!premium) {
          roomDurationMinutes = 15;
          roomMode = 'text';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        premium = false;
        premiumLoading = false;
        roomDurationMinutes = 15;
        roomMode = 'text';
      });
    }
  }

  Future<void> _toggleDuration() async {
    if (premiumLoading) return;
    if (voiceMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium sesli odalar 30 dakikadır.')),
      );
      return;
    }
    if (premium) {
      setState(() => roomDurationMinutes = roomDurationMinutes == 15 ? 30 : 15);
      return;
    }

    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    if (activated == true) {
      await _loadPremium();
      if (mounted && premium) setState(() => roomDurationMinutes = 30);
    }
  }

  Future<void> _toggleRoomMode() async {
    if (premiumLoading) return;
    if (premium) {
      setState(() {
        if (voiceMode) {
          roomMode = 'text';
        } else {
          roomMode = 'voice';
          roomDurationMinutes = 30;
        }
      });
      return;
    }

    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    if (activated == true) {
      await _loadPremium();
      if (mounted && premium) {
        setState(() {
          roomMode = 'voice';
          roomDurationMinutes = 30;
        });
      }
    }
  }

  void _startSearch(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomSearchingScreen(
          profileName: widget.profileName,
          roomDurationMinutes: roomDurationMinutes,
          roomMode: roomMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RuntimeAppConfig>(
      valueListenable: RuntimeAppConfigService.listenable,
      builder: (context, runtime, _) => Scaffold(
        backgroundColor: AppColors.lime,
        body: LayoutBuilder(
          builder: (context, viewport) {
            final desktop = viewport.maxWidth > 520;
            final width = desktop ? 390.0 : viewport.maxWidth;
            final height = desktop ? 844.0 : viewport.maxHeight;

            return Container(
              color: desktop ? const Color(0xFFEFF1F7) : AppColors.lime,
              alignment: Alignment.center,
              child: Container(
                width: width,
                height: height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                  boxShadow: desktop
                      ? const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ]
                      : null,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(.35),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                            const Spacer(),
                            const Meet6MiniBrand(height: 26, forceLogo2: true),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.lime,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(.68),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: AppColors.navy.withOpacity(.14),
                                  blurRadius: 28,
                                  spreadRadius: 7,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: voiceMode
                                ? const Icon(Icons.mic_rounded, color: AppColors.navy, size: 58)
                                : const Text(
                                    '6',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 74,
                                      height: .9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          voiceMode ? 'Premium sesli odaya katıl' : 'Odaya katılmadan önce',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 27,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          voiceMode
                              ? '6 Premium kullanıcı, 30 dakika boyunca canlı sesli sohbet eder.'
                              : 'Meet6 odaları kısa, gerçek ve güvenli sohbetler için tasarlandı.',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _RuleTile(
                          icon: voiceMode ? Icons.mic_rounded : Icons.chat_bubble_outline_rounded,
                          title: voiceMode ? 'Sesli sohbet · Premium' : 'Yazılı sohbet',
                          subtitle: premiumLoading
                              ? 'Premium durumu kontrol ediliyor...'
                              : premium
                                  ? (voiceMode
                                      ? 'Yalnız Premium üyelerle sesli oda. Yazılıya dönmek için dokun.'
                                      : 'Premium sesli odaya geçmek için dokun.')
                                  : 'Sesli sohbet yalnız Meet6 Premium üyelerine açıktır.',
                          onTap: _toggleRoomMode,
                          trailing: premiumLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.navy,
                                  ),
                                )
                              : Icon(
                                  voiceMode
                                      ? Icons.workspace_premium_rounded
                                      : premium
                                          ? Icons.swap_horiz_rounded
                                          : Icons.lock_rounded,
                                  color: AppColors.navy,
                                  size: 20,
                                ),
                        ),
                        _RuleTile(
                          icon: premium ? Icons.workspace_premium_rounded : Icons.groups_2_rounded,
                          title: '${runtime.minimumUsers} kişi, $roomDurationMinutes dakika',
                          subtitle: voiceMode
                              ? 'Sesli Premium odaların süresi 30 dakikadır.'
                              : premiumLoading
                                  ? 'Premium oda seçenekleri kontrol ediliyor...'
                                  : premium
                                      ? 'Premium aktif · 15 / 30 dk arasında değiştirmek için dokun.'
                                      : 'Sen + ${runtime.minimumUsers - 1} kişi sohbet eder. 30 dk Premium için dokun.',
                          onTap: _toggleDuration,
                          trailing: Icon(
                            voiceMode
                                ? Icons.mic_rounded
                                : premium
                                    ? Icons.swap_horiz_rounded
                                    : Icons.lock_rounded,
                            color: AppColors.navy,
                            size: 20,
                          ),
                        ),
                        const _RuleTile(
                          icon: Icons.favorite_rounded,
                          title: 'Saygılı ve doğal ol',
                          subtitle: 'Hakaret, taciz ve rahatsız edici davranışlara yer yok.',
                        ),
                        _RuleTile(
                          icon: Icons.visibility_off_rounded,
                          title: 'Seçimler gizlidir',
                          subtitle: 'Sohbet bitince ${runtime.selectionSeconds} saniyelik gizli seçim başlar; yalnızca karşılıklı seçim eşleşir.',
                        ),
                        _RuleTile(
                          icon: Icons.timer_rounded,
                          title: 'Süre bitince sohbet kapanır',
                          subtitle: 'Gerekirse oylamayla +${runtime.extensionMinutes} dakika uzatılabilir.',
                          last: true,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () => _startSearch(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(voiceMode ? Icons.mic_rounded : Icons.search_rounded),
                                const SizedBox(width: 9),
                                Text(
                                  voiceMode
                                      ? '30 dk Premium sesli oda ara'
                                      : '$roomDurationMinutes dk oda ara',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.last = false,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11.5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.31),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.navy.withOpacity(.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.lime, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.navy.withOpacity(.68),
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 7),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(17),
              child: content,
            ),
    );
  }
}

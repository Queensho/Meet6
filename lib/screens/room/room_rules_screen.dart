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

  void _selectTextMode() {
    if (premiumLoading) return;
    setState(() => roomMode = 'text');
  }

  Future<void> _selectVoiceMode() async {
    if (premiumLoading) return;
    if (premium) {
      setState(() {
        roomMode = 'voice';
        roomDurationMinutes = 15;
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
          roomDurationMinutes = 15;
        });
      }
    }
  }

  Future<void> _selectDuration(int minutes) async {
    if (premiumLoading) return;
    if (minutes == 15) {
      setState(() => roomDurationMinutes = 15);
      return;
    }

    if (voiceMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium birebir sesli eşleşmeler 15 dakikadır.'),
        ),
      );
      return;
    }

    if (premium) {
      setState(() => roomDurationMinutes = 30);
      return;
    }

    final activated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
    if (!mounted) return;
    if (activated == true) {
      await _loadPremium();
      if (mounted && premium) {
        setState(() => roomDurationMinutes = 30);
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
                  borderRadius:
                      desktop ? BorderRadius.circular(32) : BorderRadius.zero,
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
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(.38),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                            const Spacer(),
                            const Meet6MiniBrand(
                              height: 26,
                              forceLogo2: true,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.lime,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(.64),
                                        blurRadius: 22,
                                        spreadRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: AppColors.navy.withOpacity(.12),
                                        blurRadius: 24,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '6',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 64,
                                      height: .9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -4,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Center(
                                child: Text(
                                  'Odaya katılmadan önce',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 28,
                                    height: 1.02,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Meet6 odaları kısa, gerçek ve güvenli sohbetler için tasarlandı.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.navy.withOpacity(.72),
                                    fontSize: 12.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const _SectionTitle(
                                title: 'Oda seçimi',
                                subtitle: 'Sohbet etmek istediğin oda tipini seç.',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _ModeCard(
                                      selected: !voiceMode,
                                      icon: Icons.groups_2_rounded,
                                      title: '${runtime.minimumUsers} Kişi Yazılı',
                                      subtitle: '${runtime.minimumUsers} kişi',
                                      durationLabel:
                                          '$roomDurationMinutes dk',
                                      statusLabel: roomDurationMinutes == 30
                                          ? 'Premium'
                                          : 'Standart',
                                      onTap: _selectTextMode,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ModeCard(
                                      selected: voiceMode,
                                      icon: Icons.mic_rounded,
                                      title: 'Birebir Sesli',
                                      subtitle: '1 kişiyle',
                                      durationLabel: '15 dk',
                                      premium: true,
                                      loading: premiumLoading,
                                      onTap: _selectVoiceMode,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const _SectionTitle(
                                title: 'Süre seçimi',
                                subtitle: 'Ne kadar sohbet etmek istersin?',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DurationChoice(
                                      selected: roomDurationMinutes == 15,
                                      label: '15 dk',
                                      onTap: () => _selectDuration(15),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DurationChoice(
                                      selected: roomDurationMinutes == 30,
                                      label: '30 dk',
                                      premium: true,
                                      disabled: voiceMode,
                                      onTap: () => _selectDuration(30),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                voiceMode
                                    ? 'Birebir sesli eşleşmeler 15 dakikadır.'
                                    : '15 dk herkes için. 30 dk Premium üyelikte açılır.',
                                style: TextStyle(
                                  color: AppColors.navy.withOpacity(.62),
                                  fontSize: 10.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const _SectionTitle(
                                title: 'Oda kuralları',
                                subtitle: 'Herkes için daha iyi bir deneyim.',
                              ),
                              const SizedBox(height: 10),
                              _RuleTile(
                                icon: Icons.visibility_off_rounded,
                                title: 'Kararınız gizlidir',
                                subtitle:
                                    'Görüşme bitince ${runtime.selectionSeconds} saniyelik gizli seçim başlar.',
                              ),
                              _RuleTile(
                                icon: Icons.timer_rounded,
                                title: 'Süre bitince görüşme kapanır',
                                subtitle:
                                    'İsterseniz oylamayla +${runtime.extensionMinutes} dakika uzatılabilir.',
                              ),
                              const _RuleTile(
                                icon: Icons.favorite_rounded,
                                title: 'Saygılı ve doğal ol',
                                subtitle:
                                    'Hakaret, taciz ve rahatsız edici davranışlara yer yok.',
                                last: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton(
                            onPressed: premiumLoading
                                ? null
                                : () => _startSearch(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              disabledBackgroundColor:
                                  AppColors.navy.withOpacity(.6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  voiceMode
                                      ? Icons.mic_rounded
                                      : Icons.search_rounded,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    voiceMode
                                        ? 'Birebir sesli eşleşme ara'
                                        : '$roomDurationMinutes dk oda ara',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.navy.withOpacity(.67),
            fontSize: 11.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.onTap,
    this.statusLabel,
    this.premium = false,
    this.loading = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String durationLabel;
  final VoidCallback onTap;
  final String? statusLabel;
  final bool premium;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.navy;
    final secondary = selected
        ? Colors.white.withOpacity(.72)
        : AppColors.navy.withOpacity(.64);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 178,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white.withOpacity(.38),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.navy
                : AppColors.navy.withOpacity(.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(selected ? .13 : .06),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(.1)
                        : AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.lime,
                    size: 27,
                  ),
                ),
                const Spacer(),
                if (loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (premium)
                  const _PremiumBadge()
                else if (selected)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.navy,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                height: 1.02,
                fontWeight: FontWeight.w900,
                letterSpacing: -.45,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: secondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniPill(
                  icon: Icons.schedule_rounded,
                  label: durationLabel,
                  selected: selected,
                ),
                if (statusLabel != null)
                  _MiniPill(
                    label: statusLabel!,
                    selected: selected,
                    premium: statusLabel == 'Premium',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD968),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.navy,
            size: 13,
          ),
          SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.selected,
    this.icon,
    this.premium = false,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final foreground = premium
        ? AppColors.navy
        : selected
            ? Colors.white
            : AppColors.navy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: premium
            ? const Color(0xFFFFD968)
            : selected
                ? Colors.white.withOpacity(.11)
                : AppColors.navy.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.selected,
    required this.label,
    required this.onTap,
    this.premium = false,
    this.disabled = false,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final bool premium;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.navy;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.navy
              : Colors.white.withOpacity(disabled ? .24 : .4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.navy.withOpacity(.07)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              color: foreground,
              size: 21,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (premium) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD968),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.navy,
                  size: 13,
                ),
              ),
            ],
          ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.navy.withOpacity(.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.lime, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.navy.withOpacity(.66),
                      fontSize: 10.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

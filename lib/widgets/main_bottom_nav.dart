import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_runtime_config_service.dart';
import '../services/live_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.unreadMessages = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  // Eski ekran çağrılarını kırmamak için parametre tutuluyor. Rozet değeri
  // tek doğruluk kaynağı olan backend matches snapshot'ından hesaplanır.
  final int unreadMessages;

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  int unreadMessages = 0;
  StreamSubscription<RealtimeEvent>? realtimeSub;

  @override
  void initState() {
    super.initState();
    unawaited(AppRuntimeConfigService.refresh());
    _refreshUnread();
    realtimeSub = RealtimeService.events.listen((event) {
      if (!mounted) return;
      if (event.type == 'matches:update') {
        final next = (event.data['unreadTotal'] as num?)?.toInt() ?? 0;
        if (next != unreadMessages) setState(() => unreadMessages = next);
      } else if (event.type == 'connection:connected') {
        unawaited(_refreshUnread());
        unawaited(AppRuntimeConfigService.refresh());
      }
    });
  }

  Future<void> _refreshUnread() async {
    try {
      final data = await LiveService.matches();
      if (!mounted) return;
      final next = (data['unreadTotal'] as num?)?.toInt() ?? 0;
      if (next != unreadMessages) setState(() => unreadMessages = next);
    } catch (_) {
      // Geçici bağlantı hatasında son doğru rozeti koru.
    }
  }

  @override
  void didUpdateWidget(covariant MainBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex == 2) unawaited(_refreshUnread());
  }

  @override
  void dispose() {
    realtimeSub?.cancel();
    super.dispose();
  }

  double _homeNavWidth(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final phoneWidth = mediaWidth > 520 ? 390.0 : mediaWidth;
    final homeHorizontal = (phoneWidth * .055).clamp(18.0, 24.0);

    // Ana sayfada MainBottomNav, sayfa yatay padding'i + kendi eski 14px
    // güvenli boşluğu içinde çiziliyordu. Tüm sekmelerde aynı gerçek genişliği
    // üretmek için o ölçüyü burada tek kaynağa çeviriyoruz.
    return (phoneWidth - (2 * (homeHorizontal + 14))).clamp(240.0, 340.0);
  }

  Widget _nav() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              outlineIcon: Icons.home_outlined,
              selected: widget.selectedIndex == 0,
              onTap: () => widget.onTap(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.favorite_rounded,
              outlineIcon: Icons.favorite_border_rounded,
              selected: widget.selectedIndex == 1,
              onTap: () => widget.onTap(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat_bubble_rounded,
              outlineIcon: Icons.chat_bubble_outline_rounded,
              selected: widget.selectedIndex == 2,
              badge: unreadMessages,
              onTap: () => widget.onTap(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              outlineIcon: Icons.person_outline_rounded,
              selected: widget.selectedIndex == 3,
              onTap: () => widget.onTap(3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppRuntimeConfig>(
      valueListenable: AppRuntimeConfigService.value,
      builder: (context, config, _) {
        final showAnnouncement = config.announcementEnabled &&
            config.announcementMessage.trim().isNotEmpty;
        final targetWidth = _homeNavWidth(context);

        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 5, 0, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = targetWidth.clamp(0.0, constraints.maxWidth).toDouble();
              return Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAnnouncement) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.navy.withOpacity(.10),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.campaign_rounded,
                                color: AppColors.navy,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (config.announcementTitle.trim().isNotEmpty)
                                      Text(
                                        config.announcementTitle.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    Text(
                                      config.announcementMessage.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 10.5,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _nav(),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.outlineIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData outlineIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: selected ? 42 : 44,
            height: selected ? 42 : 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.lime : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 13 : 18),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? icon : outlineIcon,
                  color: selected ? AppColors.navy : Colors.white,
                  size: 23,
                ),
                if (badge > 0)
                  Positioned(
                    top: -9,
                    right: -12,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.navy, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          height: 1,
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

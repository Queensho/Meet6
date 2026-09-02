import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.unreadMessages = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 5, 14, 8),
      child: Container(
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
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.favorite_rounded,
                outlineIcon: Icons.favorite_border_rounded,
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.chat_bubble_rounded,
                outlineIcon: Icons.chat_bubble_outline_rounded,
                selected: selectedIndex == 2,
                badge: unreadMessages,
                onTap: () => onTap(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_rounded,
                outlineIcon: Icons.person_outline_rounded,
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ),
          ],
        ),
      ),
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
                  size: selected ? 23 : 23,
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

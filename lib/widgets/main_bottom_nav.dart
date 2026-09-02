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
      child: Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.97),
          border: const Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_rounded,
                outlineIcon: Icons.home_outlined,
                label: 'Ana Sayfa',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.favorite_rounded,
                outlineIcon: Icons.favorite_border_rounded,
                label: 'Eşleşmeler',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.chat_bubble_rounded,
                outlineIcon: Icons.chat_bubble_outline_rounded,
                label: 'Mesajlar',
                selected: selectedIndex == 2,
                badge: unreadMessages,
                onTap: () => onTap(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.person_rounded,
                outlineIcon: Icons.person_outline_rounded,
                label: 'Profil',
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
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData outlineIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime.withOpacity(.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? icon : outlineIcon,
                  color: selected ? AppColors.navy : AppColors.muted,
                  size: 23,
                ),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
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
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.navy : AppColors.muted,
                fontSize: 9.3,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../models/message_thread_preview.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/phone_frame.dart';
import '../home/home_screen.dart';
import '../matches/matches_screen.dart';
import '../profile/profile_screen.dart';
import 'private_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.profileName,
    required this.preferences,
  });

  final String profileName;
  final MatchingPreferences preferences;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late MatchingPreferences preferences;

  final chats = const [
    MessageThreadPreview(
      name: 'Ece',
      lastMessage: 'Ben de aynı şeyi düşündüm 😄',
      timeLabel: '10:32',
      initial: 'E',
      unreadCount: 2,
      isOnline: true,
    ),
    MessageThreadPreview(
      name: 'Deniz',
      lastMessage: 'Hafta sonu için kahve planı yapalım mı?',
      timeLabel: 'Dün',
      initial: 'D',
      isOnline: false,
    ),
    MessageThreadPreview(
      name: 'Bora',
      lastMessage: 'Odadaki soru çok iyiydi 😂',
      timeLabel: 'Pzt',
      initial: 'B',
      isOnline: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    preferences = widget.preferences;
  }

  void _openChat(MessageThreadPreview item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          name: item.name,
          initial: item.initial,
          isOnline: item.isOnline,
          fromNewMatch: false,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profileName: widget.profileName,
          city: preferences.city,
          country: preferences.country,
          latitude: preferences.latitude,
          longitude: preferences.longitude,
          distanceKm: preferences.distanceKm,
          lookingFor: preferences.lookingFor,
          minAge: preferences.minAge,
          maxAge: preferences.maxAge,
          purpose: preferences.purpose,
        ),
      ),
    );
  }

  void _goMatches() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MatchesScreen(
          profileName: widget.profileName,
          preferences: preferences,
        ),
      ),
    );
  }

  void _goProfile() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          profileName: widget.profileName,
          initialPreferences: preferences,
          asRootTab: true,
          onPreferencesChanged: (value) {
            if (!mounted) return;
            setState(() => preferences = value);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mesajlar',
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 30,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Özel sohbetlerin',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 43,
                              height: 43,
                              decoration: const BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Text(
                          'Sohbetler',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SliverList.separated(
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 88,
                        endIndent: 20,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final item = chats[index];
                        return InkWell(
                          onTap: () => _openChat(item),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: AppColors.navy,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        item.initial,
                                        style: const TextStyle(
                                          color: AppColors.lime,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (item.isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF36C76C),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: scheme.surface,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: TextStyle(
                                                color: scheme.onSurface,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.timeLabel,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: item.unreadCount > 0
                                                    ? scheme.onSurface
                                                    : scheme.onSurfaceVariant,
                                                fontSize: 12,
                                                fontWeight: item.unreadCount > 0
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (item.unreadCount > 0) ...[
                                            const SizedBox(width: 9),
                                            Container(
                                              constraints: const BoxConstraints(minWidth: 21),
                                              height: 21,
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${item.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
              MainBottomNav(
                selectedIndex: 2,
                unreadMessages: 2,
                onTap: (index) {
                  if (index == 0) _goHome();
                  if (index == 1) _goMatches();
                  if (index == 3) _goProfile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

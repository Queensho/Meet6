import 'package:flutter/material.dart';

import '../../models/matching_preferences.dart';
import '../../models/message_thread_preview.dart';
import '../../theme/app_colors.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/phone_frame.dart';
import '../home/home_screen.dart';
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

  final newMatches = const [
    MessageThreadPreview(
      name: 'Ece',
      lastMessage: 'Yeni eşleşme',
      timeLabel: 'Şimdi',
      initial: 'E',
      isOnline: true,
      isNewMatch: true,
    ),
    MessageThreadPreview(
      name: 'Selin',
      lastMessage: 'Yeni eşleşme',
      timeLabel: '12 dk',
      initial: 'S',
      isOnline: true,
      isNewMatch: true,
    ),
    MessageThreadPreview(
      name: 'Mert',
      lastMessage: 'Yeni eşleşme',
      timeLabel: '1 sa',
      initial: 'M',
      isNewMatch: true,
    ),
  ];

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

  void _openChat(MessageThreadPreview item, {bool newMatch = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          name: item.name,
          initial: item.initial,
          isOnline: item.isOnline,
          fromNewMatch: newMatch,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PhoneFrame(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mesajlar',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 30,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.1,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Eşleşmelerin ve özel sohbetlerin',
                                  style: TextStyle(
                                    color: AppColors.muted,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Text(
                            'Yeni eşleşmeler',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${newMatches.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 128,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                        scrollDirection: Axis.horizontal,
                        itemCount: newMatches.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = newMatches[index];
                          return InkWell(
                            onTap: () => _openChat(item, newMatch: true),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 82,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.92),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: const BoxDecoration(
                                          color: AppColors.navy,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          item.initial,
                                          style: const TextStyle(
                                            color: AppColors.lime,
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AppColors.lime,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.favorite_rounded,
                                            color: AppColors.navy,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 7),
                      child: Text(
                        'Sohbetler',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 88,
                      endIndent: 20,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final item = chats[index];
                      return InkWell(
                        onTap: () => _openChat(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 11, 20, 11),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
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
                                          border: Border.all(color: Colors.white, width: 2),
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
                                            style: const TextStyle(
                                              color: AppColors.navy,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          item.timeLabel,
                                          style: const TextStyle(
                                            color: AppColors.muted,
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
                                                  ? AppColors.navy
                                                  : AppColors.muted,
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
                                            minWidth: 21,
                                            height: 21,
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.blue,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
              ),
            ),
            MainBottomNav(
              selectedIndex: 1,
              unreadMessages: 2,
              onTap: (index) {
                if (index == 0) _goHome();
                if (index == 2) _goProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

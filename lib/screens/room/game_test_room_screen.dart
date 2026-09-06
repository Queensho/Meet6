import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';

class GameTestRoomScreen extends StatelessWidget {
  const GameTestRoomScreen({
    super.key,
    required this.profileName,
  });

  final String profileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final me = profileName.trim().isEmpty ? 'Sen' : profileName.trim();
    final players = <String>[me, 'Ece', 'Mert', 'Selin', 'Arda', 'Duru'];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF101D16), Color(0xFF071022)]
                  : const [Color(0xFFD8FF32), Color(0xFFF8FFD6)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: dark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      const Meet6MiniBrand(height: 28),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mini Oyun Test Odası',
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.navy,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '5 test oyuncusu + sen = 6 kişi',
                    style: TextStyle(
                      color: dark ? Colors.white70 : AppColors.navy.withOpacity(.68),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: .86,
                    ),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final isMe = index == 0;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.navy
                              : (dark ? const Color(0xFF15231C) : Colors.white.withOpacity(.72)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMe
                                ? AppColors.lime
                                : AppColors.navy.withOpacity(.10),
                            width: isMe ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isMe ? AppColors.lime : AppColors.blue.withOpacity(.16),
                              child: Text(
                                players[index].characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              players[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : (dark ? Colors.white : AppColors.navy),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isMe ? 'SEN' : 'TEST',
                              style: TextStyle(
                                color: isMe
                                    ? AppColors.lime
                                    : (dark ? Colors.white54 : AppColors.navy.withOpacity(.48)),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sports_esports_rounded, color: AppColors.lime),
                            SizedBox(width: 8),
                            Text(
                              'İki Doğru Bir Yalan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Test odasında 6 oyuncu hazır. Oyun akışı burada geliştirilecek ve gerçek oda mantığına bağlanacak.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Oyunu başlat',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

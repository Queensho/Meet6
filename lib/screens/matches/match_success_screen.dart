import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';
import '../../widgets/phone_frame.dart';
import '../messages/private_chat_screen.dart';

class MatchSuccessScreen extends StatefulWidget {
  const MatchSuccessScreen({
    super.key,
    required this.matchId,
    required this.profileName,
    required this.matchProfile,
  });

  final String matchId;
  final String profileName;
  final Map<String, dynamic> matchProfile;

  @override
  State<MatchSuccessScreen> createState() => _MatchSuccessScreenState();
}

class _MatchSuccessScreenState extends State<MatchSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> scale;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    scale = CurvedAnimation(parent: controller, curve: Curves.elasticOut);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get matchName => widget.matchProfile['display_name']?.toString() ?? 'Meet6';

  String get matchPhoto {
    final raw = widget.matchProfile['photo_urls'];
    if (raw is List && raw.isNotEmpty) return raw.first.toString();
    return '';
  }

  void _openChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          matchId: widget.matchId,
          name: matchName,
          userId: widget.matchProfile['user_id']?.toString() ?? '',
          photoUrl: matchPhoto,
          fromNewMatch: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lime,
      body: PhoneFrame(
        child: Container(
          color: AppColors.lime,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Meet6MiniBrand(height: 30, forceLogo2: true),
                  ),
                  const Spacer(),
                  ScaleTransition(
                    scale: scale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 238,
                          height: 238,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.navy.withOpacity(.10), width: 2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PhotoBubble(
                              url: '',
                              fallback: widget.profileName.trim().isEmpty
                                  ? '6'
                                  : widget.profileName.trim().characters.first.toUpperCase(),
                            ),
                            Transform.translate(
                              offset: const Offset(-10, 0),
                              child: _PhotoBubble(
                                url: matchPhoto,
                                fallback: matchName.characters.first.toUpperCase(),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 34,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppColors.lime, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Eşleştiniz!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '$matchName de seni seçti. Özel sohbetiniz artık açık.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy.withOpacity(.72),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _openChat,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text(
                        'Mesaj gönder',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text(
                      'Şimdi değil',
                      style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
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

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.url, required this.fallback});

  final String url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: ClipOval(
        child: Container(
          color: AppColors.navy,
          child: url.isEmpty
              ? Center(
                  child: Text(
                    fallback,
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Image.network(
                  ApiService.absoluteMediaUrl(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      fallback,
                      style: const TextStyle(
                        color: AppColors.lime,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

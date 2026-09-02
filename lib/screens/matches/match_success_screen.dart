import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/meet6_3d_avatar.dart';
import '../messages/private_chat_screen.dart';

class MatchSuccessScreen extends StatefulWidget {
  const MatchSuccessScreen({
    super.key,
    required this.profileName,
    required this.matchName,
    required this.matchInitial,
    required this.avatarAlignment,
  });

  final String profileName;
  final String matchName;
  final String matchInitial;
  final Alignment avatarAlignment;

  @override
  State<MatchSuccessScreen> createState() => _MatchSuccessScreenState();
}

class _MatchSuccessScreenState extends State<MatchSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _myInitial {
    final name = widget.profileName.trim();
    return name.isEmpty ? '6' : name.characters.first.toUpperCase();
  }

  void _openChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          name: widget.matchName,
          initial: widget.matchInitial,
          fromNewMatch: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 30,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.8,
                              ),
                              children: [
                                TextSpan(
                                  text: 'meet',
                                  style: TextStyle(color: AppColors.navy),
                                ),
                                TextSpan(
                                  text: '6',
                                  style: TextStyle(color: AppColors.blue),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  color: AppColors.navy,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Karşılıklı seçim',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ScaleTransition(
                        scale: _scale,
                        child: SizedBox(
                          width: 300,
                          height: 190,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 22,
                                child: Container(
                                  width: 126,
                                  height: 126,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.navy.withOpacity(.14),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.navy,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _myInitial,
                                      style: const TextStyle(
                                        color: AppColors.lime,
                                        fontSize: 46,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 22,
                                child: Meet63DAvatar(
                                  alignment: widget.avatarAlignment,
                                  size: 126,
                                  borderWidth: 5,
                                ),
                              ),
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: AppColors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Eşleştiniz!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 39,
                          height: .98,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.matchName} ile ikiniz de birbirinizi seçtiniz.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Artık özel sohbetiniz açık.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton(
                          onPressed: _openChat,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(19),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, size: 20),
                              SizedBox(width: 9),
                              Text(
                                'Mesaj gönder',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.navy,
                        ),
                        child: const Text(
                          'Şimdi değil',
                          style: TextStyle(fontWeight: FontWeight.w900),
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
    );
  }
}

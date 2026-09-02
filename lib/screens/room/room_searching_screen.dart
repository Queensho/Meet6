import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/meet6_3d_avatar.dart';
import '../chat/room_chat_screen.dart';

class RoomSearchingScreen extends StatefulWidget {
  const RoomSearchingScreen({
    super.key,
    this.profileName = '',
  });

  final String profileName;

  @override
  State<RoomSearchingScreen> createState() => _RoomSearchingScreenState();
}

class _RoomSearchingScreenState extends State<RoomSearchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _foundTimer;
  Timer? _enterTimer;
  bool found = false;

  static const _alignments = [
    Alignment(0, -1),
    Alignment(-1, -.30),
    Alignment(1, -.30),
    Alignment(-1, .60),
    Alignment(1, .60),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..forward();

    _foundTimer = Timer(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      setState(() => found = true);
    });

    _enterTimer = Timer(const Duration(milliseconds: 3500), _enterRoom);
  }

  void _enterRoom() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomChatScreen(profileName: widget.profileName),
      ),
    );
  }

  @override
  void dispose() {
    _foundTimer?.cancel();
    _enterTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF50650D),
      body: LayoutBuilder(
        builder: (context, viewport) {
          final desktop = viewport.maxWidth > 520;
          final width = desktop ? 390.0 : viewport.maxWidth;
          final height = desktop ? 844.0 : viewport.maxHeight;

          return Container(
            color: desktop ? const Color(0xFFEFF1F7) : const Color(0xFF50650D),
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius:
                    desktop ? BorderRadius.circular(32) : BorderRadius.zero,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF52680F), Color(0xFF263108)],
                ),
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
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
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
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: '6',
                                  style: TextStyle(color: AppColors.lime),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text(
                              'İptal',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final p = Curves.easeOutCubic.transform(
                            _controller.value.clamp(0.0, 1.0),
                          );
                          final avatarCount = (p * 5).ceil().clamp(1, 5);

                          return SizedBox(
                            width: 310,
                            height: 310,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                for (final factor in [.98, .80, .62, .46])
                                  Container(
                                    width: 310 * factor,
                                    height: 310 * factor,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(
                                          factor == .46 ? .42 : .18,
                                        ),
                                        width: factor == .46 ? 2.6 : 1.6,
                                      ),
                                      boxShadow: factor == .46
                                          ? [
                                              BoxShadow(
                                                color: AppColors.lime
                                                    .withOpacity(.22),
                                                blurRadius: 28,
                                                spreadRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                Container(
                                  width: 132,
                                  height: 132,
                                  decoration: BoxDecoration(
                                    color: AppColors.lime,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.lime.withOpacity(.48),
                                        blurRadius: 32,
                                        spreadRadius: 9,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
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
                                for (var i = 0; i < avatarCount; i++)
                                  _OrbitFoundAvatar(
                                    index: i,
                                    alignment: _alignments[i],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 34),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey(found),
                          children: [
                            Text(
                              found ? 'Uygun oda bulundu!' : 'Oda aranıyor...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              found
                                  ? '5 kişi hazır. Odaya giriyorsun.'
                                  : 'Sana uygun 5 kişi bulunuyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.16),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(.10)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.lime,
                                  size: 21,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    found
                                        ? 'Oda hazır, bağlanılıyor'
                                        : 'En uygun oda aranıyor',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 7,
                                    value: found ? 1 : _controller.value * .90,
                                    backgroundColor: Colors.white.withOpacity(.12),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppColors.lime,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Oda bulununca sohbet otomatik başlayacak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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

class _OrbitFoundAvatar extends StatelessWidget {
  const _OrbitFoundAvatar({
    required this.index,
    required this.alignment,
  });

  final int index;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const positions = [
      Alignment(0, -1.0),
      Alignment(-.92, -.25),
      Alignment(.92, -.25),
      Alignment(-.68, .78),
      Alignment(.68, .78),
    ];
    final pos = positions[index];
    final radius = 118.0;

    return Transform.translate(
      offset: Offset(pos.x * radius, pos.y * radius),
      child: Meet63DAvatar(
        alignment: alignment,
        size: 52,
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum XpRewardTier {
  none,
  limeFrame,
  risingBadge,
  neonFrame,
  animatedStar,
  eliteFrame,
  eliteBadge,
}

XpRewardTier xpRewardTierForLevel(int level) {
  if (level >= 30) return XpRewardTier.eliteBadge;
  if (level >= 20) return XpRewardTier.eliteFrame;
  if (level >= 18) return XpRewardTier.animatedStar;
  if (level >= 10) return XpRewardTier.neonFrame;
  if (level >= 5) return XpRewardTier.risingBadge;
  if (level >= 3) return XpRewardTier.limeFrame;
  return XpRewardTier.none;
}

String xpRewardNameForLevel(int level) {
  switch (xpRewardTierForLevel(level)) {
    case XpRewardTier.limeFrame:
      return 'Lime çerçeve';
    case XpRewardTier.risingBadge:
      return 'Yükselen rozet';
    case XpRewardTier.neonFrame:
      return 'Neon çerçeve';
    case XpRewardTier.animatedStar:
      return 'Animasyonlu yıldız';
    case XpRewardTier.eliteFrame:
      return 'Elite çerçeve';
    case XpRewardTier.eliteBadge:
      return 'Meet6 Elite';
    case XpRewardTier.none:
      return 'Başlangıç seviyesi';
  }
}

class XpLevelRing extends StatefulWidget {
  const XpLevelRing({
    super.key,
    required this.level,
    this.totalXp,
    this.size = 58,
    this.onTap,
    this.showXp = true,
  });

  final int level;
  final int? totalXp;
  final double size;
  final VoidCallback? onTap;
  final bool showXp;

  @override
  State<XpLevelRing> createState() => _XpLevelRingState();
}

class _XpLevelRingState extends State<XpLevelRing>
    with SingleTickerProviderStateMixin {
  static const _spritePath = 'assets/images/xp_level_rewards_sprite.png';
  static const _spriteCount = 6;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _safeLevel => widget.level.clamp(1, 30);

  XpRewardTier get _tier => xpRewardTierForLevel(_safeLevel);

  int? get _spriteIndex {
    switch (_tier) {
      case XpRewardTier.limeFrame:
        return 0;
      case XpRewardTier.risingBadge:
        return 1;
      case XpRewardTier.neonFrame:
        return 2;
      case XpRewardTier.animatedStar:
        return 3;
      case XpRewardTier.eliteFrame:
        return 4;
      case XpRewardTier.eliteBadge:
        return 5;
      case XpRewardTier.none:
        return null;
    }
  }

  double get _frameScale {
    switch (_tier) {
      case XpRewardTier.limeFrame:
        return 1.48;
      case XpRewardTier.risingBadge:
        return 1.72;
      case XpRewardTier.neonFrame:
        return 1.58;
      case XpRewardTier.animatedStar:
        return 1.70;
      case XpRewardTier.eliteFrame:
        return 1.72;
      case XpRewardTier.eliteBadge:
        return 1.82;
      case XpRewardTier.none:
        return 1.0;
    }
  }

  String _formatXp(int value) {
    final raw = math.max(0, value).toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write('.');
      out.write(raw[i]);
    }
    return out.toString();
  }

  Widget _baseBadge() {
    final totalXp = widget.totalXp;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.18, -.28),
          radius: 1.05,
          colors: [Color(0xFF1D2B4D), Color(0xFF07142F)],
        ),
        border: Border.all(color: AppColors.navy, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.lime.withValues(alpha: .86),
            width: 1.35,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Lv ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '$_safeLevel',
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
            if (widget.showXp && totalXp != null) ...[
              const SizedBox(height: 1),
              Text(
                '${_formatXp(totalXp)} XP',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 6.3,
                  height: 1,
                  letterSpacing: .1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _spriteFrame(double frameSize, int index) {
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: frameSize,
          maxWidth: frameSize,
          minHeight: frameSize * _spriteCount,
          maxHeight: frameSize * _spriteCount,
          child: Transform.translate(
            offset: Offset(0, -index * frameSize),
            child: Image.asset(
              _spritePath,
              width: frameSize,
              height: frameSize * _spriteCount,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedFrame(double frameSize, int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        var scale = 1.0;
        var angle = 0.0;
        var y = 0.0;

        if (_tier == XpRewardTier.neonFrame) {
          scale = .985 + (.025 * t);
        } else if (_tier == XpRewardTier.animatedStar) {
          scale = .97 + (.045 * t);
          angle = (-.035) + (.07 * t);
        } else if (_tier == XpRewardTier.risingBadge) {
          y = -2.2 * t;
        } else if (_tier == XpRewardTier.eliteBadge) {
          scale = .985 + (.025 * t);
        }

        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: _spriteFrame(frameSize, index),
    );
  }

  Widget _glow(double outerSize) {
    if (_tier != XpRewardTier.neonFrame &&
        _tier != XpRewardTier.animatedStar &&
        _tier != XpRewardTier.eliteBadge) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: outerSize * .76,
          height: outerSize * .76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withValues(alpha: .13 + (.10 * t)),
                blurRadius: 12 + (8 * t),
                spreadRadius: 2 + (2 * t),
              ),
              if (_tier != XpRewardTier.neonFrame)
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: .09 + (.08 * t)),
                  blurRadius: 18 + (8 * t),
                  spreadRadius: 1 + (2 * t),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _spriteIndex;
    final outerSize = widget.size * _frameScale;
    final content = SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _glow(outerSize),
          _baseBadge(),
          if (index != null) _animatedFrame(outerSize, index),
        ],
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      label:
          'Seviye $_safeLevel. ${xpRewardNameForLevel(_safeLevel)}${widget.totalXp == null ? '' : ', ${_formatXp(widget.totalXp!)} XP'}.',
      child: widget.onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                child: content,
              ),
            ),
    );
  }
}

class EliteRoomAura extends StatefulWidget {
  const EliteRoomAura({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<EliteRoomAura> createState() => _EliteRoomAuraState();
}

class _EliteRoomAuraState extends State<EliteRoomAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_controller.value);
                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Color.lerp(AppColors.lime, AppColors.blue, t)!
                          .withValues(alpha: .18 + (.10 * t)),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lime.withValues(alpha: .05 + (.04 * t)),
                        blurRadius: 16 + (8 * t),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

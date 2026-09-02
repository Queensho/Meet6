import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/meet6_3d_avatar.dart';
import '../../widgets/phone_frame.dart';
import '../matches/match_success_screen.dart';

class RoomSelectionScreen extends StatefulWidget {
  const RoomSelectionScreen({super.key, this.profileName = ''});

  final String profileName;

  @override
  State<RoomSelectionScreen> createState() => _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends State<RoomSelectionScreen> {
  static const participants = [
    _Participant('A', 'Aslı', Alignment(-.70, -.70)),
    _Participant('M', 'Mert', Alignment(.72, -.72)),
    _Participant('E', 'Ece', Alignment(-.78, .48)),
    _Participant('B', 'Bora', Alignment(.76, .48)),
    _Participant('S', 'Selin', Alignment(0, -.92)),
  ];

  int? selectedIndex;
  bool submitting = false;

  Future<void> _submit() async {
    if (selectedIndex == null || submitting) return;
    setState(() => submitting = true);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final participant = participants[selectedIndex!];

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MatchSuccessScreen(
          profileName: widget.profileName,
          matchName: participant.name,
          matchInitial: participant.initial,
          avatarAlignment: participant.alignment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '6',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            color: dark ? AppColors.lime : AppColors.blue,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Gizli seçim',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'Kiminle devam\netmek istersin?',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 33,
                    height: 1.02,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Sohbette en çok bağ kurduğun 1 kişiyi seç. Seçimin yalnızca karşılıklıysa açıklanır.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.lime.withOpacity(.13)
                        : AppColors.lime.withOpacity(.22),
                    borderRadius: BorderRadius.circular(14),
                    border: dark
                        ? Border.all(color: AppColors.lime.withOpacity(.24))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        color: dark ? AppColors.lime : AppColors.navy,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Test modu: mock kullanıcıların seçimleri hazır.',
                          style: TextStyle(
                            color: dark ? scheme.onSurface : AppColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.02,
                    ),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      final selected = selectedIndex == index;

                      final cardColor = selected
                          ? AppColors.lime
                          : (dark ? scheme.surface : Colors.white);
                      final nameColor = selected
                          ? AppColors.navy
                          : scheme.onSurface;

                      return InkWell(
                        onTap: submitting
                            ? null
                            : () => setState(() => selectedIndex = index),
                        borderRadius: BorderRadius.circular(23),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: selected
                                  ? AppColors.navy
                                  : scheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                            boxShadow: dark
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x0C111B4C),
                                      blurRadius: 16,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Meet63DAvatar(
                                      alignment: participant.alignment,
                                      size: 76,
                                      borderWidth: 3.5,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      participant.name,
                                      style: TextStyle(
                                        color: nameColor,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.navy,
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed:
                        selectedIndex == null || submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          dark ? AppColors.lime : AppColors.navy,
                      disabledBackgroundColor: dark
                          ? scheme.surfaceContainerHigh
                          : AppColors.navy.withOpacity(.18),
                      foregroundColor:
                          dark ? AppColors.navy : Colors.white,
                      disabledForegroundColor: scheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: submitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: dark
                                  ? AppColors.navy
                                  : AppColors.lime,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Seçimimi kaydet',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 9),
                              Icon(Icons.lock_rounded, size: 20),
                            ],
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

class _Participant {
  const _Participant(
    this.initial,
    this.name,
    this.alignment,
  );

  final String initial;
  final String name;
  final Alignment alignment;
}

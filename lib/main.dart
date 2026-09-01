import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const Meet6App());
}

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  static const Color bg = Color(0xFF07111F);
  static const Color surface = Color(0xFF111D2E);
  static const Color teal = Color(0xFF19C3C8);
  static const Color coral = Color(0xFFFF6B5E);
  static const Color text = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: teal,
          secondary: coral,
          surface: surface,
        ),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class PhoneShell extends StatelessWidget {
  const PhoneShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07111F), Color(0xFF0B2234)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneShell(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Meet6App.teal.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Meet6App.teal.withOpacity(.4)),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Meet6App.coral),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Meet6',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      _CircleIcon(icon: Icons.notifications_none_rounded),
                    ],
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'Canlı tanışma\nodaları',
                    style: TextStyle(
                      fontSize: 38,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '6 kişi, 15 dakika, gerçek sohbet.\nBelki de doğru eşleşme.',
                    style: TextStyle(color: Meet6App.muted, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Yaklaşan oda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Meet6App.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Meet6App.coral.withOpacity(.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'ÖNE ÇIKAN ODA',
                                style: TextStyle(
                                  color: Meet6App.coral,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.more_horiz_rounded, color: Meet6App.muted),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Oda 24',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                              ),
                            ),
                            _TimeChip(),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _InfoRow(icon: Icons.groups_rounded, text: '6 kişilik oda'),
                        const SizedBox(height: 10),
                        const _InfoRow(icon: Icons.timer_outlined, text: '15 dk serbest sohbet'),
                        const SizedBox(height: 10),
                        const _InfoRow(
                          icon: Icons.favorite_border_rounded,
                          text: 'Karşılıklı seçim = özel sohbet',
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(child: _AvatarStack()),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.05),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                '4/6 kişi hazır',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RoomScreen()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Meet6App.teal,
                        foregroundColor: const Color(0xFF031419),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Draft'a Katıl",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _BottomBar(),
        ],
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  int seconds = 15 * 60;
  Timer? timer;
  bool extensionAsked = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (seconds > 0) {
        setState(() => seconds--);
        if (seconds == 60 && !extensionAsked) {
          extensionAsked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _showExtendDialog());
        }
      } else {
        timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String get timeText {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showExtendDialog() async {
    final extend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Meet6App.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Sohbeti 5 dakika uzatmak ister misin?'),
        content: const Text(
          'Oylar gizli. Çoğunluk uzatırsa oda 5 dakika daha devam eder.',
          style: TextStyle(color: Meet6App.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bitir')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('+5 dk uzat'),
          ),
        ],
      ),
    );
    if (extend == true && mounted) {
      setState(() => seconds += 5 * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhoneShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Oda 24', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('6 kişi aktif', style: TextStyle(color: Meet6App.teal, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: seconds <= 60
                        ? Meet6App.coral.withOpacity(.16)
                        : Meet6App.teal.withOpacity(.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    timeText,
                    style: TextStyle(
                      color: seconds <= 60 ? Meet6App.coral : Meet6App.teal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _RoomAvatars(),
          ),
          const Divider(height: 26, color: Color(0x1FFFFFFF)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: const [
                _Message(name: 'Aylin', text: 'Herkese selam 👋 Kahveci olan var mı?', mine: false),
                _Message(name: 'Mert', text: 'Ben varım 😄 Flat white ekibiyim.', mine: false),
                _Message(name: 'Sen', text: 'Filtre kahve + sahil yürüyüşü bence net.', mine: true),
                _Message(name: 'Zeynep', text: 'Sahil kısmına +1 🌊', mine: false),
                _Message(name: 'Can', text: 'Hafta sonu planı olan var mı?', mine: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Mesajını yaz...',
                      hintStyle: const TextStyle(color: Meet6App.muted),
                      filled: true,
                      fillColor: Meet6App.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Meet6App.teal,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF031419)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Meet6App.text),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Meet6App.teal.withOpacity(.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 14, color: Meet6App.teal),
          SizedBox(width: 6),
          Text('Bugün 21:00', style: TextStyle(color: Meet6App.teal, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Meet6App.muted, size: 20),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Meet6App.text, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF54A0FF), Color(0xFFFF9F43), Color(0xFFEE5253), Color(0xFF10AC84)];
    return SizedBox(
      height: 38,
      child: Stack(
        children: List.generate(colors.length, (index) {
          return Positioned(
            left: index * 25,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors[index],
                shape: BoxShape.circle,
                border: Border.all(color: Meet6App.surface, width: 3),
              ),
              child: const Icon(Icons.person_rounded, size: 21, color: Colors.white),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1625),
        border: Border(top: BorderSide(color: Color(0x16FFFFFF))),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.grid_view_rounded, label: 'Odalar', active: true),
          _NavItem(icon: Icons.favorite_border_rounded, label: 'Eşleşmeler'),
          _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Sohbetler'),
          _NavItem(icon: Icons.person_outline_rounded, label: 'Profil'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Meet6App.teal : Meet6App.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RoomAvatars extends StatelessWidget {
  const _RoomAvatars();

  @override
  Widget build(BuildContext context) {
    const names = ['Aylin', 'Mert', 'Zeynep', 'Can', 'Elif', 'Sen'];
    const colors = [
      Color(0xFF54A0FF),
      Color(0xFFFF9F43),
      Color(0xFFEE5253),
      Color(0xFF10AC84),
      Color(0xFFA55EEA),
      Meet6App.teal,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(names.length, (i) {
        return Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: Meet6App.teal.withOpacity(.28), width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(names[i], style: const TextStyle(fontSize: 10, color: Meet6App.muted)),
          ],
        );
      }),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.name, required this.text, required this.mine});

  final String name;
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 315),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: mine ? Meet6App.teal.withOpacity(.18) : Meet6App.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? Meet6App.teal.withOpacity(.24) : Colors.white.withOpacity(.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                color: mine ? Meet6App.teal : Meet6App.coral,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

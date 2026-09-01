import 'package:flutter/material.dart';

void main() => runApp(const Meet6App());

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF747474);
  static const line = Color(0xFFE8E8E8);
  static const soft = Color(0xFFF7F7F7);
  static const accent = Color(0xFF6F5AE8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6 UX',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: soft,
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.bottom,
    this.showBack = false,
    this.onBack,
  });

  final Widget child;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: IconButton(
                        onPressed: onBack ?? () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                Expanded(child: child),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    child: bottom!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Meet6App.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE4E4E4),
          disabledForegroundColor: const Color(0xFF999999),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      bottom: Column(
        children: [
          PrimaryButton(
            label: 'Başla',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PhoneScreen()),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PhoneScreen()),
            ),
            child: const Text('Zaten hesabım var  →  Giriş yap'),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('meet6', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
            const Spacer(),
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Meet6App.soft,
                  borderRadius: BorderRadius.circular(120),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('6', style: TextStyle(fontSize: 86, fontWeight: FontWeight.w900)),
                    for (int i = 0; i < 6; i++) _PersonDot(index: i),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '6 kişi.\n15 dakika.\nGerçek sohbet.',
              style: TextStyle(fontSize: 42, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profil kaydırmak yerine canlı bir odaya gir, insanları konuşurken tanı.',
              style: TextStyle(color: Meet6App.muted, fontSize: 17, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonDot extends StatelessWidget {
  const _PersonDot({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final positions = <Alignment>[
      const Alignment(0, -1.05),
      const Alignment(.92, -.48),
      const Alignment(.92, .48),
      const Alignment(0, 1.05),
      const Alignment(-.92, .48),
      const Alignment(-.92, -.48),
    ];
    return Align(
      alignment: positions[index],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Meet6App.line),
        ),
        child: const Icon(Icons.person_rounded, size: 25, color: Meet6App.muted),
      ),
    );
  }
}

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final enabled = controller.text.replaceAll(' ', '').length >= 10;
    return PageFrame(
      showBack: true,
      bottom: PrimaryButton(
        label: 'Devam et',
        onPressed: enabled
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OtpScreen()))
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
        children: [
          const _StepTitle(
            title: 'Telefon numaran nedir?',
            subtitle: 'Hesabını oluşturmak ve güvenli tutmak için numaranı doğrulayacağız.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Meet6App.soft,
                  border: Border.all(color: Meet6App.line),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: Text('🇹🇷  +90', style: TextStyle(fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '5XX XXX XX XX'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: Meet6App.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text('Numaran diğer kullanıcılara gösterilmez.', style: TextStyle(color: Meet6App.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final enabled = controller.text.length == 6;
    return PageFrame(
      showBack: true,
      bottom: PrimaryButton(
        label: 'Doğrula',
        onPressed: enabled
            ? () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileWizard()),
                )
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
        children: [
          const _StepTitle(
            title: '6 haneli kodu gir',
            subtitle: '+90 5XX XXX XX XX numarasına gönderdiğimiz kodu yaz.',
          ),
          const SizedBox(height: 30),
          TextField(
            controller: controller,
            maxLength: 6,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w800),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Numarayı değiştir')),
              TextButton(onPressed: () {}, child: const Text('Kodu tekrar gönder')),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Prototip: herhangi bir 6 haneli sayı ile devam edebilirsin.',
            style: TextStyle(color: Meet6App.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ProfileWizard extends StatefulWidget {
  const ProfileWizard({super.key});
  @override
  State<ProfileWizard> createState() => _ProfileWizardState();
}

class _ProfileWizardState extends State<ProfileWizard> {
  int step = 0;
  String name = '';
  String birth = '';
  String gender = '';
  String interest = '';
  String distance = '25 km';
  String intent = '';
  String bio = '';
  int photos = 0;

  final nameController = TextEditingController();
  final birthController = TextEditingController();
  final bioController = TextEditingController();

  static const total = 8;

  bool get canContinue {
    switch (step) {
      case 0:
        return nameController.text.trim().length >= 2;
      case 1:
        return birthController.text.trim().length >= 8;
      case 2:
        return gender.isNotEmpty;
      case 3:
        return interest.isNotEmpty;
      case 4:
        return distance.isNotEmpty;
      case 5:
        return photos >= 2;
      case 6:
        return intent.isNotEmpty;
      default:
        return true;
    }
  }

  void next() {
    name = nameController.text.trim();
    birth = birthController.text.trim();
    bio = bioController.text.trim();
    if (step < total - 1) {
      setState(() => step++);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(name: name.isEmpty ? 'Tayfun' : name)),
        (_) => false,
      );
    }
  }

  void back() {
    if (step == 0) {
      Navigator.maybePop(context);
    } else {
      setState(() => step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      showBack: true,
      onBack: back,
      bottom: PrimaryButton(
        label: step == total - 1 ? 'Meet6’ya gir' : 'Devam',
        onPressed: canContinue ? next : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (step + 1) / total,
                      minHeight: 5,
                      backgroundColor: Meet6App.line,
                      color: Meet6App.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${step + 1}/$total', style: const TextStyle(color: Meet6App.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(child: _buildStep()),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case 0:
        return _OnboardingPage(
          title: 'Sana nasıl hitap edelim?',
          subtitle: 'Profilinde diğer insanların göreceği adın.',
          child: TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Adın'),
          ),
        );
      case 1:
        return _OnboardingPage(
          title: 'Doğum tarihin nedir?',
          subtitle: 'Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.',
          child: TextField(
            controller: birthController,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'GG / AA / YYYY'),
          ),
        );
      case 2:
        return _OnboardingPage(
          title: 'Kendini nasıl tanımlıyorsun?',
          subtitle: 'Bu bilgiyi daha sonra değiştirebilirsin.',
          child: _ChoiceList(
            values: const ['Kadın', 'Erkek', 'Non-binary', 'Diğer', 'Belirtmek istemiyorum'],
            selected: gender,
            onSelected: (v) => setState(() => gender = v),
          ),
        );
      case 3:
        return _OnboardingPage(
          title: 'Kimlerle tanışmak istersin?',
          subtitle: 'Sana uygun oda oluştururken bunu kullanacağız.',
          child: _ChoiceList(
            values: const ['Kadınlar', 'Erkekler', 'Herkes'],
            selected: interest,
            onSelected: (v) => setState(() => interest = v),
          ),
        );
      case 4:
        return _OnboardingPage(
          title: 'Ne kadar yakından?',
          subtitle: 'Konumunu sadece uygun insanları aynı odaya getirmek için kullanırız.',
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Meet6App.soft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Meet6App.line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on_outlined),
                    SizedBox(width: 12),
                    Expanded(child: Text('Konumumu kullan', style: TextStyle(fontWeight: FontWeight.w800))),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text('Maksimum mesafe', style: TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['10 km', '25 km', '50 km', 'Fark etmez'].map((v) {
                  return ChoiceChip(
                    label: Text(v),
                    selected: distance == v,
                    onSelected: (_) => setState(() => distance = v),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      case 5:
        return _OnboardingPage(
          title: 'Seni gösteren fotoğraflar ekle',
          subtitle: 'Başlamak için en az 2 fotoğraf yeterli.',
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .78,
            ),
            itemCount: 6,
            itemBuilder: (_, i) {
              final filled = i < photos;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  if (!filled && photos < 6) photos++;
                  else if (filled && photos > 0) photos--;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: filled ? const Color(0xFFECECEC) : Meet6App.soft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: filled ? Meet6App.ink : Meet6App.line),
                  ),
                  child: Center(
                    child: filled
                        ? const Icon(Icons.person_rounded, size: 42)
                        : const Icon(Icons.add_rounded, color: Meet6App.muted),
                  ),
                ),
              );
            },
          ),
        );
      case 6:
        return _OnboardingPage(
          title: 'Burada ne arıyorsun?',
          subtitle: 'İnsanları aynı beklentiye sahip odalara yerleştirmeye yardımcı olur.',
          child: Column(
            children: [
              _ChoiceList(
                values: const ['Ciddi ilişki', 'Yeni insanlarla tanışmak', 'Akışına bırakıyorum', 'Emin değilim'],
                selected: intent,
                onSelected: (v) => setState(() => intent = v),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: bioController,
                maxLength: 120,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Bir cümlede sen (isteğe bağlı)'),
              ),
            ],
          ),
        );
      default:
        return _OnboardingPage(
          title: 'Profilin hazır 🎉',
          subtitle: 'Artık profil gezmek yerine ilk Meet6 odana katılabilirsin.',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Meet6App.soft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Meet6App.line),
            ),
            child: Column(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, size: 46),
                ),
                const SizedBox(height: 14),
                Text(nameController.text.isEmpty ? 'Adın' : nameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(intent.isEmpty ? 'Tanışmaya hazırsın' : intent, style: const TextStyle(color: Meet6App.muted)),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_2_outlined, size: 19),
                    SizedBox(width: 8),
                    Text('Sıradaki adım: 6 kişilik canlı oda'),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      children: [
        _StepTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 28),
        child,
      ],
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({required this.values, required this.selected, required this.onSelected});
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: values.map((v) {
        final active = selected == v;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelected(v),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              decoration: BoxDecoration(
                color: active ? Meet6App.ink : Meet6App.soft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? Meet6App.ink : Meet6App.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(v, style: TextStyle(color: active ? Colors.white : Meet6App.ink, fontWeight: FontWeight.w800)),
                  ),
                  Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined, color: active ? Colors.white : Meet6App.muted),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      Row(
                        children: [
                          const Text('meet6', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                          const Spacer(),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                          const CircleAvatar(backgroundColor: Meet6App.soft, child: Icon(Icons.person_rounded, color: Meet6App.ink)),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Text('Merhaba $name 👋', style: const TextStyle(color: Meet6App.muted, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(
                        'Tanışmaya\nhazır mısın?',
                        style: TextStyle(fontSize: 40, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Meet6App.soft,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Meet6App.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                _MiniStat(icon: Icons.groups_2_outlined, text: '6 kişi'),
                                SizedBox(width: 10),
                                _MiniStat(icon: Icons.timer_outlined, text: '15 dakika'),
                              ],
                            ),
                            const SizedBox(height: 22),
                            const Text('Meet6 Odası', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text(
                              'Sistem sana uygun 5 kişiyi bulur. 15 dakika serbestçe konuşursunuz. Finalde herkes gizlice 1 kişiyi seçer.',
                              style: TextStyle(color: Meet6App.muted, fontSize: 15, height: 1.45),
                            ),
                            const SizedBox(height: 18),
                            const Row(
                              children: [
                                Icon(Icons.visibility_off_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Seçimler gizli', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.favorite_border_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Karşılıklı seçim → özel sohbet', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 22),
                            PrimaryButton(
                              label: 'Odaya Katıl',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const QueueScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Meet6App.line),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Meet6’da profil kaydırma yok. Ana deneyim canlı odalara katılmak.'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _BottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  int ready = 3;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      showBack: true,
      bottom: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: const Text('Kuyruktan çık'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
        child: Column(
          children: [
            const Text('Seni uygun odaya\nyerleştiriyoruz', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('$ready / 6 kişi hazır', style: const TextStyle(color: Meet6App.muted, fontSize: 16)),
            const Spacer(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < ready;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 78,
                  height: 98,
                  decoration: BoxDecoration(
                    color: filled ? const Color(0xFFECECEC) : Meet6App.soft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: filled ? Meet6App.ink : Meet6App.line),
                  ),
                  child: Icon(filled ? Icons.person_rounded : Icons.add_rounded, color: filled ? Meet6App.ink : Meet6App.muted),
                );
              }),
            ),
            const Spacer(),
            Text('${6 - ready} kişi daha bekleniyor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: ready < 6 ? () => setState(() => ready++) : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(ready < 6 ? 'Prototip: bir kişi daha ekle' : 'Oda hazır — sonraki UX aşaması'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
      child: Row(children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(text, style: const TextStyle(fontWeight: FontWeight.w800))]),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 12),
        Text(subtitle, style: const TextStyle(color: Meet6App.muted, fontSize: 16, height: 1.45)),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Meet6App.line))),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Ana Sayfa', active: true),
          _NavItem(icon: Icons.favorite_border_rounded, label: 'Eşleşmeler'),
          _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Mesajlar'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Meet6App.ink : Meet6App.muted),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? Meet6App.ink : Meet6App.muted)),
        ],
      ),
    );
  }
}

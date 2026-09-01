import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const Meet6App());

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  static const background = Color(0xFFF8F9FD);
  static const navy = Color(0xFF111B4C);
  static const blue = Color(0xFF2F5BFF);
  static const lime = Color(0xFFD8FF32);
  static const muted = Color(0xFF9298B0);
  static const border = Color(0xFFD9DDEA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();

  bool get canContinue =>
      phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 10;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final h = phone.maxHeight;
            final compact = w < 375;
            final veryCompact = w < 340;
            final horizontal = (w * .045).clamp(14.0, 19.0);
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                8,
                horizontal,
                keyboard + 4,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 12).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Brand(width: w),
                    SizedBox(height: compact ? 8 : 10),
                    _Headline(width: w),
                    const SizedBox(height: 3),
                    Text(
                      '6 kişilik çevrende yeni insanlarla\nsohbet etmeye başla.',
                      style: TextStyle(
                        color: Meet6App.muted,
                        fontSize: (w * .033).clamp(11.8, 13.5),
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 5),
                    _HeroPng(width: w),
                    SizedBox(height: compact ? 5 : 8),
                    _BottomLoginArea(
                      compact: compact,
                      veryCompact: veryCompact,
                      canContinue: canContinue,
                      phoneController: phoneController,
                      onChanged: () => setState(() {}),
                      onContinue: () {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OtpScreen(
                              phoneNumber: phoneController.text,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final controllers = List.generate(6, (_) => TextEditingController());
  final focusNodes = List.generate(6, (_) => FocusNode());
  Timer? timer;
  int secondsLeft = 45;

  bool get complete => controllers.every((c) => c.text.length == 1);

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    secondsLeft = 45;
    if (mounted) setState(() {});
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (secondsLeft <= 1) {
        t.cancel();
        setState(() => secondsLeft = 0);
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (complete) FocusScope.of(context).unfocus();
  }

  String get formattedPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return '+90 ${widget.phoneNumber}';
    final d = digits.substring(digits.length - 10);
    return '+90 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8, 10)}';
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final h = phone.maxHeight;
            final compact = w < 375;
            final horizontal = (w * .055).clamp(18.0, 24.0);
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                keyboard + 10,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 22).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BackButton(onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        const _MiniBrand(),
                      ],
                    ),
                    SizedBox(height: compact ? 38 : 52),
                    Center(
                      child: Container(
                        width: compact ? 102 : 116,
                        height: compact ? 102 : 116,
                        decoration: const BoxDecoration(
                          color: Meet6App.lime,
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: Meet6App.navy,
                              size: compact ? 44 : 50,
                            ),
                            Positioned(
                              right: compact ? 17 : 19,
                              bottom: compact ? 18 : 20,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Meet6App.blue,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 28 : 34),
                    Text(
                      'Telefonunu doğrula',
                      style: TextStyle(
                        color: Meet6App.navy,
                        fontSize: (w * .075).clamp(25.0, 31.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '$formattedPhone numarasına gönderdiğimiz\n6 haneli kodu gir.',
                      style: TextStyle(
                        color: Meet6App.muted,
                        fontSize: (w * .036).clamp(13.0, 15.0),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Numarayı değiştir',
                        style: TextStyle(
                          color: Meet6App.blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 22 : 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final boxWidth =
                            ((w - horizontal * 2 - 35) / 6).clamp(43.0, 52.0);
                        return SizedBox(
                          width: boxWidth,
                          height: compact ? 54 : 60,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) =>
                                _onDigitChanged(index, value),
                            style: TextStyle(
                              color: Meet6App.navy,
                              fontSize: compact ? 21 : 23,
                              fontWeight: FontWeight.w900,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withOpacity(.9),
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Meet6App.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Meet6App.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: compact ? 18 : 22),
                    Center(
                      child: secondsLeft > 0
                          ? Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  color: Meet6App.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Kodu tekrar gönderebilirsin  ',
                                  ),
                                  TextSpan(
                                    text:
                                        '00:${secondsLeft.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Meet6App.navy,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : TextButton(
                              onPressed: _startTimer,
                              child: const Text(
                                'Kodu tekrar gönder',
                                style: TextStyle(
                                  color: Meet6App.blue,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: compact ? 30 : 42),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 54 : 58,
                      child: FilledButton(
                        onPressed: complete ? _verify : null,
                        style: _primaryButtonStyle(radius: 18),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Doğrula',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 9),
                            Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final birthDateController = TextEditingController();
  final bioController = TextEditingController();
  final promptController = TextEditingController();

  int step = 1;
  bool photoSelected = false;
  String? gender;

  String? lookingFor;
  RangeValues ageRange = const RangeValues(22, 35);
  String city = 'İstanbul';
  double distance = 25;
  String? intention;

  final extraPhotos = List<bool>.filled(4, false);
  final Set<String> interests = {};
  String prompt = 'Benimle iyi anlaşmanın yolu...';

  static const interestOptions = [
    'Kahve',
    'Müzik',
    'Seyahat',
    'Spor',
    'Sinema',
    'Yemek',
    'Kitap',
    'Oyun',
    'Doğa',
    'Fotoğraf',
    'Dans',
    'Teknoloji',
  ];

  static const promptOptions = [
    'Benimle iyi anlaşmanın yolu...',
    'İlk buluşmada beni etkileyen şey...',
    'Beni güldürmenin en kolay yolu...',
  ];

  bool get step1Valid =>
      photoSelected &&
      nameController.text.trim().length >= 2 &&
      birthDateController.text.isNotEmpty &&
      gender != null;

  bool get step2Valid => lookingFor != null && intention != null;

  bool get step3Valid =>
      bioController.text.trim().length >= 10 &&
      interests.length >= 3 &&
      promptController.text.trim().length >= 3;

  bool get currentStepValid {
    if (step == 1) return step1Valid;
    if (step == 2) return step2Valid;
    return step3Valid;
  }

  @override
  void dispose() {
    nameController.dispose();
    birthDateController.dispose();
    bioController.dispose();
    promptController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(latest.year - 7, latest.month, latest.day),
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Doğum tarihini seç',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (date == null || !mounted) return;
    birthDateController.text =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    setState(() {});
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (step > 1) {
      setState(() => step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (!currentStepValid) return;
    FocusScope.of(context).unfocus();
    if (step < 3) {
      setState(() => step++);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileReadyScreen(name: nameController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final h = phone.maxHeight;
            final compact = w < 375;
            final horizontal = (w * .055).clamp(18.0, 24.0);
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                keyboard + 12,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (h - 24).clamp(0.0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BackButton(onTap: _back),
                        const Spacer(),
                        const _MiniBrand(),
                      ],
                    ),
                    SizedBox(height: compact ? 20 : 26),
                    _StepProgress(step: step),
                    SizedBox(height: compact ? 18 : 24),
                    if (step == 1)
                      _buildStepOne(w, compact)
                    else if (step == 2)
                      _buildStepTwo(w, compact)
                    else
                      _buildStepThree(w, compact),
                    SizedBox(height: compact ? 24 : 30),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 52 : 56,
                      child: FilledButton(
                        onPressed: currentStepValid ? _next : null,
                        style: _primaryButtonStyle(radius: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              step == 3 ? 'Profili tamamla' : 'Devam et',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Icon(
                              step == 3
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepOne(double w, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeading(
          width: w,
          title: 'Seni biraz\ntanıyalım',
          subtitle: 'Diğer kişiler seni odada bu bilgilerle görecek.',
        ),
        SizedBox(height: compact ? 18 : 24),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => photoSelected = !photoSelected),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: compact ? 112 : 124,
                  height: compact ? 112 : 124,
                  decoration: BoxDecoration(
                    color: photoSelected
                        ? Meet6App.lime
                        : const Color(0xFFF0F2F8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: photoSelected ? Meet6App.navy : Meet6App.border,
                      width: photoSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    photoSelected
                        ? Icons.person_rounded
                        : Icons.add_a_photo_rounded,
                    color: photoSelected ? Meet6App.navy : Meet6App.muted,
                    size: compact ? 42 : 47,
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 3,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Meet6App.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Meet6App.background,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            photoSelected ? 'Fotoğraf eklendi' : 'Profil fotoğrafı ekle',
            style: TextStyle(
              color: photoSelected ? Meet6App.blue : Meet6App.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: compact ? 20 : 26),
        const _FieldLabel('Adın'),
        const SizedBox(height: 7),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'Sana nasıl hitap edelim?',
            icon: Icons.person_outline_rounded,
          ),
        ),
        SizedBox(height: compact ? 14 : 17),
        const _FieldLabel('Doğum tarihi'),
        const SizedBox(height: 7),
        TextField(
          controller: birthDateController,
          readOnly: true,
          onTap: _pickBirthDate,
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'GG.AA.YYYY',
            icon: Icons.calendar_today_outlined,
            suffix: Icons.keyboard_arrow_down_rounded,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Meet6 yalnızca 18 yaş ve üzeri kullanıcılar içindir.',
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        const _FieldLabel('Cinsiyet'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoicePill(
              label: 'Kadın',
              selected: gender == 'Kadın',
              onTap: () => setState(() => gender = 'Kadın'),
            ),
            _ChoicePill(
              label: 'Erkek',
              selected: gender == 'Erkek',
              onTap: () => setState(() => gender = 'Erkek'),
            ),
            _ChoicePill(
              label: 'Diğer',
              selected: gender == 'Diğer',
              onTap: () => setState(() => gender = 'Diğer'),
            ),
            _ChoicePill(
              label: 'Belirtmek istemiyorum',
              selected: gender == 'Belirtmek istemiyorum',
              onTap: () =>
                  setState(() => gender = 'Belirtmek istemiyorum'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwo(double w, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeading(
          width: w,
          title: 'Kimlerle tanışmak\nistiyorsun?',
          subtitle:
              'Meet6 odalarını temel tercihlerini dikkate alarak oluşturur.',
        ),
        SizedBox(height: compact ? 22 : 28),
        const _FieldLabel('Kimi görmek istersin?'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Kadınlar', 'Erkekler', 'Herkes'].map((item) {
            return _ChoicePill(
              label: item,
              selected: lookingFor == item,
              onTap: () => setState(() => lookingFor = item),
            );
          }).toList(),
        ),
        SizedBox(height: compact ? 20 : 24),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Yaş aralığı')),
            Text(
              '${ageRange.start.round()} - ${ageRange.end.round()}',
              style: const TextStyle(
                color: Meet6App.blue,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: ageRange,
          min: 18,
          max: 60,
          divisions: 42,
          labels: RangeLabels(
            ageRange.start.round().toString(),
            ageRange.end.round().toString(),
          ),
          activeColor: Meet6App.blue,
          inactiveColor: Meet6App.border,
          onChanged: (value) => setState(() => ageRange = value),
        ),
        SizedBox(height: compact ? 8 : 12),
        const _FieldLabel('Şehir'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: city,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Meet6App.muted,
          ),
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'Şehrini seç',
            icon: Icons.location_on_outlined,
          ),
          items: const [
            'İstanbul',
            'Ankara',
            'İzmir',
            'Bursa',
            'Antalya',
            'Diğer',
          ].map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => city = value);
          },
        ),
        SizedBox(height: compact ? 18 : 22),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Maksimum mesafe')),
            Text(
              '${distance.round()} km',
              style: const TextStyle(
                color: Meet6App.blue,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: distance,
          min: 5,
          max: 100,
          divisions: 19,
          label: '${distance.round()} km',
          activeColor: Meet6App.blue,
          inactiveColor: Meet6App.border,
          onChanged: (value) => setState(() => distance = value),
        ),
        SizedBox(height: compact ? 10 : 14),
        const _FieldLabel('Tanışma amacı'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Ciddi ilişki',
            'Flört',
            'Yeni insanlarla tanışma',
            'Akışına bırakıyorum',
          ].map((item) {
            return _ChoicePill(
              label: item,
              selected: intention == item,
              onTap: () => setState(() => intention = item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepThree(double w, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeading(
          width: w,
          title: 'Profiline biraz\nkarakter kat',
          subtitle:
              'Odadaki insanların seni daha kolay tanımasına yardımcı ol.',
        ),
        SizedBox(height: compact ? 20 : 26),
        const _FieldLabel('Ek fotoğraflar'),
        const SizedBox(height: 8),
        Row(
          children: List.generate(extraPhotos.length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == extraPhotos.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () => setState(
                    () => extraPhotos[index] = !extraPhotos[index],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: compact ? 76 : 86,
                    decoration: BoxDecoration(
                      color: extraPhotos[index]
                          ? Meet6App.lime
                          : Colors.white.withOpacity(.82),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: extraPhotos[index]
                            ? Meet6App.navy
                            : Meet6App.border,
                        width: extraPhotos[index] ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      extraPhotos[index]
                          ? Icons.person_rounded
                          : Icons.add_photo_alternate_outlined,
                      color: extraPhotos[index]
                          ? Meet6App.navy
                          : Meet6App.muted,
                      size: 26,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        const Text(
          'İstersen şimdi ekleyebilir, daha sonra değiştirebilirsin.',
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 18 : 22),
        const _FieldLabel('Kısaca sen'),
        const SizedBox(height: 7),
        TextField(
          controller: bioController,
          maxLength: 120,
          minLines: 3,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'Kendinden birkaç cümleyle bahset...',
            icon: Icons.edit_note_rounded,
          ).copyWith(alignLabelWithHint: true),
        ),
        SizedBox(height: compact ? 12 : 16),
        Row(
          children: [
            const Expanded(child: _FieldLabel('İlgi alanların')),
            Text(
              '${interests.length}/5',
              style: const TextStyle(
                color: Meet6App.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: interestOptions.map((item) {
            final selected = interests.contains(item);
            return _ChoicePill(
              label: item,
              selected: selected,
              compact: true,
              onTap: () {
                setState(() {
                  if (selected) {
                    interests.remove(item);
                  } else if (interests.length < 5) {
                    interests.add(item);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        const Text(
          'En az 3, en fazla 5 ilgi alanı seç.',
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 18 : 22),
        const _FieldLabel('Profil sorusu'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: prompt,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Meet6App.muted,
          ),
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'Bir soru seç',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          items: promptOptions.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => prompt = value);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: promptController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hint: 'Cevabını yaz...',
            icon: Icons.auto_awesome_outlined,
          ),
        ),
      ],
    );
  }
}

class ProfileReadyScreen extends StatelessWidget {
  const ProfileReadyScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PhoneFrame(
        child: LayoutBuilder(
          builder: (context, phone) {
            final w = phone.maxWidth;
            final compact = w < 375;
            final horizontal = (w * .07).clamp(22.0, 28.0);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _MiniBrand(),
                  ),
                  const Spacer(),
                  Container(
                    width: compact ? 126 : 144,
                    height: compact ? 126 : 144,
                    decoration: const BoxDecoration(
                      color: Meet6App.lime,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Meet6App.navy,
                      size: 64,
                    ),
                  ),
                  SizedBox(height: compact ? 28 : 34),
                  Text(
                    'Profilin hazır, $name!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Meet6App.navy,
                      fontSize: (w * .082).clamp(28.0, 34.0),
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Artık sana uygun 6 kişilik odaları keşfetmeye hazırsın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Meet6App.muted,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ana sayfa sıradaki ekran olacak'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: _primaryButtonStyle(radius: 18),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Meet6’ya başla',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 9),
                          Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (index) {
            final active = index < step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? Meet6App.blue : Meet6App.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Profil oluştur · $step/3',
          style: const TextStyle(
            color: Meet6App.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeading extends StatelessWidget {
  const _ProfileHeading({
    required this.width,
    required this.title,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Meet6App.navy,
            fontSize: (width * .085).clamp(28.0, 34.0),
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: (width * .035).clamp(12.5, 14.5),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        final desktop = viewport.maxWidth > 520;
        return Container(
          color: desktop ? const Color(0xFFEFF1F7) : Meet6App.background,
          alignment: Alignment.center,
          child: Container(
            width: desktop ? 390 : viewport.maxWidth,
            height: desktop ? 844 : viewport.maxHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Meet6App.background,
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
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: WavePainter()),
                  ),
                ),
                SafeArea(bottom: false, child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Meet6App.border),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Meet6App.navy,
        ),
      ),
    );
  }
}

class _BottomLoginArea extends StatelessWidget {
  const _BottomLoginArea({
    required this.compact,
    required this.veryCompact,
    required this.canContinue,
    required this.phoneController,
    required this.onChanged,
    required this.onContinue,
  });

  final bool compact;
  final bool veryCompact;
  final bool canContinue;
  final TextEditingController phoneController;
  final VoidCallback onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final fieldHeight = veryCompact ? 44.0 : (compact ? 47.0 : 51.0);
    final providerHeight = veryCompact ? 42.0 : (compact ? 45.0 : 48.0);
    final gap = veryCompact ? 5.0 : (compact ? 7.0 : 9.0);

    OutlineInputBorder fieldBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(height: fieldHeight, child: const _CountryCode()),
            const SizedBox(width: 7),
            Expanded(
              child: SizedBox(
                height: fieldHeight,
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    color: Meet6App.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '5XX XXX XX XX',
                    hintStyle: const TextStyle(
                      color: Color(0xFFADB1C3),
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(.84),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                    border: fieldBorder(Meet6App.border),
                    enabledBorder: fieldBorder(Meet6App.border),
                    focusedBorder: fieldBorder(Meet6App.blue, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap - 1),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Meet6App.blue, size: 15),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Numaran diğer kullanıcılara gösterilmez.',
                style: TextStyle(
                  color: Meet6App.muted,
                  fontSize: 10.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        SizedBox(
          width: double.infinity,
          height: fieldHeight,
          child: FilledButton(
            onPressed: canContinue ? onContinue : null,
            style: _primaryButtonStyle(radius: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Devam et',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 21),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        const _OrDivider(),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _ProviderButton(
                height: providerHeight,
                background: const Color(0xFFF1F3FA),
                foreground: Meet6App.navy,
                border: Meet6App.border,
                icon: const _GoogleMark(),
                label: 'Google',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProviderButton(
                height: providerHeight,
                background: Meet6App.navy,
                foreground: Colors.white,
                border: Meet6App.navy,
                icon: const Icon(
                  Icons.apple_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: 'Apple',
                onTap: () {},
              ),
            ),
          ],
        ),
        SizedBox(height: veryCompact ? 4 : 6),
        const _LegalText(),
        SizedBox(height: veryCompact ? 1 : 2),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: (width * .094).clamp(31.0, 38.0),
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
        children: const [
          TextSpan(text: 'meet', style: TextStyle(color: Meet6App.navy)),
          TextSpan(text: '6', style: TextStyle(color: Meet6App.blue)),
        ],
      ),
    );
  }
}

class _MiniBrand extends StatelessWidget {
  const _MiniBrand();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
        children: [
          TextSpan(text: 'meet', style: TextStyle(color: Meet6App.navy)),
          TextSpan(text: '6', style: TextStyle(color: Meet6App.blue)),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: (width * .057).clamp(19.5, 23.5),
          height: 1.07,
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
        ),
        children: const [
          TextSpan(
            text: 'Yeni insanlarla\n',
            style: TextStyle(color: Meet6App.navy),
          ),
          TextSpan(
            text: 'gerçek bağlantılar kur',
            style: TextStyle(color: Meet6App.blue),
          ),
        ],
      ),
    );
  }
}

class _HeroPng extends StatelessWidget {
  const _HeroPng({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (width * .62).clamp(205.0, 255.0);
    final imageWidth = (width * .86).clamp(265.0, 345.0);

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Center(
        child: Image.asset(
          'assets/images/file_000000009c248210b0e425b8f2d3e68d.png',
          width: imageWidth,
          height: heroHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Meet6App.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇹🇷', style: TextStyle(fontSize: 15)),
          SizedBox(width: 5),
          Text(
            '+90',
            style: TextStyle(
              color: Meet6App.navy,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 1),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: Meet6App.muted,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Meet6App.navy,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15,
          vertical: compact ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? Meet6App.lime : Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Meet6App.navy : Meet6App.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Meet6App.navy,
                size: 17,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Meet6App.navy,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _fieldTextStyle = TextStyle(
  color: Meet6App.navy,
  fontSize: 15,
  fontWeight: FontWeight.w800,
);

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  IconData? suffix,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFFA8ADC1),
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
    prefixIcon: Icon(icon, color: Meet6App.muted, size: 20),
    suffixIcon: suffix == null
        ? null
        : Icon(suffix, color: Meet6App.muted, size: 21),
    filled: true,
    fillColor: Colors.white.withOpacity(.86),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: border(Meet6App.border),
    focusedBorder: border(Meet6App.blue, width: 1.5),
    border: border(Meet6App.border),
  );
}

ButtonStyle _primaryButtonStyle({double radius = 18}) {
  return FilledButton.styleFrom(
    backgroundColor: Meet6App.lime,
    disabledBackgroundColor: const Color(0xFFE8F3AE),
    disabledForegroundColor: Meet6App.navy.withOpacity(.4),
    foregroundColor: Meet6App.navy,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Meet6App.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'veya',
            style: TextStyle(
              color: Meet6App.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: Meet6App.border)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.height,
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double height;
  final Color background;
  final Color foreground;
  final Color border;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: Meet6App.muted,
            fontSize: 9.7,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: 'Devam ederek '),
            TextSpan(
              text: 'Kullanım Koşulları',
              style: TextStyle(
                color: Meet6App.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: ' ve '),
            TextSpan(
              text: 'Gizlilik Politikası',
              style: TextStyle(
                color: Meet6App.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: '’nı kabul etmiş olursun.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  const WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * .06).clamp(18.0, 26.0);
    final lime = Paint()
      ..color = Meet6App.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blue = Paint()
      ..color = Meet6App.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final blob = Paint()..color = const Color(0xFFF0F1F8);

    canvas.drawCircle(
      Offset(size.width * .98, size.height * .28),
      size.width * .20,
      blob,
    );
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .53),
      size.width * .16,
      blob,
    );

    final top = Path()
      ..moveTo(size.width * .64, -10)
      ..cubicTo(
        size.width * .72,
        size.height * .02,
        size.width * .68,
        size.height * .06,
        size.width * .79,
        size.height * .09,
      )
      ..cubicTo(
        size.width * .88,
        size.height * .12,
        size.width * .82,
        size.height * .15,
        size.width * 1.04,
        size.height * .18,
      );
    canvas.drawPath(top, lime);

    final bottom = Path()
      ..moveTo(-18, size.height - size.height * .055)
      ..cubicTo(
        size.width * .06,
        size.height - size.height * .09,
        size.width * .13,
        size.height - size.height * .02,
        size.width * .23,
        size.height - size.height * .03,
      )
      ..cubicTo(
        size.width * .33,
        size.height - size.height * .04,
        size.width * .38,
        size.height + 12,
        size.width * .49,
        size.height + 2,
      );
    canvas.drawPath(bottom, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

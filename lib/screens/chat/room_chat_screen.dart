import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import 'room_selection_screen.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/participant_strip.dart';

class RoomChatScreen extends StatefulWidget {
  const RoomChatScreen({super.key, this.profileName = ''});

  final String profileName;

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  Timer? timer;

  int secondsLeft = 15 * 60;
  bool extensionPromptShown = false;
  bool extendedOnce = false;
  bool navigatingToSelection = false;
  bool fastTestMode = false;

  final messages = <ChatMessage>[
    const ChatMessage(
      sender: 'Meet6',
      text: 'Oda hazır. 6 kişi burada — sohbet için 15 dakikan var.',
      time: '',
      isSystem: true,
    ),
    const ChatMessage(
      sender: 'Aslı',
      avatarLabel: 'A',
      text: 'Herkese selam 👋 İlk kim başlıyor?',
      time: '00:01',
    ),
    const ChatMessage(
      sender: 'Mert',
      avatarLabel: 'M',
      text: 'Ben başlayayım 😄 Bugün buraya gelmenize sebep olan şey ne?',
      time: '00:02',
    ),
    const ChatMessage(
      sender: 'Ece',
      avatarLabel: 'E',
      text: 'Yeni insanlarla tanışmak. Klasik ama gerçek 😅',
      time: '00:03',
    ),
  ];

  bool get canSend =>
      messageController.text.trim().isNotEmpty && secondsLeft > 0;
  bool get isLastTwoMinutes => secondsLeft > 0 && secondsLeft <= 120;
  bool get isLastMinute => secondsLeft > 0 && secondsLeft <= 60;

  String get timerText {
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    timer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted || navigatingToSelection) return;
    if (secondsLeft <= 1) {
      timer?.cancel();
      setState(() => secondsLeft = 0);
      _openSelection();
      return;
    }

    setState(() => secondsLeft--);

    if (secondsLeft == 60 && !extensionPromptShown && !extendedOnce) {
      extensionPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showExtensionOffer();
      });
    }
  }

  void _sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty || secondsLeft == 0) return;

    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      messages.add(
        ChatMessage(
          sender: widget.profileName.isEmpty ? 'Sen' : widget.profileName,
          text: text,
          time: time,
          isMine: true,
        ),
      );
      messageController.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showTestMenu() async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Test menüsü',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '15 dakika beklemeden oda sonu akışını test et.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'minute'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text(
                    'Son 1 dakikaya git',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'selection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHigh,
                    foregroundColor: scheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text(
                    'Seçim ekranını aç',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'selection') {
      timer?.cancel();
      setState(() => secondsLeft = 0);
      _openSelection();
      return;
    }

    if (action == 'minute') {
      setState(() {
        fastTestMode = true;
        secondsLeft = 61;
        extensionPromptShown = false;
        extendedOnce = false;
        messages.add(
          const ChatMessage(
            sender: 'Meet6',
            text: 'TEST: Sayaç son 1 dakikaya alındı.',
            time: '',
            isSystem: true,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _showExtensionOffer() async {
    if (!mounted || secondsLeft == 0) return;
    final scheme = Theme.of(context).colorScheme;

    final extend = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_alarm_rounded,
                  color: AppColors.navy,
                  size: 29,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sohbeti +5 dk uzatalım mı?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fastTestMode
                    ? 'TEST modunda kabul edersen 5 dakika yerine 10 saniye eklenir.'
                    : 'Odadaki yeterli kişi kabul ederse sohbet 5 dakika daha devam edecek. Seçim yine sohbet bittikten sonra yapılacak.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(color: scheme.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Hayır',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          '+5 dk iste',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || extend != true || secondsLeft == 0) return;
    setState(() {
      extendedOnce = true;
      secondsLeft = fastTestMode ? 10 : secondsLeft + 5 * 60;
      messages.add(
        ChatMessage(
          sender: 'Meet6',
          text: fastTestMode
              ? 'TEST: Uzatma kabul edildi. 10 saniye sonra gizli seçim açılacak.'
              : '4 kişi devam etmek istedi. Sohbet +5 dakika uzatıldı ⚡',
          time: '',
          isSystem: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _openSelection() {
    if (!mounted || navigatingToSelection) return;
    navigatingToSelection = true;
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomSelectionScreen(profileName: widget.profileName),
        ),
      );
    });
  }

  Future<void> _leaveRoom() async {
    final scheme = Theme.of(context).colorScheme;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Odadan çıkmak istiyor musun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Çıkarsan bu sohbete tekrar dönemeyebilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.navy,
                  ),
                  child: const Text(
                    'Sohbette kal',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(
                  'Odadan çık',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: PhoneFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _leaveRoom,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface,
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meet6 Odası',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '6 kişi · Gizli seçim sohbet sonunda',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showTestMenu,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        'TEST',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLastMinute
                          ? AppColors.lime
                          : dark
                              ? scheme.surfaceContainerHigh
                              : AppColors.navy,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isLastMinute
                            ? AppColors.lime
                            : scheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      timerText,
                      style: TextStyle(
                        color: isLastMinute
                            ? AppColors.navy
                            : dark
                                ? scheme.onSurface
                                : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 10),
            const ParticipantStrip(),
            if (isLastTwoMinutes)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(dark ? .15 : .35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.lime.withOpacity(dark ? .45 : .55),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.lime,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isLastMinute
                              ? 'Son 1 dakika. Süre bitince gizli seçim açılacak.'
                              : 'Sohbetin son 2 dakikası. Birazdan uzatma seçeneği gelecek.',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    ChatMessageBubble(message: messages[index]),
              ),
            ),
            ChatInputBar(
              controller: messageController,
              onChanged: (_) => setState(() {}),
              onSend: _sendMessage,
              canSend: canSend,
            ),
          ],
        ),
      ),
    );
  }
}

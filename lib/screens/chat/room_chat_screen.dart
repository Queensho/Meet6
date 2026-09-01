import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../theme/app_colors.dart';
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

  bool get canSend => messageController.text.trim().isNotEmpty && secondsLeft > 0;

  String get timerText {
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (secondsLeft <= 1) {
        timer?.cancel();
        setState(() => secondsLeft = 0);
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _leaveRoom() async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Odadan çıkmak istiyor musun?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Çıkarsan bu 15 dakikalık sohbete tekrar dönemeyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
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
                    onPressed: () => Navigator.pop(context, false),
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
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Odadan çık',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final desktop = viewport.maxWidth > 520;
          final width = desktop ? 390.0 : viewport.maxWidth;
          final height = desktop ? 844.0 : viewport.maxHeight;

          return Container(
            color: desktop ? const Color(0xFFEFF1F7) : AppColors.background,
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.background,
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
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _leaveRoom,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.border),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meet6 Odası',
                                  style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '6 kişi çevrimiçi',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: secondsLeft <= 60
                                  ? const Color(0xFFFFECEA)
                                  : AppColors.lime,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: secondsLeft <= 60
                                    ? const Color(0xFFFF6B5F)
                                    : AppColors.navy,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.navy,
                                  size: 17,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  timerText,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: ParticipantStrip(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5FF),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.blue.withOpacity(.12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: AppColors.blue,
                              size: 19,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '15 dakika özgür sohbet. Sonunda herkes gizlice bir kişiyi seçer.',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 11.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
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
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            ChatMessageBubble(message: messages[index]),
                      ),
                    ),
                    if (secondsLeft > 0)
                      ChatInputBar(
                        controller: messageController,
                        canSend: canSend,
                        onChanged: (_) => setState(() {}),
                        onSend: _sendMessage,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        color: Colors.white,
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Seçim ekranına geç',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

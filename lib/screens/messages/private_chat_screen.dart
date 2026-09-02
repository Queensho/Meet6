import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.name,
    required this.initial,
    this.isOnline = true,
    this.fromNewMatch = false,
  });

  final String name;
  final String initial;
  final bool isOnline;
  final bool fromNewMatch;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final controller = TextEditingController();
  final List<_PrivateMessage> messages = [];

  @override
  void initState() {
    super.initState();
    messages.addAll([
      if (widget.fromNewMatch)
        const _PrivateMessage(
          text: 'Meet6 odasında karşılıklı seçim yaptınız. İlk mesajı sen gönderebilirsin 👋',
          mine: false,
          system: true,
        )
      else ...[
        const _PrivateMessage(text: 'Oda gerçekten eğlenceliydi 😄', mine: false),
        const _PrivateMessage(text: 'Kesinlikle, 15 dakika çok hızlı geçti.', mine: true),
      ],
    ]);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() => messages.add(_PrivateMessage(text: text, mine: true)));
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: PhoneFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.initial,
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (widget.isOnline)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF36C76C),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isOnline ? 'Çevrimiçi' : 'Yakın zamanda aktifti',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz_rounded, color: AppColors.navy),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  if (message.system) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withOpacity(.36),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: AppColors.navy.withOpacity(.08)),
                      ),
                      child: Text(
                        message.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return Align(
                    alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: message.mine ? AppColors.navy : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(17),
                          topRight: const Radius.circular(17),
                          bottomLeft: Radius.circular(message.mine ? 17 : 5),
                          bottomRight: Radius.circular(message.mine ? 5 : 17),
                        ),
                        border: message.mine ? null : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.mine ? Colors.white : AppColors.navy,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        filled: true,
                        fillColor: AppColors.softSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: AppColors.lime,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateMessage {
  const _PrivateMessage({
    required this.text,
    required this.mine,
    this.system = false,
  });

  final String text;
  final bool mine;
  final bool system;
}

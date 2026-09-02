import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/form_components.dart';
import 'widgets/settings_page_shell.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final messageController = TextEditingController();
  String topic = 'Hesap';

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      title: 'Yardım ve destek',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        physics: const BouncingScrollPhysics(),
        children: [
          const Text(
            'Sık sorulanlar',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const _FaqTile(
            question: 'Oda eşleşmesi nasıl çalışıyor?',
            answer: 'Konumun ve eşleşme tercihlerin kullanılarak sana uygun 6 kişilik oda oluşturulur. Sohbet sonunda seçim ekranı açılır.',
          ),
          const _FaqTile(
            question: 'Konumum diğer kişilere gösteriliyor mu?',
            answer: 'Hayır. Koordinatın gösterilmez; yalnızca şehir ve yaklaşık mesafe bilgisi kullanılabilir.',
          ),
          const _FaqTile(
            question: 'Birini nasıl engellerim?',
            answer: 'Profil veya özel sohbet menüsünden Engelle seçeneğini kullanabilirsin. Engellenen hesapları Ayarlar’dan yönetebilirsin.',
          ),
          const _FaqTile(
            question: 'Eşleşme ne zaman oluşur?',
            answer: 'Oda bittikten sonra iki kişi birbirini gizlice seçerse özel sohbet eşleşmesi oluşur.',
          ),
          const SizedBox(height: 22),
          const Text(
            'Destek talebi',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: topic,
            decoration: meet6InputDecoration(
              hint: 'Konu seç',
              icon: Icons.support_agent_rounded,
            ),
            items: const [
              'Hesap',
              'Konum',
              'Oda ve eşleşme',
              'Güvenlik',
              'Teknik sorun',
              'Diğer',
            ]
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => topic = value ?? topic),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: messageController,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: meet6InputDecoration(
              hint: 'Sorununu veya sorunu anlat...',
              icon: Icons.edit_note_rounded,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: messageController.text.trim().length >= 5 ? _send : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Destek talebi gönder',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    FocusScope.of(context).unfocus();
    messageController.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Destek talebin demo olarak kaydedildi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: AppColors.blue,
        collapsedIconColor: AppColors.muted,
        title: Text(
          question,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.7,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

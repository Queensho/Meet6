import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'widgets/settings_page_shell.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      title: 'Koşullar ve gizlilik',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        physics: const BouncingScrollPhysics(),
        children: const [
          _LegalCard(
            icon: Icons.description_outlined,
            title: 'Kullanım koşulları',
            text: 'Meet6 kullanımında hesap güvenliği, topluluk kuralları, oda davranışları ve hizmetin kullanım sınırları bu bölümde açıklanır. Yayın öncesi nihai hukuki metin eklenecektir.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Gizlilik politikası',
            text: 'Konum, profil ve eşleşme verilerinin hangi amaçlarla işlendiği; saklama süreleri ve kullanıcı hakları burada açıklanır. Hassas konum diğer kullanıcılara doğrudan gösterilmez.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            icon: Icons.cookie_outlined,
            title: 'Çerez ve web teknolojileri',
            text: 'Web sürümünde oturum, güvenlik ve temel kullanım ölçümü için gerekli teknolojilerin nasıl kullanıldığı bu bölümde yer alacaktır.',
          ),
          SizedBox(height: 10),
          _LegalCard(
            icon: Icons.groups_outlined,
            title: 'Topluluk kuralları',
            text: 'Taciz, tehdit, nefret söylemi, sahte hesap, spam ve uygunsuz içerik Meet6 topluluk kurallarına aykırıdır. Kullanıcılar profil ve sohbetlerden raporlanabilir veya engellenebilir.',
          ),
          SizedBox(height: 18),
          Center(
            child: Text(
              'Son güncelleme: 2 Eylül 2026',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: title == 'Gizlilik politikası',
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 15),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.softSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.blue, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.8,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

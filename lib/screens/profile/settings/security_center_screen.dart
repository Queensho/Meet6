import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'blocked_accounts_screen.dart';
import 'help_support_screen.dart';
import 'widgets/settings_page_shell.dart';

class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      title: 'Güvenlik merkezi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lime.withOpacity(.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.navy.withOpacity(.08)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_rounded, color: AppColors.blue, size: 24),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Engelleme, şikâyet ve destek araçları hesabını ve sohbet deneyimini korumak için birlikte çalışır.',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SecurityAction(
            icon: Icons.block_rounded,
            title: 'Engellenen hesaplar',
            subtitle: 'Engellediğin kişileri görüntüle ve engeli kaldır',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedAccountsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _SecurityAction(
            icon: Icons.support_agent_rounded,
            title: 'Destek ve şikâyet',
            subtitle: 'Meet6 destek ekibine talep gönder ve yanıtlarını gör',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'GÜVENLİ KULLANIM',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const _SafetyTip(
            icon: Icons.lock_person_outlined,
            text: 'Telefon, adres, parola veya ödeme bilgilerini tanımadığın kişilerle paylaşma.',
          ),
          const SizedBox(height: 8),
          const _SafetyTip(
            icon: Icons.report_gmailerrorred_rounded,
            text: 'Rahatsız eden birini profil, oda veya sohbet içindeki şikâyet ve engelle araçlarıyla bildir.',
          ),
          const SizedBox(height: 8),
          const _SafetyTip(
            icon: Icons.emergency_outlined,
            text: 'Acil bir güvenlik riski varsa uygulama içi desteğin yanında yerel acil yardım hizmetlerine ulaş.',
          ),
        ],
      ),
    );
  }
}

class _SecurityAction extends StatelessWidget {
  const _SecurityAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.92),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _IconBox(icon),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.2,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  const _SafetyTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11.7,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.blue, size: 20),
    );
  }
}

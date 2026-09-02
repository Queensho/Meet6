import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/phone_frame.dart';
import '../login_screen.dart';
import 'settings/blocked_accounts_screen.dart';
import 'settings/help_support_screen.dart';
import 'settings/legal_screen.dart';
import 'settings/privacy_security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool roomReminders = true;
  bool showOnline = true;
  bool preciseLocation = false;
  bool vibration = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PhoneFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ayarlar',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                physics: const BouncingScrollPhysics(),
                children: [
                  const _SectionTitle('Bildirimler'),
                  _SettingsCard(
                    children: [
                      _SwitchTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Bildirimler',
                        subtitle: 'Eşleşme ve mesaj bildirimlerini al',
                        value: notifications,
                        onChanged: (v) => setState(() => notifications = v),
                      ),
                      _SwitchTile(
                        icon: Icons.schedule_rounded,
                        title: 'Oda hatırlatmaları',
                        subtitle: 'Yeni oda açılmadan önce haber ver',
                        value: roomReminders,
                        onChanged: (v) => setState(() => roomReminders = v),
                      ),
                      _SwitchTile(
                        icon: Icons.vibration_rounded,
                        title: 'Titreşim',
                        subtitle: 'Mesaj ve seçimlerde titreşim kullan',
                        value: vibration,
                        onChanged: (v) => setState(() => vibration = v),
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Gizlilik ve konum'),
                  _SettingsCard(
                    children: [
                      _SwitchTile(
                        icon: Icons.circle_outlined,
                        title: 'Çevrimiçi durumumu göster',
                        subtitle: 'Diğer kişiler aktif olduğunu görebilir',
                        value: showOnline,
                        onChanged: (v) => setState(() => showOnline = v),
                      ),
                      _SwitchTile(
                        icon: Icons.my_location_rounded,
                        title: 'Hassas konum',
                        subtitle: 'Yakın oda önerilerini daha doğru göster',
                        value: preciseLocation,
                        onChanged: (v) => setState(() => preciseLocation = v),
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Hesap'),
                  _SettingsCard(
                    children: [
                      _LinkTile(
                        icon: Icons.shield_outlined,
                        title: 'Gizlilik ve güvenlik',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacySecurityScreen(),
                          ),
                        ),
                      ),
                      _LinkTile(
                        icon: Icons.block_rounded,
                        title: 'Engellenen hesaplar',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BlockedAccountsScreen(),
                          ),
                        ),
                      ),
                      _LinkTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Yardım ve destek',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        ),
                      ),
                      _LinkTile(
                        icon: Icons.description_outlined,
                        title: 'Koşullar ve gizlilik',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(),
                          ),
                        ),
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsCard(
                    children: [
                      _LinkTile(
                        icon: Icons.logout_rounded,
                        title: 'Çıkış yap',
                        danger: true,
                        onTap: _showLogoutConfirm,
                      ),
                      _LinkTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Hesabımı sil',
                        danger: true,
                        onTap: _showDeleteConfirm,
                        last: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Meet6 · v0.1.0',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirm() async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE24A4A),
                size: 34,
              ),
              const SizedBox(height: 10),
              const Text(
                'Çıkış yapmak istiyor musun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Bu prototipte çıkış yaptığında giriş ekranına dönersin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE24A4A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Çıkış yap',
                        style: TextStyle(fontWeight: FontWeight.w900),
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

    if (approved == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showDeleteConfirm() async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE24A4A),
                size: 38,
              ),
              const SizedBox(height: 10),
              const Text(
                'Hesabını silmek istiyor musun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Gerçek hesap backend’i henüz bağlı olmadığı için bu işlem şu an yalnızca prototip akışını test eder. Sunucuda veri silmez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Vazgeç',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Prototip hesabı sil ve çık',
                  style: TextStyle(
                    color: Color(0xFFE24A4A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (approved == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.blue,
          secondary: _IconBox(icon),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        if (!last) const Divider(height: 1, indent: 62, color: AppColors.border),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE24A4A) : AppColors.navy;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: _IconBox(icon, danger: danger),
          title: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: danger ? const Color(0xFFE24A4A) : AppColors.muted,
          ),
        ),
        if (!last) const Divider(height: 1, indent: 62, color: AppColors.border),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFEEEE) : AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: danger ? const Color(0xFFE24A4A) : AppColors.blue,
        size: 20,
      ),
    );
  }
}

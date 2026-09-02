import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
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
  bool accountActionRunning = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PhoneFrame(
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: accountActionRunning
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(backgroundColor: scheme.surface),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ayarlar',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (accountActionRunning)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const _SectionTitle('Görünüm'),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.instance,
                      builder: (context, mode, _) {
                        return _SettingsCard(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ThemeChoice(
                                    icon: Icons.light_mode_rounded,
                                    title: 'Aydınlık',
                                    selected: mode == ThemeMode.light,
                                    onTap: () => ThemeController.instance
                                        .setMode(ThemeMode.light),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ThemeChoice(
                                    icon: Icons.dark_mode_rounded,
                                    title: 'Karanlık',
                                    selected: mode == ThemeMode.dark,
                                    onTap: () => ThemeController.instance
                                        .setMode(ThemeMode.dark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
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
                          onTap: accountActionRunning
                              ? () {}
                              : _showLogoutConfirm,
                        ),
                        _LinkTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Hesabımı sil',
                          danger: true,
                          onTap: accountActionRunning
                              ? () {}
                              : _showDeleteConfirm,
                          last: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Meet6 · v0.1.0',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
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
      ),
    );
  }

  Future<void> _showLogoutConfirm() async {
    final approved = await _showConfirmSheet(
      icon: Icons.logout_rounded,
      title: 'Çıkış yapmak istiyor musun?',
      description:
          'Bu cihazdaki Meet6 oturumun sunucuda kapatılacak ve giriş ekranına döneceksin.',
      confirmLabel: 'Çıkış yap',
    );

    if (approved != true || !mounted) return;
    setState(() => accountActionRunning = true);
    await ApiService.logout();
    await SessionService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showDeleteConfirm() async {
    final approved = await _showConfirmSheet(
      icon: Icons.warning_amber_rounded,
      title: 'Hesabını kalıcı olarak sil?',
      description:
          'Profilin, fotoğrafların, eşleşmelerin ve mesajların sunucudan kalıcı olarak silinir. Bu işlem geri alınamaz.',
      confirmLabel: 'Hesabı kalıcı sil',
    );

    if (approved != true || !mounted) return;
    setState(() => accountActionRunning = true);
    try {
      await ApiService.deleteAccount();
      await SessionService.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => accountActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => accountActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap silinemedi. Bağlantını kontrol edip tekrar dene.'),
        ),
      );
    }
  }

  Future<bool?> _showConfirmSheet({
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFFE24A4A), size: 36),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
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
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Vazgeç'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE24A4A),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          confirmLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.children, this.child});

  final List<Widget>? children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child ?? Column(children: children ?? const []),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 82,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lime
              : scheme.surfaceContainerHigh.withOpacity(.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.navy : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.navy : scheme.onSurface,
              size: 25,
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.navy : scheme.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.blue,
          secondary: _IconBox(icon),
          title: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        if (!last)
          Divider(height: 1, indent: 62, color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? const Color(0xFFE24A4A) : scheme.onSurface;
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
            color: danger ? const Color(0xFFE24A4A) : scheme.onSurfaceVariant,
          ),
        ),
        if (!last)
          Divider(height: 1, indent: 62, color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: danger
            ? const Color(0x33E24A4A)
            : scheme.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: danger ? const Color(0xFFE24A4A) : scheme.primary,
        size: 20,
      ),
    );
  }
}

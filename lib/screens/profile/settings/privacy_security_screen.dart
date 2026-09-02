import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'widgets/settings_page_shell.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool showOnline = true;
  bool allowRoomInvites = true;
  bool allowPrivateMessages = true;
  bool blurLocation = true;
  bool hideExactDistance = true;
  bool readReceipts = true;

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      title: 'Gizlilik ve güvenlik',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        physics: const BouncingScrollPhysics(),
        children: [
          const _InfoBanner(),
          const SizedBox(height: 18),
          const _SectionTitle('Görünürlük'),
          _Card(
            children: [
              _SwitchRow(
                icon: Icons.circle_outlined,
                title: 'Çevrimiçi durumumu göster',
                subtitle: 'Diğer kişiler aktif olduğunu görebilir.',
                value: showOnline,
                onChanged: (value) => setState(() => showOnline = value),
              ),
              _SwitchRow(
                icon: Icons.location_off_outlined,
                title: 'Konumumu yaklaşık göster',
                subtitle: 'Tam konum yerine yalnızca şehir ve yaklaşık mesafe kullanılır.',
                value: blurLocation,
                onChanged: (value) => setState(() => blurLocation = value),
              ),
              _SwitchRow(
                icon: Icons.straighten_outlined,
                title: 'Tam mesafeyi gizle',
                subtitle: 'Örn. 2,3 km yerine “5 km içinde” gösterilir.',
                value: hideExactDistance,
                onChanged: (value) => setState(() => hideExactDistance = value),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle('İletişim'),
          _Card(
            children: [
              _SwitchRow(
                icon: Icons.groups_outlined,
                title: 'Oda davetlerine izin ver',
                subtitle: 'Uygun olduğunda oda önerileri ve davetleri al.',
                value: allowRoomInvites,
                onChanged: (value) => setState(() => allowRoomInvites = value),
              ),
              _SwitchRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Özel mesajlara izin ver',
                subtitle: 'Yalnızca eşleştiğin kişiler özel mesaj gönderebilir.',
                value: allowPrivateMessages,
                onChanged: (value) => setState(() => allowPrivateMessages = value),
              ),
              _SwitchRow(
                icon: Icons.done_all_rounded,
                title: 'Okundu bilgisini göster',
                subtitle: 'Özel mesajlarda okundu durumunu paylaş.',
                value: readReceipts,
                onChanged: (value) => setState(() => readReceipts = value),
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ActionTile(
            icon: Icons.security_rounded,
            title: 'Güvenlik merkezi',
            subtitle: 'Raporlama, engelleme ve güvenli kullanım ipuçları',
            onTap: () => _showInfo(
              context,
              'Güvenlik merkezi için temel arayüz hazır. Raporlama backend ile bağlanacak.',
            ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.download_outlined,
            title: 'Verilerimi indir',
            subtitle: 'Hesabınla ilgili veri kopyası iste',
            onTap: () => _showInfo(
              context,
              'Veri indirme talebi hesap backend’i bağlandığında gerçek dosya oluşturacak.',
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.lime.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navy.withOpacity(.08)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.blue, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Konumun oda eşleştirmesi için kullanılır. Diğer kişilere koordinatın gösterilmez.',
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
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
              fontSize: 11.2,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (!last) const Divider(height: 1, indent: 62, color: AppColors.border),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
          padding: const EdgeInsets.all(13),
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
                    const SizedBox(height: 2),
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

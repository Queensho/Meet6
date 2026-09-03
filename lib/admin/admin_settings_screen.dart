import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'services/admin_api_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final roomDuration = TextEditingController();
  final extension = TextEditingController();
  final selectionSeconds = TextEditingController();
  final roomRepeatHours = TextEditingController();
  final recentMatchDays = TextEditingController();
  final minimumUsers = TextEditingController();
  final maintenanceMessage = TextEditingController();
  final announcementTitle = TextEditingController();
  final announcementMessage = TextEditingController();

  bool maintenanceMode = false;
  bool announcementEnabled = false;
  bool editable = false;
  bool loading = true;
  bool saving = false;
  String? error;
  String? savedMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    roomDuration.dispose();
    extension.dispose();
    selectionSeconds.dispose();
    roomRepeatHours.dispose();
    recentMatchDays.dispose();
    minimumUsers.dispose();
    maintenanceMessage.dispose();
    announcementTitle.dispose();
    announcementMessage.dispose();
    super.dispose();
  }

  int _int(TextEditingController controller, int fallback) =>
      int.tryParse(controller.text.trim()) ?? fallback;

  void _apply(Map<String, dynamic> data) {
    final raw = data['settings'];
    if (raw is! Map) return;
    final settings = Map<String, dynamic>.from(raw);
    roomDuration.text = '${settings['roomDurationMinutes'] ?? 15}';
    extension.text = '${settings['extensionMinutes'] ?? 5}';
    selectionSeconds.text = '${settings['selectionSeconds'] ?? 10}';
    roomRepeatHours.text = '${settings['roomRepeatHours'] ?? 24}';
    recentMatchDays.text = '${settings['recentMatchDays'] ?? 7}';
    minimumUsers.text = '${settings['minimumRoomUsers'] ?? 6}';
    maintenanceMode = settings['maintenanceMode'] == true;
    maintenanceMessage.text = settings['maintenanceMessage']?.toString() ?? '';
    announcementEnabled = settings['announcementEnabled'] == true;
    announcementTitle.text = settings['announcementTitle']?.toString() ?? '';
    announcementMessage.text = settings['announcementMessage']?.toString() ?? '';
    editable = data['editable'] == true;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      savedMessage = null;
    });
    try {
      final data = await AdminApiService.settings();
      if (!mounted) return;
      setState(() => _apply(data));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401) widget.onLogout();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (!editable || saving) return;
    final body = <String, dynamic>{
      'roomDurationMinutes': _int(roomDuration, 15),
      'extensionMinutes': _int(extension, 5),
      'selectionSeconds': _int(selectionSeconds, 10),
      'roomRepeatHours': _int(roomRepeatHours, 24),
      'recentMatchDays': _int(recentMatchDays, 7),
      'minimumRoomUsers': _int(minimumUsers, 6),
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage.text.trim(),
      'announcementEnabled': announcementEnabled,
      'announcementTitle': announcementTitle.text.trim(),
      'announcementMessage': announcementMessage.text.trim(),
    };
    setState(() {
      saving = true;
      error = null;
      savedMessage = null;
    });
    try {
      final data = await AdminApiService.updateSettings(body);
      if (!mounted) return;
      setState(() {
        _apply(data);
        savedMessage = 'Ayarlar kaydedildi. Yeni işlemlerde hemen kullanılacak.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration _decoration(String label, String helper) => InputDecoration(
        labelText: label,
        helperText: helper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  Widget _numberField(
    TextEditingController controller,
    String label,
    String helper,
  ) => TextField(
        controller: controller,
        enabled: editable && !saving,
        keyboardType: TextInputType.number,
        decoration: _decoration(label, helper),
      );

  Widget _section(String title, String subtitle, List<Widget> children) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        title: const Text('Uygulama Ayarları', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: loading || saving ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (!editable)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
                    child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.blue),
                      SizedBox(width: 10),
                      Expanded(child: Text('Bu değerleri yalnızca Super Admin değiştirebilir.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w800)),
                  ),
                if (savedMessage != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: const Color(0xFFE8F8EF), borderRadius: BorderRadius.circular(16)),
                    child: Text(savedMessage!, style: const TextStyle(color: Color(0xFF16784A), fontWeight: FontWeight.w800)),
                  ),
                LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth >= 900;
                  final roomFields = [
                    _numberField(roomDuration, 'Oda süresi (dk)', 'Varsayılan: 15'),
                    _numberField(extension, 'Uzatma süresi (dk)', 'Varsayılan: +5'),
                    _numberField(selectionSeconds, 'Gizli seçim süresi (sn)', 'Varsayılan: 10'),
                    _numberField(minimumUsers, 'Minimum kullanıcı sayısı', '2–6, varsayılan: 6'),
                    _numberField(roomRepeatHours, 'Tekrar-oda engeli (saat)', 'Varsayılan: 24'),
                    _numberField(recentMatchDays, 'Recent-match engeli (gün)', 'Varsayılan: 7'),
                  ];
                  return _section(
                    'Oda & Matchmaking',
                    'Değişiklikler yeni odalar ve sonraki matchmaking hesaplarında kullanılır. Aktif odanın mevcut bitiş zamanı geriye dönük değiştirilmez.',
                    [
                      if (wide)
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: roomFields.map((field) => SizedBox(width: (box.maxWidth - 82) / 3, child: field)).toList(),
                        )
                      else
                        ...roomFields.expand((field) => [field, const SizedBox(height: 12)]),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                _section(
                  'Bakım Modu',
                  'Açıldığında yeni matchmaking ve oda işlemleri durdurulur; uygulamayı yeniden açan kullanıcı bakım ekranını görür.',
                  [
                    SwitchListTile.adaptive(
                      value: maintenanceMode,
                      onChanged: editable && !saving ? (value) => setState(() => maintenanceMode = value) : null,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bakım modu', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(maintenanceMode ? 'AKTİF' : 'Kapalı'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maintenanceMessage,
                      enabled: editable && !saving,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: _decoration('Bakım mesajı', 'Kullanıcıya gösterilecek açıklama'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  'Uygulama Duyurusu',
                  'Kampanya, güncelleme veya genel bilgilendirme için uygulama içinde gösterilecek metin.',
                  [
                    SwitchListTile.adaptive(
                      value: announcementEnabled,
                      onChanged: editable && !saving ? (value) => setState(() => announcementEnabled = value) : null,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Duyuruyu göster', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: announcementTitle,
                      enabled: editable && !saving,
                      maxLength: 120,
                      decoration: _decoration('Duyuru başlığı', 'Örn. Meet6 güncellendi'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: announcementMessage,
                      enabled: editable && !saving,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: _decoration('Duyuru mesajı', 'Kullanıcıların göreceği duyuru'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (editable)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      ),
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Ayarları kaydet', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

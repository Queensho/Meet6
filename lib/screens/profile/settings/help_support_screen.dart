import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/live_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/form_components.dart';
import 'widgets/settings_page_shell.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.focusRequestId});

  final String? focusRequestId;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final messageController = TextEditingController();
  String topic = 'Hesap';
  bool sending = false;
  List<Map<String, dynamic>> requests = const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await LiveService.supportRequests();
      final loaded = [...data];
      final focusId = widget.focusRequestId?.trim() ?? '';
      if (focusId.isNotEmpty) {
        final index = loaded.indexWhere(
          (item) => item['id']?.toString() == focusId,
        );
        if (index > 0) {
          final focused = loaded.removeAt(index);
          loaded.insert(0, focused);
        }
      }
      if (mounted) setState(() => requests = loaded);
    } catch (_) {}
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = messageController.text.trim();
    if (message.length < 5 || sending) return;
    FocusScope.of(context).unfocus();
    setState(() => sending = true);
    try {
      final result = await LiveService.createSupportRequest(
        topic: topic,
        message: message,
      );
      final raw = result['request'];
      if (!mounted) return;
      messageController.clear();
      setState(() {
        if (raw is Map) {
          requests = [Map<String, dynamic>.from(raw), ...requests];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destek talebin sunucuya kaydedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _statusLabel(String value) {
    if (value == 'in_progress') return 'İnceleniyor';
    if (value == 'answered') return 'Yanıtlandı';
    if (value == 'closed') return 'Kapatıldı';
    return 'Açık';
  }

  Widget _requestCard(Map<String, dynamic> item, ColorScheme scheme) {
    final status = item['status']?.toString() ?? 'open';
    final response = item['admin_response']?.toString().trim() ?? '';
    final focused = widget.focusRequestId?.toString() == item['id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? AppColors.lime : scheme.outlineVariant,
          width: focused ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['topic']?.toString() ?? 'Destek',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['message']?.toString() ?? '',
                      maxLines: response.isEmpty ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusLabel(status),
                style: TextStyle(
                  color: status == 'closed'
                      ? scheme.onSurfaceVariant
                      : status == 'answered'
                          ? const Color(0xFF36A766)
                          : scheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (response.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.lime.withValues(alpha: .55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meet6 destek yanıtı',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    response,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SettingsPageShell(
      title: 'Yardım ve destek',
      child: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            Text(
              'Sık sorulanlar',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const _FaqTile(
              question: 'Oda eşleşmesi nasıl çalışıyor?',
              answer: 'Konumun, yaş aralığın, tanışma tercihin ve engel listen kullanılarak 6 uyumlu kişi aynı odaya alınır.',
            ),
            const _FaqTile(
              question: 'Konumum diğer kişilere gösteriliyor mu?',
              answer: 'Hayır. Kesin koordinatın diğer kullanıcılara gönderilmez; eşleştirme motoru yalnızca mesafe hesabında kullanır.',
            ),
            const _FaqTile(
              question: 'Birini nasıl engellerim?',
              answer: 'Eşleşme profili veya özel sohbet menüsünden Engelle seçeneğini kullanabilirsin. Engellenen iki kullanıcı tekrar aynı odaya alınmaz.',
            ),
            const _FaqTile(
              question: 'Eşleşme ne zaman oluşur?',
              answer: 'Oda sonunda iki kişi birbirini gizlice seçerse sunucuda eşleşme oluşur ve özel sohbet açılır.',
            ),
            const SizedBox(height: 22),
            Text(
              'Destek talebi',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: topic,
              dropdownColor: scheme.surface,
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
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
              ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: sending ? null : (value) => setState(() => topic = value ?? topic),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: scheme.onSurface),
              decoration: meet6InputDecoration(
                hint: 'Sorununu veya sorunu anlat...',
                icon: Icons.edit_note_rounded,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: messageController.text.trim().length >= 5 && !sending ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? AppColors.lime : AppColors.navy,
                  foregroundColor: dark ? AppColors.navy : Colors.white,
                  disabledBackgroundColor: scheme.surfaceContainerHigh,
                  disabledForegroundColor: scheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  sending ? 'Gönderiliyor...' : 'Destek talebi gönder',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Taleplerim',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in requests.take(5)) _requestCard(item, scheme),
            ],
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        title: Text(
          question,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
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

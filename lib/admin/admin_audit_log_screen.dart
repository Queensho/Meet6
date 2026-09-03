import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'services/admin_api_service.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> logs = const [];
  List<Map<String, dynamic>> actions = const [];
  String action = 'all';
  String targetType = 'all';
  int page = 1;
  int total = 0;
  bool loading = true;
  String? error;
  static const limit = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool firstPage = false}) async {
    if (firstPage) page = 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AdminApiService.auditLogs(
        action: action,
        targetType: targetType,
        search: searchController.text.trim(),
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        logs = ((result['logs'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        actions = ((result['actions'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        total = (result['total'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final actionValues = <String>{'all', ...actions.map((e) => '${e['action']}')}.toList();
    if (!actionValues.contains(action)) action = 'all';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        title: const Text('Admin Audit Log', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: AppColors.blue))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.admin_panel_settings_rounded, color: AppColors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Değiştirilemez yönetim geçmişi', style: TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 6),
                const Text('Hangi adminin kimi, ne zaman ve hangi nedenle banladığını, sildiğini veya değiştirdiğini burada izleyebilirsin.', style: TextStyle(color: AppColors.muted, height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(
                    width: wide ? 340 : double.infinity,
                    child: TextField(
                      controller: searchController,
                      onSubmitted: (_) => _load(firstPage: true),
                      decoration: const InputDecoration(hintText: 'Admin, kullanıcı, neden, hedef ID ara', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
                    ),
                  ),
                  DropdownButton<String>(
                    value: action,
                    items: actionValues.map((value) => DropdownMenuItem(value: value, child: Text(value == 'all' ? 'Tüm işlemler' : _actionLabel(value)))).toList(),
                    onChanged: loading ? null : (value) { if (value == null) return; setState(() => action = value); _load(firstPage: true); },
                  ),
                  DropdownButton<String>(
                    value: targetType,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tüm hedefler')),
                      DropdownMenuItem(value: 'user', child: Text('Kullanıcı')),
                      DropdownMenuItem(value: 'room', child: Text('Oda')),
                      DropdownMenuItem(value: 'match', child: Text('Eşleşme')),
                      DropdownMenuItem(value: 'report', child: Text('Şikâyet')),
                      DropdownMenuItem(value: 'support_request', child: Text('Destek talebi')),
                    ],
                    onChanged: loading ? null : (value) { if (value == null) return; setState(() => targetType = value); _load(firstPage: true); },
                  ),
                  FilledButton.icon(
                    onPressed: loading ? null : () => _load(firstPage: true),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('Uygula'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white),
                  ),
                ]),
              ]),
            ),
            if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: AppColors.blue)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700))),
            const SizedBox(height: 16),
            if (!loading && logs.isEmpty)
              const _EmptyAudit()
            else if (wide)
              _AuditTable(logs: logs)
            else
              ...logs.map((log) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _AuditCard(log: log))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('$total kayıt', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              IconButton(onPressed: page > 1 && !loading ? () { setState(() => page--); _load(); } : null, icon: const Icon(Icons.chevron_left_rounded)),
              Text('$page', style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(onPressed: page * limit < total && !loading ? () { setState(() => page++); _load(); } : null, icon: const Icon(Icons.chevron_right_rounded)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.logs});
  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.softSurface),
            columns: const [
              DataColumn(label: Text('Tarih')),
              DataColumn(label: Text('Admin')),
              DataColumn(label: Text('İşlem')),
              DataColumn(label: Text('Hedef')),
              DataColumn(label: Text('Neden / Detay')),
            ],
            rows: logs.map((log) {
              final admin = Map<String, dynamic>.from((log['admin'] as Map?) ?? const {});
              return DataRow(cells: [
                DataCell(Text(_date(log['createdAt']))),
                DataCell(Text('${admin['displayName'] ?? '-'}\n${admin['role'] ?? ''}')),
                DataCell(_ActionChip('${log['action']}')),
                DataCell(Text('${log['targetLabel'] ?? '-'}')),
                DataCell(SizedBox(width: 340, child: Text(_detailText(log), maxLines: 3, overflow: TextOverflow.ellipsis))),
              ]);
            }).toList(),
          ),
        ),
      );
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final admin = Map<String, dynamic>.from((log['admin'] as Map?) ?? const {});
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${admin['displayName'] ?? 'Admin'}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900))), _ActionChip('${log['action']}')]),
        const SizedBox(height: 4),
        Text('${admin['role'] ?? ''} · ${_date(log['createdAt'])}', style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text('${log['targetLabel'] ?? '-'}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(_detailText(log), style: const TextStyle(color: AppColors.muted, height: 1.35, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.action);
  final String action;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: _actionColor(action).withOpacity(.12), borderRadius: BorderRadius.circular(999)),
        child: Text(_actionLabel(action), style: TextStyle(color: _actionColor(action), fontSize: 10.5, fontWeight: FontWeight.w900)),
      );
}

class _EmptyAudit extends StatelessWidget {
  const _EmptyAudit();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(38),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [
          Icon(Icons.history_rounded, size: 46, color: AppColors.blue),
          SizedBox(height: 10),
          Text('Bu filtrede audit kaydı yok.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
        ]),
      );
}

String _detailText(Map<String, dynamic> log) {
  final detail = Map<String, dynamic>.from((log['detail'] as Map?) ?? const {});
  final reason = detail['reason']?.toString().trim();
  if (reason != null && reason.isNotEmpty) return reason;
  final originalBanReason = detail['originalBanReason']?.toString().trim();
  if (originalBanReason != null && originalBanReason.isNotEmpty) return originalBanReason;
  final response = detail['response']?.toString().trim();
  if (response != null && response.isNotEmpty) return response;
  if (detail.isEmpty) return '-';
  try {
    return const JsonEncoder.withIndent('  ').convert(detail);
  } catch (_) {
    return detail.toString();
  }
}

String _actionLabel(String action) {
  const labels = {
    'ban_user': 'Ban verdi',
    'unban_user': 'Ban kaldırdı',
    'warn_user': 'Uyardı',
    'remove_profile_photo': 'Fotoğraf sildi',
    'remove_from_matchmaking': 'Matchmaking’den çıkardı',
    'close_room': 'Odayı kapattı',
    'remove_room_member': 'Odadan çıkardı',
    'end_match': 'Eşleşmeyi bitirdi',
    'moderate_report': 'Şikâyeti yönetti',
    'mark_report_evidence': 'Kanıt işaretledi',
    'support_request_action': 'Destek talebini değiştirdi',
    'view_moderation_history': 'Moderasyon geçmişini açtı',
  };
  return labels[action] ?? action.replaceAll('_', ' ');
}

Color _actionColor(String action) {
  if (action.contains('ban') || action.contains('remove') || action.contains('close') || action.contains('end')) return const Color(0xFFC74646);
  if (action.contains('warn') || action.contains('report')) return const Color(0xFFD88B19);
  return AppColors.blue;
}

String _date(Object? value) {
  if (value == null) return '-';
  final dt = DateTime.tryParse(value.toString())?.toLocal();
  if (dt == null) return value.toString();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

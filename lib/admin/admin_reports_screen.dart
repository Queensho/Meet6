import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'services/admin_api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> reports = const [];
  Map<String, dynamic> stats = const {};
  bool loading = true;
  bool canModerate = false;
  String? error;
  String status = 'open';
  int page = 1;
  int total = 0;
  static const limit = 20;

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
      final result = await AdminApiService.reports(
        status: status,
        search: searchController.text.trim(),
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        reports = ((result['reports'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        stats = Map<String, dynamic>.from((result['stats'] as Map?) ?? const {});
        total = (result['total'] as num?)?.toInt() ?? 0;
        canModerate = result['canModerate'] == true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Şikâyetler yüklenemedi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _setStatus(String value) {
    if (value == status) return;
    setState(() => status = value);
    _load(firstPage: true);
  }

  void _openReport(String reportId) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final panel = _ReportDetailPanel(
      reportId: reportId,
      onChanged: () => _load(),
    );
    if (wide) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 900),
            child: panel,
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: .96, child: panel),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Şikâyetler & Moderasyon',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        _PriorityBadge(),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: loading ? null : _load,
                    tooltip: 'Yenile',
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.blue),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'Güvenlik Merkezi',
                    style: TextStyle(color: AppColors.navy, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canModerate
                        ? 'Açık vakaları incele, kanıtları değerlendir ve yaptırım uygula.'
                        : 'Şikâyetleri ve kanıtları görüntüleyebilirsin. Yaptırım için moderatör yetkisi gerekir.',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  _StatusSummary(
                    stats: stats,
                    selected: status,
                    onSelected: _setStatus,
                  ),
                  const SizedBox(height: 16),
                  _ReportFilters(
                    controller: searchController,
                    status: status,
                    loading: loading,
                    onSearch: () => _load(firstPage: true),
                    onStatus: _setStatus,
                  ),
                  if (loading) const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(color: AppColors.blue),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _MessageBox(message: error!, danger: true),
                  ],
                  const SizedBox(height: 14),
                  if (!loading && reports.isEmpty)
                    const _EmptyReports()
                  else
                    ...reports.map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportCard(
                          report: report,
                          onTap: () => _openReport(report['id']?.toString() ?? ''),
                        ),
                      ),
                    ),
                  if (total > limit) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: page > 1 && !loading
                              ? () {
                                  setState(() => page--);
                                  _load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '$page / ${(total / limit).ceil()}',
                          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          onPressed: page * limit < total && !loading
                              ? () {
                                  setState(() => page++);
                                  _load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEC),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Text(
          'ÖNCELİKLİ',
          style: TextStyle(
            color: Color(0xFFD74747),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      );
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.stats, required this.selected, required this.onSelected});

  final Map<String, dynamic> stats;
  final String selected;
  final ValueChanged<String> onSelected;

  int count(String key) => (stats[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('open', 'Açık', count('open'), Icons.report_gmailerrorred_rounded, const Color(0xFFD74747)),
      ('reviewing', 'İnceleniyor', count('reviewing'), Icons.manage_search_rounded, const Color(0xFFE69B2E)),
      ('resolved', 'Çözüldü', count('resolved'), Icons.task_alt_rounded, const Color(0xFF239B68)),
      ('rejected', 'Reddedildi', count('rejected'), Icons.cancel_outlined, AppColors.muted),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth >= 760 ? (box.maxWidth - 36) / 4 : (box.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            final active = selected == item.$1;
            return InkWell(
              onTap: () => onSelected(item.$1),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: width,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: active ? item.$5.withOpacity(.07) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? item.$5 : AppColors.border, width: active ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: item.$5.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
                      child: Icon(item.$4, color: item.$5, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.$3}', style: const TextStyle(color: AppColors.navy, fontSize: 23, fontWeight: FontWeight.w900, height: 1)),
                          const SizedBox(height: 5),
                          Text(item.$2, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.controller,
    required this.status,
    required this.loading,
    required this.onSearch,
    required this.onStatus,
  });

  final TextEditingController controller;
  final String status;
  final bool loading;
  final VoidCallback onSearch;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final search = TextField(
            controller: controller,
            enabled: !loading,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'İsim, sebep veya şikâyet ID ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: onSearch, icon: const Icon(Icons.arrow_forward_rounded)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
            ),
          );
          final dropdown = DropdownButtonFormField<String>(
            value: status,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tümü')),
              DropdownMenuItem(value: 'open', child: Text('Açık')),
              DropdownMenuItem(value: 'reviewing', child: Text('İnceleniyor')),
              DropdownMenuItem(value: 'resolved', child: Text('Çözüldü')),
              DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
            ],
            onChanged: loading ? null : (value) => value == null ? null : onStatus(value),
          );
          if (box.maxWidth >= 700) {
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), SizedBox(width: 190, child: dropdown)]);
          }
          return Column(children: [search, const SizedBox(height: 10), dropdown]);
        },
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reporter = Map<String, dynamic>.from((report['reporter'] as Map?) ?? const {});
    final reported = Map<String, dynamic>.from((report['reported'] as Map?) ?? const {});
    final contextType = report['contextType']?.toString() ?? 'profile';
    final contextText = contextType == 'private_chat'
        ? 'Özel sohbet #${report['matchId'] ?? '-'}'
        : contextType == 'room'
            ? 'Oda #${report['roomId'] ?? '-'}'
            : 'Profil şikâyeti';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: report['status']?.toString() ?? 'open'),
                  const SizedBox(width: 8),
                  Text('#${report['id'] ?? '-'}', style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(_formatDate(report['createdAt']), style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: _MiniUser(label: 'Şikâyet eden', user: reporter)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.muted)),
                  Expanded(child: _MiniUser(label: 'Şikâyet edilen', user: reported, danger: true)),
                ],
              ),
              const SizedBox(height: 14),
              Text(report['reason']?.toString() ?? 'Sebep belirtilmedi', style: const TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900)),
              if ((report['detail']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(report['detail'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, height: 1.35)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: contextType == 'private_chat' ? Icons.chat_bubble_outline_rounded : Icons.forum_outlined, text: contextText),
                  _InfoPill(icon: Icons.fact_check_outlined, text: '${report['evidenceCount'] ?? 0} kanıt'),
                  if ((reported['previousReportCount'] as num?)?.toInt() != 0)
                    _InfoPill(icon: Icons.history_rounded, text: '${reported['previousReportCount']} önceki şikâyet', danger: true),
                  if (reported['activelyBanned'] == true)
                    const _InfoPill(icon: Icons.block_rounded, text: 'Aktif ban', danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniUser extends StatelessWidget {
  const _MiniUser({required this.label, required this.user, this.danger = false});
  final String label;
  final Map<String, dynamic> user;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final photo = AdminApiService.mediaUrl(user['photoUrl']?.toString());
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: danger ? const Color(0xFFFFECEC) : AppColors.softSurface,
          backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
          child: photo.isEmpty ? Icon(Icons.person_rounded, color: danger ? const Color(0xFFD74747) : AppColors.blue, size: 19) : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(user['displayName']?.toString() ?? 'İsimsiz', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportDetailPanel extends StatefulWidget {
  const _ReportDetailPanel({required this.reportId, required this.onChanged});

  final String reportId;
  final VoidCallback onChanged;

  @override
  State<_ReportDetailPanel> createState() => _ReportDetailPanelState();
}

class _ReportDetailPanelState extends State<_ReportDetailPanel> {
  Map<String, dynamic>? report;
  bool loading = true;
  bool working = false;
  bool canModerate = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AdminApiService.reportDetail(widget.reportId);
      if (!mounted) return;
      setState(() {
        report = Map<String, dynamic>.from((result['report'] as Map?) ?? const {});
        canModerate = result['canModerate'] == true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _action(String action, String label, {bool danger = false}) async {
    if (!canModerate || working) return;
    final note = TextEditingController();
    final reason = TextEditingController(text: report?['reason']?.toString() ?? '');
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action == 'warn' || action.startsWith('ban_')) ...[
                TextField(
                  controller: reason,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Yaptırım nedeni', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: note,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Moderatör notu',
                  hintText: 'İnceleme sonucu, gözlem veya karar notu...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: danger ? const Color(0xFFD74747) : AppColors.blue),
            child: Text(label),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      note.dispose();
      reason.dispose();
      return;
    }
    setState(() => working = true);
    try {
      await AdminApiService.reportAction(
        widget.reportId,
        action: action,
        note: note.text,
        reason: reason.text,
      );
      widget.onChanged();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      note.dispose();
      reason.dispose();
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _toggleEvidence(Map<String, dynamic> item) async {
    if (!canModerate || working) return;
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => working = true);
    try {
      await AdminApiService.markReportEvidence(widget.reportId, id, item['is_key_evidence'] != true);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && report == null) return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    if (error != null && report == null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    final data = report ?? const <String, dynamic>{};
    final reporter = Map<String, dynamic>.from((data['reporter'] as Map?) ?? const {});
    final reported = Map<String, dynamic>.from((data['reported'] as Map?) ?? const {});
    final evidence = ((data['evidenceMessages'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final previous = ((data['previousReports'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final warnings = ((data['warnings'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final bans = ((data['bans'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final notes = ((data['moderatorNotes'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final status = data['status']?.toString() ?? 'open';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 10, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Şikâyet #${data['id'] ?? widget.reportId}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      _StatusChip(status: status),
                    ]),
                    const SizedBox(height: 3),
                    Text('Gönderildi: ${_formatDate(data['createdAt'])}', style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (working) const Padding(padding: EdgeInsets.only(right: 10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))),
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              LayoutBuilder(builder: (context, box) {
                final cards = [
                  _PersonDetailCard(title: 'Şikâyet eden', user: reporter),
                  _PersonDetailCard(title: 'Şikâyet edilen', user: reported, danger: true),
                ];
                if (box.maxWidth >= 720) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]);
                return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
              }),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Şikâyet',
                icon: Icons.report_gmailerrorred_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['reason']?.toString() ?? '-', style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
                    if ((data['detail']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(data['detail'].toString(), style: const TextStyle(color: AppColors.muted, height: 1.45)),
                    ],
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (data['roomId'] != null) _InfoPill(icon: Icons.forum_outlined, text: 'Oda #${data['roomId']}'),
                      if (data['matchId'] != null) _InfoPill(icon: Icons.chat_outlined, text: 'Özel sohbet #${data['matchId']}'),
                      if (data['roomId'] == null && data['matchId'] == null) const _InfoPill(icon: Icons.person_outline_rounded, text: 'Profil şikâyeti'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Kanıt Mesajları',
                icon: Icons.fact_check_outlined,
                trailing: Text('${evidence.length} kayıt', style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
                child: evidence.isEmpty
                    ? const Text('Bu şikâyette mesaj kanıtı bulunmuyor.', style: TextStyle(color: AppColors.muted))
                    : Column(
                        children: evidence.map((item) => _EvidenceMessage(
                          item: item,
                          reportedUserId: reported['userId']?.toString() ?? '',
                          canModerate: canModerate,
                          onToggleKey: () => _toggleEvidence(item),
                        )).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Önceki Şikâyet Geçmişi',
                icon: Icons.history_rounded,
                trailing: Text('${previous.length} kayıt', style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
                child: previous.isEmpty
                    ? const Text('Bu kullanıcı hakkında önceki şikâyet bulunmuyor.', style: TextStyle(color: AppColors.muted))
                    : Column(children: previous.map((item) => _HistoryRow(item: item)).toList()),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Önceki Yaptırımlar',
                icon: Icons.gavel_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warnings.isEmpty && bans.isEmpty)
                      const Text('Uyarı veya ban geçmişi bulunmuyor.', style: TextStyle(color: AppColors.muted)),
                    ...warnings.map((item) => _SanctionRow(icon: Icons.warning_amber_rounded, title: 'Uyarı', text: item['reason']?.toString() ?? '-', date: item['created_at'])),
                    ...bans.map((item) => _SanctionRow(icon: Icons.block_rounded, title: item['ends_at'] == null ? 'Kalıcı ban' : 'Geçici ban', text: item['reason']?.toString() ?? '-', date: item['starts_at'], danger: true)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Moderatör Notları',
                icon: Icons.sticky_note_2_outlined,
                child: notes.isEmpty
                    ? const Text('Henüz moderatör notu eklenmemiş.', style: TextStyle(color: AppColors.muted))
                    : Column(
                        children: notes.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(14)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item['note']?.toString() ?? '-', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, height: 1.4)),
                              const SizedBox(height: 5),
                              Text('${item['admin_name'] ?? 'Admin'} · ${_formatDate(item['created_at'])}', style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        )).toList(),
                      ),
              ),
              if (canModerate) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Moderasyon Kararı',
                  icon: Icons.admin_panel_settings_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yaptırım uygulamak şikâyeti otomatik kapatmaz. İnceleme sonunda Çözüldü veya Reddedildi seç.', style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'open') _ActionButton(label: 'İncelemeye al', icon: Icons.manage_search_rounded, onTap: () => _action('review', 'İncelemeye al')),
                          _ActionButton(label: 'Uyar', icon: Icons.warning_amber_rounded, onTap: () => _action('warn', 'Uyarı gönder')),
                          _ActionButton(label: '24 saat ban', icon: Icons.timer_outlined, danger: true, onTap: () => _action('ban_24h', '24 saat ban', danger: true)),
                          _ActionButton(label: '7 gün ban', icon: Icons.calendar_view_week_rounded, danger: true, onTap: () => _action('ban_7d', '7 gün ban', danger: true)),
                          _ActionButton(label: '30 gün ban', icon: Icons.calendar_month_rounded, danger: true, onTap: () => _action('ban_30d', '30 gün ban', danger: true)),
                          _ActionButton(label: 'Kalıcı ban', icon: Icons.block_rounded, danger: true, onTap: () => _action('ban_permanent', 'Kalıcı ban', danger: true)),
                        ],
                      ),
                      const Divider(height: 28),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status != 'resolved') _ActionButton(label: 'Şikâyeti çöz / kapat', icon: Icons.task_alt_rounded, success: true, onTap: () => _action('resolve', 'Çözüldü olarak kapat')),
                          if (status != 'rejected') _ActionButton(label: 'Reddet', icon: Icons.cancel_outlined, onTap: () => _action('reject', 'Şikâyeti reddet')),
                          if (status == 'resolved' || status == 'rejected') _ActionButton(label: 'Yeniden aç', icon: Icons.replay_rounded, onTap: () => _action('reopen', 'Şikâyeti yeniden aç')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _EvidenceMessage extends StatelessWidget {
  const _EvidenceMessage({required this.item, required this.reportedUserId, required this.canModerate, required this.onToggleKey});
  final Map<String, dynamic> item;
  final String reportedUserId;
  final bool canModerate;
  final VoidCallback onToggleKey;

  @override
  Widget build(BuildContext context) {
    final fromReported = item['sender_user_id']?.toString() == reportedUserId;
    final key = item['is_key_evidence'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: key ? const Color(0xFFFFF7E8) : fromReported ? const Color(0xFFFFF3F3) : AppColors.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: key ? Border.all(color: const Color(0xFFE6A23C)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item['sender_name']?.toString() ?? 'Kullanıcı', style: TextStyle(color: fromReported ? const Color(0xFFD74747) : AppColors.navy, fontSize: 11, fontWeight: FontWeight.w900))),
                Text(_formatDate(item['message_created_at']), style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              Text(item['body']?.toString() ?? '', style: const TextStyle(color: AppColors.navy, height: 1.4)),
              if (key) ...[
                const SizedBox(height: 6),
                const Text('ANA KANIT', style: TextStyle(color: Color(0xFFC17A00), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5)),
              ],
            ]),
          ),
          if (canModerate)
            IconButton(
              tooltip: key ? 'Ana kanıttan çıkar' : 'Ana kanıt olarak işaretle',
              onPressed: onToggleKey,
              icon: Icon(key ? Icons.star_rounded : Icons.star_border_rounded, color: key ? const Color(0xFFE6A23C) : AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _PersonDetailCard extends StatelessWidget {
  const _PersonDetailCard({required this.title, required this.user, this.danger = false});
  final String title;
  final Map<String, dynamic> user;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final photo = AdminApiService.mediaUrl(user['photoUrl']?.toString());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF7F7) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: danger ? const Color(0xFFFFDADA) : AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: danger ? const Color(0xFFFFE7E7) : AppColors.softSurface,
          backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
          child: photo.isEmpty ? Icon(Icons.person_rounded, color: danger ? const Color(0xFFD74747) : AppColors.blue) : null,
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(user['displayName']?.toString() ?? 'İsimsiz kullanıcı', style: const TextStyle(color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('ID ${user['userId'] ?? '-'}${user['city'] == null ? '' : ' · ${user['city']}'}', style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          if (danger && user['accountStatus'] != null) Text('Hesap: ${user['accountStatus']}', style: const TextStyle(color: Color(0xFFD74747), fontSize: 10, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.blue, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatusChip(status: item['status']?.toString() ?? 'open', compact: true),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['reason']?.toString() ?? '-', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${item['reporter_name'] ?? 'Kullanıcı'} · ${_formatDate(item['created_at'])}', style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
}

class _SanctionRow extends StatelessWidget {
  const _SanctionRow({required this.icon, required this.title, required this.text, required this.date, this.danger = false});
  final IconData icon;
  final String title;
  final String text;
  final Object? date;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: danger ? const Color(0xFFD74747) : const Color(0xFFE69B2E), size: 18),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
            Text(text, style: const TextStyle(color: AppColors.muted, height: 1.35)),
            Text(_formatDate(date), style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onTap, this.danger = false, this.success = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD74747) : success ? const Color(0xFF239B68) : AppColors.blue;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(.45)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.compact = false});
  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'reviewing' => ('İnceleniyor', const Color(0xFFE69B2E)),
      'resolved' => ('Çözüldü', const Color(0xFF239B68)),
      'rejected' => ('Reddedildi', AppColors.muted),
      _ => ('Açık', const Color(0xFFD74747)),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: color, fontSize: compact ? 8.5 : 9.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, this.danger = false});
  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: danger ? const Color(0xFFFFECEC) : AppColors.softSurface, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: danger ? const Color(0xFFD74747) : AppColors.blue),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: danger ? const Color(0xFFD74747) : AppColors.navy, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.danger = false});
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: danger ? const Color(0xFFFFECEC) : AppColors.softSurface, borderRadius: BorderRadius.circular(14)),
        child: Text(message, style: TextStyle(color: danger ? const Color(0xFFD74747) : AppColors.navy, fontWeight: FontWeight.w700)),
      );
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: const Column(children: [
          Icon(Icons.verified_user_outlined, color: AppColors.blue, size: 38),
          SizedBox(height: 10),
          Text('Bu filtrede şikâyet yok', style: TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Yeni vakalar geldiğinde burada görünecek.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
      );
}

String _formatDate(Object? raw) {
  final value = raw?.toString() ?? '';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '-';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d.$m.${date.year} $h:$min';
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'admin_live_rooms_screen.dart';
import 'admin_users_screen.dart';
import 'services/admin_api_service.dart';

class AdminMatchesScreen extends StatefulWidget {
  const AdminMatchesScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminMatchesScreen> createState() => _AdminMatchesScreenState();
}

class _AdminMatchesScreenState extends State<AdminMatchesScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> matches = const [];
  bool loading = true;
  String? error;
  String status = 'all';
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

  Future<void> _load({bool firstPage = false, bool silent = false}) async {
    if (firstPage) page = 1;
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await AdminApiService.matches(
        status: status,
        search: searchController.text.trim(),
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        matches = ((result['matches'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        total = _n(result['total']);
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Eşleşmeler yüklenemedi.');
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout().catchError((_) {});
    await SessionService.clearAuth();
    if (mounted) widget.onLogout();
  }

  void _openMatch(String matchId) {
    final width = MediaQuery.sizeOf(context).width;
    final panel = _MatchDetailPanel(
      matchId: matchId,
      onChanged: () => _load(silent: true),
    );
    if (width >= 800) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 880),
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
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _MatchesNav(onLogout: _logout)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _MatchesNav(onLogout: _logout)),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (!wide)
                        Builder(
                          builder: (context) => IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Eşleşmeler',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: loading ? null : () => _load(),
                        tooltip: 'Yenile',
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.blue),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _Header(total: total),
                        const SizedBox(height: 16),
                        _Filters(
                          controller: searchController,
                          status: status,
                          loading: loading,
                          onSearch: () => _load(firstPage: true),
                          onStatus: (value) {
                            setState(() => status = value);
                            _load(firstPage: true);
                          },
                        ),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(color: AppColors.blue),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (!loading && matches.isEmpty)
                          const _Empty()
                        else
                          LayoutBuilder(
                            builder: (context, box) {
                              final desktop = box.maxWidth >= 900;
                              final width = desktop ? (box.maxWidth - 12) / 2 : box.maxWidth;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: matches
                                    .map(
                                      (match) => SizedBox(
                                        width: width,
                                        child: _MatchCard(
                                          match: match,
                                          onTap: () => _openMatch('${match['id']}'),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        const SizedBox(height: 14),
                        _Pagination(
                          page: page,
                          total: total,
                          limit: limit,
                          loading: loading,
                          onPrevious: page <= 1
                              ? null
                              : () {
                                  setState(() => page--);
                                  _load();
                                },
                          onNext: page * limit >= total
                              ? null
                              : () {
                                  setState(() => page++);
                                  _load();
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eşleşme operasyonu', style: TextStyle(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Karşılıklı seçimden doğan özel eşleşmeleri ve güvenlik durumunu incele', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(999)),
            child: Text('$total eşleşme', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
          ),
        ],
      );
}

class _Filters extends StatelessWidget {
  const _Filters({
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: controller,
                enabled: !loading,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: 'İsim, eşleşme ID veya oda ID',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(onPressed: loading ? null : onSearch, icon: const Icon(Icons.arrow_forward_rounded)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  isDense: true,
                ),
              ),
            ),
            for (final item in const [('all', 'Tümü'), ('active', 'Aktif'), ('removed', 'Kaldırılmış')])
              ChoiceChip(
                label: Text(item.$2),
                selected: status == item.$1,
                onSelected: loading ? null : (_) => onStatus(item.$1),
                selectedColor: AppColors.navy,
                backgroundColor: AppColors.softSurface,
                labelStyle: TextStyle(
                  color: status == item.$1 ? AppColors.lime : AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
              ),
          ],
        ),
      );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.onTap});
  final Map<String, dynamic> match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = _map(match['userA']);
    final b = _map(match['userB']);
    final block = _map(match['blockState']);
    final removed = match['status'] == 'removed';
    final reports = _n(match['reportCount']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: reports > 0 ? const Color(0xFFFFC6C6) : AppColors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Eşleşme #${match['id']}', style: const TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  _StatusChip(removed: removed),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Person(user: a)),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppColors.softSurface, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_rounded, color: AppColors.blue, size: 18),
                  ),
                  Expanded(child: _Person(user: b, alignEnd: true)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Metric(icon: Icons.meeting_room_outlined, text: match['sourceRoomId'] == null ? 'Oda bilinmiyor' : 'Oda #${match['sourceRoomId']}'),
                  _Metric(icon: Icons.schedule_rounded, text: _date(match['matchedAt'])),
                  _Metric(icon: Icons.chat_bubble_outline_rounded, text: match['lastMessageAt'] == null ? 'Mesaj yok' : 'Son ${_date(match['lastMessageAt'])}'),
                  _Metric(
                    icon: block['mutual'] == true ? Icons.gpp_bad_rounded : Icons.block_rounded,
                    text: block['mutual'] == true ? 'Karşılıklı engel' : block['any'] == true ? 'Engel var' : 'Engel yok',
                    danger: block['any'] == true,
                  ),
                  _Metric(
                    icon: reports > 0 ? Icons.report_rounded : Icons.verified_user_outlined,
                    text: reports > 0 ? '$reports şikâyet' : 'Şikâyet yok',
                    danger: reports > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.user, this.alignEnd = false});
  final Map<String, dynamic> user;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final url = AdminApiService.mediaUrl(user['photoUrl']?.toString());
    final avatar = CircleAvatar(
      radius: 23,
      backgroundColor: AppColors.softSurface,
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.muted) : null,
    );
    final text = Expanded(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text('${user['displayName'] ?? 'Meet6'}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
          Text('ID ${user['id'] ?? '-'}', style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return Row(
      children: alignEnd ? [text, const SizedBox(width: 8), avatar] : [avatar, const SizedBox(width: 8), text],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.removed});
  final bool removed;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: removed ? const Color(0xFFF0F1F5) : const Color(0xFFE8FFF2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          removed ? 'Kaldırılmış' : 'Aktif',
          style: TextStyle(color: removed ? AppColors.muted : const Color(0xFF157949), fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text, this.danger = false});
  final IconData icon;
  final String text;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: danger ? const Color(0xFFFFEEEE) : AppColors.softSurface, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: danger ? const Color(0xFFC83D3D) : AppColors.blue),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: danger ? const Color(0xFFC83D3D) : AppColors.navy, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _MatchDetailPanel extends StatefulWidget {
  const _MatchDetailPanel({required this.matchId, required this.onChanged});
  final String matchId;
  final VoidCallback onChanged;

  @override
  State<_MatchDetailPanel> createState() => _MatchDetailPanelState();
}

class _MatchDetailPanelState extends State<_MatchDetailPanel> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool actionLoading = false;
  String? error;

  Map<String, dynamic> get match => _map(data?['match']);
  String get role => _map(data?['admin'])['role']?.toString() ?? '';
  bool get canModerate => role == 'moderator' || role == 'super_admin';

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
      final result = await AdminApiService.matchDetail(widget.matchId);
      if (mounted) setState(() => data = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _reason() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eşleşmeyi sonlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 240,
          decoration: const InputDecoration(
            hintText: 'Moderasyon nedeni',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length >= 3) Navigator.pop(context, text);
            },
            child: const Text('Sonlandır'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _endMatch() async {
    final reason = await _reason();
    if (reason == null || actionLoading) return;
    setState(() => actionLoading = true);
    try {
      await AdminApiService.endMatch(widget.matchId, reason);
      await _load();
      widget.onChanged();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eşleşme sonlandırıldı.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    if (error != null && data == null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));

    final a = _map(match['userA']);
    final b = _map(match['userB']);
    final block = _map(match['blockState']);
    final reports = ((match['reports'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final messages = ((match['messages'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final active = match['status'] == 'active';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Eşleşme #${match['id'] ?? widget.matchId}', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 9),
                      _StatusChip(removed: !active),
                    ]),
                    const SizedBox(height: 3),
                    Text(match['sourceRoomId'] == null ? 'Kaynak oda bulunamadı' : 'Oda #${match['sourceRoomId']} içinden çıktı', style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loading) const LinearProgressIndicator(color: AppColors.blue),
              _Section(
                title: 'Eşleşen kullanıcılar',
                child: Row(
                  children: [
                    Expanded(child: _Person(user: a)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.favorite_rounded, color: AppColors.blue)),
                    Expanded(child: _Person(user: b, alignEnd: true)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Eşleşme bilgisi',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Metric(icon: Icons.calendar_month_outlined, text: 'Eşleşti: ${_date(match['matchedAt'])}'),
                    _Metric(icon: Icons.meeting_room_outlined, text: match['sourceRoomId'] == null ? 'Oda bilinmiyor' : 'Oda #${match['sourceRoomId']}'),
                    _Metric(icon: Icons.chat_bubble_outline_rounded, text: match['lastMessageAt'] == null ? 'Mesaj yok' : 'Son mesaj: ${_date(match['lastMessageAt'])}'),
                    _Metric(icon: Icons.chat_outlined, text: '${_n(match['messageCount'])} mesaj'),
                    if (!active) _Metric(icon: Icons.link_off_rounded, text: 'Kaldırıldı: ${_date(match['removedAt'])}', danger: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Engelleme durumu',
                danger: block['any'] == true,
                child: Column(
                  children: [
                    _StateRow(label: '${a['displayName'] ?? 'A'} → ${b['displayName'] ?? 'B'}', active: block['userABlockedUserB'] == true, positiveText: 'Engelledi', negativeText: 'Engellemedi'),
                    _StateRow(label: '${b['displayName'] ?? 'B'} → ${a['displayName'] ?? 'A'}', active: block['userBBlockedUserA'] == true, positiveText: 'Engelledi', negativeText: 'Engellemedi'),
                    if (block['mutual'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(children: [Icon(Icons.gpp_bad_rounded, color: Color(0xFFC83D3D), size: 18), SizedBox(width: 6), Text('İki taraf da birbirini engellemiş.', style: TextStyle(color: Color(0xFFC83D3D), fontWeight: FontWeight.w900))]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Şikâyetler (${reports.length})',
                danger: reports.isNotEmpty,
                child: reports.isEmpty
                    ? const Text('Bu iki kullanıcı arasında şikâyet yok.', style: TextStyle(color: AppColors.muted))
                    : Column(
                        children: reports.map((report) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.report_rounded, color: Color(0xFFC83D3D)),
                          title: Text('${report['reporter_name'] ?? 'Kullanıcı'} → ${report['reported_name'] ?? 'Kullanıcı'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${report['reason'] ?? 'Şikâyet'}${report['detail'] == null ? '' : '\n${report['detail']}'}\n${_date(report['created_at'])} · ${report['status'] ?? ''}'),
                          isThreeLine: true,
                        )).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Özel mesaj geçmişi (${messages.length})',
                child: messages.isEmpty
                    ? const Text('Mesaj yok.', style: TextStyle(color: AppColors.muted))
                    : ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Son mesajları göster', style: TextStyle(fontWeight: FontWeight.w800)),
                        children: messages.map((message) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.blue, size: 18),
                          title: Text('${message['body'] ?? ''}', maxLines: 4, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${message['display_name'] ?? 'Kullanıcı'} · ${_date(message['created_at'])}'),
                        )).toList(),
                      ),
              ),
              if (!active && '${match['adminEndReason'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'Admin sonlandırma kaydı',
                  danger: true,
                  child: Text('${match['adminEndReason']}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
                ),
              ],
              if (active && canModerate) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: actionLoading ? null : _endMatch,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC83D3D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Eşleşmeyi administratör olarak sonlandır', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.label, required this.active, required this.positiveText, required this.negativeText});
  final String label;
  final bool active;
  final String positiveText;
  final String negativeText;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800))),
            Icon(active ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: active ? const Color(0xFFC83D3D) : const Color(0xFF21B573), size: 18),
            const SizedBox(width: 6),
            Text(active ? positiveText : negativeText, style: TextStyle(color: active ? const Color(0xFFC83D3D) : const Color(0xFF157949), fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.danger = false});
  final String title;
  final Widget child;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: danger ? const Color(0xFFFFC6C6) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: danger ? const Color(0xFFC83D3D) : AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.total, required this.limit, required this.loading, required this.onPrevious, required this.onNext});
  final int page;
  final int total;
  final int limit;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : ((total + limit - 1) ~/ limit);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$page / $pages', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        IconButton(onPressed: loading ? null : onPrevious, icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(onPressed: loading ? null : onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(38),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: const Column(
          children: [
            Icon(Icons.favorite_border_rounded, size: 44, color: AppColors.muted),
            SizedBox(height: 10),
            Text('Bu filtrede eşleşme bulunamadı.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _MatchesNav extends StatelessWidget {
  const _MatchesNav({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Dashboard', Icons.dashboard_rounded),
      ('Kullanıcılar', Icons.people_alt_outlined),
      ('Aktif odalar', Icons.forum_outlined),
      ('Eşleşmeler', Icons.favorite_outline_rounded),
      ('Şikâyetler', Icons.report_outlined),
      ('Destek', Icons.support_agent_rounded),
      ('Banlar', Icons.block_rounded),
      ('Audit Log', Icons.history_rounded),
    ];
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: SafeArea(
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: Text('MEET6', style: TextStyle(color: AppColors.lime, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.8))),
            const Align(alignment: Alignment.centerLeft, child: Text('ADMIN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2))),
            const SizedBox(height: 26),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  selected: i == 3,
                  selectedTileColor: Colors.white.withOpacity(.10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(items[i].$2, color: i == 3 ? AppColors.lime : Colors.white70),
                  title: Text(items[i].$1, style: TextStyle(color: i == 3 ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
                  onTap: () {
                    if (i == 0) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } else if (i == 1) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AdminUsersScreen(onLogout: onLogout)));
                    } else if (i == 2) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AdminLiveRoomsScreen(onLogout: onLogout)));
                    } else if (i == 3) {
                      Navigator.maybePop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${items[i].$1} ekranı sıradaki modülde bağlanacak.')));
                    }
                  },
                ),
              ),
            const Spacer(),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: const Icon(Icons.logout_rounded, color: Colors.white70),
              title: const Text('Çıkış yap', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int _n(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _date(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty || raw == 'null') return '-';
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

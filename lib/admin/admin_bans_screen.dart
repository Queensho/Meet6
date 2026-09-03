import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'admin_user_detail_screen.dart';
import 'services/admin_api_service.dart';

class AdminBansScreen extends StatefulWidget {
  const AdminBansScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminBansScreen> createState() => _AdminBansScreenState();
}

class _AdminBansScreenState extends State<AdminBansScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> bans = const [];
  Map<String, dynamic> stats = const {};
  String status = 'active';
  int page = 1;
  int total = 0;
  bool loading = true;
  String? error;
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
      final result = await AdminApiService.bans(
        status: status,
        search: searchController.text.trim(),
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        bans = ((result['bans'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        stats = Map<String, dynamic>.from((result['stats'] as Map?) ?? const {});
        total = (result['total'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        if (e.statusCode == 401) {
          await SessionService.clearAuth();
          if (mounted) widget.onLogout();
        }
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openBan(String banId) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 860),
          child: _BanDetail(
            banId: banId,
            onLogout: widget.onLogout,
          ),
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Banlar & Yönetim', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: AppColors.blue)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(label: 'Aktif ban', value: _num('active'), icon: Icons.block_rounded),
                _StatCard(label: 'Kaldırılmış', value: _num('revoked'), icon: Icons.lock_open_rounded),
                _StatCard(label: 'Süresi dolmuş', value: _num('expired'), icon: Icons.timer_off_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: wide ? 360 : double.infinity,
                    child: TextField(
                      controller: searchController,
                      onSubmitted: (_) => _load(firstPage: true),
                      decoration: const InputDecoration(
                        hintText: 'Kullanıcı, ban nedeni, admin veya ID ara',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'revoked', child: Text('Kaldırılmış')),
                      DropdownMenuItem(value: 'expired', child: Text('Süresi dolmuş')),
                      DropdownMenuItem(value: 'all', child: Text('Tümü')),
                    ],
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => status = value);
                            _load(firstPage: true);
                          },
                  ),
                  FilledButton.icon(
                    onPressed: loading ? null : () => _load(firstPage: true),
                    icon: const Icon(Icons.filter_alt_rounded),
                    label: const Text('Uygula'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: AppColors.blue)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700))),
            const SizedBox(height: 16),
            if (!loading && bans.isEmpty)
              const _EmptyState()
            else if (wide)
              _BanTable(bans: bans, onTap: _openBan)
            else
              ...bans.map((ban) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BanCard(ban: ban, onTap: () => _openBan('${ban['id']}')),
                  )),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$total kayıt', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: page > 1 && !loading ? () { setState(() => page--); _load(); } : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('$page', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(
                  onPressed: page * limit < total && !loading ? () { setState(() => page++); _load(); } : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _num(String key) => (stats[key] as num?)?.toInt() ?? 0;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.blue)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

class _BanTable extends StatelessWidget {
  const _BanTable({required this.bans, required this.onTap});
  final List<Map<String, dynamic>> bans;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.softSurface),
            columns: const [
              DataColumn(label: Text('Kullanıcı')),
              DataColumn(label: Text('Ban nedeni')),
              DataColumn(label: Text('Banlayan admin')),
              DataColumn(label: Text('Başlangıç')),
              DataColumn(label: Text('Bitiş')),
              DataColumn(label: Text('Durum')),
              DataColumn(label: Text('')),
            ],
            rows: bans.map((ban) {
              final user = Map<String, dynamic>.from((ban['user'] as Map?) ?? const {});
              final admin = Map<String, dynamic>.from((ban['bannedBy'] as Map?) ?? const {});
              return DataRow(cells: [
                DataCell(Text('${user['displayName'] ?? '-'}\n${user['phoneMasked'] ?? ''}')),
                DataCell(SizedBox(width: 220, child: Text('${ban['reason'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text('${admin['displayName'] ?? '-'}')),
                DataCell(Text(_date(ban['startsAt']))),
                DataCell(Text(ban['permanent'] == true ? 'Kalıcı' : _date(ban['endsAt']))),
                DataCell(_StateChip('${ban['state']}')),
                DataCell(IconButton(onPressed: () => onTap('${ban['id']}'), icon: const Icon(Icons.chevron_right_rounded, color: AppColors.blue))),
              ]);
            }).toList(),
          ),
        ),
      );
}

class _BanCard extends StatelessWidget {
  const _BanCard({required this.ban, required this.onTap});
  final Map<String, dynamic> ban;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from((ban['user'] as Map?) ?? const {});
    final admin = Map<String, dynamic>.from((ban['bannedBy'] as Map?) ?? const {});
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${user['displayName'] ?? 'İsimsiz kullanıcı'}', style: const TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900))),
            _StateChip('${ban['state']}'),
          ]),
          const SizedBox(height: 6),
          Text('${user['phoneMasked'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('${ban['reason'] ?? ''}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Banlayan: ${admin['displayName'] ?? '-'} · ${_date(ban['startsAt'])}', style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(ban['permanent'] == true ? 'Bitiş: Kalıcı' : 'Bitiş: ${_date(ban['endsAt'])}', style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _BanDetail extends StatefulWidget {
  const _BanDetail({required this.banId, required this.onLogout});
  final String banId;
  final VoidCallback onLogout;

  @override
  State<_BanDetail> createState() => _BanDetailState();
}

class _BanDetailState extends State<_BanDetail> {
  Map<String, dynamic>? ban;
  bool loading = true;
  bool working = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AdminApiService.banDetail(widget.banId);
      if (!mounted) return;
      setState(() => ban = Map<String, dynamic>.from((result['ban'] as Map?) ?? const {}));
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

  Future<void> _revoke() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Banı kaldır'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Ban kaldırma nedeni', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Banı kaldır')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 3) return;
    setState(() => working = true);
    try {
      await AdminApiService.revokeBan(widget.banId, reason);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.blue)));
    if (error != null || ban == null) return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(error ?? 'Ban bulunamadı.')));
    final data = ban!;
    final user = Map<String, dynamic>.from((data['user'] as Map?) ?? const {});
    final admin = Map<String, dynamic>.from((data['bannedBy'] as Map?) ?? const {});
    final history = Map<String, dynamic>.from((data['history'] as Map?) ?? const {});
    final bans = ((history['bans'] as List?) ?? const []).whereType<Map>().toList();
    final warnings = ((history['warnings'] as List?) ?? const []).whereType<Map>().toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
        child: Row(children: [
          const Icon(Icons.gavel_rounded, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text('Ban #${data['id']}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(22), children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${user['displayName'] ?? '-'}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('${user['phoneMasked'] ?? ''} · ${user['city'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ])),
            _StateChip('${data['state']}'),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: '${user['userId']}', onLogout: widget.onLogout))),
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Kullanıcı profilini aç'),
          ),
          const SizedBox(height: 18),
          _InfoBox(title: 'Ban nedeni', value: '${data['reason'] ?? '-'}'),
          const SizedBox(height: 10),
          _InfoBox(title: 'Banlayan admin', value: '${admin['displayName'] ?? '-'} · ${admin['role'] ?? '-'}'),
          const SizedBox(height: 10),
          _InfoBox(title: 'Süre', value: '${_date(data['startsAt'])} → ${data['permanent'] == true ? 'Kalıcı' : _date(data['endsAt'])}'),
          if (data['revokedAt'] != null) ...[
            const SizedBox(height: 10),
            _InfoBox(title: 'Ban kaldırıldı', value: _date(data['revokedAt'])),
          ],
          const SizedBox(height: 22),
          const Text('Önceki yaptırımlar', style: TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('${bans.length} ban · ${warnings.length} uyarı', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...bans.take(12).map((item) => _HistoryTile(
                icon: Icons.block_rounded,
                title: '${item['state'] == 'active' ? 'Aktif ban' : item['state'] == 'revoked' ? 'Kaldırılmış ban' : 'Süresi dolmuş ban'} · ${item['ends_at'] == null ? 'Kalıcı' : _date(item['ends_at'])}',
                subtitle: '${item['reason'] ?? ''}\n${item['admin_name'] ?? 'Admin'} · ${_date(item['starts_at'])}',
              )),
          ...warnings.take(12).map((item) => _HistoryTile(
                icon: Icons.warning_amber_rounded,
                title: 'Uyarı',
                subtitle: '${item['reason'] ?? ''}\n${item['admin_name'] ?? 'Admin'} · ${_date(item['created_at'])}',
              )),
        ]),
      ),
      if (data['state'] == 'active')
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: working ? null : _revoke,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F9D66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(working ? 'İşleniyor...' : 'Banı kaldır', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: AppColors.softSurface, child: Icon(icon, color: AppColors.blue)),
        title: Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.35)),
      );
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.state);
  final String state;
  @override
  Widget build(BuildContext context) {
    final label = state == 'active' ? 'Aktif' : state == 'revoked' ? 'Kaldırıldı' : 'Süresi doldu';
    final background = state == 'active' ? const Color(0xFFFFE9E9) : state == 'revoked' ? const Color(0xFFE9F8F0) : AppColors.softSurface;
    final foreground = state == 'active' ? const Color(0xFFC63D3D) : state == 'revoked' ? const Color(0xFF188A58) : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(38),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [
          Icon(Icons.verified_user_outlined, size: 46, color: AppColors.blue),
          SizedBox(height: 10),
          Text('Bu filtrede ban kaydı yok.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
        ]),
      );
}

String _date(Object? value) {
  if (value == null) return '-';
  final dt = DateTime.tryParse(value.toString())?.toLocal();
  if (dt == null) return value.toString();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

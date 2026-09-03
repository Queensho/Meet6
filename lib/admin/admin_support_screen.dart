import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'admin_user_detail_screen.dart';
import 'services/admin_api_service.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> requests = const [];
  Map<String, dynamic> stats = const {};
  Map<String, dynamic> priorities = const {};
  bool loading = true;
  String? error;
  String status = 'open';
  String priority = 'all';
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
    setState(() { loading = true; error = null; });
    try {
      final result = await AdminApiService.supportRequests(
        status: status,
        priority: priority,
        search: searchController.text.trim(),
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        requests = ((result['requests'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        stats = Map<String, dynamic>.from((result['stats'] as Map?) ?? const {});
        priorities = Map<String, dynamic>.from((result['priorities'] as Map?) ?? const {});
        total = (result['total'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Destek talepleri yüklenemedi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openRequest(String requestId) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 820),
          child: _SupportDetail(requestId: requestId, onLogout: widget.onLogout),
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _logout() async {
    await ApiService.logout().catchError((_) {});
    await SessionService.clearAuth();
    if (mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _SupportNav(onLogout: _logout)),
      body: Row(children: [
        if (wide) SizedBox(width: 250, child: _SupportNav(onLogout: _logout)),
        Expanded(child: Column(children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              if (!wide) Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded))),
              const SizedBox(width: 6),
              const Expanded(child: Text('Destek Talepleri', style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900))),
              IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: AppColors.blue)),
            ]),
          ),
          Expanded(child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Counter('Açık', stats['open'], const Color(0xFFE86B35)),
                _Counter('Cevaplandı', stats['answered'], AppColors.blue),
                _Counter('Kapandı', stats['closed'], const Color(0xFF21B573)),
                _Counter('Yüksek öncelik', priorities['high'], const Color(0xFFD74747)),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 300, child: TextField(controller: searchController, onSubmitted: (_) => _load(firstPage: true), decoration: InputDecoration(hintText: 'Kullanıcı, konu, mesaj veya talep ID', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: () => _load(firstPage: true), icon: const Icon(Icons.arrow_forward_rounded))))),
                DropdownButton<String>(value: status, items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tüm durumlar')),
                  DropdownMenuItem(value: 'open', child: Text('Açık')),
                  DropdownMenuItem(value: 'answered', child: Text('Cevaplandı')),
                  DropdownMenuItem(value: 'closed', child: Text('Kapandı')),
                ], onChanged: (v) { if (v != null) { setState(() => status = v); _load(firstPage: true); } }),
                DropdownButton<String>(value: priority, items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tüm öncelikler')),
                  DropdownMenuItem(value: 'low', child: Text('Düşük')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                ], onChanged: (v) { if (v != null) { setState(() => priority = v); _load(firstPage: true); } }),
              ]),
              if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: AppColors.blue)),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700))),
              const SizedBox(height: 16),
              if (!loading && requests.isEmpty)
                const Padding(padding: EdgeInsets.all(36), child: Center(child: Text('Bu filtrede destek talebi yok.', style: TextStyle(color: AppColors.muted))))
              else
                ...requests.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _SupportCard(item: item, onTap: () => _openRequest('${item['id']}')))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$total talep', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                IconButton(onPressed: page <= 1 || loading ? null : () { setState(() => page--); _load(); }, icon: const Icon(Icons.chevron_left_rounded)),
                Text('$page', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(onPressed: page * limit >= total || loading ? null : () { setState(() => page++); _load(); }, icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ]),
          )),
        ])),
      ]),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.label, this.value, this.color);
  final String label;
  final Object? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 9), Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800))), Text('${value ?? 0}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900))]),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  Color _priorityColor(String value) => value == 'high' ? const Color(0xFFD74747) : value == 'low' ? const Color(0xFF21B573) : AppColors.blue;
  String _priorityLabel(String value) => value == 'high' ? 'Yüksek' : value == 'low' ? 'Düşük' : 'Normal';
  String _statusLabel(String value) => value == 'answered' ? 'Cevaplandı' : value == 'closed' ? 'Kapandı' : 'Açık';

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from((item['user'] as Map?) ?? const {});
    final p = item['priority']?.toString() ?? 'normal';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: p == 'high' && item['status'] == 'open' ? const Color(0x33D74747) : AppColors.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: AppColors.softSurface, child: Text((user['displayName']?.toString().isNotEmpty ?? false) ? user['displayName'].toString()[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(item['topic']?.toString() ?? '-', style: const TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900))), _Pill(_priorityLabel(p), _priorityColor(p)), const SizedBox(width: 6), _Pill(_statusLabel(item['status']?.toString() ?? 'open'), AppColors.navy)]),
            const SizedBox(height: 5),
            Text('${user['displayName'] ?? 'İsimsiz kullanıcı'}${user['city'] != null ? ' · ${user['city']}' : ''}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(item['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, height: 1.35)),
            const SizedBox(height: 8),
            Text(item['createdAt']?.toString() ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)));
}

class _SupportDetail extends StatefulWidget {
  const _SupportDetail({required this.requestId, required this.onLogout});
  final String requestId;
  final VoidCallback onLogout;

  @override
  State<_SupportDetail> createState() => _SupportDetailState();
}

class _SupportDetailState extends State<_SupportDetail> {
  final responseController = TextEditingController();
  Map<String, dynamic>? request;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { responseController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await AdminApiService.supportRequestDetail(widget.requestId);
      if (!mounted) return;
      final value = Map<String, dynamic>.from((result['request'] as Map?) ?? const {});
      setState(() { request = value; responseController.text = value['adminResponse']?.toString() ?? ''; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) { await SessionService.clearAuth(); if (mounted) widget.onLogout(); }
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _action(String action, {String? priority}) async {
    if (saving) return;
    setState(() { saving = true; error = null; });
    try {
      final result = await AdminApiService.supportRequestAction(widget.requestId, action: action, response: action == 'reply' ? responseController.text : null, priority: priority);
      if (!mounted) return;
      setState(() => request = Map<String, dynamic>.from((result['request'] as Map?) ?? const {}));
      if (action == 'reply') responseController.text = request?['adminResponse']?.toString() ?? '';
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && request == null) return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    final user = Map<String, dynamic>.from((request?['user'] as Map?) ?? const {});
    final status = request?['status']?.toString() ?? 'open';
    final priority = request?['priority']?.toString() ?? 'normal';
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 12), child: Row(children: [Expanded(child: Text('Destek #${widget.requestId}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.close_rounded))])),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: user['userId']?.toString() ?? '', onLogout: widget.onLogout))),
          borderRadius: BorderRadius.circular(18),
          child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(18)), child: Row(children: [
            const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person_rounded, color: AppColors.blue)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user['displayName']?.toString() ?? 'İsimsiz kullanıcı', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)), Text('${user['age'] ?? '-'} yaş · ${user['city'] ?? '-'}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))])),
            const Text('Profili aç', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w900)), const SizedBox(width: 5), const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.blue),
          ])),
        ),
        const SizedBox(height: 16),
        _DetailBlock('Konu', request?['topic']?.toString() ?? '-'),
        const SizedBox(height: 10),
        _DetailBlock('Kullanıcının mesajı', request?['message']?.toString() ?? '-'),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _DetailBlock('Tarih', request?['createdAt']?.toString() ?? '-')), const SizedBox(width: 10), Expanded(child: _DetailBlock('Durum', status)), const SizedBox(width: 10), Expanded(child: _DetailBlock('Öncelik', priority))]),
        const SizedBox(height: 18),
        const Text('Öncelik', style: TextStyle(color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'low', label: Text('Düşük')), ButtonSegment(value: 'normal', label: Text('Normal')), ButtonSegment(value: 'high', label: Text('Yüksek'))], selected: {priority}, onSelectionChanged: saving ? null : (v) => _action('set_priority', priority: v.first)),
        const SizedBox(height: 18),
        TextField(controller: responseController, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Admin cevabı', hintText: 'Kullanıcıya gönderilecek yanıt...', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: saving ? null : () => _action('reply'), icon: const Icon(Icons.send_rounded), label: const Text('Cevabı gönder'), style: FilledButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48))),
        const SizedBox(height: 10),
        if (status == 'closed') OutlinedButton.icon(onPressed: saving ? null : () => _action('reopen'), icon: const Icon(Icons.restart_alt_rounded), label: const Text('Talebi yeniden aç'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))) else OutlinedButton.icon(onPressed: saving ? null : () => _action('close'), icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Talebi kapat'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700))),
      ])),
    ]);
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock(this.title, this.value);
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, height: 1.35))]));
}

class _SupportNav extends StatelessWidget {
  const _SupportNav({required this.onLogout});
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Container(color: AppColors.navy, padding: const EdgeInsets.fromLTRB(16, 22, 16, 18), child: SafeArea(child: Column(children: [
    const Align(alignment: Alignment.centerLeft, child: Text('MEET6', style: TextStyle(color: AppColors.lime, fontSize: 24, fontWeight: FontWeight.w900))),
    const Align(alignment: Alignment.centerLeft, child: Text('ADMIN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2))),
    const SizedBox(height: 26),
    ListTile(selected: true, selectedTileColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: const Icon(Icons.support_agent_rounded, color: AppColors.lime), title: const Text('Destek Talepleri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
    const Spacer(),
    ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.white70), title: const Text('Çıkış yap', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)), onTap: onLogout),
  ])));
}

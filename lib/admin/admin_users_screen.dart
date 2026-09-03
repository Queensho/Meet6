import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'services/admin_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> users = const [];
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

  Future<void> _load({bool firstPage = false}) async {
    if (firstPage) page = 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AdminApiService.users(
        search: searchController.text.trim(),
        status: status,
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        users = ((result['users'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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
      if (mounted) setState(() => error = 'Kullanıcılar yüklenemedi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout().catchError((_) {});
    await SessionService.clearAuth();
    if (mounted) widget.onLogout();
  }

  void _openUser(String userId) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 760) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940, maxHeight: 860),
            child: _UserDetailPanel(
              userId: userId,
              onChanged: () => _load(),
            ),
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
        builder: (_) => FractionallySizedBox(
          heightFactor: .94,
          child: _UserDetailPanel(
            userId: userId,
            onChanged: () => _load(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _UsersNav(onLogout: _logout)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _UsersNav(onLogout: _logout)),
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
                          'Kullanıcılar',
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
                              style: const TextStyle(
                                color: Color(0xFFD74747),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (!loading && users.isEmpty)
                          const _EmptyUsers()
                        else if (wide)
                          _DesktopUsersTable(users: users, onTap: _openUser)
                        else
                          ...users.map((user) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _MobileUserCard(user: user, onTap: () => _openUser('${user['id']}')),
                              )),
                        const SizedBox(height: 16),
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kullanıcı yönetimi',
                style: TextStyle(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                'Profil, aktivite ve moderasyon işlemleri',
                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$total kullanıcı',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: TextField(
              controller: controller,
              enabled: !loading,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                hintText: 'İsim, telefon veya şehir ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(onPressed: loading ? null : onSearch, icon: const Icon(Icons.arrow_forward_rounded)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
          ),
          DropdownButton<String>(
            value: status,
            borderRadius: BorderRadius.circular(16),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tüm kullanıcılar')),
              DropdownMenuItem(value: 'active', child: Text('Aktif')),
              DropdownMenuItem(value: 'banned', child: Text('Banlı')),
              DropdownMenuItem(value: 'incomplete', child: Text('Profil eksik')),
            ],
            onChanged: loading ? null : (value) => value == null ? null : onStatus(value),
          ),
        ],
      ),
    );
  }
}

class _DesktopUsersTable extends StatelessWidget {
  const _DesktopUsersTable({required this.users, required this.onTap});
  final List<Map<String, dynamic>> users;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.softSurface),
          columns: const [
            DataColumn(label: Text('Kullanıcı')),
            DataColumn(label: Text('Telefon')),
            DataColumn(label: Text('Şehir')),
            DataColumn(label: Text('Profil')),
            DataColumn(label: Text('Oda / Eşleşme')),
            DataColumn(label: Text('Şikâyet')),
            DataColumn(label: Text('Durum')),
          ],
          rows: users.map((user) {
            final id = '${user['id']}';
            return DataRow(
              onSelectChanged: (_) => onTap(id),
              cells: [
                DataCell(_UserIdentity(user: user)),
                DataCell(Text('${user['phoneMasked'] ?? '-'}')),
                DataCell(Text(_location(user))),
                DataCell(_ProfileState(user: user)),
                DataCell(Text('${_n(user['roomCount'])} / ${_n(user['matchCount'])}')),
                DataCell(Text('${_n(user['reportsReceived'])} aldı · ${_n(user['reportsMade'])} yaptı')),
                DataCell(_StatusChip(user: user)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MobileUserCard extends StatelessWidget {
  const _MobileUserCard({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _UserIdentity(user: user)),
                  _StatusChip(user: user),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniMetric(label: 'Oda', value: '${_n(user['roomCount'])}')),
                  Expanded(child: _MiniMetric(label: 'Eşleşme', value: '${_n(user['matchCount'])}')),
                  Expanded(child: _MiniMetric(label: 'Şikâyet', value: '${_n(user['reportsReceived'])}')),
                  Expanded(child: _MiniMetric(label: 'Engel', value: '${_n(user['blockCount'])}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 5),
                  Text('${user['phoneMasked'] ?? '-'}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const Spacer(),
                  Text(_location(user), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final url = AdminApiService.mediaUrl(user['photoUrl']?.toString());
    final age = user['age'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.softSurface,
          backgroundImage: url.isEmpty ? null : NetworkImage(url),
          child: url.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.muted) : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user['displayName'] ?? 'İsimsiz'}${age == null ? '' : ', $age'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                user['online'] == true ? 'Şu an online' : 'Son: ${_date(user['lastSeenAt'])}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: user['online'] == true ? const Color(0xFF1A8F5A) : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileState extends StatelessWidget {
  const _ProfileState({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final complete = user['profileCompleted'] == true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(complete ? Icons.check_circle_rounded : Icons.timelapse_rounded, size: 17, color: complete ? const Color(0xFF1A8F5A) : const Color(0xFFE09A25)),
        const SizedBox(width: 5),
        Text(complete ? 'Tamam' : 'Eksik'),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final banned = user['status'] == 'banned';
    final online = user['online'] == true;
    final label = banned ? 'Banlı' : online ? 'Online' : 'Aktif';
    final bg = banned ? const Color(0xFFFFE8E8) : online ? const Color(0xFFE8FFF2) : AppColors.softSurface;
    final fg = banned ? const Color(0xFFC83D3D) : online ? const Color(0xFF157949) : AppColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.total,
    required this.limit,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

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

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: const Column(
        children: [
          Icon(Icons.person_search_rounded, size: 42, color: AppColors.muted),
          SizedBox(height: 10),
          Text('Bu filtrede kullanıcı bulunamadı.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _UserDetailPanel extends StatefulWidget {
  const _UserDetailPanel({required this.userId, required this.onChanged});
  final String userId;
  final VoidCallback onChanged;

  @override
  State<_UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends State<_UserDetailPanel> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? history;
  bool loading = true;
  bool actionLoading = false;
  bool historyLoading = false;
  String? error;

  Map<String, dynamic> get user => Map<String, dynamic>.from((data?['user'] as Map?) ?? const {});
  String get role => ((data?['admin'] as Map?)?['role'] ?? '').toString();
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
      final result = await AdminApiService.userDetail(widget.userId);
      if (mounted) setState(() => data = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _askReason(String title, {String hint = 'Moderasyon nedeni'}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
          ],
        ),
      ) ??
      false;

  Future<void> _action(String action, {int? durationHours}) async {
    if (actionLoading) return;
    String? reason;
    if (action == 'warn' || action == 'ban') {
      reason = await _askReason(action == 'warn' ? 'Kullanıcıyı uyar' : 'Ban nedeni');
      if (reason == null) return;
    } else {
      final ok = await _confirm(
        action == 'unban' ? 'Banı kaldır' : 'Matchmaking’den çıkar',
        action == 'unban'
            ? 'Kullanıcının aktif banı kaldırılacak.'
            : 'Kullanıcı eşleşme kuyruğundaysa kuyruktan çıkarılacak.',
      );
      if (!ok) return;
    }
    setState(() => actionLoading = true);
    try {
      await AdminApiService.userAction(
        widget.userId,
        action: action,
        reason: reason,
        durationHours: durationHours,
      );
      await _load();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moderasyon işlemi uygulandı.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _removePhoto(String url) async {
    final ok = await _confirm('Fotoğrafı kaldır', 'Bu fotoğraf kullanıcının profilinden ve upload dizininden kaldırılacak.');
    if (!ok) return;
    setState(() => actionLoading = true);
    try {
      await AdminApiService.removePhoto(widget.userId, url);
      await _load();
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (historyLoading) return;
    setState(() => historyLoading = true);
    try {
      final result = await AdminApiService.moderationHistory(widget.userId);
      if (mounted) setState(() => history = result);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (error != null && data == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    }

    final photos = ((user['photoUrls'] as List?) ?? const []).map((e) => e.toString()).toList();
    final stats = Map<String, dynamic>.from((user['stats'] as Map?) ?? const {});
    final completion = (user['profileCompletion'] as num?)?.toInt() ?? 0;
    final banned = user['status'] == 'banned';
    final warnings = ((user['warnings'] as List?) ?? const []).whereType<Map>().toList();

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
                    Text('${user['displayName'] ?? 'Kullanıcı'}', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('${user['phoneMasked'] ?? '-'} · ID ${user['id'] ?? '-'}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              _StatusChip(user: {'status': user['status'], 'online': user['online']}),
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loading) const LinearProgressIndicator(color: AppColors.blue),
              _DetailTop(user: user, completion: completion),
              const SizedBox(height: 18),
              _StatsGrid(stats: stats),
              const SizedBox(height: 18),
              _Section(
                title: 'Fotoğraflar',
                child: photos.isEmpty
                    ? const Text('Profil fotoğrafı yok.', style: TextStyle(color: AppColors.muted))
                    : SizedBox(
                        height: 165,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            final raw = photos[index];
                            final url = AdminApiService.mediaUrl(raw);
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(url, width: 128, height: 165, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 128, color: AppColors.softSurface, child: const Icon(Icons.broken_image_outlined))),
                                ),
                                if (canModerate)
                                  Positioned(
                                    right: 5,
                                    top: 5,
                                    child: IconButton.filled(
                                      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                                      iconSize: 17,
                                      onPressed: actionLoading ? null : () => _removePhoto(raw),
                                      icon: const Icon(Icons.delete_outline_rounded),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'Profil bilgileri',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow('Yaş', '${user['age'] ?? '-'}'),
                    _InfoRow('Cinsiyet', '${user['gender'] ?? '-'}'),
                    _InfoRow('Şehir', '${user['city'] ?? '-'} / ${user['country'] ?? '-'}'),
                    _InfoRow('Kayıt tarihi', _date(user['createdAt'])),
                    _InfoRow('Son görülme', user['online'] == true ? 'Şu an online' : _date(user['lastSeenAt'])),
                    _InfoRow('Kesin konum', user['hasPreciseLocation'] == true ? 'Profilde kayıtlı (koordinat gösterilmiyor)' : 'Yok'),
                    const SizedBox(height: 10),
                    Text('${user['bio'] ?? 'Bio yok'}', style: const TextStyle(color: AppColors.navy, height: 1.45)),
                    const SizedBox(height: 10),
                    Text('${user['profilePrompt'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    if ('${user['profileAnswer'] ?? ''}'.isNotEmpty)
                      Text('${user['profileAnswer']}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ((user['interests'] as List?) ?? const [])
                          .map((e) => Chip(label: Text('$e'), visualDensity: VisualDensity.compact))
                          .toList(),
                    ),
                  ],
                ),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 18),
                _Section(
                  title: 'Uyarılar',
                  child: Column(
                    children: warnings.map((warning) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE09A25)),
                          title: Text('${warning['reason'] ?? '-'}'),
                          subtitle: Text(_date(warning['created_at'])),
                        )).toList(),
                  ),
                ),
              ],
              if (canModerate) ...[
                const SizedBox(height: 18),
                _Section(
                  title: 'Moderasyon',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(onPressed: actionLoading ? null : () => _action('warn'), icon: const Icon(Icons.warning_amber_rounded), label: const Text('Uyar')),
                      if (!banned) ...[
                        OutlinedButton(onPressed: actionLoading ? null : () => _action('ban', durationHours: 24), child: const Text('24 saat ban')),
                        OutlinedButton(onPressed: actionLoading ? null : () => _action('ban', durationHours: 24 * 7), child: const Text('7 gün ban')),
                        OutlinedButton(onPressed: actionLoading ? null : () => _action('ban', durationHours: 24 * 30), child: const Text('30 gün ban')),
                        FilledButton.tonal(onPressed: actionLoading ? null : () => _action('ban'), child: const Text('Kalıcı ban')),
                      ] else
                        FilledButton.tonalIcon(onPressed: actionLoading ? null : () => _action('unban'), icon: const Icon(Icons.lock_open_rounded), label: const Text('Banı kaldır')),
                      OutlinedButton.icon(onPressed: actionLoading ? null : () => _action('remove_matchmaking'), icon: const Icon(Icons.person_remove_alt_1_outlined), label: const Text('Matchmaking’den çıkar')),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Mesaj / oda geçmişi',
                  child: history == null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: historyLoading ? null : _loadHistory,
                            icon: historyLoading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.visibility_outlined),
                            label: const Text('Moderasyon geçmişini görüntüle'),
                          ),
                        )
                      : _ModerationHistory(data: history!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTop extends StatelessWidget {
  const _DetailTop({required this.user, required this.completion});
  final Map<String, dynamic> user;
  final int completion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profil tamamlanma', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('%$completion', style: const TextStyle(color: AppColors.lime, fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: completion / 100, minHeight: 7, color: AppColors.lime, backgroundColor: Colors.white12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Icon(user['profileCompleted'] == true ? Icons.verified_rounded : Icons.pending_outlined, size: 42, color: user['profileCompleted'] == true ? AppColors.lime : Colors.white54),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Oda', _n(stats['rooms'])),
      ('Eşleşme', _n(stats['matches'])),
      ('Aldığı şikâyet', _n(stats['reportsReceived'])),
      ('Yaptığı şikâyet', _n(stats['reportsMade'])),
      ('Engel', _n(stats['blocks'])),
      ('Oda mesajı', _n(stats['roomMessages'])),
      ('Özel mesaj', _n(stats['privateMessages'])),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((item) => Container(
            width: 112,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.$2}', style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(item.$1, style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          )).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 115, child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}

class _ModerationHistory extends StatelessWidget {
  const _ModerationHistory({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rooms = ((data['rooms'] as List?) ?? const []).whereType<Map>().toList();
    final roomMessages = ((data['roomMessages'] as List?) ?? const []).whereType<Map>().toList();
    final privateMessages = ((data['privateMessages'] as List?) ?? const []).whereType<Map>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Son ${rooms.length} oda · ${roomMessages.length} oda mesajı · ${privateMessages.length} özel mesaj', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (rooms.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Son odalar', style: TextStyle(fontWeight: FontWeight.w800)),
            children: rooms.map((room) => ListTile(
                  dense: true,
                  title: Text('Oda #${room['id']} · ${room['status']}'),
                  subtitle: Text('${_date(room['started_at'])} · ${room['message_count'] ?? 0} mesaj'),
                )).toList(),
          ),
        if (roomMessages.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Kullanıcının oda mesajları', style: TextStyle(fontWeight: FontWeight.w800)),
            children: roomMessages.map((msg) => ListTile(
                  dense: true,
                  title: Text('${msg['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Oda #${msg['room_id']} · ${_date(msg['created_at'])}'),
                )).toList(),
          ),
        if (privateMessages.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Kullanıcının özel mesajları', style: TextStyle(fontWeight: FontWeight.w800)),
            children: privateMessages.map((msg) => ListTile(
                  dense: true,
                  title: Text('${msg['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Eşleşme #${msg['match_id']} · ${_date(msg['created_at'])}'),
                )).toList(),
          ),
      ],
    );
  }
}

class _UsersNav extends StatelessWidget {
  const _UsersNav({required this.onLogout});
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
                  selected: i == 1,
                  selectedTileColor: Colors.white.withOpacity(.10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(items[i].$2, color: i == 1 ? AppColors.lime : Colors.white70),
                  title: Text(items[i].$1, style: TextStyle(color: i == 1 ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
                  onTap: () {
                    if (i == 0) {
                      Navigator.maybePop(context);
                    } else if (i != 1) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${items[i].$1} ekranı sıradaki modülde bağlanacak.')));
                    } else {
                      Navigator.maybePop(context);
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

int _n(dynamic value) => (value as num?)?.toInt() ?? int.tryParse('$value') ?? 0;

String _location(Map<String, dynamic> user) {
  final city = '${user['city'] ?? ''}'.trim();
  final country = '${user['country'] ?? ''}'.trim();
  if (city.isEmpty && country.isEmpty) return '-';
  if (country.isEmpty) return city;
  if (city.isEmpty) return country;
  return '$city, $country';
}

String _date(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty || raw == 'null') return '-';
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

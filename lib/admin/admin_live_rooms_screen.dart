import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'admin_users_screen.dart';
import 'services/admin_api_service.dart';

class AdminLiveRoomsScreen extends StatefulWidget {
  const AdminLiveRoomsScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminLiveRoomsScreen> createState() => _AdminLiveRoomsScreenState();
}

class _AdminLiveRoomsScreenState extends State<AdminLiveRoomsScreen> {
  List<Map<String, dynamic>> rooms = const [];
  bool loading = true;
  String? error;
  String status = 'live';
  int page = 1;
  int total = 0;
  static const limit = 20;
  Timer? ticker;
  bool stageRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || rooms.isEmpty) return;
    var changed = false;
    var hitZero = false;
    final next = rooms.map((room) {
      final current = (room['remainingSeconds'] as num?)?.toInt() ?? 0;
      final live = room['status'] == 'active' || room['status'] == 'selection';
      if (!live || current <= 0) return room;
      changed = true;
      final updated = Map<String, dynamic>.from(room);
      updated['remainingSeconds'] = current - 1;
      if (current == 1) hitZero = true;
      return updated;
    }).toList();
    if (changed) setState(() => rooms = next);
    if (hitZero && !stageRefreshScheduled) {
      stageRefreshScheduled = true;
      Future<void>.delayed(const Duration(milliseconds: 700), () async {
        if (mounted) await _load(silent: true);
        stageRefreshScheduled = false;
      });
    }
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
      final result = await AdminApiService.rooms(
        status: status,
        page: page,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        rooms = ((result['rooms'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        total = (result['total'] as num?)?.toInt() ?? 0;
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
      if (mounted) setState(() => error = 'Odalar yüklenemedi.');
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout().catchError((_) {});
    await SessionService.clearAuth();
    if (mounted) widget.onLogout();
  }

  void _openRoom(String roomId) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 820) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 900),
            child: _RoomDetailPanel(
              roomId: roomId,
              onChanged: () => _load(silent: true),
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
          heightFactor: .96,
          child: _RoomDetailPanel(
            roomId: roomId,
            onChanged: () => _load(silent: true),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: wide ? null : Drawer(child: _RoomsNav(onLogout: _logout)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _RoomsNav(onLogout: _logout)),
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
                          'Canlı Odalar',
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
                        _RoomsHeader(total: total, live: status == 'live'),
                        const SizedBox(height: 16),
                        _RoomFilters(
                          status: status,
                          loading: loading,
                          onChanged: (value) {
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
                        if (!loading && rooms.isEmpty)
                          const _EmptyRooms()
                        else
                          LayoutBuilder(
                            builder: (context, box) {
                              final desktop = box.maxWidth >= 900;
                              final cardWidth = desktop ? (box.maxWidth - 12) / 2 : box.maxWidth;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: rooms
                                    .map(
                                      (room) => SizedBox(
                                        width: cardWidth,
                                        child: _RoomCard(
                                          room: room,
                                          onTap: () => _openRoom('${room['id']}'),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        _RoomPagination(
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

class _RoomsHeader extends StatelessWidget {
  const _RoomsHeader({required this.total, required this.live});
  final int total;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                live ? 'Canlı operasyon' : 'Oda geçmişi',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                live
                    ? '6 kişilik odaların bağlantı, mesaj ve moderasyon durumu'
                    : 'Tamamlanan odaları katılımcı ve olay geçmişiyle incele',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
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
            '$total oda',
            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _RoomFilters extends StatelessWidget {
  const _RoomFilters({required this.status, required this.loading, required this.onChanged});
  final String status;
  final bool loading;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = [
      ('live', 'Canlı'),
      ('active', 'Sohbet / +5'),
      ('selection', 'Seçim'),
      ('closed', 'Biten'),
      ('all', 'Tümü'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: values.map((item) {
          final selected = item.$1 == status;
          return ChoiceChip(
            label: Text(item.$2),
            selected: selected,
            onSelected: loading ? null : (_) => onChanged(item.$1),
            selectedColor: AppColors.navy,
            backgroundColor: AppColors.softSurface,
            labelStyle: TextStyle(
              color: selected ? AppColors.lime : AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide.none,
          );
        }).toList(),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final Map<String, dynamic> room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final participants = ((room['participants'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final reports = _n(room['reportCount']);
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
                  Text(
                    'Oda #${room['id']}',
                    style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  _StageChip(stage: '${room['stage'] ?? 'chat'}'),
                  const Spacer(),
                  if (room['status'] != 'closed')
                    _Countdown(seconds: _n(room['remainingSeconds'])),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Başlangıç: ${_date(room['startedAt'])}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, index) => _ParticipantAvatar(member: participants[index]),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoomMetric(icon: Icons.people_alt_outlined, text: '${_n(room['activeMemberCount'])}/${_n(room['originalMemberCount'])} kişi'),
                  _RoomMetric(icon: Icons.chat_bubble_outline_rounded, text: '${_n(room['messageCount'])} mesaj'),
                  _RoomMetric(icon: Icons.sync_rounded, text: '${_n(room['reconnectCount'])} reconnect'),
                  _RoomMetric(
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

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.member});
  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final url = AdminApiService.mediaUrl(member['photoUrl']?.toString());
    final connected = member['connected'] == true;
    final removed = member['removed'] == true || member['removedByAdmin'] == true;
    final name = '${member['displayName'] ?? 'Meet6'}';
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.softSurface,
                backgroundImage: url.isEmpty ? null : NetworkImage(url),
                child: url.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.muted, size: 20) : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: removed
                        ? const Color(0xFFE15A5A)
                        : connected
                            ? const Color(0xFF21B573)
                            : const Color(0xFF9AA1B5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            name.split(' ').first,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RoomMetric extends StatelessWidget {
  const _RoomMetric({required this.icon, required this.text, this.danger = false});
  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFEEEE) : AppColors.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: danger ? const Color(0xFFC83D3D) : AppColors.blue),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: danger ? const Color(0xFFC83D3D) : AppColors.navy,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final value = switch (stage) {
      'extension' => ('+5 dk', const Color(0xFFEAF7FF), AppColors.blue),
      'selection' => ('Seçim', const Color(0xFFFFF1D8), const Color(0xFFB56E00)),
      'closed' => ('Kapalı', const Color(0xFFF0F1F5), AppColors.muted),
      _ => ('Normal sohbet', const Color(0xFFE8FFF2), const Color(0xFF157949)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: value.$2, borderRadius: BorderRadius.circular(999)),
      child: Text(value.$1, style: TextStyle(color: value.$3, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final s = seconds.clamp(0, 60 * 60);
    final text = '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _RoomDetailPanel extends StatefulWidget {
  const _RoomDetailPanel({required this.roomId, required this.onChanged});
  final String roomId;
  final VoidCallback onChanged;

  @override
  State<_RoomDetailPanel> createState() => _RoomDetailPanelState();
}

class _RoomDetailPanelState extends State<_RoomDetailPanel> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool actionLoading = false;
  String? error;
  Timer? ticker;
  int remaining = 0;

  Map<String, dynamic> get room => Map<String, dynamic>.from((data?['room'] as Map?) ?? const {});
  String get role => ((data?['admin'] as Map?)?['role'] ?? '').toString();
  bool get canModerate => role == 'moderator' || role == 'super_admin';
  bool get live => room['status'] == 'active' || room['status'] == 'selection';

  @override
  void initState() {
    super.initState();
    _load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && remaining > 0) setState(() => remaining--);
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AdminApiService.roomDetail(widget.roomId);
      if (!mounted) return;
      setState(() {
        data = result;
        remaining = _n((result['room'] as Map?)?['remainingSeconds']);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _reason(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 240,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length >= 3) Navigator.pop(context, text);
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _closeRoom() async {
    final reason = await _reason('Odayı kapat', 'Kapatma nedeni');
    if (reason == null || actionLoading) return;
    setState(() => actionLoading = true);
    try {
      await AdminApiService.closeRoom(widget.roomId, reason);
      await _load();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oda kapatıldı.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _removeMember(String userId, String displayName) async {
    final reason = await _reason('$displayName kişisini çıkar', 'Odadan çıkarma nedeni');
    if (reason == null || actionLoading) return;
    setState(() => actionLoading = true);
    try {
      await AdminApiService.removeRoomMember(widget.roomId, userId, reason);
      await _load();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$displayName odadan çıkarıldı.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => actionLoading = false);
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

    final participants = ((room['participants'] as List?) ?? const []).whereType<Map>().toList();
    final messages = ((room['messages'] as List?) ?? const []).whereType<Map>().toList();
    final reports = ((room['reports'] as List?) ?? const []).whereType<Map>().toList();
    final votes = ((room['extensionVotes'] as List?) ?? const []).whereType<Map>().toList();
    final selections = ((room['selections'] as List?) ?? const []).whereType<Map>().toList();
    final closed = room['status'] == 'closed';

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
                    Row(
                      children: [
                        Text('Oda #${room['id'] ?? widget.roomId}', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 9),
                        _StageChip(stage: '${room['stage'] ?? 'chat'}'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      closed ? 'Geçmiş oda kaydı' : 'Canlı oda operasyonu',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (!closed) _Countdown(seconds: remaining),
              const SizedBox(width: 4),
              IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loading) const LinearProgressIndicator(color: AppColors.blue),
              _RoomOverview(room: room, remaining: remaining),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Katılımcılar (${participants.length})',
                child: Column(
                  children: participants.map((raw) {
                    final member = Map<String, dynamic>.from(raw);
                    final removed = member['removedByAdmin'] == true;
                    final left = member['leftAt'] != null;
                    return _ParticipantRow(
                      member: member,
                      canRemove: canModerate && live && !removed && !left,
                      actionLoading: actionLoading,
                      onRemove: () => _removeMember(
                        '${member['userId']}',
                        '${member['displayName'] ?? 'Kullanıcı'}',
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (reports.isNotEmpty)
                _DetailSection(
                  title: 'Şikâyetler (${reports.length})',
                  danger: true,
                  child: Column(
                    children: reports.map((raw) {
                      final report = Map<String, dynamic>.from(raw);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.report_rounded, color: Color(0xFFC83D3D)),
                        title: Text('${report['reason'] ?? 'Şikâyet'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${report['reporter_name'] ?? 'Kullanıcı'} → ${report['reported_name'] ?? 'Kullanıcı'}\n${report['detail'] ?? ''}\n${_date(report['created_at'])}',
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                ),
              if (reports.isNotEmpty) const SizedBox(height: 16),
              _DetailSection(
                title: 'Mesaj geçmişi (${_n(room['messageCount'])})',
                child: messages.isEmpty
                    ? const Text('Mesaj yok.', style: TextStyle(color: AppColors.muted))
                    : ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text('Son ${messages.length} mesajı göster', style: const TextStyle(fontWeight: FontWeight.w800)),
                        children: messages.map((raw) {
                          final msg = Map<String, dynamic>.from(raw);
                          final system = msg['sender_user_id'] == null;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(system ? Icons.info_outline_rounded : Icons.chat_bubble_outline_rounded, size: 18, color: system ? AppColors.muted : AppColors.blue),
                            title: Text('${msg['body'] ?? ''}', maxLines: 4, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${system ? 'Sistem' : (msg['display_name'] ?? 'Kullanıcı')} · ${_date(msg['created_at'])}'),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Uzatma oylaması',
                child: votes.isEmpty
                    ? const Text('Uzatma oyu yok.', style: TextStyle(color: AppColors.muted))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: votes.map((raw) {
                          final vote = Map<String, dynamic>.from(raw);
                          final yes = vote['vote'] == true;
                          return Chip(
                            avatar: Icon(yes ? Icons.check_rounded : Icons.close_rounded, size: 17),
                            label: Text('${vote['display_name'] ?? 'Kullanıcı'}: ${yes ? 'Evet' : 'Hayır'}'),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: closed ? 'Gizli seçim geçmişi' : 'Gizli seçim',
                child: closed
                    ? selections.isEmpty
                        ? const Text('Seçim kaydı yok.', style: TextStyle(color: AppColors.muted))
                        : Column(
                            children: selections.map((raw) {
                              final selection = Map<String, dynamic>.from(raw);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.lock_open_rounded, color: AppColors.blue),
                                title: Text('${selection['chooser_name'] ?? 'Kullanıcı'} → ${selection['selected_name'] ?? 'Kullanıcı'}'),
                                subtitle: Text(_date(selection['updated_at'])),
                              );
                            }).toList(),
                          )
                    : Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selections.length} kişi seçim yaptı. Oda kapanana kadar seçim hedefleri gizlidir.',
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
              ),
              if (closed && '${room['closedReason'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Kapanış',
                  child: Text(
                    '${room['closedReason']}',
                    style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (canModerate && live) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: actionLoading ? null : _closeRoom,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC83D3D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Odayı kapat', style: TextStyle(fontWeight: FontWeight.w900)),
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

class _RoomOverview extends StatelessWidget {
  const _RoomOverview({required this.room, required this.remaining});
  final Map<String, dynamic> room;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(20)),
      child: Wrap(
        spacing: 22,
        runSpacing: 14,
        children: [
          _OverviewItem(label: 'Başlangıç', value: _date(room['startedAt'])),
          _OverviewItem(label: 'Aşama', value: _stageLabel('${room['stage'] ?? 'chat'}')),
          _OverviewItem(label: 'Kalan', value: room['status'] == 'closed' ? 'Tamamlandı' : _duration(remaining)),
          _OverviewItem(label: 'Mesaj', value: '${_n(room['messageCount'])}'),
          _OverviewItem(label: 'Reconnect', value: '${_n(room['reconnectCount'])}'),
          _OverviewItem(label: 'Şikâyet', value: '${_n(room['reportCount'])}'),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.lime, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.member,
    required this.canRemove,
    required this.actionLoading,
    required this.onRemove,
  });
  final Map<String, dynamic> member;
  final bool canRemove;
  final bool actionLoading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = AdminApiService.mediaUrl(member['photoUrl']?.toString());
    final connected = member['connected'] == true;
    final reconnect = _n(member['reconnectCount']);
    final removed = member['removedByAdmin'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                backgroundImage: url.isEmpty ? null : NetworkImage(url),
                child: url.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.muted) : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: connected ? const Color(0xFF21B573) : const Color(0xFF9AA1B5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${member['displayName'] ?? 'Kullanıcı'}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  removed
                      ? 'Admin tarafından çıkarıldı'
                      : '${connected ? 'Bağlı' : 'Bağlı değil'} · $reconnect reconnect · ${_n(member['messageCount'])} mesaj · ${_n(member['reportsReceived'])} şikâyet',
                  style: TextStyle(
                    color: removed ? const Color(0xFFC83D3D) : AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Odadan çıkar',
              onPressed: actionLoading ? null : onRemove,
              icon: const Icon(Icons.person_remove_alt_1_rounded, color: Color(0xFFC83D3D)),
            ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child, this.danger = false});
  final String title;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: danger ? const Color(0xFFFFC6C6) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: danger ? const Color(0xFFC83D3D) : AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RoomPagination extends StatelessWidget {
  const _RoomPagination({
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

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(38),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: const Column(
        children: [
          Icon(Icons.forum_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 10),
          Text('Bu filtrede oda bulunamadı.', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RoomsNav extends StatelessWidget {
  const _RoomsNav({required this.onLogout});
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
                  selected: i == 2,
                  selectedTileColor: Colors.white.withOpacity(.10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(items[i].$2, color: i == 2 ? AppColors.lime : Colors.white70),
                  title: Text(items[i].$1, style: TextStyle(color: i == 2 ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
                  onTap: () {
                    if (i == 0) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } else if (i == 1) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => AdminUsersScreen(onLogout: onLogout)),
                      );
                    } else if (i == 2) {
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

int _n(dynamic value) => (value as num?)?.toInt() ?? int.tryParse('$value') ?? 0;

String _date(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty || raw == 'null') return '-';
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

String _duration(int seconds) {
  final value = seconds.clamp(0, 60 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

String _stageLabel(String stage) => switch (stage) {
      'extension' => '+5 dakika',
      'selection' => 'Gizli seçim',
      'closed' => 'Kapalı',
      _ => 'Normal sohbet',
    };

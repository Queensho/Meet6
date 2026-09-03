import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'services/admin_api_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId, required this.onLogout});
  final String userId;
  final VoidCallback onLogout;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  Map<String, dynamic>? user;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await AdminApiService.userDetail(widget.userId);
      if (mounted) setState(() => user = Map<String, dynamic>.from((result['user'] as Map?) ?? const {}));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _text(String key, [String fallback = '-']) {
    final value = user?[key]?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final photos = ((user?['photoUrls'] as List?) ?? const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final stats = Map<String, dynamic>.from((user?['stats'] as Map?) ?? const {});
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Profili', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading && user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : error != null && user == null
              ? Center(child: Text(error!, style: const TextStyle(color: Color(0xFFD74747))))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.softSurface,
                          backgroundImage: photos.isEmpty ? null : NetworkImage(AdminApiService.mediaUrl(photos.first)),
                          child: photos.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.blue, size: 34) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_text('displayName', 'İsimsiz kullanıcı'), style: const TextStyle(color: AppColors.navy, fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${_text('phoneMasked')} · ${_text('age')} yaş · ${_text('city')}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(user?['online'] == true ? 'Online' : 'Offline', style: TextStyle(color: user?['online'] == true ? const Color(0xFF21B573) : AppColors.muted, fontWeight: FontWeight.w900)),
                        ])),
                        Text('%${(user?['profileCompletion'] as num?)?.toInt() ?? 0}', style: const TextStyle(color: AppColors.blue, fontSize: 22, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    if (photos.isNotEmpty)
                      SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: photos.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(AdminApiService.mediaUrl(photos[i]), width: 120, height: 150, fit: BoxFit.cover)))),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _Stat('Odalar', stats['rooms']),
                      _Stat('Eşleşmeler', stats['matches']),
                      _Stat('Aldığı şikâyet', stats['reportsReceived']),
                      _Stat('Yaptığı şikâyet', stats['reportsMade']),
                      _Stat('Engel', stats['blocks']),
                      _Stat('Oda mesajı', stats['roomMessages']),
                      _Stat('Özel mesaj', stats['privateMessages']),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Profil bilgileri', style: TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        _Row('Bio', _text('bio')),
                        _Row('Cinsiyet', _text('gender')),
                        _Row('Şehir / Ülke', '${_text('city')} / ${_text('country')}'),
                        _Row('Profil sorusu', _text('profilePrompt')),
                        _Row('Cevap', _text('profileAnswer')),
                        _Row('Kayıt', _text('createdAt')),
                        _Row('Son görülme', _text('lastSeenAt')),
                      ]),
                    ),
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Container(
    width: 145,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${value ?? 0}', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800))]),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))), Expanded(child: Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)))]),
  );
}

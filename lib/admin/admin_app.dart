import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import 'admin_live_rooms_screen.dart';
import 'admin_users_screen.dart';
import 'services/admin_api_service.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
      primary: AppColors.blue,
      secondary: AppColors.lime,
      surface: Colors.white,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6 Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        fontFamilyFallback: const ['Arial', 'sans-serif'],
      ),
      home: const _AdminGate(),
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate();

  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  bool loading = true;
  bool authorized = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      await AdminApiService.me();
      if (mounted) setState(() => authorized = true);
    } catch (_) {
      await SessionService.clearAuth();
      if (mounted) setState(() => authorized = false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }
    if (!authorized) {
      return _AdminLoginScreen(onAuthenticated: () => setState(() => authorized = true));
    }
    return AdminDashboardScreen(onLogout: () => setState(() => authorized = false));
  }
}

class _AdminLoginScreen extends StatefulWidget {
  const _AdminLoginScreen({required this.onAuthenticated});
  final VoidCallback onAuthenticated;

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool codeSent = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!codeSent) {
        await ApiService.requestOtp(phone.text);
        if (mounted) setState(() => codeSent = true);
      } else {
        final auth = await ApiService.verifyOtp(phone.text, code.text.trim());
        await SessionService.saveAuth(sessionId: auth.sessionId, userId: auth.userId);
        await AdminApiService.me();
        if (mounted) widget.onAuthenticated();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
      if (e.statusCode == 403) await SessionService.clearAuth();
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı kurulamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: const [BoxShadow(blurRadius: 32, color: Color(0x11000000), offset: Offset(0, 14))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Meet6Brand(width: 190),
                const SizedBox(height: 24),
                const Text('Admin Paneli', style: TextStyle(color: AppColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Yetkili Meet6 hesabınla telefon ve OTP kullanarak giriş yap.', style: TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 24),
                TextField(
                  controller: phone,
                  enabled: !codeSent && !loading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon numarası', prefixText: '+90 ', border: OutlineInputBorder()),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: code,
                    enabled: !loading,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Doğrulama kodu', counterText: '', border: OutlineInputBorder()),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white),
                    child: loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(codeSent ? 'Admin paneline gir' : 'Kod gönder', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  int period = 7;
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
      final result = await AdminApiService.dashboard(periodDays: period);
      if (mounted) setState(() => data = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
      if (e.statusCode == 401 || e.statusCode == 403) {
        await SessionService.clearAuth();
        if (mounted) widget.onLogout();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    await SessionService.clearAuth();
    if (mounted) widget.onLogout();
  }

  int _stat(String key) => ((data?['stats'] as Map?)?[key] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get _health => Map<String, dynamic>.from((data?['health'] as Map?) ?? const {});
  List<Map<String, dynamic>> _series(String key) => ((data?['charts'] as Map?)?[key] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final content = _DashboardContent(
      loading: loading,
      error: error,
      period: period,
      onPeriod: (value) {
        if (value == period) return;
        setState(() => period = value);
        _load();
      },
      onRefresh: _load,
      stats: {
        'Toplam kullanıcı': [_stat('totalUsers'), Icons.groups_2_outlined, 'Bugün +${_stat('todayRegistrations')}'],
        'Online kullanıcı': [_stat('onlineUsers'), Icons.circle, 'Gerçek zamanlı'],
        'Kuyrukta bekleyen': [_stat('queuedUsers'), Icons.hourglass_top_rounded, 'Matchmaking'],
        'Aktif odalar': [_stat('activeRooms'), Icons.forum_outlined, '6 kişilik'],
        'Tamamlanan oda': [_stat('todayCompletedRooms'), Icons.check_circle_outline_rounded, 'Bugün'],
        'Karşılıklı eşleşme': [_stat('todayMatches'), Icons.favorite_outline_rounded, 'Bugün'],
        'Gönderilen mesaj': [_stat('totalMessages'), Icons.chat_bubble_outline_rounded, 'Bugün ${_stat('todayMessages')}'],
        'Açık şikâyet': [_stat('openReports'), Icons.report_gmailerrorred_outlined, 'Moderasyon'],
        'Açık destek': [_stat('openSupportRequests'), Icons.support_agent_rounded, 'Bekleyen'],
        'Banlı hesap': [_stat('bannedUsers'), Icons.block_rounded, 'Aktif ban'],
      },
      registrations: _series('registrations'),
      matches: _series('matches'),
      health: _health,
    );

    return Scaffold(
      drawer: wide ? null : Drawer(child: _AdminNav(onLogout: _logout)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: _AdminNav(onLogout: _logout)),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      if (!wide) Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu_rounded))),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Dashboard', style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: loading ? null : _load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded, color: AppColors.blue)),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({required this.onLogout});
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
                  selected: i == 0,
                  selectedTileColor: Colors.white.withOpacity(.10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(items[i].$2, color: i == 0 ? AppColors.lime : Colors.white70),
                  title: Text(items[i].$1, style: TextStyle(color: i == 0 ? Colors.white : Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
                  onTap: () {
                    if (i == 0) {
                      Navigator.maybePop(context);
                      return;
                    }
                    if (i == 1) {
                      Navigator.maybePop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminUsersScreen(onLogout: onLogout),
                        ),
                      );
                      return;
                    }
                    if (i == 2) {
                      Navigator.maybePop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminLiveRoomsScreen(onLogout: onLogout),
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${items[i].$1} ekranını sıradaki adımda bağlıyoruz.')),
                    );
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

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.loading,
    required this.error,
    required this.period,
    required this.onPeriod,
    required this.onRefresh,
    required this.stats,
    required this.registrations,
    required this.matches,
    required this.health,
  });

  final bool loading;
  final String? error;
  final int period;
  final ValueChanged<int> onPeriod;
  final VoidCallback onRefresh;
  final Map<String, List<Object>> stats;
  final List<Map<String, dynamic>> registrations;
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic> health;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cardWidth = box.maxWidth >= 1250 ? (box.maxWidth - 104) / 5 : box.maxWidth >= 760 ? (box.maxWidth - 76) / 3 : (box.maxWidth - 52) / 2;
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Genel Bakış', style: TextStyle(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Meet6 canlı operasyon ve büyüme özeti', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                ])),
                SegmentedButton<int>(
                  segments: const [ButtonSegment(value: 7, label: Text('7 gün')), ButtonSegment(value: 30, label: Text('30 gün'))],
                  selected: {period},
                  onSelectionChanged: (value) => onPeriod(value.first),
                ),
              ],
            ),
            if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(color: AppColors.blue)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFD74747), fontWeight: FontWeight.w700))),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.entries.map((entry) => SizedBox(
                width: cardWidth.clamp(155, 260),
                child: _StatCard(title: entry.key, value: entry.value[0] as int, icon: entry.value[1] as IconData, subtitle: entry.value[2] as String),
              )).toList(),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(width: box.maxWidth >= 900 ? (box.maxWidth - 54) / 2 : box.maxWidth - 40, child: _ChartCard(title: 'Yeni kullanıcılar', subtitle: 'Son $period gün', data: registrations, icon: Icons.person_add_alt_1_rounded)),
                SizedBox(width: box.maxWidth >= 900 ? (box.maxWidth - 54) / 2 : box.maxWidth - 40, child: _ChartCard(title: 'Karşılıklı eşleşmeler', subtitle: 'Son $period gün', data: matches, icon: Icons.favorite_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Sistem Sağlığı', style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HealthChip(label: 'API', value: health['api']),
                _HealthChip(label: 'PostgreSQL', value: health['database']),
                _HealthChip(label: 'Redis', value: health['redis']),
                _HealthChip(label: 'WebSocket', value: health['websocket'], detail: '${health['websocketConnections'] ?? 0} bağlantı'),
                _HealthChip(label: 'Gecikme', value: 'ok', detail: '${health['latencyMs'] ?? 0} ms'),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.subtitle});
  final String title;
  final int value;
  final IconData icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.blue, size: 20)),
        const Spacer(),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle)),
      ]),
      const SizedBox(height: 14),
      Text('$value', style: const TextStyle(color: AppColors.navy, fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
      const SizedBox(height: 7),
      Text(title, style: const TextStyle(color: AppColors.navy, fontSize: 12.5, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.data, required this.icon});
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> data;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 270,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: AppColors.blue, size: 20), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900))), Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 18),
      Expanded(child: CustomPaint(painter: _LineChartPainter(data.map((e) => (e['value'] as num?)?.toDouble() ?? 0).toList()), child: const SizedBox.expand())),
    ]),
  );
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppColors.border.withOpacity(.65)..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(1, (max, value) => value > max ? value : max);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue * (size.height - 12)) - 6;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = AppColors.blue..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = AppColors.lime);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = AppColors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.values != values;
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.value, this.detail});
  final String label;
  final Object? value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final healthy = value?.toString().toLowerCase() == 'ok' || value?.toString().toUpperCase() == 'PONG';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: healthy ? const Color(0xFF21B573) : const Color(0xFFE65B5B), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 12)),
        if (detail != null) ...[const SizedBox(width: 8), Text(detail!, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 10.5))],
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const backendUrl = String.fromEnvironment('SUPABASE_URL');
const backendKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get backendConfigured => backendUrl.isNotEmpty && backendKey.isNotEmpty;

class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key});
  @override
  State<AdminPortal> createState() => _AdminPortalState();
}
class _AdminPortalState extends State<AdminPortal> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  Future<bool>? authorization;
  String? checkedUser;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<bool> checkAdmin() async {
    final rows = await Supabase.instance.client.from('admins').select('user_id');
    return rows.any((row) => row['user_id'] == Supabase.instance.client.auth.currentUser?.id);
  }
  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'E-posta ve şifrenizi yazın.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      password.clear();
    } catch (_) {
      if (mounted) setState(() => error = 'Giriş yapılamadı. Bilgilerinizi ve bağlantınızı kontrol edin.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (!backendConfigured) return shell(const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_outline, size: 48), SizedBox(height: 20), Text('Yönetici girişi', style: TextStyle(fontSize: 26)),
      SizedBox(height: 16), Text('Güvenli giriş bağlantısı henüz yapılandırılmadı. Yönetim paneli erişime kapalı.', textAlign: TextAlign.center),
    ]));
    return StreamBuilder<AuthState>(stream: Supabase.instance.client.auth.onAuthStateChange, builder: (context, snapshot) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        checkedUser = null; authorization = null;
        return shell(Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 42), const SizedBox(height: 16),
          const Text('Yönetici girişi', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)), const SizedBox(height: 24),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder())),
          const SizedBox(height: 16), TextField(controller: password, obscureText: true, onSubmitted: (_) { if (!busy) login(); }, decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder())),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Kontrol ediliyor…' : 'Giriş yap'))),
        ]));
      }
      if (checkedUser != user.id) { checkedUser = user.id; authorization = checkAdmin(); }
      return FutureBuilder<bool>(future: authorization, builder: (context, access) {
        if (access.connectionState != ConnectionState.done) return shell(const Center(child: CircularProgressIndicator()));
        if (access.data != true) return shell(Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock, size: 48), const SizedBox(height: 16), const Text('Yönetici erişimi doğrulanamadı.'),
          const SizedBox(height: 16), TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Çıkış yap')),
        ]));
        return const AdminDashboard();
      });
    });
  }
  Widget shell(Widget child) => Scaffold(backgroundColor: const Color(0xFFF7F5FA),
    appBar: AppBar(title: const Text('Beauty Studio • Yönetim')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SizedBox(width: 420,
      child: Card(child: Padding(padding: const EdgeInsets.all(32), child: child))))));
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  late Future<List<Map<String, dynamic>>> appointments;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() { appointments = Supabase.instance.client.from('appointments').select().order('starts_at'); }
  Future<void> cancel(String id) async {
    final sure = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Randevu iptal edilsin mi?'), content: const Text('Saat yeniden açılır ve müşteriye iptal e-postası gönderilir.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('İptal et'))]));
    if (sure != true) return;
    await Supabase.instance.client.from('appointments').update({'status': 'cancelled'}).eq('id', id);
    if (mounted) setState(refresh);
  }
  // Salon times are Europe/Amsterdam; the admin's browser is assumed to be in that zone.
  String when(Object? iso) {
    final t = DateTime.parse(iso as String).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF7F5FA),
    appBar: AppBar(title: const Text('Beauty Studio • Dashboard'), actions: [
      IconButton(tooltip: 'Yenile', onPressed: () => setState(refresh), icon: const Icon(Icons.refresh)),
      TextButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Çıkış yap')), const SizedBox(width: 16),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: appointments, builder: (context, result) {
      if (result.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (result.hasError) return const Center(child: Text('Randevular yüklenemedi. Bağlantı ve yetkileri kontrol edin.'));
      final rows = result.data ?? [];
      final active = rows.where((r) => r['status'] != 'cancelled').toList();
      final revenue = active.fold<double>(0, (sum, r) => sum + (r['price'] as num).toDouble());
      return ListView(padding: const EdgeInsets.all(28), children: [
        const Text('Genel bakış', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)), const SizedBox(height: 24),
        Wrap(spacing: 16, runSpacing: 16, children: [metric('Aktif randevular', '${active.length}', Icons.calendar_month), metric('Müşteriler', '${rows.map((r) => r['client_email']).toSet().length}', Icons.people_outline), metric('Planlanan gelir', '€${revenue.toStringAsFixed(2)}', Icons.euro)]),
        const SizedBox(height: 32), const Text('Randevular', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
        if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(32), child: Text('Henüz kayıtlı randevu bulunmuyor.'))),
        ...rows.map((r) => Card(child: ListTile(isThreeLine: true, leading: const Icon(Icons.event), title: Text('${r['client_name']} • ${r['service']}'),
          subtitle: Text('${when(r['starts_at'])} • ${r['duration_minutes']} dk\n${r['client_email']} • ${r['client_phone']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('€${r['price']}\n${r['status'] == 'cancelled' ? 'iptal (${r['cancelled_by'] ?? ''})' : r['status']}', textAlign: TextAlign.end),
            if (r['status'] == 'confirmed') IconButton(tooltip: 'İptal et (müşteriye e-posta gider)', icon: const Icon(Icons.event_busy),
              onPressed: () => cancel(r['id'] as String)),
          ])))),
      ]);
    }));
  Widget metric(String title, String value, IconData icon) => SizedBox(width: 260, child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 16), Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)), Text(title)]))));
}
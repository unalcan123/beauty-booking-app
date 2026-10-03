import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show euro;

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
      setState(() => error = 'Vul je e-mailadres en wachtwoord in.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      password.clear();
    } catch (_) {
      if (mounted) setState(() => error = 'Inloggen mislukt. Controleer je gegevens en verbinding.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (!backendConfigured) return shell(const Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_outline, size: 48), SizedBox(height: 20), Text('Inloggen beheerder', style: TextStyle(fontSize: 26)),
      SizedBox(height: 16), Text('De beveiligde inlogverbinding is nog niet ingesteld. Het beheerpaneel is niet toegankelijk.', textAlign: TextAlign.center),
    ]));
    return StreamBuilder<AuthState>(stream: Supabase.instance.client.auth.onAuthStateChange, builder: (context, snapshot) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        checkedUser = null; authorization = null;
        return shell(Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 42), const SizedBox(height: 16),
          const Text('Inloggen beheerder', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)), const SizedBox(height: 24),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mailadres', border: OutlineInputBorder())),
          const SizedBox(height: 16), TextField(controller: password, obscureText: true, onSubmitted: (_) { if (!busy) login(); }, decoration: const InputDecoration(labelText: 'Wachtwoord', border: OutlineInputBorder())),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Bezig met controleren…' : 'Inloggen'))),
        ]));
      }
      if (checkedUser != user.id) { checkedUser = user.id; authorization = checkAdmin(); }
      return FutureBuilder<bool>(future: authorization, builder: (context, access) {
        if (access.connectionState != ConnectionState.done) return shell(const Center(child: CircularProgressIndicator()));
        if (access.data != true) return shell(Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock, size: 48), const SizedBox(height: 16), const Text('Beheerderstoegang kon niet worden bevestigd.'),
          const SizedBox(height: 16), TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Uitloggen')),
        ]));
        return const AdminDashboard();
      });
    });
  }
  Widget shell(Widget child) => Scaffold(backgroundColor: const Color(0xFFF7F5FA),
    appBar: AppBar(title: const Text('Beauty Studio • Beheer')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SizedBox(width: 420,
      child: Card(child: Padding(padding: const EdgeInsets.all(32), child: child))))));
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  late Future<List<Map<String, dynamic>>> appointments, services;
  @override
  void initState() { super.initState(); refresh(); }
  void refresh() {
    appointments = Supabase.instance.client.from('appointments').select().order('starts_at');
    services = Supabase.instance.client.from('services').select().order('duration_minutes', ascending: false);
  }
  // New prices apply to new bookings only; existing appointments keep their booked price.
  Future<void> editPrice(Map<String, dynamic> service) async {
    final input = TextEditingController(text: '${service['price']}');
    String? problem;
    final saved = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setDialog) => AlertDialog(
      title: Text('Prijs van ${service['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: input, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '€ ', border: const OutlineInputBorder(), errorText: problem)),
        const SizedBox(height: 12),
        const Text('De nieuwe prijs geldt alleen voor nieuwe afspraken.', style: TextStyle(color: Colors.black54, fontSize: 13)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuleren')),
        FilledButton(child: const Text('Opslaan'), onPressed: () async {
          final value = double.tryParse(input.text.trim().replaceAll(',', '.'));
          if (value == null || value < 0 || value > 10000) { setDialog(() => problem = 'Vul een bedrag tussen 0 en 10000 in.'); return; }
          try {
            final rows = await Supabase.instance.client.from('services').update({'price': value}).eq('id', service['id']).select();
            if (rows.isEmpty) throw StateError('not allowed');
            if (c.mounted) Navigator.pop(c, true);
          } catch (_) {
            setDialog(() => problem = 'Opslaan mislukt. Controleer je rechten en verbinding.');
          }
        })])));
    input.dispose();
    if (saved == true && mounted) {
      setState(refresh);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prijs bijgewerkt.')));
    }
  }
  Widget priceList() => FutureBuilder<List<Map<String, dynamic>>>(future: services, builder: (context, result) {
    if (result.connectionState != ConnectionState.done) return const LinearProgressIndicator();
    if (result.hasError) return const Text('Behandelingen konden niet worden geladen.');
    return Card(child: Column(children: [for (final sv in result.data!) ListTile(
      leading: const Icon(Icons.sell_outlined), title: Text('${sv['name']}'), subtitle: Text('${sv['duration_minutes']} minuten'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(euro(sv['price'] as num), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        IconButton(tooltip: 'Prijs wijzigen', icon: const Icon(Icons.edit_outlined), onPressed: () => editPrice(sv)),
      ]))]));
  });
  Future<void> cancel(String id) async {
    final sure = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Afspraak annuleren?'), content: const Text('Het tijdstip komt weer vrij en de klant ontvangt een annuleringsmail.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Terug')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Afspraak annuleren'))]));
    if (sure != true) return;
    await Supabase.instance.client.from('appointments').update({'status': 'cancelled'}).eq('id', id);
    if (mounted) setState(refresh);
  }
  // Salon times are Europe/Amsterdam; the admin's browser is assumed to be in that zone.
  String when(Object? iso) {
    final t = DateTime.parse(iso as String).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
  String statusLabel(Map<String, dynamic> r) => switch (r['status']) {
    'cancelled' => 'geannuleerd (${r['cancelled_by'] == 'customer' ? 'klant' : 'salon'})',
    'completed' => 'afgerond',
    _ => 'bevestigd',
  };
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF7F5FA),
    appBar: AppBar(title: const Text('Beauty Studio • Dashboard'), actions: [
      IconButton(tooltip: 'Vernieuwen', onPressed: () => setState(refresh), icon: const Icon(Icons.refresh)),
      TextButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Uitloggen')), const SizedBox(width: 16),
    ]),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: appointments, builder: (context, result) {
      if (result.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (result.hasError) return const Center(child: Text('Afspraken konden niet worden geladen. Controleer de verbinding en rechten.'));
      final rows = result.data ?? [];
      final active = rows.where((r) => r['status'] != 'cancelled').toList();
      final revenue = active.fold<double>(0, (sum, r) => sum + (r['price'] as num).toDouble());
      return ListView(padding: const EdgeInsets.all(28), children: [
        const Text('Overzicht', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)), const SizedBox(height: 24),
        Wrap(spacing: 16, runSpacing: 16, children: [metric('Actieve afspraken', '${active.length}', Icons.calendar_month), metric('Klanten', '${rows.map((r) => r['client_email']).toSet().length}', Icons.people_outline), metric('Verwachte omzet', '€${revenue.toStringAsFixed(2)}', Icons.euro)]),
        const SizedBox(height: 32), const Text('Behandelingen en prijzen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
        priceList(),
        const SizedBox(height: 32), const Text('Afspraken', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
        if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(32), child: Text('Er zijn nog geen afspraken.'))),
        ...rows.map((r) => Card(child: ListTile(isThreeLine: true, leading: const Icon(Icons.event), title: Text('${r['client_name']} • ${r['service']}'),
          subtitle: Text('${when(r['starts_at'])} • ${r['duration_minutes']} min\n${r['client_email']} • ${r['client_phone']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('€${r['price']}\n${statusLabel(r)}', textAlign: TextAlign.end),
            if (r['status'] == 'confirmed') IconButton(tooltip: 'Annuleren (klant krijgt een e-mail)', icon: const Icon(Icons.event_busy),
              onPressed: () => cancel(r['id'] as String)),
          ])))),
      ]);
    }));
  Widget metric(String title, String value, IconData icon) => SizedBox(width: 260, child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 16), Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)), Text(title)]))));
}
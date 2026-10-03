import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_portal.dart' show backendConfigured;

/// Customer self-cancellation, opened from the link in the confirmation e-mail.
class CancelPage extends StatefulWidget {
  final String token;
  const CancelPage({super.key, required this.token});
  @override
  State<CancelPage> createState() => _CancelPageState();
}

class _CancelPageState extends State<CancelPage> {
  late Future<Map<String, dynamic>?> booking;
  bool busy = false, done = false;
  String? error;
  static final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  @override
  void initState() { super.initState(); booking = load(); }
  Future<Map<String, dynamic>?> load() async {
    if (!backendConfigured || !uuid.hasMatch(widget.token)) return null;
    final rows = await Supabase.instance.client.rpc('get_booking', params: {'p_token': widget.token}) as List;
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }
  Future<void> cancel() async {
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.rpc('cancel_appointment', params: {'p_token': widget.token});
      done = true;
    } on PostgrestException catch (e) {
      error = switch (e.message) {
        'too_late' => 'Je afspraak begint binnen 24 uur en kan niet meer online worden geannuleerd. Bel de salon.',
        'already_cancelled' => 'Deze afspraak is al geannuleerd.',
        _ => 'Afspraak niet gevonden.',
      };
    } catch (_) {
      error = 'Annuleren mislukt. Controleer je verbinding en probeer het opnieuw.';
    }
    if (mounted) setState(() => busy = false);
  }
  String when(String iso) {
    final t = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BROW BELLE', style: TextStyle(letterSpacing: 3, fontSize: 17)),
      backgroundColor: const Color(0xFFFAF7F5), centerTitle: true),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SizedBox(width: 460,
      child: Card(child: Padding(padding: const EdgeInsets.all(32), child: FutureBuilder<Map<String, dynamic>?>(
        future: booking,
        builder: (context, result) {
          if (result.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final b = result.data;
          if (result.hasError || b == null) return const Text('Afspraak niet gevonden. Controleer of je de volledige link hebt gekopieerd.', textAlign: TextAlign.center);
          final cancelled = done || b['status'] == 'cancelled';
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Afspraak annuleren', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text('${b['service']}'), Text('${when(b['starts_at'] as String)} • ${b['duration_minutes']} minuten'),
            const SizedBox(height: 20),
            if (cancelled) const Text('Je afspraak is geannuleerd. Je ontvangt een bevestiging per e-mail.', style: TextStyle(fontWeight: FontWeight.w600))
            else if (b['cancellable'] != true) const Text('Je afspraak begint binnen 24 uur en kan niet meer online worden geannuleerd. Bel de salon.')
            else SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
              onPressed: busy ? null : cancel, child: Text(busy ? 'Bezig met annuleren…' : 'Afspraak annuleren'))),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false), child: const Text('Nieuwe afspraak maken')),
          ]);
        })))))),
  );
}

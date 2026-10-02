import 'package:flutter/material.dart';
import 'booking_time_picker.dart';
import 'admin_portal.dart';
import 'cancel_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (backendConfigured) await Supabase.initialize(url: backendUrl, publishableKey: backendKey);
  runApp(const BeautyApp());
}

class BeautyApp extends StatelessWidget {
  const BeautyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Beauty Studio',
    theme: ThemeData(useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF79566C)),
      scaffoldBackgroundColor: Colors.white),
    onGenerateRoute: (settings) => MaterialPageRoute(
      settings: settings,
      builder: (_) {
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/admin' || uri.path == '/dashboard') return const AdminPortal();
        if (uri.path == '/iptal') return CancelPage(token: uri.queryParameters['t'] ?? '');
        return const BookingPage();
      },
    ),
  );
}

class Service {
  final String id, name;
  final int minutes;
  final num price;
  final IconData icon;
  const Service(this.id, this.name, this.minutes, this.price, this.icon);
  String get priceLabel => euro(price);
}

String euro(num value) => '€${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(2)}';
const serviceIcons = {'manicure': Icons.back_hand_outlined, 'haircut': Icons.content_cut, 'brows': Icons.face_outlined};

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // Demo fallback only; with a backend, names, durations and prices come from public.services
  // (admins edit prices there) and the server uses its own values when booking.
  static const demoServices = [
    Service('manicure', 'Manikür & jel oje', 60, 35, Icons.back_hand_outlined),
    Service('haircut', 'Saç kesimi & şekillendirme', 45, 30, Icons.content_cut),
    Service('brows', 'Kaş şekillendirme', 20, 15, Icons.face_outlined),
  ];
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  List<Service> services = demoServices;
  Service service = demoServices.first;
  bool servicesLoading = backendConfigured;
  bool servicesFailed = false;
  DateTime? date;
  String? time;
  int step = 0;
  bool completed = false, submitting = false;
  String? cancelToken;
  @override
  void initState() { super.initState(); if (backendConfigured) loadServices(); }
  Future<void> loadServices() async {
    setState(() { servicesLoading = true; servicesFailed = false; });
    try {
      final rows = await Supabase.instance.client.from('services').select().order('duration_minutes', ascending: false);
      final loaded = [for (final r in rows) Service(r['id'] as String, r['name'] as String, r['duration_minutes'] as int,
        r['price'] as num, serviceIcons[r['id']] ?? Icons.spa_outlined)];
      if (!mounted) return;
      setState(() {
        services = loaded; servicesLoading = false;
        service = loaded.firstWhere((x) => x.id == service.id, orElse: () => loaded.first);
      });
    } catch (_) {
      if (mounted) setState(() { servicesLoading = false; servicesFailed = true; });
    }
  }
  @override
  void dispose() { name.dispose(); phone.dispose(); email.dispose(); super.dispose(); }

  String dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  Future<void> chooseDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: date ?? now,
      firstDate: now, lastDate: now.add(const Duration(days: 90)));
    if (picked != null && mounted) setState(() { date = picked; time = null; });
  }
  String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Future<void> submit() async {
    if (!backendConfigured) { setState(() => completed = true); return; }
    setState(() => submitting = true);
    String? problem;
    try {
      cancelToken = await Supabase.instance.client.rpc('book_appointment', params: {
        'p_service_id': service.id, 'p_day': isoDate(date!), 'p_time': time,
        'p_name': name.text.trim(), 'p_email': email.text.trim(), 'p_phone': phone.text.trim()});
    } on PostgrestException catch (e) {
      problem = e.message;
    } catch (_) {
      problem = 'network';
    }
    if (!mounted) return;
    setState(() {
      submitting = false;
      if (problem == null) { completed = true; }
      else if (problem == 'slot_taken') { step = 1; time = null; }
    });
    if (problem != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(switch (problem) {
      'slot_taken' => 'Bu saat az önce doldu. Lütfen başka bir saat seçin.',
      'invalid_details' => 'İletişim bilgilerinizi kontrol edin.',
      'too_many_bookings' => 'Bu e-posta ile çok sayıda aktif randevu var.',
      _ => 'Randevu kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.',
    })));
  }
  void next() {
    if (step == 1 && (date == null || time == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tarih ve saat seçin.')));
      return;
    }
    if (step == 2 && !form.currentState!.validate()) return;
    if (step == 3) { submit(); return; }
    setState(() => step++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BEAUTY STUDIO', style: TextStyle(letterSpacing: 3, fontSize: 17)),
      backgroundColor: const Color(0xFFFAF7F5), centerTitle: true),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Kendine güzel bir\nzaman ayır.', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w600, height: 1.15)),
        const SizedBox(height: 12),
        const Text('Tırnak, saç ve kaş bakımı • Hollanda', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        if (!backendConfigured) ...[Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF0E6EC), borderRadius: BorderRadius.circular(12)),
          child: const Text('Demo: Saatler örnektir. Bu ekran gerçek rezervasyon oluşturmaz.')),
        const SizedBox(height: 24)],
        if (completed) ...[
          const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF79566C)),
          const SizedBox(height: 16),
          Text(backendConfigured ? 'Randevunuz alındı' : 'Rezervasyon önizlemesi hazır', textAlign: TextAlign.center, style: TextStyle(fontSize: 25)),
          const SizedBox(height: 12),
          Text('${name.text}\n${service.name}\n${dateLabel(date!)} • $time\n${service.priceLabel}', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(backendConfigured ? 'Saat sizin için ayrıldı. Onay e-postası ${email.text.trim()} adresine gönderilecek.' : 'Bilgiler gönderilmedi ve kaydedilmedi.', textAlign: TextAlign.center),
          if (cancelToken != null) ...[
            const SizedBox(height: 12),
            const Text('İptal etmeniz gerekirse (en geç 24 saat önce) bu bağlantıyı saklayın:', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
            SelectableText('${Uri.base.removeFragment()}#/iptal?t=$cancelToken', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          OutlinedButton(onPressed: () => setState(() { completed = false; cancelToken = null; step = 0; date = null; time = null; name.clear(); phone.clear(); email.clear(); }), child: const Text('Yeni randevu seç')),
        ] else ...[
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(4, (i) => Chip(
            backgroundColor: i == step ? const Color(0xFFE5D5DF) : Colors.white,
            label: Text('${i + 1}. ${['Hizmet', 'Tarih & saat', 'Bilgiler', 'Özet'][i]}')))),
          const SizedBox(height: 20),
          Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(24), child: content())),
          const SizedBox(height: 20),
          Row(children: [if (step > 0) TextButton(onPressed: () => setState(() => step--), child: const Text('Geri')),
            const Spacer(), FilledButton(onPressed: submitting ? null : next, child: Text(step == 3 ? (submitting ? 'Kaydediliyor…' : backendConfigured ? 'Randevuyu onayla' : 'Önizlemeyi tamamla') : 'Devam et'))]),
        ],
        const SizedBox(height: 32),
        const Text('Size özel bakım, sakin bir ortam.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)),
      ]))),
  );

  Widget content() {
    if (step == 0 && servicesLoading) return const Center(child: CircularProgressIndicator());
    if (step == 0 && (servicesFailed || services.isEmpty)) return Row(children: [const Expanded(child: Text('Hizmetler yüklenemedi.')),
      TextButton(onPressed: loadServices, child: const Text('Tekrar dene'))]);
    if (step == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Hizmetini seç', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      ...services.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: () => setState(() => service = s),
        child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), color: service.id == s.id ? const Color(0xFFF5EDF2) : Colors.white,
          border: Border.all(color: service.id == s.id ? const Color(0xFF79566C) : const Color(0xFFE8E3E6))),
          child: Row(children: [Icon(s.icon), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)), Text('${s.minutes} dakika', style: const TextStyle(color: Colors.black54))])),
            Text(s.priceLabel), const SizedBox(width: 12), Icon(service.id == s.id ? Icons.radio_button_checked : Icons.radio_button_off)])))))
    ]);
    if (step == 1) return BookingTimePicker(
      serviceId: service.id, service: service.name, minutes: service.minutes, price: service.price,
      date: date, time: time,
      onChanged: (selectedDate, selectedTime) => setState(() { date = selectedDate; time = selectedTime; }),
    );
    if (step == 2) return Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('İletişim bilgilerin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Ad soyad', border: OutlineInputBorder()),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Adınızı yazın.' : null),
      const SizedBox(height: 16),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon', hintText: '+31 …', border: OutlineInputBorder()),
        validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 9 ? 'Geçerli bir telefon numarası yazın.' : null),
      const SizedBox(height: 16),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
        validator: (v) => !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? 'Geçerli bir e-posta yazın.' : null),
    ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Randevu özeti', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      ListTile(contentPadding: EdgeInsets.zero, leading: Icon(service.icon), title: Text(service.name), subtitle: Text('${service.minutes} dakika'), trailing: Text(service.priceLabel)),
      const Divider(),
      Text('${dateLabel(date!)} • $time • Europe/Amsterdam'),
      const SizedBox(height: 16), Text(name.text), Text(phone.text), Text(email.text),
      const SizedBox(height: 20),
      Text(backendConfigured ? 'Onayladığınızda saat tekrar kontrol edilir ve sizin için ayrılır.' : 'Bu demo yalnızca seçiminizi gösterir. Gerçek rezervasyon için müsaitlik kontrolü ve kayıt sistemi bağlanmalıdır.'),
    ]);
  }
}

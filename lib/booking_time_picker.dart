import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_portal.dart' show backendConfigured;
import 'main.dart' show euro;

class BookingTimePicker extends StatefulWidget {
  final String serviceId, service;
  final int minutes;
  final num price;
  final DateTime? date;
  final String? time;
  final void Function(DateTime, String?) onChanged;
  const BookingTimePicker({super.key, required this.serviceId, required this.service, required this.minutes,
    required this.price, required this.date, required this.time, required this.onChanged});
  @override
  State<BookingTimePicker> createState() => _BookingTimePickerState();
}

class _BookingTimePickerState extends State<BookingTimePicker> {
  late DateTime month;
  Future<List<String>>? available;
  String? loadedFor;
  static const purple = Color(0xFF4E3473);
  static const blue = Color(0xFFD6EAFF);
  static const months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  @override
  void initState() {
    super.initState();
    final initial = widget.date ?? DateTime.now();
    month = DateTime(initial.year, initial.month);
  }
  static String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  // Free start times come from the server, which also enforces them when booking.
  Future<List<String>> loadSlots(DateTime d) async {
    if (!backendConfigured) return const [];
    final rows = await Supabase.instance.client.rpc('get_available_slots', params: {'p_day': isoDate(d), 'p_service_id': widget.serviceId});
    return [for (final r in rows as List) r['slot'] as String];
  }
  void changeMonth(int delta) => setState(() => month = DateTime(month.year, month.month + delta));
  Widget day(DateTime value) {
    final today = DateUtils.dateOnly(DateTime.now());
    final enabled = value.month == month.month && !value.isBefore(today) && !value.isAfter(today.add(const Duration(days: 90)));
    final selected = DateUtils.isSameDay(value, widget.date);
    return Center(child: SizedBox(width: 40, height: 40, child: TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder(),
        backgroundColor: selected ? purple : Colors.transparent,
        foregroundColor: selected ? Colors.white : const Color(0xFF434343),
        disabledForegroundColor: const Color(0xFFBFC3CE)),
      onPressed: enabled ? () => widget.onChanged(value, null) : null,
      child: Text('${value.day}'))));
  }
  Widget calendar() => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 850;
    final columns = wide ? 21 : 7;
    final first = month.subtract(Duration(days: month.weekday - 1));
    final count = DateTime(month.year, month.month + 1, 0).day + month.weekday - 1;
    final rows = (count / columns).ceil();
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E3E8)), borderRadius: BorderRadius.circular(3)),
      child: Column(children: [
        Row(children: [IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_left)),
          if (constraints.maxWidth > 500) TextButton(onPressed: () => changeMonth(-1), child: const Text('Önceki ay')),
          Expanded(child: Text('${months[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (constraints.maxWidth > 500) TextButton(onPressed: () => changeMonth(1), child: const Text('Sonraki ay')),
          IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 32),
        Row(children: List.generate(columns, (i) => Expanded(child: Column(children: [
          Text(['PZT','SAL','ÇAR','PER','CUM','CMT','PAZ'][i % 7], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: i % 7 >= 5 ? const Color(0xFFD65D66) : const Color(0xFF484848))),
          const SizedBox(height: 18), Container(width: 30, height: 1, color: const Color(0xFFAAAAAA)), const SizedBox(height: 10),
        ])))),
        ...List.generate(rows, (row) => Row(children: List.generate(columns, (col) => Expanded(child: day(first.add(Duration(days: row * columns + col))))))),
      ]));
  });
  Widget serviceCard() => Container(width: double.infinity, padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E3E8)), borderRadius: BorderRadius.circular(3)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.service, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 42), Text('${widget.minutes} dakika'), const SizedBox(height: 12), Text(euro(widget.price)),
    ]));
  Widget slots() {
    final d = widget.date;
    final key = d == null ? null : '${isoDate(d)}|${widget.serviceId}';
    if (key != loadedFor) { loadedFor = key; available = d == null ? null : loadSlots(d); }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Uygun başlangıç saatleri', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF4B4B4B))),
    const SizedBox(height: 12),
    if (widget.date == null) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Önce takvimden bir gün seçin.')),
    if (available != null) FutureBuilder<List<String>>(future: available, builder: (context, result) {
      if (result.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
      if (result.hasError) return Row(children: [const Expanded(child: Text('Müsait saatler yüklenemedi.')),
        TextButton(onPressed: () => setState(() => loadedFor = null), child: const Text('Tekrar dene'))]);
      final times = result.data!;
      if (times.isEmpty) return const Text('Bu gün için müsait saat kalmadı. Lütfen başka bir gün seçin.');
      return Wrap(spacing: 10, runSpacing: 10, children: times.map((value) {
        final selected = widget.time == value;
        return SizedBox(width: 111, height: 48, child: TextButton(
          onPressed: () => widget.onChanged(widget.date!, value),
          style: TextButton.styleFrom(backgroundColor: selected ? purple : blue,
            foregroundColor: selected ? Colors.white : const Color(0xFF535B62),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          child: Text(value)));
      }).toList());
    }),
    const SizedBox(height: 22),
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Icon(Icons.circle, size: 13, color: blue), const SizedBox(width: 6),
      const Text('Müsait saatler', style: const TextStyle(color: Colors.black54, fontSize: 12))]),
  ]);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Row(children: [
      Expanded(child: Text('Tarih ve saat', textAlign: TextAlign.center, style: TextStyle(fontSize: 20))),
      Expanded(child: Text('Müşteri', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Color(0xFFC7C7C7)))),
    ])),
    const Divider(height: 36, color: Color(0xFFE2E3E8)),
    const SizedBox(height: 20), calendar(), const SizedBox(height: 20),
    LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= 700
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 280, child: serviceCard()), const SizedBox(width: 48), Expanded(child: Padding(padding: const EdgeInsets.only(top: 26), child: slots()))])
      : Column(children: [serviceCard(), const SizedBox(height: 24), slots()])),
  ]);
}
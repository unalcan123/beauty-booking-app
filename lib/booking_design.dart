import 'package:flutter/material.dart';

const ink = Color(0xFF203D38);
const accent = Color(0xFF23675B);

class BookingHero extends StatelessWidget {
  const BookingHero({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: const Color(0xFFEAF1EC), borderRadius: BorderRadius.circular(28)),
    child: LayoutBuilder(builder: (context, box) => Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SANA ÖZEL BİR MOLA', style: TextStyle(color: accent, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text('Kendine güzel bir\nzaman ayır.', style: TextStyle(color: ink, fontSize: box.maxWidth < 500 ? 30 : 46, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: -1.5)),
        const SizedBox(height: 16),
        const Text('Tırnak, saç ve kaş bakımı.\nHizmetini seç, sana uygun zamanı ayır.', style: TextStyle(color: Color(0xFF62726C), height: 1.6, fontSize: 15)),
        const SizedBox(height: 24),
        const Row(children: [Icon(Icons.location_on_outlined, size: 16, color: accent), SizedBox(width: 6), Text('Hollanda', style: TextStyle(color: ink))]),
      ])),
      if (box.maxWidth > 650) Container(width: 180, height: 180,
        decoration: BoxDecoration(color: const Color(0xFFD7E5DB), borderRadius: BorderRadius.circular(90)),
        child: const Icon(Icons.spa_outlined, size: 86, color: accent)),
    ])),
  );
}

class BookingProgress extends StatelessWidget {
  final int step;
  const BookingProgress({super.key, required this.step});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => Row(
    children: List.generate(4, (index) => Expanded(child: Row(children: [
      Expanded(child: Column(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200), width: 38, height: 38,
          decoration: BoxDecoration(color: index <= step ? accent : const Color(0xFFEBEEEB), shape: BoxShape.circle),
          child: Center(child: index < step ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text('${index + 1}', style: TextStyle(color: index == step ? Colors.white : const Color(0xFF8A9490), fontWeight: FontWeight.w600)))),
        const SizedBox(height: 8),
        Text(['Hizmet', box.maxWidth < 420 ? 'Zaman' : 'Tarih & saat', 'Bilgiler', 'Özet'][index],
          style: TextStyle(fontSize: 12, color: index <= step ? ink : const Color(0xFF8A9490), fontWeight: index == step ? FontWeight.w700 : FontWeight.w400)),
      ])),
    ]))),
  ));
}

class ModernServiceTile extends StatelessWidget {
  final String title, price;
  final int minutes;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ModernServiceTile({super.key, required this.title, required this.price, required this.minutes,
    required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(selected: selected, button: true, child: Material(color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: selected ? const Color(0xFFF0F6F2) : Colors.white,
            border: Border.all(color: selected ? accent : const Color(0xFFE5E9E5), width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: selected ? const Color(0xFFDDEBE1) : const Color(0xFFF3F3EF), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: accent, size: 26)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink)),
              const SizedBox(height: 7), Row(children: [const Icon(Icons.schedule, size: 14, color: Color(0xFF7D8983)), const SizedBox(width: 5), Text('$minutes dakika', style: const TextStyle(fontSize: 13, color: Color(0xFF7D8983)))]),
            ])),
            const SizedBox(width: 12), Text(price, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(width: 12), Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? accent : const Color(0xFFCAD2CD), size: 22),
          ]))))));
}
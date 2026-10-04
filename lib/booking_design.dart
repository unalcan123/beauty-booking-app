import 'package:flutter/material.dart';

const ink = Color(0xFF203D38);
const accent = Color(0xFF23675B);

class BookingHero extends StatelessWidget {
  const BookingHero({super.key});
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: const Color(0xFFEAF1EC), borderRadius: BorderRadius.circular(28)),
    child: LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 650;
      final text = Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EVEN TIJD VOOR JEZELF', style: TextStyle(color: accent, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text('Gun jezelf een\nmooi moment.', style: TextStyle(color: ink, fontSize: box.maxWidth < 500 ? 30 : 46, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: -1.5)),
        const SizedBox(height: 16),
        const Text('Nagels, haar en wenkbrauwen.\nKies je behandeling en een tijd die jou past.', style: TextStyle(color: Color(0xFF62726C), height: 1.6, fontSize: 15)),
        const SizedBox(height: 24),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          HeroChip(icon: Icons.back_hand_outlined, label: 'Nagels'),
          HeroChip(icon: Icons.content_cut, label: 'Haar'),
          HeroChip(icon: Icons.face_outlined, label: 'Wenkbrauwen'),
        ]),
        const SizedBox(height: 20),
        const Row(children: [Icon(Icons.location_on_outlined, size: 16, color: accent), SizedBox(width: 6), Text('Nederland', style: TextStyle(color: ink))]),
      ]));
      if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 220, child: BeautyPhoto('assets/images/hero.jpg', alignment: Alignment(0, -0.35))),
        text,
      ]);
      return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: text),
        const SizedBox(width: 340, child: BeautyPhoto('assets/images/hero.jpg', alignment: Alignment(0, -0.2))),
      ]));
    }),
  );
}

class HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const HeroChip({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: const Color(0xBFFFFFFF), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: accent), const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}

/// Decorative salon photo (bundled asset); falls back to a soft tint if it cannot load.
class BeautyPhoto extends StatelessWidget {
  final String asset;
  final Alignment alignment;
  const BeautyPhoto(this.asset, {super.key, this.alignment = Alignment.center});
  @override
  Widget build(BuildContext context) => Image.asset(asset, fit: BoxFit.cover, alignment: alignment,
    excludeFromSemantics: true, gaplessPlayback: true,
    errorBuilder: (context, error, stack) => const ColoredBox(color: Color(0xFFD7E5DB)));
}

class BookingGallery extends StatelessWidget {
  const BookingGallery({super.key});
  static const photos = ['sfeer_nagels', 'sfeer_haar', 'sfeer_ogen', 'sfeer_nailart'];
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('SFEER BIJ BROW BELLE', style: TextStyle(color: accent, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Met aandacht voor elk detail', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w600)),
    const SizedBox(height: 16),
    LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth < 600 ? 2 : 4;
      const gap = 12.0;
      final size = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final p in photos) SizedBox(width: size, height: size * 1.25,
          child: ClipRRect(borderRadius: BorderRadius.circular(20), child: BeautyPhoto('assets/images/$p.jpg'))),
      ]);
    }),
  ]);
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
        Text(['Behandeling', box.maxWidth < 420 ? 'Tijd' : 'Datum & tijd', 'Gegevens', 'Overzicht'][index],
          style: TextStyle(fontSize: 12, color: index <= step ? ink : const Color(0xFF8A9490), fontWeight: index == step ? FontWeight.w700 : FontWeight.w400)),
      ])),
    ]))),
  ));
}

class ModernServiceTile extends StatelessWidget {
  final String title, price;
  final int minutes;
  final IconData icon;
  final String? image;
  final bool selected;
  final VoidCallback onTap;
  const ModernServiceTile({super.key, required this.title, required this.price, required this.minutes,
    required this.icon, this.image, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(selected: selected, button: true, child: Material(color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: selected ? const Color(0xFFF0F6F2) : Colors.white,
            border: Border.all(color: selected ? accent : const Color(0xFFE5E9E5), width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            image != null
              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: SizedBox(width: 60, height: 60, child: BeautyPhoto(image!)))
              : Container(width: 52, height: 52, decoration: BoxDecoration(color: selected ? const Color(0xFFDDEBE1) : const Color(0xFFF3F3EF), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: accent, size: 26)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink)),
              const SizedBox(height: 7), Row(children: [const Icon(Icons.schedule, size: 14, color: Color(0xFF7D8983)), const SizedBox(width: 5), Text('$minutes minuten', style: const TextStyle(fontSize: 13, color: Color(0xFF7D8983)))]),
            ])),
            const SizedBox(width: 12), Text(price, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(width: 12), Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? accent : const Color(0xFFCAD2CD), size: 22),
          ]))))));
}
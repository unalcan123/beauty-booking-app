import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beauty_booking/main.dart';

void main() {
  testWidgets('Customer page has no dashboard entry', (tester) async {
    await tester.pumpWidget(const BeautyApp());
    expect(find.text('BEAUTY STUDIO'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Inloggen beheerder'), findsNothing);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('voorbeeld'), findsNothing);
  });
  test('Prices are shown without trailing zeros', () {
    expect(euro(35), '€35');
    expect(euro(35.0), '€35');
    expect(euro(16.5), '€16.50');
  });
  for (final route in ['/admin', '/dashboard']) {
    testWidgets('$route fails closed without backend configuration', (tester) async {
      await tester.pumpWidget(const BeautyApp());
      final context = tester.element(find.byType(BookingPage));
      Navigator.of(context).pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.text('Inloggen beheerder'), findsOneWidget);
      expect(find.text('De beveiligde inlogverbinding is nog niet ingesteld. Het beheerpaneel is niet toegankelijk.'), findsOneWidget);
      expect(find.text('Overzicht'), findsNothing);
    });
  }
}
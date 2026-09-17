import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/tournament.dart';
import 'package:flutter_application_1/main.dart' as app;

void main() {
  testWidgets('turnuva ağacı geniş ve dar ekranlarda taşmadan görünür', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(1180, 700), Size(390, 844)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: TournamentScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('ALTIN ISTAKA TURNUVASI'), findsOneWidget);
      expect(find.text('ÇEYREK FİNAL'), findsOneWidget);
      expect(find.text('YARI FİNAL'), findsOneWidget);
      expect(find.text('FİNAL'), findsOneWidget);
      expect(find.text('OYUNCU 2'), findsNWidgets(3));
      expect(find.text('OYUNCU 3'), findsNWidgets(3));
      expect(find.text('OYUNCU 4'), findsNWidgets(3));
      expect(find.textContaining('Rakip'), findsNothing);
      expect(find.byKey(const ValueKey('tournament-action')), findsOneWidget);
    }
  });

  testWidgets('ana menü turnuva butonu popup yerine turnuva sahnesini açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('TURNUVALAR'));
    await tester.pumpAndSettle();

    expect(find.byType(TournamentScreen), findsOneWidget);
    expect(find.text('ALTIN ISTAKA TURNUVASI'), findsOneWidget);
    expect(find.textContaining('Yaklaşan turnuvalar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

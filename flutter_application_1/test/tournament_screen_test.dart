import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/tournament.dart';
import 'package:flutter_application_1/main.dart' as app;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('turnuva sayacı ilk açılışta başlar', () async {
    final firstDeadline = await initializeTournamentCycle();
    expect(firstDeadline.isAfter(DateTime.now()), isTrue);
    expect(
      firstDeadline.difference(DateTime.now()),
      lessThanOrEqualTo(const Duration(hours: 24)),
    );
  });

  test('geçmiş turnuva süresi yeni döneme taşınır', () async {
    SharedPreferences.setMockInitialValues({
      'tournament.deadline_ms': DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch,
    });
    final rolledDeadline = await initializeTournamentCycle();
    expect(rolledDeadline.isAfter(DateTime.now()), isTrue);
    expect(
      rolledDeadline.difference(DateTime.now()),
      lessThanOrEqualTo(const Duration(hours: 24)),
    );
  });

  testWidgets('turnuva ağacı geniş ve dar ekranlarda taşmadan görünür', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(1180, 700),
      Size(1024, 768),
      Size(768, 1024),
      Size(568, 320),
      Size(320, 568),
      Size(390, 844),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: TournamentScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('ALTIN ISTAKA TURNUVASI'), findsOneWidget);
      expect(find.text('ÇEYREK FİNAL'), findsOneWidget);
      expect(find.text('YARI FİNAL'), findsOneWidget);
      expect(find.text('FİNAL'), findsOneWidget);
      expect(find.text('4 OYUNCU'), findsOneWidget);
      expect(find.text('3 TUR'), findsWidgets);
      expect(find.text('EN DÜŞÜK PUAN'), findsOneWidget);
      expect(find.textContaining('Rakip'), findsNothing);
      expect(
        find.byKey(const ValueKey('tournament-action')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_StageTrack',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1. AŞAMA'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'images/anamenu/menubg.png',
        ),
        findsNothing,
      );
    }
  });

  testWidgets('ana menü turnuva butonu popup yerine turnuva sahnesini açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('TURNUVA'));
    await tester.pumpAndSettle();

    expect(find.byType(TournamentScreen), findsOneWidget);
    expect(find.text('ALTIN ISTAKA TURNUVASI'), findsOneWidget);
    expect(find.textContaining('Yaklaşan turnuvalar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

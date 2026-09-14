import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/oda.dart';
import 'package:flutter_application_1/tournament.dart';

Future<void> pumpRouteTransition(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> disposeGameRoute(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Katlamalı seçimi oyun ekranını doğru modla açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('OYUN MODLARI'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('feature-entry-Katlamalı')));
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.entryPoint, GameEntryPoint.gameMode);
    expect(game.launchConfig.mode, OkeyGameMode.progressive);
    expect(game.launchConfig.selectionLabel, 'Katlamalı');
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });

  testWidgets('seçilen oda oyun ekranına oda bilgisiyle gider', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoomSelectScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Odaya Gir'));
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.entryPoint, GameEntryPoint.room);
    expect(game.launchConfig.selectionLabel, 'Başlangıç');
    expect(game.launchConfig.entryFee, 500);
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });

  testWidgets('turnuva maçı oyun ekranına tur bilgisiyle gider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: TournamentScreen()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('tournament-action')));
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.entryPoint, GameEntryPoint.tournament);
    expect(game.launchConfig.tournamentRound, 0);
    expect(game.launchConfig.opponent, 'Deniz');
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/game_mode_select.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/oda.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/daily_league.dart';
import 'package:flutter_application_1/league_screen.dart';

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
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('okey/league_reminder'),
          (call) async => call.method == 'requestPermission' ? false : null,
        );
    playerProgress.reset();
    await dailyLeague.load();
  });

  testWidgets('Renkli seçim ayrı oyun modu olarak açılır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: GameModeSelectScreen()));
    await tester.pump(const Duration(milliseconds: 650));

    await tester.tap(
      find.byKey(const ValueKey('game-mode-card-color-bonus-101')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('game-mode-start')));
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.mode, OkeyGameMode.colorBonus101);
    expect(game.launchConfig.modeLabel, 'Renkli 101');
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });

  testWidgets('Katlamalı seçimi oyun ekranını doğru modla açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('OYUN\nMODLARI'));
    await pumpRouteTransition(tester);
    expect(find.byType(GameModeSelectScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-mode-card-color-bonus-101')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('game-mode-card-progressive')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('game-mode-start')));
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

    final coinsBefore = playerProgress.coins;
    final dynamic enterButton = tester.widget(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_EnterRoomButton',
      ),
    );
    enterButton.onTap();
    enterButton.onTap();
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.entryPoint, GameEntryPoint.room);
    expect(game.launchConfig.selectionLabel, 'Başlangıç');
    expect(game.launchConfig.entryFee, 2000);
    expect(playerProgress.coins, coinsBefore - 2000);
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });

  testWidgets('lig Oyna butonu ayni sonsuz Hemen Oyna masasına gider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LeagueScreen()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('league-play')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await pumpRouteTransition(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.launchConfig.entryPoint, GameEntryPoint.quickPlay);
    expect(game.launchConfig.tournamentRound, isNull);
    expect(game.launchConfig.opponent, isNull);
    expect(tester.takeException(), isNull);
    await disposeGameRoute(tester);
  });

  testWidgets('ligden oyuna girip cikmak tamamlanmamis eli lige eklemez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LeagueScreen()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('league-play')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await pumpRouteTransition(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await pumpRouteTransition(tester);

    expect(find.byKey(const ValueKey('league-progress')), findsOneWidget);
    expect(find.text('0 / 20 EL'), findsOneWidget);
    expect(find.textContaining('Rakip'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

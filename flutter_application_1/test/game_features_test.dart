import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/game_navigation.dart';
import 'package:flutter_application_1/difficulty_picker.dart';
import 'package:flutter_application_1/daily_challenge.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/saved_game.dart';
import 'package:flutter_application_1/main.dart' as app;

import 'panel_artwork_test_support.dart';

Future<void> frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  preparePanelArtwork();
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await savedGame.clear();
    playerProgress.reset();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('okey/league_reminder'),
      (_) async => null,
    );
  });

  test(
    'quick play cycles start easy or medium and use every difficulty once',
    () {
      final orders = <String>{};
      for (var seed = 0; seed < 500; seed++) {
        final order = quickPlayDifficulties(Random(seed));
        expect(order.first, isNot(BotDifficulty.hard));
        expect(order.toSet(), BotDifficulty.values.toSet());
        orders.add(order.map((value) => value.name).join(','));
      }
      expect(orders, hasLength(4));
    },
  );

  test('daily challenge checks mode and win, persists and pays once', () async {
    var now = DateTime(2026, 1, 1);
    final progress = PlayerProgressController();
    final challenge = DailyChallengeController(progress, clock: () => now);
    while (challenge.definition.mode != OkeyGameMode.progressive) {
      now = now.add(const Duration(days: 1));
    }
    await challenge.load();
    await challenge.recordRound(
      config: const GameLaunchConfig.quickPlay(),
      won: true,
    );
    expect(challenge.current, 0);
    const config = GameLaunchConfig.gameMode(
      mode: OkeyGameMode.progressive,
      id: 'progressive',
      label: 'Katlamalı',
    );
    await challenge.recordRound(config: config, won: false);
    expect(challenge.current, 0);
    await challenge.recordRound(config: config, won: true);
    expect(challenge.canClaim, isTrue);
    final before = progress.coins;
    final claims = await Future.wait([challenge.claim(), challenge.claim()]);
    expect(claims.reduce((a, b) => a + b), 500);
    expect(progress.coins, before + 500);
    final restored = DailyChallengeController(progress, clock: () => now);
    await restored.load();
    expect(restored.claimed, isTrue);
    expect(await restored.claim(), 0);
    now = now.add(const Duration(days: 1));
    restored.refresh();
    expect(restored.claimed, isFalse);
    expect(restored.current, 0);
  });

  test('malformed stored game does not create a Continue action', () async {
    await SharedPreferencesAsync().setString(
      SavedGameController.storageKey,
      '{"version":1}',
    );
    final store = SavedGameController();
    await store.load();
    expect(store.hasGame, isFalse);
  });

  testWidgets(
    'difficulty picker cancellation costs nothing and selection configures every bot',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const room = GameLaunchConfig.room(
        id: 'room-0',
        label: 'Başlangıç',
        entryFee: 2000,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openGameScreen<void>(context, config: room),
                child: const Text('START'),
              ),
            ),
          ),
        ),
      );
      final before = playerProgress.coins;
      await tester.tap(find.text('START'));
      await frames(tester);
      expect(find.byKey(const ValueKey('difficulty-picker')), findsOneWidget);
      expect(playerProgress.coins, before);
      final easy = tester.getCenter(
        find.byKey(const ValueKey('difficulty-easy')),
      );
      final hard = tester.getCenter(
        find.byKey(const ValueKey('difficulty-hard')),
      );
      expect(easy.dy, hard.dy);
      expect(easy.dx, lessThan(hard.dx));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await frames(tester);
      expect(playerProgress.coins, before);
      await tester.tap(find.text('START'));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('difficulty-hard')));
      await frames(tester, 22);
      expect(playerProgress.coins, before - 2000);
      expect(
        tester
            .widget<GameScreen>(find.byType(GameScreen))
            .launchConfig
            .difficulty,
        BotDifficulty.hard,
      );
      expect(savedGame.hasGame, isTrue);
      expect(
        (savedGame.snapshot!['bots'] as List)
            .map((bot) => bot['difficulty'])
            .toSet(),
        {'hard'},
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'room checkpoint resumes next hand without charging or replaying rewards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = const GameLaunchConfig.room(
        id: 'room-0',
        label: 'Başlangıç',
        entryFee: 2000,
      ).withDifficulty(BotDifficulty.hard);
      await tester.pumpWidget(
        MaterialApp(home: GameScreen(startingPlayer: 0, launchConfig: config)),
      );
      await frames(tester, 22);
      final checkpoint =
          jsonDecode(jsonEncode(savedGame.snapshot)) as Map<String, dynamic>;
      checkpoint['betweenRounds'] = true;
      checkpoint['penalty'] = 42;
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      await savedGame.save(checkpoint);
      final coins = playerProgress.coins;
      final games = playerProgress.gamesPlayed;
      await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
      await frames(tester);
      await tester.tap(find.text('DEVAM ET'));
      await frames(tester, 12);
      for (
        var attempt = 0;
        attempt < 80 && find.byType(GameScreen).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await frames(tester, 1);
      }
      expect(find.byType(GameScreen), findsOneWidget);
      await frames(tester, 5);
      expect(find.byKey(const ValueKey('difficulty-picker')), findsNothing);
      expect(playerProgress.coins, coins);
      expect(playerProgress.gamesPlayed, games);
      expect(savedGame.snapshot!['el'], 2);
      expect(savedGame.snapshot!['penalty'], 42);
      expect(
        tester
            .widget<GameScreen>(find.byType(GameScreen))
            .launchConfig
            .difficulty,
        BotDifficulty.hard,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resume preserves cards slots deck and difficulty without a new deal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const config = GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            startingPlayer: 0,
            launchConfig: config.withDifficulty(BotDifficulty.hard),
          ),
        ),
      );
      await frames(tester, 22);
      await tester.tap(find.text('SERİ DİZ'));
      await frames(tester, 5);
      expect(savedGame.hasGame, isTrue);
      final saved =
          jsonDecode(jsonEncode(savedGame.snapshot)) as Map<String, dynamic>;
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      final reloaded = SavedGameController();
      await reloaded.load();
      expect(reloaded.hasGame, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            savedState: saved,
            launchConfig: GameLaunchConfig.fromJson(
              saved['config'] as Map<String, dynamic>,
            ),
          ),
        ),
      );
      await frames(tester, 5);
      final after = savedGame.snapshot!;
      for (final key in [
        'rack',
        'slots',
        'deck',
        'melds',
        'discards',
        'el',
        'turn',
        'drawn',
        'difficultyOrder',
        'minimumScore',
        'minimumPairs',
      ]) {
        expect(after[key], saved[key], reason: key);
      }
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_DealtRackTile',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
      await frames(tester);
      expect(find.text('HEMEN OYNA'), findsOneWidget);
      expect(find.text('DEVAM ET'), findsOneWidget);
      expect(
        tester.getCenter(find.text('HEMEN OYNA')).dx,
        lessThan(tester.getCenter(find.text('DEVAM ET')).dx),
      );
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await frames(tester);
      expect(find.byKey(const ValueKey('daily-challenge-card')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('popup-outside-close')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('home-missions-button')));
      await frames(tester);
      expect(
        find.byKey(const ValueKey('daily-challenge-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-challenge-countdown')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester, 12);
      expect(tester.takeException(), isNull);
    },
  );
}

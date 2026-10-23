import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/game_mode_select.dart';
import 'package:flutter_application_1/oda.dart';
import 'package:flutter_application_1/player_progress.dart';

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  preparePanelArtwork();
  setUp(() {
    playerProgress.reset();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
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
  });

  for (final room in [false, true]) {
    for (final difficulty in BotDifficulty.values) {
      testWidgets(
        '${room ? 'room' : 'mode'} play waits for ${difficulty.name} difficulty and opens once',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(800, 360));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              home: room
                  ? const RoomSelectScreen()
                  : const GameModeSelectScreen(),
            ),
          );
          await _frames(tester);
          final before = playerProgress.coins;
          final play = find.byKey(
            ValueKey(room ? 'room-enter-button' : 'game-mode-start'),
          );
          // Two callbacks model a fast double tap before the modal paints.
          final callback = tester.widget<TextButton>(play).onPressed!;
          callback();
          callback();
          await _frames(tester, 4);
          expect(
            find.byKey(const ValueKey('difficulty-picker')),
            findsOneWidget,
          );
          expect(find.byType(GameScreen), findsNothing);
          expect(playerProgress.coins, before);
          for (final level in BotDifficulty.values) {
            expect(
              find.byKey(ValueKey('difficulty-${level.name}')).hitTestable(),
              findsOneWidget,
            );
          }
          await tester.tap(
            find.byKey(ValueKey('difficulty-${difficulty.name}')),
          );
          await _frames(tester, 12);
          final game = tester.widget<GameScreen>(find.byType(GameScreen));
          expect(game.launchConfig.difficulty, difficulty);
          expect(
            game.launchConfig.entryPoint,
            room ? GameEntryPoint.room : GameEntryPoint.gameMode,
          );
          expect(playerProgress.coins, room ? before - 1500 : before);
          expect(find.byKey(const ValueKey('difficulty-picker')), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await _frames(tester, 2);
        },
      );
    }

    testWidgets(
      '${room ? 'room' : 'mode'} difficulty cancellation keeps the selection and balance',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 360));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: room
                ? const RoomSelectScreen()
                : const GameModeSelectScreen(),
          ),
        );
        await _frames(tester);
        final before = playerProgress.coins;
        final play = find.byKey(
          ValueKey(room ? 'room-enter-button' : 'game-mode-start'),
        );
        await tester.tap(play);
        await _frames(tester, 4);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await _frames(tester, 4);
        expect(find.byType(GameScreen), findsNothing);
        expect(find.byKey(const ValueKey('difficulty-picker')), findsNothing);
        expect(playerProgress.coins, before);
        await tester.tap(play);
        await _frames(tester, 4);
        expect(find.byKey(const ValueKey('difficulty-picker')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

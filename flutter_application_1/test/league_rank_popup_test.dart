import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/daily_league.dart';
import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';

void main() {
  setUp(() async {
    await dailyLeague.resetForTesting();
    await SharedPreferencesAsync().clear();
    await dailyLeague.load();
    for (var n = 0; n < 3; n++) {
      await dailyLeague.recordRound(
        config: const GameLaunchConfig.quickPlay(),
        roundId: 'notice-$n',
        tablePenalties: [80, 50, 60, 70],
        simulatedPenalties: List.filled(16, 202),
      );
    }
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
          final playerId = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (_) async => null,
          );
        }
        return null;
      },
    );
  });
  testWidgets(
    'league rank appears at new hand start, fades, and does not repeat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(
            startingPlayer: 0,
            launchConfig: GameLaunchConfig.gameMode(
              mode: OkeyGameMode.classic101,
              id: 'custom',
              label: 'Kuralı sen belirle',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('league-rank-popup')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('league-rank-popup')), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('league-rank-popup')), findsOneWidget);
      expect(find.text('4. sıradasın'), findsOneWidget);
      expect(find.text('20 yarışmacı · 3/20 el tamamlandı'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.tap(find.byKey(const ValueKey('rack-visible-tile-0')));
      // A random first tile may be okey, whose single tap waits for the
      // double-tap window used to reveal its face.
      await tester.pump(const Duration(milliseconds: 350));
      final dynamic rackArea = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_RackArea',
        ),
      );
      expect(
        (rackArea.rack as List<Tile>).any((tile) => tile.selected),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('league-rank-popup')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('league-rank-popup')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

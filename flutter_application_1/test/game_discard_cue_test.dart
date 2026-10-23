import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/game.dart';

void main() {
  setUp(() {
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

  testWidgets(
    'yellow discard cue follows the player turn without moving its target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      final cue = find.byKey(const ValueKey('discard-turn-highlight-Oyuncu 1'));
      Color borderColor() =>
          (tester.widget<AnimatedContainer>(cue).foregroundDecoration
                  as BoxDecoration)
              .border!
              .top
              .color;
      expect(borderColor(), const Color(0xFFFFD54F));
      final target = find.byKey(const ValueKey('discard-target-Oyuncu 1'));
      final bounds = tester.getRect(target);
      final dynamic rack = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RackArea'),
      );
      final tile = (rack.rack as List<Tile>).firstWhere(
        (tile) => !tile.isOkey && !tile.isFakeOkey,
      );
      await tester.tap(find.byKey(ValueKey('rack-tile-${tile.id}')));
      await tester.pump();
      await tester.tap(find.text('TAŞ AT'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(borderColor(), Colors.transparent);
      expect(tester.getRect(target), bounds);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

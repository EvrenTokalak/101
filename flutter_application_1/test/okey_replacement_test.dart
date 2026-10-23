import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/daily_league.dart';
import 'package:flutter_application_1/game.dart';

void main() {
  setUp(() async {
    await dailyLeague.load();
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

  for (final type in ['seri', 'grup', 'cift']) {
    for (final manual in [false, true]) {
      testWidgets(
        '$type okey exchange preserves the final rack tile and can be undone (${manual ? 'drag' : 'button'})',
        (tester) async {
          final game = await _openPlayerAndArrange(
            tester,
            type: type,
            slot: manual ? 20 : 2,
          );
          if (manual) {
            await _dragToMeld(tester, game.replacement, type);
          } else {
            await tester.tap(find.text('İŞLE'));
          }
          await tester.pump(const Duration(milliseconds: 650));

          expect(game.meld.tiles, contains(game.replacement));
          expect(game.meld.tiles, isNot(contains(game.okey)));
          expect(game.rack, [game.okey]);
          expect(game.slots[game.originalSlot], game.okey.id);
          expect(game.slots.whereType<int>(), orderedEquals([game.okey.id]));
          expect(
            find.byKey(ValueKey('rack-tile-${game.okey.id}')),
            findsOneWidget,
          );
          expect(find.textContaining('son atış için'), findsNothing);

          await tester.tap(find.text('GERİ\nAL'));
          await tester.pump(const Duration(milliseconds: 650));
          expect(game.rack, [game.replacement]);
          expect(game.meld.tiles, contains(game.okey));
          expect(game.meld.tiles, isNot(contains(game.replacement)));
          expect(game.slots[game.originalSlot], game.replacement.id);
          expect(
            game.slots.whereType<int>(),
            orderedEquals([game.replacement.id]),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final type in ['seri', 'grup', 'cift']) {
    for (final manual in [false, true]) {
      testWidgets(
        '$type exchange keeps spare tiles and unique rack slots (${manual ? 'drag' : 'button'})',
        (tester) async {
          final game = await _openPlayerAndArrange(
            tester,
            type: type,
            slot: manual ? 2 : 20,
          );
          final spare = Tile(id: 13000, number: 13, color: TileColor.black);
          game.rack.add(spare);
          game.slots[29] = spare.id;
          final dynamic state = tester.state(find.byType(GameScreen));
          state.setState(() {});
          await tester.pump();

          if (manual) {
            await _dragToMeld(tester, game.replacement, type);
          } else {
            await tester.tap(find.text('İŞLE'));
          }
          await tester.pump(const Duration(milliseconds: 650));
          expect(game.rack, unorderedEquals([game.okey, spare]));
          expect(game.slots[game.originalSlot], game.okey.id);
          expect(game.slots[29], spare.id);
          expect(game.slots.whereType<int>().toSet(), {game.okey.id, spare.id});
          expect(game.slots.whereType<int>(), hasLength(2));
          expect(game.meld.tiles, contains(game.replacement));
          expect(game.meld.tiles, isNot(contains(game.okey)));

          await tester.tap(find.text('GERİ\nAL'));
          await tester.pump(const Duration(milliseconds: 650));
          expect(game.rack, unorderedEquals([game.replacement, spare]));
          expect(game.slots[game.originalSlot], game.replacement.id);
          expect(game.slots[29], spare.id);
          expect(game.slots.whereType<int>(), hasLength(2));
          expect(game.meld.tiles, contains(game.okey));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('the final rack tile cannot be added without an okey exchange', (
    tester,
  ) async {
    final game = await _openPlayerAndArrange(tester, type: 'seri', slot: 20);
    game.meld.tiles = [
      Tile(id: 12001, number: 2, color: TileColor.red),
      Tile(id: 12002, number: 3, color: TileColor.red),
      Tile(id: 12003, number: 4, color: TileColor.red),
    ];
    final dynamic state = tester.state(find.byType(GameScreen));
    state.setState(() {});
    await tester.pump();
    await tester.tap(find.text('İŞLE'));
    await tester.pump(const Duration(milliseconds: 650));
    expect(game.rack, [game.replacement]);
    expect(game.meld.tiles, hasLength(3));
    expect(game.slots[20], game.replacement.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<_ExchangeGame> _openPlayerAndArrange(
  WidgetTester tester, {
  required String type,
  required int slot,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(home: GameScreen(startingPlayer: 0)),
  );
  await tester.pump(const Duration(milliseconds: 2700));
  final dynamic area = tester.widget(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RackArea'),
  );
  final rack = area.rack as List<Tile>;
  final slots = area.slots as List<int?>;
  var id = 10000;
  final replacement = Tile(id: id++, number: 5, color: TileColor.red);
  rack
    ..clear()
    ..addAll([
      for (final number in [2, 4, 8, 10, 12])
        for (var copy = 0; copy < 2; copy++)
          Tile(id: id++, number: number, color: TileColor.blue),
      replacement,
    ]);
  slots.fillRange(0, slots.length, null);
  for (var index = 0; index < rack.length; index++) {
    slots[index] = rack[index].id;
  }
  final dynamic state = tester.state(find.byType(GameScreen));
  state.setState(() {});
  await tester.pump();
  await tester.tap(find.text('ÇİFT AÇ'));
  await tester.pump(const Duration(milliseconds: 650));
  expect(rack, [replacement]);

  final dynamic table = tester.widget(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TableArea'),
  );
  final melds = table.melds as List<Meld>;
  final okey = Tile(id: id++, number: 7, color: TileColor.yellow, isOkey: true);
  final meld = Meld(
    type: type,
    tiles: switch (type) {
      'seri' => [
        Tile(id: id++, number: 4, color: TileColor.red),
        okey,
        Tile(id: id++, number: 6, color: TileColor.red),
      ],
      'grup' => [
        for (final color in [TileColor.blue, TileColor.black, TileColor.yellow])
          Tile(id: id++, number: 5, color: color),
        okey,
      ],
      _ => [Tile(id: id++, number: 5, color: TileColor.red), okey],
    },
  );
  melds
    ..clear()
    ..add(meld);
  slots.fillRange(0, slots.length, null);
  slots[slot] = replacement.id;
  state.setState(() {});
  await tester.pump();
  return _ExchangeGame(rack, slots, replacement, okey, meld, slot);
}

Future<void> _dragToMeld(
  WidgetTester tester,
  Tile replacement,
  String type,
) async {
  final tileFinder = find.byKey(ValueKey('rack-tile-${replacement.id}'));
  final drag = tester.widget<Draggable>(tileFinder);
  final meldRect = tester.getRect(
    find.byKey(ValueKey('${type == 'cift' ? 'pair' : 'run'}-meld-0')),
  );
  final gesture = await tester.startGesture(tester.getCenter(tileFinder));
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 12)),
  );
  await gesture.moveTo(meldRect.center - drag.feedbackOffset);
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.up();
  await tester.pump();
}

class _ExchangeGame {
  final List<Tile> rack;
  final List<int?> slots;
  final Tile replacement;
  final Tile okey;
  final Meld meld;
  final int originalSlot;

  const _ExchangeGame(
    this.rack,
    this.slots,
    this.replacement,
    this.okey,
    this.meld,
    this.originalSlot,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/daily_league.dart';

void main() {
  testWidgets(
    'side bot profiles retain their original size on a short phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump();
      for (final seat in ['Oyuncu 2', 'Oyuncu 4']) {
        final avatar = tester.getRect(find.byKey(ValueKey('bot-avatar-$seat')));
        expect(avatar.width, greaterThanOrEqualTo(35));
        expect(avatar.height, greaterThanOrEqualTo(35));
      }
      for (final pair in const [
        ('Oyuncu 2', 'görseller/pp/10_kartal.png'),
        ('Oyuncu 3', 'görseller/pp/11_timsah.png'),
        ('Oyuncu 4', 'görseller/pp/12_kopekbaligi.png'),
      ]) {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(ValueKey('bot-avatar-${pair.$1}')),
            matching: find.byType(Image),
          ),
        );
        expect(
          ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
          pair.$2,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reduced motion shows the rack without a deal animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GameScreen(startingPlayer: 0),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DealtRackTile',
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('game-rack-area')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  setUp(() async {
    await dailyLeague.load();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final playerId = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (call) async => null,
          );
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global/events'),
          (call) async => null,
        );
  });
  testWidgets('rack deal advances smoothly on consecutive display frames', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final dynamic dealt = tester.widget(
      find
          .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_DealtRackTile',
          )
          .first,
    );
    final progress = dealt.progress as ValueListenable<double>;
    for (var frame = 0; frame < 8; frame++) {
      final previous = progress.value;
      await tester.pump(const Duration(milliseconds: 16));
      expect(progress.value, greaterThan(previous));
    }
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_DealtRackTile',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'player turn cue follows deal, allows tile taps and does not repeat on settings resume',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      expect(find.byKey(const ValueKey('player-turn-notice')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byKey(const ValueKey('player-turn-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('player-turn-rack-glow')), findsNothing);
      final dynamic area = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_RackArea',
        ),
      );
      final tile = (area.rack as List<Tile>).firstWhere(
        (tile) => !tile.isOkey && !tile.isFakeOkey,
      );
      await tester.tap(find.byKey(ValueKey('rack-tile-${tile.id}')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tile.selected, isTrue);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.byKey(const ValueKey('player-turn-notice')), findsNothing);
      expect(find.byKey(const ValueKey('player-turn-rack-glow')), findsNothing);
      final tableFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TableArea',
      );
      final tableBeforeSettings = tester.widget(tableFinder);
      await tester.tap(find.byKey(const ValueKey('game-settings-button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        identical(tester.widget(tableFinder), tableBeforeSettings),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('settings-close-button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('player-turn-notice')), findsNothing);
      expect(
        identical(tester.widget(tableFinder), tableBeforeSettings),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('game buttons shrink on quick press and reset on cancellation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.gameMode(
            mode: OkeyGameMode.classic101,
            id: 'press-test',
            label: 'Classic',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2700));
    final arrange = find.text('SERİ DİZ');
    final scale = find.ancestor(
      of: arrange,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    final press = await tester.startGesture(tester.getCenter(arrange));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<AnimatedScale>(scale).scale, .96);
    await press.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    final cancelled = await tester.startGesture(tester.getCenter(arrange));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<AnimatedScale>(scale).scale, .96);
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    final inactive = find.text('TAŞ AT');
    final inactiveScale = find.ancestor(
      of: inactive,
      matching: find.byType(AnimatedScale),
    );
    final inactivePress = await tester.startGesture(tester.getCenter(inactive));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<AnimatedScale>(inactiveScale).scale, 1);
    await inactivePress.up();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.takeException(), isNull);
    final removedPress = await tester.startGesture(tester.getCenter(arrange));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await removedPress.up();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'result totals track this session while league keeps its daily scores',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await dailyLeague.resetForTesting();
        await SharedPreferencesAsync().clear();
        await dailyLeague.load();
        await dailyLeague.recordRound(
          config: const GameLaunchConfig.quickPlay(),
          roundId: 'earlier-session',
          tablePenalties: [700, 800, 900, 1000],
          simulatedPenalties: List.filled(16, 1000),
        );
      });
      addTearDown(() => dailyLeague.resetForTesting(waitForWrites: false));
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      var id = 85000;
      Future<GameEndDialog> finishHand() async {
        final dynamic area = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final rack = area.rack as List<Tile>;
        final slots = area.slots as List<int?>;
        rack.clear();
        rack.addAll([
          for (final number in [2, 4, 8, 10, 12])
            for (var copy = 0; copy < 2; copy++)
              Tile(id: id++, number: number, color: TileColor.blue),
          Tile(id: id++, number: 13, color: TileColor.red),
        ]);
        slots.fillRange(0, slots.length, null);
        for (var i = 0; i < rack.length; i++) {
          slots[i] = rack[i].id;
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        state.setState(() {});
        await tester.pump();
        await tester.tap(find.text('ÇİFT AÇ'));
        await tester.pump(const Duration(milliseconds: 650));
        expect(rack, hasLength(1));
        await tester.tap(find.byKey(ValueKey('rack-tile-${rack.single.id}')));
        await tester.pump();
        await tester.tap(find.text('TAŞ AT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 3500));
        await tester.pump(const Duration(milliseconds: 500));
        final result = tester.widget<GameEndDialog>(find.byType(GameEndDialog));
        var leagueRecorded = false;
        result.leagueUpdate!.then((_) => leagueRecorded = true);
        for (var attempt = 0; attempt < 500 && !leagueRecorded; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(leagueRecorded, isTrue);
        return result;
      }

      final first = await finishHand();
      expect(first.totalPenalty, -101);
      for (var i = 0; i < first.bots.length; i++) {
        expect(first.bots[i].penalty + first.botPens[i], first.botPens[i]);
      }
      expect(
        dailyLeague.standings.firstWhere((entry) => entry.isPlayer).penalty,
        599,
      );
      first.onNewRound();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000));
      final second = await finishHand();
      expect(second.totalPenalty, -202);
      for (var i = 0; i < second.bots.length; i++) {
        expect(second.bots[i].penalty, first.botPens[i]);
      }
      expect(
        dailyLeague.standings.firstWhere((entry) => entry.isPlayer).penalty,
        498,
      );
      second.onResetMatch();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000));
      final reset = await finishHand();
      expect(reset.totalPenalty, -101);
      expect(reset.bots.every((bot) => bot.penalty == 0), isTrue);
      expect(
        dailyLeague.standings.firstWhere((entry) => entry.isPlayer).penalty,
        397,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('room match pays the double entry fee once after three hands', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    playerProgress.reset(coins: 10000);
    addTearDown(playerProgress.reset);
    expect(playerProgress.trySpendCoins(2000), isTrue);
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.room(
            id: 'room-0',
            label: 'Başlangıç',
            entryFee: 2000,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2700));
    var id = 96000;
    for (var round = 1; round <= 3; round++) {
      final dynamic area = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RackArea'),
      );
      final rack = area.rack as List<Tile>;
      final slots = area.slots as List<int?>;
      rack.clear();
      rack.addAll([
        for (final number in [2, 4, 8, 10, 12])
          for (var copy = 0; copy < 2; copy++)
            Tile(id: id++, number: number, color: TileColor.blue),
        Tile(id: id++, number: 13, color: TileColor.red),
      ]);
      slots.fillRange(0, slots.length, null);
      for (var i = 0; i < rack.length; i++) {
        slots[i] = rack[i].id;
      }
      final dynamic state = tester.state(find.byType(GameScreen));
      state.setState(() {});
      await tester.pump();
      await tester.tap(find.text('ÇİFT AÇ'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(rack, hasLength(1));
      await tester.tap(find.byKey(ValueKey('rack-tile-${rack.single.id}')));
      await tester.pump();
      await tester.tap(find.text('TAŞ AT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 400));
      final result = tester.widget<GameEndDialog>(find.byType(GameEndDialog));
      expect(result.elCount, round);
      expect(result.matchComplete, round == 3);
      expect(result.reward!.coins, round == 3 ? 4000 : 0);
      expect(playerProgress.coins, round == 3 ? 12000 : 8000);
      if (round < 3) {
        result.onNewRound();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 3000));
      } else {
        expect(find.text('+4.000 ALTIN'), findsOneWidget);
        state.setState(() {});
        await tester.pump();
        expect(playerProgress.coins, 12000);
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'button draw pulses until next touch and discard visibly travels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.tap(find.byKey(const ValueKey('rack-visible-tile-0')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('TAŞ AT'));
      await tester.pump();
      await tester.pump();
      final flights = find.byWidgetPredicate(
        (widget) => widget.key.toString().contains('player-tile-flight-'),
      );
      expect(flights, findsWidgets);
      await tester.pump(const Duration(milliseconds: 220));
      expect(flights, findsWidgets);
      for (var frame = 0; frame < 180; frame++) {
        final dynamic table = tester.widget(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_TableArea',
          ),
        );
        if (table.canDraw == true) break;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(find.text('TAŞ ÇEK'), findsOneWidget);
      await tester.tap(find.text('TAŞ ÇEK'));
      await tester.pump();
      await tester.pump();
      expect(flights, findsWidgets);
      final frame = find.byKey(const ValueKey('drawn-tile-pulse-frame'));
      expect(frame, findsOneWidget);
      expect(
        find.descendant(of: flights, matching: frame),
        findsOneWidget,
        reason: 'The border belongs to the flying tile, not its rack slot.',
      );
      final borderStart = tester.getRect(frame);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(frame).center, isNot(borderStart.center));
      final decoration =
          tester.widget<DecoratedBox>(frame).decoration as BoxDecoration;
      expect(decoration.color, isNull);
      expect(decoration.gradient, isNull);
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);
      await tester.pump(const Duration(seconds: 3));
      expect(frame, findsOneWidget);
      expect(find.descendant(of: flights, matching: frame), findsNothing);
      final before = tester.widget<DecoratedBox>(frame).decoration;
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<DecoratedBox>(frame).decoration, isNot(before));
      await tester.tap(find.byKey(const ValueKey('grid-per-summary')));
      await tester.pump();
      expect(frame, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'six percent leading-edge overlap pushes before the finger reaches the tile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      final source = find.byKey(const ValueKey('rack-slot-0'));
      final target = find.byKey(const ValueKey('rack-slot-8'));
      final sourceKey = tester
          .widget<Draggable>(
            find.descendant(
              of: source,
              matching: find.byWidgetPredicate((widget) => widget is Draggable),
            ),
          )
          .key!;
      final rect = tester.getRect(target);
      final tileWidth = rect.width - 1.2;
      final drop = Offset(
        rect.left - tileWidth / 2 + tileWidth * 0.06,
        rect.center.dy,
      );
      expect(drop.dx, lessThan(rect.left));
      await tester.dragFrom(
        tester.getCenter(source),
        drop - tester.getCenter(source),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.descendant(of: target, matching: find.byKey(sourceKey)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bot opening frame and remaining badge update independently of name',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump();
      final label = find.byKey(const ValueKey('bot-name-Oyuncu 2'));
      expect(find.text('Açmadı'), findsNothing);
      expect(find.text('Açtı'), findsNothing);
      expect(find.textContaining('Kalan:'), findsNothing);
      expect(tester.widget<Text>(label).style!.color, OC.cream);
      final seat = find.byKey(const ValueKey('seat-Oyuncu 2'));
      final info = find.ancestor(
        of: seat,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_PlayerInfo',
        ),
      );
      final dynamic widget = tester.widget(info);
      final BotPlayer bot = widget.bot as BotPlayer;
      final int fakeOkeyValue = widget.fakeOkeyValue as int;
      final name = bot.displayName;
      expect(tester.widget<Text>(label).data, name);
      final avatar = find.byKey(const ValueKey('bot-avatar-frame-Oyuncu 2'));
      final badge = find.byKey(const ValueKey('bot-remaining-Oyuncu 2'));
      expect(
        (tester.widget<Container>(avatar).decoration as BoxDecoration)
            .border!
            .top
            .color,
        OC.numRed,
      );
      expect(badge, findsNothing);
      final expected = Rules.penaltyFor(bot.hand, fakeOkeyValue: fakeOkeyValue);
      bot.hasOpened = true;
      tester.element(info).markNeedsBuild();
      await tester.pump();
      expect(tester.widget<Text>(label).data, name);
      expect(tester.widget<Text>(badge).data, '$expected');
      expect(
        (tester.widget<Container>(avatar).decoration as BoxDecoration)
            .border!
            .top
            .color,
        const Color(0xFF83E5A0),
      );
      expect(tester.widget<Text>(label).maxLines, 1);
      expect(tester.widget<Text>(label).softWrap, isFalse);
      expect(tester.widget<Text>(label).style!.color, OC.cream);
      expect(
        find.descendant(of: seat, matching: find.byType(Text)),
        findsNWidgets(2),
      );
      for (final size in const [
        Size(1280, 720),
        Size(1024, 768),
        Size(568, 320),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pump();
        final labelRect = tester.getRect(label);
        final seatRect = tester.getRect(seat);
        expect(seatRect.contains(labelRect.topLeft), isTrue);
        expect(seatRect.contains(labelRect.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
      }
      bot.hand.clear();
      tester.element(info).markNeedsBuild();
      await tester.pump();
      expect(tester.widget<Text>(label).data, name);
      expect(tester.widget<Text>(badge).data, '0');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('game screen renders at desktop and short web sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(1280, 720),
      Size(1024, 420),
      Size(800, 450),
      Size(1024, 768),
      Size(1280, 800),
      Size(1920, 600),
      Size(1366, 1024),
      Size(768, 1024),
      Size(800, 1280),
      Size(390, 844),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
          home: const GameScreen(startingPlayer: 0),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('İŞLE'), findsOneWidget);
      expect(find.text('GERİ AL'), findsNothing);
      expect(find.byIcon(Icons.auto_fix_high_rounded), findsNothing);
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
      expect(find.text('ÇİFT AÇ'), findsOneWidget);
      expect(find.text('SERİ AÇ'), findsOneWidget);
      expect(find.text('SERİ DİZ'), findsOneWidget);
      expect(find.text('ÇİFT DİZ'), findsOneWidget);
      expect(find.text('TAŞ AT'), findsOneWidget);
      expect(find.byKey(const ValueKey('discard-Oyuncu 1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-settings-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('run-meld-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('group-meld-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('table-draw-column')), findsOneWidget);
      expect(find.byKey(const ValueKey('pair-meld-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('pair-grid-viewer')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pair-grid-viewer')),
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('opening-rule-caption')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('game-mode-caption')), findsOneWidget);
      expect(find.bySemanticsLabel('SIRADAN'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pair-area-drop-target')),
        findsOneWidget,
      );
      final tableBounds = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_TableArea',
        ),
      );
      final topAvatar = tester.getRect(
        find.byKey(const ValueKey('bot-avatar-frame-Oyuncu 3')),
      );
      final dynamic tableWidget = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_TableArea',
        ),
      );
      final gridBounds = tester.getRect(find.byKey(tableWidget.gridKey as Key));
      expect(
        gridBounds.top - tableBounds.top,
        closeTo(20, .1),
        reason: 'Top bot must not reduce the original grid height at $size',
      );
      expect(tableBounds.bottom - gridBounds.bottom, closeTo(8, .1));
      expect(
        topAvatar.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('game-help-button'))).top,
        ),
        reason: 'Top bot avatar must not be clipped at $size',
      );
      final sideOverlapPairs = <(String, String)>[
        ('Oyuncu 4', 'Oyuncu 3'),
        ('Oyuncu 4', 'Oyuncu 4'),
        ('Oyuncu 2', 'Oyuncu 2'),
      ];
      for (final pair in sideOverlapPairs) {
        final profileRect = tester.getRect(
          find.byKey(ValueKey('seat-${pair.$1}')),
        );
        final discardTargetRect = tester.getRect(
          find.byKey(ValueKey('discard-target-${pair.$2}')),
        );
        expect(
          profileRect.overlaps(discardTargetRect),
          isFalse,
          reason: '${pair.$1} / ${pair.$2} overlap at $size',
        );
      }

      final runGridSize = tester.getSize(
        find.byKey(const ValueKey('run-meld-grid')),
      );
      final groupGridSize = tester.getSize(
        find.byKey(const ValueKey('group-meld-grid')),
      );
      final pairGridSize = tester.getSize(
        find.byKey(const ValueKey('pair-meld-grid-surface')),
      );
      expect(groupGridSize.width, closeTo(runGridSize.width, 0.1));
      if (size.width < size.height) {
        final pairRect = tester.getRect(
          find.byKey(const ValueKey('pair-meld-grid-surface')),
        );
        final runRect = tester.getRect(
          find.byKey(const ValueKey('run-meld-grid')),
        );
        expect(pairRect.top, greaterThanOrEqualTo(runRect.bottom));
      }
      expect(
        (runGridSize.height / 8) / (runGridSize.width / 13),
        lessThanOrEqualTo(1.62),
        reason: 'Meld cells must keep their proportions at $size',
      );
      final rackRect = tester.getRect(
        find.byKey(const ValueKey('rack-area-surface')),
      );
      final rackTileSize = tester.getSize(
        find
            .byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_RackTileDraggable',
            )
            .first,
      );
      expect(
        rackTileSize.height / rackTileSize.width,
        closeTo(1.58, .001),
        reason: 'Rack tiles must keep their shape at $size',
      );
      expect(
        rackRect.height,
        lessThanOrEqualTo(size.width * 0.18 + 1),
        reason: 'Tall tablet windows must not stretch the rack at $size',
      );
      expect(pairGridSize.width / runGridSize.width, closeTo(8 / 13, 0.03));
      expect(
        pairGridSize.height / runGridSize.height,
        closeTo((6 * 0.86) / 8, 0.03),
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Draggable),
        findsWidgets,
      );

      if (size == const Size(1280, 720)) {
        Finder actionInkFinder(String label) => find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        InkWell actionInk(String label) =>
            tester.widget<InkWell>(actionInkFinder(label));
        expect(actionInk('SERİ DİZ').onTap, isNull);
        expect(actionInk('ÇİFT DİZ').onTap, isNull);
        expect(actionInk('İŞLE').onTap, isNull);
        expect(
          tester.getSize(actionInkFinder('İŞLE')).width,
          closeTo(tester.getSize(actionInkFinder('SERİ AÇ')).width, 0.1),
        );

        final player2 = tester.getCenter(
          find.byKey(const ValueKey('seat-Oyuncu 2')),
        );
        final player3 = tester.getCenter(
          find.byKey(const ValueKey('seat-Oyuncu 3')),
        );
        final player4 = tester.getCenter(
          find.byKey(const ValueKey('seat-Oyuncu 4')),
        );
        expect(player2.dx, greaterThan(player3.dx));
        expect(player4.dx, lessThan(player3.dx));
        expect(player3.dy, lessThan(player2.dy));

        final player2Discard = tester.getCenter(
          find.byKey(const ValueKey('discard-Oyuncu 2')),
        );
        final player1Discard = tester.getCenter(
          find.byKey(const ValueKey('discard-Oyuncu 1')),
        );
        final player3Discard = tester.getCenter(
          find.byKey(const ValueKey('discard-Oyuncu 3')),
        );
        final player4Discard = tester.getCenter(
          find.byKey(const ValueKey('discard-Oyuncu 4')),
        );
        expect(player3Discard.dy, closeTo(player2Discard.dy, 0.1));
        expect(player3Discard.dx, closeTo(player4Discard.dx, 0.1));
        expect(player1Discard.dx, closeTo(player2Discard.dx, 0.1));

        final runGridRect = tester.getRect(
          find.byKey(const ValueKey('run-meld-grid')),
        );
        final groupGridRect = tester.getRect(
          find.byKey(const ValueKey('group-meld-grid')),
        );
        final leftBotRect = tester.getRect(
          find.byKey(const ValueKey('seat-Oyuncu 4')),
        );
        final rightBotRect = tester.getRect(
          find.byKey(const ValueKey('seat-Oyuncu 2')),
        );
        expect(leftBotRect.right, lessThanOrEqualTo(runGridRect.left));
        expect(rightBotRect.left, greaterThanOrEqualTo(groupGridRect.right));
        final leftUpperDiscardTarget = tester.getRect(
          find.byKey(const ValueKey('discard-target-Oyuncu 3')),
        );
        final leftLowerDiscardTarget = tester.getRect(
          find.byKey(const ValueKey('discard-target-Oyuncu 4')),
        );
        final rightUpperDiscardTarget = tester.getRect(
          find.byKey(const ValueKey('discard-target-Oyuncu 2')),
        );
        expect(leftBotRect.overlaps(leftUpperDiscardTarget), isFalse);
        expect(leftBotRect.overlaps(leftLowerDiscardTarget), isFalse);
        expect(rightBotRect.overlaps(rightUpperDiscardTarget), isFalse);
        final openingCaptionCenter = tester.getCenter(
          find.byKey(const ValueKey('opening-rule-caption')),
        );
        final modeCaptionCenter = tester.getCenter(
          find.byKey(const ValueKey('game-mode-caption')),
        );
        expect(
          openingCaptionCenter.dx,
          inInclusiveRange(runGridRect.left, runGridRect.right),
        );
        expect(
          modeCaptionCenter.dx,
          inInclusiveRange(groupGridRect.left, groupGridRect.right),
        );
        final playerDiscardZone = tester.getRect(
          find.byKey(const ValueKey('discard-target-Oyuncu 1')),
        );
        expect(playerDiscardZone.top, greaterThan(player2.dy));
        expect(playerDiscardZone.left, lessThan(groupGridRect.right));
        expect(playerDiscardZone.right, greaterThan(groupGridRect.right));
        expect(playerDiscardZone.height, greaterThan(66));
        for (final label in const [
          'Oyuncu 1',
          'Oyuncu 2',
          'Oyuncu 3',
          'Oyuncu 4',
        ]) {
          final discardRect = tester.getRect(
            find.byKey(ValueKey('discard-$label')),
          );
          final discardTargetRect = tester.getRect(
            find.byKey(ValueKey('discard-target-$label')),
          );
          expect(discardTargetRect.width, greaterThan(discardRect.width + 40));
          expect(discardRect.overlaps(runGridRect), isFalse);
          expect(discardRect.overlaps(groupGridRect), isFalse);
        }

        await tester.pump(const Duration(milliseconds: 2700));
        expect(actionInk('SERİ DİZ').onTap, isNotNull);
        expect(actionInk('ÇİFT DİZ').onTap, isNotNull);
        expect(actionInk('İŞLE').onTap, isNotNull);

        final draggable = find.byWidgetPredicate(
          (widget) => widget is Draggable,
        );
        final sourceSlot = find.byKey(const ValueKey('rack-slot-0'));
        final emptySlot = find.byKey(const ValueKey('rack-slot-14'));
        await tester.dragFrom(
          tester.getCenter(sourceSlot),
          tester.getCenter(emptySlot) - tester.getCenter(sourceSlot),
        );
        await tester.pump();

        expect(
          find.descendant(of: emptySlot, matching: draggable),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sourceSlot, matching: draggable),
          findsNothing,
        );

        expect(find.text('PERİ BURAYA BIRAK'), findsNothing);
        final gridViewers = tester.widgetList<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        expect(gridViewers, hasLength(3));
        for (final gridViewer in gridViewers) {
          expect(gridViewer.panEnabled, isTrue);
          expect(gridViewer.scaleEnabled, isTrue);
          expect(gridViewer.minScale, 1);
          expect(gridViewer.maxScale, 3.4);
          expect(gridViewer.boundaryMargin, EdgeInsets.zero);
        }
        final firstController = gridViewers.first.transformationController!;
        firstController.value = Matrix4.diagonal3Values(2, 2, 1);
        await tester.pump();
        expect(find.byKey(const ValueKey('grid-reset-button')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('grid-reset-button')));
        await tester.pumpAndSettle();
        expect(firstController.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
        expect(find.byKey(const ValueKey('grid-reset-button')), findsNothing);
        expect(find.byTooltip('Gridi yakınlaştır'), findsNothing);
        expect(find.byTooltip('Gridi uzaklaştır'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      }
    }
  });

  testWidgets('cift diz sonrasi ozet kutusu cift etiketini gosterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2700));

    await tester.tap(find.text('ÇİFT DİZ'));
    await tester.pump();

    expect(find.text('ÇİFT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('rack tile inserts using only its source gap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    final sourceSlot = find.byKey(const ValueKey('rack-slot-1'));
    final targetSlot = find.byKey(const ValueKey('rack-slot-7'));
    final shiftedSlot = find.byKey(const ValueKey('rack-slot-8'));
    final sourceTile = find.descendant(
      of: sourceSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final shiftedTile = find.descendant(
      of: shiftedSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final sourceKey = tester.widget<Draggable>(sourceTile).key!;
    final shiftedKey = tester.widget<Draggable>(shiftedTile).key!;
    final targetRect = tester.getRect(targetSlot);
    final neighbourBefore = tester.getCenter(shiftedSlot);

    await tester.dragFrom(
      tester.getCenter(sourceSlot),
      Offset(
            targetRect.center.dx + targetRect.width * 0.46,
            targetRect.center.dy,
          ) -
          tester.getCenter(sourceSlot),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-8')),
        matching: find.byKey(sourceKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-9')),
        matching: find.byKey(shiftedKey),
      ),
      findsOneWidget,
    );
    final neighbour = find.byKey(const ValueKey('rack-visible-tile-9'));
    final settledPosition = tester.getCenter(
      find.byKey(const ValueKey('rack-slot-9')),
    );
    expect(tester.getCenter(neighbour).dx, closeTo(neighbourBefore.dx, 1));
    await tester.pump(const Duration(milliseconds: 50));
    final halfway = tester.getCenter(neighbour);
    expect(halfway.dx, greaterThan(neighbourBefore.dx));
    expect(halfway.dx, lessThan(settledPosition.dx));
    expect(halfway.dy, closeTo(neighbourBefore.dy, 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getCenter(neighbour).dx, closeTo(settledPosition.dx, 1));
    expect(
      find.descendant(
        of: find.byKey(sourceKey),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
  });

  testWidgets('github rack drag uses an empty source placeholder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    final sourceSlot = find.byKey(const ValueKey('rack-slot-0'));
    final draggableFinder = find.descendant(
      of: sourceSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final draggable = tester.widget<Draggable>(draggableFinder);
    final placeholder = draggable.childWhenDragging as SizedBox;
    expect(placeholder.width, greaterThan(0));
    expect(placeholder.height, greaterThan(0));

    final pointer = tester.getCenter(sourceSlot) + const Offset(0, -40);
    final gesture = await tester.startGesture(tester.getCenter(sourceSlot));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    final feedback = find.byKey(const ValueKey('rack-drag-feedback-tile'));
    final initialFeedback = tester.getRect(feedback);
    await tester.pump(const Duration(milliseconds: 70));
    final midwayFeedback = tester.getRect(feedback);
    await tester.pump(const Duration(milliseconds: 80));
    final liftedFeedback = tester.getRect(feedback);
    expect(midwayFeedback.top, lessThan(initialFeedback.top));
    expect(midwayFeedback.top, greaterThan(liftedFeedback.top));
    expect(
      pointer.dy - liftedFeedback.bottom,
      closeTo(6, .1),
      reason: 'The tile should stay visible just above the fingertip',
    );
    final sourceTileWhileDragging = find.descendant(
      of: sourceSlot,
      matching: find.byKey(const ValueKey('rack-visible-tile-0')),
    );
    expect(sourceTileWhileDragging, findsNothing);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(
        of: sourceSlot,
        matching: find.byKey(const ValueKey('rack-visible-tile-0')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('left edge drop inserts before the target tile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    final vacancySource = find.byKey(const ValueKey('rack-slot-4'));
    final emptySlot = find.byKey(const ValueKey('rack-slot-14'));
    await tester.dragFrom(
      tester.getCenter(vacancySource),
      tester.getCenter(emptySlot) - tester.getCenter(vacancySource),
    );
    await tester.pump();

    final sourceSlot = find.byKey(const ValueKey('rack-slot-8'));
    final targetSlot = find.byKey(const ValueKey('rack-slot-7'));
    final sourceTile = find.descendant(
      of: sourceSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final targetTile = find.descendant(
      of: targetSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final sourceKey = tester.widget<Draggable>(sourceTile).key!;
    final targetKey = tester.widget<Draggable>(targetTile).key!;
    final targetRect = tester.getRect(targetSlot);

    final gesture = await tester.startGesture(tester.getCenter(sourceSlot));
    await gesture.moveTo(
      Offset(targetRect.left + targetRect.width * 0.04, targetRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final leftTilt = find.byKey(const ValueKey('rack-insertion-tilt-6'));
    final rightTilt = find.byKey(const ValueKey('rack-insertion-tilt-7'));
    expect(tester.widget<AnimatedRotation>(leftTilt).turns, lessThan(0));
    expect(tester.widget<AnimatedRotation>(rightTilt).turns, greaterThan(0));
    expect(tester.getRect(targetSlot), targetRect);
    await gesture.up();
    await tester.pump();

    expect(tester.widget<AnimatedRotation>(leftTilt).turns, 0);
    expect(tester.widget<AnimatedRotation>(rightTilt).turns, 0);

    expect(
      find.descendant(of: targetSlot, matching: find.byKey(sourceKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-8')),
        matching: find.byKey(targetKey),
      ),
      findsOneWidget,
    );
    // Kenar bandındaki bırakma, çift dokunma tanıyıcısının kısa bekleme
    // süresini başlatabilir; test kapanmadan bu süreyi tamamla.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('dropping near the left tile edge pushes only that tile chain', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    final sourceSlot = find.byKey(const ValueKey('rack-slot-0'));
    final targetSlot = find.byKey(const ValueKey('rack-slot-8'));
    final sourceTile = find.descendant(
      of: sourceSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final targetTile = find.descendant(
      of: targetSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final sourceKey = tester.widget<Draggable>(sourceTile).key!;
    final targetKey = tester.widget<Draggable>(targetTile).key!;

    final pushRect = tester.getRect(targetSlot);
    await tester.dragFrom(
      tester.getCenter(sourceSlot),
      Offset(pushRect.left + pushRect.width * 0.15, pushRect.center.dy) -
          tester.getCenter(sourceSlot),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-8')),
        matching: find.byKey(sourceKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-9')),
        matching: find.byKey(targetKey),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('tile centre does not trigger pushing or insertion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));
    final source = find.byKey(const ValueKey('rack-slot-0'));
    final target = find.byKey(const ValueKey('rack-slot-8'));
    final tiles = find.byWidgetPredicate((widget) => widget is Draggable);
    final sourceKey = tester
        .widget<Draggable>(find.descendant(of: source, matching: tiles))
        .key!;
    final targetKey = tester
        .widget<Draggable>(find.descendant(of: target, matching: tiles))
        .key!;
    await tester.dragFrom(
      tester.getCenter(source),
      tester.getCenter(target) - tester.getCenter(source),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.descendant(of: source, matching: find.byKey(sourceKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: target, matching: find.byKey(targetKey)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('right edge pushes the chain left', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    final vacancySource = find.byKey(const ValueKey('rack-slot-0'));
    final vacancyTarget = find.byKey(const ValueKey('rack-slot-14'));
    await tester.dragFrom(
      tester.getCenter(vacancySource),
      tester.getCenter(vacancyTarget) - tester.getCenter(vacancySource),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final sourceSlot = find.byKey(const ValueKey('rack-slot-8'));
    final targetSlot = find.byKey(const ValueKey('rack-slot-5'));
    final sourceTile = find.descendant(
      of: sourceSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final targetTile = find.descendant(
      of: targetSlot,
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final sourceKey = tester.widget<Draggable>(sourceTile).key!;
    final targetKey = tester.widget<Draggable>(targetTile).key!;

    final pushRect = tester.getRect(targetSlot);
    await tester.dragFrom(
      tester.getCenter(sourceSlot),
      Offset(pushRect.right - pushRect.width * 0.15, pushRect.center.dy) -
          tester.getCenter(sourceSlot),
    );
    await tester.pump();

    expect(
      find.descendant(of: targetSlot, matching: find.byKey(sourceKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-slot-4')),
        matching: find.byKey(targetKey),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('middle area shows pairs and an unlabeled draw tray', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.room(
            id: 'beginner',
            label: 'Başlangıç',
            entryFee: 500,
          ),
        ),
      ),
    );
    await tester.pump();

    final drawArea = find.byKey(const ValueKey('table-draw-column'));
    final perSummary = find.byKey(const ValueKey('grid-per-summary'));
    final indicator = find.byKey(const ValueKey('grid-indicator'));
    final deckSlot = find.byKey(const ValueKey('grid-deck-slot'));
    final indicatorDeckHitArea = find.byKey(
      const ValueKey('indicator-deck-draw-hit-area'),
    );
    final expandedDrawHitArea = find.byKey(
      const ValueKey('expanded-deck-draw-hit-area'),
    );
    expect(find.descendant(of: drawArea, matching: perSummary), findsOneWidget);
    expect(find.descendant(of: drawArea, matching: indicator), findsOneWidget);
    expect(find.descendant(of: drawArea, matching: deckSlot), findsOneWidget);
    expect(
      tester.getSize(perSummary).width,
      greaterThan(tester.getSize(indicator).width),
    );
    expect(tester.getSize(indicator).width, tester.getSize(deckSlot).width);
    final drawnTileRect = tester.getRect(
      find.byKey(const ValueKey('draw-deck-tile')),
    );
    final indicatorRect = tester.getRect(indicator);
    expect(drawnTileRect.width, closeTo(indicatorRect.width, 0.01));
    expect(drawnTileRect.height, closeTo(indicatorRect.height, 0.01));
    final dynamic drawColumn = tester.widget(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_GridDrawColumn',
      ),
    );
    expect(
      indicatorRect.width / indicatorRect.height,
      closeTo(drawColumn.dragTileWidth / drawColumn.dragTileHeight, .001),
    );
    expect(
      indicatorRect.width,
      lessThanOrEqualTo(drawColumn.dragTileWidth + .01),
    );
    expect(
      indicatorRect.height,
      lessThanOrEqualTo(drawColumn.dragTileHeight + .01),
    );
    expect(drawnTileRect.bottom, closeTo(indicatorRect.bottom, 0.01));
    final deckRect = tester.getRect(deckSlot);
    expect(deckRect.inflate(0.01).contains(drawnTileRect.topLeft), isTrue);
    expect(deckRect.inflate(0.01).contains(drawnTileRect.bottomRight), isTrue);
    final hitAreaRect = tester.getRect(indicatorDeckHitArea);
    expect(hitAreaRect.left, lessThanOrEqualTo(tester.getRect(indicator).left));
    expect(
      hitAreaRect.right,
      greaterThanOrEqualTo(tester.getRect(deckSlot).right),
    );
    final expandedHitAreaRect = tester.getRect(expandedDrawHitArea);
    expect(expandedHitAreaRect.left, lessThanOrEqualTo(hitAreaRect.left));
    expect(expandedHitAreaRect.left, lessThan(tester.getRect(indicator).left));
    expect(expandedHitAreaRect.right, greaterThanOrEqualTo(hitAreaRect.right));
    expect(
      tester.getSize(perSummary).height,
      greaterThan(tester.getSize(indicator).height),
    );
    final drawAreaRect = tester.getRect(drawArea);
    final perSummaryRect = tester.getRect(perSummary);
    expect(perSummaryRect.left - drawAreaRect.left, lessThan(8));
    expect(
      find.descendant(of: drawArea, matching: find.text('ELIMINASYON 101')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawArea, matching: find.text('ODA · BAŞLANGIÇ')),
      findsNothing,
    );
    expect(
      find.descendant(of: drawArea, matching: find.text('BET · 500')),
      findsNothing,
    );
    expect(find.text('GÖSTERGE'), findsNothing);
    expect(find.text('TAŞ ÇEK'), findsNothing);
    expect(find.byKey(const ValueKey('grid-indicator')), findsOneWidget);
    expect(find.byKey(const ValueKey('draw-deck-tile')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('zamanlı mod 7 saniye sonunda otomatik hamle yapar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.gameMode(
            mode: OkeyGameMode.timed101,
            id: 'timed-101',
            label: 'Zamanlı 101',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.byKey(const ValueKey('timed-turn-countdown')), findsOneWidget);
    expect(find.text('7 SN'), findsNothing);

    await tester.pump(const Duration(seconds: 7));

    expect(find.byKey(const ValueKey('timed-turn-countdown')), findsNothing);
    expect(find.textContaining('Süre doldu'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('katlamali mod guncel acilis hedeflerini gosterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.gameMode(
            mode: OkeyGameMode.progressive,
            id: 'progressive',
            label: 'Katlamali',
          ),
        ),
      ),
    );
    await tester.pump();

    final target = find.byKey(const ValueKey('progressive-opening-target'));
    expect(target, findsOneWidget);
    final draw = find.byKey(const ValueKey('table-draw-column'));
    expect(find.descendant(of: draw, matching: target), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-area-surface')),
        matching: target,
      ),
      findsNothing,
    );
    final targetRect = tester.getRect(target);
    final drawRect = tester.getRect(draw);
    expect(drawRect.contains(targetRect.center), isTrue);
    expect(
      targetRect.overlaps(
        tester.getRect(
          find.byKey(const ValueKey('expanded-deck-draw-hit-area')),
        ),
      ),
      isFalse,
    );
    expect(
      targetRect.overlaps(
        tester.getRect(find.byKey(const ValueKey('grid-per-summary'))),
      ),
      isFalse,
    );
    for (final value in ['101', '5']) {
      expect(
        find.descendant(of: target, matching: find.text(value)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renk bonusu gridde buyuk gorunup mod basligina yerlesir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.gameMode(
            mode: OkeyGameMode.colorBonus101,
            id: 'color-bonus-101',
            label: 'Renkli 101',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('color-bonus-round-intro')),
      findsOneWidget,
    );
    final rackFinder = find.byKey(const ValueKey('game-rack-area'));
    final rackState = tester.state(rackFinder);
    final dynamic dealtTile = tester.widget(
      find
          .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_DealtRackTile',
          )
          .first,
    );
    final dealProgress = dealtTile.progress as ValueListenable<double>;
    await tester.pump(const Duration(milliseconds: 700));
    final progressBeforeIntroEnds = dealProgress.value;
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('color-bonus-round-intro')), findsNothing);
    expect(tester.state(rackFinder), same(rackState));
    expect(dealProgress.value, greaterThanOrEqualTo(progressBeforeIntroEnds));
    expect(find.textContaining('RENKLİ •'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'processing before the last discard uses its own animation and keeps rewards unchanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      final dynamic area = tester.widget(
        find.byKey(const ValueKey('game-rack-area')),
      );
      final rack = area.rack as List<Tile>;
      final slots = area.slots as List<int?>;
      rack.clear();
      var id = 9700;
      for (final number in [2, 4, 8, 10, 12]) {
        for (var copy = 0; copy < 2; copy++) {
          rack.add(Tile(id: id++, number: number, color: TileColor.blue));
        }
      }
      final processTile = Tile(id: id++, number: 7, color: TileColor.red);
      rack.addAll([
        processTile,
        Tile(id: id++, number: 13, color: TileColor.yellow),
      ]);
      slots.fillRange(0, slots.length, null);
      for (var slot = 0; slot < rack.length; slot++) {
        slots[slot] = rack[slot].id;
      }
      final dynamic state = tester.state(find.byType(GameScreen));
      state.setState(() {});
      await tester.pump();
      await tester.tap(find.text('ÇİFT AÇ'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(rack, hasLength(2));
      final dynamic table = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_TableArea',
        ),
      );
      (table.melds as List<Meld>).add(
        Meld(
          type: 'seri',
          tiles: [
            for (final number in [4, 5, 6])
              Tile(id: id++, number: number, color: TileColor.red),
          ],
        ),
      );
      processTile.selected = true;
      state.setState(() {});
      await tester.pump();
      await tester.tap(find.text('İŞLE'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(rack, hasLength(1));
      rack.single.selected = true;
      state.setState(() {});
      await tester.pump();
      await tester.tap(find.text('TAŞ AT'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('processed-finish-celebration')),
        findsOneWidget,
      );
      expect(find.text('İŞLEYEREK BİTTİN!'), findsNothing);
      expect(find.byKey(const ValueKey('elden-finish-confetti')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      final result = tester.widget<GameEndDialog>(find.byType(GameEndDialog));
      expect(result.playerPen, -101);
      expect(result.reward!.coins, 150);
      expect(result.reward!.xp, 30);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );
  testWidgets(
    'right group grid leaves one cell between variable length melds',
    (tester) async {
      for (final size in const [
        Size(1280, 720),
        Size(1024, 768),
        Size(568, 320),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(startingPlayer: 0)),
        );
        final dynamic table = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TableArea',
          ),
        );
        final melds = table.melds as List<Meld>;
        for (final length in [3, 3, 4, 4]) {
          final index = melds.length;
          melds.add(
            Meld(
              type: 'grup',
              tiles: [
                for (var color = 0; color < length; color++)
                  Tile(
                    id: 1000 + index * 4 + color,
                    number: index + 1,
                    color: TileColor.values[color],
                  ),
              ],
            ),
          );
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        state.setState(() {});
        await tester.pump();

        void expectPositions(List<(int, int)> expected) {
          final dynamic grid = tester.widget(
            find.byKey(const ValueKey('group-meld-grid')),
          );
          for (var index = 0; index < expected.length; index++) {
            final position = tester.widget<Positioned>(
              find
                  .ancestor(
                    of: find.byKey(ValueKey('run-meld-$index')),
                    matching: find.byType(Positioned),
                  )
                  .first,
            );
            expect(
              position.left,
              closeTo(expected[index].$2 * grid.cellWidth, .01),
            );
            expect(
              position.top,
              closeTo(expected[index].$1 * grid.cellHeight, .01),
            );
          }
        }

        expectPositions([(0, 0), (0, 4), (0, 8), (1, 0)]);
        melds[0].tiles.add(Tile(id: 1100, number: 1, color: TileColor.yellow));
        state.setState(() {});
        await tester.pump();
        expectPositions([(0, 0), (0, 5), (0, 9), (1, 0)]);
        melds[1].tiles.add(Tile(id: 1101, number: 2, color: TileColor.yellow));
        state.setState(() {});
        await tester.pump();
        expectPositions([(0, 0), (0, 5), (1, 0), (1, 5)]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'processable tiles can move to either rack row at the finger position',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      final draggables = find.descendant(
        of: find.byKey(const ValueKey('rack-area-surface')),
        matching: find.byWidgetPredicate((w) => w is Draggable),
      );
      final source = tester.widgetList<Draggable>(draggables).firstWhere((w) {
        final dynamic data = w.data;
        return !(data.tile as Tile).isOkey;
      });
      final dynamic data = source.data;
      final tile = data.tile as Tile;
      final dynamic table = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TableArea'),
      );
      (table.melds as List<Meld>).add(
        Meld(
          type: 'grup',
          tiles: [
            for (final color in TileColor.values)
              if (color != tile.color)
                Tile(
                  id: -2000 - color.index,
                  number: tile.number,
                  color: color,
                ),
          ],
        ),
      );
      final dynamic state = tester.state(find.byType(GameScreen));
      state.setState(() {});
      await tester.pump();
      expect(
        find.byKey(ValueKey('processable-highlight-${tile.id}')),
        findsOneWidget,
      );
      final sourceKey = ValueKey('rack-tile-${tile.id}');
      final dynamic rackArea = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RackArea'),
      );
      final slots = rackArea.slots as List<int?>;
      final emptyLowerSlot = List.generate(
        15,
        (i) => i + 15,
      ).firstWhere((i) => slots[i] == null);
      for (final targetIndex in [emptyLowerSlot, data.sourceSlot as int]) {
        final target = find.byKey(ValueKey('rack-slot-$targetIndex'));
        final start = tester.getCenter(find.byKey(sourceKey));
        await tester.dragFrom(start, tester.getCenter(target) - start);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.descendant(of: target, matching: find.byKey(sourceKey)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'cross-row moves insert, swap full rows and snap near row edges',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in const [
        Size(1280, 720),
        Size(1024, 768),
        Size(568, 320),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(startingPlayer: 0)),
        );
        await tester.pump(const Duration(milliseconds: 2700));
        final dynamic area = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final slots = area.slots as List<int?>;
        final ids = slots.whereType<int>().toList();
        final dynamic state = tester.state(find.byType(GameScreen));
        void layout(bool fullLower) {
          slots.fillRange(0, slots.length, null);
          for (var i = 0; i < ids.length; i++) {
            slots[fullLower ? (i < 7 ? i : i + 8) : i] = ids[i];
          }
          state.setState(() {});
        }

        void expectIntact() {
          expect(slots.whereType<int>().length, ids.length);
          expect(slots.whereType<int>().toSet(), ids.toSet());
        }

        layout(false);
        await tester.pump();
        final target = find.byKey(const ValueKey('rack-slot-18'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('rack-slot-0'))),
        );
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('rack-drop-preview-18')),
          findsNothing,
        );
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(slots[18], ids[0]);
        expect(slots[19], ids[18]);
        expect(slots[0], isNull);
        expectIntact();
        await tester.dragFrom(
          tester.getCenter(target),
          tester.getCenter(find.byKey(const ValueKey('rack-slot-7'))) -
              tester.getCenter(target),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(slots[6], ids[0]);
        expect(slots[7], ids[7]);
        expectIntact();

        layout(true);
        await tester.pump();
        final swapped = slots[18];
        final swapGesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('rack-slot-0'))),
        );
        await swapGesture.moveBy(const Offset(0, -20));
        await tester.pump();
        await swapGesture.moveTo(tester.getCenter(target));
        await tester.pump();
        expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
        await swapGesture.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(slots[18], ids[0]);
        expect(slots[0], swapped);
        expectIntact();

        layout(false);
        await tester.pump();
        final edge = tester.getRect(find.byKey(const ValueKey('rack-slot-23')));
        final point = Offset(edge.center.dx, edge.bottom + edge.height * .15);
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('rack-slot-0'))),
          point - tester.getCenter(find.byKey(const ValueKey('rack-slot-0'))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(slots[23], ids[0]);
        expectIntact();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('player uses indicator only in the initial pair opening', (
    tester,
  ) async {
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
    var nextId = 4000;
    Tile tile(int number, TileColor color, {bool indicator = false}) => Tile(
      id: nextId++,
      number: number,
      color: color,
      isIndicator: indicator,
    );
    rack.clear();
    rack.addAll([
      for (final value in [
        (2, TileColor.red),
        (4, TileColor.blue),
        (8, TileColor.black),
        (10, TileColor.yellow),
      ])
        for (var copy = 0; copy < 2; copy++) tile(value.$1, value.$2),
      tile(6, TileColor.red, indicator: true),
      tile(13, TileColor.yellow),
      tile(6, TileColor.red, indicator: true),
      tile(13, TileColor.yellow),
      tile(12, TileColor.black),
    ]);
    slots.fillRange(0, slots.length, null);
    for (var i = 0; i < 10; i++) {
      slots[i] = rack[i].id;
    }
    slots[20] = rack[10].id;
    slots[22] = rack[11].id;
    slots[24] = rack[12].id;
    final dynamic state = tester.state(find.byType(GameScreen));
    state.setState(() {});
    await tester.pump();
    InkWell pairButton() => tester.widget<InkWell>(
      find
          .ancestor(of: find.text('ÇİFT AÇ'), matching: find.byType(InkWell))
          .first,
    );
    expect(pairButton().onTap, isNotNull);
    await tester.tap(find.text('ÇİFT AÇ'));
    await tester.pump(const Duration(milliseconds: 900));
    List<Meld> tableMelds() =>
        (tester.widget(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_TableArea',
              ),
            ) as dynamic).melds
            as List<Meld>;
    expect(tableMelds().where((m) => m.type == 'cift'), hasLength(5));
    expect(rack, hasLength(3));
    await tester.tap(find.text('ÇİFT DİZ'));
    await tester.pump();
    expect(pairButton().onTap, isNull);
    expect(tableMelds().where((m) => m.type == 'cift'), hasLength(5));
    final otherIndex = rack.indexWhere((t) => t.color == TileColor.yellow);
    final otherId = rack[otherIndex].id;
    rack[otherIndex] = Tile(
      id: otherId,
      number: 6,
      color: TileColor.red,
      isIndicator: true,
    );
    state.setState(() {});
    await tester.pump();
    await tester.tap(find.text('ÇİFT DİZ'));
    await tester.pump();
    expect(pairButton().onTap, isNotNull);
    await tester.tap(find.text('ÇİFT AÇ'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tableMelds().where((m) => m.type == 'cift'), hasLength(6));
    expect(rack, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final opening in [true, false]) {
    testWidgets(
      'bot last table move is highlighted after landing: opening=$opening',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(
            home: GameScreen(
              startingPlayer: 0,
              launchConfig: GameLaunchConfig.gameMode(
                mode: OkeyGameMode.standard,
                id: 'last-move',
                label: 'Last move',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 2700));
        final tableFinder = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_TableArea',
        );
        dynamic table() => tester.widget(tableFinder);
        final bot = (table().bots as List<BotPlayer>).first;
        final List<Tile> played;
        if (opening) {
          played = [
            for (final color in TileColor.values)
              for (var number = 9; number <= 11; number++)
                Tile(
                  number: number,
                  color: color,
                  id: -800 - color.index * 10 - number,
                ),
          ];
          bot.hand = [
            ...played,
            Tile(number: 2, color: TileColor.black, id: -950),
          ];
          bot.turnsPlayed = 2;
        } else {
          played = [Tile(number: 7, color: TileColor.red, id: -960)];
          bot.hand = [
            ...played,
            Tile(number: 12, color: TileColor.blue, id: -961),
            Tile(number: 2, color: TileColor.black, id: -962),
          ];
          bot.hasOpened = true;
          bot.openType = 'seri';
          (table().melds as List<Meld>).add(
            Meld(
              type: 'seri',
              tiles: [
                for (var number = 4; number <= 6; number++)
                  Tile(number: number, color: TileColor.red, id: -970 - number),
              ],
            ),
          );
        }
        bot.tileCount = bot.hand.length;
        final dynamic rack = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final discard = (rack.rack as List<Tile>).firstWhere(
          (t) => !t.isOkey && !t.isFakeOkey,
        );
        await tester.tap(find.byKey(ValueKey('rack-tile-${discard.id}')));
        await tester.pump();
        await tester.tap(find.text('TAŞ AT'));
        final highlights = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'processed-tile-highlight-',
              ),
        );
        for (
          var attempt = 0;
          attempt < 140 && highlights.evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(highlights, findsWidgets);
        final dynamic scope = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TileMotionScope',
          ),
        );
        final dynamic lastMove = scope.processedHighlight.value;
        expect(
          (lastMove.tileIds as Set<int>).intersection(
            played.map((t) => t.id).toSet(),
          ),
          isNotEmpty,
        );
        expect(lastMove.color, OC.goldLight);
        expect(lastMove.duration, const Duration(milliseconds: 1400));
        await tester.pump(const Duration(milliseconds: 450));
        expect(highlights, findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'bot waits after the previous discard then draws before playing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(
            startingPlayer: 0,
            launchConfig: GameLaunchConfig.gameMode(
              mode: OkeyGameMode.standard,
              id: 'pacing',
              label: 'Pacing',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      final tableFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TableArea',
      );
      dynamic table() => tester.widget(tableFinder);
      final BotPlayer firstBot = (table().bots as List<BotPlayer>).first;
      expect(firstBot.hand.length, 21);
      final profileScale = find.byKey(
        const ValueKey('profile-turn-scale-Oyuncu 2'),
      );
      double renderedScale() => tester
          .widget<ScaleTransition>(
            find.descendant(
              of: profileScale,
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      final avatar = find.byKey(const ValueKey('bot-avatar-Oyuncu 2'));
      final name = find.byKey(const ValueKey('bot-name-Oyuncu 2'));
      final avatarCenter = tester.getCenter(avatar);
      final nameCenter = tester.getCenter(name);
      expect(renderedScale(), closeTo(.86, .001));
      final dynamic rackArea = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_RackArea',
        ),
      );
      final tile = (rackArea.rack as List<Tile>).firstWhere(
        (tile) => !tile.isOkey && !tile.isFakeOkey,
      );
      await tester.tap(find.byKey(ValueKey('rack-tile-${tile.id}')));
      await tester.pump();
      await tester.tap(find.text('TAŞ AT'));
      await tester.pump(const Duration(milliseconds: 540));
      expect(table().activeTurn, 1);
      expect(firstBot.hand.length, 21);
      await tester.pump(const Duration(milliseconds: 200));
      expect(renderedScale(), greaterThan(.86));
      expect(renderedScale(), lessThan(1));
      expect(tester.getCenter(avatar), avatarCenter);
      expect(tester.getCenter(name), nameCenter);
      expect(
        firstBot.hand.length,
        21,
        reason: 'The previous discard must settle before the next draw.',
      );
      await tester.pump(const Duration(milliseconds: 121));
      for (
        var attempt = 0;
        attempt < 50 && firstBot.hand.length == 21;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 5));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(table().activeTurn, 1);
      expect(renderedScale(), closeTo(1, .001));
      expect(
        firstBot.hand.length,
        22,
        reason: 'The draw follows the short pause, before the thinking time.',
      );
      final flightFinder = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_BotTableTileFlight',
      );
      expect(flightFinder, findsOneWidget);
      final dynamic flight = tester.widget(flightFinder);
      final flightOrigin = tester.getTopLeft(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_FlyingTableTiles',
        ),
      );
      final seatCenter = tester.getCenter(
        find.byKey(const ValueKey('seat-Oyuncu 2')),
      );
      expect(
        ((flight.target as Rect).center + flightOrigin - seatCenter).distance,
        lessThan(.1),
        reason: 'The draw lands at the actual bot seat on this screen.',
      );
      expect(
        ((flight.source as Rect).center - (flight.target as Rect).center)
            .distance,
        greaterThan(20),
        reason: 'The draw travels from the real table source.',
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(table().activeTurn, 1);
      expect(firstBot.hand.length, 22);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_FlyingBotDiscard',
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1000));
      for (
        var attempt = 0;
        attempt < 50 && table().activeTurn == 1;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(
        table().activeTurn,
        2,
        reason: 'A simple discard should finish after a short thinking pause.',
      );
      final openedTileCount = (table().melds as List<Meld>).fold<int>(
        0,
        (sum, meld) => sum + meld.tiles.length,
      );
      expect(firstBot.hand.length + openedTileCount, 21);
      final secondBot = (table().bots as List<BotPlayer>)[1];
      expect(secondBot.hand.length, 21);
      await tester.pump(const Duration(milliseconds: 200));
      expect(renderedScale(), greaterThan(.86));
      expect(renderedScale(), lessThan(1));
      expect(tester.getCenter(avatar), avatarCenter);
      expect(tester.getCenter(name), nameCenter);
      expect(
        secondBot.hand.length,
        21,
        reason:
            'Consecutive bots must also leave a gap between discard and draw.',
      );
      await tester.pump(const Duration(milliseconds: 121));
      for (
        var attempt = 0;
        attempt < 50 && secondBot.hand.length == 21;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(secondBot.hand.length, 22);
      final botDraw = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_FlyingTableTiles',
      );
      expect(botDraw, findsOneWidget);
      final tween = tester.widget<TweenAnimationBuilder<double>>(
        find.descendant(
          of: botDraw,
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
      );
      expect(tween.duration.inMilliseconds, greaterThanOrEqualTo(300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
  for (final scenario in [
    (true, 'button'),
    (true, 'side'),
    (true, 'side-processable'),
    (true, 'center'),
    (false, 'button'),
    (false, 'side'),
    (false, 'side-processable'),
    (false, 'center'),
  ]) {
    final openingTurnFinish = scenario.$1;
    final finishMethod = scenario.$2;
    testWidgets(
      'every -101 finish shows confetti without a caption: $openingTurnFinish $finishMethod',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(startingPlayer: 0)),
        );
        await tester.pump(const Duration(milliseconds: 2700));
        dynamic rackArea() => tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final rack = rackArea().rack as List<Tile>;
        final slots = rackArea().slots as List<int?>;
        var id = 7000;
        rack.clear();
        rack.addAll([
          for (final number in [2, 4, 8, 10, 12])
            for (var copy = 0; copy < 2; copy++)
              Tile(id: id++, number: number, color: TileColor.blue),
          Tile(id: id++, number: 13, color: TileColor.red),
          if (!openingTurnFinish)
            Tile(id: id++, number: 1, color: TileColor.yellow),
        ]);
        slots.fillRange(0, slots.length, null);
        for (var i = 0; i < rack.length; i++) {
          slots[i] = rack[i].id;
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        state.setState(() {});
        await tester.pump();
        await tester.tap(find.text('ÇİFT AÇ'));
        await tester.pump(const Duration(milliseconds: 650));
        expect(rack.length, openingTurnFinish ? 1 : 2);
        if (!openingTurnFinish) {
          // Keep this animation fixture below 101 while the player waits a turn;
          // league rivals may now legally open on their very first turn.
          final dynamic fixtureTable = tester.widget(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_TableArea',
            ),
          );
          for (final bot in fixtureTable.bots as List<BotPlayer>) {
            bot.hand = [
              for (final color in TileColor.values)
                for (var number = 1; number <= 5; number++)
                  Tile(id: id++, number: number, color: color),
              Tile(id: id++, number: 1, color: TileColor.red),
            ];
            bot.tileCount = bot.hand.length;
          }
          rack.first.selected = true;
          state.setState(() {});
          await tester.pump();
          await tester.tap(find.text('TAŞ AT'));
          await tester.pump(const Duration(milliseconds: 600));
          for (var i = 0; i < 220; i++) {
            final dynamic table = tester.widget(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_TableArea',
              ),
            );
            if (table.activeTurn == 0) break;
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          await tester.pump();
          await tester.tap(find.text('TAŞ ÇEK'));
          await tester.pump(const Duration(milliseconds: 650));
          rack.removeRange(1, rack.length);
          slots.fillRange(0, slots.length, null);
          slots[0] = rack.single.id;
        }
        if (finishMethod == 'side-processable') {
          final dynamic table = tester.widget(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_TableArea',
            ),
          );
          final last = rack.single;
          rack[0] = Tile(id: id++, number: 13, color: TileColor.red);
          final slot = slots.indexOf(last.id);
          slots[slot] = rack.single.id;
          (table.melds as List<Meld>).add(
            Meld(
              type: 'seri',
              tiles: [
                for (final number in [10, 11, 12])
                  Tile(id: id++, number: number, color: TileColor.red),
              ],
            ),
          );
        }
        await tester.runAsync(() => dailyLeague.load());
        final leagueRoundsBefore = dailyLeague.completedRounds;
        final leaguePenaltyBefore = dailyLeague.standings
            .firstWhere((e) => e.isPlayer)
            .penalty;
        final completedBefore = playerProgress.gamesPlayed;
        rack.single.selected = true;
        state.setState(() {});
        await tester.pump();
        if (finishMethod == 'button') {
          await tester.tap(find.text('TAŞ AT'));
        } else {
          final target = finishMethod.startsWith('side')
              ? find.byKey(const ValueKey('discard-target-Oyuncu 1'))
              : find.byKey(const ValueKey('center-finish-drop-target'));
          await tester.dragFrom(
            tester.getCenter(
              find.byKey(ValueKey('rack-tile-${rack.single.id}')),
            ),
            tester.getCenter(target) -
                tester.getCenter(
                  find.byKey(ValueKey('rack-tile-${rack.single.id}')),
                ),
          );
        }
        await tester.pump();
        expect(playerProgress.gamesPlayed, completedBefore + 1);
        expect(
          find.byKey(const ValueKey('elden-finish-confetti')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('elden-tile-celebration')),
          findsOneWidget,
        );
        expect(
          find.text(openingTurnFinish ? 'ELDEN BİTTİN!' : 'ELİ BİTİRDİN!'),
          findsNothing,
        );
        expect(find.byType(GameEndDialog), findsNothing);
        for (final frame in [180, 260, 280]) {
          await tester.pump(Duration(milliseconds: frame));
          expect(tester.takeException(), isNull);
          expect(find.byType(GameEndDialog), findsNothing);
          expect(
            find.byKey(const ValueKey('elden-finish-confetti')),
            findsOneWidget,
          );
        }
        await tester.pump(const Duration(milliseconds: 450));
        expect(
          find.byKey(const ValueKey('elden-tile-celebration')),
          findsNothing,
        );
        expect(find.byType(GameEndDialog), findsOneWidget);
        expect(playerProgress.gamesPlayed, completedBefore + 1);
        for (
          var wait = 0;
          wait < 50 && dailyLeague.completedRounds == leagueRoundsBefore;
          wait++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        expect(dailyLeague.completedRounds, leagueRoundsBefore + 1);
        expect(
          dailyLeague.standings.firstWhere((e) => e.isPlayer).penalty,
          leaguePenaltyBefore - 101,
        );
        await tester.pump(const Duration(milliseconds: 900));
        expect(
          find.byKey(const ValueKey('round-end-tile-accent')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      },
    );
  }
  for (final dropCellOffset in <Offset?>[
    null,
    Offset.zero,
    const Offset(-3, 0),
    const Offset(3, 0),
    const Offset(0, -.7),
    const Offset(0, .7),
  ]) {
    final manualDrop = dropCellOffset != null;
    testWidgets(
      'returned okey stays in rack after left run replacement: offset=$dropCellOffset',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(startingPlayer: 0)),
        );
        await tester.pump(const Duration(milliseconds: 2700));
        final dynamic area = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final rack = area.rack as List<Tile>;
        final slots = area.slots as List<int?>;
        var id = 9000;
        final replacement = Tile(id: id++, number: 5, color: TileColor.blue);
        final spare = Tile(id: id++, number: 13, color: TileColor.black);
        rack.clear();
        rack.addAll([
          for (final number in [2, 4, 8, 10, 12])
            for (var copy = 0; copy < 2; copy++)
              Tile(id: id++, number: number, color: TileColor.blue),
          replacement,
          spare,
        ]);
        slots.fillRange(0, slots.length, null);
        for (var i = 0; i < rack.length; i++) {
          slots[i] = rack[i].id;
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        state.setState(() {});
        await tester.pump();
        await tester.tap(find.text('ÇİFT AÇ'));
        await tester.pump(const Duration(milliseconds: 650));
        expect(rack, hasLength(2));
        final dynamic table = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TableArea',
          ),
        );
        final melds = table.melds as List<Meld>;
        final okey = Tile(
          id: id++,
          number: 7,
          color: TileColor.yellow,
          isOkey: true,
        );
        final run = Meld(
          type: 'seri',
          tiles: [
            Tile(id: id++, number: 4, color: TileColor.blue),
            okey,
            Tile(id: id++, number: 6, color: TileColor.blue),
          ],
        );
        melds
          ..clear()
          ..add(run);
        slots.fillRange(0, slots.length, null);
        slots[20] = replacement.id;
        slots[22] = spare.id;
        state.setState(() {});
        await tester.pump();
        final originalSlot = slots.indexOf(replacement.id);
        if (manualDrop) {
          final drag = tester.widget<Draggable>(
            find.byKey(ValueKey('rack-tile-${replacement.id}')),
          );
          final dynamic currentTable = tester.widget(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_TableArea',
            ),
          );
          expect(currentTable.canAcceptMeldDrop(0, drag.data), isTrue);
          final source = tester.getCenter(
            find.byKey(ValueKey('rack-tile-${replacement.id}')),
          );
          final rect = tester.getRect(find.byKey(const ValueKey('run-meld-0')));
          final target =
              rect.center -
              drag.feedbackOffset +
              Offset(
                dropCellOffset.dx * rect.width / 3,
                dropCellOffset.dy * rect.height,
              );
          final gesture = await tester.startGesture(source);
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
          final gridFinder = find.byKey(const ValueKey('run-meld-grid'));
          final dynamic grid = tester.widget(gridFinder);
          final emptyCell =
              tester.getTopLeft(gridFinder) +
              Offset(grid.cellWidth * 11.5, grid.cellHeight * 5.5) -
              drag.feedbackOffset;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 12)),
          );
          await gesture.moveTo(emptyCell);
          await tester.pump(const Duration(milliseconds: 20));
          expect(
            find.byKey(const ValueKey('grid-drag-magnifier')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('grid-meld-coordinate-guide')),
            findsOneWidget,
          );
          void expectOkeyCoordinate() {
            final guide = find.byKey(
              const ValueKey('grid-meld-coordinate-guide'),
            );
            final dynamic painter = tester.widget<CustomPaint>(guide).painter;
            final expected = tester
                .renderObject<RenderBox>(guide)
                .globalToLocal(
                  tester.getCenter(
                    find.byKey(ValueKey('table-visible-tile-${okey.id}')),
                  ),
                );
            expect((painter.target as Offset).dx, closeTo(expected.dx, .1));
            expect((painter.target as Offset).dy, closeTo(expected.dy, .1));
          }

          expectOkeyCoordinate();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 12)),
          );
          await gesture.moveTo(target);
          await tester.pump(const Duration(milliseconds: 20));
          expect(
            find.byKey(const ValueKey('grid-drag-magnifier')),
            findsOneWidget,
          );
          final guide = find.byKey(
            const ValueKey('grid-meld-coordinate-guide'),
          );
          expect(guide, findsOneWidget);
          final dynamic painter = tester.widget<CustomPaint>(guide).painter;
          expect(painter.color, replacement.displayColor);
          expectOkeyCoordinate();
          expect(find.byKey(const ValueKey('meld-drop-preview')), findsNothing);
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          final flight = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(
                  'player-tile-flight-',
                ) &&
                (w.key as ValueKey<String>).value.endsWith('-${okey.id}'),
          );
          expect(flight, findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(
                    'processed-tile-highlight-${replacement.id}-',
                  ),
            ),
            findsOneWidget,
          );
          expect(rack.map((t) => t.id), contains(okey.id));
          await tester.pump(const Duration(milliseconds: 20));
          expect(guide, findsNothing);
        } else {
          await tester.tap(find.text('İŞLE'));
        }
        await tester.pump(const Duration(milliseconds: 650));
        expect(run.tiles.map((t) => t.id), contains(replacement.id));
        expect(run.tiles.map((t) => t.id), isNot(contains(okey.id)));
        expect(run.tiles, hasLength(3));
        expect(rack.map((t) => t.id), containsAll([okey.id, spare.id]));
        expect(rack, hasLength(2));
        expect(slots[originalSlot], okey.id);
        expect(find.byKey(ValueKey('rack-tile-${okey.id}')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final dropOffset in <Offset?>[
    Offset.zero,
    Offset(0, -14),
    Offset(12, 0),
    null,
  ]) {
    final nearRackDrop = dropOffset != null;
    testWidgets(
      'midpoint meld drop accepts a visible lower meld and rejects a distant rack: offset=$dropOffset',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(startingPlayer: 0)),
        );
        await tester.pump(const Duration(milliseconds: 2700));
        final dynamic area = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_RackArea',
          ),
        );
        final rack = area.rack as List<Tile>;
        final slots = area.slots as List<int?>;
        var id = 9000;
        final replacement = Tile(id: id++, number: 5, color: TileColor.red);
        final spare = Tile(id: id++, number: 13, color: TileColor.black);
        rack.clear();
        rack.addAll([
          for (final number in [2, 4, 8, 10, 12])
            for (var copy = 0; copy < 2; copy++)
              Tile(id: id++, number: number, color: TileColor.blue),
          replacement,
          spare,
        ]);
        slots.fillRange(0, slots.length, null);
        for (var i = 0; i < rack.length; i++) {
          slots[i] = rack[i].id;
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        state.setState(() {});
        await tester.pump();
        await tester.tap(find.text('ÇİFT AÇ'));
        await tester.pump(const Duration(milliseconds: 650));
        expect(rack, hasLength(2));
        final dynamic table = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TableArea',
          ),
        );
        final melds = table.melds as List<Meld>;
        final okey = Tile(
          id: id++,
          number: 7,
          color: TileColor.yellow,
          isOkey: true,
        );
        final run = Meld(
          type: 'seri',
          tiles: [
            Tile(id: id++, number: 4, color: TileColor.red),
            okey,
            Tile(id: id++, number: 6, color: TileColor.red),
          ],
        );
        melds
          ..clear()
          ..add(run);
        slots.fillRange(0, slots.length, null);
        slots[20] = replacement.id;
        slots[22] = spare.id;
        state.setState(() {});
        await tester.pump();
        final originalSlot = slots.indexOf(replacement.id);
        {
          final drag = tester.widget<Draggable>(
            find.byKey(ValueKey('rack-tile-${replacement.id}')),
          );
          final dynamic currentTable = tester.widget(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_TableArea',
            ),
          );
          expect(currentTable.canAcceptMeldDrop(0, drag.data), isTrue);
          final source = tester.getCenter(
            find.byKey(ValueKey('rack-tile-${replacement.id}')),
          );
          expect((drag.data as dynamic).liftedForMeld, isTrue);
          expect(drag.feedbackOffset, const Offset(0, -16));
          final dynamic grid = tester.widget(
            find.byKey(const ValueKey('run-meld-grid')),
          );
          final targetIndex = (grid.rows as int) - 1;
          melds.clear();
          for (var row = 0; row < targetIndex; row++) {
            melds.add(
              Meld(
                type: 'seri',
                tiles: [
                  for (final number in [4, 5, 6])
                    Tile(id: id++, number: number, color: TileColor.red),
                ],
              ),
            );
          }
          melds.add(run);
          state.setState(() {});
          await tester.pump();
          final meldFinder = find.byKey(ValueKey('run-meld-$targetIndex'));
          final upperRack = tester.getRect(
            find.byKey(const ValueKey('rack-slot-0')),
          );
          final viewerFinder = find
              .ancestor(
                of: meldFinder,
                matching: find.byType(InteractiveViewer),
              )
              .first;
          final viewer = tester.widget<InteractiveViewer>(viewerFinder);
          final viewerTop = tester.getTopLeft(viewerFinder).dy;
          final scale =
              (upperRack.top - 14 - 52 - viewerTop) /
              (tester.getCenter(meldFinder).dy - viewerTop);
          viewer.transformationController!.value = Matrix4.diagonal3Values(
            scale,
            scale,
            1,
          );
          await tester.pump();
          final nearTarget = tester.getCenter(meldFinder) - drag.feedbackOffset;
          final target = nearRackDrop
              ? nearTarget + dropOffset!
              : Offset(nearTarget.dx, upperRack.bottom - 5);
          expect(nearTarget.dy, lessThan(upperRack.top - 22));
          final gesture = await tester.startGesture(source);
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 12)),
          );
          await gesture.moveTo(target);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          if (nearRackDrop) {
            expect(
              find.byKey(const ValueKey('grid-meld-coordinate-guide')),
              findsOneWidget,
            );
          } else {
            // A stale/overlapping target must still reject a distant rack drop.
            currentTable.onMeldDrop(targetIndex, drag.data);
            expect(run.tiles.map((t) => t.id), contains(okey.id));
            expect(rack.map((t) => t.id), contains(replacement.id));
          }
          await gesture.up();
        }
        await tester.pump(const Duration(milliseconds: 650));
        if (nearRackDrop) {
          expect(run.tiles.map((t) => t.id), contains(replacement.id));
          expect(run.tiles.map((t) => t.id), isNot(contains(okey.id)));
          expect(run.tiles, hasLength(3));
          expect(rack.map((t) => t.id), containsAll([okey.id, spare.id]));
          expect(rack, hasLength(2));
          expect(slots[originalSlot], okey.id);
          expect(find.byKey(ValueKey('rack-tile-${okey.id}')), findsOneWidget);
        } else {
          expect(run.tiles.map((t) => t.id), contains(okey.id));
          expect(rack.map((t) => t.id), contains(replacement.id));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'manual meld target stays stable and drop matches its coordinate',
    (tester) async {
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
      var id = 9000;
      final replacement = Tile(id: id++, number: 5, color: TileColor.blue);
      final spare = Tile(id: id++, number: 13, color: TileColor.black);
      rack.clear();
      rack.addAll([
        for (final number in [2, 4, 8, 10, 12])
          for (var copy = 0; copy < 2; copy++)
            Tile(id: id++, number: number, color: TileColor.blue),
        replacement,
        spare,
      ]);
      slots.fillRange(0, slots.length, null);
      for (var i = 0; i < rack.length; i++) {
        slots[i] = rack[i].id;
      }
      final dynamic state = tester.state(find.byType(GameScreen));
      state.setState(() {});
      await tester.pump();
      await tester.tap(find.text('ÇİFT AÇ'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(rack, hasLength(2));
      final dynamic table = tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TableArea'),
      );
      final melds = table.melds as List<Meld>;
      final run = Meld(
        type: 'grup',
        tiles: [
          for (final color in [
            TileColor.red,
            TileColor.yellow,
            TileColor.black,
          ])
            Tile(id: id++, number: 5, color: color),
        ],
      );
      final other = Meld(
        type: 'grup',
        tiles: [
          for (final color in [
            TileColor.red,
            TileColor.yellow,
            TileColor.black,
          ])
            Tile(id: id++, number: 5, color: color),
        ],
      );
      melds
        ..clear()
        ..addAll([run, other]);
      slots.fillRange(0, slots.length, null);
      slots[20] = replacement.id;
      slots[22] = spare.id;
      state.setState(() {});
      await tester.pump();
      final drag = tester.widget<Draggable>(
        find.byKey(ValueKey('rack-tile-${replacement.id}')),
      );
      final firstRect = tester.getRect(
        find.byKey(const ValueKey('run-meld-0')),
      );
      final secondRect = tester.getRect(
        find.byKey(const ValueKey('run-meld-1')),
      );
      final cellWidth = firstRect.width / 3;
      dynamic visual() => (tester.widget(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_TileMotionScope',
        ),
      ) as dynamic).dragVisual.value;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey('rack-tile-${replacement.id}'))),
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      Future<void> move(Offset center) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 12)),
        );
        await gesture.moveTo(center - drag.feedbackOffset);
        await tester.pump(const Duration(milliseconds: 110));
      }

      await move(firstRect.center);
      expect(visual().target.index, 0);
      expect((visual().snapOffset as Offset).distance, lessThan(cellWidth));
      await move(Offset(firstRect.left + cellWidth * .70, firstRect.center.dy));
      expect(visual().target.index, 0);
      expect((visual().snapOffset as Offset).dx, lessThan(0));
      expect((visual().snapOffset as Offset).distance, lessThan(10));
      final jitter = Offset(
        firstRect.right + cellWidth * .65,
        firstRect.center.dy,
      );
      await move(jitter);
      expect(visual().target.index, 0);
      await move(secondRect.center);
      expect(visual().target.index, 1);
      await move(firstRect.center);
      expect(visual().target.index, 0);
      await move(jitter);
      final guide = find.byKey(const ValueKey('grid-meld-coordinate-guide'));
      final dynamic painter = tester.widget<CustomPaint>(guide).painter;
      final actualTarget = tester
          .renderObject<RenderBox>(guide)
          .localToGlobal(painter.target as Offset);
      expect(actualTarget.dx, closeTo(firstRect.left + cellWidth / 2, .1));
      expect(actualTarget.dy, closeTo(firstRect.center.dy, .1));
      await gesture.up();
      await tester.pump();
      expect(run.tiles.map((tile) => tile.id), contains(replacement.id));
      expect(other.tiles, hasLength(3));
      expect(rack, hasLength(1));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'processed-tile-highlight-${replacement.id}-',
              ),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 360));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'processed-tile-highlight-${replacement.id}-',
              ),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'processed-tile-highlight-',
              ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

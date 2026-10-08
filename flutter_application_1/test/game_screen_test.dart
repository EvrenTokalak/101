import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';

void main() {
  setUp(() {
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
      await tester.pump(const Duration(seconds: 3));
      expect(frame, findsOneWidget);
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

  testWidgets('botlar yalnizca actiktan sonra kalan puani gosterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump();
    expect(find.text('Açmadı'), findsNothing);
    expect(
      find.byKey(const ValueKey('bot-status-badge-Oyuncu 2')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('bot-remaining-points-Oyuncu 2')),
      findsNothing,
    );
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
    final expected = Rules.penaltyFor(bot.hand, fakeOkeyValue: fakeOkeyValue);
    bot.hasOpened = true;
    tester.element(info).markNeedsBuild();
    await tester.pump();
    expect(find.text('Açtı'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('bot-remaining-points-Oyuncu 2')),
          )
          .data,
      '$expected',
    );
    expect(find.text('Açmadı'), findsNothing);
    expect(
      find.byKey(const ValueKey('bot-remaining-points-Oyuncu 3')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('bot-remaining-points-Oyuncu 4')),
      findsNothing,
    );
    bot.hand.clear();
    tester.element(info).markNeedsBuild();
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('bot-remaining-points-Oyuncu 2')),
          )
          .data,
      '0',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('game screen renders at desktop and short web sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(1280, 720),
      Size(1024, 420),
      Size(800, 450),
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
      expect(find.text('SIRADAN'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pair-area-drop-target')),
        findsOneWidget,
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

  testWidgets('cift diz sonrasi ozet kutusu toplam etiketini gosterir', (
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

    expect(find.text('TOPLAM'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 70));
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
    final gripCenterY =
        liftedFeedback.top +
        liftedFeedback.height * .85 -
        3 -
        liftedFeedback.width * .105;
    expect(gripCenterY, closeTo(pointer.dy, .1));
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

    await tester.dragFrom(
      tester.getCenter(sourceSlot),
      Offset(targetRect.left + targetRect.width * 0.04, targetRect.center.dy) -
          tester.getCenter(sourceSlot),
    );
    await tester.pump();

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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('rack-area-surface')),
        matching: target,
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(target).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('rack-slot-0'))).left,
      ),
    );
    expect(
      find.descendant(of: target, matching: find.text('101')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: target, matching: find.text('5')),
      findsOneWidget,
    );
    for (final entry in {'101': 0, '5': 23}.entries) {
      final slot = tester.getRect(
        find.byKey(ValueKey('rack-slot-${entry.value}')),
      );
      final number = find.descendant(
        of: target,
        matching: find.text(entry.key),
      );
      expect(
        tester.getCenter(number).dy,
        closeTo(slot.center.dy - slot.height * 0.15, 1),
      );
      expect(tester.widget<Text>(number).style!.fontWeight, FontWeight.w900);
    }
    expect(
      find.descendant(of: target, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      tester
          .getCenter(find.descendant(of: target, matching: find.text('101')))
          .dy,
      lessThan(
        tester
            .getCenter(find.descendant(of: target, matching: find.text('5')))
            .dy,
      ),
    );
    expect(
      find.descendant(of: target, matching: find.text('PER: 101')),
      findsNothing,
    );
    expect(
      find.descendant(of: target, matching: find.text('ÇİFT: 5')),
      findsNothing,
    );
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
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byKey(const ValueKey('color-bonus-round-intro')), findsNothing);
    expect(find.textContaining('RENKLİ •'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

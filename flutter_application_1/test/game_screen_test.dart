import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';

void main() {
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
        expect(player1Discard.dx, greaterThan(player2Discard.dx));
        expect(player1Discard.dx - player2Discard.dx, lessThanOrEqualTo(10));

        final runGridRect = tester.getRect(
          find.byKey(const ValueKey('run-meld-grid')),
        );
        final groupGridRect = tester.getRect(
          find.byKey(const ValueKey('group-meld-grid')),
        );
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
        expect(gridViewers, hasLength(2));
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
    expect(find.descendant(of: drawArea, matching: perSummary), findsOneWidget);
    expect(find.descendant(of: drawArea, matching: indicator), findsOneWidget);
    expect(find.descendant(of: drawArea, matching: deckSlot), findsOneWidget);
    expect(
      tester.getSize(perSummary).width,
      greaterThan(tester.getSize(indicator).width),
    );
    expect(tester.getSize(indicator).width, tester.getSize(deckSlot).width);
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
}

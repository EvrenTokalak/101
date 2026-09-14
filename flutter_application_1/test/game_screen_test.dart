import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

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
      expect(find.byKey(const ValueKey('standard-meld-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('pair-meld-grid')), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is Draggable),
        findsWidgets,
      );

      if (size == const Size(1280, 720)) {
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
        final gridViewer = tester.widget<InteractiveViewer>(
          find.byKey(const ValueKey('meld-grid-viewer')),
        );
        expect(gridViewer.panEnabled, isTrue);
        expect(gridViewer.scaleEnabled, isTrue);
        expect(gridViewer.minScale, 1);
        expect(gridViewer.maxScale, 2.6);
        expect(find.byTooltip('Gridi yakınlaştır'), findsNothing);
        expect(find.byTooltip('Gridi uzaklaştır'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      }
    }
  });

  testWidgets('cift diz sonrasi ozet kutusu cift sayisini gosterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump();

    await tester.tap(find.text('ÇİFT DİZ'));
    await tester.pump();

    expect(find.textContaining('ÇİFT SAYISI:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}

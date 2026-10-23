import 'panel_artwork_test_support.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart' show GameScreen;
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/startup_tutorial.dart';
import 'package:flutter_application_1/app_controls.dart';

void main() {
  preparePanelArtwork();
  Future<void> expectFingerVisits(
    WidgetTester tester,
    Finder start,
    Finder end,
  ) async {
    var nearestStart = double.infinity;
    var nearestEnd = double.infinity;
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      final finger = tester.getCenter(
        find.byKey(const ValueKey('tutorial-finger')),
      );
      nearestStart = min(
        nearestStart,
        (finger - tester.getCenter(start)).distance,
      );
      nearestEnd = min(nearestEnd, (finger - tester.getCenter(end)).distance);
    }
    expect(nearestStart, lessThan(4));
    expect(nearestEnd, lessThan(4));
  }

  testWidgets('ana menü sorusu görsel oyun öğreticisini açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const app.OkeyApp(home: app.MainMenuScreen(showTutorialPrompt: true)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('tutorial-question')), findsOneWidget);
    expect(find.text('HEMEN OYNA'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutorial-start-button')));
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(GameScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('in-game-tutorial-overlay')),
      findsOneWidget,
    );
    expect(find.text('1. TAŞI SÜRÜKLEYEREK ÇEK'), findsOneWidget);

    final deckCenter = tester.getCenter(
      find.byKey(const ValueKey('grid-deck-slot')),
    );
    final drawTarget = tester.getCenter(
      find.byKey(const ValueKey('rack-slot-23')),
    );
    await expectFingerVisits(
      tester,
      find.byKey(const ValueKey('grid-deck-slot')),
      find.byKey(const ValueKey('rack-slot-23')),
    );
    final expandedDeck = tester.getRect(
      find.byKey(const ValueKey('expanded-deck-draw-hit-area')),
    );
    final expandedDeckStart = Offset(expandedDeck.left + 5, deckCenter.dy);
    await tester.dragFrom(expandedDeckStart, drawTarget - expandedDeckStart);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('2. SERİYİ ELLE DİZ'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('tutorial-open-button')))
          .onTap,
      isNull,
    );

    final rack = find.byKey(const ValueKey('rack-area-surface'));
    final wrongTile = find.ancestor(
      of: find.descendant(of: rack, matching: find.text('7')),
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final wrongTileCenter = tester.getCenter(wrongTile);
    final lockedTarget = tester.getCenter(
      find.byKey(const ValueKey('rack-slot-14')),
    );
    await tester.dragFrom(wrongTileCenter, lockedTarget - wrongTileCenter);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2. SERİYİ ELLE DİZ'), findsOneWidget);

    final yellowThree = find.ancestor(
      of: find.descendant(of: rack, matching: find.text('3')),
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final yellowThreeCenter = tester.getCenter(yellowThree);
    final arrangeTarget = tester.getCenter(
      find.byKey(const ValueKey('rack-slot-14')),
    );
    await expectFingerVisits(
      tester,
      find.byKey(const ValueKey('rack-slot-20')),
      find.byKey(const ValueKey('rack-slot-14')),
    );
    final arrangeDrag = await tester.startGesture(yellowThreeCenter);
    await arrangeDrag.moveBy(const Offset(25, -25));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final feedback = find.byKey(const ValueKey('rack-drag-feedback-tile'));
    final movingFrame = find.descendant(
      of: feedback,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.key.toString().contains('processable-highlight-'),
      ),
    );
    expect(movingFrame, findsOneWidget);
    expect(
      find.byKey(const ValueKey('tutorial-arrange-highlight')),
      findsNothing,
    );
    final frameBeforeMove = tester.getCenter(movingFrame);
    await arrangeDrag.moveBy(const Offset(20, -15));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final frameMovement = tester.getCenter(movingFrame) - frameBeforeMove;
    expect(frameMovement.dx, closeTo(20, 2));
    expect(frameMovement.dy, closeTo(-15, 2));
    expect(tester.getRect(movingFrame), tester.getRect(feedback));
    await arrangeDrag.moveTo(arrangeTarget);
    await arrangeDrag.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('3. ELİNİ AÇ'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('tutorial-open-button')))
          .onTap,
      isNotNull,
    );
    expect(find.text('SERİ ≥ 101'), findsOneWidget);
    expect(
      find.text('SERİ puanın en az 101 olduğunda SERİ AÇ düğmesine bas.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('tutorial-total-highlight')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tutorial-hand-image')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tutorial-open-highlight')),
      findsOneWidget,
    );
    expect(find.text('101+ HAZIR'), findsOneWidget);
    final hand = tester.widget<Image>(
      find.byKey(const ValueKey('tutorial-hand-image')),
    );
    expect(
      ((hand.image as ResizeImage).imageProvider as AssetImage).assetName,
      'görseller/icon/t_hand',
    );
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        (tester.getCenter(find.byKey(const ValueKey('tutorial-finger'))) -
                tester.getCenter(
                  find.byKey(const ValueKey('tutorial-open-button')),
                ))
            .distance,
        lessThan(1),
      );
      expect(
        find.byKey(const ValueKey('tutorial-total-highlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tutorial-open-highlight')),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('SERİ AÇ'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('4. İŞLEK TAŞI İŞLE'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-opening-popup')), findsOneWidget);
    expect(find.textContaining('elini açtı'), findsOneWidget);
    final processableHighlights = find.descendant(
      of: rack,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.key.toString().contains('processable-highlight-'),
      ),
    );
    expect(processableHighlights, findsWidgets);
    for (final highlight in tester.widgetList<DecoratedBox>(
      processableHighlights,
    )) {
      final decoration = highlight.decoration as BoxDecoration;
      expect((decoration.border! as Border).top.color, const Color(0xFF2E7D32));
    }

    final redSeven = find.ancestor(
      of: find.descendant(of: rack, matching: find.text('7')),
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final redSevenCenter = tester.getCenter(redSeven);
    final processTarget = tester.getCenter(
      find.byKey(const ValueKey('run-meld-0')),
    );
    await expectFingerVisits(
      tester,
      find.byKey(const ValueKey('rack-slot-22')),
      find.byKey(const ValueKey('run-meld-0')),
    );
    await tester.dragFrom(redSevenCenter, const Offset(-500, -400));
    await tester.pump();
    expect(
      find.text(
        'Kırmızı 7’yi parlayan kırmızı 4–5–6 perinin üzerine veya sonuna bırak.',
      ),
      findsOneWidget,
    );
    final processingGesture = await tester.startGesture(redSevenCenter);
    await processingGesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await processingGesture.moveTo(processTarget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('meld-drop-silhouette')), findsNothing);
    expect(find.byKey(const ValueKey('meld-drop-target-glow')), findsOneWidget);
    await processingGesture.up();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget.key.toString().contains('player-tile-flight-'),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('5. SON TAŞI AT VE BİT'), findsOneWidget);
    expect(
      find
          .byWidgetPredicate(
            (widget) => widget.key.toString().contains('rack-visible-tile-'),
          )
          .evaluate()
          .length,
      1,
    );

    final lastTile = find.ancestor(
      of: find.descendant(of: rack, matching: find.text('13')),
      matching: find.byWidgetPredicate((widget) => widget is Draggable),
    );
    final lastTileCenter = tester.getCenter(lastTile);
    final discardTarget = tester.getCenter(
      find.byKey(const ValueKey('center-finish-drop-target')),
    );
    final lastTileSlot = find
        .ancestor(
          of: lastTile,
          matching: find.byWidgetPredicate(
            (widget) => widget.key.toString().contains('rack-slot-'),
          ),
        )
        .first;
    await expectFingerVisits(
      tester,
      lastTileSlot,
      find.byKey(const ValueKey('center-finish-drop-target')),
    );
    await tester.dragFrom(lastTileCenter, discardTarget - lastTileCenter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('tutorial-completion-check')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('in-game-tutorial-overlay')),
      findsNothing,
    );
    expect(find.text('ÖĞRETİCİ TAMAMLANDI!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('HEMEN OYNA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feature-dialog-PROFİLİM')),
      findsOneWidget,
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('profile-name-field')),
    );
    expect(nameField.controller?.text, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Gökde',
    );
    await tester.tap(find.byKey(const ValueKey('profile-name-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.playerName, 'Gökde');
    await tester.tap(find.byKey(const ValueKey('profile-close-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.playerName, 'Gökde');
    expect(find.byKey(const ValueKey('feature-dialog-PROFİLİM')), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('home-feature-tour')), findsOneWidget);
    expect(find.text('GÜNLÜK ÖDÜL'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-feature-next')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('feature-dialog-GÜNLÜK GİRİŞ ÖDÜLÜ')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('GÖREVLER'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('home-feature-next')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('feature-dialog-GÖREVLER')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 300));
    final missionsClose = find.byKey(const ValueKey('popup-outside-close'));
    final missionsFrame = tester.getRect(
      find.byKey(const ValueKey('popup-panel-artwork')),
    );
    expect(missionsClose.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(missionsClose).center.dy,
      closeTo(missionsFrame.top + missionsFrame.height * .205, .1),
    );
    expect(
      tester.getRect(missionsClose).right,
      lessThanOrEqualTo(missionsFrame.right),
    );
    final homeButton = tester.element(
      find.byKey(const ValueKey('home-missions-button')),
    );
    expect(TickerMode.valuesOf(homeButton).enabled, isFalse);
    await tester.tap(missionsClose);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(TickerMode.valuesOf(homeButton).enabled, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('öğretici ayarlar panelinden yeniden açılabilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const app.OkeyApp(home: app.MainMenuScreen(showTutorialPrompt: false)),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey('main-settings-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('settings-tutorial-button')),
      findsOneWidget,
    );

    final tutorialButton = find.byKey(
      const ValueKey('settings-tutorial-button'),
    );
    final knob = find.descendant(
      of: tutorialButton,
      matching: find.byType(AnimatedAlign),
    );
    expect(tester.widget<AnimatedAlign>(knob).alignment, Alignment.centerLeft);
    await tester.tap(tutorialButton);
    await tester.pump();
    expect(tester.widget<AnimatedAlign>(knob).alignment, Alignment.centerRight);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('in-game-tutorial-overlay')),
      findsOneWidget,
    );
  });
  testWidgets(
    'tutorial prompt fits narrow and short screens without broken title words',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [
        const Size(320, 568),
        const Size(568, 320),
        const Size(320, 360),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TutorialPromptDialog())),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(find.text('ÖĞRETİCİYİ GÖRMEK\nİSTER MİSİN?'), findsOneWidget);
        expect(
          tester
              .widget<Image>(find.byKey(const ValueKey('popup-panel-artwork')))
              .image,
          appPopupArtwork(appTutorialPanelAsset),
        );
        expect(
          find.byKey(const ValueKey('popup-outside-close')).hitTestable(),
          findsOneWidget,
        );
        final artworkBounds = tester.getRect(
          find.byKey(const ValueKey('popup-panel-artwork')),
        );
        final titleBox = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('tutorial-panel-title')),
        );
        final titleBounds = Rect.fromPoints(
          titleBox.localToGlobal(Offset.zero),
          titleBox.localToGlobal(titleBox.size.bottomRight(Offset.zero)),
        );
        expect(
          titleBounds.width,
          lessThanOrEqualTo(artworkBounds.width * .39 + .1),
        );
        expect(
          titleBounds.top,
          greaterThanOrEqualTo(
            artworkBounds.top + artworkBounds.height * .11 - .1,
          ),
        );
        expect(
          titleBounds.bottom,
          lessThanOrEqualTo(
            artworkBounds.top + artworkBounds.height * .20 + .1,
          ),
        );
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.textContaining('Kontrollü bir eğitim'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('tutorial-start-button')),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('tutorial-start-button')).hitTestable(),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('missions tour follows actual button after resizing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const app.OkeyApp(home: app.MainMenuScreen(showTutorialPrompt: false)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final missions = find.byKey(const ValueKey('home-missions-button'));
    expect(missions, findsOneWidget);
    showDialog<void>(
      context: tester.element(missions),
      builder: (_) => const HomeFeatureTourDialog(daily: false),
    );
    for (final size in [
      const Size(1280, 720),
      const Size(390, 844),
      const Size(568, 320),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      final box = tester.renderObject<RenderBox>(missions);
      final target = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      final highlight = tester.getRect(
        find.byKey(const ValueKey('home-feature-target')),
      );
      expect(highlight.left, closeTo(target.left, 1));
      expect(highlight.top, closeTo(target.top, 1));
      expect(highlight.width, closeTo(target.width, 1));
      expect(highlight.height, closeTo(target.height, 1));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game_help_dialog.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/app_controls.dart';

void main() {
  preparePanelArtwork();
  testWidgets('help swipes keep the frame, title and close button fixed', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(900, 520),
      const Size(568, 320),
      const Size(390, 844),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHelpDialog(key: ValueKey(size))),
        ),
      );
      await tester.pumpAndSettle();
      final artwork = find.byKey(const ValueKey('popup-panel-artwork'));
      final title = find.byKey(const ValueKey('panel-title-region'));
      final close = find.byKey(const ValueKey('popup-outside-close'));
      final viewport = find.byKey(const ValueKey('help-page-viewport'));
      final frameRect = tester.getRect(artwork);
      final expectedSize = gameHelpPanelSize(
        BoxConstraints(maxWidth: size.width - 24, maxHeight: size.height - 24),
      );
      expect(frameRect.width, closeTo(expectedSize.width, .01));
      expect(frameRect.height, closeTo(expectedSize.height, .01));
      final titleRect = tester.getRect(title);
      final closeRect = tester.getRect(close);
      final viewportRect = tester.getRect(viewport);
      expect(viewportRect.left, greaterThan(frameRect.left));
      expect(viewportRect.right, lessThan(frameRect.right));
      expect(
        viewportRect.top,
        greaterThan(frameRect.top + frameRect.height * .23),
      );
      final drag = await tester.startGesture(viewportRect.center);
      await drag.moveBy(Offset(-viewportRect.width * .65, 0));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(artwork), frameRect);
      expect(tester.getRect(title), titleRect);
      expect(tester.getRect(close), closeRect);
      expect(tester.getRect(viewport), viewportRect);
      expect(tester.takeException(), isNull, reason: 'swipe at $size');
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('meld-examples-page')), findsOneWidget);
      expect(find.text('PER ÖRNEKLERİ'), findsNothing);
      expect(close.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ten concise rules fit the artwork frame in every language', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => appLanguage.value = AppLanguage.turkish);
    for (final language in AppLanguage.values) {
      appLanguage.value = language;
      for (final size in const [
        Size(900, 520),
        Size(568, 320),
        Size(390, 844),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameHelpDialog(key: ValueKey('$language-$size')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final quickFont = tester
            .widget<Text>(find.byKey(const ValueKey('quick-rule-1')))
            .style!
            .fontSize;
        final quickViewport = tester.getRect(
          find.byKey(const ValueKey('help-page-viewport')),
        );
        for (var step = 1; step <= 5; step++) {
          final rect = tester.getRect(find.byKey(ValueKey('quick-rule-$step')));
          expect(quickViewport.inflate(.1).contains(rect.topLeft), isTrue);
          expect(quickViewport.inflate(.1).contains(rect.bottomRight), isTrue);
        }
        for (final control in [
          'open-run',
          'sort-run',
          'open-pairs',
          'sort-pairs',
          'process',
          'draw',
        ]) {
          final button = find.byKey(ValueKey('help-control-$control'));
          final description = tester.widget<Text>(
            find.byKey(ValueKey('help-control-description-$control')),
          );
          expect(description.style!.fontSize, quickFont);
          final descriptionRect = tester.getRect(
            find.byKey(ValueKey('help-control-description-$control')),
          );
          expect(
            quickViewport.inflate(.1).contains(descriptionRect.topLeft),
            isTrue,
          );
          expect(
            quickViewport.inflate(.1).contains(descriptionRect.bottomRight),
            isTrue,
          );
          expect(
            descriptionRect.bottom,
            lessThan(
              tester.getRect(find.byKey(const ValueKey('help-next'))).top - 7,
            ),
          );
          final rect = tester.getRect(button);
          expect(quickViewport.inflate(.1).contains(rect.topLeft), isTrue);
          expect(quickViewport.inflate(.1).contains(rect.bottomRight), isTrue);
          final decoration =
              tester.widget<DecoratedBox>(button).decoration as BoxDecoration;
          expect(decoration.image!.image, isA<AssetImage>());
        }
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('help-next')))
              .color,
          const Color(0xFFFFDF74),
        );
        tester
            .widget<PageView>(find.byType(PageView))
            .controller!
            .jumpToPage(2);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find.byKey(const ValueKey('help-page-viewport')),
        );
        final firstRule = tester.widget<Text>(
          find.byKey(const ValueKey('general-rule-1')),
        );
        expect(quickFont, lessThanOrEqualTo(16));
        for (var rule = 1; rule <= 10; rule++) {
          expect(find.text('$rule.'), findsOneWidget);
          final body = find.byKey(ValueKey('general-rule-$rule'));
          final text = tester.widget<Text>(body);
          expect(text.style!.fontSize, firstRule.style!.fontSize);
          expect(text.style!.fontSize, lessThanOrEqualTo(16));
          if (language == AppLanguage.turkish) {
            expect(
              text.data!.length,
              inInclusiveRange(
                firstRule.data!.length - 12,
                firstRule.data!.length + 14,
              ),
            );
          }
          final rect = tester.getRect(body);
          expect(rect.width, greaterThan(viewport.width * .3));
          expect(
            viewport.inflate(.1).contains(rect.topLeft),
            isTrue,
            reason: 'rule $rule at $size',
          );
          expect(
            viewport.inflate(.1).contains(rect.bottomRight),
            isTrue,
            reason: 'rule $rule at $size',
          );
        }
        expect(find.text('11.'), findsNothing);
        final leftScale = tester
            .renderObject<RenderBox>(
              find.byKey(const ValueKey('general-rule-1')),
            )
            .getTransformTo(null)
            .getMaxScaleOnAxis();
        final rightScale = tester
            .renderObject<RenderBox>(
              find.byKey(const ValueKey('general-rule-6')),
            )
            .getTransformTo(null)
            .getMaxScaleOnAxis();
        expect(leftScale, closeTo(rightScale, .001));
        expect(tester.takeException(), isNull, reason: '$language at $size');
      }
    }
  });
  testWidgets('yardım penceresi üç referans sayfasını gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GameHelpDialog())),
    );

    expect(
      find.text(
        'Her tur taş çekin; seri için en az 101 puan veya çift için 5 çift toplayın.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('help-dot-0')), findsNothing);
    expect(
      tester
          .widget<Image>(find.byKey(const ValueKey('popup-panel-artwork')))
          .image,
      appPopupArtwork(appHelpPanelAsset),
    );
    expect(
      find.byKey(const ValueKey('popup-outside-close')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meld-examples-page')), findsOneWidget);
    expect(find.text('PER ÖRNEKLERİ'), findsNothing);
    expect(find.text('DOĞRU'), findsOneWidget);
    expect(find.text('YANLIŞ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('general-rules-page')), findsOneWidget);
    expect(find.text('GENEL KURALLAR'), findsNothing);
    expect(
      find.text('Biten −101, açmayan 202; diğerleri kalan puanı alır.'),
      findsOneWidget,
    );
    for (var index = 1; index <= 10; index++) {
      expect(find.text('$index.'), findsOneWidget);
    }
    expect(find.text('11.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ana menüdeki soru düğmesi yardımı açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.byKey(const ValueKey('main-help-button')));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.byKey(const ValueKey('game-help-dialog')), findsOneWidget);
    expect(find.text('NASIL OYNANIR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yardım penceresinin tüm sayfaları İngilizce gösterilir', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.english;
    addTearDown(() => appLanguage.value = AppLanguage.turkish);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GameHelpDialog())),
    );

    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(
      find.text('Draw each turn; collect 101 meld points or five pairs.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meld-examples-page')), findsOneWidget);
    expect(find.text('MELD EXAMPLES'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('general-rules-page')), findsOneWidget);
    expect(find.text('GENERAL RULES'), findsNothing);
    expect(
      find.text('The player with the lowest score wins the game.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

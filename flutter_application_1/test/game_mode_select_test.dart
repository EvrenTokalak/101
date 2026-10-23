import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/game_mode_select.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  preparePanelArtwork();
  testWidgets('oyun modu sahnesi geniş ve kısa ekranlarda taşmaz', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    playerProgress.reset();

    for (final size in const [
      Size(1280, 720),
      Size(1024, 420),
      Size(800, 450),
      Size(800, 360),
      Size(568, 320),
      Size(390, 844),
      Size(320, 568),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
          home: const GameModeSelectScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('OYUN MODLARI'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-mode-card-classic-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('game-mode-card-timed-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('game-mode-card-color-bonus-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('game-mode-card-progressive')),
        findsOneWidget,
      );
      expect(find.text('BU MODDA OYNA'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-mode-start')).hitTestable(),
        findsOneWidget,
      );
      for (final id in [
        'classic-101',
        'timed-101',
        'color-bonus-101',
        'progressive',
      ]) {
        final card = tester.getRect(find.byKey(ValueKey('game-mode-card-$id')));
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        final info = find.byKey(ValueKey('game-mode-info-$id'));
        expect(tester.getSize(info).width, greaterThanOrEqualTo(44));
        expect(info.hitTestable(), findsOneWidget);
      }

      await tester.tap(
        find.byKey(const ValueKey('game-mode-info-classic-101')),
      );
      await tester.pump(const Duration(milliseconds: 320));
      expect(
        find.byKey(const ValueKey('game-mode-info-dialog-classic-101')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bu moddaki eller günlük lige sayılmaz.'),
        findsOneWidget,
      );
      final infoSize = tester.getSize(
        find.byKey(const ValueKey('game-mode-info-dialog-classic-101')),
      );
      expect(infoSize.width, lessThanOrEqualTo(480));
      expect(infoSize.height, lessThanOrEqualTo(320));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('game-mode-info-dialog-classic-101')),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 320));
    }
  });

  testWidgets('information does not select a different game mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: GameModeSelectScreen()));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('game-mode-card-timed-101')));
    await tester.pump(const Duration(milliseconds: 300));
    final info = find.byKey(const ValueKey('game-mode-info-progressive'));
    await tester.tap(info);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('game-mode-info-dialog-progressive')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Seri ve çift hedefleri ayrı ilerler'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('game-mode-card-timed-101')),
        matching: find.text('SEÇİLİ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('game-mode-card-progressive')),
        matching: find.text('SEÇİLİ'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mode information contains only a title and a complete paragraph',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => appLanguage.value = AppLanguage.turkish);

      for (final scenario in const [
        (AppLanguage.turkish, Size(568, 320)),
        (AppLanguage.english, Size(320, 568)),
      ]) {
        appLanguage.value = scenario.$1;
        await tester.binding.setSurfaceSize(scenario.$2);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const GameModeSelectScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        for (final id in const [
          'classic-101',
          'timed-101',
          'color-bonus-101',
          'progressive',
        ]) {
          await tester.tap(find.byKey(ValueKey('game-mode-info-$id')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final dialog = find.byKey(ValueKey('game-mode-info-dialog-$id'));
          final paragraph = find.byKey(
            ValueKey('game-mode-info-paragraph-$id'),
          );
          expect(
            find.descendant(of: dialog, matching: find.byType(Text)),
            findsNWidgets(2),
          );
          expect(
            find.descendant(of: dialog, matching: find.byType(Wrap)),
            findsNothing,
          );
          final text = tester.widget<Text>(paragraph);
          expect(text.textSpan!.toPlainText(), isNot(contains('\n')));
          expect(text.textSpan!.toPlainText().length, greaterThan(150));
          expect(text.maxLines, isNull);
          final panelRect = tester.getRect(dialog);
          final paragraphRect = tester.getRect(paragraph);
          expect(paragraphRect.left, greaterThanOrEqualTo(panelRect.left));
          expect(paragraphRect.top, greaterThanOrEqualTo(panelRect.top));
          expect(paragraphRect.right, lessThanOrEqualTo(panelRect.right));
          final scroll = find.descendant(
            of: dialog,
            matching: find.byType(Scrollable),
          );
          expect(scroll, findsOneWidget);
          final viewport = tester.getRect(scroll);
          expect(viewport.bottom, lessThanOrEqualTo(panelRect.bottom));
          final position = tester.state<ScrollableState>(scroll).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          expect(
            tester.getBottomRight(paragraph).dy,
            lessThanOrEqualTo(viewport.bottom + 1),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${scenario.$1} $id ${scenario.$2}',
          );
          await tester.tap(find.byIcon(Icons.close_rounded));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
    },
  );
}

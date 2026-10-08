import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/app_settings_dialog.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(568, 320),
    Size(1280, 720),
  ]) {
    testWidgets('profile cards, real values and keyboard at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      playerProgress.reset();
      appLanguage.value = AppLanguage.turkish;
      appSettings.value = const AppSettings(fontScale: 1.25);
      addTearDown(playerProgress.reset);
      addTearDown(() => appSettings.value = const AppSettings());
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      playerProgress.recordCompletedGame(
        config: const GameLaunchConfig.quickPlay(),
        won: true,
        openedHand: true,
        finishedHand: true,
      );
      playerProgress.recordCompletedGame(
        config: const GameLaunchConfig.quickPlay(),
        won: false,
        openedHand: false,
        finishedHand: false,
      );
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text(defaultPlayerProfileName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final panel = find.byKey(const ValueKey('feature-dialog-PROFİLİM'));
      final panelRect = tester.getRect(panel);
      if (size.width >= 1000) {
        final expectedSize = appSettingsPanelSize(
          const BoxConstraints(maxWidth: 1256, maxHeight: 696),
        );
        expect(panelRect.width, closeTo(expectedSize.width, .01));
        expect(panelRect.height, closeTo(expectedSize.height, .01));
        final results = find.byKey(const ValueKey('profile-stat-results'));
        final label = find.descendant(
          of: results,
          matching: find.text('Galibiyet / Mağlubiyet'),
        );
        final value = find.descendant(
          of: results,
          matching: find.text('1 / 1'),
        );
        expect(tester.widget<Text>(label).style?.fontSize, 22);
        expect(tester.widget<Text>(value).style?.fontSize, 36);
        // Only the shared responsive canvas scales text, never individual cards.
        final labelFitting = find
            .ancestor(of: label, matching: find.byType(FittedBox))
            .evaluate()
            .map((element) => element.widget)
            .toSet();
        final valueFitting = find
            .ancestor(of: value, matching: find.byType(FittedBox))
            .evaluate()
            .map((element) => element.widget)
            .toSet();
        expect(labelFitting.length, 1);
        expect(valueFitting, labelFitting);
      }
      final rects = <Rect>[];
      for (final entry in [
        ('games', '2'),
        ('results', '1 / 1'),
        ('rate', '%50'),
        ('xp', formatGameNumber(playerProgress.totalXpEarned)),
        ('opened', '1'),
        ('finished', '1'),
      ]) {
        final card = find.byKey(ValueKey('profile-stat-${entry.$1}'));
        expect(
          find.descendant(of: card, matching: find.text(entry.$2)),
          findsOneWidget,
        );
        final rect = tester.getRect(card);
        rects.add(rect);
        expect(rect.left, greaterThanOrEqualTo(panelRect.left));
        expect(rect.right, lessThanOrEqualTo(panelRect.right));
      }
      const columns = 3;
      expect(rects[columns - 1].top, closeTo(rects.first.top, 0.1));
      expect(rects[columns].top, greaterThan(rects.first.bottom));
      expect(
        find.descendant(of: panel, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      // The reference grid fits the shared panel canvas without scrolling.
      expect(
        find.descendant(
          of: panel,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('profile-name-field')));
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.35);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      final fieldRect = tester.getRect(
        find.byKey(const ValueKey('profile-name-field')),
      );
      expect(fieldRect.bottom, lessThanOrEqualTo(size.height * 0.65));
      expect(tester.takeException(), isNull);
    });
  }
}

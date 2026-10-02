import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game_mode_select.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  testWidgets('oyun modu sahnesi geniş ve kısa ekranlarda taşmaz', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    playerProgress.reset();

    for (final size in const [
      Size(1280, 720),
      Size(1024, 420),
      Size(800, 450),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: GameModeSelectScreen()));
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

      await tester.tap(
        find.byKey(const ValueKey('game-mode-info-classic-101')),
      );
      await tester.pump(const Duration(milliseconds: 320));
      expect(
        find.byKey(const ValueKey('game-mode-info-dialog-classic-101')),
        findsOneWidget,
      );
      expect(find.text('Standart 101 kuralları'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 320));
    }
  });
}

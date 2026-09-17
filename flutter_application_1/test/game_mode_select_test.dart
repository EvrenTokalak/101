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
      expect(find.text('Oyun Modu Seç'), findsOneWidget);
      expect(find.text('Eliminasyon 101'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-mode-card-elimination-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('game-mode-card-paired-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('game-mode-card-progressive')),
        findsOneWidget,
      );
      expect(find.text('MODU SEÇ'), findsOneWidget);
    }
  });
}

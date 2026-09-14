import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  testWidgets('oyun ayarlari acilir, degisir ve dar ekranda tasmaz', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(startingPlayer: 0)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('game-settings-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('OYUN AYARLARI'), findsOneWidget);
    expect(find.text('Hamle İpuçları'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsNothing);
    expect(find.text('ANA MENÜYE DÖN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('KAYDET'));
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'KAYDET'),
    );
    saveButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('OYUN AYARLARI'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

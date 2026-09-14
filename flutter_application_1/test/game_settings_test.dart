import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';

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
    expect(find.text('Grid Büyüteci'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    expect(find.text('Müzik'), findsNothing);
    expect(
      find.textContaining('Klasik 101', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Hemen Oyna', findRichText: true),
      findsOneWidget,
    );
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

  testWidgets('oyun ayarları mod ve turnuva ayrıntılarını gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          startingPlayer: 0,
          launchConfig: GameLaunchConfig.tournament(
            round: 1,
            roundLabel: 'YARI FİNAL',
            opponent: 'Efe',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('game-settings-button')));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.byKey(const ValueKey('game-match-info')), findsOneWidget);
    expect(find.textContaining('Turnuva', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('YARI FİNAL', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('game-match-info')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().endsWith('Efe'),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

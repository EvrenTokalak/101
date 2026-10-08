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

    expect(find.text('AYARLAR'), findsOneWidget);
    expect(find.text('Ses Efektleri'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('Rakip Resimleri'), findsOneWidget);
    expect(find.text('Otomatik Istaka Dizimi'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    expect(find.text('Grid Büyüteci'), findsNothing);
    expect(find.text('ANA MENÜ'), findsNothing);
    expect(find.text('ANA SAYFA'), findsOneWidget);
    expect(find.text('YENİDEN BAŞLAT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-tutorial-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-home-button')), findsNothing);
    expect(find.byKey(const ValueKey('game-restart-button')), findsNothing);
    expect(tester.takeException(), isNull);

    for (final size in const [Size(800, 450), Size(568, 320), Size(390, 844)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      final actions = [
        find.byKey(const ValueKey('settings-home-button')),
        find.byKey(const ValueKey('settings-restart-button')),
        find.widgetWithText(OutlinedButton, 'VARSAYILAN'),
        find.widgetWithText(FilledButton, 'KAYDET'),
      ];
      final rects = actions.map(tester.getRect).toList();
      final panel = tester.getRect(
        find.byKey(const ValueKey('settings-dialog')),
      );
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].center.dy, closeTo(rects.first.center.dy, 0.1));
        expect(panel.contains(rects[i].topLeft), isTrue);
        expect(panel.contains(rects[i].bottomRight), isTrue);
        expect(actions[i].hitTestable(), findsOneWidget);
        if (i > 0) expect(rects[i - 1].right, lessThan(rects[i].left));
      }
      expect(tester.takeException(), isNull);
    }

    await tester.ensureVisible(find.text('KAYDET'));
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'KAYDET'),
    );
    saveButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AYARLAR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oyun sahnesi ana menü ile aynı ayarları ve yardımı gösterir', (
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

    expect(find.text('AYARLAR'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-match-info')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-close-button')));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.byKey(const ValueKey('game-help-button')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey('game-help-dialog')), findsOneWidget);
    expect(find.text('101 OKEY NASIL OYNANIR?'), findsOneWidget);
    expect(find.text('1. AÇILIŞ değerine ulaşın.'), findsNothing);
    expect(find.text('AÇILIŞ değerine ulaşın.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

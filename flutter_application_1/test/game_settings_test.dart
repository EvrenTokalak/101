import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/performance_overlay.dart';

void main() {
  preparePanelArtwork();
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
    final table = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TableArea',
    );
    expect(
      find
          .ancestor(of: table, matching: find.byType(TickerMode))
          .evaluate()
          .any((element) => !(element.widget as TickerMode).enabled),
      isTrue,
    );
    expect(find.text('Ses Efektleri'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('Rakip Resimleri'), findsOneWidget);
    expect(find.text('Otomatik Istaka Dizimi'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-performance-button')));
    await tester.pump();
    expect(performanceOverlayEnabled.value, isTrue);
    await tester.tap(find.byKey(const ValueKey('settings-performance-button')));
    await tester.pump();
    expect(performanceOverlayEnabled.value, isFalse);
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

    for (final size in const [
      Size(800, 450),
      Size(568, 320),
      Size(390, 844),
      Size(320, 568),
      Size(1024, 768),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      final actions = [
        find.byKey(const ValueKey('settings-home-button')),
        find.byKey(const ValueKey('settings-restart-button')),
        find.byKey(const ValueKey('settings-default-button')),
        find.byKey(const ValueKey('settings-save-button')),
      ];
      final rects = actions.map(tester.getRect).toList();
      final panel = tester.getRect(
        find.byKey(const ValueKey('settings-dialog')),
      );
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].center.dy, closeTo(rects.first.center.dy, 0.1));
        expect(rects[i].width, closeTo(rects.first.width, 0.1));
        expect(rects[i].height, closeTo(rects.first.height, 0.1));
        expect(panel.contains(rects[i].topLeft), isTrue);
        expect(panel.contains(rects[i].bottomRight), isTrue);
        expect(actions[i].hitTestable(), findsOneWidget);
        if (i > 0) expect(rects[i - 1].right, lessThan(rects[i].left));
      }
      expect(tester.takeException(), isNull);
    }

    await tester.ensureVisible(find.text('KAYDET'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-save-button')));
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
    expect(find.text('NASIL OYNANIR'), findsOneWidget);
    expect(find.text('1. AÇILIŞ değerine ulaşın.'), findsNothing);
    expect(find.byKey(const ValueKey('quick-rule-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'hiding opponent photos preserves centered names and table piles',
    (tester) async {
      setGameOpponentPicturesEnabled(true);
      addTearDown(() => setGameOpponentPicturesEnabled(true));
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(startingPlayer: 0)),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      for (final name in ['Oyuncu 2', 'Oyuncu 3', 'Oyuncu 4']) {
        expect(find.byKey(ValueKey('bot-avatar-$name')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('game-settings-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Rakip Resimleri'));
      await tester.tap(find.text('KAYDET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final name in ['Oyuncu 2', 'Oyuncu 3', 'Oyuncu 4']) {
        expect(find.byKey(ValueKey('bot-avatar-$name')), findsNothing);
        expect(find.byKey(ValueKey('bot-name-$name')), findsOneWidget);
        expect(find.byKey(ValueKey('seat-$name')), findsOneWidget);
      }
      final table = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TableArea',
      );
      expect(
        tester
            .widgetList(
              find.descendant(
                of: table,
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_TableDiscardPile',
                ),
              ),
            )
            .length,
        4,
      );
      for (final name in ['Oyuncu 2', 'Oyuncu 4']) {
        final seat = find.byKey(ValueKey('seat-$name'));
        final fitted = find
            .ancestor(of: seat, matching: find.byType(FittedBox))
            .first;
        expect(
          tester.getCenter(seat).dy,
          closeTo(tester.getCenter(fitted).dy, 0.1),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

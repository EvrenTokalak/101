import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/oda.dart';
import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  testWidgets('room buttons remain visible at short web sizes', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          home: const RoomSelectScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('MASA SEÇ'), findsOneWidget);
      expect(find.text('Odaya Gir'), findsOneWidget);
      expect(find.text('BAŞLANGIÇ'), findsOneWidget);
      expect(find.textContaining('DOLU'), findsNothing);
      for (final fee in ['1.500', '3.750', '7.500', '12.000']) {
        expect(find.text(fee), findsOneWidget);
      }
      for (var index = 0; index < 4; index++) {
        final rect = tester.getRect(find.byKey(ValueKey('room-card-$index')));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      expect(
        find.byKey(const ValueKey('room-enter-button')).hitTestable(),
        findsOneWidget,
      );
    }
  });

  testWidgets('son masa 25. seviyede açılır', (tester) async {
    playerProgress.reset(level: 0);
    addTearDown(playerProgress.reset);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoomSelectScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text("SEVİYE 25'TE AÇILIR"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-card-3')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("SEVİYE 25'TE AÇILIR"), findsOneWidget);
    await tester.tap(find.text('Odaya Gir'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('25. seviyede açılır'), findsOneWidget);
  });

  testWidgets('selection and lock emblems follow live player progress', (
    tester,
  ) async {
    playerProgress.reset(level: 0, coins: 20000);
    addTearDown(playerProgress.reset);
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoomSelectScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('room-dynamic-emblem-1')), findsOneWidget);
    expect(find.text("SEVİYE 15'TE AÇILIR"), findsOneWidget);
    playerProgress.reset(level: 25, coins: 20000);
    await tester.pump();
    expect(find.byKey(const ValueKey('room-dynamic-emblem-1')), findsNothing);
    expect(find.byKey(const ValueKey('room-dynamic-emblem-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-dynamic-emblem-3')), findsOneWidget);
    expect(find.textContaining('AÇILIR'), findsNothing);
    expect(find.textContaining('DOLU'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('room-card-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-card-1')),
        matching: find.text('SEÇİLİ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-card-0')),
        matching: find.text('SEÇİLİ'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('yetersiz altınla ücretli odaya girilemez', (tester) async {
    playerProgress.reset(coins: 100);
    addTearDown(playerProgress.reset);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RoomSelectScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Odaya Gir'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.textContaining('1.500 altın gerekiyor'), findsOneWidget);
    expect(playerProgress.coins, 100);
    expect(tester.takeException(), isNull);
  });
}

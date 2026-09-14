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
      expect(find.text('Oda Seç'), findsOneWidget);
      expect(find.text('Odaya Gir'), findsOneWidget);
      expect(find.text('BAŞLANGIÇ'), findsOneWidget);
    }
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
    expect(find.textContaining('500 altın gerekiyor'), findsOneWidget);
    expect(playerProgress.coins, 100);
    expect(tester.takeException(), isNull);
  });
}

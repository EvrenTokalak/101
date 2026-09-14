import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/oda.dart';

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
}

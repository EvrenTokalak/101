// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Okey app opens on the splash screen', (tester) async {
    await tester.pumpWidget(const OkeyApp());

    expect(find.text('101'), findsOneWidget);
    expect(find.text('OKEY'), findsOneWidget);

    // Splash'taki gecikmeli animasyon zincirinin her adımına bir frame ver.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('HEMEN OYNA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

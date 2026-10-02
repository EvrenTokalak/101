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

  testWidgets('ana menü mağaza sayfasını açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.byKey(const ValueKey('main-store-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('MAĞAZA'), findsOneWidget);
    expect(find.byKey(const ValueKey('store-racks-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('store-tiles-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('store-backgrounds-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('store-racks-list')), findsOneWidget);
    expect(find.text('KLASİK AHŞAP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('store-tiles-tab')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('store-tiles-list')), findsOneWidget);
    expect(find.text('KLASİK TAŞ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('store-backgrounds-tab')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('store-backgrounds-list')),
      findsOneWidget,
    );
    expect(find.text('GECE MAVİSİ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ana menu eylemleri referanstaki ikiye iki sirada gorunur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    final missions = tester.getCenter(find.text('GÖREVLER'));
    final modes = tester.getCenter(find.text('OYUN MODLARI'));
    final rooms = tester.getCenter(find.text('MASA SEÇ'));
    final tournament = tester.getCenter(find.text('TURNUVALAR'));
    final quickPlay = tester.getCenter(find.text('HEMEN OYNA'));

    expect(missions.dy, closeTo(modes.dy, 0.1));
    expect(rooms.dy, closeTo(tournament.dy, 0.1));
    expect(missions.dy, lessThan(rooms.dy));
    expect(rooms.dy, lessThan(quickPlay.dy));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

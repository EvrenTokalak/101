import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_controls.dart';

import 'panel_artwork_test_support.dart';

void main() {
  preparePanelArtwork();

  testWidgets('generic panel titles and scrollable content fit small screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [
      Size(320, 568),
      Size(568, 320),
      Size(800, 360),
      Size(1280, 720),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.25),
            ),
            child: Scaffold(
              body: Center(
                child: AppGenericPanel(
                  title: const Text('UZUN BİR PANEL BAŞLIĞI'),
                  onClose: () {},
                  scrollable: true,
                  child: Column(
                    children: [
                      for (var i = 0; i < 15; i++)
                        SizedBox(height: 50, child: Text('Bilgi satırı $i')),
                      TextButton(
                        onPressed: () {},
                        child: const Text('SON İŞLEM'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final frame = tester.getRect(find.byType(AppGenericPanel));
      final title = tester.getRect(
        find.byKey(const ValueKey('panel-title-region')),
      );
      expect(frame.contains(title.center), isTrue);
      expect(frame.width, lessThanOrEqualTo(size.width - 24));
      expect(frame.height, lessThanOrEqualTo(size.height - 24));
      await tester.ensureVisible(find.text('SON İŞLEM'));
      await tester.pump();
      expect(find.text('SON İŞLEM').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'generic panel at $size');
    }
  });

  testWidgets('panel content can be dragged with a mouse', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 180,
              child: AppPanelScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 48, child: Text('Görev $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPanelScrollView)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    expect(position.pixels, greaterThan(0));
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

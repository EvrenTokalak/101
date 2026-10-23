import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_controls.dart';

import 'panel_artwork_test_support.dart';

void main() {
  preparePanelArtwork();
  testWidgets('localized action labels fit fixed bounds with large text', (
    tester,
  ) async {
    for (final scale in [1.0, 1.25, 2.0]) {
      for (final width in [100.0, 160.0, 230.0]) {
        for (final label in [
          'YENİDEN BAŞLAT',
          'NEU STARTEN',
          'MARK ALL AS READ',
        ]) {
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Center(
                    child: AppArtworkButton(
                      key: const ValueKey('action'),
                      width: width,
                      label: label,
                      fontSize: 20,
                      icon: Icons.restart_alt,
                      outlinedText: true,
                      onPressed: () => taps++,
                    ),
                  ),
                ),
              ),
            ),
          );
          final bounds = tester.getRect(find.byKey(const ValueKey('action')));
          final text = tester.getRect(find.text(label));
          expect(bounds.width, width);
          expect(bounds.height, AppButtonMetrics.height);
          expect(bounds.contains(text.topLeft), isTrue);
          expect(bounds.contains(text.bottomRight), isTrue);
          await tester.tap(find.text(label));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}

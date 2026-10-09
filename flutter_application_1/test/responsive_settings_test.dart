import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_settings_dialog.dart';
import 'package:flutter_application_1/app_language.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(568, 320),
    Size(1024, 768),
    Size(1280, 720),
  ]) {
    testWidgets('home and settings at $size with large text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      appLanguage.value = AppLanguage.turkish;
      appSettings.value = const AppSettings(fontScale: 1.25);
      addTearDown(() => appSettings.value = const AppSettings());
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      expect(tester.takeException(), isNull);
      if (size.width / size.height >= 1.2 && size.height >= 600) {
        final layout = tester.getRect(
          find.byKey(const ValueKey('landscape-home-layout')),
        );
        expect(layout.top, closeTo(0, 1));
        expect(layout.height, closeTo(size.height, 1));
      }
      // Evicted artwork must never delay the interactive settings panel.
      PaintingBinding.instance.imageCache.clear();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(
        find.byKey(const ValueKey('settings-dialog')),
      );
      final artwork = find.byKey(const ValueKey('settings-panel-artwork'));
      expect(artwork, findsOneWidget);
      final image = tester.widget<Image>(artwork);
      expect(image.image, appSettingsArtwork);
      expect(
        find.byKey(const ValueKey('settings-panel-ready')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-close-button')).hitTestable(),
        findsOneWidget,
      );
      expect(panel.width / panel.height, closeTo(1671 / 941, 0.001));
      final cards = find.byKey(const ValueKey('settings-option-card'));
      expect(cards, findsNWidgets(9));
      expect(
        find.byKey(const ValueKey('settings-switch-indicator')),
        findsNWidgets(7),
      );
      for (final card in cards.evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(panel.contains(rect.topLeft), isTrue);
        expect(panel.contains(rect.bottomRight), isTrue);
      }
      final rowRects = cards
          .evaluate()
          .take(8)
          .map((card) => tester.getRect(find.byWidget(card.widget)))
          .toList();
      for (var i = 0; i < 8; i += 2) {
        expect(rowRects[i].center.dy, closeTo(rowRects[i + 1].center.dy, 0.1));
        expect(rowRects[i].right, lessThan(rowRects[i + 1].left));
      }
      final soundSwitch = find
          .byKey(const ValueKey('settings-switch-indicator'))
          .first;
      Alignment soundKnobAlignment() =>
          tester
                  .widget<AnimatedAlign>(
                    find.descendant(
                      of: soundSwitch,
                      matching: find.byType(AnimatedAlign),
                    ),
                  )
                  .alignment
              as Alignment;
      expect(soundKnobAlignment(), Alignment.centerRight);
      await tester.tap(find.text('Ses Efektleri'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(soundKnobAlignment(), Alignment.centerLeft);
      await tester.tap(find.text('Ses Efektleri'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(size.width));
      expect(panel.bottom, lessThanOrEqualTo(size.height));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-dialog')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      for (final key in ['settings-language-dropdown']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(panel.contains(rect.topLeft), isTrue);
        expect(panel.contains(rect.bottomRight), isTrue);
      }
      expect(find.text('KAYDET').hitTestable(), findsOneWidget);
      for (final language in ['EN', 'DE', 'TR']) {
        await tester.tap(
          find.byKey(const ValueKey('settings-language-dropdown')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final button = find.byKey(ValueKey('language-$language'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('KAYDET'));
      await tester.tap(find.text('KAYDET'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('settings remain usable when panel artwork fails to load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MissingSettingsArtwork(),
          child: const AppSettingsDialog(initial: AppSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('AYARLAR'), findsWidgets);
    expect(
      find.byKey(const ValueKey('settings-panel-fallback')),
      findsOneWidget,
    );
    expect(find.text('KAYDET').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Ses Efektleri'));
    await tester.pump();
    final indicator = find
        .byKey(const ValueKey('settings-switch-indicator'))
        .first;
    expect(
      tester
          .widget<AnimatedAlign>(
            find.descendant(
              of: indicator,
              matching: find.byType(AnimatedAlign),
            ),
          )
          .alignment,
      Alignment.centerLeft,
    );
    expect(
      find.byKey(const ValueKey('settings-close-button')).hitTestable(),
      findsOneWidget,
    );
  });
}

class _MissingSettingsArtwork extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == appSettingsPanelAsset) {
      return Future<ByteData>.error(StateError('Missing settings artwork'));
    }
    return rootBundle.load(key);
  }
}

import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/app_controls.dart';
import 'package:flutter_application_1/app_settings_dialog.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/player_progress.dart';

Rect _paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

void main() {
  preparePanelArtwork();
  for (final size in const [Size(568, 320), Size(800, 360), Size(390, 844)]) {
    testWidgets('separate name editor fits above a phone keyboard at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      playerProgress.reset();
      appLanguage.value = AppLanguage.turkish;
      appSettings.value = const AppSettings();
      addTearDown(playerProgress.reset);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);
      // A visible navigation bar becomes IME padding while the keyboard opens.
      tester.view.viewPadding = const FakeViewPadding(bottom: 16);
      tester.view.padding = const FakeViewPadding(bottom: 16);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      final homeProfile = find.byKey(const ValueKey('main-xp-chip'));
      final homeProfileRect = _paintedRect(tester, homeProfile);
      await tester.tap(find.text(defaultPlayerProfileName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final profile = find.byKey(const ValueKey('feature-dialog-PROFİLİM'));
      final profileRect = tester.getRect(profile);
      expect(find.byKey(const ValueKey('profile-name-field')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-name-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final nameDialog = find.byKey(const ValueKey('profile-name-dialog'));
      expect(nameDialog, findsOneWidget);
      expect(
        tester
            .widget<Image>(
              find.descendant(
                of: nameDialog,
                matching: find.byKey(const ValueKey('popup-panel-artwork')),
              ),
            )
            .image,
        appPopupArtwork(appGenericPanelAsset),
      );
      final field = find.byKey(const ValueKey('profile-name-field'));
      await tester.enterText(field, 'Yeni Oyuncu');
      final controller = tester.widget<TextField>(field).controller;
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * .55);
      tester.view.padding = const FakeViewPadding();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getRect(profile), profileRect);
      expect(_paintedRect(tester, homeProfile), homeProfileRect);
      expect(find.byKey(const ValueKey('profile-stat-games')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-draft-avatar')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(tester.widget<TextField>(field).controller!.text, 'Yeni Oyuncu');
      expect(
        tester.widget<TextField>(field).style!.fontSize,
        greaterThanOrEqualTo(18),
      );
      expect(tester.testTextInput.isVisible, isTrue);
      final keyboardTop = size.height * .45;
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('profile-name-confirm')))
            .bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(tester.getRect(nameDialog).bottom, lessThanOrEqualTo(keyboardTop));
      expect(playerProgress.playerName, defaultPlayerProfileName);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.padding = const FakeViewPadding(bottom: 16);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(_paintedRect(tester, homeProfile), homeProfileRect);
      expect(find.byKey(const ValueKey('profile-stat-games')), findsOneWidget);
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(tester.widget<TextField>(field).controller!.text, 'Yeni Oyuncu');
      await tester.tap(find.byKey(const ValueKey('profile-name-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(nameDialog, findsNothing);
      expect(profile, findsOneWidget);
      expect(playerProgress.playerName, defaultPlayerProfileName);
      await tester.tap(find.byKey(const ValueKey('profile-name-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(playerProgress.playerName, 'Yeni Oyuncu');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('name validation and cancel preserve the unsaved profile draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    playerProgress.reset();
    appLanguage.value = AppLanguage.turkish;
    appSettings.value = const AppSettings();
    addTearDown(playerProgress.reset);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.text(defaultPlayerProfileName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final edit = find.byKey(const ValueKey('profile-name-edit'));
    final field = find.byKey(const ValueKey('profile-name-field'));
    final confirm = find.byKey(const ValueKey('profile-name-confirm'));
    final dialog = find.byKey(const ValueKey('profile-name-dialog'));
    final cancel = find.descendant(
      of: dialog,
      matching: find.byKey(const ValueKey('popup-outside-close')),
    );
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, '   ');
    await tester.tap(confirm);
    await tester.pump();
    expect(dialog, findsOneWidget);
    expect(playerProgress.playerName, defaultPlayerProfileName);
    await tester.enterText(field, ' Taslak Oyuncu ');
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(dialog, findsNothing);
    expect(playerProgress.playerName, defaultPlayerProfileName);
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<TextField>(field).controller!.text, 'Taslak Oyuncu');
    await tester.enterText(field, 'Vazgeçilen İsim');
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(dialog, findsNothing);
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<TextField>(field).controller!.text, 'Taslak Oyuncu');
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('profile-close-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(playerProgress.playerName, defaultPlayerProfileName);
    await tester.tap(find.text(defaultPlayerProfileName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<TextField>(field).controller!.text,
      defaultPlayerProfileName,
    );
    expect(tester.takeException(), isNull);
  });
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(568, 320),
    Size(1280, 720),
  ]) {
    testWidgets('profile cards, real values and keyboard at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      playerProgress.reset();
      appLanguage.value = AppLanguage.turkish;
      appSettings.value = const AppSettings(fontScale: 1.25);
      addTearDown(playerProgress.reset);
      addTearDown(() => appSettings.value = const AppSettings());
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      playerProgress.recordOpening(156);
      playerProgress.recordCompletedGame(
        config: const GameLaunchConfig.quickPlay(),
        won: true,
        openedHand: true,
        finishedHand: true,
      );
      playerProgress.recordCompletedGame(
        config: const GameLaunchConfig.quickPlay(),
        won: false,
        openedHand: false,
        finishedHand: false,
      );
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text(defaultPlayerProfileName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final panel = find.byKey(const ValueKey('feature-dialog-PROFİLİM'));
      final panelRect = tester.getRect(panel);
      if (size.width >= 1000) {
        final expectedSize = appSettingsPanelSize(
          const BoxConstraints(maxWidth: 1256, maxHeight: 696),
        );
        expect(panelRect.width, closeTo(expectedSize.width, .01));
        expect(panelRect.height, closeTo(expectedSize.height, .01));
        final results = find.byKey(const ValueKey('profile-stat-results'));
        final label = find.descendant(
          of: results,
          matching: find.text('Galibiyet / Mağlubiyet'),
        );
        final value = find.descendant(
          of: results,
          matching: find.text('1 / 1'),
        );
        expect(tester.widget<Text>(label).style?.fontSize, 26);
        expect(tester.widget<Text>(value).style?.fontSize, 46);
        for (final textFinder in [label, value]) {
          final box = tester.renderObject<RenderBox>(textFinder);
          final textRect = Rect.fromPoints(
            box.localToGlobal(Offset.zero),
            box.localToGlobal(box.size.bottomRight(Offset.zero)),
          );
          final cardBox = tester.renderObject<RenderBox>(results);
          final cardRect = Rect.fromPoints(
            cardBox.localToGlobal(Offset.zero),
            cardBox.localToGlobal(cardBox.size.bottomRight(Offset.zero)),
          );
          expect(textRect.left, greaterThanOrEqualTo(cardRect.left));
          expect(textRect.right, lessThanOrEqualTo(cardRect.right + .1));
          expect(textRect.top, greaterThanOrEqualTo(cardRect.top));
          expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom + .1));
        }
      }
      final rects = <Rect>[];
      for (final entry in [
        ('games', '2'),
        ('results', '1 / 1'),
        ('opening', '156'),
        ('xp', formatGameNumber(playerProgress.totalXpEarned)),
        ('opened', '1'),
        ('finished', '1'),
      ]) {
        final card = find.byKey(ValueKey('profile-stat-${entry.$1}'));
        expect(
          find.descendant(of: card, matching: find.text(entry.$2)),
          findsOneWidget,
        );
        final box = tester.renderObject<RenderBox>(card);
        final rect = Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(panelRect.top + panelRect.height * .89),
        );
        rects.add(rect);
        expect(rect.left, greaterThanOrEqualTo(panelRect.left));
        expect(rect.right, lessThanOrEqualTo(panelRect.right));
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom - .1));
        expect(rects[i].left, closeTo(rects.first.left, .1));
      }
      expect(
        find.descendant(of: panel, matching: find.byType(Scrollable)),
        findsNothing,
      );
      // The reference grid fits the shared panel canvas without scrolling.
      expect(
        find.descendant(
          of: panel,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      for (final save in [false, true]) {
        await tester.tap(find.byKey(const ValueKey('profile-avatar-edit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const ValueKey('profile-avatar-1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(playerProgress.playerAvatarIndex, 0);
        expect(
          tester
              .widget<Image>(find.byKey(const ValueKey('profile-draft-avatar')))
              .image,
          isA<ResizeImage>().having(
            (image) => image.imageProvider,
            'asset',
            AssetImage(playerAvatarAssets[1]),
          ),
        );
        await tester.tap(
          find.byKey(
            ValueKey(save ? 'profile-name-save' : 'profile-close-button'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(playerProgress.playerAvatarIndex, save ? 1 : 0);
        await tester.tap(find.text(defaultPlayerProfileName));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          tester
              .widget<Image>(find.byKey(const ValueKey('profile-draft-avatar')))
              .image,
          isA<ResizeImage>().having(
            (image) => image.imageProvider,
            'asset',
            AssetImage(playerAvatarAssets[save ? 1 : 0]),
          ),
        );
      }
      await tester.tap(find.byKey(const ValueKey('profile-name-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.35);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      final fieldRect = tester.getRect(
        find.byKey(const ValueKey('profile-name-field')),
      );
      expect(fieldRect.bottom, lessThanOrEqualTo(size.height * 0.65));
      expect(tester.takeException(), isNull);
    });
  }
}

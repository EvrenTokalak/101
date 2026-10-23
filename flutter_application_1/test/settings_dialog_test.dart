import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/daily_login_rewards.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/performance_overlay.dart';
import 'package:flutter_application_1/app_controls.dart';

void main() {
  preparePanelArtwork();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesAsync().clear();
    performanceOverlayEnabled.value = false;
  });

  testWidgets('dil seçimi ana menü metinlerini İngilizceye çevirir', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.turkish;
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => appLanguage.value = AppLanguage.turkish);

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('settings-language-dropdown')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('language-EN')));
    await tester.pump();
    expect(find.text('SETTINGS'), findsOneWidget);
    await tester.ensureVisible(find.text('SAVE'));
    await tester.tap(find.text('SAVE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PLAY NOW'), findsOneWidget);
    expect(find.text('Beginner · Level 0'), findsOneWidget);
    expect(find.textContaining('League ·'), findsOneWidget);
    expect(find.text('GAME\nMODES'), findsOneWidget);
  });

  testWidgets('Almanca dil seçimi ana menü ve ayarlarda uygulanır', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.turkish;
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => appLanguage.value = AppLanguage.turkish);

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('settings-language-dropdown')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('language-DE')));
    await tester.pump();
    expect(find.text('EINSTELLUNGEN'), findsOneWidget);
    await tester.ensureVisible(find.text('SPEICHERN'));
    await tester.tap(find.text('SPEICHERN'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('JETZT SPIELEN'), findsOneWidget);
    expect(find.text('Anfänger · Stufe 0'), findsOneWidget);
    expect(find.textContaining('Liga ·'), findsOneWidget);
    expect(find.text('SPIEL\nMODI'), findsOneWidget);
  });

  testWidgets(
    'home wallet follows entry fees and room win payments without a reward animation',
    (tester) async {
      playerProgress.reset(coins: 10000);
      addTearDown(playerProgress.reset);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      final balance = find.byKey(const ValueKey('home-coin-balance'));
      expect(tester.widget<Text>(balance).data, '10.000');
      expect(playerProgress.trySpendCoins(2000), isTrue);
      await tester.pump();
      expect(tester.widget<Text>(balance).data, '8.000');
      playerProgress.recordCompletedGame(
        config: const GameLaunchConfig.room(
          id: 'room-0',
          label: 'Başlangıç',
          entryFee: 2000,
        ),
        won: true,
        openedHand: true,
        finishedHand: true,
        roundNumber: 3,
        roomMatchWon: true,
      );
      await tester.pump();
      expect(tester.widget<Text>(balance).data, '12.000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('settings icon opens the animated settings dialog', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.turkish;
    playerProgress.reset();
    addTearDown(playerProgress.reset);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('main-xp-chip')), findsOneWidget);
    expect(find.text('Başlangıç · Seviye 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AYARLAR'), findsOneWidget);
    expect(find.text('Ses Efektleri'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    expect(find.text('Oyun Davetleri'), findsNothing);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('Rakip Resimleri'), findsOneWidget);
    expect(find.text('Otomatik Istaka Dizimi'), findsOneWidget);
    expect(find.text('Hamle İpuçları'), findsOneWidget);
    expect(find.text('Ses ve titreşim'), findsOneWidget);
    expect(find.text('Oynanış'), findsOneWidget);
    expect(find.text('Görünüm ve dil'), findsOneWidget);
    expect(find.text('MÜZİK'), findsNothing);
    expect(find.text('KENAR TAŞLARI'), findsNothing);
    expect(find.text('PERFORMANS'), findsNothing);
    expect(find.text('Akıcı Animasyonlar'), findsNothing);
    final settingsDialogSize = tester.getSize(
      find.byKey(const ValueKey('settings-dialog')),
    );
    expect(
      tester
          .getRect(
            find.descendant(
              of: find.byKey(const ValueKey('settings-close-button')),
              matching: find.byType(Image),
            ),
          )
          .size,
      const Size(40, 40),
    );
    expect(find.byKey(const ValueKey('performance-readout')), findsNothing);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.2);
    await tester.pump();
    await tester.ensureVisible(find.text('KAYDET'));
    await tester.tap(find.text('KAYDET'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('performance-readout')), findsNothing);

    final menuTextContext = tester.element(find.text('HEMEN OYNA'));
    expect(
      MediaQuery.textScalerOf(menuTextContext).scale(10),
      closeTo(12.6, 0.01),
    );

    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('GELEN KUTUSU'), findsOneWidget);
    expect(find.text('Günlük ödülün hazır'), findsOneWidget);
    expect(find.text('Lig sıralamanı kontrol et'), findsOneWidget);
    expect(find.text('YENİ'), findsNothing);
    expect(
      find.byKey(const ValueKey('inbox-unread-dot-Günlük ödülün hazır')),
      findsNothing,
    );
    expect(find.textContaining('20.00'), findsNothing);
    expect(find.textContaining('Ödülünü almayı unutma'), findsNothing);
    expect(find.textContaining('masalarında bol şans'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    final inboxDialogSize = tester.getSize(
      find.byKey(const ValueKey('feature-dialog-GELEN KUTUSU')),
    );
    expect(inboxDialogSize.width, closeTo(settingsDialogSize.width, 0.1));
    expect(inboxDialogSize, settingsDialogSize);
    expect(
      tester
          .widget<Image>(find.byKey(const ValueKey('popup-panel-artwork')))
          .image,
      appPopupArtwork('images/ui/panels/gelen-kutusu.png'),
    );
    expect(
      TickerMode.valuesOf(
        tester.element(find.byKey(const ValueKey('home-missions-button'))),
      ).enabled,
      isFalse,
    );
    final inboxClose = tester.getRect(
      find.byKey(const ValueKey('popup-outside-close')),
    );
    final inboxArtwork = tester.getRect(
      find.byKey(const ValueKey('popup-panel-artwork')),
    );
    expect(
      inboxClose.center.dy,
      closeTo(inboxArtwork.top + inboxArtwork.height * .225, 0.1),
    );
    expect(inboxClose.right, lessThanOrEqualTo(inboxArtwork.right));

    final inboxViewport = find.byKey(
      const ValueKey('feature-content-viewport-GELEN KUTUSU'),
    );
    final viewportRect = tester.getRect(inboxViewport);
    expect(
      viewportRect.bottom,
      lessThanOrEqualTo(inboxArtwork.top + inboxArtwork.height * .82 + .1),
    );
    expect(
      find.descendant(of: inboxViewport, matching: find.byType(Scrollbar)),
      findsNothing,
    );
    expect(
      viewportRect.top,
      greaterThan(inboxArtwork.top + inboxArtwork.height * .23),
    );
    expect(viewportRect.bottom, lessThan(inboxArtwork.bottom));
    final clip = tester.widget<ClipRRect>(inboxViewport);
    expect(clip.clipBehavior, Clip.antiAlias);
    final drag = await tester.startGesture(viewportRect.center);
    await drag.moveBy(const Offset(0, -90));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(inboxViewport), viewportRect);
    expect(
      tester.getRect(find.byKey(const ValueKey('popup-panel-artwork'))),
      inboxArtwork,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('popup-outside-close'))),
      inboxClose,
    );
    await drag.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Günlük ödülün hazır'));

    await tester.tap(find.text('Günlük ödülün hazır'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('GÜNLÜK ÖDÜL'), findsOneWidget);
    expect(find.text('GELEN KUTUSU'), findsNothing);

    expect(find.text('TAMAM'), findsNothing);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.byKey(const ValueKey('main-wallet-button')));
    await tester.pump();
    expect(find.text('Cüzdan yapım aşamasında.'), findsOneWidget);
    expect(find.text('CÜZDAN'), findsNothing);

    await tester.tap(find.text(defaultPlayerProfileName));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('PROFİLİM'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-name-field')), findsNothing);
    expect(find.byKey(const ValueKey('profile-name-edit')), findsOneWidget);
    expect(find.text('Başlangıç · Seviye 0'), findsOneWidget);
    expect(find.text('En Yüksek Açılış'), findsOneWidget);
    final profileDialog = find.byKey(const ValueKey('feature-dialog-PROFİLİM'));
    final profileDialogSize = tester.getSize(profileDialog);
    expect(profileDialogSize, settingsDialogSize);
    final profileClose = find.byKey(const ValueKey('profile-close-button'));
    expect(profileClose.hitTestable(), findsOneWidget);
    expect(tester.getSize(profileClose).width, greaterThanOrEqualTo(40));
    expect(
      tester
          .getRect(
            find.descendant(of: profileClose, matching: find.byType(Image)),
          )
          .size,
      const Size(32, 32),
    );
    expect(
      find.descendant(
        of: profileDialog,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('profile-career-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-avatar-1')), findsNothing);
    expect(find.byKey(const ValueKey('profile-avatar-edit')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-avatar-edit')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey('profile-avatar-picker')), findsOneWidget);
    expect(playerAvatarAssets, hasLength(24));
    final avatarGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('profile-avatar-grid')),
    );
    expect(
      (avatarGrid.childrenDelegate as SliverChildBuilderDelegate)
          .estimatedChildCount,
      24,
    );
    expect(find.byKey(const ValueKey('profile-avatar-1')), findsOneWidget);
    final avatarPickerSize = tester.getSize(
      find.byKey(const ValueKey('profile-avatar-picker')),
    );
    expect(avatarPickerSize.width, lessThan(profileDialogSize.width));
    expect(
      avatarPickerSize.height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    await tester.tap(find.byKey(const ValueKey('profile-avatar-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.playerAvatarIndex, 1);
    expect(find.byKey(const ValueKey('profile-avatar-picker')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-name-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Gökde',
    );
    await tester.tap(find.byKey(const ValueKey('profile-name-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.playerName, 'Gökde');
    expect(playerProgress.playerAvatarIndex, 1);
    await tester.tap(find.byKey(const ValueKey('profile-close-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.playerName, 'Gökde');
    expect(playerProgress.playerAvatarIndex, 1);
    expect(find.byKey(const ValueKey('feature-dialog-PROFİLİM')), findsNothing);
    await tester.tap(find.text('Gökde').first);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('profile-name-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      '123456789012345678',
    );
    await tester.pump();
    expect(find.text('18 karakter sınırına ulaştın.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-name-dialog')),
        matching: find.byKey(const ValueKey('popup-outside-close')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('profile-close-button')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Gökde'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'daily reward pays once per day and advances across calendar days',
    (tester) async {
      appLanguage.value = AppLanguage.turkish;
      playerProgress.reset();
      await dailyLogin.load();
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(playerProgress.reset);

      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));

      expect(
        find.byKey(const ValueKey('main-notification-badge')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('daily-reward-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = find.byKey(
        const ValueKey('feature-dialog-GÜNLÜK GİRİŞ ÖDÜLÜ'),
      );
      expect(dialog, findsOneWidget);
      expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('popup-panel-artwork')))
            .image,
        appPopupArtwork('images/ui/panels/gunluk-odul.png'),
      );
      expect(tester.getSize(dialog), const Size(1256, 1256 / 2.35));
      final outsideClose = find.byKey(const ValueKey('popup-outside-close'));
      final artwork = find.byKey(const ValueKey('popup-panel-artwork'));
      expect(outsideClose.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(outsideClose).center.dy,
        closeTo(
          tester.getRect(dialog).top +
              appPanelCloseRect(
                'images/ui/panels/gunluk-odul.png',
                tester.getSize(dialog),
              ).center.dy,
          0.1,
        ),
      );
      expect(
        tester.getRect(outsideClose).right,
        lessThanOrEqualTo(tester.getRect(artwork).right),
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('daily-login-claim')), findsNothing);
      expect(find.byKey(const ValueKey('daily-login-day-1')), findsOneWidget);
      expect(find.text('TOPLA'), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-login-today-1')), findsOneWidget);
      final closeButton = tester.widget<AppCloseButton>(
        find.descendant(of: dialog, matching: find.byType(AppCloseButton)),
      );
      expect(closeButton.size, 32);
      expect(tester.getSize(outsideClose), const Size(46, 46));
      expect(find.text('ALINDI'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.text('KİLİTLİ'), findsNWidgets(6));
      expect(find.textContaining('Her gün gel'), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.text('ALTIN')),
        findsNothing,
      );
      final firstDay = tester.getRect(
        find.byKey(const ValueKey('daily-login-day-1')),
      );
      final fourthDay = tester.getRect(
        find.byKey(const ValueKey('daily-login-day-4')),
      );
      final fifthDay = tester.getRect(
        find.byKey(const ValueKey('daily-login-day-5')),
      );
      expect(firstDay.top, fourthDay.top);
      expect(firstDay.height, lessThanOrEqualTo(420));
      expect(fifthDay.top, firstDay.top);
      final finalDay = tester.getRect(
        find.byKey(const ValueKey('daily-login-day-7')),
      );
      expect(finalDay.width / firstDay.width, closeTo(1.5, .001));
      expect(finalDay.height, closeTo(firstDay.height, .001));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('daily-login-collect-1')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('daily-login-collect-visual-1')))
            .height,
        24,
      );

      for (final size in const [
        Size(320, 568),
        Size(320, 360),
        Size(390, 844),
        Size(568, 320),
        Size(800, 360),
        Size(1280, 720),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'daily reward layout at $size',
        );
        final firstCard = tester.getRect(
          find.byKey(const ValueKey('daily-login-day-1')),
        );
        expect(firstCard.width, greaterThan(30));
        expect(firstCard.height / firstCard.width, closeTo(236 / 104, .001));
        final amount = tester.getRect(
          find.byKey(const ValueKey('daily-login-reward-1')),
        );
        final collect = tester.getRect(
          find.byKey(const ValueKey('daily-login-collect-1')),
        );
        expect(amount.bottom, lessThanOrEqualTo(collect.top));
        expect(outsideClose.hitTestable(), findsOneWidget);
        if (size == const Size(800, 360)) {
          final firstDayCoin = find.descendant(
            of: find.byKey(const ValueKey('daily-login-coins-1')),
            matching: find.byType(Image),
          );
          final displayedHeight =
              tester.getBottomRight(firstDayCoin).dy -
              tester.getTopLeft(firstDayCoin).dy;
          expect(
            displayedHeight,
            greaterThanOrEqualTo(18),
            reason: 'Coins must remain visible in landscape phone previews',
          );
        }
        expect(
          tester.getRect(outsideClose).center.dy,
          closeTo(
            tester.getRect(dialog).top +
                appPanelCloseRect(
                  'images/ui/panels/gunluk-odul.png',
                  tester.getSize(dialog),
                ).center.dy,
            0.1,
          ),
        );
        expect(
          find.byKey(const ValueKey('daily-login-day-1')).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('daily-login-collect-1')))
              .height,
          greaterThanOrEqualTo(44),
        );
        final scrollViews = find.descendant(
          of: dialog,
          matching: find.byType(SingleChildScrollView),
        );
        expect(scrollViews, findsNothing);
        expect(find.byKey(const ValueKey('daily-days-next')), findsNothing);
        expect(find.byKey(const ValueKey('daily-days-previous')), findsNothing);
        final contentBounds = tester.getRect(
          find.byKey(const ValueKey('artwork-panel-content')),
        );
        for (var day = 1; day <= 7; day++) {
          final card = find.byKey(ValueKey('daily-login-day-$day'));
          expect(card.hitTestable(), findsOneWidget);
          final rect = tester.getRect(card);
          expect(rect.left, greaterThanOrEqualTo(contentBounds.left - .1));
          expect(rect.right, lessThanOrEqualTo(contentBounds.right + .1));
          expect(rect.top, greaterThanOrEqualTo(contentBounds.top - .1));
          expect(rect.bottom, lessThanOrEqualTo(contentBounds.bottom + .1));
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('daily-login-day-7')),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('daily-login-day-7')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'daily reward at $size');
        final panelBounds = tester.getRect(
          find.byKey(const ValueKey('artwork-panel-content')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('daily-login-collect-7')),
        );
        await tester.pump();
        final lastButton = tester.getRect(
          find.byKey(const ValueKey('daily-login-collect-visual-7')),
        );
        final frame = tester.getRect(artwork);
        expect(
          lastButton.bottom,
          lessThanOrEqualTo(frame.top + frame.height * .85),
        );
        expect(lastButton.bottom, lessThanOrEqualTo(panelBounds.bottom + .1));
        for (var day = 1; day <= 7; day++) {
          final labelBox = tester.renderObject<RenderBox>(
            find.byKey(ValueKey('daily-login-label-$day')),
          );
          final rewardBox = tester.renderObject<RenderBox>(
            find.byKey(ValueKey('daily-login-reward-$day')),
          );
          final labelCenter = labelBox.localToGlobal(
            labelBox.size.center(Offset.zero),
          );
          final rewardCenter = rewardBox.localToGlobal(
            rewardBox.size.center(Offset.zero),
          );
          expect(labelCenter.dy, lessThan(rewardCenter.dy));
          expect(labelCenter.dx, closeTo(rewardCenter.dx, .1));
          final amount = tester.getRect(
            find.byKey(ValueKey('daily-login-amount-$day')),
          );
          final firstAmount = tester.getRect(
            find.byKey(const ValueKey('daily-login-amount-1')),
          );
          if (size.width > size.height) {
            expect(amount.top, closeTo(firstAmount.top, .1));
            expect(amount.bottom, closeTo(firstAmount.bottom, .1));
          }
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('daily-login-day-1')),
        );
        await tester.pump();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('daily-login-day-1')),
      );
      await tester.tap(find.byKey(const ValueKey('daily-login-day-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final coin = find.byKey(const ValueKey('reward-coin-flight'));

      expect(coin, findsOneWidget);
      expect(find.byKey(const ValueKey('reward-xp-flight')), findsNothing);
      expect(
        (tester.getCenter(coin) -
                tester.getCenter(
                  find.byKey(const ValueKey('main-wallet-button')),
                ))
            .distance,
        lessThan(3),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(dailyLogin.canClaimToday, isFalse);
      expect(dailyLogin.displayDay, 1);
      expect(
        find.descendant(of: dialog, matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );
      expect(find.text('ALINDI'), findsOneWidget);
      expect(find.text('YARIN'), findsOneWidget);
      expect(find.text('KİLİTLİ'), findsNWidgets(5));
      final collect = tester.widget<Container>(
        find.byKey(const ValueKey('daily-login-collect-visual-1')),
      );
      expect(
        (collect.decoration as BoxDecoration).color,
        const Color(0xFF535A59),
      );
      expect(find.byKey(const ValueKey('daily-reward-badge')), findsNothing);
      expect(
        find.byKey(const ValueKey('main-notification-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('main-notification-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      final balanceAfterClaim = playerProgress.coins;
      for (var day = 1; day <= 7; day++) {
        expect(
          tester
              .widget<GestureDetector>(
                find.byKey(ValueKey('daily-login-day-$day')),
              )
              .onTap,
          isNull,
        );
      }
      await dailyLogin.load();
      expect(dailyLogin.canClaimToday, isFalse);
      expect(await dailyLogin.claim(), isNull);
      expect(playerProgress.coins, balanceAfterClaim);
      final now = DateTime.now();
      final yesterday =
          DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
              Duration.millisecondsPerDay -
          1;
      for (var day = 2; day <= 7; day++) {
        await SharedPreferencesAsync().setInt(
          'daily_login.last_claim_day',
          yesterday,
        );
        await dailyLogin.load();
        await tester.pump();
        final card = find.byKey(ValueKey('daily-login-day-$day'));
        await tester.ensureVisible(card);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.tap(card);
        await tester.pump();
        if (day == 3) {
          await tester.pump(const Duration(milliseconds: 600));
          final xp = find.byKey(const ValueKey('reward-xp-flight'));
          expect(xp, findsOneWidget);
          expect(
            (tester.getCenter(xp) -
                    tester.getCenter(
                      find.byKey(const ValueKey('home-xp-progress')),
                    ))
                .distance,
            lessThan(3),
          );
        }
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(dailyLogin.displayDay, 7);
      expect(dailyLogin.canClaimToday, isFalse);
      expect(find.text('ALINDI'), findsNWidgets(7));
      await SharedPreferencesAsync().setInt(
        'daily_login.last_claim_day',
        yesterday,
      );
      await dailyLogin.load();
      await tester.pump();
      expect(dailyLogin.displayDay, 1);
      expect(dailyLogin.canClaimToday, isTrue);
      expect(find.text('ALINDI'), findsNothing);
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(const ValueKey('daily-login-day-1')),
            )
            .onTap,
        isNotNull,
      );

      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('main-wallet-reward-animation')),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Günlük ödülün hazır'), findsOneWidget);
    },
  );

  testWidgets(
    'mark all read keeps inbox entries and clears badges without claiming rewards',
    (tester) async {
      appLanguage.value = AppLanguage.turkish;
      playerProgress.reset();
      await dailyLogin.load();
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final coins = playerProgress.coins;
      final readButton = find.byKey(const ValueKey('inbox-mark-all-read'));
      final buttonPosition = tester.getRect(readButton);
      final inboxEntries = find.text('Günlük ödülün hazır');
      expect(inboxEntries, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inbox-mark-all-read')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(inboxEntries, findsOneWidget);
      expect(find.text('Hoş geldin!'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('inbox-opacity-inbox-welcome')),
            )
            .opacity,
        .5,
      );
      await tester.drag(
        find.byKey(const ValueKey('feature-content-viewport-GELEN KUTUSU')),
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(readButton), buttonPosition);
      expect(
        find.byKey(const ValueKey('main-notification-badge')),
        findsNothing,
      );
      expect(playerProgress.coins, coins);
      expect(dailyLogin.canClaimToday, isTrue);
      await tester.tap(find.byKey(const ValueKey('popup-outside-close')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(inboxEntries, findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-mark-all-read')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('hoş geldin bildirimi yalnız gelen kutusunu kapatır ve okunur', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.turkish;
    await dailyLogin.load();
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Hoş geldin!'));
    await tester.tap(find.text('Hoş geldin!'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('PROFİLİM'), findsNothing);
    expect(find.text('GELEN KUTUSU'), findsNothing);
    expect(find.text('HEMEN OYNA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hoş geldin!'), findsOneWidget);
    expect(find.text('Lig sıralamanı kontrol et'), findsOneWidget);
  });

  testWidgets(
    'inbox supports swiping both ways and persistent clear without claiming rewards',
    (tester) async {
      appLanguage.value = AppLanguage.turkish;
      await dailyLogin.load();
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await tester.pump(const Duration(milliseconds: 600));
      final coins = playerProgress.coins;
      for (final (id, delta) in [
        ('inbox-daily', -650.0),
        ('inbox-league', 650.0),
      ]) {
        final item = find.byKey(ValueKey('inbox-dismiss-$id'));
        await tester.ensureVisible(item);
        await tester.drag(item, Offset(delta, 0));
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(item, findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Hoş geldin!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inbox-clear-all')));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Dismissible), findsNothing);
      expect(find.text('Yeni bildirimin yok.'), findsOneWidget);
      for (final key in ['inbox-mark-all-read', 'inbox-clear-all']) {
        final button = find.byKey(ValueKey(key));
        expect(button, findsOneWidget);
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.descendant(
                  of: button,
                  matching: find.byType(AnimatedOpacity),
                ),
              )
              .opacity,
          .45,
        );
        expect(
          tester
              .widget<TextButton>(
                find.descendant(of: button, matching: find.byType(TextButton)),
              )
              .onPressed,
          isNull,
        );
      }
      expect(playerProgress.coins, coins);
      expect(dailyLogin.canClaimToday, isTrue);
      await tester.tap(find.byKey(const ValueKey('popup-outside-close')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byIcon(Icons.mail_outlined));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Yeni bildirimin yok.'), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-mark-all-read')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-clear-all')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('main-notification-badge')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

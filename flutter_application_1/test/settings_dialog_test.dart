import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_language.dart';
import 'package:flutter_application_1/daily_login_rewards.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/performance_overlay.dart';

void main() {
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
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('MÜZİK'), findsNothing);
    expect(find.text('KENAR TAŞLARI'), findsNothing);
    expect(find.text('PERFORMANS'), findsNothing);
    expect(find.text('Akıcı Animasyonlar'), findsNothing);
    final settingsDialogSize = tester.getSize(
      find.byKey(const ValueKey('settings-dialog')),
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
      findsOneWidget,
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
    expect(inboxDialogSize.height, closeTo(540.0, 0.1));

    await tester.tap(find.text('Günlük ödülün hazır'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('7 GÜNLÜK GİRİŞ ÖDÜLÜ'), findsOneWidget);
    expect(find.text('GELEN KUTUSU'), findsNothing);

    await tester.tap(find.text('TAMAM').last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.byKey(const ValueKey('main-wallet-button')));
    await tester.pump();
    expect(find.text('Cüzdan yapım aşamasında.'), findsOneWidget);
    expect(find.text('CÜZDAN'), findsNothing);

    await tester.tap(find.text(defaultPlayerProfileName));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('PROFİLİM'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-name-field')), findsOneWidget);
    expect(find.text('Başlangıç · Seviye 0'), findsOneWidget);
    expect(find.text('Kazanma Oranı'), findsOneWidget);
    final profileDialog = find.byKey(const ValueKey('feature-dialog-PROFİLİM'));
    final profileDialogSize = tester.getSize(profileDialog);
    expect(profileDialogSize, settingsDialogSize);
    final profileClose = find.byKey(const ValueKey('profile-close-button'));
    expect(profileClose.hitTestable(), findsOneWidget);
    expect(tester.getSize(profileClose).width, greaterThanOrEqualTo(40));
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
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-avatar-picker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-avatar-confirm')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey('profile-avatar-picker')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Gökde',
    );
    await tester.tap(find.byKey(const ValueKey('profile-name-save')));
    await tester.pump();
    expect(playerProgress.playerName, 'Gökde');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      '123456789012345678',
    );
    await tester.pump();
    expect(find.text('18 karakter sınırına ulaştın.'), findsOneWidget);

    await tester.tap(find.text('TAMAM').last);
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Gökde'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gunluk odul karta dokununca alinir ve bildirimi kapanir', (
    tester,
  ) async {
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

    final dialog = find.byKey(
      const ValueKey('feature-dialog-GÜNLÜK GİRİŞ ÖDÜLÜ'),
    );
    expect(dialog, findsOneWidget);
    // Eski günlük giriş ölçüsü: 640 px panel + iki yanda 8 px dış boşluk.
    expect(tester.getSize(dialog), const Size(656, 360));
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('daily-login-claim')), findsNothing);
    expect(find.byKey(const ValueKey('daily-login-day-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-login-day-1')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(dailyLogin.canClaimToday, isFalse);
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

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('main-wallet-reward-animation')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Günlük ödülün hazır'), findsNothing);
  });

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
    await tester.tap(find.text('Hoş geldin!'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('PROFİLİM'), findsNothing);
    expect(find.text('GELEN KUTUSU'), findsNothing);
    expect(find.text('HEMEN OYNA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hoş geldin!'), findsNothing);
    expect(find.text('Lig sıralamanı kontrol et'), findsOneWidget);
  });
}

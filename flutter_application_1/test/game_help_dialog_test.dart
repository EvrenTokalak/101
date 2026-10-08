import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game_help_dialog.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app_language.dart';

void main() {
  testWidgets('yardım penceresi üç referans sayfasını gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GameHelpDialog())),
    );

    expect(find.text('AÇILIŞ değerine ulaşın.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.text('PER ÖRNEKLERİ'), findsOneWidget);
    expect(find.text('DOĞRU'), findsOneWidget);
    expect(find.text('YANLIŞ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.text('GENEL KURALLAR'), findsOneWidget);
    expect(
      find.textContaining('El açmayan oyuncu 202 ceza puanı alır.'),
      findsOneWidget,
    );
    for (var index = 1; index <= 10; index++) {
      expect(find.text('$index.'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ana menüdeki soru düğmesi yardımı açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.tap(find.byKey(const ValueKey('main-help-button')));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.byKey(const ValueKey('game-help-dialog')), findsOneWidget);
    expect(find.text('101 OKEY NASIL OYNANIR?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yardım penceresinin tüm sayfaları İngilizce gösterilir', (
    tester,
  ) async {
    appLanguage.value = AppLanguage.english;
    addTearDown(() => appLanguage.value = AppLanguage.turkish);
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GameHelpDialog())),
    );

    expect(find.text('HOW TO PLAY 101 OKEY?'), findsOneWidget);
    expect(find.text('Reach the opening requirement.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.text('MELD EXAMPLES'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('help-next')));
    await tester.pumpAndSettle();
    expect(find.text('GENERAL RULES'), findsOneWidget);
    expect(
      find.text('The player with the lowest score wins the game.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  testWidgets('oyun sonu butonlari dar ekranda gorunur ve calisir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var newRoundPressed = false;
    var resetPressed = false;
    var homePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 520),
            textScaler: TextScaler.linear(1.25),
          ),
          child: Scaffold(
            body: GameEndDialog(
              winner: 'Sen',
              playerPen: 0,
              bots: [
                BotPlayer(name: 'Oyuncu 2'),
                BotPlayer(name: 'Oyuncu 3'),
                BotPlayer(name: 'Oyuncu 4'),
              ],
              botPens: const [202, 35, 48],
              elCount: 2,
              totalPenalty: 17,
              onNewRound: () => newRoundPressed = true,
              onResetMatch: () => resetPressed = true,
              onHome: () => homePressed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('YENİ TUR'), findsOneWidget);
    expect(find.text('SKORU SIFIRLA'), findsOneWidget);
    expect(find.text('ANA SAYFA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('YENİ TUR'));
    await tester.tap(find.text('SKORU SIFIRLA'));
    await tester.tap(find.text('ANA SAYFA'));

    expect(newRoundPressed, isTrue);
    expect(resetPressed, isTrue);
    expect(homePressed, isTrue);
  });
}

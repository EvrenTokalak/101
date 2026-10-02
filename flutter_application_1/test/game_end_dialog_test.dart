import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/player_progress.dart';

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
              playerName: 'Gökde',
              playerPen: 0,
              bots: [
                BotPlayer(name: 'Oyuncu 2', displayName: 'Mert'),
                BotPlayer(name: 'Oyuncu 3', displayName: 'Selin'),
                BotPlayer(name: 'Oyuncu 4', displayName: 'Emre'),
              ],
              botPens: const [202, 35, 48],
              elCount: 2,
              totalPenalty: 17,
              reward: const GameReward(
                xp: 95,
                coins: 300,
                levelsGained: 1,
                xpBreakdown: ['Oyun tamamlama +30 XP'],
              ),
              onNewRound: () => newRoundPressed = true,
              onResetMatch: () => resetPressed = true,
              onHome: () => homePressed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('DEVAM ET'), findsOneWidget);
    expect(find.text('TUR BİTTİ'), findsNothing);
    expect(
      find.byKey(const ValueKey('end-screen-header-artwork-slot')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('end-screen-winner-card')), findsNothing);
    expect(find.text('KAZANAN'), findsNothing);
    expect(find.text('2 TUR'), findsOneWidget);
    expect(find.text('YENİDEN BAŞLAT'), findsOneWidget);
    expect(find.text('ANA SAYFA'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-reward-card')), findsOneWidget);
    expect(find.text('+95 XP'), findsOneWidget);
    final playerNameText = tester.widget<Text>(find.text('Gökde').last);
    expect(playerNameText.style?.color, OC.gold);
    expect(playerNameText.style?.fontWeight, FontWeight.w900);
    expect(playerNameText.style?.fontSize, 18);
    expect(find.text('Oyuncu 2'), findsNothing);
    final playerRowTop = tester
        .getTopLeft(find.byKey(ValueKey('score-row-${playerNameText.data}')))
        .dy;
    final selinRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('score-row-Selin')))
        .dy;
    final emreRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('score-row-Emre')))
        .dy;
    final mertRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('score-row-Mert')))
        .dy;
    expect(playerRowTop, lessThan(selinRowTop));
    expect(selinRowTop, lessThan(emreRowTop));
    expect(emreRowTop, lessThan(mertRowTop));
    expect(
      tester.getCenter(find.text('YENİDEN BAŞLAT')).dx,
      lessThan(tester.getCenter(find.text('ANA SAYFA')).dx),
    );
    expect(
      tester.getCenter(find.text('DEVAM ET')).dx,
      greaterThan(tester.getCenter(find.text('ANA SAYFA')).dx),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('DEVAM ET'));
    await tester.tap(find.text('YENİDEN BAŞLAT'));
    await tester.tap(find.text('ANA SAYFA'));

    expect(newRoundPressed, isTrue);
    expect(resetPressed, isTrue);
    expect(homePressed, isTrue);
  });
}

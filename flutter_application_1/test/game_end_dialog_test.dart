import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/daily_league.dart';
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
              leagueUpdate: Future.value(
                const LeagueRoundUpdate(
                  roundId: 'result-test',
                  rank: 4,
                  previousRank: 6,
                ),
              ),
              onNewRound: () => newRoundPressed = true,
              onResetMatch: () => resetPressed = true,
              onHome: () => homePressed = true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byKey(const ValueKey('game-end-league-cell')), findsOneWidget);
    expect(find.text('4/20 LİG'), findsOneWidget);
    expect(find.text('2 sıra yükseldin'), findsOneWidget);
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
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    final rankOne = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('score-row-Gökde')),
        matching: find.text('1'),
      ),
    );
    expect(rankOne.style?.color, const Color(0xFF33200A));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
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
  for (final size in const [Size(568, 320), Size(1024, 768)]) {
    testWidgets(
      'restored result stays on screen without another animation at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var continued = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameEndDialog(
                winner: 'Sen',
                playerPen: -101,
                bots: [
                  BotPlayer(name: 'B'),
                  BotPlayer(name: 'C'),
                  BotPlayer(name: 'D'),
                ],
                botPens: const [202, 40, 20],
                elCount: 1,
                totalPenalty: -101,
                onNewRound: () => continued = true,
                onResetMatch: () {},
                onHome: () {},
              ),
            ),
          ),
        );
        final panel = tester.getRect(
          find.byKey(const ValueKey('game-end-panel')),
        );
        expect(panel.width, lessThanOrEqualTo(size.width - 24));
        expect(panel.height, lessThanOrEqualTo(size.height - 20));
        expect(
          find.byKey(const ValueKey('round-end-tile-accent')),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 180));
        await tester.tap(find.text('DEVAM ET'));
        expect(continued, isTrue);
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byKey(const ValueKey('round-end-tile-accent')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

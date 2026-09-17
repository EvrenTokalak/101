import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  late PlayerProgressController progress;

  setUp(() {
    progress = PlayerProgressController();
    progress.reset(level: 9);
  });

  test('yeni oyuncu seviye 0 ile başlar', () {
    final freshProgress = PlayerProgressController();

    expect(freshProgress.level, 0);
    expect(freshProgress.title, 'Beginner');
    expect(freshProgress.xpForNextLevel, 30);
  });

  test('görseldeki seviye bantları doğru unvan ve XP eşiğini verir', () {
    expect(progress.title, 'Learner');
    expect(progress.xpForNextLevel, 50);

    progress.reset(level: 50);
    expect(progress.title, 'Pro');
    expect(progress.xpForNextLevel, 100);

    progress.reset(level: 95);
    expect(progress.title, 'Grandmaster');
    expect(progress.xpForNextLevel, 150);
  });

  test('Hemen Oyna sonuçtan bağımsız sabit XP verir', () {
    final reward = progress.recordCompletedGame(
      config: const GameLaunchConfig.quickPlay(),
      won: true,
      openedHand: true,
      finishedHand: true,
    );

    expect(reward.xp, 30);
    expect(reward.xpBreakdown, hasLength(1));
    expect(reward.coins, 150);
    expect(progress.level, 9);
    expect(progress.levelXp, 30);
  });

  test('Katlamalı mod başarı bonuslarını ve seviye atlamayı uygular', () {
    final reward = progress.recordCompletedGame(
      config: const GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      ),
      won: true,
      openedHand: true,
      finishedHand: true,
    );

    expect(reward.xp, 95);
    expect(reward.coins, 300);
    expect(reward.levelsGained, 1);
    expect(progress.level, 10);
    expect(progress.levelXp, 45);
  });

  test('oda ücreti harcanır, yetersiz bakiye reddedilir ve ödül eklenir', () {
    progress.reset(coins: 1000, level: 9);
    expect(progress.trySpendCoins(500), isTrue);
    expect(progress.coins, 500);
    expect(progress.trySpendCoins(1000), isFalse);

    final reward = progress.recordCompletedGame(
      config: const GameLaunchConfig.room(
        id: 'room-0',
        label: 'Başlangıç',
        entryFee: 500,
      ),
      won: true,
      openedHand: false,
      finishedHand: true,
    );

    expect(reward.coins, 2000);
    expect(progress.coins, 2500);
  });
}

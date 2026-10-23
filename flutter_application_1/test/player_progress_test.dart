import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  test('highest opening keeps the record across reloads', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.clear();
    final controller = PlayerProgressController();
    await controller.load();
    controller.recordOpening(156);
    controller.recordOpening(112);
    expect(controller.highestOpening, 156);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final reopened = PlayerProgressController();
    await reopened.load();
    expect(reopened.highestOpening, 156);
    reopened.recordOpening(202);
    expect(reopened.highestOpening, 202);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await preferences.clear();
  });
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
    expect(freshProgress.coins, 25600);
  });
  test(
    'legacy avatar indices preserve surviving images and replace deleted ones',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.clear();
      await preferences.setInt('profile.avatar_index', 27);
      await progress.load();
      expect(
        progress.playerAvatarAsset,
        'görseller/pp/mm_av3_yaban_domuzu.png',
      );
      expect(progress.playerAvatarIndex, 23);
      await preferences.clear();
      await preferences.setInt('profile.avatar_index', 26);
      final reopened = PlayerProgressController();
      await reopened.load();
      expect(reopened.playerAvatarAsset, playerAvatarAssets.first);
    },
  );
  test('avatar file identity takes priority over old list position', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.clear();
    await preferences.setInt('profile.avatar_index', 0);
    await preferences.setString(
      'profile.avatar_asset',
      'görseller/pp/mm_av1_boga.png',
    );
    await progress.load();
    expect(progress.playerAvatarIndex, 21);
    await preferences.setString(
      'profile.avatar_asset',
      'görseller/pp/deleted.png',
    );
    final reopened = PlayerProgressController();
    await reopened.load();
    expect(reopened.playerAvatarAsset, playerAvatarAssets.first);
  });

  test('profil adı düzenlenir ve geçersiz değerler reddedilir', () {
    expect(progress.playerName, defaultPlayerProfileName);
    expect(progress.updatePlayerName('  Gökde  '), isTrue);
    expect(progress.playerName, 'Gökde');
    expect(progress.updatePlayerName('   '), isFalse);
    expect(progress.playerName, 'Gökde');
  });

  test('seviye yükseldikçe XP eşikleri kademeli büyür', () {
    expect(progress.title, 'Learner');
    expect(progress.xpForNextLevel, 75);

    progress.reset(level: 2);
    expect(progress.xpForNextLevel, 30);
    progress.reset(level: 3);
    expect(progress.xpForNextLevel, 30);
    progress.reset(level: 4);
    expect(progress.xpForNextLevel, 50);
    progress.reset(level: 7);
    expect(progress.xpForNextLevel, 50);
    progress.reset(level: 8);
    expect(progress.xpForNextLevel, 75);

    progress.reset(level: 50);
    expect(progress.title, 'Pro');
    expect(progress.xpForNextLevel, 220);

    progress.reset(level: 95);
    expect(progress.title, 'Grandmaster');
    expect(progress.xpForNextLevel, 450);
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
    expect(progress.levelXp, 20);
  });

  test('sonraki turlarda Excel dışı ek XP ve altın verilmez', () {
    final reward = progress.recordCompletedGame(
      config: const GameLaunchConfig.gameMode(
        mode: OkeyGameMode.classic101,
        id: 'classic-101',
        label: 'Klasik 101',
      ),
      won: true,
      openedHand: false,
      finishedHand: false,
      roundNumber: 3,
    );

    expect(reward.xp, 60);
    expect(reward.coins, 300);
    expect(reward.xpBreakdown, isNot(contains('Tur galibiyeti +20 XP')));
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
      roundNumber: 3,
      roomMatchWon: true,
    );

    expect(reward.coins, 1000);
    expect(progress.coins, 1500);
  });

  test('oda ara el galibiyeti para ödemez, masa kaybında yatırım kalır', () {
    progress.reset(coins: 4000);
    const room = GameLaunchConfig.room(
      id: 'room-0',
      label: 'Başlangıç',
      entryFee: 2000,
    );
    expect(progress.trySpendCoins(2000), isTrue);
    for (final matchWon in <bool?>[null, false]) {
      final reward = progress.recordCompletedGame(
        config: room,
        won: true,
        openedHand: true,
        finishedHand: true,
        roomMatchWon: matchWon,
      );
      expect(reward.coins, 0);
      expect(progress.coins, 2000);
    }
  });

  test('oda toplam galibiyeti son el kaybedilse de yatırımı iki kat öder', () {
    progress.reset(coins: 4000);
    expect(progress.trySpendCoins(2000), isTrue);
    final reward = progress.recordCompletedGame(
      config: const GameLaunchConfig.room(
        id: 'room-0',
        label: 'Başlangıç',
        entryFee: 2000,
      ),
      won: false,
      openedHand: true,
      finishedHand: false,
      roundNumber: 3,
      roomMatchWon: true,
    );
    expect(reward.coins, 4000);
    expect(progress.coins, 6000);
  });
}

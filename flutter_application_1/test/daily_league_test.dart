import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/daily_league.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/league_simulation.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  late DateTime now;
  late PlayerProgressController wallet;
  late DailyLeagueController league;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 9, 16);
    wallet = PlayerProgressController();
    await wallet.load();
    league = DailyLeagueController(now: () => now, wallet: wallet);
    await league.load();
  });
  Future<bool> round(int number, {
    GameLaunchConfig config = const GameLaunchConfig.quickPlay(),
    List<int> table = const [-101, 202, 45, 88],
    List<int>? simulated,
  }) => league.recordRound(config: config, roundId: 'round-$number',
    tablePenalties: table, simulatedPenalties: simulated ?? List.filled(16, 100));

  test('first opening starts saved 24 hours, not midnight', () async {
    expect(league.deadline, now.add(const Duration(hours: 24)));
    now = now.add(const Duration(hours: 5));
    final reopened = DailyLeagueController(now: () => now, wallet: wallet);
    await reopened.load();
    expect(reopened.deadline, league.deadline);
    expect(reopened.remaining, const Duration(hours: 19));
    expect(reopened.standings.length, 20);
    expect(reopened.completedRounds, 0);
  });
  test('initial deadline follows the mission clock', () async {
    final end = now.add(const Duration(hours: 7));
    SharedPreferences.setMockInitialValues({
      'tasks.deadline_ms': end.millisecondsSinceEpoch,
    });
    final aligned = DailyLeagueController(now: () => now, wallet: wallet);
    await aligned.load();
    expect(aligned.deadline, end);
  });
  test('one round advances all 20; duplicate and idle time do not', () async {
    expect(await round(1), isTrue);
    expect(await round(1), isFalse);
    expect(league.completedRounds, 1);
    final scores = {for (final e in league.standings) e.id: e.penalty};
    expect(scores[0], -101);
    expect(scores[1], 202);
    expect(scores[2], 45);
    expect(scores[3], 88);
    for (var i = 4; i < 20; i++) { expect(scores[i], 100); }
    final before = league.standings.map((e) => e.penalty).toList();
    now = now.add(const Duration(hours: 3));
    league.refresh();
    expect(league.standings.map((e) => e.penalty), before);
    final reopened = DailyLeagueController(now: () => now, wallet: wallet);
    await reopened.load();
    expect(reopened.completedRounds, 1);
    expect(reopened.standings.map((e) => e.penalty), before);
  });
  test('only Quick Play contributes, never rooms or fun modes', () async {
    for (final mode in OkeyGameMode.values) {
      expect(await round(1, config: GameLaunchConfig.gameMode(
        mode: mode, id: mode.name, label: mode.name)), isFalse);
    }
    expect(await round(1, config: const GameLaunchConfig.tutorial()), isFalse);
    expect(await round(1, config: const GameLaunchConfig.room(
      id: 'room', label: 'room', entryFee: 500)), isFalse);
    expect(league.completedRounds, 0);
  });
  test('20 rounds freeze results and award exactly once across reloads', () async {
    final initial = wallet.coins;
    for (var i = 1; i <= 19; i++) { await round(i); }
    expect(wallet.coins, initial);
    await round(20);
    expect(league.finalRank, 1);
    expect(wallet.coins, initial + 3000);
    expect(wallet.leagueStars, 3);
    final totals = league.standings.map((e) => e.penalty).toList();
    expect(await round(21), isFalse);
    expect(league.standings.map((e) => e.penalty), totals);
    final reloadedWallet = PlayerProgressController();
    await reloadedWallet.load();
    final reopened = DailyLeagueController(now: () => now, wallet: reloadedWallet);
    await reopened.load();
    expect(reloadedWallet.coins, initial + 3000);
    expect(reloadedWallet.leagueStars, 3);
    expect(reopened.complete, isTrue);
  });
  for (final rank in [1, 2, 3, 4]) {
    test('ties share rank $rank and its reward', () async {
      final initial = wallet.coins;
      final scores = List.filled(20, 100)..[0] = 50..[4] = 50;
      for (var i = 1; i < rank; i++) { scores[i] = 20; }
      for (var n = 1; n <= 20; n++) {
        await round(n, table: scores.take(4).toList(),
          simulated: scores.skip(4).toList());
      }
      expect(league.playerRank, rank);
      expect(league.standings.firstWhere((e) => e.id == 4).rank, rank);
      final prize = LeaguePrize.forRank(rank);
      expect(wallet.coins, initial + prize.coins);
      expect(wallet.leagueStars, prize.stars);
    });
  }
  test('expiry resets unfinished scores without awarding anything', () async {
    await round(1);
    final initial = wallet.coins;
    final oldDeadline = league.deadline!;
    now = oldDeadline.add(const Duration(hours: 49));
    league.refresh();
    expect(league.completedRounds, 0);
    expect(league.standings.every((e) => e.penalty == 0), isTrue);
    expect(league.deadline, oldDeadline.add(const Duration(hours: 72)));
    expect(wallet.coins, initial);
    expect(wallet.leagueStars, 0);
    expect(await round(2), isTrue);
    expect(league.completedRounds, 1);
  });
  test('rewards survive cycle reset; tiers use lifetime stars', () async {
    for (var cycle = 0; cycle < 2; cycle++) {
      for (var i = 1; i <= 20; i++) { await round(cycle * 20 + i); }
      now = league.deadline!;
      league.refresh();
    }
    expect(wallet.leagueStars, 6);
    expect(league.tier, 'Amateur');
    expect(league.completedRounds, 0);
    expect(league.nextTierStars, 15);
  });
  test('saved final result recovers reward missing from wallet', () async {
    final deadline = now.add(const Duration(hours: 24));
    await SharedPreferencesAsync().setString(DailyLeagueController.storageKey,
      jsonEncode({
        'deadline': deadline.millisecondsSinceEpoch,
        'totals': [-2020, ...List.filled(19, 2000)],
        'roundIds': List.generate(20, (i) => 'saved-$i'),
        'finalRank': 1,
      }));
    final reopened = DailyLeagueController(now: () => now, wallet: wallet);
    await reopened.load();
    expect(wallet.coins, initialPlayerCoins + 3000);
    expect(wallet.leagueStars, 3);
  });
  test('virtual tables are deterministic with existing penalty values', () {
    final scores = simulateLeaguePenalties(seed: 2026, noWinner: false);
    expect(scores, simulateLeaguePenalties(seed: 2026, noWinner: false));
    expect(scores.length, 16);
    for (var table = 0; table < 4; table++) {
      final group = scores.skip(table * 4).take(4);
      expect(group.where((score) => score == -101).length, 1);
      expect(group.every((score) => score >= -101 && score <= 546), isTrue);
    }
    expect(simulateLeaguePenalties(seed: 7, noWinner: true)
      .every((score) => score >= 0), isTrue);
  });
}

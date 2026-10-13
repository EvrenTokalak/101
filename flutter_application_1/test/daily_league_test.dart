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
    await SharedPreferencesAsync().clear();
    now = DateTime(2026, 10, 9, 16);
    wallet = PlayerProgressController();
    await wallet.load();
    league = DailyLeagueController(now: () => now, wallet: wallet);
    await league.load();
  });
  Future<bool> round(
    int number, {
    GameLaunchConfig config = const GameLaunchConfig.quickPlay(),
    List<int> table = const [-101, 202, 45, 88],
    List<int>? simulated,
  }) => league.recordRound(
    config: config,
    roundId: 'round-$number',
    tablePenalties: table,
    simulatedPenalties: simulated ?? List.filled(16, 100),
  );

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
  test(
    'rank notice is available once per three hands and survives reopening',
    () async {
      expect(league.takeRankNotice(), isNull);
      for (var n = 1; n <= 3; n++) {
        await round(n);
        if (n < 3) expect(league.takeRankNotice(), isNull);
      }
      final notice = league.takeRankNotice()!;
      expect(notice.completedRounds, 3);
      expect(notice.rank, league.playerRank);
      expect(league.takeRankNotice(), isNull);
      await round(4);
      final reopened = DailyLeagueController(now: () => now, wallet: wallet);
      await reopened.load();
      expect(reopened.takeRankNotice(), isNull);
      await round(5);
      await round(6);
      expect(league.takeRankNotice()!.completedRounds, 6);
      now = league.deadline!;
      league.refresh();
      for (var n = 1; n <= 3; n++) {
        await round(n);
      }
      expect(league.takeRankNotice()!.completedRounds, 3);
    },
  );
  test('initial deadline follows the mission clock', () async {
    final end = now.add(const Duration(hours: 7));
    await SharedPreferencesAsync().clear();
    await SharedPreferencesAsync().setInt(
      'tasks.deadline_ms',
      end.millisecondsSinceEpoch,
    );
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
    for (var i = 4; i < 20; i++) {
      expect(scores[i], 100);
    }
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
      expect(
        await round(
          1,
          config: GameLaunchConfig.gameMode(
            mode: mode,
            id: mode.name,
            label: mode.name,
          ),
        ),
        isFalse,
      );
    }
    expect(await round(1, config: const GameLaunchConfig.tutorial()), isFalse);
    expect(
      await round(
        1,
        config: const GameLaunchConfig.room(
          id: 'room',
          label: 'room',
          entryFee: 500,
        ),
      ),
      isFalse,
    );
    expect(league.completedRounds, 0);
  });
  test(
    '20 rounds freeze results and award exactly once across reloads',
    () async {
      final initial = wallet.coins;
      for (var i = 1; i <= 19; i++) {
        await round(i);
      }
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
      final reopened = DailyLeagueController(
        now: () => now,
        wallet: reloadedWallet,
      );
      await reopened.load();
      expect(reloadedWallet.coins, initial + 3000);
      expect(reloadedWallet.leagueStars, 3);
      expect(reopened.complete, isTrue);
    },
  );
  for (final rank in [1, 2, 3, 4]) {
    test('ties share rank $rank and its reward', () async {
      final initial = wallet.coins;
      final scores = List.filled(20, 100)
        ..[0] = 50
        ..[4] = 50;
      for (var i = 1; i < rank; i++) {
        scores[i] = 20;
      }
      for (var n = 1; n <= 20; n++) {
        await round(
          n,
          table: scores.take(4).toList(),
          simulated: scores.skip(4).toList(),
        );
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
      for (var i = 1; i <= 20; i++) {
        await round(cycle * 20 + i);
      }
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
    await SharedPreferencesAsync().setString(
      DailyLeagueController.storageKey,
      jsonEncode({
        'deadline': deadline.millisecondsSinceEpoch,
        'totals': [-2020, ...List.filled(19, 2000)],
        'roundIds': List.generate(20, (i) => 'saved-$i'),
        'finalRank': 1,
      }),
    );
    final reopened = DailyLeagueController(now: () => now, wallet: wallet);
    await reopened.load();
    expect(wallet.coins, initialPlayerCoins + 3000);
    expect(wallet.leagueStars, 3);
  });
  test('four bot tables play actual deterministic rounds', () {
    final tables = simulateLeagueTables(seed: 2026);
    final repeated = simulateLeagueTables(seed: 2026);
    expect(tables.length, 4);
    expect(
      tables.expand((t) => t.penalties),
      repeated.expand((t) => t.penalties),
    );
    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      expect(table.tableIndex, i);
      expect(table.turnsPlayed, greaterThan(0));
      expect(table.penalties.length, 4);
      expect(
        table.penalties.where((p) => p == -101).length,
        table.winnerSeat == null ? 0 : 1,
      );
      if (table.winnerSeat == null) expect(table.deckExhausted, isTrue);
      expect(table.penalties.every((p) => p >= -101 && p <= 546), isTrue);
    }
    expect(tables.fold<int>(0, (n, t) => n + t.openedMelds), greaterThan(0));
  });
  test(
    'tables rotate every three completed hands without duplicate rivals',
    () {
      for (var n = 0; n < 20; n++) {
        final seating = LeagueSeating.forRound(n);
        expect(
          seating.participantIds.toSet(),
          Set.of(List.generate(20, (i) => i)),
        );
        expect(seating.table(0).first, 0);
        if (n % 3 != 0) {
          expect(
            seating.participantIds,
            LeagueSeating.forRound(n - 1).participantIds,
          );
        } else if (n > 0) {
          expect(
            seating
                .table(0)
                .skip(1)
                .toSet()
                .intersection(
                  LeagueSeating.forRound(n - 1).table(0).skip(1).toSet(),
                ),
            isEmpty,
          );
        }
      }
    },
  );
  test(
    'rotated table scores follow rival identities through save and reload',
    () async {
      final seating = LeagueSeating.forRound(3);
      await league.recordRound(
        config: const GameLaunchConfig.quickPlay(),
        roundId: 'rotated',
        tablePenalties: [80, -101, 40, 50],
        simulatedPenalties: List.filled(16, 202),
        participantIds: seating.participantIds,
      );
      expect(league.standings.first.id, seating.table(0)[1]);
      expect(league.standings.first.penalty, -101);
      expect(league.standings.firstWhere((e) => e.id == 1).penalty, 202);
      final reopened = DailyLeagueController(now: () => now, wallet: wallet);
      await reopened.load();
      expect(
        reopened.standings.map((e) => (e.id, e.penalty)),
        league.standings.map((e) => (e.id, e.penalty)),
      );
    },
  );
  test(
    'rotated native and cooperative games use the same 16 rival scores',
    () async {
      final seating = LeagueSeating.forRound(6);
      final scores = simulateLeagueTables(
        seed: 91,
        seating: seating,
      ).expand((table) => table.penalties).toList();
      expect(await playLeagueTables(seed: 91, seating: seating), scores);
      expect(
        await playLeagueTables(seed: 91, seating: seating, useIsolate: false),
        scores,
      );
    },
  );
  test(
    'round report captures rank before and after the completed hand',
    () async {
      await round(1, table: [100, 20, 30, 40], simulated: List.filled(16, 200));
      expect(league.lastRoundUpdate!.previousRank, isNull);
      expect(league.lastRoundUpdate!.rank, 4);
      await round(
        2,
        table: [-101, 202, 202, 202],
        simulated: List.filled(16, 202),
      );
      expect(league.lastRoundUpdate!.previousRank, 4);
      expect(league.lastRoundUpdate!.rank, 1);
      expect(league.lastRoundUpdate!.placesGained, 3);
    },
  );
  test(
    'a full league has competing real winners and can outrank the player',
    () async {
      var wins = 0;
      final winners = <int>{};
      final ranks = <int>{};
      for (var n = 0; n < 20; n++) {
        final tables = simulateLeagueTables(seed: 5000 + n);
        for (final table in tables) {
          if (table.winnerSeat != null) {
            wins++;
            winners.add(table.tableIndex * 4 + table.winnerSeat!);
          }
        }
        await round(
          n + 1,
          table: [60, 202, 80, 110],
          simulated: tables.expand((table) => table.penalties).toList(),
        );
        ranks.add(league.playerRank);
      }
      // Early legal opening must produce finishes, rather than mostly 202 penalties.
      expect(wins, greaterThanOrEqualTo(24));
      expect(winners.length, greaterThanOrEqualTo(6));
      expect(ranks.length, greaterThan(1));
      expect(league.playerRank, greaterThan(1));
      expect(league.completedRounds, 20);
    },
  );
  test('a virtual table owns 4 bot hands and stops at its actual outcome', () {
    final table = LeagueVirtualTable(tableIndex: 2, seed: 37);
    expect(table.bots.map((b) => b.hand.length).reduce((a, b) => a + b), 85);
    expect(table.remainingDeck, 20);
    expect(table.finished, isFalse);
    table.step();
    expect(table.bots.fold<int>(0, (n, b) => n + b.turnsPlayed), 1);
    var moves = 1;
    while (!table.finished && moves < 500) {
      table.step();
      moves++;
    }
    expect(table.finished, isTrue);
    final result = table.result;
    table.step();
    expect(table.result.penalties, result.penalties);
    expect(table.result.turnsPlayed, result.turnsPlayed);
  });
  test(
    'background tables return the same 16 scores as their real games',
    () async {
      final expected = simulateLeagueTables(seed: 77)
          .expand((t) => t.penalties)
          .toList();
      expect(await playLeagueTables(seed: 77), expected);
      expect(await playLeagueTables(seed: 77, useIsolate: false), expected);
      var paused = true;
      var finishedWhilePaused = false;
      final pausedGame =
          playLeagueTables(
            seed: 77,
            useIsolate: false,
            shouldPause: () => paused,
          ).then((scores) {
            finishedWhilePaused = true;
            return scores;
          });
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(finishedWhilePaused, isFalse);
      paused = false;
      expect(await pausedGame, expected);
      var active = true;
      final cancelledGame = playLeagueTables(
        seed: 77,
        useIsolate: false,
        shouldPause: () => true,
        isActive: () => active,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active = false;
      expect(await cancelledGame, isEmpty);
      expect(await playLeagueTables(seed: 77, isActive: () => false), isEmpty);
    },
  );
}

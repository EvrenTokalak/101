import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/game.dart';
import 'package:flutter_application_1/league_simulation.dart';

void main() {
  test(
    '60 consecutive bot tables finish with legal melds and unique held tiles',
    () {
      final clock = Stopwatch()..start();
      final steps = <int>[];
      final rss = <int>[];
      var turns = 0;
      for (var round = 0; round < 60; round++) {
        final table = LeagueVirtualTable(
          tableIndex: round % 4,
          seed: 9000 + round,
        );
        var moves = 0;
        while (!table.finished && moves < 500) {
          final stepClock = Stopwatch()..start();
          table.step();
          steps.add(stepClock.elapsedMicroseconds);
          turns++;
          moves++;
          final held = [
            for (final bot in table.bots) ...bot.hand,
            for (final meld in table.melds) ...meld.tiles,
          ];
          expect(
            held.map((tile) => tile.id).toSet().length,
            held.length,
            reason:
                'A tile must not exist in two hands or melds, round $round.',
          );
          for (final meld in table.melds) {
            expect(
              meld.type == 'cift'
                  ? Rules.isValidPair(meld.tiles)
                  : Rules.meldType(meld.tiles) != null,
              isTrue,
            );
          }
        }
        expect(table.finished, isTrue, reason: 'Round $round must terminate.');
        expect(table.result.penalties.length, 4);
        expect(
          table.result.winnerSeat != null || table.result.deckExhausted,
          isTrue,
        );
        rss.add(ProcessInfo.currentRss);
      }
      steps.sort();
      final report = {
        'environment': 'Flutter test runner on Windows; bot engine only, not Android or GPU rendering',
        'tables': 60,
        'turns': turns,
        'elapsed_ms': clock.elapsedMilliseconds,
        'turn_p95_ms': steps[(steps.length * .95).ceil() - 1] / 1000,
        'turn_max_ms': steps.last / 1000,
        'runner_rss_first_mb': rss.first / (1024 * 1024),
        'runner_rss_last_mb': rss.last / (1024 * 1024),
        'runner_rss_peak_mb': rss.reduce(math.max) / (1024 * 1024),
      };
      final output = File('.codex-build/game-soak-report.json');
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(report),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

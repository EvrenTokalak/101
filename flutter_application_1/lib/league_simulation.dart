import 'dart:math';

import 'game.dart';

/// Four virtual tables finish once for each completed real table round.
/// Scores use the existing penalty rules; there are no league-only bonuses.
List<int> simulateLeaguePenalties({required int seed, required bool noWinner}) {
  final random = Random(seed);
  final penalties = <int>[];
  for (var table = 0; table < 4; table++) {
    final deck = buildDeck()..shuffle(random);
    final indicator = deck.firstWhere((tile) => !tile.isFakeOkey);
    deck.remove(indicator);
    Rules.applyIndicator(deck, indicator);
    final winner = noWinner ? -1 : random.nextInt(4);
    for (var seat = 0; seat < 4; seat++) {
      if (seat == winner) {
        penalties.add(-101);
        continue;
      }
      final opened = random.nextDouble() < .65;
      final pairOpened = opened && random.nextDouble() < .18;
      final remainingCount = opened ? 2 + random.nextInt(12) : 21;
      final hand = deck.take(remainingCount).toList();
      deck.removeRange(0, remainingCount);
      penalties.add(
        Rules.roundPenaltyFor(
          hand,
          fakeOkeyValue: Rules.okeyNumberForIndicator(indicator.number),
          hasOpened: opened,
          openedWithPairs: pairOpened,
        ),
      );
    }
  }
  return penalties;
}

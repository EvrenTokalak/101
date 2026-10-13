import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'daily_league.dart';
import 'game.dart';

class LeagueRoundTables {
  LeagueRoundTables({LeagueSeating? seating})
    : _seating = seating ?? LeagueSeating.forRound(0);
  final LeagueSeating? _seating;
  LeagueSeating get seating => _seating ?? LeagueSeating.forRound(0);
  bool humanCompleted = false;
  late final Future<List<int>> scores;
}

/// Stable rival styles, independent of the seat or the player's ranking.
class LeagueBotStyle {
  final BotDifficulty difficulty;
  final BotPersonality personality;
  final int openingTurn;
  const LeagueBotStyle(this.difficulty, this.personality, this.openingTurn);

  static LeagueBotStyle forRival(int index) => const [
    LeagueBotStyle(BotDifficulty.hard, BotPersonality.aggressive, 1),
    LeagueBotStyle(BotDifficulty.hard, BotPersonality.cautious, 1),
    LeagueBotStyle(BotDifficulty.medium, BotPersonality.pairFocused, 1),
    LeagueBotStyle(BotDifficulty.hard, BotPersonality.aggressive, 1),
    LeagueBotStyle(BotDifficulty.medium, BotPersonality.cautious, 2),
    LeagueBotStyle(BotDifficulty.hard, BotPersonality.pairFocused, 1),
  ][index % 6];
}

class LeagueTableResult {
  final int tableIndex;
  final List<int> penalties;
  final int? winnerSeat;
  final int turnsPlayed;
  final int openedMelds;
  final int processedTiles;
  final bool deckExhausted;
  const LeagueTableResult({
    required this.tableIndex,
    required this.penalties,
    required this.winnerSeat,
    required this.turnsPlayed,
    required this.openedMelds,
    required this.processedTiles,
    required this.deckExhausted,
  });
}

/// One independent four-bot table, with its own deck, indicator and meld area.
class LeagueVirtualTable {
  LeagueVirtualTable({
    required this.tableIndex,
    required int seed,
    List<int>? participantIds,
  }) : participantIds = List.unmodifiable(
         participantIds ?? LeagueSeating.forRound(0).table(tableIndex + 1),
       ),
       _random = Random(seed) {
    _deck = buildDeck()
      ..sort((a, b) => a.id.compareTo(b.id))
      ..shuffle(_random);
    final indicator = _deck.firstWhere((tile) => !tile.isFakeOkey);
    _deck.remove(indicator);
    _okeyNumber = Rules.okeyNumberForIndicator(indicator.number);
    Rules.applyIndicator(_deck, indicator);
    bots = [
      for (var seat = 0; seat < 4; seat++)
        BotPlayer(
          name: leagueBotNames[this.participantIds[seat] - 1],
          difficulty: LeagueBotStyle.forRival(this.participantIds[seat] - 1)
              .difficulty,
          personality: LeagueBotStyle.forRival(this.participantIds[seat] - 1)
              .personality,
          hand: _deck.sublist(seat * 21, (seat + 1) * 21),
        ),
    ];
    _deck.removeRange(0, 84);
    _turn = _random.nextInt(4);
    bots[_turn].hand.add(_deck.removeLast());
    bots[_turn].tileCount = 22;
  }

  final int tableIndex;
  final Random _random;
  final List<int> participantIds;
  late List<Tile> _deck;
  late final List<BotPlayer> bots;
  final List<Meld> melds = [];
  late final int _okeyNumber;
  late int _turn;
  Tile? _discarded;
  bool _firstTurn = true;
  bool _finished = false;
  int? _winner;
  int _turnCount = 0;
  int _openedMelds = 0;
  int _processedTiles = 0;

  bool get finished => _finished;
  int get remainingDeck => _deck.length;

  /// Advance exactly one actual AI turn; no penalty or winner is sampled.
  void step() {
    if (_finished) return;
    final bot = bots[_turn];
    final style = LeagueBotStyle.forRival(participantIds[_turn] - 1);
    final canOpen = bot.turnsPlayed + 1 >= style.openingTurn;
    const minStandard = 101;
    const minPairs = 5;
    if (!_firstTurn) {
      final discarded = _discarded;
      final takesDiscard =
          discarded != null &&
          BotEngine.wantsDiscard(
            bot,
            discarded,
            melds,
            allowOpening: canOpen,
            minimumStandardScore: minStandard,
            minimumPairCount: minPairs,
          );
      if (takesDiscard) {
        bot.hand.add(discarded);
        _discarded = null;
        for (final other in bots.where((other) => !identical(other, bot))) {
          other.opponentTakes.add(discarded);
          if (other.opponentTakes.length > 12) other.opponentTakes.removeAt(0);
        }
      } else {
        if (_deck.isEmpty) {
          _finished = true;
          return;
        }
        bot.hand.add(_deck.removeLast());
      }
    }
    _firstTurn = false;
    bot.turnsPlayed++;
    final played = BotEngine.play(
      bot,
      melds,
      allowOpening: canOpen,
      minimumStandardScore: minStandard,
      minimumPairCount: minPairs,
      random: _random,
    );
    _openedMelds += played.openedMeldCount;
    _processedTiles += played.processedTileCount;
    _turnCount++;
    _discarded = played.discarded;
    if (_discarded != null) {
      for (final other in bots) {
        other.seenDiscards.add(_discarded!);
        if (other.seenDiscards.length > 20) other.seenDiscards.removeAt(0);
      }
    }
    if (bot.hand.isEmpty) {
      _winner = _turn;
      _finished = true;
    } else if (_deck.isEmpty) {
      _finished = true;
    } else {
      _turn = (_turn + 1) % 4;
    }
  }

  LeagueTableResult get result {
    if (!_finished) throw StateError('The virtual table has not finished.');
    return LeagueTableResult(
      tableIndex: tableIndex,
      winnerSeat: _winner,
      turnsPlayed: _turnCount,
      openedMelds: _openedMelds,
      processedTiles: _processedTiles,
      deckExhausted: _deck.isEmpty,
      penalties: [
        for (var seat = 0; seat < 4; seat++)
          seat == _winner
              ? -101
              : Rules.roundPenaltyFor(
                  bots[seat].hand,
                  fakeOkeyValue: _okeyNumber,
                  hasOpened: bots[seat].hasOpened,
                  openedWithPairs: bots[seat].openType == 'cift',
                ),
      ],
    );
  }
}

List<LeagueTableResult> simulateLeagueTables({
  required int seed,
  LeagueSeating? seating,
}) {
  final random = Random(seed);
  return [
    for (var table = 0; table < 4; table++)
      _finishTable(
        LeagueVirtualTable(
          tableIndex: table,
          seed: random.nextInt(1 << 31),
          participantIds: seating?.table(table + 1),
        ),
      ),
  ];
}

LeagueTableResult _finishTable(LeagueVirtualTable table) {
  while (!table.finished) {
    table.step();
  }
  return table.result;
}

Future<List<int>> _nativeLeagueRound(int seed, LeagueSeating? seating) =>
    Isolate.run(
      () => simulateLeagueTables(
        seed: seed,
        seating: seating,
      ).expand((table) => table.penalties).toList(),
    );

/// Phones use a separate isolate; the browser yields between actual bot turns.
Future<List<int>> playLeagueTables({
  required int seed,
  bool Function()? isActive,
  bool useIsolate = true,
  LeagueSeating? seating,
}) async {
  if (isActive != null && !isActive()) return [];
  if (!kIsWeb && useIsolate) return _nativeLeagueRound(seed, seating);
  final random = Random(seed);
  final tables = [
    for (var table = 0; table < 4; table++)
      LeagueVirtualTable(
        tableIndex: table,
        seed: random.nextInt(1 << 31),
        participantIds: seating?.table(table + 1),
      ),
  ];
  while (tables.any((table) => !table.finished)) {
    if (isActive != null && !isActive()) return [];
    for (final table in tables) {
      table.step();
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }
  return tables.expand((table) => table.result.penalties).toList();
}

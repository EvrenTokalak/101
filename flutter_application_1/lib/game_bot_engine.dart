part of 'game.dart';

class BotTurnResult {
  final Tile? discarded;
  final int openedMeldCount;
  final int processedTileCount;
  final String? openedType;

  const BotTurnResult({
    required this.discarded,
    required this.openedMeldCount,
    required this.processedTileCount,
    required this.openedType,
  });
}

/// Gerçek bot eli üzerinden 101 açma, çift açma, işleme ve taş atma kararı verir.
class BotEngine {
  const BotEngine._();

  static final Random _random = Random();

  static bool wantsDiscard(
    BotPlayer bot,
    Tile discarded,
    List<Meld> tableMelds, {
    bool allowOpening = true,
    int minimumStandardScore = 101,
    int minimumPairCount = 5,
  }) {
    if (bot.hasOpened) {
      if (_canProcess(discarded, tableMelds)) return true;
      final before = _futureValue(bot.hand, tableMelds);
      final after = _futureValue([...bot.hand, discarded], tableMelds);
      return after >= before + 18;
    }

    if (!allowOpening) return false;

    final hand = [...bot.hand, discarded];
    final standard = _standardMeldsKeepingDiscard(hand);
    final standardScore = _meldScore(standard);
    final standardUsesDiscard = standard
        .expand((meld) => meld)
        .any((tile) => tile.id == discarded.id);
    final pairs = _pairsKeepingDiscard(hand);
    final pairsUseDiscard = pairs
        .expand((pair) => pair)
        .any((tile) => tile.id == discarded.id);
    return (standardScore >= minimumStandardScore && standardUsesDiscard) ||
        (pairs.length >= minimumPairCount && pairsUseDiscard);
  }

  static BotTurnResult play(
    BotPlayer bot,
    List<Meld> tableMelds, {
    bool allowOpening = true,
    int minimumStandardScore = 101,
    int minimumPairCount = 5,
  }) {
    var openedMeldCount = 0;
    var processedTileCount = 0;
    String? openedType;

    final pairAreaIsOpen = Rules.canLayPairsAfterStandard(tableMelds);

    if (!bot.hasOpened) {
      final standard = _standardMeldsKeepingDiscard(bot.hand);
      final pairs = _pairsKeepingDiscard(bot.hand);
      final standardScore = _meldScore(standard);
      final canOpenStandard =
          allowOpening && standardScore >= minimumStandardScore;
      final canOpenPairs = allowOpening && pairs.length >= minimumPairCount;

      if (canOpenStandard || canOpenPairs) {
        final choosePairs =
            canOpenPairs &&
            (!canOpenStandard ||
                pairs.expand((pair) => pair).length >
                    standard.expand((meld) => meld).length);
        final openingGroups = choosePairs ? pairs : standard;
        openedType = choosePairs ? 'cift' : 'seri';
        _moveGroupsToTable(bot, openingGroups, tableMelds, openedType);
        openedMeldCount = openingGroups.length;
        bot.hasOpened = true;
        bot.openType = openedType;
      }
    } else {
      final extraGroups = bot.openType == 'cift'
          ? _pairsKeepingDiscard(bot.hand)
          : _standardMeldsKeepingDiscard(bot.hand);
      if (extraGroups.isNotEmpty) {
        _moveGroupsToTable(bot, extraGroups, tableMelds, bot.openType);
        openedMeldCount += extraGroups.length;
      }
    }

    // Seriyle açmış bir oyuncu ancak masada başka bir çift açılımı varsa
    // elindeki gerçek çiftleri ortak çift alanına indirebilir.
    if (bot.hasOpened && bot.openType == 'seri' && pairAreaIsOpen) {
      final extraPairs = _pairsKeepingDiscard(bot.hand);
      if (extraPairs.isNotEmpty) {
        _moveGroupsToTable(bot, extraPairs, tableMelds, 'cift');
        openedMeldCount += extraPairs.length;
      }
    }

    if (bot.hasOpened) {
      processedTileCount = _processEligibleTiles(bot, tableMelds);
    }

    final discarded = _chooseDiscard(bot.hand, tableMelds);
    if (discarded != null) {
      bot.hand.removeWhere((tile) => tile.id == discarded.id);
    }
    bot.tileCount = bot.hand.length;

    return BotTurnResult(
      discarded: discarded,
      openedMeldCount: openedMeldCount,
      processedTileCount: processedTileCount,
      openedType: openedType,
    );
  }

  static void _moveGroupsToTable(
    BotPlayer bot,
    List<List<Tile>> groups,
    List<Meld> tableMelds,
    String openingType,
  ) {
    var available = max(0, bot.hand.length - 1);
    final playableGroups = <List<Tile>>[];
    for (final group in groups) {
      if (group.length > available) continue;
      playableGroups.add(group);
      available -= group.length;
    }
    final usedIds = playableGroups
        .expand((group) => group)
        .map((tile) => tile.id)
        .toSet();
    for (final group in playableGroups) {
      final type = openingType == 'cift' ? 'cift' : Rules.meldType(group)!;
      tableMelds.add(Meld(tiles: Rules.orderedMeld(group, type), type: type));
    }
    bot.hand.removeWhere((tile) => usedIds.contains(tile.id));
    bot.tileCount = bot.hand.length;
  }

  static int _processEligibleTiles(BotPlayer bot, List<Meld> tableMelds) {
    var processed = 0;
    var changed = true;
    while (changed && bot.hand.length > 1) {
      changed = false;
      for (final tile in List<Tile>.from(bot.hand)) {
        if (bot.hand.length <= 1) break;
        for (final meld in tableMelds) {
          if (!Rules.canAddToMeld(meld, [tile])) continue;
          final candidate = [...meld.tiles, tile];
          meld.tiles = Rules.orderedMeld(candidate, meld.type);
          bot.hand.removeWhere((item) => item.id == tile.id);
          processed++;
          changed = true;
          break;
        }
        if (changed) break;
      }
    }
    bot.tileCount = bot.hand.length;
    return processed;
  }

  static Tile? _chooseDiscard(List<Tile> hand, List<Meld> tableMelds) {
    if (hand.isEmpty) return null;
    final plannedIds = RackSolver.standardMelds(hand)
        .expand((meld) => meld)
        .map((tile) => tile.id)
        .toSet();
    final pairedIds = RackSolver.pairs(hand)
        .expand((pair) => pair)
        .map((tile) => tile.id)
        .toSet();

    int calculateUtility(Tile tile) {
      if (tile.isOkey) return 10000;
      var value = 0;
      if (plannedIds.contains(tile.id)) value += 160;
      if (pairedIds.contains(tile.id)) value += 90;
      if (_canProcess(tile, tableMelds)) value += 130;
      for (final other in hand) {
        if (other.id == tile.id || other.isOkey) continue;
        if (other.number == tile.number && other.color != tile.color) {
          value += 22;
        }
        if (other.color == tile.color) {
          final distance = (other.number - tile.number).abs();
          if (distance == 1) value += 28;
          if (distance == 2) value += 12;
        }
      }
      return value - tile.number;
    }

    // Sıralama karşılaştırıcısı aynı taşı birçok kez sorar. Özellikle masa
    // kalabalıkken canProcess taramasını her karşılaştırmada yinelemek yerine
    // her taşın değerini tur başına yalnız bir kez hesapla.
    final utilities = <int, int>{
      for (final tile in hand) tile.id: calculateUtility(tile),
    };

    final sorted = List<Tile>.from(hand)
      ..sort((a, b) {
        final byUtility = utilities[a.id]!.compareTo(utilities[b.id]!);
        return byUtility != 0 ? byUtility : b.number.compareTo(a.number);
      });
    final weakestScore = utilities[sorted.first.id]!;
    final plausible = sorted
        .take(3)
        .where((tile) => utilities[tile.id]! <= weakestScore + 12)
        .toList();
    return plausible[_random.nextInt(plausible.length)];
  }

  static bool _canProcess(Tile tile, List<Meld> tableMelds) {
    for (final meld in tableMelds) {
      if (Rules.canAddToMeld(meld, [tile])) {
        return true;
      }
    }
    return false;
  }

  static int _futureValue(List<Tile> hand, List<Meld> tableMelds) {
    final melds = RackSolver.standardMelds(hand);
    var value = _meldScore(melds) + melds.expand((meld) => meld).length * 8;
    value += hand.where((tile) => _canProcess(tile, tableMelds)).length * 20;
    return value;
  }

  static int _meldScore(List<List<Tile>> melds) =>
      melds.fold(0, (sum, meld) => sum + Rules.meldValue(meld));

  static List<List<Tile>> _standardMeldsKeepingDiscard(List<Tile> hand) {
    final direct = RackSolver.standardMelds(hand);
    if (direct.expand((meld) => meld).length < hand.length) return direct;

    var best = <List<Tile>>[];
    for (final reserved in hand) {
      final candidate = RackSolver.standardMelds(
        hand.where((tile) => tile.id != reserved.id).toList(),
      );
      final candidateCount = candidate.expand((meld) => meld).length;
      final bestCount = best.expand((meld) => meld).length;
      if (candidateCount > bestCount ||
          (candidateCount == bestCount &&
              _meldScore(candidate) > _meldScore(best))) {
        best = candidate;
      }
    }
    return best;
  }

  static List<List<Tile>> _pairsKeepingDiscard(List<Tile> hand) {
    final direct = RackSolver.pairs(hand);
    if (direct.expand((pair) => pair).length < hand.length) return direct;

    var best = <List<Tile>>[];
    for (final reserved in hand) {
      final candidate = RackSolver.pairs(
        hand.where((tile) => tile.id != reserved.id).toList(),
      );
      if (candidate.length > best.length) best = candidate;
    }
    return best;
  }
}

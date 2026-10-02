part of 'game.dart';

/// Istakadaki taşlardan otomatik olarak geçerli per ve çift grupları üretir.
class RackSolver {
  const RackSolver._();

  /// Istakadaki mevcut soldan-sağa yerleşimi bozmadan, bitişik perleri
  /// birbirinden ayırır. Arada boşluk bırakılmamış iki geçerli per de bulunur.
  static List<List<Tile>> standardMeldsFromLayout(Iterable<List<Tile>> rows) =>
      [
        for (final row in rows)
          ..._bestLayoutPlan(
            row,
            pairsOnly: false,
          ).melds.map((candidate) => candidate.tiles),
      ];

  /// Istakadaki yan yana çiftleri, aynı kesintisiz sırada birden fazla çift
  /// bulunsa bile ikişer taşlık gruplar halinde algılar.
  static List<List<Tile>> pairsFromLayout(Iterable<List<Tile>> rows) => [
    for (final row in rows)
      ..._bestLayoutPlan(
        row,
        pairsOnly: true,
      ).melds.map((candidate) => candidate.tiles),
  ];

  static _RackPlan _bestLayoutPlan(
    List<Tile> tiles, {
    required bool pairsOnly,
  }) {
    final memo = <int, _RackPlan>{};

    _RackPlan solve(int index) {
      if (index >= tiles.length) return const _RackPlan();
      final cached = memo[index];
      if (cached != null) return cached;

      // Geçerli bir grubun parçası olmayan taşı atlayabilmek, tüm ıstaka
      // doluyken de oyuncunun hazırladığı perleri bulmamızı sağlar.
      var best = solve(index + 1);
      final lengths = pairsOnly
          ? const [2]
          : [for (var length = 3; length <= 13; length++) length];
      for (final length in lengths) {
        final end = index + length;
        if (end > tiles.length) break;
        final group = tiles.sublist(index, end);
        final type = pairsOnly
            ? (Rules.isValidPair(group) ? 'cift' : null)
            : Rules.meldType(group);
        if (type == null || (!pairsOnly && type == 'cift')) continue;

        final ordered = Rules.orderedMeld(group, type);
        final tail = solve(end);
        final candidate = _RackMeldCandidate(
          tiles: ordered,
          signature: ordered.map((tile) => tile.id).join(','),
        );
        final plan = _RackPlan(
          melds: [candidate, ...tail.melds],
          score: (pairsOnly ? 0 : Rules.meldValue(ordered)) + tail.score,
          tileCount: ordered.length + tail.tileCount,
          jokerScore:
              (ordered.any((tile) => tile.isOkey)
                  ? Rules.meldValue(ordered)
                  : 0) +
              tail.jokerScore,
        );
        if (plan.isBetterThan(best)) best = plan;
      }
      memo[index] = best;
      return best;
    }

    return solve(0);
  }

  static List<List<Tile>> standardMelds(List<Tile> rack) {
    final candidates = <_RackMeldCandidate>[];
    final jokers = rack.where((tile) => tile.isOkey).toList();

    for (final color in TileColor.values) {
      final byNumber = <int, List<Tile>>{};
      for (final tile in rack.where(
        (tile) => !tile.isOkey && tile.color == color,
      )) {
        byNumber.putIfAbsent(tile.number, () => []).add(tile);
      }

      for (var copy = 0; copy < 2; copy++) {
        for (var start = 1; start <= 11; start++) {
          for (var end = start + 2; end <= 13; end++) {
            final tiles = <Tile>[];
            var missing = 0;
            for (var number = start; number <= end; number++) {
              final copies = byNumber[number] ?? const <Tile>[];
              if (copies.length > copy) {
                tiles.add(copies[copy]);
              } else {
                missing++;
                if (missing <= jokers.length) {
                  // Okeyi temsil ettiği sayının fiziksel konumuna yerleştir.
                  // Böylece aynı taşlarla kurulabilen farklı seriler ayrı
                  // adaylar olarak değerlendirilir.
                  tiles.add(jokers[missing - 1]);
                }
              }
            }
            if (missing > jokers.length || tiles.isEmpty) continue;
            _addCandidate(candidates, tiles, 'seri');
            for (var index = 0; index < tiles.length; index++) {
              final tile = tiles[index];
              if (tile.isOkey) continue;
              final copies = byNumber[tile.number] ?? const <Tile>[];
              if (copies.length < 2) continue;
              final mixed = List<Tile>.from(tiles)
                ..[index] = copies.firstWhere((item) => item.id != tile.id);
              _addCandidate(candidates, mixed, 'seri');
            }
          }
        }
      }
    }
    for (var number = 1; number <= 13; number++) {
      final possible = rack
          .where(
            (tile) => tile.isOkey || (!tile.isOkey && tile.number == number),
          )
          .toList();
      for (final size in const [3, 4]) {
        for (final selection in _combinations(possible, size)) {
          _addCandidate(candidates, selection, 'grup');
        }
      }
    }

    final result = _pickNonOverlapping(candidates);
    return result;
  }

  static List<List<Tile>> pairs(List<Tile> rack) {
    final groups = <List<Tile>>[];
    final used = <int>{};
    final jokers = rack.where((tile) => tile.isOkey).toList();
    final byValue = <String, List<Tile>>{};

    for (final tile in rack.where((tile) => !tile.isOkey)) {
      byValue
          .putIfAbsent('${tile.color.index}:${tile.number}', () => [])
          .add(tile);
    }

    for (final matches in byValue.values) {
      while (matches.length >= 2) {
        final pair = [matches.removeAt(0), matches.removeAt(0)];
        groups.add(pair);
        used.addAll(pair.map((tile) => tile.id));
      }
    }

    final singletons = rack.where(
      (tile) => !tile.isOkey && !used.contains(tile.id),
    );
    final freeJokers = jokers.where((tile) => !used.contains(tile.id)).toList();
    var jokerIndex = 0;
    for (final tile in singletons) {
      if (jokerIndex >= freeJokers.length) break;
      final pair = [tile, freeJokers[jokerIndex++]];
      groups.add(pair);
      used.addAll(pair.map((item) => item.id));
    }

    while (jokerIndex + 1 < freeJokers.length) {
      final pair = [freeJokers[jokerIndex++], freeJokers[jokerIndex++]];
      groups.add(pair);
      used.addAll(pair.map((item) => item.id));
    }

    return groups;
  }

  static void _addCandidate(
    List<_RackMeldCandidate> target,
    List<Tile> tiles,
    String type,
  ) {
    final valid = type == 'seri'
        ? Rules.isValidRun(tiles)
        : Rules.isValidGroup(tiles);
    if (!valid) return;
    final ordered = Rules.orderedMeld(tiles, type);
    // Sıra imzanın parçasıdır: aynı okey farklı bir sayıyı temsil ediyorsa
    // çözücü bunu ayrı bir yerleşim olarak puanlamalıdır.
    final signature = ordered.map((tile) => tile.id).join(',');
    if (target.any((item) => item.signature == signature)) return;
    target.add(_RackMeldCandidate(tiles: ordered, signature: signature));
  }

  static List<List<Tile>> _pickNonOverlapping(
    List<_RackMeldCandidate> candidates,
  ) {
    if (candidates.isEmpty) return const [];
    // Onceki acgozlu secici, bir per iki daha degerli peri engellediginde en
    // yuksek eli kacirabiliyordu. Istakadaki fiziksel taslari bit maskesiyle
    // tarayarak cakismayan perlerin gercek en yuksek puanli birlesimini bul.
    final tileIds = <int>{
      for (final candidate in candidates)
        for (final tile in candidate.tiles) tile.id,
    }.toList();
    final bitForId = <int, int>{
      for (var index = 0; index < tileIds.length; index++)
        tileIds[index]: 1 << index,
    };
    final masks = <int>[
      for (final candidate in candidates)
        candidate.tiles.fold<int>(0, (mask, tile) => mask | bitForId[tile.id]!),
    ];
    final candidatesByBit = <int, List<int>>{};
    for (var index = 0; index < masks.length; index++) {
      var bits = masks[index];
      while (bits != 0) {
        final bit = bits & -bits;
        candidatesByBit.putIfAbsent(bit, () => <int>[]).add(index);
        bits &= ~bit;
      }
    }
    final memo = <int, _RackPlan>{0: const _RackPlan()};

    _RackPlan solve(int availableMask) {
      final cached = memo[availableMask];
      if (cached != null) return cached;
      int? pivot;
      var smallestOptionCount = 1 << 30;
      var remainingBits = availableMask;
      while (remainingBits != 0) {
        final bit = remainingBits & -remainingBits;
        var optionCount = 0;
        for (final index in candidatesByBit[bit] ?? const <int>[]) {
          if (masks[index] & availableMask == masks[index]) optionCount++;
        }
        if (optionCount < smallestOptionCount) {
          pivot = bit;
          smallestOptionCount = optionCount;
          if (optionCount == 0) break;
        }
        remainingBits &= ~bit;
      }

      final pivotBit = pivot!;
      var best = solve(availableMask & ~pivotBit);
      for (final index in candidatesByBit[pivotBit] ?? const <int>[]) {
        final candidateMask = masks[index];
        if (candidateMask & availableMask != candidateMask) continue;
        final candidate = candidates[index];
        final tail = solve(availableMask & ~candidateMask);
        final value = Rules.meldValue(candidate.tiles);
        final plan = _RackPlan(
          melds: [candidate, ...tail.melds],
          score: value + tail.score,
          tileCount: candidate.tiles.length + tail.tileCount,
          jokerScore:
              (candidate.tiles.any((tile) => tile.isOkey) ? value : 0) +
              tail.jokerScore,
        );
        if (plan.isBetterThan(best)) best = plan;
      }
      memo[availableMask] = best;
      return best;
    }

    final plan = solve((1 << tileIds.length) - 1);
    final result = plan.melds.map((candidate) => candidate.tiles).toList();
    result.sort((a, b) => Rules.meldValue(b).compareTo(Rules.meldValue(a)));
    return result;
  }

  static Iterable<List<Tile>> _combinations(
    List<Tile> source,
    int count,
  ) sync* {
    if (count == 0) {
      yield const <Tile>[];
      return;
    }
    for (var index = 0; index <= source.length - count; index++) {
      for (final tail in _combinations(source.sublist(index + 1), count - 1)) {
        yield [source[index], ...tail];
      }
    }
  }
}

class _RackMeldCandidate {
  final List<Tile> tiles;
  final String signature;

  _RackMeldCandidate({required this.tiles, required this.signature});
}

class _RackPlan {
  final List<_RackMeldCandidate> melds;
  final int score;
  final int tileCount;
  final int jokerScore;

  const _RackPlan({
    this.melds = const [],
    this.score = 0,
    this.tileCount = 0,
    this.jokerScore = 0,
  });

  bool isBetterThan(_RackPlan other) =>
      score > other.score ||
      (score == other.score && jokerScore > other.jokerScore) ||
      (score == other.score &&
          jokerScore == other.jokerScore &&
          tileCount > other.tileCount) ||
      (score == other.score &&
          jokerScore == other.jokerScore &&
          tileCount == other.tileCount &&
          melds.length < other.melds.length);
}

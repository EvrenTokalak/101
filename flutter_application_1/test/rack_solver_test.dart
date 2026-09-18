import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  var nextId = 1000;

  Tile tile(
    int number,
    TileColor color, {
    bool isOkey = false,
    bool isFakeOkey = false,
  }) => Tile(
    number: number,
    color: color,
    id: nextId++,
    isOkey: isOkey,
    isFakeOkey: isFakeOkey,
  );

  test('per diz geçerli seri ve sayı grubunu bulur', () {
    final rack = [
      tile(4, TileColor.red),
      tile(5, TileColor.red),
      tile(6, TileColor.red),
      tile(9, TileColor.red),
      tile(9, TileColor.blue),
      tile(9, TileColor.black),
      tile(2, TileColor.yellow),
    ];

    final melds = RackSolver.standardMelds(rack);

    expect(melds.length, 2);
    expect(melds.every(Rules.isValidMeld), isTrue);
    expect(melds.expand((meld) => meld).length, 6);
  });

  test('per diz okey ile serideki boşluğu tamamlar', () {
    final rack = [
      tile(4, TileColor.blue),
      tile(6, TileColor.blue),
      tile(12, TileColor.red, isOkey: true),
    ];

    final melds = RackSolver.standardMelds(rack);

    expect(melds, hasLength(1));
    expect(Rules.isValidRun(melds.single), isTrue);
  });

  test('tek okeyi kullanılabileceği en yüksek değerli pere ayırır', () {
    final joker = tile(7, TileColor.yellow, isOkey: true);
    final rack = [
      tile(2, TileColor.red),
      tile(3, TileColor.red),
      tile(11, TileColor.blue),
      tile(12, TileColor.blue),
      joker,
    ];

    final melds = RackSolver.standardMelds(rack);
    final jokerMeld = melds.singleWhere((meld) => meld.contains(joker));

    expect(Rules.meldValue(jokerMeld), 36);
    expect(
      jokerMeld.where((tile) => !tile.isOkey).map((tile) => tile.number),
      containsAll([11, 12]),
    );
  });

  test(
    'per diz sahte okeyi kendi renk ve sayısında normal taş olarak kullanır',
    () {
      final fakeRedEight = tile(8, TileColor.red, isFakeOkey: true);
      final rack = [
        tile(7, TileColor.red),
        fakeRedEight,
        tile(9, TileColor.red),
      ];

      final melds = RackSolver.standardMelds(rack);

      expect(melds, hasLength(1));
      expect(melds.single, contains(fakeRedEight));
      expect(Rules.isValidRun(melds.single), isTrue);
    },
  );

  test('çift diz aynı renk ve sayıdaki kopyaları yan yana gruplar', () {
    final rack = [
      tile(7, TileColor.black),
      tile(7, TileColor.black),
      tile(11, TileColor.yellow),
      tile(11, TileColor.yellow),
      tile(3, TileColor.red),
    ];

    final pairs = RackSolver.pairs(rack);

    expect(pairs, hasLength(2));
    expect(pairs.every(Rules.isValidPair), isTrue);
  });

  test('iki okey iki ayrı eksik çifti doğru şekilde tamamlar', () {
    final firstJoker = tile(4, TileColor.red, isOkey: true);
    final secondJoker = tile(4, TileColor.red, isOkey: true);
    final rack = [
      firstJoker,
      tile(7, TileColor.black),
      secondJoker,
      tile(11, TileColor.yellow),
    ];

    final pairs = RackSolver.pairs(rack);
    final usedIds = pairs.expand((pair) => pair).map((tile) => tile.id).toSet();

    expect(pairs, hasLength(2));
    expect(pairs.every(Rules.isValidPair), isTrue);
    expect(usedIds, hasLength(4));
  });

  test('çakışan perlerde ilk bulduğunu değil daha güçlü planı seçer', () {
    final rack = [
      for (var number = 9; number <= 13; number++) tile(number, TileColor.red),
      for (var number = 10; number <= 13; number++)
        tile(number, TileColor.blue),
      tile(13, TileColor.black),
      tile(13, TileColor.yellow),
    ];

    final melds = RackSolver.standardMelds(rack);
    final score = melds.fold(0, (sum, meld) => sum + Rules.meldValue(meld));

    expect(melds.length, greaterThanOrEqualTo(2));
    expect(score, greaterThan(55));
    expect(melds.every(Rules.isValidMeld), isTrue);
  });

  test('karışık fiziksel kopyalarla çakışmayan tüm perleri bulur', () {
    final redFourA = tile(4, TileColor.red);
    final redFourB = tile(4, TileColor.red);
    final rack = [
      redFourA,
      redFourB,
      tile(5, TileColor.red),
      tile(5, TileColor.red),
      tile(6, TileColor.red),
      tile(4, TileColor.blue),
      tile(4, TileColor.black),
    ];

    final melds = RackSolver.standardMelds(rack);
    final usedIds = melds.expand((meld) => meld).map((tile) => tile.id).toSet();

    expect(melds, hasLength(2));
    expect(usedIds, hasLength(6));
    expect(melds.every(Rules.isValidMeld), isTrue);
  });

  test('bitişik dizilmiş birden fazla peri ayrı ayrı algılar', () {
    final first = [
      tile(4, TileColor.red),
      tile(5, TileColor.red),
      tile(6, TileColor.red),
    ];
    final second = [
      tile(9, TileColor.red),
      tile(9, TileColor.blue),
      tile(9, TileColor.black),
    ];

    final melds = RackSolver.standardMeldsFromLayout([
      [...first, ...second],
    ]);

    expect(melds, hasLength(2));
    expect(melds[0], orderedEquals(first));
    expect(melds[1], orderedEquals(second));
  });

  test('bitişik dizilmiş çiftleri ikişer taşlık gruplara ayırır', () {
    final first = [tile(7, TileColor.black), tile(7, TileColor.black)];
    final second = [tile(11, TileColor.yellow), tile(11, TileColor.yellow)];

    final pairs = RackSolver.pairsFromLayout([
      [...first, ...second],
    ]);

    expect(pairs, hasLength(2));
    expect(pairs[0], orderedEquals(first));
    expect(pairs[1], orderedEquals(second));
  });
}

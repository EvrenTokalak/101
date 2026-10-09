import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  var nextId = 2000;

  Tile tile(
    int number,
    TileColor color, {
    bool isOkey = false,
    bool isIndicator = false,
  }) => Tile(
    number: number,
    color: color,
    id: nextId++,
    isOkey: isOkey,
    isIndicator: isIndicator,
  );

  List<Meld> pairTable(int count) => List.generate(
    count,
    (i) => Meld(
      tiles: [
        tile(i % 13 + 1, TileColor.blue),
        tile(i % 13 + 1, TileColor.blue),
      ],
      type: 'cift',
    ),
  );

  for (final scenario in [
    (15, 20, true),
    (16, 20, false),
    (19, 24, true),
    (20, 24, false),
  ]) {
    test('initial pair opening respects remaining slots: $scenario', () {
      final hand = <Tile>[];
      for (final n in [1, 3, 5, 7, 9]) {
        hand.addAll([tile(n, TileColor.black), tile(n, TileColor.black)]);
      }
      hand.add(tile(13, TileColor.yellow));
      final bot = BotPlayer(name: 'Bot', hand: hand);
      final table = pairTable(scenario.$1);
      BotEngine.play(bot, table, pairAreaLimit: scenario.$2);
      expect(bot.hasOpened, scenario.$3);
      expect(table.length, scenario.$1 + (scenario.$3 ? 5 : 0));
    });
  }

  for (final type in ['cift', 'seri']) {
    for (final scenario in [
      (19, 20, 1),
      (20, 20, 0),
      (21, 20, 0),
      (23, 24, 1),
      (24, 24, 0),
    ]) {
      test('extra pairs respect capacity: $type $scenario', () {
        final bot = BotPlayer(
          name: 'Bot',
          hasOpened: true,
          openType: type,
          hand: [
            tile(7, TileColor.red),
            tile(7, TileColor.red),
            tile(9, TileColor.black),
            tile(9, TileColor.black),
            tile(13, TileColor.yellow),
          ],
        );
        final table = pairTable(scenario.$1);
        final result = BotEngine.play(bot, table, pairAreaLimit: scenario.$2);
        expect(result.openedMeldCount, scenario.$3);
        expect(table.length, scenario.$1 + scenario.$3);
      });
    }
  }

  for (final count in [19, 20]) {
    test('pair replacement and discard pickup respect limit: $count', () {
      final replacement = tile(7, TileColor.red);
      final joker = tile(8, TileColor.yellow, isOkey: true);
      final table = pairTable(count);
      table[0] = Meld(tiles: [tile(7, TileColor.red), joker], type: 'cift');
      final bot = BotPlayer(
        name: 'Bot',
        hasOpened: true,
        openType: 'cift',
        hand: [tile(13, TileColor.yellow)],
      );
      expect(
        BotEngine.wantsDiscard(bot, replacement, table, pairAreaLimit: 20),
        count < 20,
      );
      bot.hand.add(replacement);
      final result = BotEngine.play(bot, table, pairAreaLimit: 20);
      expect(result.processedTileCount, count < 20 ? 1 : 0);
      expect(table[0].tiles.any((t) => t.isOkey), count == 20);
    });
  }

  test('full pair area still allows processing runs', () {
    final seven = tile(7, TileColor.red);
    final table = pairTable(20)
      ..add(
        Meld(
          tiles: [
            tile(4, TileColor.red),
            tile(5, TileColor.red),
            tile(6, TileColor.red),
          ],
          type: 'seri',
        ),
      );
    final bot = BotPlayer(
      name: 'Bot',
      hasOpened: true,
      openType: 'seri',
      hand: [tile(13, TileColor.yellow)],
    );
    expect(
      BotEngine.wantsDiscard(bot, seven, table, pairAreaLimit: 20),
      isTrue,
    );
    bot.hand.add(seven);
    final result = BotEngine.play(bot, table, pairAreaLimit: 20);
    expect(result.processedTileCount, 1);
    expect(table.last.tiles, contains(seven));
  });
  test('bot göstergeyi alıp kırmızı 6 ve sarı 13 ile beş çift açar', () {
    final indicator = tile(6, TileColor.red, isIndicator: true);
    final yellowThirteen = tile(13, TileColor.yellow);
    final bot = BotPlayer(
      name: 'Bot',
      personality: BotPersonality.pairFocused,
      hand: [
        for (final value in [
          (2, TileColor.red),
          (4, TileColor.blue),
          (8, TileColor.black),
          (10, TileColor.yellow),
        ])
          for (var copy = 0; copy < 2; copy++) tile(value.$1, value.$2),
        yellowThirteen,
        tile(1, TileColor.blue),
      ],
    );
    final table = <Meld>[];
    expect(BotEngine.wantsDiscard(bot, indicator, table), isTrue);
    bot.hand.add(indicator);
    final result = BotEngine.play(bot, table);
    expect(bot.hasOpened, isTrue);
    expect(bot.openType, 'cift');
    expect(result.openedMeldCount, 5);
    expect(
      table.every(
        (meld) => meld.type == 'cift' && Rules.isValidPair(meld.tiles),
      ),
      isTrue,
    );
    expect(
      table.any(
        (meld) =>
            meld.tiles.contains(indicator) &&
            meld.tiles.contains(yellowThirteen),
      ),
      isTrue,
    );
    expect(bot.hand.any((tile) => tile.id == indicator.id), isFalse);
  });
  test('elini açmış bot göstergeyle farklı taşı ek çift olarak kullanmaz', () {
    for (final type in ['cift', 'seri']) {
      final indicator = tile(6, TileColor.red, isIndicator: true);
      final other = tile(13, TileColor.yellow);
      final bot = BotPlayer(name: 'Bot', hand: [other, tile(1, TileColor.blue)])
        ..hasOpened = true
        ..openType = type;
      final table = [
        Meld(
          type: 'cift',
          tiles: [tile(2, TileColor.black), tile(2, TileColor.black)],
        ),
      ];
      // Warm the opening cache with the same hand, then check the opened context.
      final unopened = BotPlayer(name: 'Unopened', hand: List.from(bot.hand));
      expect(
        BotEngine.wantsDiscard(unopened, indicator, table, minimumPairCount: 1),
        isTrue,
      );
      expect(BotEngine.wantsDiscard(bot, indicator, table), isFalse);
      bot.hand.add(indicator);
      final result = BotEngine.play(bot, table);
      expect(result.openedMeldCount, 0);
      expect(table, hasLength(1));
    }
  });
  test('bot 101 puana ulaşmadan per açmaz', () {
    final bot = BotPlayer(
      name: 'Bot',
      hand: [
        tile(1, TileColor.red),
        tile(2, TileColor.red),
        tile(3, TileColor.red),
        tile(12, TileColor.blue),
      ],
    );
    final table = <Meld>[];

    final result = BotEngine.play(bot, table);

    expect(bot.hasOpened, isFalse);
    expect(result.openedMeldCount, 0);
    expect(table, isEmpty);
  });

  test('açılış izni verilmediyse güçlü elle bile bekler', () {
    final bot = BotPlayer(
      name: 'Sabırlı Bot',
      hand: [
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.red),
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.blue),
        tile(4, TileColor.black),
        tile(5, TileColor.black),
        tile(6, TileColor.black),
        tile(2, TileColor.yellow),
      ],
    );
    final table = <Meld>[];

    final result = BotEngine.play(bot, table, allowOpening: false);

    expect(bot.hasOpened, isFalse);
    expect(result.openedMeldCount, 0);
    expect(table, isEmpty);
  });

  test('açılış turu gelmeyen bot kenardaki taşı almaz', () {
    final bot = BotPlayer(
      name: 'Sabırlı Bot',
      hand: [
        tile(10, TileColor.red),
        tile(11, TileColor.red),
        tile(12, TileColor.red),
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.blue),
        tile(4, TileColor.black),
        tile(5, TileColor.black),
        tile(6, TileColor.black),
      ],
    );
    final discarded = tile(13, TileColor.red);

    expect(
      BotEngine.wantsDiscard(bot, discarded, const [], allowOpening: false),
      isFalse,
    );
  });

  test('bot toplam per puanı 101 olduğunda gerçek taşlarıyla açar', () {
    final bot = BotPlayer(
      name: 'Bot',
      hand: [
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.red),
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.blue),
        tile(4, TileColor.black),
        tile(5, TileColor.black),
        tile(6, TileColor.black),
        tile(2, TileColor.yellow),
      ],
    );
    final table = <Meld>[];

    final result = BotEngine.play(bot, table);

    expect(bot.hasOpened, isTrue);
    expect(bot.openType, 'seri');
    expect(result.openedMeldCount, 3);
    expect(
      table.fold(0, (sum, meld) => sum + Rules.meldValue(meld.tiles)),
      greaterThanOrEqualTo(101),
    );
    expect(result.openingValue, 107);
  });

  test('bot renkli modda bonus serileri iki kat hesaplayarak açar', () {
    BotPlayer createBot() => BotPlayer(
      name: 'Renkli Bot',
      hand: [
        tile(7, TileColor.red),
        tile(8, TileColor.red),
        tile(9, TileColor.red),
        tile(10, TileColor.red),
        tile(11, TileColor.red),
        tile(12, TileColor.red),
        tile(2, TileColor.yellow),
      ],
    );

    final normalBot = createBot();
    final normalResult = BotEngine.play(normalBot, <Meld>[]);
    expect(normalBot.hasOpened, isFalse);
    expect(normalResult.openingValue, isNull);

    final colorBot = createBot();
    final colorResult = BotEngine.play(
      colorBot,
      <Meld>[],
      bonusColor: TileColor.red,
    );
    expect(colorBot.hasOpened, isTrue);
    expect(colorResult.openingValue, 114);
  });

  test('bot katlamali acilis sinirinin altinda kalinca acmaz', () {
    BotPlayer createBot() => BotPlayer(
      name: 'Katlamali Bot',
      hand: [
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.red),
        for (var number = 10; number <= 13; number++)
          tile(number, TileColor.blue),
        tile(4, TileColor.black),
        tile(5, TileColor.black),
        tile(6, TileColor.black),
        tile(2, TileColor.yellow),
      ],
    );

    final allowedBot = createBot();
    final allowed = BotEngine.play(
      allowedBot,
      <Meld>[],
      minimumStandardScore: 107,
    );
    expect(allowedBot.hasOpened, isTrue);
    expect(allowed.openingValue, 107);

    final blockedBot = createBot();
    final blocked = BotEngine.play(
      blockedBot,
      <Meld>[],
      minimumStandardScore: 108,
    );
    expect(blockedBot.hasOpened, isFalse);
    expect(blocked.openingValue, isNull);
  });

  test('bot beş gerçek çift oluştuğunda çift açar', () {
    final hand = <Tile>[];
    for (final number in const [1, 3, 5, 7, 9]) {
      hand
        ..add(tile(number, TileColor.black))
        ..add(tile(number, TileColor.black));
    }
    hand.add(tile(13, TileColor.yellow));
    final bot = BotPlayer(name: 'Bot', hand: hand);
    final table = <Meld>[];

    final result = BotEngine.play(bot, table);

    expect(bot.hasOpened, isTrue);
    expect(bot.openType, 'cift');
    expect(result.openedMeldCount, 5);
    expect(result.openingValue, 5);
    expect(table.every((meld) => meld.type == 'cift'), isTrue);
  });

  test('bot katlamali modda gereken cift sayisinin altinda acmaz', () {
    final hand = <Tile>[];
    for (final number in const [1, 3, 5, 7, 9]) {
      hand
        ..add(tile(number, TileColor.black))
        ..add(tile(number, TileColor.black));
    }
    hand.add(tile(13, TileColor.yellow));
    final bot = BotPlayer(name: 'Katlamali Bot', hand: hand);

    final result = BotEngine.play(bot, <Meld>[], minimumPairCount: 6);

    expect(bot.hasOpened, isFalse);
    expect(result.openingValue, isNull);
  });

  test('eli açık bot masadaki pere uygun taşı işler', () {
    final bot = BotPlayer(
      name: 'Bot',
      hasOpened: true,
      openType: 'seri',
      hand: [tile(7, TileColor.red), tile(13, TileColor.yellow)],
    );
    final table = [
      Meld(
        tiles: [
          tile(4, TileColor.red),
          tile(5, TileColor.red),
          tile(6, TileColor.red),
        ],
        type: 'seri',
      ),
    ];

    final result = BotEngine.play(bot, table);

    expect(result.processedTileCount, 1);
    expect(table.single.tiles.map((item) => item.number), contains(7));
  });

  test(
    'seri açmış bot yalnız açık çift alanı varsa elindeki çifti indirir',
    () {
      BotPlayer openedBot() => BotPlayer(
        name: 'Bot',
        hasOpened: true,
        openType: 'seri',
        hand: [
          tile(7, TileColor.red),
          tile(7, TileColor.red),
          tile(13, TileColor.yellow),
        ],
      );

      final withoutPairArea = <Meld>[];
      final firstBot = openedBot();
      final firstResult = BotEngine.play(firstBot, withoutPairArea);
      expect(firstResult.openedMeldCount, 0);
      expect(withoutPairArea, isEmpty);

      final withPairArea = <Meld>[
        Meld(
          tiles: [tile(4, TileColor.blue), tile(4, TileColor.blue)],
          type: 'cift',
        ),
      ];
      final secondBot = openedBot();
      final secondResult = BotEngine.play(secondBot, withPairArea);
      expect(secondResult.openedMeldCount, 1);
      expect(withPairArea.where((meld) => meld.type == 'cift'), hasLength(2));
    },
  );

  test('bot bütün taşlarını açmayıp bitmek için son taşı mutlaka atar', () {
    final hand = <Tile>[];
    for (final number in const [1, 3, 5, 7, 9]) {
      hand
        ..add(tile(number, TileColor.black))
        ..add(tile(number, TileColor.black));
    }
    final bot = BotPlayer(name: 'Bot', hand: hand);

    final result = BotEngine.play(bot, <Meld>[]);

    expect(result.discarded, isNotNull);
    expect(bot.hasOpened, isFalse);
    expect(bot.hand, hasLength(9));
  });

  test('açık bot yandan taşı yalnız aynı turda kullanabilecekse alır', () {
    final bot = BotPlayer(
      name: 'Bot',
      hasOpened: true,
      openType: 'seri',
      hand: [
        tile(5, TileColor.red),
        tile(6, TileColor.red),
        tile(13, TileColor.yellow),
      ],
    );

    expect(
      BotEngine.wantsDiscard(bot, tile(8, TileColor.red), const <Meld>[]),
      isFalse,
    );
    expect(
      BotEngine.wantsDiscard(bot, tile(7, TileColor.red), const <Meld>[]),
      isTrue,
    );
  });

  test('bot masadaki okeyi alıp aynı turda yeniden işler', () {
    final okey = tile(12, TileColor.blue, isOkey: true);
    final bot = BotPlayer(
      name: 'Bot',
      hasOpened: true,
      openType: 'seri',
      hand: [
        tile(5, TileColor.red),
        tile(7, TileColor.red),
        tile(13, TileColor.yellow),
      ],
    );
    final table = [
      Meld(
        tiles: [tile(4, TileColor.red), okey, tile(6, TileColor.red)],
        type: 'seri',
      ),
    ];

    final result = BotEngine.play(bot, table);

    expect(result.processedTileCount, 3);
    expect(table.single.tiles.any((item) => item.id == okey.id), isTrue);
    expect(
      table.single.tiles.map((item) => item.number),
      containsAll([4, 5, 6, 7]),
    );
  });

  test('zor ve temkinli bot rakibin beklediği taşı atmaz', () {
    final dangerous = tile(6, TileColor.red);
    final safe = tile(13, TileColor.yellow);
    final bot = BotPlayer(
      name: 'Temkinli Bot',
      difficulty: BotDifficulty.hard,
      personality: BotPersonality.cautious,
      hasOpened: true,
      openType: 'seri',
      hand: [dangerous, safe],
      opponentTakes: [tile(5, TileColor.red)],
    );

    final result = BotEngine.play(bot, <Meld>[]);

    expect(result.discarded?.id, safe.id);
    expect(bot.hand.single.id, dangerous.id);
  });

  test('bot motoru rastgele ellerde geçerli masa üretir', () {
    final random = Random(101);
    for (var iteration = 0; iteration < 150; iteration++) {
      final deck = buildDeck();
      deck.shuffle(random);
      final bot = BotPlayer(
        name: 'Simülasyon Botu',
        difficulty:
            BotDifficulty.values[iteration % BotDifficulty.values.length],
        personality:
            BotPersonality.values[iteration % BotPersonality.values.length],
        hasOpened: true,
        openType: 'seri',
        hand: deck.take(22).toList(),
      );
      final table = <Meld>[];

      final result = BotEngine.play(bot, table);

      expect(result.discarded, isNotNull, reason: 'simülasyon $iteration');
      expect(bot.tileCount, bot.hand.length, reason: 'simülasyon $iteration');
      expect(
        table.every(
          (meld) => meld.type == 'cift'
              ? Rules.isValidPair(meld.tiles)
              : Rules.isValidMeld(meld.tiles),
        ),
        isTrue,
        reason: 'simülasyon $iteration',
      );
    }
  });
}

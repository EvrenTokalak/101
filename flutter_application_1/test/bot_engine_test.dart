import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  var nextId = 2000;

  Tile tile(int number, TileColor color, {bool isOkey = false}) =>
      Tile(number: number, color: color, id: nextId++, isOkey: isOkey);

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
    expect(table.every((meld) => meld.type == 'cift'), isTrue);
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
}

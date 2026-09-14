import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game.dart';

void main() {
  var nextId = 0;

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

  group('101 per kuralları', () {
    test('aynı renk ardışık en az üç taş seri olur', () {
      final run = [
        tile(4, TileColor.red),
        tile(5, TileColor.red),
        tile(6, TileColor.red),
      ];

      expect(Rules.isValidRun(run), isTrue);
      expect(Rules.meldValue(run), 15);
      expect(
        Rules.isValidRun([
          tile(4, TileColor.red),
          tile(5, TileColor.blue),
          tile(6, TileColor.red),
        ]),
        isFalse,
      );
    });

    test('okey serideki eksik taşı tamamlar ve temsil ettiği puanı alır', () {
      final joker = tile(12, TileColor.black, isOkey: true);
      final run = [tile(4, TileColor.red), joker, tile(6, TileColor.red)];

      expect(Rules.isValidRun(run), isTrue);
      expect(Rules.meldValue(run), 15);
      expect(Rules.orderedMeld(run, 'seri')[1].isOkey, isTrue);
    });

    test('okeyin seri puanı soldan sağa yerleştiği konuma göre hesaplanır', () {
      final rightJoker = tile(4, TileColor.black, isOkey: true);
      final rightRun = [
        tile(8, TileColor.red),
        tile(9, TileColor.red),
        rightJoker,
      ];
      final leftJoker = tile(4, TileColor.black, isOkey: true);
      final leftRun = [
        leftJoker,
        tile(8, TileColor.red),
        tile(9, TileColor.red),
      ];

      expect(Rules.meldValue(rightRun), 27); // 8 + 9 + 10
      expect(Rules.meldValue(leftRun), 24); // 7 + 8 + 9
      expect(Rules.orderedMeld(rightRun, 'seri').last, same(rightJoker));
      expect(Rules.orderedMeld(leftRun, 'seri').first, same(leftJoker));
    });

    test('aynı sayı farklı renklerle grup olur', () {
      final group = [
        tile(8, TileColor.red),
        tile(8, TileColor.blue),
        tile(8, TileColor.black),
      ];

      expect(Rules.isValidGroup(group), isTrue);
      expect(Rules.meldValue(group), 24);
      expect(
        Rules.isValidGroup([
          tile(8, TileColor.red),
          tile(8, TileColor.red),
          tile(8, TileColor.black),
        ]),
        isFalse,
      );
    });

    test('çift yalnızca aynı taşın iki kopyası veya okey desteğiyle olur', () {
      expect(
        Rules.isValidPair([
          tile(11, TileColor.yellow),
          tile(11, TileColor.yellow),
        ]),
        isTrue,
      );
      expect(
        Rules.isValidPair([
          tile(11, TileColor.yellow),
          tile(11, TileColor.blue),
        ]),
        isFalse,
      );
      expect(
        Rules.isValidPair([
          tile(11, TileColor.yellow),
          tile(3, TileColor.red, isOkey: true),
        ]),
        isTrue,
      );
    });

    test('13 sınırını aşan seri kabul edilmez', () {
      expect(
        Rules.isValidRun([
          tile(12, TileColor.black),
          tile(13, TileColor.black),
          tile(1, TileColor.black),
        ]),
        isFalse,
      );
    });

    test('aynı fiziksel taş iki kez kullanılarak per oluşturulamaz', () {
      final repeated = tile(6, TileColor.red);
      expect(
        Rules.isValidRun([repeated, repeated, tile(7, TileColor.red)]),
        isFalse,
      );
      expect(Rules.isValidPair([repeated, repeated]), isFalse);
    });

    test('yalnız okeylerden oluşan sahte per kabul edilmez', () {
      expect(
        Rules.isValidRun([
          tile(1, TileColor.red, isOkey: true),
          tile(2, TileColor.blue, isOkey: true),
          tile(3, TileColor.black, isOkey: true),
        ]),
        isFalse,
      );
    });

    test(
      'seri açan oyuncu yalnız masada çift açılımı varsa çift indirebilir',
      () {
        final standardTable = [
          Meld(
            tiles: [
              tile(4, TileColor.red),
              tile(5, TileColor.red),
              tile(6, TileColor.red),
            ],
            type: 'seri',
          ),
        ];
        expect(Rules.canLayPairsAfterStandard(standardTable), isFalse);

        standardTable.add(
          Meld(
            tiles: [tile(9, TileColor.blue), tile(9, TileColor.blue)],
            type: 'cift',
          ),
        );
        expect(Rules.canLayPairsAfterStandard(standardTable), isTrue);
      },
    );

    test('ıstakadaki geçerli perlerin toplam puanını hesaplar', () {
      final run = [
        tile(4, TileColor.red),
        tile(5, TileColor.red),
        tile(6, TileColor.red),
      ];
      final numberGroup = [
        tile(8, TileColor.red),
        tile(8, TileColor.blue),
        tile(8, TileColor.black),
      ];
      final invalid = [tile(2, TileColor.red), tile(9, TileColor.blue)];

      expect(Rules.validMeldTotal([run, numberGroup, invalid]), 39);
    });

    test('okey göstergenin aynı renkteki bir sonraki sayısıdır', () {
      expect(Rules.okeyNumberForIndicator(4), 5);
      expect(Rules.okeyNumberForIndicator(13), 1);
    });

    test('kalan puanında sahte okey o elin okey numarasını alır', () {
      final rack = [
        tile(7, TileColor.blue),
        tile(0, TileColor.red, isFakeOkey: true),
        tile(11, TileColor.black, isOkey: true),
      ];

      expect(Rules.penaltyFor(rack, fakeOkeyValue: 5), 37);
    });

    test('çift açanın cezası yalnız el sonunda iki katına çıkar', () {
      final rack = [tile(4, TileColor.red), tile(9, TileColor.blue)];

      expect(Rules.penaltyFor(rack, fakeOkeyValue: 5), 13);
      expect(
        Rules.roundPenaltyFor(
          rack,
          fakeOkeyValue: 5,
          hasOpened: true,
          openedWithPairs: false,
        ),
        13,
      );
      expect(
        Rules.roundPenaltyFor(
          rack,
          fakeOkeyValue: 5,
          hasOpened: true,
          openedWithPairs: true,
        ),
        26,
      );
      expect(
        Rules.roundPenaltyFor(
          rack,
          fakeOkeyValue: 5,
          hasOpened: false,
          openedWithPairs: true,
        ),
        202,
      );
    });

    test('sahte okey perlerde o elin okey taşı gibi normal taş sayılır', () {
      final fakeRedEight = tile(8, TileColor.red, isFakeOkey: true);

      expect(
        Rules.isValidRun([
          tile(7, TileColor.red),
          fakeRedEight,
          tile(9, TileColor.red),
        ]),
        isTrue,
      );
      expect(
        Rules.isValidGroup([
          fakeRedEight,
          tile(8, TileColor.blue),
          tile(8, TileColor.black),
        ]),
        isTrue,
      );
      expect(
        Rules.isValidRun([
          tile(7, TileColor.blue),
          fakeRedEight,
          tile(9, TileColor.blue),
        ]),
        isFalse,
      );
    });

    test('101 açıldıktan sonraki geçerli perlerde puan sınırı aranmaz', () {
      final lowValueRun = [
        tile(1, TileColor.blue),
        tile(2, TileColor.blue),
        tile(3, TileColor.blue),
      ];

      expect(
        Rules.meetsStandardOpeningScore([lowValueRun], alreadyOpened: false),
        isFalse,
      );
      expect(
        Rules.meetsStandardOpeningScore([lowValueRun], alreadyOpened: true),
        isTrue,
      );
    });

    test('yalnızca pere gerçekten uyan taşları işlek kabul eder', () {
      final run = Meld(
        tiles: [
          tile(4, TileColor.red),
          tile(5, TileColor.red),
          tile(6, TileColor.red),
        ],
        type: 'seri',
      );
      final group = Meld(
        tiles: [
          tile(9, TileColor.red),
          tile(9, TileColor.blue),
          tile(9, TileColor.black),
        ],
        type: 'grup',
      );
      final pair = Meld(
        tiles: [tile(3, TileColor.blue), tile(3, TileColor.blue)],
        type: 'cift',
      );

      expect(Rules.canAddToMeld(run, [tile(7, TileColor.red)]), isTrue);
      expect(Rules.canAddToMeld(run, [tile(8, TileColor.red)]), isFalse);
      expect(Rules.canAddToMeld(group, [tile(9, TileColor.yellow)]), isTrue);
      expect(Rules.canAddToMeld(group, [tile(10, TileColor.yellow)]), isFalse);
      expect(Rules.canAddToMeld(pair, [tile(3, TileColor.blue)]), isFalse);
    });

    test('okey yalnız temsil ettiği gerçek taşla değiştirilebilir', () {
      final run = Meld(
        tiles: [
          tile(4, TileColor.red),
          tile(11, TileColor.black, isOkey: true),
          tile(6, TileColor.red),
        ],
        type: 'seri',
      );
      final group = Meld(
        tiles: [
          tile(8, TileColor.red),
          tile(8, TileColor.blue),
          tile(8, TileColor.yellow),
          tile(3, TileColor.yellow, isOkey: true),
        ],
        type: 'grup',
      );

      expect(Rules.okeyReplacementIndex(run, tile(5, TileColor.red)), 1);
      expect(Rules.okeyReplacementIndex(run, tile(5, TileColor.blue)), isNull);
      expect(Rules.okeyReplacementIndex(group, tile(8, TileColor.black)), 3);
      expect(
        Rules.okeyReplacementIndex(group, tile(9, TileColor.black)),
        isNull,
      );
    });

    test('üç taşlık aynı sayı grubundan okey geri alınamaz', () {
      final group = Meld(
        tiles: [
          tile(6, TileColor.red),
          tile(6, TileColor.blue),
          tile(2, TileColor.black, isOkey: true),
        ],
        type: 'grup',
      );

      expect(
        Rules.okeyReplacementIndex(group, tile(6, TileColor.black)),
        isNull,
      );
    });

    test('serideki okey yalnız bulunduğu konumun taşıyla alınır', () {
      final joker = tile(2, TileColor.blue, isOkey: true);
      final endRun = Meld(
        tiles: [tile(8, TileColor.red), tile(9, TileColor.red), joker],
        type: 'seri',
      );
      final middleRun = Meld(
        tiles: [tile(4, TileColor.blue), joker, tile(6, TileColor.blue)],
        type: 'seri',
      );
      final startRun = Meld(
        tiles: [
          joker,
          tile(11, TileColor.black),
          tile(12, TileColor.black),
          tile(13, TileColor.black),
        ],
        type: 'seri',
      );

      expect(Rules.okeyReplacementIndex(endRun, tile(10, TileColor.red)), 2);
      expect(
        Rules.okeyReplacementIndex(endRun, tile(7, TileColor.red)),
        isNull,
      );
      expect(Rules.okeyReplacementIndex(middleRun, tile(5, TileColor.blue)), 1);
      expect(
        Rules.okeyReplacementIndex(middleRun, tile(7, TileColor.blue)),
        isNull,
      );
      expect(
        Rules.okeyReplacementIndex(startRun, tile(10, TileColor.black)),
        0,
      );
      expect(
        Rules.okeyReplacementIndex(startRun, tile(9, TileColor.black)),
        isNull,
      );
    });

    test('birden fazla okey kalan perden okey geri alınamaz', () {
      final group = Meld(
        tiles: [
          tile(3, TileColor.red),
          tile(2, TileColor.blue, isOkey: true),
          tile(2, TileColor.black, isOkey: true),
        ],
        type: 'grup',
      );

      expect(
        Rules.okeyReplacementIndex(group, tile(3, TileColor.blue)),
        isNull,
      );
    });
  });
}

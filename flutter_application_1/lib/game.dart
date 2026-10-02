import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'game_launch.dart';
import 'app_controls.dart';
import 'app_language.dart';
import 'performance_overlay.dart';
import 'player_progress.dart';
import 'opponent_name_session.dart';
import 'store_cosmetics.dart';

part 'game_rack_solver.dart';
part 'game_bot_engine.dart';
part 'game_animations.dart';
part 'game_settings.dart';
part 'game_table_widgets.dart';

/// Ana menü ve oyun içi ayarlar arasında paylaşılan titreşim tercihi.
bool gameVibrationEnabled = true;

void setGameVibrationEnabled(bool enabled) {
  gameVibrationEnabled = enabled;
}

Future<void>? _gameAudioWarmup;

Future<void> prewarmGameAudio() {
  if (kIsWeb) return Future.value();
  return _gameAudioWarmup ??= (() async {
    try {
      await AudioCache.instance.loadAll(const [
        'sounds/tile_pick.wav',
        'sounds/tile_place.wav',
        'sounds/tile_arrange.wav',
      ]);
    } catch (_) {}
  })();
}

int _rackDecodeWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.width * media.devicePixelRatio * 0.76).round().clamp(
    720,
    1080,
  );
}

int _backgroundDecodeWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.width * media.devicePixelRatio).round().clamp(720, 1080);
}

Future<void> prewarmGameVisuals(BuildContext context) => Future.wait<void>([
  // Oyun sahnesiyle aynı anahtarı kullan; tam boy ve 1920 px kopyaları aynı
  // anda bellekte tutulmasın.
  precacheImage(
    ResizeImage(
      AssetImage(storeCosmetics.rackAsset),
      width: _rackDecodeWidth(context),
    ),
    context,
  ),
  precacheImage(AssetImage(storeCosmetics.tileAsset), context),
  if (storeCosmetics.fakeOkeyAsset case final asset?)
    precacheImage(AssetImage(asset), context),
  if (storeCosmetics.backgroundColor == null)
    precacheImage(
      ResizeImage(
        AssetImage(storeCosmetics.backgroundAsset),
        width: _backgroundDecodeWidth(context),
      ),
      context,
    ),
]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([playerProgress.load(), storeCosmetics.load()]);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const OkeyApp());
}

// ═══════════════════════════════════════════════════════════════════════════
// RENKLER
// ═══════════════════════════════════════════════════════════════════════════
class OC {
  static const bg = Color(0xFFEDE0CC);
  static const tableBdr = Color(0xFF6B4C28);
  static const tableGreen = Color(0xFF3A7A3A);
  static const tableGrid = Color(0xFF357A35);
  static const rackWood = Color(0xFFD4A03A);
  static const rackDark = Color(0xFF8B5E1E);
  static const rackSide = Color(0xFF7B4F1A);
  static const tileBg = Color(0xFFFFF8EE);
  static const tileBdr = Color(0xFFCCBB99);
  static const tileSel = Color(0xFF2196F3);
  static const numRed = Color(0xFFD32F2F);
  static const numBlue = Color(0xFF1565C0);
  static const numBlack = Color(0xFF1A1A1A);
  static const numYellow = Color(0xFFE6A000);
  static const numGreen = Color(0xFF2E7D32);
  static const gold = Color(0xFFD4A017);
  static const goldLight = Color(0xFFF0CC5A);
  static const cream = Color(0xFFF5EDD6);
  static const panelBrown = Color(0xFF5C3A1E);
  static const btnBrown = Color(0xFF6B4020);
  static const badgeCyan = Color(0xFF00BCD4);
  static const badgePurp = Color(0xFF9C27B0);
  static const okeyGold = Color(0xFFFFD700);
  static const coinGold = Color(0xFFF0B000);
  static const barBg = Color(0xFFF0E0C0);
  static const openedBg = Color(0xFFFFF3CD);
  static const openedBdr = Color(0xFFFFB300);
}

// ═══════════════════════════════════════════════════════════════════════════
// VERİ MODELİ
// ═══════════════════════════════════════════════════════════════════════════
enum TileColor { red, blue, black, yellow }

class Tile {
  int number; // 1-13, deste oluşturulurken sahte okey için geçici olarak 0
  TileColor color;
  final bool isFakeOkey; // gerçek sahte okey taşı mı
  bool isOkey; // bu tur okey olarak mı işaretlendi
  bool selected;
  bool okeyFaceRevealed;
  final int id; // unique id (drag için)

  Tile({
    required this.number,
    required this.color,
    this.isFakeOkey = false,
    this.isOkey = false,
    this.selected = false,
    this.okeyFaceRevealed = false,
    required this.id,
  });

  Color get displayColor {
    switch (color) {
      case TileColor.red:
        return OC.numRed;
      case TileColor.blue:
        return OC.numBlue;
      case TileColor.black:
        return OC.numBlack;
      case TileColor.yellow:
        return OC.numYellow;
    }
  }

  int get pointValue => isOkey ? 0 : number; // okey 0 puan değer taşır elde
}

// Perde (açılmış taş grubu)
class Meld {
  List<Tile> tiles;
  String type; // 'seri' | 'grup' | 'cift'
  Meld({required this.tiles, required this.type});
}

class _RackDragData {
  final int tileId;
  final int sourceSlot;
  final Set<int> tileIds;
  final Tile tile;

  const _RackDragData({
    required this.tileId,
    required this.sourceSlot,
    required this.tileIds,
    required this.tile,
  });
}

class _RackDragVisualState {
  final Offset? gridPosition;
  final double tilt;
  final double lift;

  const _RackDragVisualState({this.gridPosition, this.tilt = 0, this.lift = 0});
}

// İşlenebilir taşın hem çizimi hem DragTarget hit testi aynı noktayı izler.
// Böylece perin üzerindeki taş kabul edilir; altta kalan parmak değil.
const double _meldDragLift = 38;

class _RackPushPreview {
  final int tileId;
  final int sourceSlot;
  final int targetSlot;
  final int vacancySlot;
  final _RackMoveKind kind;

  const _RackPushPreview({
    required this.tileId,
    required this.sourceSlot,
    required this.targetSlot,
    required this.vacancySlot,
    required this.kind,
  });
}

enum _RackMoveKind { insert, push }

const int _maxRackPushTiles = 6;

int _rackPushVacancy(List<int?> slots, int sourceSlot, int targetSlot) {
  final rowLength = _GameScreenState._rackRowLength;
  if (sourceSlot ~/ rowLength != targetSlot ~/ rowLength) return -1;
  final rowStart = (targetSlot ~/ rowLength) * rowLength;
  final rowEnd = rowStart + rowLength;
  final pushRight = sourceSlot < targetSlot;
  if (pushRight) {
    final searchEnd = min(rowEnd, targetSlot + _maxRackPushTiles + 1);
    for (var index = targetSlot + 1; index < searchEnd; index++) {
      if (slots[index] == null) return index;
    }
  } else {
    final searchStart = max(rowStart, targetSlot - _maxRackPushTiles);
    for (var index = targetSlot - 1; index >= searchStart; index--) {
      if (slots[index] == null) return index;
    }
  }
  return -1;
}

int _nearestRackVacancy(List<int?> slots, int targetSlot) {
  final rowLength = _GameScreenState._rackRowLength;
  final rowStart = (targetSlot ~/ rowLength) * rowLength;
  final rowEnd = rowStart + rowLength;
  for (var distance = 0; distance < rowLength; distance++) {
    final left = targetSlot - distance;
    if (left >= rowStart && slots[left] == null) return left;
    final right = targetSlot + distance;
    if (right < rowEnd && right != left && slots[right] == null) return right;
  }
  return -1;
}

class _ProcessedMove {
  final Meld meld;
  final List<Tile> previousMeldTiles;
  final List<Tile> addedTiles;
  final List<Tile> returnedTiles;
  final bool removeMeldOnUndo;
  final Map<int, int> originalSlots;
  final bool tookDiscardBefore;
  final Tile? takenDiscardTileBefore;

  const _ProcessedMove({
    required this.meld,
    required this.previousMeldTiles,
    required this.addedTiles,
    this.returnedTiles = const [],
    this.removeMeldOnUndo = false,
    required this.originalSlots,
    required this.tookDiscardBefore,
    required this.takenDiscardTileBefore,
  });
}

int _idCounter = 0;

List<Tile> buildDeck() {
  final deck = <Tile>[];
  for (int copy = 0; copy < 2; copy++) {
    for (final c in TileColor.values) {
      for (int n = 1; n <= 13; n++) {
        deck.add(Tile(number: n, color: c, id: _idCounter++));
      }
    }
  }
  // 2 sahte okey
  deck.add(
    Tile(number: 0, color: TileColor.red, isFakeOkey: true, id: _idCounter++),
  );
  deck.add(
    Tile(number: 0, color: TileColor.red, isFakeOkey: true, id: _idCounter++),
  );
  deck.shuffle(Random());
  return deck;
}

// ═══════════════════════════════════════════════════════════════════════════
// BOT
// ═══════════════════════════════════════════════════════════════════════════
class BotPlayer {
  final String name;
  final String displayName;
  int tileCount;
  int penalty;
  bool hasOpened;
  String openType;
  int turnsPlayed;
  List<Tile> hand;
  BotPlayer({
    required this.name,
    String? displayName,
    this.tileCount = 21,
    this.penalty = 0,
    this.hasOpened = false,
    this.openType = '',
    this.turnsPlayed = 0,
    this.hand = const [],
  }) : displayName = displayName ?? name;
}

// ═══════════════════════════════════════════════════════════════════════════
// KURAL MOTORU
// ═══════════════════════════════════════════════════════════════════════════
class Rules {
  /// Taşların mevcut soldan-sağa dizilişine uyan seri sayılarını döndürür.
  /// Böylece okeyin temsil ettiği değer, per içindeki yerine göre belirlenir.
  static List<int>? _positionedRunNumbers(List<Tile> tiles) {
    if (tiles.length < 3 || tiles.length > 13) return null;
    final real = tiles.where((tile) => !tile.isOkey).toList();
    if (real.isEmpty) return null;
    final color = real.first.color;
    if (real.any((tile) => tile.color != color)) return null;

    for (var start = 1; start <= 14 - tiles.length; start++) {
      var matches = true;
      for (var index = 0; index < tiles.length; index++) {
        final tile = tiles[index];
        if (!tile.isOkey && tile.number != start + index) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return [
          for (var index = 0; index < tiles.length; index++) start + index,
        ];
      }
    }
    return null;
  }

  /// Seri: aynı renk, ardışık sayı, en az 3 taş
  static bool isValidRun(List<Tile> tiles) {
    if (tiles.length < 3 || tiles.length > 13) return false;
    if (tiles.map((tile) => tile.id).toSet().length != tiles.length) {
      return false;
    }
    final real = tiles.where((t) => !t.isOkey).toList();
    if (real.any((t) => t.number < 1 || t.number > 13)) {
      return false;
    }
    if (real.isEmpty || tiles.length - real.length > 2) return false;
    final col = real.first.color;
    if (real.any((t) => t.color != col)) return false;
    final nums = real.map((t) => t.number).toSet();
    if (nums.length != real.length) return false;

    for (int start = 1; start <= 14 - tiles.length; start++) {
      final sequence = {for (int i = 0; i < tiles.length; i++) start + i};
      if (nums.every(sequence.contains)) return true;
    }
    return false;
  }

  /// Çift (grup): aynı sayı, farklı renkler, en az 3, en fazla 4
  static bool isValidGroup(List<Tile> tiles) {
    if (tiles.length < 3 || tiles.length > 4) return false;
    if (tiles.map((tile) => tile.id).toSet().length != tiles.length) {
      return false;
    }
    final real = tiles.where((t) => !t.isOkey).toList();
    if (real.any((t) => t.number < 1 || t.number > 13)) {
      return false;
    }
    if (real.isEmpty || tiles.length - real.length > 2) return false;
    final num = real.first.number;
    if (real.any((t) => t.number != num)) return false;
    final cols = real.map((t) => t.color).toSet();
    if (cols.length != real.length) return false; // aynı renk tekrarı yok
    return true;
  }

  /// Çift açılışı: aynı taşın iki kopyası veya bir taş + okey.
  static bool isValidPair(List<Tile> tiles) {
    if (tiles.length != 2) return false;
    if (tiles[0].id == tiles[1].id) return false;
    final real = tiles.where((t) => !t.isOkey).toList();
    if (real.any((t) => t.number < 1 || t.number > 13)) return false;
    if (real.length <= 1) return true;
    return real[0].number == real[1].number && real[0].color == real[1].color;
  }

  static bool isValidMeld(List<Tile> tiles) =>
      isValidRun(tiles) || isValidGroup(tiles);

  static bool canAddToMeld(Meld meld, Iterable<Tile> additions) {
    if (meld.type == 'cift') return false;
    final addedTiles = additions.toList();
    if (addedTiles.isEmpty) return false;
    // Tamamlanmış perler kapalı hedeftir. Özellikle 1-13 serisine veya dört
    // renkli gruba ikinci fiziksel kopya eklenmesine hiçbir giriş yolu izin
    // vermemeli.
    if ((meld.type == 'seri' && meld.tiles.length >= 13) ||
        (meld.type == 'grup' && meld.tiles.length >= 4)) {
      return false;
    }
    final existingIds = meld.tiles.map((tile) => tile.id).toSet();
    if (addedTiles.any((tile) => existingIds.contains(tile.id)) ||
        addedTiles.map((tile) => tile.id).toSet().length != addedTiles.length) {
      return false;
    }
    final candidate = [...meld.tiles, ...addedTiles];
    return meld.type == 'seri'
        ? isValidRun(candidate)
        : isValidGroup(candidate);
  }

  /// Normal bir taş, masadaki okeyin temsil ettiği taşsa değiştirilebilir.
  static int? okeyReplacementIndex(Meld meld, Tile replacement) {
    if (replacement.isOkey) return null;
    // Aynı sayı-farklı renk grubunda üç taşlık yapı henüz okeyi geri
    // almak için tamamlanmış sayılmaz. Önce dört taşlık grup oluşmalıdır.
    if (meld.type == 'grup' && meld.tiles.length < 4) return null;
    final currentIsComplete = switch (meld.type) {
      'seri' => isValidRun(meld.tiles),
      'grup' => isValidGroup(meld.tiles),
      'cift' => isValidPair(meld.tiles),
      _ => false,
    };
    if (!currentIsComplete) return null;
    // Değişim sonunda perin/çiftin tamamen doğal taşlardan oluşması gerekir.
    if (meld.tiles.where((tile) => tile.isOkey).length != 1) return null;
    final realTiles = meld.tiles.where((tile) => !tile.isOkey).toList();
    final runNumbers = meld.type == 'seri'
        ? _positionedRunNumbers(meld.tiles)
        : null;
    final runColor = realTiles.isEmpty ? null : realTiles.first.color;
    for (var index = 0; index < meld.tiles.length; index++) {
      if (!meld.tiles[index].isOkey) continue;
      if (meld.type == 'seri' &&
          (runNumbers == null ||
              runColor == null ||
              replacement.number != runNumbers[index] ||
              replacement.color != runColor)) {
        continue;
      }
      final candidate = List<Tile>.from(meld.tiles)..[index] = replacement;
      final valid = switch (meld.type) {
        'seri' => isValidRun(candidate),
        'grup' => isValidGroup(candidate),
        'cift' => isValidPair(candidate),
        _ => false,
      };
      if (valid) return index;
    }
    return null;
  }

  /// Otomatik işlemede okeyi geri alma fırsatı, normal per uzatmalarından
  /// önce değerlendirilir.
  static int preferredMeldIndexForTile(List<Meld> melds, Tile tile) {
    for (var index = 0; index < melds.length; index++) {
      if (okeyReplacementIndex(melds[index], tile) != null) return index;
    }
    for (var index = 0; index < melds.length; index++) {
      if (canAddToMeld(melds[index], [tile])) return index;
    }
    return -1;
  }

  static String? meldType(List<Tile> tiles) {
    if (isValidRun(tiles)) return 'seri';
    if (isValidGroup(tiles)) return 'grup';
    if (isValidPair(tiles)) return 'cift';
    return null;
  }

  /// Taş değeri toplamı
  static int sumValue(List<Tile> tiles) =>
      tiles.fold(0, (s, t) => s + (t.isOkey ? 25 : t.number));

  /// Per puanı; okey, per içinde temsil ettiği taşın değerini alır.
  static int meldValue(List<Tile> tiles) {
    if (isValidGroup(tiles)) {
      final real = tiles.where((t) => !t.isOkey).toList();
      return (real.isEmpty ? 13 : real.first.number) * tiles.length;
    }
    if (isValidRun(tiles)) {
      final positionedNumbers = _positionedRunNumbers(tiles);
      if (positionedNumbers != null) {
        return positionedNumbers.fold(0, (sum, number) => sum + number);
      }
      final realNumbers = tiles
          .where((t) => !t.isOkey)
          .map((t) => t.number)
          .toSet();
      for (int start = 1; start <= 14 - tiles.length; start++) {
        final sequence = [for (int i = 0; i < tiles.length; i++) start + i];
        if (realNumbers.every(sequence.contains)) {
          return sequence.fold(0, (sum, number) => sum + number);
        }
      }
    }
    return sumValue(tiles);
  }

  /// Elde 101+ puan seri var mı?
  static bool canOpenSeri(List<Tile> rack) {
    // Basit greedily: tüm geçerli seri/grup kombinasyonlarını bul
    // Demo amaçlı: kullanıcı kendi seçiyor, biz sadece seçilenleri doğruluyoruz
    return true; // Doğrulama _onOpenMeld içinde yapılıyor
  }

  /// Meld değeri ≥ 101 mi?
  static bool meetsOpeningThreshold(List<Tile> tiles) =>
      meldValue(tiles) >= 101;

  /// 5 çift oluşturuyor mu?
  static bool isFivePairs(List<List<Tile>> groups) {
    if (groups.length < 5) return false;
    return groups.every(isValidPair);
  }

  static bool canLayPairsAfterStandard(Iterable<Meld> tableMelds) =>
      tableMelds.any((meld) => meld.type == 'cift');

  static List<Tile> orderedMeld(List<Tile> tiles, String type) {
    if (type == 'seri') {
      // Oyuncunun okeyi nereye koyduğu anlamlıdır; geçerli yerleşimi koru.
      if (_positionedRunNumbers(tiles) != null) {
        return List<Tile>.from(tiles);
      }
      final realByNumber = {
        for (final tile in tiles.where((tile) => !tile.isOkey))
          tile.number: tile,
      };
      final jokers = tiles.where((tile) => tile.isOkey).toList();
      for (int start = 1; start <= 14 - tiles.length; start++) {
        final numbers = [for (int i = 0; i < tiles.length; i++) start + i];
        if (realByNumber.keys.every(numbers.contains)) {
          return numbers
              .map((number) => realByNumber[number] ?? jokers.removeAt(0))
              .toList();
        }
      }
    }
    final ordered = List<Tile>.from(tiles);
    ordered.sort((a, b) => a.color.index.compareTo(b.color.index));
    return ordered;
  }

  /// Açık bir seriye taş eklenirken mevcut taşların, özellikle de belirli bir
  /// sayıyı temsil eden okeyin, soldan-sağa konumunu korur.
  static List<Tile> extendMeldKeepingPositions(
    List<Tile> current,
    Iterable<Tile> additions,
    String type,
  ) {
    var result = List<Tile>.from(current);
    for (final addition in additions) {
      List<Tile>? validInsertion;
      for (var index = 0; index <= result.length; index++) {
        final candidate = List<Tile>.from(result)..insert(index, addition);
        final valid = type == 'seri'
            // isValidRun sayısal kümeyi doğrular; grid sırası için ayrıca
            // taşların soldan sağa gerçekten artan konumda olması gerekir.
            ? isValidRun(candidate) && _positionedRunNumbers(candidate) != null
            : isValidGroup(candidate);
        if (valid) {
          validInsertion = candidate;
          break;
        }
      }
      if (validInsertion == null) {
        return orderedMeld([...current, ...additions], type);
      }
      result = validInsertion;
    }
    return result;
  }

  static int validMeldTotal(Iterable<List<Tile>> groups) {
    return groups.fold(0, (total, group) {
      final type = meldType(group);
      if (type != 'seri' && type != 'grup') return total;
      return total + meldValue(group);
    });
  }

  /// Renkli modda yalnızca tek renkten oluşan seriler renk bonusu alır.
  /// Farklı renklerden kurulan sayı grupları normal değerinde kalır.
  static TileColor? meldColor(List<Tile> tiles) {
    if (!isValidRun(tiles)) return null;
    final realTiles = tiles.where((tile) => !tile.isOkey).toList();
    return realTiles.isEmpty ? null : realTiles.first.color;
  }

  static int coloredOpeningValue(
    Iterable<List<Tile>> groups,
    TileColor bonusColor,
  ) => groups.fold(0, (total, group) {
    final type = meldType(group);
    if (type != 'seri' && type != 'grup') return total;
    final value = meldValue(group);
    return total + (meldColor(group) == bonusColor ? value * 2 : value);
  });

  static int okeyNumberForIndicator(int indicatorNumber) {
    if (indicatorNumber < 1 || indicatorNumber > 13) {
      throw ArgumentError.value(indicatorNumber, 'indicatorNumber');
    }
    return indicatorNumber == 13 ? 1 : indicatorNumber + 1;
  }

  static bool meetsStandardOpeningScore(
    Iterable<List<Tile>> groups, {
    required bool alreadyOpened,
  }) => alreadyOpened || validMeldTotal(groups) >= 101;

  /// Elde kalan taşların ceza puanı. Sahte okey, o elde temsil ettiği
  /// gerçek okey numarası kadar değer alır.
  static int penaltyFor(List<Tile> rack, {required int fakeOkeyValue}) {
    if (fakeOkeyValue < 1 || fakeOkeyValue > 13) {
      throw ArgumentError.value(fakeOkeyValue, 'fakeOkeyValue');
    }
    return rack.fold(0, (sum, tile) {
      if (tile.isOkey) return sum + 25;
      if (tile.isFakeOkey) return sum + fakeOkeyValue;
      return sum + tile.number;
    });
  }

  /// El sonu cezası: açmayan 202, çift açan ise kalan taş toplamının iki katı.
  /// Oyun içindeki KALAN göstergesi [penaltyFor] kullanmaya devam eder.
  static int roundPenaltyFor(
    List<Tile> rack, {
    required int fakeOkeyValue,
    required bool hasOpened,
    required bool openedWithPairs,
    bool normalOpenedPenalty = false,
  }) {
    if (!hasOpened) return 202;
    final remaining = penaltyFor(rack, fakeOkeyValue: fakeOkeyValue);
    if (normalOpenedPenalty) return remaining;
    return openedWithPairs ? remaining * 2 : remaining;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════════════════════════
class OkeyApp extends StatelessWidget {
  const OkeyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '101 Okey',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: OC.bg),
    home: const GameScreen(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// OYUN EKRANI
// ═══════════════════════════════════════════════════════════════════════════
class _BotDiscardMotion {
  final Tile tile;
  final int botIndex;
  final int serial;

  const _BotDiscardMotion({
    required this.tile,
    required this.botIndex,
    required this.serial,
  });
}

enum _TableTileMotionKind { drawDeck, drawDiscard, open, process }

enum _GameSound { pick, place, arrange }

class _TableTileMotion {
  final List<Tile> tiles;
  final _TableTileMotionKind kind;
  final int playerIndex;
  final Alignment? targetAlignment;
  final int serial;

  const _TableTileMotion({
    required this.tiles,
    required this.kind,
    required this.playerIndex,
    this.targetAlignment,
    required this.serial,
  });
}

class GameScreen extends StatefulWidget {
  final bool tournamentMode;
  final int? startingPlayer;
  final GameLaunchConfig launchConfig;

  const GameScreen({
    super.key,
    this.tournamentMode = false,
    this.startingPlayer,
    this.launchConfig = const GameLaunchConfig.quickPlay(),
  }) : assert(
         startingPlayer == null || (startingPlayer >= 0 && startingPlayer <= 3),
       );
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _rackRowLength = 15;
  static const int _rackSlotCount = _rackRowLength * 2;
  static const int _roomAndModeRoundLimit = 3;
  // Gerçek oyuncu temposu; testlerde gerektiğinde bu sabit açılabilir.
  static const bool _instantBotTurns = false;

  bool get _isTournamentGame =>
      widget.tournamentMode || widget.launchConfig.isTournament;
  bool get _hasThreeRoundLimit =>
      widget.launchConfig.entryPoint == GameEntryPoint.gameMode ||
      widget.launchConfig.entryPoint == GameEntryPoint.room;

  // ── Deste & Taşlar ────────────────────────────────────────────────────
  List<Tile> _deck = [];
  List<Tile> _rack = []; // oyuncunun taşları
  List<int?> _rackSlots = List<int?>.filled(_rackSlotCount, null);
  Tile? _indicator; // gösterge taşı
  Tile? _discarded; // son atılan taş (soldan alınabilir)
  List<List<Tile>> _discardPiles = List.generate(4, (_) => <Tile>[]);
  List<Meld> _tableMetds = []; // masadaki açık perler

  // ── Sıra Durumu ───────────────────────────────────────────────────────
  // 0 = oyuncu, 1-3 = botlar
  int _turn = 0;
  int _startingPlayer = 0;
  bool _drawnThisTurn = false; // bu turda taş çekildi mi
  bool _tookDiscard = false; // soldan taş alındı mı (zorunlu kullanım)
  Tile? _takenDiscardTile; // alınan sol taşın referansı
  bool _botBusy = false;
  _BotDiscardMotion? _botDiscardMotion;
  int _botDiscardMotionSerial = 0;
  final ValueNotifier<_TableTileMotion?> _tableTileMotion = ValueNotifier(null);
  int _tableTileMotionSerial = 0;
  int? _dealAnimationSerial;
  int _dealAnimationCounter = 0;
  bool _dealInProgress = false;
  Timer? _dealTimer;
  Timer? _playerTurnTimer;
  Timer? _botThinkTimer;
  Timer? _messageTimer;
  Timer? _warningTimer;
  int _playerTurnGeneration = 0;
  final ValueNotifier<int> _playerTurnSeconds = ValueNotifier(7);

  bool get _isTimedMode => widget.launchConfig.mode == OkeyGameMode.timed101;
  bool get _isProgressiveMode =>
      widget.launchConfig.mode == OkeyGameMode.progressive;
  bool get _isColorBonusMode =>
      widget.launchConfig.mode == OkeyGameMode.colorBonus101;
  TileColor _roundBonusColor = TileColor.red;

  String get _roundBonusColorName => switch (_roundBonusColor) {
    TileColor.red => 'KIRMIZI',
    TileColor.blue => 'MAVİ',
    TileColor.black => 'SİYAH',
    TileColor.yellow => 'SARI',
  };

  Color get _roundBonusDisplayColor => switch (_roundBonusColor) {
    TileColor.red => OC.numRed,
    TileColor.blue => OC.numBlue,
    TileColor.black => const Color(0xFF252525),
    TileColor.yellow => OC.numYellow,
  };

  String get _tableModeLabel => _isColorBonusMode
      ? 'RENKLİ • $_roundBonusColorName 2×'
      : widget.launchConfig.modeLabel;
  int _minimumStandardOpeningScore = 101;
  int _minimumPairOpeningCount = 5;

  void _recordProgressiveOpening(String type, int value) {
    if (!_isProgressiveMode) return;
    if (type == 'cift') {
      _minimumPairOpeningCount = max(_minimumPairOpeningCount, value + 1);
    } else {
      _minimumStandardOpeningScore = max(
        _minimumStandardOpeningScore,
        value + 1,
      );
    }
  }

  // ── Oyuncu Durumu ─────────────────────────────────────────────────────
  bool _playerOpened = false; // el açıldı mı
  String _playerOpenType = ''; // 'seri' | 'cift'
  int _totalPenalty = 0; // biriken ceza
  int _elCount = 0; // kaçıncı el

  // ── Botlar ────────────────────────────────────────────────────────────
  late final List<BotPlayer> _bots = [
    BotPlayer(name: 'Oyuncu 2', displayName: opponentNameSession.names[0]),
    BotPlayer(name: 'Oyuncu 3', displayName: opponentNameSession.names[1]),
    BotPlayer(name: 'Oyuncu 4', displayName: opponentNameSession.names[2]),
  ];

  // ── UI Seçim Modu ─────────────────────────────────────────────────────
  // 'normal' | 'addMeld' (işleme modu: hangi melde eklenecek seçiliyor)
  String _uiMode = 'normal';
  bool _showRackPairCount = false;
  final List<_ProcessedMove> _processedMoves = [];
  final GlobalKey _meldGridKey = GlobalKey();
  final GlobalKey _playerDiscardTargetKey = GlobalKey();
  final ValueNotifier<_RackDragVisualState> _rackDragVisual = ValueNotifier(
    const _RackDragVisualState(),
  );
  final ValueNotifier<_RackPushPreview?> _rackPushPreview = ValueNotifier(null);
  bool _draggingProcessableTile = false;
  _RackDragData? _activeRackDragData;
  Offset? _lastRackDragGlobalPosition;
  Offset? _pendingGridDragPosition;
  double _pendingRackDragTilt = 0;
  double _pendingRackDragLift = 0;
  bool _dragVisualFrameScheduled = false;
  final Stopwatch _dragVisualUpdateClock = Stopwatch()..start();
  int _lastDragVisualUpdateMicros = -33000;
  int? _rackAnalysisSignature;
  int _cachedRackPerPoints = 0;
  int _cachedRackPairCount = 0;
  int? _drawAttentionTileId;
  int _drawAttentionSerial = 0;
  int? _processableSignature;
  int _tableRevision = 0;
  Set<int> _cachedProcessableTileIds = const {};

  String? _msg;
  String? _warningMsg;
  int _warningSerial = 0;
  int _roundGeneration = 0;
  bool _showColorBonusIntro = false;
  bool _showFinishCelebration = false;
  int _finishCelebrationSerial = 0;
  bool _endDialogVisible = false;
  bool _gameOverShown = false;
  bool _autoPlayerBusy = false;
  int _autoPlayerGeneration = 0;
  int _autoPlayerTurns = 0;
  late GameSettings _gameSettings;
  bool _initialFontScaleApplied = false;
  bool get _useGameplayAnimations =>
      _gameSettings.animations && (!_gameSettings.autoPlay || _elCount <= 3);
  // Tek native oynatıcı kullanmak, manuel taş hareketlerinde üst üste açılan
  // düşük gecikmeli ses tamponlarının oturum boyunca birikmesini engeller.
  final AudioPlayer _soundPlayer = AudioPlayer();
  int _soundSerial = 0;
  final Map<_GameSound, int> _lastSoundMicros = {};
  final Stopwatch _soundClock = Stopwatch()..start();

  Future<void> _openGameSettings() async {
    _cancelTimedPlayerTurn();
    final updated = await showGeneralDialog<GameSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Oyun ayarlarını kapat',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => GameSettingsDialog(
        initial: _gameSettings,
        launchConfig: widget.launchConfig,
        onChanged: (settings) {
          if (!mounted) return;
          setGameVibrationEnabled(settings.vibration);
          final enableAutoPlay = !_gameSettings.autoPlay && settings.autoPlay;
          setState(() {
            _gameSettings = settings;
            if (!settings.autoPlay && _autoPlayerBusy) {
              _autoPlayerGeneration++;
              _autoPlayerBusy = false;
              if (_turn == 0) _botBusy = false;
            }
          });
          if (enableAutoPlay) {
            setState(_arrangeAutoPlayerRack);
            _scheduleAutoPlayer();
          }
        },
        onRestart: (settings) {
          Navigator.of(context, rootNavigator: true).pop();
          setGameVibrationEnabled(settings.vibration);
          setState(() {
            _gameSettings = settings;
            _totalPenalty = 0;
            _elCount = 0;
            for (final bot in _bots) {
              bot.penalty = 0;
            }
            _startNewRound();
          });
        },
        onExitToMenu: () => Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst),
      ),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(
            TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween(begin: 1.05, end: 0.988),
                weight: 52,
              ),
              TweenSequenceItem(
                tween: Tween(begin: 0.988, end: 1.008),
                weight: 28,
              ),
              TweenSequenceItem(tween: Tween(begin: 1.008, end: 1), weight: 20),
            ]),
          ),
          child: child,
        ),
      ),
    );
    if (updated != null && mounted) {
      setGameVibrationEnabled(updated.vibration);
      setState(() => _gameSettings = updated);
    }
    if (mounted) _startTimedPlayerTurn();
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _gameSettings = GameSettings(vibration: gameVibrationEnabled);
    unawaited(prewarmGameAudio());
    _startNewRound();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialFontScaleApplied) return;
    _initialFontScaleApplied = true;
    final inheritedScale = MediaQuery.textScalerOf(context).scale(1);
    _gameSettings = _gameSettings.copyWith(fontScale: inheritedScale);
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _cancelTimedPlayerTurn();
    _botThinkTimer?.cancel();
    _messageTimer?.cancel();
    _warningTimer?.cancel();
    _roundGeneration++;
    _autoPlayerGeneration++;
    _soundSerial++;
    unawaited(_soundPlayer.dispose());
    unawaited(AudioCache.instance.clearAll());
    _gameAudioWarmup = null;
    if (!kIsWeb) _BotWorker.instance.shutdown();
    BotEngine.clearCaches();
    _RunMeldGrid.clearLayoutCache();
    _rackDragVisual.dispose();
    _rackPushPreview.dispose();
    _tableTileMotion.dispose();
    _playerTurnSeconds.dispose();
    super.dispose();
  }

  // ── Yeni El Başlat ────────────────────────────────────────────────────
  void _startNewRound() {
    final hadPreviousRound = _elCount > 0;
    _roundGeneration++;
    final currentRoundGeneration = _roundGeneration;
    _elCount++;
    _dealTimer?.cancel();
    _cancelTimedPlayerTurn();
    _botThinkTimer?.cancel();
    _messageTimer?.cancel();
    _warningTimer?.cancel();
    _warningSerial++;
    _msg = null;
    _warningMsg = null;
    _rackAnalysisSignature = null;
    _processableSignature = null;
    _cachedProcessableTileIds = const {};
    _cachedRackPerPoints = 0;
    _cachedRackPairCount = 0;
    _minimumStandardOpeningScore = 101;
    _minimumPairOpeningCount = 5;
    if (_isColorBonusMode) {
      _roundBonusColor =
          TileColor.values[Random().nextInt(TileColor.values.length)];
    }
    _showColorBonusIntro = _isColorBonusMode;
    _pendingGridDragPosition = null;
    _pendingRackDragTilt = 0;
    _pendingRackDragLift = 0;
    _RunMeldGrid.clearLayoutCache();
    BotEngine.clearCaches();
    if (hadPreviousRound && !kIsWeb) {
      final workerReleased = _BotWorker.instance.releaseIfIdle();
      if (!workerReleased) unawaited(_BotWorker.instance.clearCaches());
      _soundSerial++;
      unawaited(_soundPlayer.stop());
      _lastSoundMicros.clear();

      // Yeni deste oluşturulmadan önce eski ele ait bütün güçlü referansları bırak.
      // Böylece kısa bir süre için iki elin taşları ve perleri birlikte tutulmaz.
      _deck.clear();
      _rack.clear();
      _rackSlots = List<int?>.filled(_rackSlotCount, null);
      _indicator = null;
      _discarded = null;
      for (final pile in _discardPiles) {
        pile.clear();
      }
      _tableMetds.clear();
      _processedMoves.clear();
      for (final bot in _bots) {
        bot.hand = <Tile>[];
      }

      // Yeni el ilk karesini çizdikten sonra eski Dart nesneleri, kullanılmayan
      // resim önbelleği ve native tamponlar birlikte bırakılır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || currentRoundGeneration != _roundGeneration) return;
        unawaited(requestMemoryTrim(aggressive: true));
      });
    }
    _showRackPairCount = false;
    _deck = buildDeck();

    // Gösterge her zaman 1-13 arasındaki gerçek taşlardan seçilir.
    final indicatorIndex = _deck.lastIndexWhere((tile) => !tile.isFakeOkey);
    _indicator = _deck.removeAt(indicatorIndex);

    // Okey = gösterge rengi, gösterge+1 sayı
    final okeyNum = Rules.okeyNumberForIndicator(_indicator!.number);
    final okeyCol = _indicator!.color;
    for (final t in _deck) {
      if (t.isFakeOkey) {
        // Sahte okey joker değildir; bu elde okey olan taşın normal kopyasıdır.
        // Görselde yıldız olarak kalır, per hesaplarında renk/sayı taşır.
        t.number = okeyNum;
        t.color = okeyCol;
        t.isOkey = false;
      } else {
        t.isOkey = t.number == okeyNum && t.color == okeyCol;
      }
    }

    _startingPlayer = widget.startingPlayer ?? Random().nextInt(4);

    // Önce herkese 21, ardından başlayan oyuncuya 22. taş dağıtılır.
    _rack = List<Tile>.from(_deck.take(21));
    _deck = _deck.sublist(21);
    for (final bot in _bots) {
      bot.hand = List<Tile>.from(_deck.take(21));
      _deck = _deck.sublist(21);
      bot.hasOpened = false;
      bot.openType = '';
      bot.turnsPlayed = 0;
    }
    final extraTile = _deck.removeLast();
    if (_startingPlayer == 0) {
      _rack.add(extraTile);
    } else {
      _bots[_startingPlayer - 1].hand.add(extraTile);
    }
    _compactRackSlots();
    if (_gameSettings.autoPlay) _arrangeAutoPlayerRack();
    for (final bot in _bots) {
      bot.tileCount = bot.hand.length;
    }

    _tableMetds = [];
    _markTableChanged();
    _discarded = null;
    _discardPiles = List.generate(4, (_) => <Tile>[]);
    _playerOpened = false;
    _playerOpenType = '';
    _drawnThisTurn = false;
    _tookDiscard = false;
    _takenDiscardTile = null;
    _botBusy = false;
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
    _draggingProcessableTile = false;
    _drawAttentionTileId = null;
    _botDiscardMotion = null;
    _tableTileMotion.value = null;
    _uiMode = 'normal';
    _processedMoves.clear();
    _gameOverShown = false;
    _autoPlayerBusy = false;
    _autoPlayerGeneration++;
    _autoPlayerTurns = 0;
    _showFinishCelebration = false;
    _finishCelebrationSerial++;
    _endDialogVisible = false;

    // Her el rastgele bir koltuktan başlar; başlayan oyuncu zaten 22 taşlıdır.
    _turn = _startingPlayer;
    _drawnThisTurn = _turn == 0;
    final openingTurn = _turn;
    if (_useGameplayAnimations) {
      final serial = ++_dealAnimationCounter;
      _dealAnimationSerial = serial;
      _dealInProgress = true;
      _dealTimer?.cancel();
      _dealTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted || _dealAnimationSerial != serial) return;
        _dealTimer = null;
        setState(() {
          _dealAnimationSerial = null;
          _dealInProgress = false;
        });
        if (openingTurn > 0 && _turn == openingTurn && !_botBusy) {
          _runBot(_turn - 1, alreadyHasExtraTile: true);
        } else if (openingTurn == 0) {
          _startTimedPlayerTurn();
          _scheduleAutoPlayer(alreadyHasExtraTile: true);
        }
      });
    } else {
      _dealTimer?.cancel();
      _dealTimer = null;
      _dealAnimationSerial = null;
      _dealInProgress = false;
    }
    if (_turn > 0 && !_dealInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _turn == openingTurn && !_botBusy) {
          _runBot(_turn - 1, alreadyHasExtraTile: true);
        }
      });
    } else if (_turn == 0 && !_dealInProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startTimedPlayerTurn();
          _scheduleAutoPlayer(alreadyHasExtraTile: true);
        }
      });
    }
  }

  void _cancelTimedPlayerTurn() {
    _playerTurnGeneration++;
    _playerTurnTimer?.cancel();
    _playerTurnTimer = null;
  }

  void _startTimedPlayerTurn() {
    _cancelTimedPlayerTurn();
    if (!_isTimedMode ||
        !mounted ||
        _turn != 0 ||
        _dealInProgress ||
        _gameOverShown ||
        _gameSettings.autoPlay) {
      return;
    }
    final generation = _playerTurnGeneration;
    _playerTurnSeconds.value = 7;
    _playerTurnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          generation != _playerTurnGeneration ||
          _turn != 0 ||
          _dealInProgress ||
          _gameOverShown) {
        timer.cancel();
        return;
      }
      final remaining = _playerTurnSeconds.value - 1;
      _playerTurnSeconds.value = remaining;
      if (remaining > 0) return;
      timer.cancel();
      _playerTurnTimer = null;
      _handleTimedPlayerTimeout(generation);
    });
  }

  List<Tile> _timedDiscardCandidates() {
    final protectedIds = RackSolver.standardMelds(_rack)
        .expand((group) => group)
        .map((tile) => tile.id)
        .toSet();
    var candidates = _rack
        .where((tile) => !protectedIds.contains(tile.id) && !tile.isOkey)
        .toList();
    if (candidates.isEmpty) {
      candidates = _rack
          .where((tile) => !protectedIds.contains(tile.id))
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = _rack.where((tile) => !tile.isOkey).toList();
    }
    return candidates.isEmpty ? List<Tile>.from(_rack) : candidates;
  }

  void _handleTimedPlayerTimeout(int generation) {
    if (!mounted ||
        generation != _playerTurnGeneration ||
        _turn != 0 ||
        _gameOverShown) {
      return;
    }
    if (!_drawnThisTurn) _drawFromDeck();
    if (!mounted ||
        _turn != 0 ||
        !_drawnThisTurn ||
        _gameOverShown ||
        _rack.isEmpty) {
      return;
    }
    final candidates = _timedDiscardCandidates();
    final tile = candidates[Random().nextInt(candidates.length)];
    setState(() {
      for (final item in _rack) {
        item.selected = item.id == tile.id;
      }
    });
    _discardTile(timedOut: true);
    if (mounted) {
      _msg_('Süre doldu. Per dışında kalan bir taş otomatik atıldı.');
    }
  }

  void _beginTableTileMotion(
    _TableTileMotionKind kind,
    Iterable<Tile> tiles, {
    int playerIndex = 0,
    Alignment? targetAlignment,
  }) {
    final isBotMotion = playerIndex > 0;
    final visibleTileLimit = switch (kind) {
      _TableTileMotionKind.drawDeck || _TableTileMotionKind.drawDiscard => 1,
      _TableTileMotionKind.process => isBotMotion ? 1 : 2,
      _TableTileMotionKind.open => isBotMotion ? 1 : 4,
    };
    final visibleTiles = tiles.take(visibleTileLimit).toList();
    if (visibleTiles.isEmpty) return;
    if (kind == _TableTileMotionKind.open ||
        kind == _TableTileMotionKind.process) {
      _playInteractionFeedback(
        strong: kind == _TableTileMotionKind.open,
        sound: _GameSound.arrange,
      );
    }
    if (!_useGameplayAnimations) return;
    final serial = ++_tableTileMotionSerial;
    _tableTileMotion.value = _TableTileMotion(
      tiles: visibleTiles,
      kind: kind,
      playerIndex: playerIndex,
      targetAlignment: targetAlignment,
      serial: serial,
    );
    final clearDelay = switch (kind) {
      _TableTileMotionKind.drawDeck || _TableTileMotionKind.drawDiscard =>
        Duration(milliseconds: isBotMotion ? 150 : 240),
      _TableTileMotionKind.process => Duration(
        milliseconds: isBotMotion ? 150 : 250,
      ),
      _TableTileMotionKind.open => Duration(
        milliseconds: isBotMotion ? 180 : 330,
      ),
    };
    Future.delayed(clearDelay, () {
      if (!mounted || _tableTileMotion.value?.serial != serial) return;
      _tableTileMotion.value = null;
    });
  }

  // ── Mesaj ─────────────────────────────────────────────────────────────
  void _msg_(
    String m, {
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    if (_msg == m) return;
    _warningTimer?.cancel();
    _warningTimer = null;
    _messageTimer?.cancel();
    setState(() {
      _warningMsg = null;
      _msg = m;
    });
    _messageTimer = Timer(duration, () {
      _messageTimer = null;
      if (mounted && _msg == m) setState(() => _msg = null);
    });
  }

  void _warn_(String message) {
    final serial = ++_warningSerial;
    _messageTimer?.cancel();
    _messageTimer = null;
    _warningTimer?.cancel();
    setState(() {
      _msg = null;
      _warningMsg = message;
    });
    _warningTimer = Timer(const Duration(milliseconds: 2400), () {
      _warningTimer = null;
      if (!mounted || serial != _warningSerial) return;
      setState(() => _warningMsg = null);
    });
  }

  // ── Taş Seç / Seçimi Kaldır ───────────────────────────────────────────
  void _compactRackSlots() {
    _rackSlots = List<int?>.filled(_rackSlotCount, null);
    final firstRowCount = (_rack.length / 2).ceil();
    for (int index = 0; index < _rack.length; index++) {
      final slot = index < firstRowCount
          ? index
          : _rackRowLength + index - firstRowCount;
      _rackSlots[slot] = _rack[index].id;
    }
  }

  bool _placeInRackSlot(Tile tile, [int? requestedSlot]) {
    final hasRequestedSlot =
        requestedSlot != null &&
        requestedSlot >= 0 &&
        requestedSlot < _rackSlots.length;
    final isolatedSlot = hasRequestedSlot ? requestedSlot : _isolatedRackSlot();
    final edgeSlot = hasRequestedSlot || isolatedSlot != null
        ? null
        : _emptyRackEdgeSlot();
    final targetSlot = isolatedSlot ?? edgeSlot ?? _rackSlots.indexOf(null);
    if (targetSlot >= 0) _insertRackTileAt(tile.id, targetSlot);
    return !hasRequestedSlot && isolatedSlot == null;
  }

  int? _isolatedRackSlot() {
    for (var row = 0; row < 2; row++) {
      final start = row * _rackRowLength;
      final end = start + _rackRowLength;
      for (var slot = start; slot < end; slot++) {
        if (_rackSlots[slot] != null) continue;
        final leftEmpty = slot == start || _rackSlots[slot - 1] == null;
        final rightEmpty = slot == end - 1 || _rackSlots[slot + 1] == null;
        if (leftEmpty && rightEmpty) return slot;
      }
    }
    return null;
  }

  int? _emptyRackEdgeSlot() {
    final edgeSlots = <int>[
      _rackSlotCount - 1,
      _rackRowLength - 1,
      _rackRowLength,
      0,
      _rackSlotCount - 2,
      _rackRowLength - 2,
      _rackRowLength + 1,
      1,
    ];
    for (final slot in edgeSlots) {
      if (_rackSlots[slot] == null) return slot;
    }
    return null;
  }

  void _insertRackTileAt(int tileId, int targetIndex) {
    final target = targetIndex.clamp(0, _rackSlotCount - 1);
    if (_rackSlots[target] == null) {
      _rackSlots[target] = tileId;
      return;
    }

    var nearestEmpty = -1;
    var nearestDistance = _rackSlotCount + 1;
    for (var index = 0; index < _rackSlots.length; index++) {
      if (_rackSlots[index] != null) continue;
      final distance = (index - target).abs();
      if (distance < nearestDistance) {
        nearestEmpty = index;
        nearestDistance = distance;
      }
    }
    if (nearestEmpty == -1) return;

    if (nearestEmpty > target) {
      for (var index = nearestEmpty; index > target; index--) {
        _rackSlots[index] = _rackSlots[index - 1];
      }
    } else {
      for (var index = nearestEmpty; index < target; index++) {
        _rackSlots[index] = _rackSlots[index + 1];
      }
    }
    _rackSlots[target] = tileId;
  }

  void _clearRackSlots(Set<int> tileIds) {
    for (int index = 0; index < _rackSlots.length; index++) {
      if (tileIds.contains(_rackSlots[index])) _rackSlots[index] = null;
    }
  }

  Tile? _rackTileById(int? id) {
    if (id == null) return null;
    for (final tile in _rack) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  void _playInteractionFeedback({
    bool strong = false,
    _GameSound sound = _GameSound.place,
  }) {
    if (_gameSettings.sound) {
      final now = _soundClock.elapsedMicroseconds;
      final minimumGap = sound == _GameSound.pick ? 55000 : 80000;
      final shouldPlay =
          now - (_lastSoundMicros[sound] ?? -minimumGap) >= minimumGap;
      if (shouldPlay) _lastSoundMicros[sound] = now;
      final asset = switch (sound) {
        _GameSound.pick => 'sounds/tile_pick.wav',
        _GameSound.place => 'sounds/tile_place.wav',
        _GameSound.arrange => 'sounds/tile_arrange.wav',
      };
      if (shouldPlay) {
        final serial = ++_soundSerial;
        unawaited(() async {
          try {
            await _soundPlayer.stop();
            if (!mounted || serial != _soundSerial) return;
            await _soundPlayer.play(
              AssetSource(asset),
              volume: strong ? 0.78 : 0.62,
              mode: PlayerMode.lowLatency,
            );
          } catch (_) {
            // Ses desteği olmayan test ortamlarında oyun akışını sürdür.
          }
        }());
      }
    }
    if (_gameSettings.vibration) {
      if (strong) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _tapTile(int tileId) {
    if (_turn != 0) {
      _warn_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Taş atmadan önce taş çekmelisin.');
      return;
    }
    final tile = _rackTileById(tileId);
    if (tile != null) {
      _playInteractionFeedback(sound: _GameSound.pick);
      setState(() => tile.selected = !tile.selected);
    }
  }

  void _clearRackSelection() {
    if (!_rack.any((tile) => tile.selected)) return;
    setState(() {
      for (final tile in _rack) {
        tile.selected = false;
      }
    });
  }

  void _releaseTurnTransients() {
    _pendingGridDragPosition = null;
    _pendingRackDragTilt = 0;
    _pendingRackDragLift = 0;
    _draggingProcessableTile = false;
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
    _drawAttentionTileId = null;
    _rackAnalysisSignature = null;
    _processableSignature = null;
    _cachedProcessableTileIds = const {};
  }

  Set<int> get _selectedTileIds =>
      _rack.where((tile) => tile.selected).map((tile) => tile.id).toSet();

  List<List<Tile>> _rackGroups(Set<int> tileIds) {
    final groups = <List<Tile>>[];
    var current = <Tile>[];
    for (int index = 0; index < _rackSlots.length; index++) {
      if (index == _rackRowLength && current.isNotEmpty) {
        groups.add(current);
        current = <Tile>[];
      }
      final tile = _rackTileById(_rackSlots[index]);
      if (tile != null && tileIds.contains(tile.id)) {
        current.add(tile);
      } else if (current.isNotEmpty) {
        groups.add(current);
        current = <Tile>[];
      }
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  List<Tile> _tilesForDrag(_RackDragData data) {
    final ids = data.tileIds.isEmpty ? {data.tileId} : data.tileIds;
    return _rack.where((tile) => ids.contains(tile.id)).toList();
  }

  void _reorderRack(int tileId, int targetIndex, _RackMoveKind moveKind) {
    final from = _rackSlots.indexOf(tileId);
    if (from == -1) return;
    final target = targetIndex.clamp(0, _rackSlotCount - 1);
    if (from == target) return;
    var moved = false;
    setState(() {
      // Kaynak taşı önce kaldır. Böylece taşın bıraktığı gerçek boşluk da
      // zincirleme yerleştirme hesabına dahil edilir.
      _rackSlots[from] = null;
      if (_rackSlots[target] == null) {
        _rackSlots[target] = tileId;
        moved = true;
      } else if (moveKind == _RackMoveKind.insert) {
        // Hedef satırdaki herhangi bir boşluk yeterlidir. Arada kaç taş
        // olduğuna bakılmaz; satır tamamen doluysa araya sokma yapılmaz.
        final vacancy = _nearestRackVacancy(_rackSlots, target);
        if (vacancy < 0) {
          _rackSlots[from] = tileId;
          return;
        }
        final destination = vacancy < target ? target - 1 : target;
        if (vacancy < destination) {
          for (var index = vacancy; index < destination; index++) {
            _rackSlots[index] = _rackSlots[index + 1];
          }
        } else {
          for (var index = vacancy; index > destination; index--) {
            _rackSlots[index] = _rackSlots[index - 1];
          }
        }
        _rackSlots[destination] = tileId;
        moved = true;
      } else {
        final vacancy = _rackPushVacancy(_rackSlots, from, target);
        if (vacancy < 0) {
          _rackSlots[from] = tileId;
          return;
        }
        if (vacancy > target) {
          for (var index = vacancy; index > target; index--) {
            _rackSlots[index] = _rackSlots[index - 1];
          }
        } else {
          for (var index = vacancy; index < target; index++) {
            _rackSlots[index] = _rackSlots[index + 1];
          }
        }
        _rackSlots[target] = tileId;
        moved = true;
      }
      if (moved) _rackAnalysisSignature = null;
    });
    if (moved) _playInteractionFeedback(sound: _GameSound.place);
  }

  int get _currentRackSignature => Object.hash(
    Object.hashAll(
      _rack.map(
        (tile) => Object.hash(tile.id, tile.number, tile.color, tile.isOkey),
      ),
    ),
    Object.hashAll(_rackSlots),
  );

  void _ensureRackAnalysis() {
    final signature = _currentRackSignature;
    if (_rackAnalysisSignature == signature) return;
    final allIds = _rack.map((tile) => tile.id).toSet();
    final groups = _rackGroups(allIds);
    _cachedRackPerPoints = _isColorBonusMode
        ? Rules.coloredOpeningValue(groups, _roundBonusColor)
        : Rules.validMeldTotal(groups);
    _cachedRackPairCount = RackSolver.pairs(_rack).length;
    _rackAnalysisSignature = signature;
  }

  int get _rackPerPoints {
    _ensureRackAnalysis();
    return _cachedRackPerPoints;
  }

  int get _rackPairCount {
    _ensureRackAnalysis();
    return _cachedRackPairCount;
  }

  int get _currentOkeyNumber =>
      Rules.okeyNumberForIndicator(_indicator!.number);

  int get _rackRemainingPoints =>
      Rules.penaltyFor(_rack, fakeOkeyValue: _currentOkeyNumber);

  // ── Desteden Taş Çek ─────────────────────────────────────────────────
  void _drawFromDeck([int? targetSlot]) {
    if (_turn != 0) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (_drawnThisTurn) {
      _msg_('Bu turda zaten taş çektin.');
      return;
    }
    if (_deck.isEmpty) {
      _endRoundNoDeck();
      return;
    }

    setState(() {
      final tile = _deck.removeLast();
      _rack.add(tile);
      final usedInnerGap = _placeInRackSlot(tile, targetSlot);
      _drawAttentionTileId = usedInnerGap ? tile.id : null;
      if (usedInnerGap) _drawAttentionSerial++;
      _drawnThisTurn = true;
      _tookDiscard = false;
    });
    _playInteractionFeedback(sound: _GameSound.pick);
  }

  // ── Atılan Taşı Al (soldan çek) ───────────────────────────────────────
  void _takeDiscarded([int? targetSlot]) {
    if (_turn != 0) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (_drawnThisTurn) {
      _msg_('Bu turda zaten taş çektin.');
      return;
    }
    if (_discarded == null) {
      _msg_('Atılan taş yok.');
      return;
    }

    setState(() {
      _takenDiscardTile = _discarded;
      final tile = _discarded!;
      _rack.add(tile);
      final usedInnerGap = _placeInRackSlot(tile, targetSlot);
      _drawAttentionTileId = usedInnerGap ? tile.id : null;
      if (usedInnerGap) _drawAttentionSerial++;
      if (_discardPiles[3].isNotEmpty && _discardPiles[3].last.id == tile.id) {
        _discardPiles[3].removeLast();
      }
      _discarded = null;
      _drawnThisTurn = true;
      _tookDiscard = true;
    });
    _playInteractionFeedback(sound: _GameSound.pick);
  }

  void _returnTakenDiscard() {
    final tile = _takenDiscardTile;
    if (_turn != 0 || !_tookDiscard || tile == null) return;
    if (_processedMoves.isNotEmpty) {
      _msg_('Taşı geri bırakmadan önce işlenen taşları geri al.');
      return;
    }
    if (!_rack.any((item) => item.id == tile.id)) {
      _msg_('Alınan taş artık ıstakada olmadığı için geri bırakılamaz.');
      return;
    }

    setState(() {
      _clearRackSlots({tile.id});
      _rack.removeWhere((item) => item.id == tile.id);
      tile.selected = false;
      _discarded = tile;
      _addDiscardToPile(3, tile);
      _drawnThisTurn = false;
      _tookDiscard = false;
      _takenDiscardTile = null;
    });
    _playInteractionFeedback();
    _msg_('Taş geri bırakıldı. Artık ortadan taş çekebilirsin.');
  }

  // ── Taş At ────────────────────────────────────────────────────────────
  void _discardTile({
    bool celebrateCenterFinish = false,
    bool timedOut = false,
  }) {
    if (_turn != 0) {
      _warn_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Taş atmadan önce taş çekmelisin.');
      return;
    }
    if (_tookDiscard && !_playerOpened && !timedOut) {
      _msg_('Soldan aldığın taşı açılışta kullan veya geri bırak.');
      return;
    }

    final sel = _rack.where((t) => t.selected).toList();
    if (sel.length != 1) {
      _msg_('Atmak için tam 1 taş seç.');
      return;
    }

    final tile = sel.first;
    _cancelTimedPlayerTurn();

    // Atılan taş işleme cezası kontrolü
    if (_rack.length > 1 && _checkDiscardPenalty(tile)) {
      _totalPenalty += 101;
      _msg_('101 CEZA! Atılan taş masaya işlenebilirdi.');
    }

    setState(() {
      // Taş atıldığı anda o turdaki işlemeler kesinleşir ve geri alınamaz.
      _processedMoves.clear();
      _clearRackSlots({tile.id});
      _rack.removeWhere((t) => t.selected);
      // Seçim görünümü yalnızca ıstakaya aittir. Taş atma alanına
      // taşınırken mavi çerçeve ve yukarı kayma durumunu taşımamalı.
      tile.selected = false;
      _discarded = tile;
      _addDiscardToPile(0, tile);
      _drawnThisTurn = false;
      _tookDiscard = false;
      _takenDiscardTile = null;
    });
    _releaseTurnTransients();
    _playInteractionFeedback(strong: true);

    if (_rack.isEmpty) {
      if (celebrateCenterFinish && _useGameplayAnimations) {
        final serial = ++_finishCelebrationSerial;
        setState(() {
          _showFinishCelebration = true;
          _botBusy = true;
        });
        Future.delayed(const Duration(milliseconds: 920), () {
          if (!mounted || serial != _finishCelebrationSerial) return;
          setState(() => _showFinishCelebration = false);
          _endRoundPlayerWins();
        });
        return;
      }
      _endRoundPlayerWins();
      return;
    }
    _nextTurn();
  }

  bool _checkDiscardPenalty(Tile tile) {
    for (final meld in _tableMetds) {
      final test = [...meld.tiles, tile];
      if (meld.type == 'seri' && Rules.isValidRun(test)) return true;
      if (meld.type == 'grup' && Rules.isValidGroup(test)) return true;
    }
    return false;
  }

  // ── El Aç (standart perler: seri + aynı sayı grubu) ───────────────────
  void _openStandardMelds(
    Set<int> tileIds, {
    List<List<Tile>>? detectedGroups,
  }) {
    if (_turn != 0) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _msg_('Önce taş çekmelisin.');
      return;
    }
    if (_playerOpened && _playerOpenType == 'cift') {
      _msg_('Çift açmışsın, seri açamazsın.');
      return;
    }

    final groups = detectedGroups ?? _rackGroups(tileIds);
    final selected = groups.expand((group) => group).toList();
    if (selected.length < 3 || groups.isEmpty) {
      _msg_('En az 3 bitişik taş seç veya masaya sürükle.');
      return;
    }
    final types = groups.map(Rules.meldType).toList();
    if (types.any((type) => type != 'seri' && type != 'grup')) {
      _msg_('Her per en az 3 taş olmalı: seri veya farklı renkli grup.');
      return;
    }
    final openingValue = _isColorBonusMode
        ? Rules.coloredOpeningValue(groups, _roundBonusColor)
        : Rules.validMeldTotal(groups);
    if (!_playerOpened && openingValue < _minimumStandardOpeningScore) {
      _msg_(
        'İlk açılıştaki tüm perlerin toplamı en az '
        '$_minimumStandardOpeningScore olmalı.\n'
        'Seçili toplam: $openingValue',
      );
      return;
    }
    if (selected.length >= _rack.length) {
      _msg_('Bitmek için elinde atacağın son bir taş bırakmalısın.');
      return;
    }

    // Soldan taş aldıysa kullanılmış olmalı
    if (_tookDiscard && _takenDiscardTile != null) {
      if (!tileIds.contains(_takenDiscardTile!.id)) {
        _msg_('Soldan aldığın taşı bu açılımda kullanmak zorundasın.');
        return;
      }
    }

    setState(() {
      for (final tile in selected) {
        tile.selected = false;
      }
      for (int i = 0; i < groups.length; i++) {
        final type = types[i]!;
        _tableMetds.add(
          Meld(tiles: Rules.orderedMeld(groups[i], type), type: type),
        );
      }
      _markTableChanged();
      _clearRackSlots(tileIds);
      _rack.removeWhere((tile) => tileIds.contains(tile.id));
      if (!_playerOpened) {
        _recordProgressiveOpening('seri', openingValue);
      }
      _playerOpened = true;
      _playerOpenType = 'seri';
      _tookDiscard = false;
      _takenDiscardTile = null;
      _beginTableTileMotion(_TableTileMotionKind.open, selected);
    });
    _msg_('${groups.length} per açıldı! ✓ ($openingValue puan)');
  }

  // ── El Aç (Çift) ─────────────────────────────────────────────────────
  List<List<Tile>>? _pairGroups(Set<int> tileIds) {
    final selected = _rack.where((tile) => tileIds.contains(tile.id)).toList();
    if (selected.isEmpty || selected.length.isOdd) return null;

    final pairs = RackSolver.pairs(selected);
    final pairedIds = pairs
        .expand((pair) => pair)
        .map((tile) => tile.id)
        .toSet();
    return pairedIds.length == selected.length ? pairs : null;
  }

  void _openPairs(Set<int> tileIds, {List<List<Tile>>? detectedPairs}) {
    if (_turn != 0) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _msg_('Önce taş çekmelisin.');
      return;
    }
    final layingPairsAfterStandard = _playerOpened && _playerOpenType == 'seri';
    if (layingPairsAfterStandard &&
        !Rules.canLayPairsAfterStandard(_tableMetds)) {
      _msg_('Masada çift açan oyuncu olmadığı için çift açamazsın.');
      return;
    }

    final selected = _rack.where((tile) => tileIds.contains(tile.id)).toList();
    if (selected.length < 2 || selected.length.isOdd) {
      _msg_('Çift sayıda taş seç (2\'li gruplar).');
      return;
    }
    final pairs = detectedPairs ?? _pairGroups(tileIds);
    if (pairs == null) {
      _msg_('Seçimde eşleşmeyen çift taşı var.');
      return;
    }
    if (!_playerOpened && pairs.length < _minimumPairOpeningCount) {
      _msg_(
        'İlk çift açılış için en az $_minimumPairOpeningCount çift gerekli. '
        '(${pairs.length} çift seçili)',
      );
      return;
    }
    if (selected.length >= _rack.length) {
      _msg_('Bitmek için elinde atacağın son bir taş bırakmalısın.');
      return;
    }
    if (_tookDiscard && _takenDiscardTile != null) {
      if (!tileIds.contains(_takenDiscardTile!.id)) {
        _msg_('Soldan aldığın taşı bu açılımda kullanmak zorundasın.');
        return;
      }
    }

    final wasAlreadyOpened = _playerOpened;
    final tookDiscardBefore = _tookDiscard;
    final takenDiscardTileBefore = _takenDiscardTile;
    final originalSlots = <int, int>{};
    for (final tile in selected) {
      final slot = _rackSlots.indexOf(tile.id);
      if (slot >= 0) originalSlots[tile.id] = slot;
    }
    setState(() {
      for (final tile in selected) {
        tile.selected = false;
      }
      for (final p in pairs) {
        final meld = Meld(tiles: List.from(p), type: 'cift');
        _tableMetds.add(meld);
        if (wasAlreadyOpened) {
          _processedMoves.add(
            _ProcessedMove(
              meld: meld,
              previousMeldTiles: const [],
              addedTiles: List<Tile>.from(p),
              removeMeldOnUndo: true,
              originalSlots: {
                for (final tile in p)
                  if (originalSlots.containsKey(tile.id))
                    tile.id: originalSlots[tile.id]!,
              },
              tookDiscardBefore: tookDiscardBefore,
              takenDiscardTileBefore: takenDiscardTileBefore,
            ),
          );
        }
      }
      _markTableChanged();
      _clearRackSlots(tileIds);
      _rack.removeWhere((tile) => tileIds.contains(tile.id));
      if (!wasAlreadyOpened) {
        _recordProgressiveOpening('cift', pairs.length);
      }
      _playerOpened = true;
      if (!layingPairsAfterStandard) _playerOpenType = 'cift';
      _tookDiscard = false;
      _takenDiscardTile = null;
      _beginTableTileMotion(
        wasAlreadyOpened
            ? _TableTileMotionKind.process
            : _TableTileMotionKind.open,
        selected,
        targetAlignment: wasAlreadyOpened ? const Alignment(0, -0.18) : null,
      );
    });
    _msg_(
      wasAlreadyOpened
          ? '${pairs.length} çift, açık çift alanına işlendi! ✓'
          : '${pairs.length} çift açıldı! ✓',
    );
  }

  // ── İşleme (masadaki perde taş ekle) ─────────────────────────────────
  bool _meldAcceptsTiles(Meld meld, Iterable<Tile> tiles) {
    return Rules.canAddToMeld(meld, tiles);
  }

  bool _meldCanUseTiles(Meld meld, Iterable<Tile> tiles) {
    final candidates = tiles.toList();
    return _meldAcceptsTiles(meld, candidates) ||
        (candidates.length == 1 &&
            Rules.okeyReplacementIndex(meld, candidates.single) != null);
  }

  Set<int> get _eligibleMeldIndexes {
    final selected = _rack.where((tile) => tile.selected).toList();
    return {
      for (var index = 0; index < _tableMetds.length; index++)
        if (_meldCanUseTiles(_tableMetds[index], selected)) index,
    };
  }

  Set<int> get _processableTileIds {
    if (_rack.isEmpty || _tableMetds.isEmpty) return const <int>{};
    final signature = Object.hash(_currentRackSignature, _tableRevision);
    if (_processableSignature == signature) return _cachedProcessableTileIds;
    _cachedProcessableTileIds = Set<int>.unmodifiable({
      for (final tile in _rack)
        if (_tableMetds.any((meld) => _meldCanUseTiles(meld, [tile]))) tile.id,
    });
    _processableSignature = signature;
    return _cachedProcessableTileIds;
  }

  void _addDiscardToPile(int seat, Tile tile) {
    final pile = _discardPiles[seat];
    pile.add(tile);
    // Arayüz yalnızca son taşı gösterir. Uzun oyunlarda görünmeyen geçmişi
    // sınırsız tutmak gereksiz bellek ve liste maliyeti oluşturur.
    const retainedTiles = 8;
    if (pile.length > retainedTiles) {
      pile.removeRange(0, pile.length - retainedTiles);
    }
  }

  void _markTableChanged() {
    _tableRevision++;
    _processableSignature = null;
  }

  int _automaticTargetMeldIndex(Tile tile) {
    return Rules.preferredMeldIndexForTile(_tableMetds, tile);
  }

  Alignment _motionTargetForMeld(Meld meld) => switch (meld.type) {
    'seri' => const Alignment(-0.56, -0.08),
    'cift' => const Alignment(0, -0.18),
    _ => const Alignment(0.56, -0.08),
  };

  void _startGridDragZoom(_RackDragData data) {
    _playInteractionFeedback(sound: _GameSound.pick);
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
    _pendingRackDragTilt = 0;
    _pendingRackDragLift = 0;
    _activeRackDragData = data;
    _lastRackDragGlobalPosition = null;
    final draggedIds = data.tileIds.isEmpty ? {data.tileId} : data.tileIds;
    _draggingProcessableTile = draggedIds.any(_processableTileIds.contains);
    if (!_draggingProcessableTile) {
      _pendingGridDragPosition = null;
      _rackDragVisual.value = const _RackDragVisualState();
    }
  }

  void _updateGridDragZoom(_RackDragData _, DragUpdateDetails details) {
    final targetTilt = (details.delta.dx * 0.035).clamp(-0.18, 0.18);
    final tilt = _pendingRackDragTilt * 0.55 + targetTilt.toDouble() * 0.45;
    Offset? localPosition;
    var lift = 0.0;
    final renderObject = _meldGridKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      // İşlenebilir taşın görseli ve hedef noktası sürükleme boyunca aynı sabit
      // uzaklıkta kalır; masaya girerken hit-test konumu sıçramaz.
      lift = _draggingProcessableTile ? _meldDragLift : 0;
      // Grid ipucu parmağı değil, feedback içinde gerçekten görünen taşın
      // merkezini takip eder. Taş yukarı kaldırıldığında büyüteç de aynı ölçüde
      // yukarı gider ve kullanıcı hangi hücreyi hedeflediğini doğrudan görür.
      final tileCenter = renderObject.globalToLocal(
        details.globalPosition.translate(0, -lift),
      );
      // Manuel islemede hedefi parmak yerine ekranda gorunen tasin merkezi
      // belirler. Buyutec ve kesin birakma ayni koordinati kullanir.
      _lastRackDragGlobalPosition = details.globalPosition.translate(0, -lift);
      final inside =
          tileCenter.dx >= 0 &&
          tileCenter.dy >= 0 &&
          tileCenter.dx <= renderObject.size.width &&
          tileCenter.dy <= renderObject.size.height;
      if (_gameSettings.gridMagnifier && _draggingProcessableTile && inside) {
        const positionStep = 12.0;
        localPosition = Offset(
          (tileCenter.dx / positionStep).round() * positionStep,
          (tileCenter.dy / positionStep).round() * positionStep,
        );
      }
    }
    _lastRackDragGlobalPosition ??= details.globalPosition;
    final steppedTilt = (tilt / 0.025).round() * 0.025;
    _scheduleDragVisualFrame(localPosition, steppedTilt, lift);
  }

  void _scheduleDragVisualFrame(
    Offset? gridPosition,
    double rackTilt,
    double rackLift,
  ) {
    _pendingGridDragPosition = gridPosition;
    _pendingRackDragTilt = rackTilt;
    _pendingRackDragLift = rackLift;
    final nowMicros = _dragVisualUpdateClock.elapsedMicroseconds;
    if (nowMicros - _lastDragVisualUpdateMicros < 66000) return;
    _lastDragVisualUpdateMicros = nowMicros;
    if (_dragVisualFrameScheduled) return;
    _dragVisualFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _dragVisualFrameScheduled = false;
      if (!mounted) return;
      final current = _rackDragVisual.value;
      if (current.gridPosition != _pendingGridDragPosition ||
          current.tilt != _pendingRackDragTilt ||
          current.lift != _pendingRackDragLift) {
        _rackDragVisual.value = _RackDragVisualState(
          gridPosition: _pendingGridDragPosition,
          tilt: _pendingRackDragTilt,
          lift: _pendingRackDragLift,
        );
      }
    });
  }

  void _endGridDragZoom() {
    final dragData = _activeRackDragData;
    final globalPosition = _lastRackDragGlobalPosition;
    final discardRenderObject = _playerDiscardTargetKey.currentContext
        ?.findRenderObject();
    if (dragData != null &&
        globalPosition != null &&
        discardRenderObject is RenderBox &&
        discardRenderObject.hasSize) {
      final origin = discardRenderObject.localToGlobal(Offset.zero);
      final targetRect = (origin & discardRenderObject.size).inflate(28);
      if (targetRect.contains(globalPosition)) {
        _dropToDiscard(dragData);
      }
    }
    _draggingProcessableTile = false;
    _activeRackDragData = null;
    _lastRackDragGlobalPosition = null;
    _pendingGridDragPosition = null;
    _pendingRackDragTilt = 0;
    _pendingRackDragLift = 0;
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
  }

  bool get _canLayPairsAfterStandard =>
      _playerOpened &&
      _playerOpenType == 'seri' &&
      Rules.canLayPairsAfterStandard(_tableMetds);

  bool _canDropOnMeld(int meldIndex, _RackDragData data) {
    if (!_playerOpened || _turn != 0 || !_drawnThisTurn) return false;
    return _meldCanUseTiles(_tableMetds[meldIndex], _tilesForDrag(data));
  }

  bool _canLayTilesInPairArea(Iterable<Tile> tiles) {
    if (_turn != 0 || !_drawnThisTurn) return false;
    final candidates = tiles.toList();
    if (candidates.length < 2 || candidates.length.isOdd) return false;
    if (candidates.length >= _rack.length) return false;
    final candidateIds = candidates.map((tile) => tile.id).toSet();
    final pairs = _pairGroups(candidateIds);
    if (pairs == null) return false;
    if (!_playerOpened && pairs.length < _minimumPairOpeningCount) return false;
    if (_playerOpened &&
        _playerOpenType == 'seri' &&
        !Rules.canLayPairsAfterStandard(_tableMetds)) {
      return false;
    }
    if (_tookDiscard &&
        _takenDiscardTile != null &&
        !candidateIds.contains(_takenDiscardTile!.id)) {
      return false;
    }
    return true;
  }

  int _pairReplacementTarget(Iterable<Tile> tiles) {
    if (!_playerOpened || _turn != 0 || !_drawnThisTurn) return -1;
    final candidates = tiles.toList();
    if (candidates.length != 1 || candidates.length >= _rack.length) return -1;
    for (var index = 0; index < _tableMetds.length; index++) {
      final meld = _tableMetds[index];
      if (meld.type == 'cift' &&
          Rules.okeyReplacementIndex(meld, candidates.single) != null) {
        return index;
      }
    }
    return -1;
  }

  bool _canDropOnPairArea(_RackDragData data) {
    final tiles = _tilesForDrag(data);
    return _pairReplacementTarget(tiles) >= 0 || _canLayTilesInPairArea(tiles);
  }

  void _dropOnPairArea(_RackDragData data) {
    final tiles = _tilesForDrag(data);
    final replacementTarget = _pairReplacementTarget(tiles);
    if (replacementTarget >= 0) {
      _tryAddToMeld(replacementTarget, tiles.map((tile) => tile.id).toSet());
      return;
    }
    if (!_canLayTilesInPairArea(tiles)) return;
    final ids = tiles.map((tile) => tile.id).toSet();
    _openPairs(ids, detectedPairs: _pairGroups(ids));
  }

  void _enterAddMode() {
    if (_turn != 0 || _botBusy) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (!_playerOpened) {
      _msg_('Önce el açman gerekiyor.');
      return;
    }
    if (!_drawnThisTurn) {
      _msg_('Önce taş çekmelisin.');
      return;
    }
    final selectedIds = _selectedTileIds;
    final limitToSelection = selectedIds.isNotEmpty;
    if (limitToSelection) {
      final selectedTiles = _rack
          .where((tile) => selectedIds.contains(tile.id))
          .toList();
      if (_canLayTilesInPairArea(selectedTiles)) {
        _openPairs(selectedIds, detectedPairs: _pairGroups(selectedIds));
        return;
      }
    }
    var processed = 0;
    final processedTiles = <Tile>[];
    Alignment? processMotionTarget;
    setState(() {
      while (_rack.length > 1) {
        Tile? tileToProcess;
        var targetMeldIndex = -1;
        final orderedTiles = _rackSlots
            .map(_rackTileById)
            .whereType<Tile>()
            .where((tile) => !limitToSelection || selectedIds.contains(tile.id))
            .toList();
        for (final tile in orderedTiles) {
          targetMeldIndex = _automaticTargetMeldIndex(tile);
          if (targetMeldIndex >= 0) tileToProcess = tile;
          if (tileToProcess != null) break;
        }
        if (tileToProcess == null || targetMeldIndex == -1) break;

        processMotionTarget ??= _motionTargetForMeld(
          _tableMetds[targetMeldIndex],
        );
        _placeTilesIntoMeld(targetMeldIndex, [tileToProcess]);
        processedTiles.add(tileToProcess);
        processed++;
      }
      _uiMode = 'normal';
      _beginTableTileMotion(
        _TableTileMotionKind.process,
        processedTiles,
        targetAlignment: processMotionTarget,
      );
    });
    if (processed == 0) {
      _msg_(
        limitToSelection
            ? 'Seçili taş açık perlere işlenemiyor.'
            : 'Istakada açık perlere işlenebilen taş yok.',
      );
    } else {
      _msg_(
        limitToSelection
            ? '$processed seçili taş işlendi.'
            : '$processed taş otomatik işlendi.',
      );
    }
  }

  void _processIntoMeld(int meldIdx, List<Tile> tiles) {
    final meld = _tableMetds[meldIdx];
    // Otomatik, buton ve sürükle-bırak işlemlerinin tamamı burada birleşir.
    // Arayüz hedefi yanlış seçse bile geçersiz veya tamamlanmış pere yazma.
    if (!Rules.canAddToMeld(meld, tiles)) return;
    final originalSlots = <int, int>{};
    for (final tile in tiles) {
      final slot = _rackSlots.indexOf(tile.id);
      if (slot >= 0) originalSlots[tile.id] = slot;
    }
    _processedMoves.add(
      _ProcessedMove(
        meld: meld,
        previousMeldTiles: List<Tile>.from(meld.tiles),
        addedTiles: List<Tile>.from(tiles),
        originalSlots: originalSlots,
        tookDiscardBefore: _tookDiscard,
        takenDiscardTileBefore: _takenDiscardTile,
      ),
    );

    for (final tile in tiles) {
      tile.selected = false;
    }
    meld.tiles = Rules.extendMeldKeepingPositions(meld.tiles, tiles, meld.type);
    _markTableChanged();
    final tileIds = tiles.map((tile) => tile.id).toSet();
    _clearRackSlots(tileIds);
    _rack.removeWhere((tile) => tileIds.contains(tile.id));
    if (_takenDiscardTile != null && tileIds.contains(_takenDiscardTile!.id)) {
      _tookDiscard = false;
      _takenDiscardTile = null;
    }
  }

  void _placeTilesIntoMeld(int meldIdx, List<Tile> tiles) {
    if (tiles.length == 1) {
      final replacementIndex = Rules.okeyReplacementIndex(
        _tableMetds[meldIdx],
        tiles.single,
      );
      if (replacementIndex != null) {
        _replaceOkeyInMeld(meldIdx, tiles.single, replacementIndex);
        return;
      }
    }
    _processIntoMeld(meldIdx, tiles);
  }

  void _replaceOkeyInMeld(int meldIdx, Tile replacement, int replacementIndex) {
    final meld = _tableMetds[meldIdx];
    final okey = meld.tiles[replacementIndex];
    final originalSlot = _rackSlots.indexOf(replacement.id);
    _processedMoves.add(
      _ProcessedMove(
        meld: meld,
        previousMeldTiles: List<Tile>.from(meld.tiles),
        addedTiles: [replacement],
        returnedTiles: [okey],
        originalSlots: {if (originalSlot >= 0) replacement.id: originalSlot},
        tookDiscardBefore: _tookDiscard,
        takenDiscardTileBefore: _takenDiscardTile,
      ),
    );

    replacement.selected = false;
    okey.selected = false;
    final changed = List<Tile>.from(meld.tiles)
      ..[replacementIndex] = replacement;
    meld.tiles = changed;
    _markTableChanged();
    _clearRackSlots({replacement.id});
    _rack.removeWhere((tile) => tile.id == replacement.id);
    _rack.add(okey);
    _placeInRackSlot(okey, originalSlot >= 0 ? originalSlot : null);
    if (_takenDiscardTile?.id == replacement.id) {
      _tookDiscard = false;
      _takenDiscardTile = null;
    }
  }

  void _undoProcessedMoves() {
    if (_processedMoves.isEmpty) return;
    if (_turn != 0 || !_drawnThisTurn) {
      _msg_('İşlenen taşlar yalnız taş atmadan önce geri alınabilir.');
      return;
    }

    final restoredCount = _processedMoves.fold<int>(
      0,
      (count, move) => count + move.addedTiles.length,
    );
    setState(() {
      for (final move in _processedMoves.reversed) {
        if (move.removeMeldOnUndo) {
          _tableMetds.remove(move.meld);
        } else {
          move.meld.tiles = List<Tile>.from(move.previousMeldTiles);
        }
        final returnedIds = move.returnedTiles.map((tile) => tile.id).toSet();
        _clearRackSlots(returnedIds);
        _rack.removeWhere((tile) => returnedIds.contains(tile.id));
        for (final tile in move.addedTiles) {
          if (!_rack.any((item) => item.id == tile.id)) _rack.add(tile);
          tile.selected = false;
          _clearRackSlots({tile.id});
          _placeInRackSlot(tile, move.originalSlots[tile.id]);
        }
        _tookDiscard = move.tookDiscardBefore;
        _takenDiscardTile = move.takenDiscardTileBefore;
      }
      _markTableChanged();
      _processedMoves.clear();
      _uiMode = 'normal';
    });
    _msg_('$restoredCount işlenmiş taş ıstakaya geri alındı.');
  }

  void _addToMeld(int meldIdx) {
    if (_uiMode != 'addMeld') return;
    _tryAddToMeld(meldIdx, _selectedTileIds);
  }

  void _tryAddToMeld(int meldIdx, Set<int> tileIds) {
    final selected = _rack.where((tile) => tileIds.contains(tile.id)).toList();
    if (selected.isEmpty) {
      setState(() => _uiMode = 'normal');
      return;
    }
    if (selected.length >= _rack.length) {
      _msg_('Bitmek için elinde atacağın son bir taş bırakmalısın.');
      setState(() => _uiMode = 'normal');
      return;
    }

    final meld = _tableMetds[meldIdx];
    if (!_meldCanUseTiles(meld, selected)) {
      _msg_('Bu taşlar o perdeye eklenemiyor.');
      setState(() => _uiMode = 'normal');
      return;
    }
    final swappedOkey =
        selected.length == 1 &&
        Rules.okeyReplacementIndex(meld, selected.single) != null;

    setState(() {
      _placeTilesIntoMeld(meldIdx, selected);
      _uiMode = 'normal';
      _beginTableTileMotion(
        _TableTileMotionKind.process,
        selected,
        targetAlignment: _motionTargetForMeld(meld),
      );
    });
    _msg_(
      swappedOkey
          ? 'Taş yerine işlendi, okey ıstakana alındı.'
          : '${selected.length} taş pere işlendi.',
    );
  }

  void _dropOnMeld(int meldIndex, _RackDragData data) {
    if (!_playerOpened) {
      _msg_('Başka bir pere işlemeden önce elini açmalısın.');
      return;
    }
    if (_turn != 0 || !_drawnThisTurn) {
      _msg_('Taş işlemek için sıra sende olmalı ve taş çekmelisin.');
      return;
    }
    final ids = _tilesForDrag(data).map((tile) => tile.id).toSet();
    _tryAddToMeld(meldIndex, ids);
  }

  void _dropToDiscard(_RackDragData data) {
    final index = _rack.indexWhere((tile) => tile.id == data.tileId);
    if (index == -1) return;
    setState(() {
      for (final tile in _rack) {
        tile.selected = tile.id == data.tileId;
      }
    });
    _discardTile(celebrateCenterFinish: _rack.length == 1);
  }

  void _finishByCenterDrop(_RackDragData data) {
    if (_turn != 0 || !_drawnThisTurn || _rack.length != 1) return;
    if (_rack.single.id != data.tileId || data.tileIds.length != 1) return;
    setState(() => _rack.single.selected = true);
    _discardTile(celebrateCenterFinish: true);
  }

  Set<int> _applyRackGroupLayout(List<List<Tile>> groups) {
    final placedIds = <int>{};
    final reservedSeparators = <int>{};

    _rackSlots = List<int?>.filled(_rackSlotCount, null);
    for (final tile in _rack) {
      tile.selected = false;
    }

    var row = 0;
    var position = 0;
    for (final group in groups) {
      if (group.length > _rackRowLength) continue;
      if (position > 0 && position + group.length > _rackRowLength) {
        row++;
        position = 0;
      }
      if (row >= 2) break;

      for (final tile in group) {
        final slot = row * _rackRowLength + position;
        _rackSlots[slot] = tile.id;
        placedIds.add(tile.id);
        position++;
      }
      if (position < _rackRowLength) {
        reservedSeparators.add(row * _rackRowLength + position);
        position++;
      }
    }

    final remaining =
        _rack.where((tile) => !placedIds.contains(tile.id)).toList()
          ..sort((a, b) {
            final byNumber = b.number.compareTo(a.number);
            if (byNumber != 0) return byNumber;
            final byColor = b.color.index.compareTo(a.color.index);
            if (byColor != 0) return byColor;
            return b.id.compareTo(a.id);
          });
    final trailingSlots = [
      for (var index = _rackSlotCount - 1; index >= 0; index--)
        if (_rackSlots[index] == null && !reservedSeparators.contains(index))
          index,
    ];
    for (
      var index = 0;
      index < remaining.length && index < trailingSlots.length;
      index++
    ) {
      _rackSlots[trailingSlots[index]] = remaining[index].id;
    }
    _rackAnalysisSignature = null;
    return placedIds;
  }

  Set<int> _layoutRackGroups(List<List<Tile>> groups) {
    late Set<int> placedIds;
    setState(() => placedIds = _applyRackGroupLayout(groups));
    return placedIds;
  }

  void _arrangeAutoPlayerRack() {
    final standard = RackSolver.standardMelds(_rack);
    final pairs = RackSolver.pairs(_rack);
    final standardTiles = standard.fold<int>(
      0,
      (sum, group) => sum + group.length,
    );
    final pairTiles = pairs.fold<int>(0, (sum, group) => sum + group.length);
    final usePairs = pairTiles > standardTiles;
    _showRackPairCount = usePairs;
    _applyRackGroupLayout(usePairs ? pairs : standard);
  }

  void _arrangeStandardMelds() {
    setState(() => _showRackPairCount = false);
    final groups = RackSolver.standardMelds(_rack);
    if (groups.isEmpty) {
      _layoutRackGroups(const []);
      _msg_('Istakada dizilebilecek geçerli per bulunamadı.');
      return;
    }
    _layoutRackGroups(groups);
    _playInteractionFeedback(sound: _GameSound.arrange);
  }

  void _arrangePairs() {
    final pairs = RackSolver.pairs(_rack);
    setState(() => _showRackPairCount = true);
    if (pairs.isEmpty) {
      _layoutRackGroups(const []);
      _msg_('Istakada dizilebilecek çift bulunamadı.');
      return;
    }
    _layoutRackGroups(pairs);
    _playInteractionFeedback(sound: _GameSound.arrange);
  }

  void _autoOpenStandardMelds() {
    final allIds = _rack.map((tile) => tile.id).toSet();
    final groups = RackSolver.standardMeldsFromLayout(_rackGroups(allIds));
    if (groups.isEmpty) {
      _msg_('Istakada boşluklarla ayırdığın geçerli bir per bulunamadı.');
      return;
    }
    final ids = groups.expand((group) => group).map((tile) => tile.id).toSet();
    _openStandardMelds(ids, detectedGroups: groups);
  }

  void _autoOpenPairs() {
    final allIds = _rack.map((tile) => tile.id).toSet();
    final pairs = RackSolver.pairsFromLayout(_rackGroups(allIds));
    if (pairs.isEmpty) {
      _msg_('Istakada yan yana dizdiğin geçerli bir çift bulunamadı.');
      return;
    }
    final ids = pairs.expand((pair) => pair).map((tile) => tile.id).toSet();
    _openPairs(ids, detectedPairs: pairs);
  }

  // ── Sıra Geçişi ───────────────────────────────────────────────────────
  void _scheduleAutoPlayer({bool alreadyHasExtraTile = false}) {
    if (!_gameSettings.autoPlay ||
        _autoPlayerBusy ||
        _dealInProgress ||
        _gameOverShown ||
        _turn != 0) {
      return;
    }
    final generation = ++_autoPlayerGeneration;
    _autoPlayerBusy = true;
    setState(() => _botBusy = true);
    Future.delayed(const Duration(milliseconds: 260), () async {
      if (!mounted ||
          generation != _autoPlayerGeneration ||
          !_gameSettings.autoPlay ||
          _gameOverShown ||
          _turn != 0) {
        return;
      }

      if (!alreadyHasExtraTile && !_drawnThisTurn) {
        if (_deck.isEmpty) {
          _autoPlayerBusy = false;
          setState(() => _botBusy = false);
          _endRoundNoDeck();
          return;
        }
        final drawn = _deck.removeLast();
        _rack.add(drawn);
        _placeInRackSlot(drawn);
        _drawnThisTurn = true;
      }

      final playerBot = BotPlayer(
        name: 'Oyuncu 1',
        tileCount: _rack.length,
        hasOpened: _playerOpened,
        openType: _playerOpenType,
        turnsPlayed: ++_autoPlayerTurns,
        hand: List<Tile>.from(_rack),
      );
      final tableIdsBefore = _tableMetds
          .expand((meld) => meld.tiles)
          .map((tile) => tile.id)
          .toSet();
      final computation = await _computeBotTurnInBackground(
        playerBot,
        _tableMetds,
        allowOpening: true,
        minimumStandardScore: _minimumStandardOpeningScore,
        minimumPairCount: _minimumPairOpeningCount,
        bonusColor: _isColorBonusMode ? _roundBonusColor : null,
      );
      if (!mounted ||
          generation != _autoPlayerGeneration ||
          !_gameSettings.autoPlay ||
          _gameOverShown ||
          _turn != 0) {
        return;
      }

      final movedToTable = computation.tableMelds
          .expand((meld) => meld.tiles)
          .any((tile) => !tableIdsBefore.contains(tile.id));
      final discarded = computation.result.discarded;
      setState(() {
        final openedType = computation.result.openedType;
        final openingValue = computation.result.openingValue;
        if (openedType != null && openingValue != null) {
          _recordProgressiveOpening(openedType, openingValue);
        }
        _rack = computation.bot.hand;
        _playerOpened = computation.bot.hasOpened;
        _playerOpenType = computation.bot.openType;
        if (movedToTable) {
          _tableMetds = computation.tableMelds;
          _markTableChanged();
        }
        for (final tile in _rack) {
          tile.selected = false;
        }
        _compactRackSlots();
        _arrangeAutoPlayerRack();
        _processedMoves.clear();
        _drawnThisTurn = false;
        _tookDiscard = false;
        _takenDiscardTile = null;
        _discarded = discarded;
        if (discarded != null) _addDiscardToPile(0, discarded);
        _autoPlayerBusy = false;
        _botBusy = false;
      });

      if (_rack.isEmpty) {
        _endRoundPlayerWins();
      } else {
        _nextTurn();
      }
    });
  }

  void _nextTurn() {
    _cancelTimedPlayerTurn();
    final nextTurn = (_turn + 1) % 4;
    setState(() {
      _turn = nextTurn;
      _botBusy = nextTurn != 0;
      _botDiscardMotion = null;
      if (nextTurn == 0) _drawnThisTurn = false;
    });
    if (nextTurn != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _turn == nextTurn && _botBusy) {
          _runBot(nextTurn - 1, alreadyMarkedBusy: true);
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startTimedPlayerTurn();
          _scheduleAutoPlayer();
        }
      });
    }
  }

  // ── Bot Oynaması ──────────────────────────────────────────────────────
  void _runBot(
    int botIdx, {
    bool alreadyHasExtraTile = false,
    bool alreadyMarkedBusy = false,
  }) {
    if (_gameOverShown || _turn == 0 || _turn != botIdx + 1) return;
    final roundGeneration = _roundGeneration;
    if (!alreadyMarkedBusy) setState(() => _botBusy = true);

    final botThinkTime = _gameSettings.autoPlay
        ? const Duration(milliseconds: 110)
        : _instantBotTurns
        ? const Duration(milliseconds: 25)
        : Duration(milliseconds: 650 + Random().nextInt(651));
    _botThinkTimer?.cancel();
    _botThinkTimer = Timer(botThinkTime, () async {
      _botThinkTimer = null;
      if (!mounted ||
          roundGeneration != _roundGeneration ||
          _gameOverShown ||
          _turn == 0 ||
          _turn != botIdx + 1) {
        return;
      }

      final bot = _bots[botIdx];
      const earliestOpeningTurns = [3, 4, 3];
      const standardOpeningTargets = [105, 110, 103];
      const pairOpeningTargets = [5, 6, 5];
      final minimumStandardScore = _isProgressiveMode
          ? _minimumStandardOpeningScore
          : standardOpeningTargets[botIdx];
      final minimumPairCount = _isProgressiveMode
          ? _minimumPairOpeningCount
          : pairOpeningTargets[botIdx];
      final nextBotTurn = bot.turnsPlayed + 1;
      final allowOpening = nextBotTurn >= earliestOpeningTurns[botIdx];
      final discardCandidate = _discarded;
      final canTakeDiscard = !alreadyHasExtraTile && discardCandidate != null
          ? await _computeBotWantsDiscard(
              bot,
              discardCandidate,
              _tableMetds,
              allowOpening: allowOpening,
              minimumStandardScore: minimumStandardScore,
              minimumPairCount: minimumPairCount,
              bonusColor: _isColorBonusMode ? _roundBonusColor : null,
            )
          : false;
      if (!mounted ||
          roundGeneration != _roundGeneration ||
          _gameOverShown ||
          _turn != botIdx + 1) {
        return;
      }
      if (!alreadyHasExtraTile && !canTakeDiscard && _deck.isEmpty) {
        setState(() => _botBusy = false);
        _endRoundNoDeck();
        return;
      }

      Tile? drawnTile;
      var animatedDraw = false;
      if (!alreadyHasExtraTile) {
        setState(() {
          if (canTakeDiscard) {
            drawnTile = _discarded!;
            final previousSeat = botIdx;
            if (_discardPiles[previousSeat].isNotEmpty &&
                _discardPiles[previousSeat].last.id == drawnTile!.id) {
              _discardPiles[previousSeat].removeLast();
            }
            _discarded = null;
          } else {
            drawnTile = _deck.removeLast();
          }
          bot.hand.add(drawnTile!);
          bot.tileCount = bot.hand.length;
          _beginTableTileMotion(
            canTakeDiscard
                ? _TableTileMotionKind.drawDiscard
                : _TableTileMotionKind.drawDeck,
            [drawnTile!],
            playerIndex: botIdx + 1,
          );
          animatedDraw = _useGameplayAnimations;
        });
      }

      Future<void> playAndDiscard() async {
        if (!mounted ||
            roundGeneration != _roundGeneration ||
            _gameOverShown ||
            _turn == 0 ||
            _turn != botIdx + 1) {
          return;
        }
        late final BotTurnResult result;
        final tableTileIdsBefore = _tableMetds
            .expand((meld) => meld.tiles)
            .map((tile) => tile.id)
            .toSet();
        var movedToTable = <Tile>[];
        bot.turnsPlayed++;
        final computation = await _computeBotTurnInBackground(
          bot,
          _tableMetds,
          allowOpening: bot.turnsPlayed >= earliestOpeningTurns[botIdx],
          minimumStandardScore: minimumStandardScore,
          minimumPairCount: minimumPairCount,
          bonusColor: _isColorBonusMode ? _roundBonusColor : null,
        );
        if (!mounted ||
            roundGeneration != _roundGeneration ||
            _gameOverShown ||
            _turn != botIdx + 1) {
          return;
        }
        result = computation.result;
        bot.hand = computation.bot.hand;
        bot.tileCount = computation.bot.tileCount;
        bot.hasOpened = computation.bot.hasOpened;
        bot.openType = computation.bot.openType;
        bot.turnsPlayed = computation.bot.turnsPlayed;
        movedToTable = computation.tableMelds
            .expand((meld) => meld.tiles)
            .where((tile) => !tableTileIdsBefore.contains(tile.id))
            .toList();
        // Botlarin buyuk bolumu bu turda masaya tas indirmez. Bu durumda
        // klonlanmis ayni masayi geri atamak hem grid onbellegini bosaltiyor hem
        // de atma animasyonundan hemen once gereksiz bir tam sahne rebuild'i
        // uretiyordu. Masayi yalnizca gercekten degistiyse yenile.
        if (movedToTable.isNotEmpty) {
          setState(() {
            final openedType = result.openedType;
            final openingValue = result.openingValue;
            if (openedType != null && openingValue != null) {
              _recordProgressiveOpening(openedType, openingValue);
            }
            _tableMetds = computation.tableMelds;
            _markTableChanged();
            _beginTableTileMotion(
              result.openedMeldCount > 0
                  ? _TableTileMotionKind.open
                  : _TableTileMotionKind.process,
              movedToTable,
              playerIndex: botIdx + 1,
            );
          });
        }

        void finishTurn() {
          if (!mounted ||
              roundGeneration != _roundGeneration ||
              _gameOverShown ||
              _turn == 0 ||
              _turn != botIdx + 1) {
            return;
          }
          if (bot.hand.isEmpty) {
            setState(() {
              _botBusy = false;
              _discarded = result.discarded;
              if (result.discarded != null) {
                _addDiscardToPile(botIdx + 1, result.discarded!);
              }
              _botDiscardMotion = null;
            });
            _endRoundBotWins(botIdx);
          } else if (_deck.isEmpty) {
            setState(() {
              _botBusy = false;
              _discarded = result.discarded;
              if (result.discarded != null) {
                _addDiscardToPile(botIdx + 1, result.discarded!);
              }
              _botDiscardMotion = null;
            });
            _endRoundNoDeck();
          } else {
            final nextTurn = (_turn + 1) % 4;
            // Atılan taşı kesinleştirme ve sıra değişimini tek sahne
            // güncellemesinde yap; botlar arasında iki tam rebuild oluşmasın.
            setState(() {
              _discarded = result.discarded;
              if (result.discarded != null) {
                _addDiscardToPile(botIdx + 1, result.discarded!);
              }
              _botDiscardMotion = null;
              _turn = nextTurn;
              _botBusy = nextTurn != 0;
              if (nextTurn == 0) _drawnThisTurn = false;
            });
            if (nextTurn != 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _turn == nextTurn && _botBusy) {
                  _runBot(nextTurn - 1, alreadyMarkedBusy: true);
                }
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _startTimedPlayerTurn();
                  _scheduleAutoPlayer();
                }
              });
            }
          }
        }

        void startDiscard() {
          if (!mounted ||
              roundGeneration != _roundGeneration ||
              _gameOverShown ||
              _turn != botIdx + 1) {
            return;
          }
          if (result.discarded != null && _useGameplayAnimations) {
            setState(() {
              _discarded = result.discarded;
              _botDiscardMotion = _BotDiscardMotion(
                tile: result.discarded!,
                botIndex: botIdx,
                serial: ++_botDiscardMotionSerial,
              );
            });
            Future.delayed(const Duration(milliseconds: 210), finishTurn);
          } else {
            finishTurn();
          }
        }

        final tableMotionDelay =
            _useGameplayAnimations && movedToTable.isNotEmpty
            ? Duration(milliseconds: result.openedMeldCount > 0 ? 180 : 150)
            : Duration.zero;
        if (tableMotionDelay == Duration.zero) {
          startDiscard();
        } else {
          Future.delayed(tableMotionDelay, startDiscard);
        }
      }

      if (animatedDraw) {
        Future.delayed(const Duration(milliseconds: 150), playAndDiscard);
      } else {
        playAndDiscard();
      }
    });
  }

  // ── El Bitti: Oyuncu Kazandı ──────────────────────────────────────────
  void _endRoundPlayerWins() {
    if (_gameOverShown) return;
    _cancelTimedPlayerTurn();
    _gameOverShown = true;

    // Diğer oyuncuların cezaları
    final botPenList = <int>[];
    for (final b in _bots) {
      final p = Rules.roundPenaltyFor(
        b.hand,
        fakeOkeyValue: _currentOkeyNumber,
        hasOpened: b.hasOpened,
        openedWithPairs: b.openType == 'cift',
        normalOpenedPenalty: _isColorBonusMode,
      );
      botPenList.add(p);
    }

    _totalPenalty -= 101;
    _showEndDialog(winner: 'Oyuncu 1', playerPen: -101, botPens: botPenList);
  }

  // ── El Bitti: Bot Kazandı ─────────────────────────────────────────────
  void _endRoundBotWins(int botIdx) {
    if (_gameOverShown) return;
    _cancelTimedPlayerTurn();
    _gameOverShown = true;

    final myPen = Rules.roundPenaltyFor(
      _rack,
      fakeOkeyValue: _currentOkeyNumber,
      hasOpened: _playerOpened,
      openedWithPairs: _playerOpenType == 'cift',
      normalOpenedPenalty: _isColorBonusMode,
    );
    _totalPenalty += myPen;

    final botPens = List.generate(_bots.length, (i) {
      if (i == botIdx) return -101;
      return Rules.roundPenaltyFor(
        _bots[i].hand,
        fakeOkeyValue: _currentOkeyNumber,
        hasOpened: _bots[i].hasOpened,
        openedWithPairs: _bots[i].openType == 'cift',
        normalOpenedPenalty: _isColorBonusMode,
      );
    });

    _showEndDialog(
      winner: _bots[botIdx].name,
      playerPen: myPen,
      botPens: botPens,
    );
  }

  // ── El Bitti: Deste Tükendi ───────────────────────────────────────────
  void _endRoundNoDeck() {
    if (_gameOverShown) return;
    _cancelTimedPlayerTurn();
    _gameOverShown = true;
    final myPen = Rules.roundPenaltyFor(
      _rack,
      fakeOkeyValue: _currentOkeyNumber,
      hasOpened: _playerOpened,
      openedWithPairs: _playerOpenType == 'cift',
      normalOpenedPenalty: _isColorBonusMode,
    );
    _totalPenalty += myPen;
    final botPens = _bots
        .map(
          (b) => Rules.roundPenaltyFor(
            b.hand,
            fakeOkeyValue: _currentOkeyNumber,
            hasOpened: b.hasOpened,
            openedWithPairs: b.openType == 'cift',
            normalOpenedPenalty: _isColorBonusMode,
          ),
        )
        .toList();
    _showEndDialog(winner: 'Tur bitti', playerPen: myPen, botPens: botPens);
  }

  void _showEndDialog({
    required String winner,
    required int playerPen,
    required List<int> botPens,
  }) {
    final playerWon = winner == 'Oyuncu 1' || winner == 'Sen';
    final roundLimit = _hasThreeRoundLimit ? _roomAndModeRoundLimit : null;
    final matchComplete = roundLimit != null && _elCount >= roundLimit;
    final reward = playerProgress.recordCompletedGame(
      config: widget.launchConfig,
      won: playerWon,
      openedHand: _playerOpened,
      finishedHand: playerWon,
      roundNumber: _elCount,
    );
    if (_gameSettings.autoPlay && !matchComplete) {
      final completedRound = _roundGeneration;
      for (var i = 0; i < _bots.length; i++) {
        _bots[i].penalty += botPens[i];
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted ||
            completedRound != _roundGeneration ||
            !_gameSettings.autoPlay) {
          return;
        }
        setState(_startNewRound);
      });
      return;
    }
    if (mounted && !_endDialogVisible) {
      setState(() => _endDialogVisible = true);
    }
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: appText('Tur sonu', 'Round result'),
      barrierColor: const Color(0xB8000000),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => GameEndDialog(
        winner: winner,
        playerName: playerProgress.playerName,
        playerPen: playerPen,
        bots: _bots,
        botPens: botPens,
        elCount: _elCount,
        maxRounds: roundLimit,
        matchComplete: matchComplete,
        totalPenalty: _totalPenalty,
        reward: reward,
        homeLabel: _isTournamentGame
            ? appText('TURNUVAYA DÖN', 'TOURNAMENT')
            : appText('ANA SAYFA', 'HOME'),
        onNewRound: () {
          Navigator.pop(context);
          setState(() {
            for (var i = 0; i < _bots.length; i++) {
              _bots[i].penalty += botPens[i];
            }
            _startNewRound();
          });
        },
        onResetMatch: () {
          Navigator.pop(context);
          setState(() {
            _totalPenalty = 0;
            _elCount = 0;
            for (final bot in _bots) {
              bot.penalty = 0;
            }
            _startNewRound();
          });
        },
        onHome: () {
          if (_isTournamentGame) {
            Navigator.of(context).pop();
            Navigator.of(context).pop(winner == 'Oyuncu 1');
          } else if (widget.launchConfig.entryPoint ==
              GameEntryPoint.gameMode) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      ),
      transitionBuilder: (_, animation, _, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
          reverseCurve: Curves.easeInCubic,
        );
        final motion = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(motion),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(motion),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sel = _rack.where((t) => t.selected).length;
    final myTurn = _turn == 0 && !_botBusy && !_dealInProgress;
    final canAct = myTurn && _drawnThisTurn;
    final eligibleMeldIndexes = myTurn && _uiMode == 'addMeld'
        ? _eligibleMeldIndexes
        : const <int>{};
    final processableTileIds = _gameSettings.moveHints
        ? _processableTileIds
        : const <int>{};
    final centerNotice =
        _warningMsg ??
        _msg ??
        (_uiMode == 'addMeld' ? 'İşlemek istediğin perdeye dokun' : null);

    return Scaffold(
      backgroundColor: const Color(0xFF071B14),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _clearRackSelection,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(_gameSettings.fontScale)),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final sceneWidth = viewport.maxWidth;
                final sceneHeight = viewport.maxHeight;
                final edgeInset = sceneWidth * 0.012;
                final actionPanelWidth = sceneWidth * 0.115;
                final controlGap = max(3.0, sceneWidth * 0.003);
                final rackHeight = sceneHeight * 0.29;
                final infoPanelHeight = sceneHeight * 0.11;
                final rackContentWidth =
                    sceneWidth -
                    edgeInset * 2 -
                    actionPanelWidth * 2 -
                    controlGap * 2 -
                    8;
                final normalRackTileWidth = max(
                  1.0,
                  rackContentWidth / _rackRowLength - 3.2,
                );
                final rackVisualTileWidth = max(
                  1.0,
                  ((rackContentWidth - 4) * 0.852) / _rackRowLength - 1.6,
                );
                final rackVisualTileHeight = min(
                  rackVisualTileWidth * 1.58,
                  max(1.0, (rackHeight - 6) / 2),
                );
                final gridTileWidth = normalRackTileWidth * 0.85;

                return SizedBox.expand(
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF071B14)),
                      ),
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: storeCosmetics.backgroundColor != null
                              ? ColoredBox(
                                  color: storeCosmetics.backgroundColor!,
                                )
                              : Image.asset(
                                  storeCosmetics.backgroundAsset,
                                  fit: BoxFit.cover,
                                  cacheWidth: _backgroundDecodeWidth(context),
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
                                ),
                        ),
                      ),
                      TickerMode(
                        enabled: !_endDialogVisible,
                        child: RepaintBoundary(
                          child: _GameSceneEntrance(
                            enabled: _useGameplayAnimations,
                            child: Stack(
                              children: [
                                // ── Büyük oyun masası ───────────────────────────────────
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  bottom: rackHeight,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      edgeInset,
                                      sceneHeight * 0.012,
                                      edgeInset,
                                      sceneHeight * 0.008,
                                    ),
                                    child: _TableArea(
                                      melds: _tableMetds,
                                      bots: _bots,
                                      playerName: playerProgress.playerName,
                                      activeTurn: _turn,
                                      discardPiles: _discardPiles,
                                      uiMode: _uiMode,
                                      eligibleMeldIndexes: eligibleMeldIndexes,
                                      onMeldTap: _addToMeld,
                                      onMeldDrop: _dropOnMeld,
                                      canAcceptMeldDrop: _canDropOnMeld,
                                      onPairDrop: _dropOnPairArea,
                                      canAcceptPairDrop: _canDropOnPairArea,
                                      myTurn: myTurn,
                                      drawnThisTurn: _drawnThisTurn,
                                      onPlayerDiscardDrop: _dropToDiscard,
                                      playerDiscardTargetKey:
                                          _playerDiscardTargetKey,
                                      canTakeDiscard:
                                          myTurn &&
                                          !_drawnThisTurn &&
                                          _discarded != null,
                                      onTakeDiscard: _takeDiscarded,
                                      canReturnDiscard:
                                          _tookDiscard &&
                                          _takenDiscardTile != null &&
                                          _rack.any(
                                            (tile) =>
                                                tile.id ==
                                                _takenDiscardTile!.id,
                                          ),
                                      returnDiscardTileId:
                                          _takenDiscardTile?.id,
                                      onReturnDiscard: _returnTakenDiscard,
                                      gridTileWidth: gridTileWidth,
                                      gridKey: _meldGridKey,
                                      dragVisual: _rackDragVisual,
                                      botDiscardMotion: _botDiscardMotion,
                                      tableTileMotion: _tableTileMotion,
                                      bottomReservedSpace: infoPanelHeight,
                                      gameModeLabel:
                                          _isColorBonusMode &&
                                              _showColorBonusIntro
                                          ? ''
                                          : _tableModeLabel,
                                      minimumStandardOpeningScore:
                                          _isProgressiveMode
                                          ? _minimumStandardOpeningScore
                                          : null,
                                      minimumPairOpeningCount:
                                          _isProgressiveMode
                                          ? _minimumPairOpeningCount
                                          : null,
                                      deckCount: _deck.length,
                                      indicator: _indicator,
                                      perPoints: _playerOpened
                                          ? _rackRemainingPoints
                                          : _rackPerPoints,
                                      showRemainingPoints: _playerOpened,
                                      pairCount:
                                          !_playerOpened && _showRackPairCount
                                          ? _rackPairCount
                                          : null,
                                      canDraw: myTurn && !_drawnThisTurn,
                                      onDraw: _drawFromDeck,
                                      canFinishByCenterDrop:
                                          canAct && _rack.length == 1,
                                      onFinishByCenterDrop: _finishByCenterDrop,
                                      dragTileWidth: rackVisualTileWidth,
                                      dragTileHeight: rackVisualTileHeight,
                                      showGrid: _gameSettings.showGrid,
                                      showBots: _gameSettings.showBots,
                                    ),
                                  ),
                                ),

                                if (_isColorBonusMode && _showColorBonusIntro)
                                  Positioned(
                                    top: sceneHeight * 0.02,
                                    left: edgeInset + 58,
                                    right: edgeInset + 58,
                                    bottom: rackHeight + 8,
                                    child: _ColorBonusRoundIntro(
                                      key: ValueKey(
                                        'color-bonus-round-intro-$_roundGeneration',
                                      ),
                                      colorName: _roundBonusColorName,
                                      color: _roundBonusDisplayColor,
                                      onFinished: () {
                                        if (!mounted || !_showColorBonusIntro) {
                                          return;
                                        }
                                        setState(
                                          () => _showColorBonusIntro = false,
                                        );
                                      },
                                    ),
                                  ),

                                if (_isTimedMode && myTurn)
                                  Positioned(
                                    left:
                                        edgeInset +
                                        actionPanelWidth +
                                        controlGap,
                                    right:
                                        edgeInset +
                                        actionPanelWidth +
                                        controlGap,
                                    bottom: rackHeight - 2,
                                    height: 10,
                                    child: _TimedRackCountdown(
                                      key: ValueKey(
                                        'timed-rack-$_playerTurnGeneration',
                                      ),
                                      seconds: _playerTurnSeconds,
                                      active: myTurn,
                                    ),
                                  ),

                                // ── Referanstaki gibi: kontroller + ahşap ıstaka ─────────
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: rackHeight,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: edgeInset,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          width: actionPanelWidth,
                                          child: _RackActionPanel(
                                            actions: [
                                              _RackAction(
                                                label: 'SERİ AÇ',
                                                active:
                                                    canAct &&
                                                    !(_playerOpened &&
                                                        _playerOpenType ==
                                                            'cift'),
                                                color: const Color(0xFF19862B),
                                                onTap: _autoOpenStandardMelds,
                                              ),
                                              _RackAction(
                                                label: 'ÇİFT AÇ',
                                                active:
                                                    canAct &&
                                                    (!(_playerOpened &&
                                                            _playerOpenType ==
                                                                'seri') ||
                                                        _canLayPairsAfterStandard),
                                                color: const Color(0xFF9A650E),
                                                onTap: _autoOpenPairs,
                                              ),
                                              _RackAction(
                                                label: 'İŞLE',
                                                active: !_dealInProgress,
                                                color: const Color(0xFF08658F),
                                                onTap: _enterAddMode,
                                                secondaryLabel:
                                                    _processedMoves.isNotEmpty
                                                    ? 'GERİ AL'
                                                    : null,
                                                secondaryActive:
                                                    !_dealInProgress &&
                                                    _processedMoves.isNotEmpty,
                                                secondaryColor: const Color(
                                                  0xFF9A650E,
                                                ),
                                                secondaryOnTap:
                                                    _undoProcessedMoves,
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: controlGap),
                                        Expanded(
                                          child: IgnorePointer(
                                            ignoring: _dealInProgress,
                                            child: _gameSettings.showRack
                                                ? _RackArea(
                                                    rack: _rack,
                                                    slots: _rackSlots,
                                                    dealAnimationSerial:
                                                        _dealAnimationSerial,
                                                    onTileTap: _tapTile,
                                                    onReorder: _reorderRack,
                                                    onTileDragStart:
                                                        _startGridDragZoom,
                                                    onTileDragUpdate:
                                                        _updateGridDragZoom,
                                                    onTileDragEnd:
                                                        _endGridDragZoom,
                                                    dragVisual: _rackDragVisual,
                                                    pushPreview:
                                                        _rackPushPreview,
                                                    processableTileIds:
                                                        processableTileIds,
                                                    drawAttentionTileId:
                                                        _drawAttentionTileId,
                                                    drawAttentionSerial:
                                                        _drawAttentionSerial,
                                                    canAcceptDeckDrop:
                                                        myTurn &&
                                                        !_drawnThisTurn,
                                                    canAcceptDiscardDrop:
                                                        myTurn &&
                                                        !_drawnThisTurn &&
                                                        _discarded != null,
                                                    onDeckDropAt: _drawFromDeck,
                                                    onDiscardDropAt:
                                                        _takeDiscarded,
                                                  )
                                                : const SizedBox.expand(),
                                          ),
                                        ),
                                        SizedBox(width: controlGap),
                                        SizedBox(
                                          width: actionPanelWidth,
                                          child: _RackActionPanel(
                                            actions: [
                                              _RackAction(
                                                label: 'SERİ DİZ',
                                                active:
                                                    !_dealInProgress &&
                                                    _rack.length >= 3,
                                                color: const Color(0xFF19862B),
                                                onTap: _arrangeStandardMelds,
                                              ),
                                              _RackAction(
                                                label: 'ÇİFT DİZ',
                                                active:
                                                    !_dealInProgress &&
                                                    _rack.length >= 2,
                                                color: const Color(0xFF9A650E),
                                                onTap: _arrangePairs,
                                              ),
                                              _RackAction(
                                                label: _drawnThisTurn
                                                    ? 'TAŞ AT'
                                                    : 'TAŞ ÇEK',
                                                active: _drawnThisTurn
                                                    ? canAct && sel == 1
                                                    : myTurn &&
                                                          _deck.isNotEmpty,
                                                color: const Color(0xFF08658F),
                                                onTap: _drawnThisTurn
                                                    ? _discardTile
                                                    : _drawFromDeck,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 0,
                        right: 0,
                        child: _TopBar(onSettings: _openGameSettings),
                      ),

                      // Tüm oyun mesajları aynı merkezî bildirimde gösterilir.
                      if (centerNotice != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: const Alignment(0, -0.25),
                              child: RepaintBoundary(
                                child: _GameCenterNotice(text: centerNotice),
                              ),
                            ),
                          ),
                        ),

                      if (_showFinishCelebration)
                        const Positioned.fill(child: _FinishCelebration()),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÜST BAR
// ═══════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _TopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) => _PressScale(
    child: IconButton(
      key: const ValueKey('game-settings-button'),
      tooltip: 'Oyun ayarları',
      onPressed: onSettings,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        minimumSize: const Size(42, 42),
        padding: EdgeInsets.zero,
      ),
      icon: Image.asset(
        'images/ui/game_settings.png',
        width: 40,
        height: 40,
        cacheWidth: 64,
        cacheHeight: 64,
        filterQuality: FilterQuality.low,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// OYUNCU BİLGİSİ (avatar + isim + taş sayısı)
// ═══════════════════════════════════════════════════════════════════════════
class _PlayerInfo extends StatefulWidget {
  final BotPlayer bot;
  final bool active;
  final bool horizontal;

  const _PlayerInfo({
    required this.bot,
    required this.active,
    this.horizontal = false,
  });

  @override
  State<_PlayerInfo> createState() => _PlayerInfoState();
}

class _PlayerInfoState extends State<_PlayerInfo> {
  late final Widget _avatarFace;
  late final Widget _nameTag;

  @override
  void initState() {
    super.initState();
    final avatarSize = widget.horizontal ? 41.0 : 43.0;
    _avatarFace = RepaintBoundary(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFB98532), width: 1.2),
        ),
        child: Image.asset(
          switch (widget.bot.name) {
            'Oyuncu 2' => 'images/ui/avatar_bot2.jpg',
            'Oyuncu 3' => 'images/ui/avatar_bot3.jpg',
            _ => 'images/ui/avatar_bot4.jpg',
          },
          fit: BoxFit.cover,
          cacheWidth: 64,
          cacheHeight: 64,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
        ),
      ),
    );
    _nameTag = RepaintBoundary(
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.horizontal ? 80 : 54),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE6141917),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF7B5224), width: 1),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.bot.displayName,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        _avatarFace,
        Positioned(
          right: -3,
          bottom: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13201C),
              border: Border.all(color: OC.gold, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.bot.tileCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (widget.active)
          Positioned(
            left: -2,
            top: -2,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: OC.okeyGold,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    return Container(
      key: ValueKey('seat-${widget.bot.name}'),
      padding: const EdgeInsets.all(2),
      child: widget.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [avatar, const SizedBox(width: 4), _nameTag],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [avatar, const SizedBox(height: 3), _nameTag],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MASA ALANI
// ═══════════════════════════════════════════════════════════════════════════
class _TableArea extends StatelessWidget {
  final List<Meld> melds;
  final List<BotPlayer> bots;
  final String playerName;
  final int activeTurn;
  final List<List<Tile>> discardPiles;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;
  final bool myTurn;
  final bool drawnThisTurn;
  final ValueChanged<_RackDragData> onPlayerDiscardDrop;
  final GlobalKey playerDiscardTargetKey;
  final bool canTakeDiscard;
  final VoidCallback onTakeDiscard;
  final bool canReturnDiscard;
  final int? returnDiscardTileId;
  final VoidCallback onReturnDiscard;
  final double gridTileWidth;
  final GlobalKey gridKey;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final _BotDiscardMotion? botDiscardMotion;
  final ValueNotifier<_TableTileMotion?> tableTileMotion;
  final double bottomReservedSpace;
  final String gameModeLabel;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;
  final bool showGrid;
  final bool showBots;

  const _TableArea({
    required this.melds,
    required this.bots,
    required this.playerName,
    required this.activeTurn,
    required this.discardPiles,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
    required this.myTurn,
    required this.drawnThisTurn,
    required this.onPlayerDiscardDrop,
    required this.playerDiscardTargetKey,
    required this.canTakeDiscard,
    required this.onTakeDiscard,
    required this.canReturnDiscard,
    required this.returnDiscardTileId,
    required this.onReturnDiscard,
    required this.gridTileWidth,
    required this.gridKey,
    required this.dragVisual,
    required this.botDiscardMotion,
    required this.tableTileMotion,
    required this.bottomReservedSpace,
    required this.gameModeLabel,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
    required this.showGrid,
    required this.showBots,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, tableBox) {
        final playerTwoBottom =
            (tableBox.maxHeight + 112 - bottomReservedSpace) / 2 + 32;
        final discardZoneTop = min(
          tableBox.maxHeight - 72,
          max(96.0, playerTwoBottom),
        );
        final sideDiscardHitWidth = 38 + gridTileWidth * 2;
        const sideDiscardInset = 8.0;
        const upperDiscardTop = 46.0;
        final lowerLeftDiscardBottom = max(2.0, bottomReservedSpace - 104);
        const sideProfileHeight = 72.0;
        const discardHitHeight = 66.0;
        final minimumProfileTop = upperDiscardTop + discardHitHeight + 8;
        double profileTopBefore(double lowerDiscardTop) {
          final maximumProfileTop = max(
            minimumProfileTop,
            lowerDiscardTop - sideProfileHeight - 8,
          );
          return ((minimumProfileTop + maximumProfileTop) / 2).clamp(
            minimumProfileTop,
            maximumProfileTop,
          );
        }

        final leftProfileTop = profileTopBefore(
          tableBox.maxHeight - lowerLeftDiscardBottom - discardHitHeight,
        );
        final rightProfileTop = profileTopBefore(discardZoneTop);
        return Row(
          children: [
            // Seçilen görsel doğrudan masa yüzeyidir. Ek renk katmanı çizmek
            // hem temayı kapatır hem de gereksiz GPU overdraw oluşturur.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(58, 20, 58, 8),
                        child: SizedBox.expand(
                          key: gridKey,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              if (showGrid)
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: _MeldGridBoard(
                                      tileWidth: gridTileWidth,
                                      melds: melds,
                                      uiMode: uiMode,
                                      eligibleMeldIndexes: eligibleMeldIndexes,
                                      onMeldTap: onMeldTap,
                                      onMeldDrop: onMeldDrop,
                                      canAcceptMeldDrop: canAcceptMeldDrop,
                                      onPairDrop: onPairDrop,
                                      canAcceptPairDrop: canAcceptPairDrop,
                                      deckCount: deckCount,
                                      indicator: indicator,
                                      perPoints: perPoints,
                                      showRemainingPoints: showRemainingPoints,
                                      pairCount: pairCount,
                                      minimumStandardOpeningScore:
                                          minimumStandardOpeningScore,
                                      minimumPairOpeningCount:
                                          minimumPairOpeningCount,
                                      canDraw: canDraw,
                                      onDraw: onDraw,
                                      canFinishByCenterDrop:
                                          canFinishByCenterDrop,
                                      onFinishByCenterDrop:
                                          onFinishByCenterDrop,
                                      dragTileWidth: dragTileWidth,
                                      dragTileHeight: dragTileHeight,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child:
                                    ValueListenableBuilder<
                                      _RackDragVisualState
                                    >(
                                      valueListenable: dragVisual,
                                      builder: (context, visual, _) {
                                        return _GridDragMagnifier(
                                          position: visual.gridPosition,
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        left: 58,
                        right: 58,
                        height: 24,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 13,
                              child: _GridTopCaption(
                                key: ValueKey('opening-rule-caption'),
                                text: minimumStandardOpeningScore == null
                                    ? 'EL AÇMA: 101 PER • 5 ÇİFT'
                                    : 'PER: $minimumStandardOpeningScore • '
                                          'ÇİFT: $minimumPairOpeningCount',
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                            Expanded(flex: 8, child: const SizedBox.shrink()),
                            Expanded(
                              flex: 13,
                              child: _GridTopCaption(
                                key: const ValueKey('game-mode-caption'),
                                text: gameModeLabel.toUpperCase(),
                                alignment: Alignment.centerRight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showBots)
                        Positioned(
                          top: -3,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _PlayerInfo(
                              bot: bots[1],
                              active: activeTurn == 2,
                              horizontal: true,
                            ),
                          ),
                        ),
                      if (showBots)
                        Positioned(
                          left: 0,
                          top: leftProfileTop,
                          child: _PlayerInfo(
                            bot: bots[2],
                            active: activeTurn == 3,
                          ),
                        ),
                      if (showBots)
                        Positioned(
                          right: 0,
                          top: rightProfileTop,
                          child: _PlayerInfo(
                            bot: bots[0],
                            active: activeTurn == 1,
                          ),
                        ),
                      if (showBots)
                        Positioned(
                          top: upperDiscardTop,
                          right: sideDiscardInset,
                          child: _TableDiscardPile(
                            tiles: discardPiles[1],
                            label: bots[0].displayName,
                            keyLabel: bots[0].name,
                            hitWidth: sideDiscardHitWidth,
                            visualAlignment: Alignment.topRight,
                          ),
                        ),
                      Positioned(
                        top: discardZoneTop,
                        bottom: 0,
                        right: sideDiscardInset,
                        width: sideDiscardHitWidth,
                        child: _TableDiscardPile(
                          targetKey: playerDiscardTargetKey,
                          tiles: discardPiles[0],
                          label: playerName,
                          keyLabel: 'Oyuncu 1',
                          active: myTurn && drawnThisTurn,
                          onDrop: onPlayerDiscardDrop,
                          hitWidth: sideDiscardHitWidth,
                          hitHeight: tableBox.maxHeight - discardZoneTop,
                          visualAlignment: Alignment.bottomRight,
                        ),
                      ),
                      if (showBots)
                        Positioned(
                          top: upperDiscardTop,
                          left: 8,
                          child: _TableDiscardPile(
                            tiles: discardPiles[2],
                            label: bots[1].displayName,
                            keyLabel: bots[1].name,
                            hitWidth: 38 + gridTileWidth * 2,
                            visualAlignment: Alignment.topLeft,
                          ),
                        ),
                      if (showBots)
                        Positioned(
                          bottom: lowerLeftDiscardBottom,
                          left: 8,
                          child: _TableDiscardPile(
                            tiles: discardPiles[3],
                            label: bots[2].displayName,
                            keyLabel: bots[2].name,
                            takeEnabled: canTakeDiscard,
                            onTake: onTakeDiscard,
                            showReturnButton: canReturnDiscard,
                            returnTileId: returnDiscardTileId,
                            onReturn: onReturnDiscard,
                            hitWidth: 38 + gridTileWidth * 2,
                            visualAlignment: Alignment.bottomLeft,
                          ),
                        ),
                      if (showBots && botDiscardMotion != null)
                        Positioned.fill(
                          child: _FlyingBotDiscard(
                            motion: botDiscardMotion!,
                            bottomReservedSpace: bottomReservedSpace,
                          ),
                        ),
                      Positioned.fill(
                        child: ValueListenableBuilder<_TableTileMotion?>(
                          valueListenable: tableTileMotion,
                          builder: (context, motion, _) => motion == null
                              ? const SizedBox.shrink()
                              : RepaintBoundary(
                                  child: _FlyingTableTiles(motion: motion),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridTopCaption extends StatelessWidget {
  final String text;
  final Alignment alignment;

  const _GridTopCaption({
    super.key,
    required this.text,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Container(
      constraints: const BoxConstraints(maxHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xB30B2823),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x66718D83)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: Color(0xFFE5D5AC),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _TimedRackCountdown extends StatefulWidget {
  final ValueListenable<int> seconds;
  final bool active;

  const _TimedRackCountdown({
    super.key,
    required this.seconds,
    required this.active,
  });

  @override
  State<_TimedRackCountdown> createState() => _TimedRackCountdownState();
}

class _TimedRackCountdownState extends State<_TimedRackCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _lastSeconds;

  @override
  void initState() {
    super.initState();
    _lastSeconds = widget.seconds.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
      value: widget.active && widget.seconds.value <= 0
          ? 1
          : (widget.seconds.value / 7).clamp(0.0, 1.0),
    );
    if (widget.active && widget.seconds.value > 0) {
      _controller.reverse(from: _controller.value);
    }
    widget.seconds.addListener(_handleSecondsChanged);
  }

  void _handleSecondsChanged() {
    final currentSeconds = widget.seconds.value;
    if (widget.active && currentSeconds > _lastSeconds) {
      _controller.duration = const Duration(seconds: 7);
      _controller.reverse(from: (currentSeconds / 7).clamp(0.0, 1.0));
    }
    _lastSeconds = currentSeconds;
  }

  @override
  void didUpdateWidget(covariant _TimedRackCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      oldWidget.seconds.removeListener(_handleSecondsChanged);
      _lastSeconds = widget.seconds.value;
      widget.seconds.addListener(_handleSecondsChanged);
    }
    if (!widget.active) {
      _controller.stop();
      return;
    }
    if (!oldWidget.active && widget.seconds.value > 0) {
      _controller.duration = const Duration(seconds: 7);
      _controller.reverse(from: (widget.seconds.value / 7).clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    widget.seconds.removeListener(_handleSecondsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: const Color(0xE6000000),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          key: const ValueKey('timed-turn-countdown'),
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => SizedBox(
                  key: const ValueKey('timed-turn-countdown-fill'),
                  width: constraints.maxWidth * _controller.value,
                  height: constraints.maxHeight,
                  child: const ColoredBox(color: Color(0xFFFFD33D)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CenteredGridViewer extends StatefulWidget {
  final Widget child;
  final bool alignRight;

  const _CenteredGridViewer({
    super.key,
    required this.child,
    required this.alignRight,
  });

  @override
  State<_CenteredGridViewer> createState() => _CenteredGridViewerState();
}

class _CenteredGridViewerState extends State<_CenteredGridViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformation = TransformationController();
  late final AnimationController _centeringController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      )..addListener(() {
        final animation = _centeringAnimation;
        if (animation != null) _transformation.value = animation.value;
      });
  Animation<Matrix4>? _centeringAnimation;
  bool _lockingBasePan = false;
  bool _showResetButton = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_handleTransformChanged);
  }

  void _handleTransformChanged() {
    _lockPanAtBaseScale();
    final matrix = _transformation.value;
    final translation = matrix.getTranslation();
    final shouldShow =
        matrix.getMaxScaleOnAxis() > 1.002 ||
        translation.x.abs() > 0.5 ||
        translation.y.abs() > 0.5;
    if (shouldShow != _showResetButton && mounted) {
      setState(() => _showResetButton = shouldShow);
    }
  }

  void _lockPanAtBaseScale() {
    if (_lockingBasePan) return;
    final matrix = _transformation.value;
    if (matrix.getMaxScaleOnAxis() > 1.001) return;
    final translation = matrix.getTranslation();
    if (translation.x.abs() < 0.01 && translation.y.abs() < 0.01) return;
    _lockingBasePan = true;
    _transformation.value = Matrix4.identity();
    _lockingBasePan = false;
  }

  @override
  void dispose() {
    _transformation.removeListener(_handleTransformChanged);
    _centeringController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails _) {
    _centeringController.stop();
  }

  void _resetView() {
    _centeringAnimation =
        Matrix4Tween(
          begin: _transformation.value.clone(),
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: _centeringController,
            curve: Curves.easeOutCubic,
          ),
        );
    _centeringController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      return Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: 1,
              maxScale: 3.4,
              panEnabled: true,
              scaleEnabled: true,
              panAxis: PanAxis.free,
              boundaryMargin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              onInteractionStart: _onInteractionStart,
              child: widget.child,
            ),
          ),
          if (_showResetButton)
            Positioned(
              left: widget.alignRight ? null : 5,
              right: widget.alignRight ? 5 : null,
              bottom: 5,
              child: _GridResetButton(onPressed: _resetView),
            ),
        ],
      );
    },
  );
}

class _GridResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GridResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE615211E),
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      key: const ValueKey('grid-reset-button'),
      onTap: onPressed,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: OC.gold.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fit_screen_rounded, size: 13, color: OC.okeyGold),
            SizedBox(width: 4),
            Text(
              'TAM GÖRÜNÜM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GridDragMagnifier extends StatelessWidget {
  final Offset? position;

  const _GridDragMagnifier({required this.position});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final activePosition = position;
        final lensWidth = min(
          box.maxWidth,
          min(180.0, max(112.0, box.maxWidth * 0.24)),
        );
        final lensHeight = min(
          box.maxHeight,
          min(112.0, max(74.0, box.maxHeight * 0.31)),
        );
        final left = ((activePosition?.dx ?? 0) - lensWidth / 2)
            .clamp(0.0, max(0.0, box.maxWidth - lensWidth))
            .toDouble();
        final top = ((activePosition?.dy ?? 0) - lensHeight / 2)
            .clamp(0.0, max(0.0, box.maxHeight - lensHeight))
            .toDouble();
        final lensCenter = Offset(left + lensWidth / 2, top + lensHeight / 2);

        // RawMagnifier'ı sürükleme aralarında ağaçtan çıkarmıyoruz. Böylece
        // engine her taş kaldırılışında yeni bir offscreen yüzey ayırmak yerine
        // aynı küçük yüzeyi yeniden kullanıyor.
        return Offstage(
          offstage: activePosition == null,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                key: const ValueKey('grid-drag-magnifier'),
                left: left,
                top: top,
                child: RawMagnifier(
                  size: Size(lensWidth, lensHeight),
                  magnificationScale: 1.45,
                  focalPointOffset:
                      (activePosition ?? Offset.zero) - lensCenter,
                  clipBehavior: Clip.hardEdge,
                  decoration: MagnifierDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: OC.numGreen.withValues(alpha: 0.88),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _FlyingBotDiscard extends StatelessWidget {
  final _BotDiscardMotion motion;
  final double bottomReservedSpace;

  const _FlyingBotDiscard({
    required this.motion,
    required this.bottomReservedSpace,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          const tileWidth = 27.0;
          const tileHeight = 35.0;
          final startCenter = switch (motion.botIndex) {
            0 => Offset(box.maxWidth - 28, box.maxHeight / 2),
            1 => Offset(box.maxWidth / 2, 24),
            _ => Offset(28, box.maxHeight / 2),
          };
          final endTop = switch (motion.botIndex) {
            0 => const Offset(0, 46),
            1 => const Offset(8, 46),
            _ => Offset(
              8,
              box.maxHeight - max(2, bottomReservedSpace - 104) - tileHeight,
            ),
          };
          final targetLeft = motion.botIndex == 0
              ? box.maxWidth - 8 - tileWidth
              : endTop.dx;
          final targetTop = endTop.dy;
          final targetCenter = Offset(
            targetLeft + tileWidth / 2,
            targetTop + tileHeight / 2,
          );
          final travel = startCenter - targetCenter;
          return Stack(
            children: [
              Positioned(
                left: targetLeft,
                top: targetTop,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bot-discard-motion-${motion.serial}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: travel * (1 - value),
                    child: child,
                  ),
                  child: RepaintBoundary(
                    child: _TileWidget(
                      tile: motion.tile,
                      w: tileWidth,
                      h: tileHeight,
                      onTap: null,
                      showShadow: false,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeckStack extends StatelessWidget {
  final int count;
  final double tileWidth;
  final double tileHeight;

  const _DeckStack({
    required this.count,
    this.tileWidth = 48,
    this.tileHeight = 62,
  });
  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return SizedBox(
        key: const ValueKey('draw-deck-stack'),
        width: tileWidth,
        height: tileHeight,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              'YOK',
              style: TextStyle(
                color: Colors.white54,
                fontSize: tileHeight * 0.13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    final layers = min((count - 1) ~/ 12 + 1, 4);
    final layerOffset = tileWidth * 0.046;
    return SizedBox(
      key: const ValueKey('draw-deck-stack'),
      width: tileWidth + (layers - 1) * layerOffset,
      height: tileHeight + (layers - 1) * layerOffset,
      child: Stack(
        children: [
          ...List.generate(
            layers,
            (i) => Positioned(
              left: i * layerOffset,
              top: i * layerOffset,
              child: _TileBack(
                key: i == layers - 1 ? const ValueKey('draw-deck-tile') : null,
                width: tileWidth,
                height: tileHeight,
                showBorder: false,
              ),
            ),
          ),
          Positioned(
            left: (layers - 1) * layerOffset,
            top: (layers - 1) * layerOffset,
            width: tileWidth,
            height: tileHeight,
            child: Center(
              child: Container(
                width: tileWidth * 0.65,
                height: tileWidth * 0.65,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D2D2).withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF747979),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: tileHeight * 0.26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double cellWidth;
  final double cellHeight;
  final int majorColumnInterval;

  const _GridPainter({
    required this.cellWidth,
    required this.cellHeight,
    this.majorColumnInterval = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x2E7CA0A0)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += cellWidth) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += cellHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    if (majorColumnInterval > 0) {
      final divider = Paint()
        ..color = const Color(0xB8C59B52)
        ..strokeWidth = 2.2;
      final step = cellWidth * majorColumnInterval;
      for (double x = step; x < size.width - 0.5; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), divider);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.majorColumnInterval != majorColumnInterval;
}

class _MeldGridBoard extends StatelessWidget {
  final double tileWidth;
  final List<Meld> melds;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;

  const _MeldGridBoard({
    required this.tileWidth,
    required this.melds,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const frameWidth = 2.0;
      const perRows = 8;
      const pairRows = 6;
      const runColumns = 13;
      const groupColumns = 13;
      const pairColumns = 8;
      const totalGridColumns = runColumns + pairColumns + groupColumns;
      final maximumCellHeight = max(
        2.0,
        (box.maxHeight - frameWidth * 2) / perRows,
      );
      final maximumCellWidth = max(
        2.0,
        (box.maxWidth - frameWidth * 6) / totalGridColumns,
      );
      final fittedTileWidth = min(
        tileWidth,
        min(
          // Gridin yatay ölçüsü ve üç bölümün eski genişlik dengesi korunur.
          // Taşın kendi dikdörtgen oranı aşağıdaki _MeldRow içinde küçültülür.
          max(1.0, (maximumCellHeight - 1) / 1.28),
          max(1.0, maximumCellWidth - 1),
        ),
      );
      final cellWidth = fittedTileWidth + 1;
      final cellHeight = maximumCellHeight;
      final runEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'seri')
          .toList();
      final groupEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'grup')
          .toList();
      final pairEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'cift')
          .toList();
      final viewportWidth = totalGridColumns * cellWidth + frameWidth * 6;
      final viewportHeight = max(perRows * cellHeight + frameWidth * 2, 56.0);

      return Align(
        alignment: Alignment.topCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const ValueKey('meld-grid-viewport'),
            width: viewportWidth,
            height: viewportHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: runColumns * cellWidth + frameWidth * 2,
                  height: perRows * cellHeight + frameWidth * 2,
                  child: _CenteredGridViewer(
                    key: const ValueKey('run-grid-viewer'),
                    alignRight: false,
                    child: _RunMeldGrid(
                      key: const ValueKey('run-meld-grid'),
                      columns: runColumns,
                      rows: perRows,
                      cellWidth: cellWidth,
                      cellHeight: cellHeight,
                      frameWidth: frameWidth,
                      entries: runEntries,
                      uiMode: uiMode,
                      eligibleMeldIndexes: eligibleMeldIndexes,
                      onMeldTap: onMeldTap,
                      onMeldDrop: onMeldDrop,
                      canAcceptMeldDrop: canAcceptMeldDrop,
                      meldGapColumns: 1,
                    ),
                  ),
                ),
                SizedBox(
                  width: pairColumns * cellWidth + frameWidth * 2,
                  height: viewportHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: cellHeight * 0.72,
                        height: pairRows * cellHeight * 0.86 + frameWidth * 2,
                        child: _CenteredGridViewer(
                          key: const ValueKey('pair-grid-viewer'),
                          alignRight: false,
                          child: _PairMeldGrid(
                            key: const ValueKey('pair-meld-grid'),
                            columns: pairColumns,
                            rows: pairRows,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight * 0.86,
                            frameWidth: frameWidth,
                            entries: pairEntries,
                            uiMode: uiMode,
                            eligibleMeldIndexes: eligibleMeldIndexes,
                            onMeldTap: onMeldTap,
                            onMeldDrop: onMeldDrop,
                            canAcceptMeldDrop: canAcceptMeldDrop,
                            onPairDrop: onPairDrop,
                            canAcceptPairDrop: canAcceptPairDrop,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: cellHeight * (perRows - pairRows),
                        child: _GridDrawColumn(
                          width: pairColumns * cellWidth + frameWidth * 2,
                          height: cellHeight * (perRows - pairRows),
                          deckCount: deckCount,
                          indicator: indicator,
                          perPoints: perPoints,
                          showRemainingPoints: showRemainingPoints,
                          pairCount: pairCount,
                          minimumStandardOpeningScore:
                              minimumStandardOpeningScore,
                          minimumPairOpeningCount: minimumPairOpeningCount,
                          canDraw: canDraw,
                          onDraw: onDraw,
                          canFinishByCenterDrop: canFinishByCenterDrop,
                          onFinishByCenterDrop: onFinishByCenterDrop,
                          dragTileWidth: dragTileWidth,
                          dragTileHeight: dragTileHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: groupColumns * cellWidth + frameWidth * 2,
                  height: perRows * cellHeight + frameWidth * 2,
                  child: _CenteredGridViewer(
                    key: const ValueKey('group-grid-viewer'),
                    alignRight: true,
                    child: _RunMeldGrid(
                      key: const ValueKey('group-meld-grid'),
                      columns: groupColumns,
                      rows: perRows,
                      cellWidth: cellWidth,
                      cellHeight: cellHeight,
                      frameWidth: frameWidth,
                      entries: groupEntries,
                      uiMode: uiMode,
                      eligibleMeldIndexes: eligibleMeldIndexes,
                      onMeldTap: onMeldTap,
                      onMeldDrop: onMeldDrop,
                      canAcceptMeldDrop: canAcceptMeldDrop,
                      meldGapColumns: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _GridDrawColumn extends StatelessWidget {
  final double width;
  final double height;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;

  const _GridDrawColumn({
    required this.width,
    required this.height,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final displayTileWidth = dragTileWidth;
    final displayTileHeight = dragTileHeight;
    final itemWidth = displayTileWidth;
    return Container(
      key: const ValueKey('table-draw-column'),
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xD90B403B),
        border: Border(bottom: BorderSide(color: Color(0xFFC48A31), width: 2)),
      ),
      child: LayoutBuilder(
        builder: (context, area) => Stack(
          children: [
            Positioned(
              left: 2,
              bottom: 2,
              child: SizedBox(
                key: const ValueKey('grid-per-summary'),
                width: (area.maxWidth - 4) / 4,
                height: min(displayTileHeight * 1.22, area.maxHeight - 4),
                child: _RackPerSummary(
                  points: perPoints,
                  showRemaining: showRemainingPoints,
                  pairCount: pairCount,
                ),
              ),
            ),
            Positioned(
              left: (area.maxWidth - 4) / 4 + 6,
              right: 2,
              bottom: 2,
              height: min(displayTileHeight * 1.22, area.maxHeight - 4),
              child: GestureDetector(
                key: const ValueKey('expanded-deck-draw-hit-area'),
                behavior: HitTestBehavior.opaque,
                onTap: canDraw ? onDraw : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A332F).withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFC48A31).withValues(alpha: 0.32),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            if (minimumStandardOpeningScore != null &&
                minimumPairOpeningCount != null)
              Positioned(
                left: (area.maxWidth - 4) / 4 + 8,
                bottom: 4,
                width: (area.maxWidth - 4) / 4,
                height: min(displayTileHeight * 1.16, area.maxHeight - 8),
                child: IgnorePointer(
                  child: _ProgressiveOpeningBadge(
                    standardScore: minimumStandardOpeningScore!,
                    pairCount: minimumPairOpeningCount!,
                  ),
                ),
              ),
            Positioned(
              right: 2,
              bottom: 2,
              child: DragTarget<_RackDragData>(
                key: const ValueKey('center-finish-drop-target'),
                onWillAcceptWithDetails: (details) =>
                    canFinishByCenterDrop && details.data.tileIds.length == 1,
                onAcceptWithDetails: (details) =>
                    onFinishByCenterDrop(details.data),
                builder: (context, candidates, rejected) => Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? OC.okeyGold.withValues(alpha: 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: candidates.isNotEmpty
                        ? Border.all(color: OC.okeyGold, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (indicator != null)
                        SizedBox(
                          key: const ValueKey('grid-indicator'),
                          width: itemWidth,
                          height: displayTileHeight,
                          child: _TileWidget(
                            tile: indicator!,
                            w: displayTileWidth,
                            h: displayTileHeight,
                            onTap: null,
                          ),
                        ),
                      const SizedBox(width: 2),
                      SizedBox(
                        key: const ValueKey('grid-deck-slot'),
                        width: itemWidth,
                        height: displayTileHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: canDraw ? onDraw : null,
                          child: _DeckDrawHandle(
                            enabled: canDraw,
                            count: deckCount,
                            onDraw: onDraw,
                            feedbackWidth: dragTileWidth,
                            feedbackHeight: dragTileHeight,
                            displayWidth: displayTileWidth,
                            displayHeight: displayTileHeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairMeldGrid extends StatelessWidget {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double frameWidth;
  final List<MapEntry<int, Meld>> entries;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;

  const _PairMeldGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.frameWidth,
    required this.entries,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('pair-meld-grid-surface'),
    width: columns * cellWidth + frameWidth * 2,
    height: rows * cellHeight + frameWidth * 2,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xFF082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GridPainter(
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                majorColumnInterval: 2,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DragTarget<_RackDragData>(
            key: const ValueKey('pair-area-drop-target'),
            onWillAcceptWithDetails: (details) =>
                canAcceptPairDrop(details.data),
            onAcceptWithDetails: (details) => onPairDrop(details.data),
            builder: (context, candidates, rejected) {
              final acceptedHover = candidates.isNotEmpty;
              final rejectedHover = rejected.isNotEmpty;
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: acceptedHover
                        ? OC.numGreen.withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: acceptedHover || rejectedHover
                        ? Border.all(
                            color: acceptedHover ? OC.okeyGold : OC.numRed,
                            width: 2.5,
                          )
                        : null,
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 3),
                  child: acceptedHover
                      ? const Text(
                          'ÇİFTİ BURAYA BIRAK',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: OC.okeyGold,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Wrap(
            spacing: 0,
            runSpacing: 0,
            children: [
              for (final entry in entries)
                SizedBox(
                  key: ValueKey('pair-meld-${entry.key}'),
                  width: cellWidth * 2,
                  height: cellHeight,
                  child: DragTarget<_RackDragData>(
                    key: ValueKey('pair-meld-target-${entry.key}'),
                    onWillAcceptWithDetails: (details) =>
                        canAcceptMeldDrop(entry.key, details.data),
                    onAcceptWithDetails: (details) =>
                        onMeldDrop(entry.key, details.data),
                    builder: (context, candidates, rejected) {
                      final isEligible =
                          uiMode == 'addMeld' &&
                          eligibleMeldIndexes.contains(entry.key);
                      final acceptedHover = candidates.isNotEmpty;
                      final rejectedHover = rejected.isNotEmpty;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isEligible ? () => onMeldTap(entry.key) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: acceptedHover
                                ? OC.gold.withValues(alpha: 0.30)
                                : isEligible
                                ? OC.numGreen.withValues(alpha: 0.25)
                                : Colors.transparent,
                            border: acceptedHover || rejectedHover
                                ? Border.all(
                                    color: acceptedHover
                                        ? OC.okeyGold
                                        : OC.numRed,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: LayoutBuilder(
                            builder: (context, pairBox) => _CachedMeldRow(
                              meld: entry.value,
                              cellWidth:
                                  pairBox.maxWidth /
                                  max(1, entry.value.tiles.length),
                              cellHeight: pairBox.maxHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RunMeldGrid extends StatelessWidget {
  static final Map<int, List<({int row, int column})>> _layoutCache = {};

  static void clearLayoutCache() => _layoutCache.clear();
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double frameWidth;
  final List<MapEntry<int, Meld>> entries;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final int meldGapColumns;

  const _RunMeldGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.frameWidth,
    required this.entries,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    this.meldGapColumns = 0,
  });

  List<({MapEntry<int, Meld> entry, int row, int column})> _placements() {
    final cacheKey = Object.hash(
      columns,
      rows,
      meldGapColumns,
      Object.hashAll(
        entries.map(
          (entry) => Object.hash(
            entry.key,
            entry.value.type,
            Object.hashAll(entry.value.tiles.map((tile) => tile.id)),
          ),
        ),
      ),
    );
    final cached = _layoutCache[cacheKey];
    if (cached != null && cached.length == entries.length) {
      return [
        for (var index = 0; index < entries.length; index++)
          (
            entry: entries[index],
            row: cached[index].row,
            column: cached[index].column,
          ),
      ];
    }

    List<({MapEntry<int, Meld> entry, int row, int column})> remember(
      List<({MapEntry<int, Meld> entry, int row, int column})> result,
    ) {
      if (_layoutCache.length >= 3) _layoutCache.clear();
      _layoutCache[cacheKey] = [
        for (final placement in result)
          (row: placement.row, column: placement.column),
      ];
      return result;
    }

    if (entries.isNotEmpty && entries.first.value.type == 'grup') {
      final result = <({MapEntry<int, Meld> entry, int row, int column})>[];
      var row = 0;
      var column = 0;
      for (final entry in entries) {
        final length = min(columns, entry.value.tiles.length);
        if (column > 0 && column + length > columns) {
          row++;
          column = 0;
        }
        if (row >= rows) break;
        result.add((entry: entry, row: row, column: column));
        column += length + meldGapColumns;
        if (column >= columns) {
          row++;
          column = 0;
        }
      }
      return remember(result);
    }

    final occupied = <int, Set<int>>{};
    final rowsByColor = <TileColor, List<int>>{
      for (final color in TileColor.values) color: [min(color.index, rows - 1)],
    };
    final rowOwners = <int, TileColor>{
      for (final color in TileColor.values)
        if (color.index < rows) color.index: color,
    };
    final result = <({MapEntry<int, Meld> entry, int row, int column})>[];

    for (final entry in entries) {
      final meld = entry.value;
      final color = meld.tiles
          .firstWhere((tile) => !tile.isOkey, orElse: () => meld.tiles.first)
          .color;
      final anchorIndex = meld.tiles.indexWhere((tile) => !tile.isOkey);
      final rawStart = anchorIndex < 0
          ? 0
          : meld.tiles[anchorIndex].number - 1 - anchorIndex;
      final column = rawStart
          .clamp(0, max(0, columns - meld.tiles.length))
          .toInt();
      final reservedColumns = {
        for (
          var reserved = max(0, column - meldGapColumns);
          reserved <=
              min(columns - 1, column + meld.tiles.length - 1 + meldGapColumns);
          reserved++
        )
          reserved,
      };
      final colorRows = rowsByColor[color]!;
      int? targetRow;
      for (final row in colorRows) {
        final rowColumns = occupied[row] ?? const <int>{};
        if (rowColumns.intersection(reservedColumns).isEmpty) {
          targetRow = row;
          break;
        }
      }

      if (targetRow == null) {
        for (var row = rows - 1; row >= TileColor.values.length; row--) {
          if (rowOwners.containsKey(row)) continue;
          rowOwners[row] = color;
          colorRows.add(row);
          targetRow = row;
          break;
        }
      }
      targetRow ??= colorRows.last;
      occupied.putIfAbsent(targetRow, () => <int>{}).addAll(reservedColumns);
      result.add((entry: entry, row: targetRow, column: column));
    }
    return remember(result);
  }

  ({int index, bool replacesOkey})? _placementFor(
    Meld meld,
    _RackDragData data,
  ) {
    if (data.tileIds.length != 1) return null;
    final replacementIndex = Rules.okeyReplacementIndex(meld, data.tile);
    if (replacementIndex != null) {
      return (index: replacementIndex, replacesOkey: true);
    }
    if (!Rules.canAddToMeld(meld, [data.tile])) return null;
    final ordered = Rules.extendMeldKeepingPositions(meld.tiles, [
      data.tile,
    ], meld.type);
    final index = ordered.indexWhere((tile) => tile.id == data.tile.id);
    return index < 0 ? null : (index: index, replacesOkey: false);
  }

  Widget _meldWidget(MapEntry<int, Meld> entry) {
    final isEligible =
        uiMode == 'addMeld' && eligibleMeldIndexes.contains(entry.key);
    const hitPadding = 8.0;
    return Transform.translate(
      key: ValueKey('run-meld-${entry.key}'),
      offset: const Offset(-hitPadding, -hitPadding),
      child: SizedBox(
        width: cellWidth * entry.value.tiles.length + hitPadding * 2,
        height: cellHeight + hitPadding * 2,
        child: DragTarget<_RackDragData>(
          onWillAcceptWithDetails: (details) =>
              canAcceptMeldDrop(entry.key, details.data),
          onAcceptWithDetails: (details) => onMeldDrop(entry.key, details.data),
          builder: (context, candidates, rejected) {
            final acceptedCandidates = candidates
                .whereType<_RackDragData>()
                .toList();
            final acceptedHover = acceptedCandidates.isNotEmpty;
            final hovering = acceptedHover || rejected.isNotEmpty;
            final focusColor = acceptedHover ? OC.okeyGold : OC.numRed;
            final placement = acceptedHover
                ? _placementFor(entry.value, acceptedCandidates.last)
                : null;
            return Padding(
              padding: const EdgeInsets.all(hitPadding),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isEligible ? () => onMeldTap(entry.key) : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hovering || isEligible)
                        Positioned.fill(
                          child: ColoredBox(
                            color: hovering
                                ? (acceptedHover ? OC.gold : OC.numRed)
                                      .withValues(alpha: 0.30)
                                : OC.numGreen.withValues(alpha: 0.25),
                          ),
                        ),
                      Positioned.fill(
                        child: _CachedMeldRow(
                          meld: entry.value,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                        ),
                      ),
                      if (placement != null)
                        _MeldPlacementPreview(
                          tile: acceptedCandidates.last.tile,
                          index: placement.index,
                          currentTileCount: entry.value.tiles.length,
                          replacesOkey: placement.replacesOkey,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                        ),
                      if (hovering)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: focusColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: columns * cellWidth + frameWidth * 2,
    height: rows * cellHeight + frameWidth * 2,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xFF082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GridPainter(
                cellWidth: cellWidth,
                cellHeight: cellHeight,
              ),
            ),
          ),
        ),
        for (final placement in _placements())
          Positioned(
            left: placement.column * cellWidth,
            top: placement.row * cellHeight,
            child: _meldWidget(placement.entry),
          ),
      ],
    ),
  );
}

class _MeldPlacementPreview extends StatelessWidget {
  final Tile tile;
  final int index;
  final int currentTileCount;
  final bool replacesOkey;
  final double cellWidth;
  final double cellHeight;

  const _MeldPlacementPreview({
    required this.tile,
    required this.index,
    required this.currentTileCount,
    required this.replacesOkey,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tileWidth = max(1.0, min(cellWidth - 1, (cellHeight - 1) / 1.46));
    final tileHeight = max(1.0, tileWidth * 1.46);
    final left = replacesOkey
        ? index * cellWidth
        : index <= 0
        ? -cellWidth
        : index >= currentTileCount
        ? currentTileCount * cellWidth
        : index * cellWidth - cellWidth * 0.5;

    return Positioned(
      key: const ValueKey('meld-drop-preview'),
      left: left,
      top: 0,
      width: cellWidth,
      height: cellHeight,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.92,
              child: Container(
                width: tileWidth,
                height: tileHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: tile.displayColor.withValues(alpha: 0.88),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -2,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: OC.okeyGold,
                size: max(13, cellWidth * 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeldRow extends StatelessWidget {
  final Meld meld;
  final double cellWidth;
  final double cellHeight;

  const _MeldRow({
    required this.meld,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tileWidth = max(1.0, min(cellWidth - 1, (cellHeight - 1) / 1.46));
    final tileHeight = max(1.0, tileWidth * 1.46);
    return Row(
      children: meld.tiles
          .map(
            (tile) => SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: Center(
                child: _TileWidget(
                  tile: tile,
                  w: tileWidth,
                  h: tileHeight,
                  onTap: null,
                  hideOkey: true,
                  allowOkeyFaceToggle: false,
                  emphasized: true,
                  numberScale: 1.08,
                  showShadow: false,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALT ALAN (Sen + Atılan/Çekilen)
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// ISTAKA
// ═══════════════════════════════════════════════════════════════════════════
class _CachedMeldRow extends StatefulWidget {
  final Meld meld;
  final double cellWidth;
  final double cellHeight;

  const _CachedMeldRow({
    required this.meld,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  State<_CachedMeldRow> createState() => _CachedMeldRowState();
}

class _CachedMeldRowState extends State<_CachedMeldRow> {
  late int _signature;
  late Widget _row;

  int _calculateSignature() => Object.hash(
    widget.cellWidth,
    widget.cellHeight,
    widget.meld.type,
    Object.hashAll(widget.meld.tiles.map((tile) => tile.id)),
  );

  Widget _buildRow() => _MeldRow(
    meld: widget.meld,
    cellWidth: widget.cellWidth,
    cellHeight: widget.cellHeight,
  );

  @override
  void initState() {
    super.initState();
    _signature = _calculateSignature();
    _row = _buildRow();
  }

  @override
  void didUpdateWidget(covariant _CachedMeldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _calculateSignature();
    if (next == _signature) return;
    _signature = next;
    _row = _buildRow();
  }

  @override
  Widget build(BuildContext context) => _row;
}

class _RackArea extends StatefulWidget {
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final Function(int) onTileTap;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final Set<int> processableTileIds;
  final int? drawAttentionTileId;
  final int drawAttentionSerial;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;

  const _RackArea({
    required this.rack,
    required this.slots,
    required this.dealAnimationSerial,
    required this.onTileTap,
    required this.onReorder,
    required this.onTileDragStart,
    required this.onTileDragUpdate,
    required this.onTileDragEnd,
    required this.dragVisual,
    required this.pushPreview,
    required this.processableTileIds,
    required this.drawAttentionTileId,
    required this.drawAttentionSerial,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  State<_RackArea> createState() => _RackAreaState();
}

class _RackAreaState extends State<_RackArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  );
  final ValueNotifier<double> _dealProgress = ValueNotifier<double>(1);

  void _syncDealProgress() {
    final next = _dealController.value;
    // Dağıtım görünümünü yaklaşık 36 FPS ile yenilemek, 22 ayrı taşın her
    // ekran tazelemesinde tekrar çizilmesini engellerken hareketi akıcı tutar.
    if ((next - _dealProgress.value).abs() >= 1 / 36 || next == 1) {
      _dealProgress.value = next;
    }
  }

  @override
  void initState() {
    super.initState();
    _dealController.addListener(_syncDealProgress);
    if (widget.dealAnimationSerial != null) {
      _dealProgress.value = 0;
      _dealController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _RackArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dealAnimationSerial != null &&
        widget.dealAnimationSerial != oldWidget.dealAnimationSerial) {
      _dealProgress.value = 0;
      _dealController.forward(from: 0);
    } else if (widget.dealAnimationSerial == null) {
      _dealController.stop();
      _dealController.value = 1;
      _dealProgress.value = 1;
    }
  }

  @override
  void dispose() {
    _dealController.removeListener(_syncDealProgress);
    _dealController.dispose();
    _dealProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rackImage = ResizeImage(
      AssetImage(storeCosmetics.rackAsset),
      width: _rackDecodeWidth(context),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Stack(
        key: const ValueKey('rack-area-surface'),
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: rackImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, rackBox) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    rackBox.maxWidth * storeCosmetics.rackHorizontalInset,
                vertical: 2,
              ),
              child: DragTarget<_DeckDragData>(
                onWillAcceptWithDetails: (_) => false,
                onAcceptWithDetails: (_) {},
                builder: (context, candidates, rejected) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: candidates.isNotEmpty
                      ? const EdgeInsets.all(3)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? OC.numGreen.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: candidates.isNotEmpty
                        ? Border.all(color: OC.numGreen, width: 2)
                        : null,
                  ),
                  child: DragTarget<_DiscardDragData>(
                    onWillAcceptWithDetails: (_) => false,
                    onAcceptWithDetails: (_) {},
                    builder: (context, discardCandidates, rejected) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: discardCandidates.isNotEmpty
                                ? OC.gold.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: _RackRows(
                            rack: widget.rack,
                            slots: widget.slots,
                            dealAnimationSerial: widget.dealAnimationSerial,
                            dealProgress: _dealProgress,
                            processableTileIds: widget.processableTileIds,
                            drawAttentionTileId: widget.drawAttentionTileId,
                            drawAttentionSerial: widget.drawAttentionSerial,
                            onTileTap: widget.onTileTap,
                            onReorder: widget.onReorder,
                            onTileDragStart: widget.onTileDragStart,
                            onTileDragUpdate: widget.onTileDragUpdate,
                            onTileDragEnd: widget.onTileDragEnd,
                            dragVisual: widget.dragVisual,
                            pushPreview: widget.pushPreview,
                            canAcceptDeckDrop: widget.canAcceptDeckDrop,
                            canAcceptDiscardDrop: widget.canAcceptDiscardDrop,
                            onDeckDropAt: widget.onDeckDropAt,
                            onDiscardDropAt: widget.onDiscardDropAt,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RackSlotDropTarget extends StatelessWidget {
  final int slotIndex;
  final int rowEnd;
  final int? occupiedTileId;
  final double tileWidth;
  final double tileHeight;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final List<int?> rackSlots;
  final Widget child;

  const _RackSlotDropTarget({
    required this.slotIndex,
    required this.rowEnd,
    required this.occupiedTileId,
    required this.tileWidth,
    required this.tileHeight,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
    required this.onReorder,
    required this.pushPreview,
    required this.rackSlots,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    BuildContext? hitTestContext;

    ({int target, _RackMoveKind kind})? moveFor(
      Offset feedbackOffset,
      _RackDragData data,
    ) {
      if (occupiedTileId == null) {
        return (target: slotIndex, kind: _RackMoveKind.insert);
      }
      final renderObject = hitTestContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return null;
      }
      final center = feedbackOffset + Offset(tileWidth / 2, tileHeight / 2);
      final local = renderObject.globalToLocal(center);
      final edgeWidth = renderObject.size.width * 0.22;
      // İttirme yalnız iki taşın gerçek birleşim çizgisinde başlar. Taşın geniş
      // orta bölgesi ise ayrı bir zincir ittirme hedefidir.
      if (local.dx <= edgeWidth) {
        return slotIndex == data.sourceSlot
            ? null
            : (target: slotIndex, kind: _RackMoveKind.insert);
      }
      if (local.dx >= renderObject.size.width - edgeWidth &&
          slotIndex + 1 < rowEnd) {
        final afterSlot = slotIndex + 1;
        return afterSlot == data.sourceSlot
            ? null
            : (target: afterSlot, kind: _RackMoveKind.insert);
      }
      return slotIndex == data.sourceSlot
          ? null
          : (target: slotIndex, kind: _RackMoveKind.push);
    }

    return DragTarget<Object>(
      key: ValueKey('rack-slot-$slotIndex'),
      onWillAcceptWithDetails: (details) => switch (details.data) {
        _DeckDragData() => canAcceptDeckDrop,
        _DiscardDragData() => canAcceptDiscardDrop,
        _RackDragData(:final tileId) => tileId != occupiedTileId,
        _ => false,
      },
      onMove: (details) {
        final data = details.data;
        if (data is! _RackDragData || occupiedTileId == null) {
          if (pushPreview.value != null) pushPreview.value = null;
          return;
        }
        final move = moveFor(details.offset, data);
        if (move == null || move.target == data.sourceSlot) {
          if (pushPreview.value != null) pushPreview.value = null;
          return;
        }
        final previewSlots = List<int?>.from(rackSlots);
        previewSlots[data.sourceSlot] = null;
        final sameRow =
            data.sourceSlot ~/ _GameScreenState._rackRowLength ==
            move.target ~/ _GameScreenState._rackRowLength;
        int vacancy;
        var valid = true;
        if (move.kind == _RackMoveKind.insert) {
          vacancy = _nearestRackVacancy(previewSlots, move.target);
          final destination = vacancy < move.target
              ? move.target - 1
              : move.target;
          valid = vacancy >= 0 && destination != data.sourceSlot;
        } else {
          vacancy = _rackPushVacancy(
            previewSlots,
            data.sourceSlot,
            move.target,
          );
          valid = sameRow && vacancy >= 0;
        }
        final next = !valid
            ? null
            : _RackPushPreview(
                tileId: data.tileId,
                sourceSlot: data.sourceSlot,
                targetSlot: move.target,
                vacancySlot: vacancy,
                kind: move.kind,
              );
        final current = pushPreview.value;
        if (current?.tileId != next?.tileId ||
            current?.targetSlot != next?.targetSlot ||
            current?.vacancySlot != next?.vacancySlot ||
            current?.kind != next?.kind) {
          pushPreview.value = next;
        }
      },
      onLeave: (data) {
        if (data is _RackDragData && pushPreview.value?.tileId == data.tileId) {
          pushPreview.value = null;
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is _DeckDragData) {
          onDeckDropAt(slotIndex);
          return;
        }
        if (data is _DiscardDragData) {
          onDiscardDropAt(slotIndex);
          return;
        }
        if (data is! _RackDragData) return;
        final preview = pushPreview.value;
        pushPreview.value = null;
        final move = preview?.tileId == data.tileId
            ? (target: preview!.targetSlot, kind: preview.kind)
            : moveFor(details.offset, data);
        if (move == null) return;
        onReorder(data.tileId, move.target, move.kind);
      },
      builder: (_, _, _) => Builder(
        builder: (context) {
          hitTestContext = context;
          return child;
        },
      ),
    );
  }
}

/// GitHub sürümündeki raf duruşunu ve sürükleme görünümünü yönetir.
/// Yer değiştirme, araya sokma ve zincir ittirme kararları ayrı tutulur.
class _RackTileDraggable extends StatelessWidget {
  final Key draggableKey;
  final Tile tile;
  final _RackDragData data;
  final double width;
  final double height;
  final Widget child;
  final ValueChanged<_RackDragData> onDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final bool liftForMeld;

  const _RackTileDraggable({
    required this.draggableKey,
    required this.tile,
    required this.data,
    required this.width,
    required this.height,
    required this.child,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.dragVisual,
    required this.liftForMeld,
  });

  @override
  Widget build(BuildContext context) => Draggable<_RackDragData>(
    key: draggableKey,
    data: data,
    dragAnchorStrategy: (_, _, _) =>
        Offset(width / 2, height / 2 + (liftForMeld ? _meldDragLift : 0)),
    // Hit-test noktası her taşta parmağın altında kalır. İşlenebilir taşlarda
    // hedefi yukarı kaydırmak raf içi sürüklemeyi zaman zaman kilitliyordu.
    feedbackOffset: Offset(0, liftForMeld ? -_meldDragLift : 0),
    onDragStarted: () => onDragStart(data),
    onDragUpdate: (details) => onDragUpdate(data, details),
    onDragEnd: (_) => onDragEnd(),
    feedback: ValueListenableBuilder<_RackDragVisualState>(
      valueListenable: dragVisual,
      child: Material(
        color: Colors.transparent,
        child: _TileWidget(
          tile: tile,
          w: width,
          h: height,
          onTap: null,
          hideOkey: true,
          emphasized: true,
          showShadow: false,
        ),
      ),
      builder: (context, visual, feedbackChild) => Transform.rotate(
        angle: visual.tilt,
        alignment: Alignment.bottomCenter,
        child: AnimatedScale(
          scale: visual.gridPosition == null ? 1 : 1.16,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: feedbackChild,
        ),
      ),
    ),
    // Yalnızca aktif sürükleme süresince kaynak yuva boş görünür. Taş yeni
    // yuvaya geçince kendi görünümü otomatik olarak ve kalıcı gizleme olmadan döner.
    childWhenDragging: SizedBox(width: width, height: height),
    child: child,
  );
}

class _RackRows extends StatelessWidget {
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final ValueListenable<double> dealProgress;
  final Set<int> processableTileIds;
  final int? drawAttentionTileId;
  final int drawAttentionSerial;
  final Function(int) onTileTap;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;
  const _RackRows({
    required this.rack,
    required this.slots,
    required this.dealAnimationSerial,
    required this.dealProgress,
    required this.processableTileIds,
    required this.drawAttentionTileId,
    required this.drawAttentionSerial,
    required this.onTileTap,
    required this.onReorder,
    required this.onTileDragStart,
    required this.onTileDragUpdate,
    required this.onTileDragEnd,
    required this.dragVisual,
    required this.pushPreview,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final avail = box.maxWidth;
        // Sürükleme sırasında hedef yuvalar 3'er piksel yatay vurgu alır.
        // En dar web görünümünde dahi satırın taşmaması için bu payı baştan ayır.
        final widthBasedTile = avail / _GameScreenState._rackRowLength - 1.6;
        final tw = max(1.0, widthBasedTile);
        final rowHeight = max(1.0, (box.maxHeight - 2) / 2);
        final th = min(tw * 1.58, rowHeight);
        return Column(
          children: [
            SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: _buildRow(0, tw, th),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: _buildRow(_GameScreenState._rackRowLength, tw, th),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Tile? _tileById(int? id) {
    if (id == null) return null;
    for (final tile in rack) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  Widget _buildRow(int offset, double tw, double th) {
    final selectedIds = rack
        .where((tile) => tile.selected)
        .map((tile) => tile.id)
        .toSet();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...List.generate(_GameScreenState._rackRowLength, (rowIndex) {
          final slotIndex = offset + rowIndex;
          final tile = _tileById(slots[slotIndex]);
          if (tile == null) {
            return _RackSlotDropTarget(
              slotIndex: slotIndex,
              rowEnd: offset + _GameScreenState._rackRowLength,
              occupiedTileId: null,
              tileWidth: tw,
              tileHeight: th,
              canAcceptDeckDrop: canAcceptDeckDrop,
              canAcceptDiscardDrop: canAcceptDiscardDrop,
              onDeckDropAt: onDeckDropAt,
              onDiscardDropAt: onDiscardDropAt,
              onReorder: onReorder,
              pushPreview: pushPreview,
              rackSlots: slots,
              child: Container(
                width: tw,
                height: th,
                margin: const EdgeInsets.symmetric(horizontal: 0.6),
              ),
            );
          }

          final dragData = _RackDragData(
            tileId: tile.id,
            sourceSlot: slotIndex,
            tileIds: tile.selected ? selectedIds : {tile.id},
            tile: tile,
          );
          final visibleTile = _TileWidget(
            key: ValueKey('rack-visible-tile-$slotIndex'),
            tile: tile,
            w: tw,
            h: th,
            onTap: () => onTileTap(tile.id),
            hideOkey: true,
            emphasized: true,
            processable: processableTileIds.contains(tile.id),
          );
          final dealIndex =
              slots.take(slotIndex + 1).whereType<int>().length - 1;
          final baseTileWidget = dealAnimationSerial == null
              ? visibleTile
              : _DealtRackTile(
                  key: ValueKey('rack-deal-$dealAnimationSerial-${tile.id}'),
                  dealIndex: dealIndex,
                  width: tw,
                  height: th,
                  front: visibleTile,
                  progress: dealProgress,
                );
          final tileWidget = tile.id == drawAttentionTileId
              ? _DrawnTileAttention(
                  key: ValueKey('draw-attention-$drawAttentionSerial'),
                  child: baseTileWidget,
                )
              : baseTileWidget;

          return _RackSlotDropTarget(
            slotIndex: slotIndex,
            rowEnd: offset + _GameScreenState._rackRowLength,
            occupiedTileId: tile.id,
            tileWidth: tw,
            tileHeight: th,
            canAcceptDeckDrop: canAcceptDeckDrop,
            canAcceptDiscardDrop: canAcceptDiscardDrop,
            onDeckDropAt: onDeckDropAt,
            onDiscardDropAt: onDiscardDropAt,
            onReorder: onReorder,
            pushPreview: pushPreview,
            rackSlots: slots,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.6),
              child: _RackTileDraggable(
                draggableKey: ValueKey('rack-tile-${tile.id}'),
                tile: tile,
                data: dragData,
                width: tw,
                height: th,
                onDragStart: onTileDragStart,
                onDragUpdate: onTileDragUpdate,
                onDragEnd: onTileDragEnd,
                dragVisual: dragVisual,
                liftForMeld: processableTileIds.contains(tile.id),
                child: tileWidget,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RackAction {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final bool isUndo;
  final String? secondaryLabel;
  final bool secondaryActive;
  final Color? secondaryColor;
  final VoidCallback? secondaryOnTap;

  const _RackAction({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.isUndo = false,
    this.secondaryLabel,
    this.secondaryActive = false,
    this.secondaryColor,
    this.secondaryOnTap,
  });
}

class _RackActionPanel extends StatelessWidget {
  final List<_RackAction> actions;

  const _RackActionPanel({required this.actions});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF111815),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF8A6027), width: 1.5),
    ),
    child: Column(
      children: [
        ...actions.asMap().entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _SceneActionButton(action: entry.value),
            ),
          );
        }),
      ],
    ),
  );
}

class _ProgressiveOpeningBadge extends StatelessWidget {
  final int standardScore;
  final int pairCount;

  const _ProgressiveOpeningBadge({
    required this.standardScore,
    required this.pairCount,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('progressive-opening-target'),
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xEE251B0D),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: OC.okeyGold, width: 1.2),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PER: $standardScore',
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: OC.numGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'ÇİFT: $pairCount',
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: Color(0xFFFFD66B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RackPerSummary extends StatelessWidget {
  final int points;
  final bool showRemaining;
  final int? pairCount;

  const _RackPerSummary({
    required this.points,
    required this.showRemaining,
    required this.pairCount,
  });

  @override
  Widget build(BuildContext context) {
    final label = showRemaining ? 'KALAN' : 'TOPLAM';
    final value = pairCount ?? points;
    final highlighted =
        (pairCount != null && pairCount! >= 5) ||
        (!showRemaining && pairCount == null && points >= 101);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF251B0D),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: highlighted ? OC.numGreen : const Color(0xFF8A6027),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: highlighted ? OC.numGreen : Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneActionButton extends StatelessWidget {
  final _RackAction action;

  const _SceneActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    if (action.secondaryLabel == null) {
      return SizedBox.expand(child: _SceneActionButtonFace(action: action));
    }
    return SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _SceneActionButtonFace(action: action)),
          const SizedBox(width: 4),
          Expanded(
            child: _SceneActionButtonFace(
              action: _RackAction(
                label: action.secondaryLabel!,
                active: action.secondaryActive,
                color: action.secondaryColor ?? const Color(0xFF9A650E),
                onTap: action.secondaryOnTap ?? action.onTap,
                isUndo: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneActionButtonFace extends StatelessWidget {
  final _RackAction action;

  const _SceneActionButtonFace({required this.action});

  String get _backgroundAsset {
    if (action.color == const Color(0xFF19862B)) {
      return 'images/ui/action_green.png';
    }
    if (action.color == const Color(0xFF08658F)) {
      return 'images/ui/action_blue.png';
    }
    return 'images/ui/action_gold.png';
  }

  @override
  Widget build(BuildContext context) => _PressScale(
    enabled: action.active,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: action.active ? 1 : 0.42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.active ? action.onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_backgroundAsset),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: FittedBox(
                  key: ValueKey('${action.label}-${action.isUndo}'),
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        action.isUndo
                            ? action.label.replaceFirst(' ', '\n')
                            : action.label,
                        maxLines: action.isUndo ? 2 : 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: action.isUndo ? 17 : 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.25,
                          height: action.isUndo ? 0.9 : 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TAŞ WİDGET
// ═══════════════════════════════════════════════════════════════════════════
class _TileWidget extends StatelessWidget {
  final Tile tile;
  final double w, h;
  final VoidCallback? onTap;
  final bool hideOkey;
  final bool allowOkeyFaceToggle;
  final bool emphasized;
  final bool processable;
  final double numberScale;
  final bool showShadow;
  const _TileWidget({
    super.key,
    required this.tile,
    required this.w,
    required this.h,
    required this.onTap,
    this.hideOkey = false,
    this.allowOkeyFaceToggle = true,
    this.emphasized = false,
    this.processable = false,
    this.numberScale = 1,
    this.showShadow = true,
  });

  String get _label {
    if (tile.isFakeOkey) return '★';
    if (tile.isOkey) return '${tile.number}';
    return '${tile.number}';
  }

  Widget _buildTile(VoidCallback? onToggleOkey) {
    final isSelected = tile.selected;
    final fakeOkeyAsset = tile.isFakeOkey ? storeCosmetics.fakeOkeyAsset : null;
    final content = hideOkey && tile.isOkey && !tile.okeyFaceRevealed
        ? null
        : Transform.translate(
            offset: Offset(0, -h * 0.15),
            child: Stack(
              children: [
                Center(
                  child: fakeOkeyAsset != null
                      ? Image.asset(
                          fakeOkeyAsset,
                          width: w * 0.54,
                          height: h * 0.42,
                          cacheWidth: 64,
                          cacheHeight: 64,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                        )
                      : SizedBox(
                          width: w * 0.82,
                          height: h * 0.55,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              _label,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                color: tile.displayColor,
                                fontSize:
                                    h *
                                    (tile.isFakeOkey ? 0.50 : 0.47) *
                                    (emphasized ? 1.13 : 1) *
                                    numberScale,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.25,
                              ),
                            ),
                          ),
                        ),
                ),
                if (fakeOkeyAsset == null)
                  Positioned(
                    bottom: 3,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: w * 0.21,
                        height: w * 0.21,
                        decoration: BoxDecoration(
                          color: tile.displayColor.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
    final decoration = BoxDecoration(
      image: DecorationImage(
        image: AssetImage(storeCosmetics.tileAsset),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.low,
      ),
      borderRadius: BorderRadius.circular(5),
    );
    final tileFace = Stack(
      fit: StackFit.expand,
      children: [
        ?content,
        if (processable)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: OC.numGreen, width: 3),
              ),
            ),
          ),
      ],
    );
    final visual = onTap == null
        ? Container(
            width: w,
            height: h,
            transform: Matrix4.translationValues(0, isSelected ? -11 : 0, 0),
            decoration: decoration,
            child: tileFace,
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: w,
            height: h,
            transform: Matrix4.translationValues(0, isSelected ? -11 : 0, 0),
            decoration: decoration,
            child: tileFace,
          );
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onToggleOkey,
      child: visual,
    );
  }

  Widget _buildOkeyAnimation(Widget tileWidget) =>
      TweenAnimationBuilder<double>(
        key: ValueKey(tile.okeyFaceRevealed),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: tileWidget,
        builder: (context, value, child) {
          final bounce = sin(value * pi);
          return Transform.translate(
            offset: Offset(0, -h * 0.22 * bounce),
            child: Transform.scale(scale: 1 + bounce * 0.08, child: child),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    if (!hideOkey || !allowOkeyFaceToggle || !tile.isOkey) {
      return _buildTile(null);
    }
    return StatefulBuilder(
      builder: (context, setOkeyState) {
        final tileWidget = _buildTile(
          () => setOkeyState(() {
            tile.okeyFaceRevealed = !tile.okeyFaceRevealed;
          }),
        );
        return _buildOkeyAnimation(tileWidget);
      },
    );
  }
}

class _ColorBonusRoundIntro extends StatelessWidget {
  final String colorName;
  final Color color;
  final VoidCallback onFinished;

  const _ColorBonusRoundIntro({
    super.key,
    required this.colorName,
    required this.color,
    required this.onFinished,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1350),
      curve: Curves.linear,
      onEnd: onFinished,
      builder: (context, progress, child) {
        final travel = ((progress - 0.24) / 0.76).clamp(0.0, 1.0);
        final easedTravel = Curves.easeInOutCubic.transform(travel);
        final alignment = Alignment.lerp(
          Alignment.center,
          const Alignment(0.72, -0.96),
          easedTravel,
        )!;
        final scale = 1 - easedTravel * 0.68;
        final opacity = progress < 0.9
            ? 1.0
            : ((1 - progress) / 0.1).clamp(0.0, 1.0);
        return Align(
          alignment: alignment,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: RepaintBoundary(
        child: Container(
          key: const ValueKey('color-bonus-round-intro'),
          width: 220,
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xF20A241A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$colorName PERLER 2×',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GameCenterNotice extends StatelessWidget {
  final String text;
  const _GameCenterNotice({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('game-warning-popup'),
    constraints: BoxConstraints(
      maxWidth: min(680, MediaQuery.sizeOf(context).width - 36),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF23A210D), Color(0xF21F1007)],
      ),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFFFC04D), width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.68),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFFFFC04D).withValues(alpha: 0.12),
          blurRadius: 8,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFFFC04D),
          size: 26,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EL SONU DİALOG
// ═══════════════════════════════════════════════════════════════════════════
class GameEndDialog extends StatelessWidget {
  final String winner;
  final String playerName;
  final int playerPen;
  final List<BotPlayer> bots;
  final List<int> botPens;
  final int elCount;
  final int? maxRounds;
  final bool matchComplete;
  final int totalPenalty;
  final GameReward? reward;
  final String homeLabel;
  final VoidCallback onNewRound;
  final VoidCallback onResetMatch;
  final VoidCallback onHome;

  const GameEndDialog({
    super.key,
    required this.winner,
    this.playerName = defaultPlayerProfileName,
    required this.playerPen,
    required this.bots,
    required this.botPens,
    required this.elCount,
    this.maxRounds,
    this.matchComplete = false,
    required this.totalPenalty,
    this.reward,
    this.homeLabel = 'ANA SAYFA',
    required this.onNewRound,
    required this.onResetMatch,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final won = winner == 'Sen' || winner == 'Oyuncu 1';
    final scoreRows =
        <
            ({
              String name,
              int roundScore,
              int total,
              bool highlighted,
              bool isPlayer,
              String avatarAsset,
            })
          >[
            (
              name: playerName,
              roundScore: playerPen,
              total: totalPenalty,
              highlighted: won,
              isPlayer: true,
              avatarAsset: playerProgress.playerAvatarAsset,
            ),
            for (var index = 0; index < bots.length; index++)
              (
                name: bots[index].displayName,
                roundScore: botPens[index],
                total: bots[index].penalty + botPens[index],
                highlighted: winner == bots[index].name,
                isPlayer: false,
                avatarAsset:
                    playerAvatarAssets[(index + 1) % playerAvatarAssets.length],
              ),
          ]
          ..sort((left, right) {
            final totalComparison = left.total.compareTo(right.total);
            if (totalComparison != 0) return totalComparison;
            return left.roundScore.compareTo(right.roundScore);
          });
    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = min(640.0, max(276.0, screenSize.width - 28));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: RepaintBoundary(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 644,
            maxHeight: max(180, screenSize.height - 20),
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF123D2C), Color(0xFF071B14)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OC.goldLight, width: 2.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.78),
                blurRadius: 34,
                spreadRadius: 3,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: OC.goldLight.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.white.withValues(alpha: 0.1), Colors.transparent],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: panelWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: const ValueKey('end-screen-header-artwork-slot'),
                    height: 114,
                    width: double.infinity,
                    child: Center(
                      child: Image.asset(
                        'images/ui/end_round_banner.png',
                        width: 500,
                        height: 114,
                        fit: BoxFit.contain,
                        cacheWidth: 600,
                        cacheHeight: 223,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  if (reward != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: _GameRewardCard(
                        reward: reward!,
                        round: elCount,
                        maxRounds: maxRounds,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B281D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: OC.gold.withValues(alpha: 0.42),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            color: Colors.black.withValues(alpha: 0.22),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    appText('SIRA', 'RANK'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    appText('OYUNCU', 'PLAYER'),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    appText('BU TUR', 'ROUND'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    appText('TOPLAM', 'TOTAL'),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...scoreRows.indexed.map((entry) {
                            final rank = entry.$1 + 1;
                            final row = entry.$2;
                            return _ScoreRow(
                              key: ValueKey('score-row-${row.name}'),
                              rank: rank,
                              name: row.name,
                              avatarAsset: row.avatarAsset,
                              elPen: row.roundScore,
                              total: row.total,
                              hi: row.highlighted,
                              isLeader: rank == 1,
                              isPlayer: row.isPlayer,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border(
                        top: BorderSide(color: OC.gold.withValues(alpha: 0.35)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _EndActionButton(
                            icon: Icons.restart_alt_rounded,
                            label: appText('YENİDEN BAŞLAT', 'RESTART'),
                            color: OC.numRed,
                            onPressed: onResetMatch,
                            subtle: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: matchComplete ? 3 : 4,
                          child: _EndActionButton(
                            icon: Icons.home_rounded,
                            label: homeLabel,
                            color: OC.panelBrown,
                            onPressed: onHome,
                          ),
                        ),
                        if (!matchComplete) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _EndActionButton(
                              icon: Icons.play_arrow_rounded,
                              label: appText('DEVAM ET', 'CONTINUE'),
                              color: OC.numGreen,
                              onPressed: onNewRound,
                              primary: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameRewardCard extends StatelessWidget {
  final GameReward reward;
  final int round;
  final int? maxRounds;

  const _GameRewardCard({
    required this.reward,
    required this.round,
    this.maxRounds,
  });

  @override
  Widget build(BuildContext context) {
    final rewards =
        <({IconData icon, Color color, String value, String label})>[
          (
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF63C7FF),
            value: '+${reward.xp}',
            label: 'XP',
          ),
          (
            icon: Icons.monetization_on_rounded,
            color: OC.coinGold,
            value: '+${formatGameNumber(reward.coins)}',
            label: appText('ALTIN', 'GOLD'),
          ),
          (
            icon: Icons.flag_rounded,
            color: const Color(0xFF70DB80),
            value: maxRounds == null ? '$round' : '$round/$maxRounds',
            label: appText('TUR', 'ROUND'),
          ),
        ];

    return Container(
      key: const ValueKey('game-reward-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF164A34), Color(0xFF0B2D20)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OC.gold.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < rewards.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 38,
                color: OC.gold.withValues(alpha: 0.22),
              ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (index == 1)
                    Image.asset(
                      'images/ui/coin.png',
                      width: 31,
                      height: 31,
                      cacheWidth: 62,
                      cacheHeight: 62,
                    )
                  else
                    Icon(
                      rewards[index].icon,
                      color: rewards[index].color,
                      size: 30,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${rewards[index].value} ${rewards[index].label}',
                        maxLines: 1,
                        style: TextStyle(
                          color: rewards[index].color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int rank;
  final String name;
  final String avatarAsset;
  final int elPen;
  final int total;
  final bool hi;
  final bool isPlayer;
  final bool isLeader;

  const _ScoreRow({
    super.key,
    required this.rank,
    required this.name,
    required this.avatarAsset,
    required this.elPen,
    required this.total,
    this.hi = false,
    this.isPlayer = false,
    this.isLeader = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 47,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: isPlayer
          ? const Color(0xFF17633C).withValues(alpha: 0.52)
          : Colors.transparent,
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 2
                ? const Color(0xFFB9CAE0)
                : rank == 3
                ? const Color(0xFFC8794E)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: rank <= 3 ? Colors.white38 : Colors.white24,
            ),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: rank == 2 || rank == 3
                  ? const Color(0xFF33200A)
                  : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 31,
          height: 31,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: hi ? OC.gold : Colors.white38),
          ),
          child: ClipOval(
            child: Image.asset(
              avatarAsset,
              fit: BoxFit.cover,
              cacheWidth: 62,
              cacheHeight: 62,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              if (isLeader) ...[
                const Icon(Icons.push_pin_rounded, color: OC.gold, size: 16),
                const SizedBox(width: 4),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isPlayer || hi
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: isPlayer ? OC.gold : Colors.white,
                  ),
                ),
              ),
              if (isPlayer) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: OC.goldLight,
                  size: 22,
                  weight: 900,
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(
            elPen > 0 ? '+$elPen' : '$elPen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: elPen > 0
                  ? const Color(0xFFFF7E74)
                  : const Color(0xFF70DB80),
            ),
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(
            '$total',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EndActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool primary;
  final bool subtle;

  const _EndActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.primary = false,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final topColor = Color.lerp(color, Colors.white, primary ? 0.26 : 0.15)!;
    final bottomColor = Color.lerp(color, Colors.black, subtle ? 0.44 : 0.24)!;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, color, bottomColor],
          stops: const [0, 0.52, 1],
        ),
        borderRadius: BorderRadius.circular(primary ? 14 : 12),
        border: Border.all(
          color: primary
              ? OC.goldLight.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: subtle ? 0.22 : 0.34),
          width: primary ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: primary ? 0.32 : 0.14),
            blurRadius: primary ? 10 : 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(primary ? 14 : 12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(primary ? 14 : 12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: primary ? 13 : 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: primary ? 23 : 20, color: Colors.white),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: primary ? 14 : 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: primary ? 0.7 : 0.2,
                        shadows: const [
                          Shadow(color: Colors.black54, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

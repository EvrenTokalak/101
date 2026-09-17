import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_launch.dart';
import 'player_progress.dart';

part 'game_rack_solver.dart';
part 'game_bot_engine.dart';
part 'game_animations.dart';
part 'game_settings.dart';
part 'game_table_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await playerProgress.load();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
  final Set<int> tileIds;
  final Tile tile;

  const _RackDragData({
    required this.tileId,
    required this.tileIds,
    required this.tile,
  });
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
  int tileCount;
  int penalty;
  bool hasOpened;
  String openType;
  int turnsPlayed;
  List<Tile> hand;
  BotPlayer({
    required this.name,
    this.tileCount = 21,
    this.penalty = 0,
    this.hasOpened = false,
    this.openType = '',
    this.turnsPlayed = 0,
    this.hand = const [],
  });
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

  static int validMeldTotal(Iterable<List<Tile>> groups) {
    return groups.fold(0, (total, group) {
      final type = meldType(group);
      if (type != 'seri' && type != 'grup') return total;
      return total + meldValue(group);
    });
  }

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
  }) {
    if (!hasOpened) return 202;
    final remaining = penaltyFor(rack, fakeOkeyValue: fakeOkeyValue);
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

class _BotDrawMotion {
  final Tile tile;
  final int botIndex;
  final bool fromDiscard;
  final int serial;

  const _BotDrawMotion({
    required this.tile,
    required this.botIndex,
    required this.fromDiscard,
    required this.serial,
  });
}

enum _TableTileMotionKind { drawDeck, drawDiscard, open, process }

class _TableTileMotion {
  final List<Tile> tiles;
  final _TableTileMotionKind kind;
  final int playerIndex;
  final int serial;

  const _TableTileMotion({
    required this.tiles,
    required this.kind,
    required this.playerIndex,
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
  // Gerçek oyuncu temposu; testlerde gerektiğinde bu sabit açılabilir.
  static const bool _instantBotTurns = true;

  bool get _isTournamentGame =>
      widget.tournamentMode || widget.launchConfig.isTournament;

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
  _BotDrawMotion? _botDrawMotion;
  int _botDrawMotionSerial = 0;
  _TableTileMotion? _tableTileMotion;
  int _tableTileMotionSerial = 0;
  int? _dealAnimationSerial;
  int _dealAnimationCounter = 0;
  bool _dealInProgress = false;
  Timer? _dealTimer;

  // ── Oyuncu Durumu ─────────────────────────────────────────────────────
  bool _playerOpened = false; // el açıldı mı
  String _playerOpenType = ''; // 'seri' | 'cift'
  int _totalPenalty = 0; // biriken ceza
  int _elCount = 0; // kaçıncı el

  // ── Botlar ────────────────────────────────────────────────────────────
  final List<BotPlayer> _bots = [
    BotPlayer(name: 'Oyuncu 2'),
    BotPlayer(name: 'Oyuncu 3'),
    BotPlayer(name: 'Oyuncu 4'),
  ];

  // ── UI Seçim Modu ─────────────────────────────────────────────────────
  // 'normal' | 'addMeld' (işleme modu: hangi melde eklenecek seçiliyor)
  String _uiMode = 'normal';
  bool _showRackPairCount = false;
  final List<_ProcessedMove> _processedMoves = [];
  final GlobalKey _meldGridKey = GlobalKey();
  final ValueNotifier<Offset?> _gridDragPosition = ValueNotifier(null);
  final ValueNotifier<double> _rackDragTilt = ValueNotifier(0);
  bool _draggingProcessableTile = false;
  Offset? _pendingGridDragPosition;
  double _pendingRackDragTilt = 0;
  bool _dragVisualFrameScheduled = false;

  String? _msg;
  bool _gameOverShown = false;
  GameSettings _gameSettings = const GameSettings();

  Future<void> _openGameSettings() async {
    final updated = await showGeneralDialog<GameSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Oyun ayarlarını kapat',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => GameSettingsDialog(
        initial: _gameSettings,
        launchConfig: widget.launchConfig,
        onExitToMenu: () => Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst),
      ),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _gameSettings = updated);
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _gridDragPosition.dispose();
    _rackDragTilt.dispose();
    super.dispose();
  }

  // ── Yeni El Başlat ────────────────────────────────────────────────────
  void _startNewRound() {
    _elCount++;
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
    for (final bot in _bots) {
      bot.tileCount = bot.hand.length;
    }

    _tableMetds = [];
    _discarded = null;
    _discardPiles = List.generate(4, (_) => <Tile>[]);
    _playerOpened = false;
    _playerOpenType = '';
    _drawnThisTurn = false;
    _tookDiscard = false;
    _takenDiscardTile = null;
    _botBusy = false;
    _gridDragPosition.value = null;
    _rackDragTilt.value = 0;
    _draggingProcessableTile = false;
    _botDrawMotion = null;
    _botDiscardMotion = null;
    _tableTileMotion = null;
    _uiMode = 'normal';
    _processedMoves.clear();
    _gameOverShown = false;

    // Her el rastgele bir koltuktan başlar; başlayan oyuncu zaten 22 taşlıdır.
    _turn = _startingPlayer;
    _drawnThisTurn = _turn == 0;
    final openingTurn = _turn;
    if (_gameSettings.animations) {
      final serial = ++_dealAnimationCounter;
      _dealAnimationSerial = serial;
      _dealInProgress = true;
      _dealTimer?.cancel();
      _dealTimer = Timer(const Duration(milliseconds: 2600), () {
        if (!mounted || _dealAnimationSerial != serial) return;
        _dealTimer = null;
        setState(() {
          _dealAnimationSerial = null;
          _dealInProgress = false;
        });
        if (openingTurn > 0 && _turn == openingTurn && !_botBusy) {
          _runBot(_turn - 1, alreadyHasExtraTile: true);
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
    }
  }

  void _beginTableTileMotion(
    _TableTileMotionKind kind,
    Iterable<Tile> tiles, {
    int playerIndex = 0,
  }) {
    if (!_gameSettings.animations) return;
    final visibleTiles = tiles.take(7).toList();
    if (visibleTiles.isEmpty) return;
    final serial = ++_tableTileMotionSerial;
    _tableTileMotion = _TableTileMotion(
      tiles: visibleTiles,
      kind: kind,
      playerIndex: playerIndex,
      serial: serial,
    );
    Future.delayed(const Duration(milliseconds: 620), () {
      if (!mounted || _tableTileMotion?.serial != serial) return;
      setState(() => _tableTileMotion = null);
    });
  }

  // ── Mesaj ─────────────────────────────────────────────────────────────
  void _msg_(
    String m, {
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    if (_msg == m) return;
    setState(() => _msg = m);
    Future.delayed(duration, () {
      if (mounted && _msg == m) setState(() => _msg = null);
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

  void _placeInRackSlot(Tile tile, [int? requestedSlot]) {
    final targetSlot =
        requestedSlot != null &&
            requestedSlot >= 0 &&
            requestedSlot < _rackSlots.length
        ? requestedSlot
        : _rackSlots.indexOf(null);
    if (targetSlot >= 0) _insertRackTileAt(tile.id, targetSlot);
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

  void _playInteractionFeedback({bool strong = false}) {
    if (_gameSettings.sound) {
      SystemSound.play(SystemSoundType.click);
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
      _msg_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _msg_('Önce taş çekmelisin.');
      return;
    }
    final tile = _rackTileById(tileId);
    if (tile != null) {
      _playInteractionFeedback();
      setState(() => tile.selected = !tile.selected);
    }
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

  void _reorderRack(int tileId, int targetIndex) {
    final from = _rackSlots.indexOf(tileId);
    if (from == -1) return;
    setState(() {
      final target = targetIndex.clamp(0, _rackSlotCount - 1);
      if (from == target) return;
      _rackSlots[from] = null;
      _insertRackTileAt(tileId, target);
    });
  }

  int get _rackPerPoints {
    final allIds = _rack.map((tile) => tile.id).toSet();
    return Rules.validMeldTotal(_rackGroups(allIds));
  }

  int get _rackPairCount => RackSolver.pairs(_rack).length;

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
      _placeInRackSlot(tile, targetSlot);
      _drawnThisTurn = true;
      _tookDiscard = false;
      _beginTableTileMotion(_TableTileMotionKind.drawDeck, [tile]);
    });
    _playInteractionFeedback();
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

    // Soldan çekilirse el açılmamışsa o sırda el AÇILMALI
    if (!_playerOpened) {
      _msg_('Soldan taş aldın! Bu turda el açmak zorunda ya da taşı geri koy.');
    }

    setState(() {
      _takenDiscardTile = _discarded;
      final tile = _discarded!;
      _rack.add(tile);
      _placeInRackSlot(tile, targetSlot);
      if (_discardPiles[3].isNotEmpty && _discardPiles[3].last.id == tile.id) {
        _discardPiles[3].removeLast();
      }
      _discarded = null;
      _drawnThisTurn = true;
      _tookDiscard = true;
      _beginTableTileMotion(_TableTileMotionKind.drawDiscard, [tile]);
    });
    _playInteractionFeedback();
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
      _discardPiles[3].add(tile);
      _drawnThisTurn = false;
      _tookDiscard = false;
      _takenDiscardTile = null;
    });
    _playInteractionFeedback();
    _msg_('Taş geri bırakıldı. Artık ortadan taş çekebilirsin.');
  }

  // ── Taş At ────────────────────────────────────────────────────────────
  void _discardTile() {
    if (_turn != 0) {
      _msg_('Sıra sende değil.');
      return;
    }
    if (!_drawnThisTurn) {
      _msg_('Önce taş çekmelisin.');
      return;
    }
    if (_tookDiscard && !_playerOpened) {
      _msg_('Soldan aldığın taşı açılışta kullan veya geri bırak.');
      return;
    }

    final sel = _rack.where((t) => t.selected).toList();
    if (sel.length != 1) {
      _msg_('Atmak için tam 1 taş seç.');
      return;
    }

    final tile = sel.first;

    // Atılan taş işleme cezası kontrolü
    if (_checkDiscardPenalty(tile)) {
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
      _discardPiles[0].add(tile);
      _drawnThisTurn = false;
      _tookDiscard = false;
      _takenDiscardTile = null;
    });
    _playInteractionFeedback(strong: true);

    if (_rack.isEmpty) {
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
    final openingValue = groups.fold(
      0,
      (sum, group) => sum + Rules.meldValue(group),
    );
    if (!Rules.meetsStandardOpeningScore(
      groups,
      alreadyOpened: _playerOpened,
    )) {
      _msg_(
        'İlk açılıştaki tüm perlerin toplamı en az 101 olmalı.\n'
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
      _clearRackSlots(tileIds);
      _rack.removeWhere((tile) => tileIds.contains(tile.id));
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
    if (!_playerOpened && pairs.length < 5) {
      _msg_(
        'İlk çift açılış için en az 5 çift gerekli. (${pairs.length} çift seçili)',
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
      _clearRackSlots(tileIds);
      _rack.removeWhere((tile) => tileIds.contains(tile.id));
      _playerOpened = true;
      if (!layingPairsAfterStandard) _playerOpenType = 'cift';
      _tookDiscard = false;
      _takenDiscardTile = null;
      _beginTableTileMotion(
        wasAlreadyOpened
            ? _TableTileMotionKind.process
            : _TableTileMotionKind.open,
        selected,
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

  Set<int> get _processableTileIds => {
    for (final tile in _rack)
      if (_tableMetds.any((meld) => _meldCanUseTiles(meld, [tile]))) tile.id,
  };

  int _automaticTargetMeldIndex(Tile tile) {
    return Rules.preferredMeldIndexForTile(_tableMetds, tile);
  }

  void _startGridDragZoom(_RackDragData data) {
    _rackDragTilt.value = 0;
    _pendingRackDragTilt = 0;
    final draggedIds = data.tileIds.isEmpty ? {data.tileId} : data.tileIds;
    _draggingProcessableTile =
        _gameSettings.gridMagnifier &&
        draggedIds.any(_processableTileIds.contains);
    if (!_draggingProcessableTile) {
      _pendingGridDragPosition = null;
      _gridDragPosition.value = null;
    }
  }

  void _updateGridDragZoom(_RackDragData _, DragUpdateDetails details) {
    final targetTilt = (details.delta.dx * 0.035).clamp(-0.18, 0.18);
    final tilt = _pendingRackDragTilt * 0.55 + targetTilt.toDouble() * 0.45;
    Offset? localPosition;
    final renderObject = _draggingProcessableTile
        ? _meldGridKey.currentContext?.findRenderObject()
        : null;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final local = renderObject.globalToLocal(details.globalPosition);
      final inside =
          local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= renderObject.size.width &&
          local.dy <= renderObject.size.height;
      if (inside) localPosition = local;
    }
    _scheduleDragVisualFrame(localPosition, tilt);
  }

  void _scheduleDragVisualFrame(Offset? gridPosition, double rackTilt) {
    _pendingGridDragPosition = gridPosition;
    _pendingRackDragTilt = rackTilt;
    if (_dragVisualFrameScheduled) return;
    _dragVisualFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _dragVisualFrameScheduled = false;
      if (!mounted) return;
      if (_gridDragPosition.value != _pendingGridDragPosition) {
        _gridDragPosition.value = _pendingGridDragPosition;
      }
      if (_rackDragTilt.value != _pendingRackDragTilt) {
        _rackDragTilt.value = _pendingRackDragTilt;
      }
    });
  }

  void _endGridDragZoom() {
    _draggingProcessableTile = false;
    _pendingGridDragPosition = null;
    _pendingRackDragTilt = 0;
    _gridDragPosition.value = null;
    _rackDragTilt.value = 0;
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
    if (!_playerOpened && pairs.length < 5) return false;
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

  bool _canDropOnPairArea(_RackDragData data) =>
      _canLayTilesInPairArea(_tilesForDrag(data));

  void _dropOnPairArea(_RackDragData data) {
    final tiles = _tilesForDrag(data);
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

        _placeTilesIntoMeld(targetMeldIndex, [tileToProcess]);
        processedTiles.add(tileToProcess);
        processed++;
      }
      _uiMode = 'normal';
      _beginTableTileMotion(_TableTileMotionKind.process, processedTiles);
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
    meld.tiles = Rules.orderedMeld([...meld.tiles, ...tiles], meld.type);
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
    meld.tiles = Rules.orderedMeld(changed, meld.type);
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
      _beginTableTileMotion(_TableTileMotionKind.process, selected);
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
    _discardTile();
  }

  Set<int> _layoutRackGroups(List<List<Tile>> groups) {
    final placedIds = <int>{};
    final reservedSeparators = <int>{};

    setState(() {
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
              final byNumber = a.number.compareTo(b.number);
              if (byNumber != 0) return byNumber;
              final byColor = a.color.index.compareTo(b.color.index);
              if (byColor != 0) return byColor;
              return a.id.compareTo(b.id);
            });
      for (final tile in remaining) {
        final emptySlot = List.generate(_rackSlotCount, (index) => index)
            .firstWhere(
              (index) =>
                  _rackSlots[index] == null &&
                  !reservedSeparators.contains(index),
              orElse: () => -1,
            );
        if (emptySlot != -1) _rackSlots[emptySlot] = tile.id;
      }
    });
    return placedIds;
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
  }

  void _autoOpenStandardMelds() {
    final allIds = _rack.map((tile) => tile.id).toSet();
    final groups = RackSolver.standardMeldsFromLayout(_rackGroups(allIds));
    if (groups.isEmpty) {
      _msg_('Istakada boşluklarla ayırdığın geçerli bir per bulunamadı.');
      return;
    }
    _openStandardMelds(
      groups.expand((group) => group).map((tile) => tile.id).toSet(),
      detectedGroups: groups,
    );
  }

  void _autoOpenPairs() {
    final allIds = _rack.map((tile) => tile.id).toSet();
    final pairs = RackSolver.pairsFromLayout(_rackGroups(allIds));
    if (pairs.isEmpty) {
      _msg_('Istakada yan yana dizdiğin geçerli bir çift bulunamadı.');
      return;
    }
    _openPairs(
      pairs.expand((pair) => pair).map((tile) => tile.id).toSet(),
      detectedPairs: pairs,
    );
  }

  // ── Sıra Geçişi ───────────────────────────────────────────────────────
  void _nextTurn() {
    _turn = (_turn + 1) % 4;
    if (_turn == 0) {
      // Oyuncunun sırası
      setState(() {
        _drawnThisTurn = false;
      });
    } else {
      _runBot(_turn - 1);
    }
  }

  // ── Bot Oynaması ──────────────────────────────────────────────────────
  void _runBot(int botIdx, {bool alreadyHasExtraTile = false}) {
    if (_gameOverShown) return;
    setState(() => _botBusy = true);

    final botThinkTime = _instantBotTurns
        ? const Duration(milliseconds: 25)
        : Duration(milliseconds: 3000 + Random().nextInt(2001));
    Future.delayed(botThinkTime, () {
      if (!mounted || _gameOverShown) return;

      final bot = _bots[botIdx];
      const earliestOpeningTurns = [3, 4, 3];
      const standardOpeningTargets = [105, 110, 103];
      const pairOpeningTargets = [5, 6, 5];
      final nextBotTurn = bot.turnsPlayed + 1;
      final allowOpening = nextBotTurn >= earliestOpeningTurns[botIdx];
      final canTakeDiscard =
          !alreadyHasExtraTile &&
          _discarded != null &&
          BotEngine.wantsDiscard(
            bot,
            _discarded!,
            _tableMetds,
            allowOpening: allowOpening,
            minimumStandardScore: standardOpeningTargets[botIdx],
            minimumPairCount: pairOpeningTargets[botIdx],
          );
      if (!alreadyHasExtraTile && !canTakeDiscard && _deck.isEmpty) {
        setState(() => _botBusy = false);
        _endRoundNoDeck();
        return;
      }

      Tile? drawnTile;
      var drewFromDiscard = false;
      if (!alreadyHasExtraTile) {
        setState(() {
          if (canTakeDiscard) {
            drawnTile = _discarded!;
            drewFromDiscard = true;
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
          if (_gameSettings.animations) {
            _botDrawMotion = _BotDrawMotion(
              tile: drawnTile!,
              botIndex: botIdx,
              fromDiscard: drewFromDiscard,
              serial: ++_botDrawMotionSerial,
            );
          }
        });
      }

      void playAndDiscard() {
        if (!mounted || _gameOverShown) return;
        late final BotTurnResult result;
        setState(() {
          _botDrawMotion = null;
          bot.turnsPlayed++;
          final tableTileIdsBefore = _tableMetds
              .expand((meld) => meld.tiles)
              .map((tile) => tile.id)
              .toSet();
          result = BotEngine.play(
            bot,
            _tableMetds,
            allowOpening: bot.turnsPlayed >= earliestOpeningTurns[botIdx],
            minimumStandardScore: standardOpeningTargets[botIdx],
            minimumPairCount: pairOpeningTargets[botIdx],
          );
          final movedToTable = _tableMetds
              .expand((meld) => meld.tiles)
              .where((tile) => !tableTileIdsBefore.contains(tile.id))
              .toList();
          if (movedToTable.isNotEmpty) {
            _beginTableTileMotion(
              result.openedMeldCount > 0
                  ? _TableTileMotionKind.open
                  : _TableTileMotionKind.process,
              movedToTable,
              playerIndex: botIdx + 1,
            );
          }
          _discarded = result.discarded;
          if (result.discarded != null && _gameSettings.animations) {
            _botDiscardMotion = _BotDiscardMotion(
              tile: result.discarded!,
              botIndex: botIdx,
              serial: ++_botDiscardMotionSerial,
            );
          }
          _botBusy = false;
        });

        void finishTurn() {
          if (!mounted || _gameOverShown) return;
          setState(() {
            if (result.discarded != null) {
              _discardPiles[botIdx + 1].add(result.discarded!);
            }
            if (_botDiscardMotion?.serial == _botDiscardMotionSerial) {
              _botDiscardMotion = null;
            }
          });
          if (bot.hand.isEmpty) {
            _endRoundBotWins(botIdx);
          } else if (_deck.isEmpty) {
            _endRoundNoDeck();
          } else {
            _nextTurn();
          }
        }

        if (result.discarded != null && _gameSettings.animations) {
          Future.delayed(const Duration(milliseconds: 480), finishTurn);
        } else {
          finishTurn();
        }
      }

      if (drawnTile != null && _gameSettings.animations) {
        Future.delayed(const Duration(milliseconds: 420), playAndDiscard);
      } else {
        playAndDiscard();
      }
    });
  }

  // ── El Bitti: Oyuncu Kazandı ──────────────────────────────────────────
  void _endRoundPlayerWins() {
    if (_gameOverShown) return;
    _gameOverShown = true;

    // Diğer oyuncuların cezaları
    final botPenList = <int>[];
    for (final b in _bots) {
      final p = Rules.roundPenaltyFor(
        b.hand,
        fakeOkeyValue: _currentOkeyNumber,
        hasOpened: b.hasOpened,
        openedWithPairs: b.openType == 'cift',
      );
      botPenList.add(p);
    }

    _totalPenalty -= 101;
    _showEndDialog(winner: 'Oyuncu 1', playerPen: -101, botPens: botPenList);
  }

  // ── El Bitti: Bot Kazandı ─────────────────────────────────────────────
  void _endRoundBotWins(int botIdx) {
    if (_gameOverShown) return;
    _gameOverShown = true;

    final myPen = Rules.roundPenaltyFor(
      _rack,
      fakeOkeyValue: _currentOkeyNumber,
      hasOpened: _playerOpened,
      openedWithPairs: _playerOpenType == 'cift',
    );
    _totalPenalty += myPen;

    final botPens = List.generate(_bots.length, (i) {
      if (i == botIdx) return -101;
      return Rules.roundPenaltyFor(
        _bots[i].hand,
        fakeOkeyValue: _currentOkeyNumber,
        hasOpened: _bots[i].hasOpened,
        openedWithPairs: _bots[i].openType == 'cift',
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
    _gameOverShown = true;
    final myPen = Rules.roundPenaltyFor(
      _rack,
      fakeOkeyValue: _currentOkeyNumber,
      hasOpened: _playerOpened,
      openedWithPairs: _playerOpenType == 'cift',
    );
    _totalPenalty += myPen;
    final botPens = _bots
        .map(
          (b) => Rules.roundPenaltyFor(
            b.hand,
            fakeOkeyValue: _currentOkeyNumber,
            hasOpened: b.hasOpened,
            openedWithPairs: b.openType == 'cift',
          ),
        )
        .toList();
    _showEndDialog(winner: 'Deste bitti', playerPen: myPen, botPens: botPens);
  }

  void _showEndDialog({
    required String winner,
    required int playerPen,
    required List<int> botPens,
  }) {
    final playerWon = winner == 'Oyuncu 1' || winner == 'Sen';
    final reward = playerProgress.recordCompletedGame(
      config: widget.launchConfig,
      won: playerWon,
      openedHand: _playerOpened,
      finishedHand: playerWon,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameEndDialog(
        winner: winner,
        playerPen: playerPen,
        bots: _bots,
        botPens: botPens,
        elCount: _elCount,
        totalPenalty: _totalPenalty,
        reward: reward,
        homeLabel: _isTournamentGame ? 'TURNUVAYA DÖN' : 'ANA SAYFA',
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
          } else {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sel = _rack.where((t) => t.selected).length;
    final myTurn = _turn == 0 && !_botBusy && !_dealInProgress;
    final canAct = myTurn && _drawnThisTurn;
    final eligibleMeldIndexes = _eligibleMeldIndexes;
    final processableTileIds = _gameSettings.moveHints
        ? _processableTileIds
        : const <int>{};

    return Scaffold(
      backgroundColor: const Color(0xFF003E2A),
      body: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_gameSettings.fontScale)),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final sceneWidth = viewport.maxWidth;
              final sceneHeight = viewport.maxHeight;
              final edgeInset = sceneWidth * 0.012;
              final actionPanelWidth = sceneWidth * 0.115;
              final controlGap = sceneWidth * 0.008;
              final rackHeight = sceneHeight * 0.29;
              final infoPanelHeight = sceneHeight * 0.11;
              final rackContentWidth =
                  sceneWidth -
                  edgeInset * 2 -
                  actionPanelWidth * 2 -
                  controlGap * 2 -
                  24;
              final normalRackTileWidth = max(
                1.0,
                rackContentWidth / _rackRowLength - 6,
              );
              final normalRackTileHeight = min(
                normalRackTileWidth * 1.28,
                max(1.0, (rackHeight - 17) / 2),
              );
              final gridTileWidth = normalRackTileWidth * 0.85;

              return SizedBox.expand(
                child: Stack(
                  children: [
                    _GameSceneEntrance(
                      enabled: _gameSettings.animations,
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
                                          tile.id == _takenDiscardTile!.id,
                                    ),
                                onReturnDiscard: _returnTakenDiscard,
                                gridTileWidth: gridTileWidth,
                                gridKey: _meldGridKey,
                                gridDragPosition: _gridDragPosition,
                                botDrawMotion: _botDrawMotion,
                                botDiscardMotion: _botDiscardMotion,
                                tableTileMotion: _tableTileMotion,
                                bottomReservedSpace: infoPanelHeight,
                                gameModeLabel: widget.launchConfig.modeLabel,
                                deckCount: _deck.length,
                                indicator: _indicator,
                                perPoints: _playerOpened
                                    ? _rackRemainingPoints
                                    : _rackPerPoints,
                                showRemainingPoints: _playerOpened,
                                pairCount: !_playerOpened && _showRackPairCount
                                    ? _rackPairCount
                                    : null,
                                canDraw: myTurn && !_drawnThisTurn,
                                onDraw: _drawFromDeck,
                                dragTileWidth: normalRackTileWidth,
                                dragTileHeight: normalRackTileHeight,
                              ),
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: actionPanelWidth,
                                    child: _RackActionPanel(
                                      actions: [
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
                                          label: 'SERİ AÇ',
                                          active:
                                              canAct &&
                                              !(_playerOpened &&
                                                  _playerOpenType == 'cift'),
                                          color: const Color(0xFF19862B),
                                          onTap: _autoOpenStandardMelds,
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
                                          secondaryOnTap: _undoProcessedMoves,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: controlGap),
                                  Expanded(
                                    child: IgnorePointer(
                                      ignoring: _dealInProgress,
                                      child: RepaintBoundary(
                                        child: _RackArea(
                                          rack: _rack,
                                          slots: _rackSlots,
                                          dealAnimationSerial:
                                              _dealAnimationSerial,
                                          onTileTap: _tapTile,
                                          onReorder: _reorderRack,
                                          onTileDragStart: _startGridDragZoom,
                                          onTileDragUpdate: _updateGridDragZoom,
                                          onTileDragEnd: _endGridDragZoom,
                                          dragTilt: _rackDragTilt,
                                          gridDragPosition: _gridDragPosition,
                                          processableTileIds:
                                              processableTileIds,
                                          canAcceptDeckDrop:
                                              myTurn && !_drawnThisTurn,
                                          canAcceptDiscardDrop:
                                              myTurn &&
                                              !_drawnThisTurn &&
                                              _discarded != null,
                                          onDeckDropAt: _drawFromDeck,
                                          onDiscardDropAt: _takeDiscarded,
                                        ),
                                      ),
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
                                          icon: _drawnThisTurn
                                              ? Icons.check_rounded
                                              : null,
                                          active: _drawnThisTurn
                                              ? canAct && sel == 1
                                              : myTurn && _deck.isNotEmpty,
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

                    Positioned(
                      top: 0,
                      right: 0,
                      child: _TopBar(onSettings: _openGameSettings),
                    ),

                    // ── Overlay Mesajı ─────────────────────────────────────────
                    if (_msg != null)
                      Positioned(
                        top: 56,
                        left: 16,
                        right: 16,
                        child: Center(child: _MsgBanner(text: _msg!)),
                      ),

                    // ── İşleme modu ipucu ─────────────────────────────────────
                    if (_uiMode == 'addMeld')
                      Positioned(
                        top: 52,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: OC.numBlue.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'İşlemek istediğin perdeye dokun',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
    child: IconButton.filledTonal(
      key: const ValueKey('game-settings-button'),
      tooltip: 'Oyun ayarları',
      onPressed: onSettings,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1D9343),
        foregroundColor: Colors.white,
        minimumSize: const Size(42, 42),
        side: const BorderSide(color: Color(0xFFC48A31), width: 1.5),
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.settings, size: 19),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// OYUNCU BİLGİSİ (avatar + isim + taş sayısı)
// ═══════════════════════════════════════════════════════════════════════════
class _PlayerInfo extends StatelessWidget {
  final BotPlayer bot;
  final bool active;
  final bool horizontal;

  const _PlayerInfo({
    required this.bot,
    required this.active,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: horizontal ? 34 : 38,
          height: horizontal ? 34 : 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFF2D89B), Color(0xFFB67828)],
            ),
            border: Border.all(
              color: active ? OC.okeyGold : const Color(0xFF4B2D12),
              width: active ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? OC.okeyGold.withValues(alpha: 0.45)
                    : Colors.black45,
                blurRadius: active ? 9 : 5,
              ),
            ],
          ),
          child: Icon(
            Icons.person,
            size: horizontal ? 21 : 23,
            color: const Color(0xFF553116),
          ),
        ),
        Positioned(
          right: -3,
          bottom: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13201C),
              border: Border.all(color: OC.gold, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '${bot.tileCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );

    final nameTag = Container(
      constraints: BoxConstraints(maxWidth: horizontal ? 48 : 52),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xE6141917),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: active ? OC.gold : const Color(0xFF7B5224),
          width: 1,
        ),
      ),
      child: Text(
        bot.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );

    return _ActiveTurnPulse(
      active: active,
      child: Container(
        key: ValueKey('seat-${bot.name}'),
        padding: const EdgeInsets.all(2),
        child: horizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [avatar, const SizedBox(width: 4), nameTag],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [avatar, const SizedBox(height: 3), nameTag],
              ),
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
  final bool canTakeDiscard;
  final VoidCallback onTakeDiscard;
  final bool canReturnDiscard;
  final VoidCallback onReturnDiscard;
  final double gridTileWidth;
  final GlobalKey gridKey;
  final ValueNotifier<Offset?> gridDragPosition;
  final _BotDrawMotion? botDrawMotion;
  final _BotDiscardMotion? botDiscardMotion;
  final _TableTileMotion? tableTileMotion;
  final double bottomReservedSpace;
  final String gameModeLabel;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final double dragTileWidth;
  final double dragTileHeight;

  const _TableArea({
    required this.melds,
    required this.bots,
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
    required this.canTakeDiscard,
    required this.onTakeDiscard,
    required this.canReturnDiscard,
    required this.onReturnDiscard,
    required this.gridTileWidth,
    required this.gridKey,
    required this.gridDragPosition,
    required this.botDrawMotion,
    required this.botDiscardMotion,
    required this.tableTileMotion,
    required this.bottomReservedSpace,
    required this.gameModeLabel,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.canDraw,
    required this.onDraw,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ana yeşil masa
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 1.05,
                colors: [Color(0xFF08703B), Color(0xFF004526)],
              ),
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
                                canDraw: canDraw,
                                onDraw: onDraw,
                                dragTileWidth: dragTileWidth,
                                dragTileHeight: dragTileHeight,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: ValueListenableBuilder<Offset?>(
                              valueListenable: gridDragPosition,
                              builder: (context, position, _) {
                                if (position == null) {
                                  return const SizedBox.shrink();
                                }
                                return _GridDragMagnifier(position: position);
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
                    height: 16,
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 13,
                          child: _GridTopCaption(
                            key: ValueKey('opening-rule-caption'),
                            text: 'EL AÇMA: 101 PER • 5 ÇİFT',
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        const Spacer(flex: 8),
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
                  Positioned(
                    top: 6,
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
                  Positioned(
                    left: 10,
                    top: 56,
                    bottom: max(0, bottomReservedSpace - 56),
                    child: Center(
                      child: _PlayerInfo(bot: bots[2], active: activeTurn == 3),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 56,
                    bottom: max(0, bottomReservedSpace - 56),
                    child: Center(
                      child: _PlayerInfo(bot: bots[0], active: activeTurn == 1),
                    ),
                  ),
                  Positioned(
                    top: 64,
                    right: 8,
                    child: _TableDiscardPile(
                      tiles: discardPiles[1],
                      label: bots[0].name,
                    ),
                  ),
                  Positioned(
                    bottom: max(8, bottomReservedSpace - 48),
                    right: 8,
                    child: _TableDiscardPile(
                      tiles: discardPiles[0],
                      label: 'Oyuncu 1',
                      active: myTurn && drawnThisTurn,
                      onDrop: onPlayerDiscardDrop,
                    ),
                  ),
                  Positioned(
                    top: 64,
                    left: 8,
                    child: _TableDiscardPile(
                      tiles: discardPiles[2],
                      label: bots[1].name,
                    ),
                  ),
                  Positioned(
                    bottom: max(8, bottomReservedSpace - 48),
                    left: 8,
                    child: _TableDiscardPile(
                      tiles: discardPiles[3],
                      label: bots[2].name,
                      takeEnabled: canTakeDiscard,
                      onTake: onTakeDiscard,
                      showReturnButton: canReturnDiscard,
                      onReturn: onReturnDiscard,
                    ),
                  ),
                  if (botDrawMotion != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: _FlyingBotDraw(motion: botDrawMotion!),
                      ),
                    ),
                  if (botDiscardMotion != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: _FlyingBotDiscard(motion: botDiscardMotion!),
                      ),
                    ),
                  if (tableTileMotion != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: _FlyingTableTiles(motion: tableTileMotion!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
      constraints: const BoxConstraints(maxHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
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
  Size _viewportSize = Size.zero;
  bool _lockingBasePan = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_lockPanAtBaseScale);
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
    _transformation.removeListener(_lockPanAtBaseScale);
    _centeringController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails _) {
    _centeringController.stop();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final scale = _transformation.value.getMaxScaleOnAxis().clamp(1.0, 3.4);
    final translation = _transformation.value.getTranslation();
    if (scale <= 1.002 &&
        translation.x.abs() < 0.5 &&
        translation.y.abs() < 0.5) {
      return;
    }
    final cornerTransform = Matrix4.identity()
      ..translateByDouble(
        widget.alignRight ? _viewportSize.width * (1 - scale) : 0,
        _viewportSize.height * (1 - scale),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
    _centeringAnimation =
        TweenSequence<Matrix4>([
          TweenSequenceItem(
            tween: Matrix4Tween(
              begin: _transformation.value.clone(),
              end: cornerTransform,
            ),
            weight: 32,
          ),
          TweenSequenceItem(
            tween: Matrix4Tween(
              begin: cornerTransform,
              end: Matrix4.identity(),
            ),
            weight: 68,
          ),
        ]).animate(
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
      _viewportSize = box.biggest;
      return InteractiveViewer(
        transformationController: _transformation,
        minScale: 1,
        maxScale: 3.4,
        panEnabled: true,
        scaleEnabled: true,
        panAxis: PanAxis.free,
        boundaryMargin: const EdgeInsets.all(160),
        clipBehavior: Clip.hardEdge,
        onInteractionStart: _onInteractionStart,
        onInteractionEnd: _onInteractionEnd,
        child: widget.child,
      );
    },
  );
}

class _GridDragMagnifier extends StatelessWidget {
  final Offset position;

  const _GridDragMagnifier({required this.position});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final lensWidth = min(
          box.maxWidth,
          min(230.0, max(128.0, box.maxWidth * 0.30)),
        );
        final lensHeight = min(
          box.maxHeight,
          min(152.0, max(88.0, box.maxHeight * 0.40)),
        );
        final left = (position.dx - lensWidth / 2)
            .clamp(0.0, max(0.0, box.maxWidth - lensWidth))
            .toDouble();
        final top = (position.dy - lensHeight / 2)
            .clamp(0.0, max(0.0, box.maxHeight - lensHeight))
            .toDouble();
        final lensCenter = Offset(left + lensWidth / 2, top + lensHeight / 2);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              key: const ValueKey('grid-drag-magnifier'),
              left: left,
              top: top,
              child: RawMagnifier(
                size: Size(lensWidth, lensHeight),
                magnificationScale: 1.64,
                focalPointOffset: position - lensCenter,
                clipBehavior: Clip.hardEdge,
                decoration: MagnifierDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: OC.numGreen.withValues(alpha: 0.88),
                      width: 1.4,
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.48),
                      blurRadius: 13,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: OC.numGreen.withValues(alpha: 0.24),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FlyingBotDraw extends StatelessWidget {
  final _BotDrawMotion motion;

  const _FlyingBotDraw({required this.motion});

  @override
  Widget build(BuildContext context) {
    final target = switch (motion.botIndex) {
      0 => const Alignment(0.88, 0),
      1 => const Alignment(0, -0.9),
      _ => const Alignment(-0.88, 0),
    };
    final discardSource = switch (motion.botIndex) {
      0 => const Alignment(0.84, 0.76),
      1 => const Alignment(0.84, -0.76),
      _ => const Alignment(-0.84, -0.76),
    };
    final source = motion.fromDiscard
        ? discardSource
        : const Alignment(0, 0.82);

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('bot-draw-motion-${motion.serial}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) => Align(
          alignment: Alignment.lerp(source, target, value)!,
          child: Transform.rotate(
            angle: (0.5 - value) * 0.12,
            child: Transform.scale(
              scale: 1 + sin(value * pi) * 0.16,
              child: Opacity(opacity: 0.65 + value * 0.35, child: child),
            ),
          ),
        ),
        child: motion.fromDiscard
            ? _TileWidget(tile: motion.tile, w: 27, h: 35, onTap: null)
            : const _TileBack(),
      ),
    );
  }
}

class _FlyingBotDiscard extends StatelessWidget {
  final _BotDiscardMotion motion;

  const _FlyingBotDiscard({required this.motion});

  @override
  Widget build(BuildContext context) {
    final (start, end) = switch (motion.botIndex) {
      0 => (const Alignment(0.88, 0), const Alignment(0.84, -0.76)),
      1 => (const Alignment(0, -0.9), const Alignment(-0.84, -0.76)),
      _ => (const Alignment(-0.88, 0), const Alignment(-0.84, 0.76)),
    };
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('bot-discard-motion-${motion.serial}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) => Align(
          alignment: Alignment.lerp(start, end, value)!,
          child: Transform.rotate(
            angle: (value - 0.5) * 0.16,
            child: Transform.scale(
              scale: 1.12 - value * 0.12,
              child: Opacity(opacity: (0.55 + value * 0.45), child: child),
            ),
          ),
        ),
        child: _TileWidget(tile: motion.tile, w: 27, h: 35, onTap: null),
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
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 3),
                  ],
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

  const _GridPainter({required this.cellWidth, required this.cellHeight});

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
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight;
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
  final bool canDraw;
  final VoidCallback onDraw;
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
    required this.canDraw,
    required this.onDraw,
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
                        child: _PairMeldGrid(
                          key: const ValueKey('pair-meld-grid'),
                          columns: pairColumns,
                          rows: pairRows,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight * 0.86,
                          frameWidth: frameWidth,
                          entries: pairEntries,
                          onPairDrop: onPairDrop,
                          canAcceptPairDrop: canAcceptPairDrop,
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
                          canDraw: canDraw,
                          onDraw: onDraw,
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
  final bool canDraw;
  final VoidCallback onDraw;
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
    required this.canDraw,
    required this.onDraw,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final displayTileWidth = dragTileWidth;
    final displayTileHeight = dragTileHeight;
    final itemWidth = displayTileWidth + 4;
    return Container(
      key: const ValueKey('table-draw-column'),
      width: width,
      height: height,
      alignment: Alignment.bottomLeft,
      decoration: const BoxDecoration(
        color: Color(0xD90B403B),
        border: Border(bottom: BorderSide(color: Color(0xFFC48A31), width: 2)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, top: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                key: const ValueKey('grid-per-summary'),
                width: itemWidth,
                height: displayTileHeight,
                child: _RackPerSummary(
                  points: perPoints,
                  showRemaining: showRemainingPoints,
                  pairCount: pairCount,
                ),
              ),
              const SizedBox(width: 3),
              if (indicator != null)
                SizedBox(
                  key: const ValueKey('grid-indicator'),
                  width: itemWidth,
                  height: displayTileHeight,
                  child: Center(
                    child: _TileWidget(
                      tile: indicator!,
                      w: displayTileWidth,
                      h: displayTileHeight,
                      onTap: null,
                    ),
                  ),
                ),
              const SizedBox(width: 3),
              SizedBox(
                key: const ValueKey('grid-deck-slot'),
                width: itemWidth,
                height: displayTileHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
      color: const Color(0xEE082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(cellWidth: cellWidth, cellHeight: cellHeight),
          ),
        ),
        Positioned.fill(
          child: Wrap(
            spacing: 0,
            runSpacing: 0,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: cellWidth * 2,
                  height: cellHeight,
                  child: _MeldRow(
                    meld: entry.value,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                  ),
                ),
            ],
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
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
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _RunMeldGrid extends StatelessWidget {
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
    return result;
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
    final ordered = Rules.orderedMeld([...meld.tiles, data.tile], meld.type);
    final index = ordered.indexWhere((tile) => tile.id == data.tile.id);
    return index < 0 ? null : (index: index, replacesOkey: false);
  }

  Widget _meldWidget(MapEntry<int, Meld> entry) {
    final isEligible =
        uiMode == 'addMeld' && eligibleMeldIndexes.contains(entry.key);
    return SizedBox(
      width: cellWidth * entry.value.tiles.length,
      height: cellHeight,
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
          return AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              boxShadow: hovering
                  ? [
                      BoxShadow(
                        color: focusColor.withValues(alpha: 0.38),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: GestureDetector(
              onTap: isEligible ? () => onMeldTap(entry.key) : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (hovering || isEligible)
                    Positioned.fill(
                      child: ColoredBox(
                        color: hovering
                            ? (acceptedHover ? OC.gold : OC.numRed).withValues(
                                alpha: 0.30,
                              )
                            : OC.numGreen.withValues(alpha: 0.25),
                      ),
                    ),
                  Positioned.fill(
                    child: _MeldRow(
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: columns * cellWidth + frameWidth * 2,
    height: rows * cellHeight + frameWidth * 2,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xEE082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(cellWidth: cellWidth, cellHeight: cellHeight),
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
    final tileWidth = max(1.0, cellWidth - 1);
    final tileHeight = max(1.0, min(cellHeight - 1, tileWidth * 1.28));
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
                  boxShadow: [
                    BoxShadow(
                      color: OC.okeyGold.withValues(alpha: 0.48),
                      blurRadius: 7,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -2,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: OC.okeyGold,
                size: max(13, cellWidth * 0.55),
                shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
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
    final tileWidth = max(1.0, cellWidth - 1);
    final tileHeight = max(1.0, min(cellHeight - 1, tileWidth * 1.28));
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
                  cornerRadius: 0,
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
class _RackArea extends StatelessWidget {
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final Function(int) onTileTap;
  final void Function(int, int) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<double> dragTilt;
  final ValueNotifier<Offset?> gridDragPosition;
  final Set<int> processableTileIds;
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
    required this.dragTilt,
    required this.gridDragPosition,
    required this.processableTileIds,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: ResizeImage(AssetImage('images/ıstaka2.png'), width: 1024),
            fit: BoxFit.fill,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 7),
            Expanded(
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
                            rack: rack,
                            slots: slots,
                            dealAnimationSerial: dealAnimationSerial,
                            processableTileIds: processableTileIds,
                            onTileTap: onTileTap,
                            onReorder: onReorder,
                            onTileDragStart: onTileDragStart,
                            onTileDragUpdate: onTileDragUpdate,
                            onTileDragEnd: onTileDragEnd,
                            dragTilt: dragTilt,
                            gridDragPosition: gridDragPosition,
                            canAcceptDeckDrop: canAcceptDeckDrop,
                            canAcceptDiscardDrop: canAcceptDiscardDrop,
                            onDeckDropAt: onDeckDropAt,
                            onDiscardDropAt: onDiscardDropAt,
                          ),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

class _RackRows extends StatelessWidget {
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final Set<int> processableTileIds;
  final Function(int) onTileTap;
  final void Function(int, int) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<double> dragTilt;
  final ValueNotifier<Offset?> gridDragPosition;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;
  const _RackRows({
    required this.rack,
    required this.slots,
    required this.dealAnimationSerial,
    required this.processableTileIds,
    required this.onTileTap,
    required this.onReorder,
    required this.onTileDragStart,
    required this.onTileDragUpdate,
    required this.onTileDragEnd,
    required this.dragTilt,
    required this.gridDragPosition,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final avail = box.maxWidth - 12;
        // Sürükleme sırasında hedef yuvalar 3'er piksel yatay vurgu alır.
        // En dar web görünümünde dahi satırın taşmaması için bu payı baştan ayır.
        final widthBasedTile = avail / _GameScreenState._rackRowLength - 6;
        final tw = max(1.0, widthBasedTile);
        final rowHeight = max(1.0, (box.maxHeight - 3) / 2);
        final th = min(tw * 1.28, rowHeight);
        return Column(
          children: [
            SizedBox(
              height: rowHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildRow(0, tw, th),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: rowHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildRow(_GameScreenState._rackRowLength, tw, th),
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
      children: [
        ...List.generate(_GameScreenState._rackRowLength, (rowIndex) {
          final slotIndex = offset + rowIndex;
          final tile = _tileById(slots[slotIndex]);
          if (tile == null) {
            return DragTarget<_DeckDragData>(
              key: ValueKey('rack-slot-$slotIndex'),
              onWillAcceptWithDetails: (_) => canAcceptDeckDrop,
              onAcceptWithDetails: (_) => onDeckDropAt(slotIndex),
              builder: (context, deckCandidates, rejected) =>
                  DragTarget<_DiscardDragData>(
                    onWillAcceptWithDetails: (_) => canAcceptDiscardDrop,
                    onAcceptWithDetails: (_) => onDiscardDropAt(slotIndex),
                    builder: (context, discardCandidates, rejected) =>
                        DragTarget<_RackDragData>(
                          onWillAcceptWithDetails: (_) => true,
                          onAcceptWithDetails: (details) =>
                              onReorder(details.data.tileId, slotIndex),
                          builder: (context, rackCandidates, rejected) {
                            return Container(
                              width: tw,
                              height: th,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.2,
                              ),
                            );
                          },
                        ),
                  ),
            );
          }

          final dragData = _RackDragData(
            tileId: tile.id,
            tileIds: tile.selected ? selectedIds : {tile.id},
            tile: tile,
          );
          final visibleTile = _ProcessableTileMarker(
            key: ValueKey('rack-visible-tile-$slotIndex'),
            active: processableTileIds.contains(tile.id),
            width: tw,
            height: th,
            child: _TileWidget(
              tile: tile,
              w: tw,
              h: th,
              onTap: () => onTileTap(tile.id),
              hideOkey: true,
              emphasized: true,
            ),
          );
          final dealIndex =
              slots.take(slotIndex + 1).whereType<int>().length - 1;
          final tileWidget = dealAnimationSerial == null
              ? visibleTile
              : _DealtRackTile(
                  key: ValueKey('rack-deal-$dealAnimationSerial-${tile.id}'),
                  dealIndex: dealIndex,
                  width: tw,
                  height: th,
                  front: visibleTile,
                );

          return DragTarget<_DeckDragData>(
            key: ValueKey('rack-slot-$slotIndex'),
            onWillAcceptWithDetails: (_) => canAcceptDeckDrop,
            onAcceptWithDetails: (_) => onDeckDropAt(slotIndex),
            builder: (context, deckCandidates, rejected) =>
                DragTarget<_DiscardDragData>(
                  onWillAcceptWithDetails: (_) => canAcceptDiscardDrop,
                  onAcceptWithDetails: (_) => onDiscardDropAt(slotIndex),
                  builder: (context, discardCandidates, rejected) =>
                      DragTarget<_RackDragData>(
                        onWillAcceptWithDetails: (details) =>
                            details.data.tileId != tile.id,
                        onAcceptWithDetails: (details) =>
                            onReorder(details.data.tileId, slotIndex),
                        builder: (context, candidates, rejected) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.2),
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 85),
                            curve: Curves.easeOutCubic,
                            offset:
                                candidates.isNotEmpty ||
                                    deckCandidates.isNotEmpty ||
                                    discardCandidates.isNotEmpty
                                ? const Offset(0.14, 0)
                                : Offset.zero,
                            child: Draggable<_RackDragData>(
                              data: dragData,
                              onDragStarted: () => onTileDragStart(dragData),
                              onDragUpdate: (details) =>
                                  onTileDragUpdate(dragData, details),
                              onDragEnd: (_) => onTileDragEnd(),
                              feedback: Material(
                                color: Colors.transparent,
                                child: ValueListenableBuilder<double>(
                                  valueListenable: dragTilt,
                                  child: _TileWidget(
                                    tile: tile,
                                    w: tw,
                                    h: th,
                                    onTap: null,
                                    hideOkey: true,
                                    emphasized: true,
                                  ),
                                  builder: (context, tilt, child) =>
                                      ValueListenableBuilder<Offset?>(
                                        valueListenable: gridDragPosition,
                                        builder: (context, position, _) =>
                                            Transform.rotate(
                                              angle: tilt,
                                              alignment: Alignment.bottomCenter,
                                              child: Transform.scale(
                                                scale: position == null
                                                    ? 1
                                                    : 1.64,
                                                child: child,
                                              ),
                                            ),
                                      ),
                                ),
                              ),
                              childWhenDragging: SizedBox(
                                width: tw,
                                height: th,
                              ),
                              child: tileWidget,
                            ),
                          ),
                        ),
                      ),
                ),
          );
        }),
      ],
    );
  }
}

class _ProcessableTileMarker extends StatelessWidget {
  final bool active;
  final double width;
  final double height;
  final Widget child;

  const _ProcessableTileMarker({
    super.key,
    required this.active,
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: active ? Border.all(color: OC.numGreen, width: 2) : null,
        boxShadow: active
            ? [
                BoxShadow(
                  color: OC.numGreen.withValues(alpha: 0.65),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    ),
  );
}

class _RackAction {
  final String label;
  final IconData? icon;
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
    this.icon,
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
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF111815),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF8A6027), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        ...actions.asMap().entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _SceneActionButton(action: entry.value),
            ),
          );
        }),
      ],
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
    final label = pairCount != null
        ? 'ÇİFT SAYISI'
        : showRemaining
        ? 'KALAN'
        : 'PER TOPLAMI';
    final value = pairCount ?? points;
    final highlighted =
        (pairCount != null && pairCount! >= 5) ||
        (!showRemaining && pairCount == null && points >= 101);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF251B0D),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: highlighted ? OC.numGreen : const Color(0xFF8A6027),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: const Color(0xFF8A6027),
          ),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: TextStyle(
                  color: highlighted ? OC.numGreen : Colors.white,
                  fontSize: 18,
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(action.color, Colors.white, 0.13)!,
                  Color.lerp(action.color, Colors.black, 0.18)!,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: action.isUndo
                    ? const Color(0xFFFFD37A)
                    : const Color(0xFFD3A44F),
                width: action.isUndo ? 1.8 : 1.2,
              ),
              boxShadow: action.active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
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
                      if (action.icon != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            action.icon,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        action.label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.25,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 2),
                          ],
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
class _TileWidget extends StatefulWidget {
  final Tile tile;
  final double w, h;
  final VoidCallback? onTap;
  final bool hideOkey;
  final bool allowOkeyFaceToggle;
  final bool emphasized;
  final double cornerRadius;
  const _TileWidget({
    super.key,
    required this.tile,
    required this.w,
    required this.h,
    required this.onTap,
    this.hideOkey = false,
    this.allowOkeyFaceToggle = true,
    this.emphasized = false,
    this.cornerRadius = 5,
  });

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget> {
  Tile get tile => widget.tile;

  String get _label {
    if (tile.isFakeOkey) return '★';
    if (tile.isOkey) return '${tile.number}';
    return '${tile.number}';
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = tile.selected;
    final tileWidget = GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.hideOkey && widget.allowOkeyFaceToggle && tile.isOkey
          ? () => setState(() {
              tile.okeyFaceRevealed = !tile.okeyFaceRevealed;
            })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.w,
        height: widget.h,
        transform: Matrix4.translationValues(0, isSelected ? -11 : 0, 0),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('images/tas_ters.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(widget.cornerRadius),
          border: Border.all(
            color: isSelected ? OC.tileSel : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? OC.tileSel.withValues(alpha: 0.45)
                  : Colors.black.withValues(
                      alpha: widget.emphasized ? 0.38 : 0.2,
                    ),
              blurRadius: isSelected ? 10 : (widget.emphasized ? 5 : 3),
              offset: Offset(0, widget.emphasized ? 2.5 : 2),
            ),
          ],
        ),
        child: widget.hideOkey && tile.isOkey && !tile.okeyFaceRevealed
            ? null
            : Stack(
                children: [
                  Center(
                    child: Text(
                      _label,
                      style: TextStyle(
                        color: tile.displayColor,
                        fontSize:
                            widget.h *
                            (tile.isFakeOkey ? 0.47 : 0.44) *
                            (widget.emphasized ? 1.13 : 1),
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.25,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.72),
                            blurRadius: 0.8,
                            offset: const Offset(0, -0.35),
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.36),
                            blurRadius: 1.1,
                            offset: const Offset(0, 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 3,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: widget.w * 0.18,
                        height: widget.w * 0.18,
                        decoration: BoxDecoration(
                          color: tile.displayColor.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
    if (!widget.hideOkey || !widget.allowOkeyFaceToggle || !tile.isOkey) {
      return tileWidget;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(tile.okeyFaceRevealed),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: RepaintBoundary(child: tileWidget),
      builder: (context, value, child) {
        final bounce = sin(value * pi);
        return Transform.translate(
          offset: Offset(0, -widget.h * 0.22 * bounce),
          child: Transform.scale(scale: 1 + bounce * 0.08, child: child),
        );
      },
    );
  }
}

class _MsgBanner extends StatelessWidget {
  final String text;
  const _MsgBanner({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 360),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: OC.panelBrown.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: OC.gold.withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
      ],
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 10),
      textAlign: TextAlign.center,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// EL SONU DİALOG
// ═══════════════════════════════════════════════════════════════════════════
class GameEndDialog extends StatelessWidget {
  final String winner;
  final int playerPen;
  final List<BotPlayer> bots;
  final List<int> botPens;
  final int elCount;
  final int totalPenalty;
  final GameReward? reward;
  final String homeLabel;
  final VoidCallback onNewRound;
  final VoidCallback onResetMatch;
  final VoidCallback onHome;

  const GameEndDialog({
    super.key,
    required this.winner,
    required this.playerPen,
    required this.bots,
    required this.botPens,
    required this.elCount,
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
    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogHeight = max(280.0, min(620.0, screenSize.height - 24));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Container(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: OC.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OC.gold, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                children: [
                  Icon(
                    won ? Icons.emoji_events_rounded : Icons.flag_rounded,
                    size: 34,
                    color: won ? OC.gold : OC.numRed,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    won ? 'Kazandın!' : 'El Bitti',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: won ? OC.numGreen : OC.numRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$elCount. El — Kazanan: $winner',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: OC.panelBrown),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: OC.tileBdr),
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Oyuncu',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: OC.panelBrown,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Bu El',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: OC.panelBrown,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Text(
                                  'Toplam',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: OC.panelBrown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          _ScoreRow(
                            name: 'Oyuncu 1',
                            elPen: playerPen,
                            total: totalPenalty,
                            hi: winner == 'Sen' || winner == 'Oyuncu 1',
                          ),
                          ...List.generate(
                            bots.length,
                            (i) => _ScoreRow(
                              name: bots[i].name,
                              elPen: botPens[i],
                              total: bots[i].penalty + botPens[i],
                              hi: winner == bots[i].name,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (reward != null) ...[
                      _GameRewardCard(reward: reward!),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: OC.openedBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OC.openedBdr),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ceza Kuralları',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: OC.panelBrown,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '• Eli bitiren oyuncu: -101 puan\n'
                            '• El açmadan biterse: 202 ceza\n'
                            '• El açıksa: elde kalan taş değerleri\n'
                            '• Çift açanın kalan taş cezası: 2 katı\n'
                            '• Sahte okey: o elin okey numarası\n'
                            '• İşlenebilir taş atma: 101 ceza\n'
                            '• Hem seri hem çift açılamaz',
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.45,
                              color: OC.numBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.32),
                border: Border(
                  top: BorderSide(color: OC.gold.withValues(alpha: 0.35)),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EndActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'YENİ TUR',
                    color: OC.numGreen,
                    onPressed: onNewRound,
                  ),
                  _EndActionButton(
                    icon: Icons.restart_alt_rounded,
                    label: 'SKORU SIFIRLA',
                    color: OC.numRed,
                    onPressed: onResetMatch,
                  ),
                  _EndActionButton(
                    icon: Icons.home_rounded,
                    label: homeLabel,
                    color: OC.panelBrown,
                    onPressed: onHome,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameRewardCard extends StatelessWidget {
  final GameReward reward;

  const _GameRewardCard({required this.reward});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('game-reward-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          OC.numGreen.withValues(alpha: 0.16),
          OC.gold.withValues(alpha: 0.18),
        ],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: OC.gold.withValues(alpha: 0.65)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OYUN ÖDÜLLERİ',
          style: TextStyle(
            color: OC.panelBrown,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF1688D4),
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  '+${reward.xp} XP',
                  style: const TextStyle(
                    color: Color(0xFF116DAA),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: OC.coinGold, size: 19),
                const SizedBox(width: 4),
                Text(
                  '+${formatGameNumber(reward.coins)} Altın',
                  style: const TextStyle(
                    color: OC.panelBrown,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (reward.levelsGained > 0)
              Text(
                '+${reward.levelsGained} SEVİYE!',
                style: const TextStyle(
                  color: OC.numGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          reward.xpBreakdown.join(' • '),
          style: const TextStyle(color: OC.numBlack, fontSize: 9, height: 1.3),
        ),
      ],
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final int elPen;
  final int total;
  final bool hi;
  const _ScoreRow({
    required this.name,
    required this.elPen,
    required this.total,
    this.hi = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    color: hi ? OC.gold.withValues(alpha: 0.15) : Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Row(
      children: [
        if (hi) const Icon(Icons.emoji_events, color: OC.gold, size: 12),
        if (hi) const SizedBox(width: 3),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: hi ? FontWeight.bold : FontWeight.normal,
              color: OC.numBlack,
            ),
          ),
        ),
        Text(
          '+$elPen',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: elPen > 0 ? OC.numRed : OC.numGreen,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$total',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: OC.numBlack,
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

  const _EndActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(118, 42),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.45),
    ),
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
}

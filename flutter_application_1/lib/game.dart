import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, kIsWeb, listEquals;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import 'game_launch.dart';
import 'bot_turn_pacing.dart';
import 'difficulty_picker.dart';
import 'saved_game.dart';
import 'daily_challenge.dart';
export 'game_launch.dart' show BotDifficulty;
import 'daily_league.dart';
import 'league_simulation.dart';
import 'league_rank_popup.dart';
import 'app_controls.dart';
import 'app_language.dart';
import 'app_settings_dialog.dart';
import 'game_help_dialog.dart';
import 'performance_overlay.dart';
import 'player_progress.dart';
import 'opponent_name_session.dart';
import 'store_cosmetics.dart';
import 'startup_tutorial.dart';

part 'game_rack_solver.dart';
part 'game_bot_engine.dart';
part 'game_animations.dart';
part 'game_settings.dart';
part 'game_table_widgets.dart';
part 'game_rack_widgets.dart';
part 'game_end_dialog.dart';
part 'game_save_state.dart';
part 'game_feedback.dart';
part 'game_bot_animations.dart';
part 'game_scene_artwork.dart';

/// Ana menü ve oyun içi ayarlar arasında paylaşılan titreşim tercihi.
bool gameVibrationEnabled = true;
bool gameSoundEffectsEnabled = true;
bool gameOpponentPicturesEnabled = true;
bool gameAutoArrangeRackEnabled = false;

void setGameVibrationEnabled(bool enabled) {
  gameVibrationEnabled = enabled;
}

void setGameSoundEffectsEnabled(bool enabled) {
  gameSoundEffectsEnabled = enabled;
}

void setGameOpponentPicturesEnabled(bool enabled) {
  gameOpponentPicturesEnabled = enabled;
}

void setGameAutoArrangeRackEnabled(bool enabled) {
  gameAutoArrangeRackEnabled = enabled;
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
  precacheImage(appPopupArtwork(appGameEndPanelAsset), context),
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
  precacheImage(
    const ResizeImage(AssetImage('images/tas_ters.png'), width: 128),
    context,
  ),
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
  bool isIndicator; // yalnız çift açarken başka bir taşı tamamlar
  bool selected;
  bool okeyFaceRevealed;
  final int id; // unique id (drag için)

  Tile({
    required this.number,
    required this.color,
    this.isFakeOkey = false,
    this.isOkey = false,
    this.isIndicator = false,
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
  final bool liftedForMeld;
  final Set<int> tileIds;
  final Tile tile;

  const _RackDragData({
    required this.tileId,
    required this.sourceSlot,
    this.liftedForMeld = false,
    required this.tileIds,
    required this.tile,
  });
}

class _RackDragVisualState {
  final Offset? gridPosition;
  final Offset? globalGridPosition;
  final _RackDragData? dragData;
  final List<Tile> tiles;
  final _MeldDragTarget? target;
  final Offset snapOffset;
  final Color color;
  final double tilt;
  final double lift;

  const _RackDragVisualState({
    this.gridPosition,
    this.globalGridPosition,
    this.dragData,
    this.tiles = const [],
    this.target,
    this.snapOffset = Offset.zero,
    this.color = OC.okeyGold,
    this.tilt = 0,
    this.lift = 0,
  });
}

class _MeldDragGeometry {
  final int index;
  final Element faceElement;
  final RenderBox viewport;
  const _MeldDragGeometry(this.index, this.faceElement, this.viewport);
  RenderBox? get face {
    if (!faceElement.mounted) return null;
    final render = faceElement.findRenderObject();
    return render is RenderBox ? render : null;
  }

  Rect get faceRect => MatrixUtils.transformRect(
    face!.getTransformTo(null),
    Offset.zero & face!.size,
  );
  Rect get viewportRect => MatrixUtils.transformRect(
    viewport.getTransformTo(null),
    Offset.zero & viewport.size,
  );
}

class _MeldDragTarget {
  final int index;
  final Offset point;
  final Rect faceRect;
  final Rect hitRect;
  final Rect viewport;
  final double cellWidth;
  const _MeldDragTarget({
    required this.index,
    required this.point,
    required this.faceRect,
    required this.hitRect,
    required this.viewport,
    required this.cellWidth,
  });

  double distanceFrom(Offset position) =>
      (position -
              Offset(
                position.dx.clamp(faceRect.left, faceRect.right),
                position.dy.clamp(faceRect.top, faceRect.bottom),
              ))
          .distance +
      (position - point).distance * .18;
}

/// Offset of the dragged tile relative to the current first tile of a meld.
double? _meldPlacementColumn(Meld meld, List<Tile> tiles, int primaryId) {
  if (tiles.isEmpty) return null;
  final replacement = tiles.length == 1
      ? Rules.okeyReplacementIndex(meld, tiles.single)
      : null;
  if (replacement != null) return replacement.toDouble();
  if (!Rules.canAddToMeld(meld, tiles)) return null;
  final ordered = Rules.extendMeldKeepingPositions(
    meld.tiles,
    tiles,
    meld.type,
  );
  final index = ordered.indexWhere((tile) => tile.id == primaryId);
  final anchor = ordered.indexWhere((tile) => tile.id == meld.tiles.first.id);
  return index < 0 || anchor < 0
      ? null
      : (meld.type == 'seri' ? index - anchor : index).toDouble();
}

// İşlenebilir taşın hem çizimi hem DragTarget hit testi aynı noktayı izler.
// Böylece perin üzerindeki taş kabul edilir; altta kalan parmak değil.
const double _meldDragLift = 32;
const double _meldDragPlacementLift = _meldDragLift / 2;
const _botDrawLeadIn = Duration(milliseconds: 320);
const _botDrawTravelDuration = Duration(milliseconds: 320);
const _botDiscardTravelDuration = Duration(milliseconds: 300);
const _botOpenTravelDuration = Duration(milliseconds: 380);
const _botProcessTravelDuration = Duration(milliseconds: 300);

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

enum _RackMoveKind { insert, pushLeft, pushRight, swap }

const int _maxRackPushTiles = 6;

int _rackPushVacancy(
  List<int?> slots,
  int sourceSlot,
  int targetSlot, {
  bool? towardRight,
}) {
  final rowLength = _GameScreenState._rackRowLength;
  if (sourceSlot ~/ rowLength != targetSlot ~/ rowLength) return -1;
  final rowStart = (targetSlot ~/ rowLength) * rowLength;
  final rowEnd = rowStart + rowLength;
  final pushRight = towardRight ?? sourceSlot < targetSlot;
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

enum BotPersonality { aggressive, cautious, pairFocused }

class BotPlayer {
  final String name;
  final String displayName;
  BotDifficulty difficulty;
  final BotPersonality personality;
  final int? leagueId;
  String get avatarAsset => switch (name) {
    'Oyuncu 2' => 'görseller/pp/10_kartal.png',
    'Oyuncu 3' => 'görseller/pp/11_timsah.png',
    'Oyuncu 4' => 'görseller/pp/12_kopekbaligi.png',
    _ => rivalAvatarAsset((leagueId ?? 1) - 1),
  };
  int tileCount;
  int penalty;
  bool hasOpened;
  String openType;
  int turnsPlayed;
  List<Tile> hand;
  List<Tile> seenDiscards;
  List<Tile> opponentTakes;
  BotPlayer({
    required this.name,
    String? displayName,
    this.difficulty = BotDifficulty.medium,
    this.personality = BotPersonality.aggressive,
    this.leagueId,
    this.tileCount = 21,
    this.penalty = 0,
    this.hasOpened = false,
    this.openType = '',
    this.turnsPlayed = 0,
    List<Tile>? hand,
    List<Tile>? seenDiscards,
    List<Tile>? opponentTakes,
  }) : displayName = displayName ?? name,
       hand = hand ?? <Tile>[],
       seenDiscards = seenDiscards ?? <Tile>[],
       opponentTakes = opponentTakes ?? <Tile>[];
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

  /// Gösterge yalnız ilk çift açılışında joker desteği verir.
  static bool isPairWildcard(Tile tile, {bool allowIndicator = true}) =>
      tile.isOkey || (allowIndicator && tile.isIndicator && !tile.isFakeOkey);

  /// Çift açılışı: aynı taşın iki kopyası, okey veya gösterge desteği.
  static bool isValidPair(List<Tile> tiles, {bool allowIndicator = true}) {
    if (tiles.length != 2) return false;
    if (tiles[0].id == tiles[1].id) return false;
    final real = tiles
        .where((tile) => !(allowIndicator ? isPairWildcard(tile) : tile.isOkey))
        .toList();
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
        'cift' => isValidPair(candidate, allowIndicator: false),
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

  /// El başında gösterge kopyasını ve gerçek/sahte okeyleri işaretler.
  static void applyIndicator(Iterable<Tile> tiles, Tile indicator) {
    final okeyNumber = okeyNumberForIndicator(indicator.number);
    for (final tile in tiles) {
      tile.isIndicator =
          !tile.isFakeOkey &&
          tile.number == indicator.number &&
          tile.color == indicator.color;
      if (tile.isFakeOkey) {
        tile.number = okeyNumber;
        tile.color = indicator.color;
        tile.isOkey = false;
      } else {
        tile.isOkey =
            tile.number == okeyNumber && tile.color == indicator.color;
      }
    }
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

enum _TableTileMotionKind { drawDeck, drawDiscard, open, process, discard }

enum _GameSound { pick, place, arrange, warning }

class _TableTileMotion {
  final Map<int, Rect> sourceRects;
  final List<Tile> tiles;
  final _TableTileMotionKind kind;
  final int playerIndex;
  final Alignment? targetAlignment;
  final int serial;

  const _TableTileMotion({
    this.sourceRects = const {},
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
  final Map<String, dynamic>? savedState;

  const GameScreen({
    super.key,
    this.tournamentMode = false,
    this.startingPlayer,
    this.launchConfig = const GameLaunchConfig.quickPlay(),
    this.savedState,
  }) : assert(
         startingPlayer == null || (startingPlayer >= 0 && startingPlayer <= 3),
       );
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  Timer? _resumeSaveTimer;
  Map<String, dynamic>? _pendingResume;
  bool _resumeReady = false;
  bool _resumeLeagueEligible = true;
  int? _resumeTimedSeconds;
  List<BotDifficulty> _quickDifficultyOrder = quickPlayDifficulties(Random());

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleResumeSave();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flushResumeSave();
  }

  static const int _rackRowLength = 15;
  static const int _rackSlotCount = _rackRowLength * 2;
  static const int _roomAndModeRoundLimit = 3;
  // Gerçek oyuncu temposu; testlerde gerektiğinde bu sabit açılabilir.
  static const bool _instantBotTurns = false;

  bool get _isTournamentGame =>
      widget.tournamentMode || widget.launchConfig.isTournament;
  bool get _isTutorialGame =>
      widget.launchConfig.entryPoint == GameEntryPoint.tutorial;

  bool _tutorialStepRequired(int requiredStep, String instruction) {
    if (!_isTutorialGame || _tutorialStep == requiredStep) return true;
    _msg_(instruction, duration: const Duration(milliseconds: 2200));
    return false;
  }

  void _finishTutorialStep(int completedStep) {
    if (!_isTutorialGame || _tutorialStep != completedStep || !mounted) return;
    setState(() => _tutorialStep = completedStep + 1);
  }

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
  Timer? _tableMotionTimer;
  Timer? _playerDiscardTimer;
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
    TileColor.red => appText('KIRMIZI', 'RED', german: 'ROT'),
    TileColor.blue => appText('MAVİ', 'BLUE', german: 'BLAU'),
    TileColor.black => appText('SİYAH', 'BLACK', german: 'SCHWARZ'),
    TileColor.yellow => appText('SARI', 'YELLOW', german: 'GELB'),
  };

  Color get _roundBonusDisplayColor => switch (_roundBonusColor) {
    TileColor.red => OC.numRed,
    TileColor.blue => OC.numBlue,
    TileColor.black => const Color(0xFF252525),
    TileColor.yellow => OC.numYellow,
  };

  String get _tableModeLabel => _isColorBonusMode
      ? '${appText('RENKLİ', 'COLOR BONUS', german: 'FARBBONUS')} • $_roundBonusColorName 2×'
      : switch (widget.launchConfig.mode) {
          OkeyGameMode.standard => appText(
            'Sıradan',
            'Standard',
            german: 'Standard',
          ),
          OkeyGameMode.classic101 => appText(
            'Klasik 101',
            'Classic 101',
            german: 'Klassisch 101',
          ),
          OkeyGameMode.timed101 => appText(
            'Zamanlı 101',
            'Timed 101',
            german: '101 auf Zeit',
          ),
          OkeyGameMode.colorBonus101 => appText(
            'Renkli 101',
            'Color Bonus 101',
            german: 'Farbbonus 101',
          ),
          OkeyGameMode.progressive => appText(
            'Katlamalı',
            'Progressive',
            german: 'Progressiv',
          ),
        };
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
  int _roundPlayerPenaltyStart = 0;
  int? _resultPlayerPenalty;
  Map<int, int>? _resultBotPenalties;
  LeagueRoundTables? _leagueRoundTables;
  Future<LeagueRoundUpdate?>? _leagueRoundUpdateFuture;
  bool _startingNextRound = false;
  LeagueRankNotice? _leagueRankNotice;
  Timer? _leagueRankNoticeTimer;
  bool _roomMatchSettled = false;
  String _leagueSessionId = DateTime.now().microsecondsSinceEpoch.toString();
  int _elCount = 0; // kaçıncı el

  // ── Botlar ────────────────────────────────────────────────────────────
  late final List<BotPlayer> _bots = [
    BotPlayer(
      name: 'Oyuncu 2',
      displayName: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? leagueBotNames[0]
          : opponentNameSession.names[0],
      difficulty: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? LeagueBotStyle.forRival(0).difficulty
          : BotDifficulty.medium,
      personality: BotPersonality.aggressive,
    ),
    BotPlayer(
      name: 'Oyuncu 3',
      displayName: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? leagueBotNames[1]
          : opponentNameSession.names[1],
      difficulty: BotDifficulty.hard,
      personality: BotPersonality.cautious,
    ),
    BotPlayer(
      name: 'Oyuncu 4',
      displayName: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? leagueBotNames[2]
          : opponentNameSession.names[2],
      difficulty: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? LeagueBotStyle.forRival(2).difficulty
          : BotDifficulty.easy,
      personality: BotPersonality.pairFocused,
    ),
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
  int _rackShiftSerial = 0;
  Map<int, int> _rackShiftOrigins = const {};
  String? _rackShiftLayoutSignature;
  bool _draggingProcessableTile = false;
  _RackDragData? _activeRackDragData;
  List<_MeldDragGeometry> _meldDragGeometry = const [];
  _RackDragData? _dragPlanData;
  int? _dragPlanRevision;
  List<Tile>? _dragPlanTiles;
  Map<int, double?>? _dragPlanColumns;
  _MeldDragTarget? _currentMeldDragTarget;
  Offset _meldDragSnap = Offset.zero;
  bool _manualMeldDropHandled = false;
  Offset? _lastRackDragGlobalPosition;
  Offset? _lastRackDragPointerPosition;
  Rect? _rackDragSourceRect;
  List<Rect?> _rackDragRowRects = const [];
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
  int _tutorialStep = 0;
  int? _tutorialArrangeTileId;
  int? _tutorialProcessTileId;
  int? _tutorialFinishTileId;
  int? _tutorialFinishSlot;

  String? _msg;
  final ValueNotifier<bool> _playerTurnAttention = ValueNotifier(false);
  Timer? _playerTurnAttentionTimer;
  bool _openingMessage = false;
  String? _warningMsg;
  int _warningSerial = 0;
  int _roundGeneration = 0;
  bool _showColorBonusIntro = false;
  bool _showFinishCelebration = false;
  bool _finishCelebrationSpectacular = true;
  bool _finishCelebrationFromHand = false;
  bool _finishCelebrationWithProcessing = false;
  List<_GridFinishTile> _finishGridTiles = const [];
  final ValueNotifier<Set<int>> _finishHiddenTileIds = ValueNotifier(const {});
  final ValueNotifier<_ProcessedTileHighlight?> _processedTileHighlight =
      ValueNotifier(null);
  Timer? _processedHighlightTimer;
  int _processedHighlightSerial = 0;
  VoidCallback? _onFinishCelebrationComplete;
  bool _openedThisPlayerTurn = false;
  bool _processedInEarlierTurns = false;
  int _finishCelebrationSerial = 0;
  bool _endDialogVisible = false;
  bool _gameOverShown = false;
  bool _autoPlayerBusy = false;
  int _autoPlayerGeneration = 0;
  int _autoPlayerTurns = 0;
  late GameSettings _gameSettings;
  bool _initialFontScaleApplied = false;
  final ValueNotifier<bool> _settingsPanelOpen = ValueNotifier(false);
  bool get _useGameplayAnimations =>
      !_reducedMotion &&
      _gameSettings.animations &&
      (!_gameSettings.autoPlay || _elCount <= 3);
  // Tek native oynatıcı kullanmak, manuel taş hareketlerinde üst üste açılan
  // düşük gecikmeli ses tamponlarının oturum boyunca birikmesini engeller.
  final AudioPlayer _soundPlayer = AudioPlayer();
  int _soundSerial = 0;
  int _lastHapticMicros = -150000;
  bool _reducedMotion = false;
  final Map<_GameSound, int> _lastSoundMicros = {};
  final Stopwatch _soundClock = Stopwatch()..start();

  Future<void> _openGameSettings() async {
    if (_settingsPanelOpen.value || !mounted) return;
    _cancelTimedPlayerTurn();
    _settingsPanelOpen.value = true;
    final updated =
        await showGeneralDialog<AppSettings>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Oyun ayarlarını kapat',
          barrierColor: Colors.black.withValues(alpha: 0.72),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => AppSettingsDialog(
            initial: appSettings.value.copyWith(
              soundEffects: _gameSettings.sound,
              vibration: _gameSettings.vibration,
              showOpponentPictures: _gameSettings.showBots,
            ),
            onHome: _returnToMainMenu,
            onRestart: _restartGameFromToolbar,
            onTutorial: _openTutorialFromSettings,
          ),
          transitionBuilder: appSettingsTransition,
        ).whenComplete(() {
          if (mounted) _settingsPanelOpen.value = false;
        });
    if (updated != null && mounted) {
      appSettings.value = updated;
      unawaited(dailyLeague.setNotificationsEnabled(updated.notifications));
      setGameSoundEffectsEnabled(updated.soundEffects);
      setGameVibrationEnabled(updated.vibration);
      setGameOpponentPicturesEnabled(updated.showOpponentPictures);
      setGameAutoArrangeRackEnabled(updated.autoArrangeRack);
      await appLanguage.setLanguage(updated.language);
      if (!mounted) return;
      setState(() {
        _gameSettings = _gameSettings.copyWith(
          sound: updated.soundEffects,
          vibration: updated.vibration,
          showBots: updated.showOpponentPictures,
          gridMagnifier: updated.moveHints,
          fontScale: updated.fontScale,
        );
      });
    }
    if (mounted) _startTimedPlayerTurn();
  }

  Future<void> _openGameHelp() async {
    _cancelTimedPlayerTurn();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Yardımı kapat',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const GameHelpDialog(),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
    if (mounted && _turn == 0 && !_gameOverShown) _startTimedPlayerTurn();
  }

  Future<void> _restartGameFromToolbar({bool closeResult = false}) async {
    if (_startingNextRound) return;
    _startingNextRound = true;
    await _leagueRoundUpdateFuture;
    _startingNextRound = false;
    if (!mounted) return;
    if (widget.launchConfig.entryPoint == GameEntryPoint.room &&
        !playerProgress.trySpendCoins(widget.launchConfig.entryFee ?? 0)) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: AppGenericPanel(
            width: 380,
            height: 220,
            title: const Text('Yetersiz altın'),
            onClose: () => Navigator.pop(context),
            scrollable: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yeni masa için ${formatGameNumber(widget.launchConfig.entryFee ?? 0)} altın gerekiyor.',
                  style: const TextStyle(color: OC.cream),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (closeResult) Navigator.pop(context);
    _cancelTimedPlayerTurn();
    setState(() {
      _roomMatchSettled = false;
      _totalPenalty = 0;
      _resultPlayerPenalty = 0;
      _resultBotPenalties = <int, int>{};
      _elCount = 0;
      for (final bot in _bots) {
        bot.penalty = 0;
      }
      _startNewRound();
    });
  }

  void _returnToMainMenu() {
    _cancelTimedPlayerTurn();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openTutorialFromSettings() {
    if (_isTutorialGame) {
      _restartGameFromToolbar();
      return;
    }
    unawaited(
      Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              const GameScreen(launchConfig: GameLaunchConfig.tutorial()),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    storeCosmetics.addListener(_cosmeticsChanged);
    _gameSettings = GameSettings(
      sound: gameSoundEffectsEnabled,
      vibration: gameVibrationEnabled,
      showBots: gameOpponentPicturesEnabled,
      gridMagnifier: appSettings.value.moveHints,
    );
    unawaited(prewarmGameAudio());
    if (widget.savedState == null || !_restoreSavedGame(widget.savedState!)) {
      _startNewRound();
    }
    _resumeReady = true;
    _rememberResumeState();
    _scheduleResumeSave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_initialFontScaleApplied) return;
    _initialFontScaleApplied = true;
    final inheritedScale = MediaQuery.textScalerOf(context).scale(1);
    _gameSettings = _gameSettings.copyWith(
      fontScale: inheritedScale / appBaseFontScale,
    );
  }

  void _cosmeticsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    storeCosmetics.removeListener(_cosmeticsChanged);
    _flushResumeSave();
    _resumeSaveTimer?.cancel();
    _resumeReady = false;
    _settingsPanelOpen.dispose();
    _playerTurnAttentionTimer?.cancel();
    _playerTurnAttention.dispose();
    _leagueRankNoticeTimer?.cancel();
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
    _finishHiddenTileIds.dispose();
    _processedHighlightTimer?.cancel();
    _processedTileHighlight.dispose();
    _tableMotionTimer?.cancel();
    _playerDiscardTimer?.cancel();
    _playerTurnSeconds.dispose();
    super.dispose();
  }

  // ── Yeni El Başlat ────────────────────────────────────────────────────
  void _startNewRound() {
    _resumeLeagueEligible = true;
    _resumeTimedSeconds = null;
    _hidePlayerTurnAttention();
    _tableMotionTimer?.cancel();
    _playerDiscardTimer?.cancel();
    _tableTileMotionSerial++;
    final hadPreviousRound = _elCount > 0;
    _roundGeneration++;
    final currentRoundGeneration = _roundGeneration;
    _leagueRankNoticeTimer?.cancel();
    _leagueRankNotice = null;
    if (widget.launchConfig.entryPoint == GameEntryPoint.quickPlay) {
      _leagueRankNoticeTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted ||
            currentRoundGeneration != _roundGeneration ||
            _gameOverShown) {
          return;
        }
        final notice = dailyLeague.takeRankNotice();
        if (notice == null) return;
        setState(() => _leagueRankNotice = notice);
        _leagueRankNoticeTimer = Timer(const Duration(milliseconds: 3200), () {
          if (mounted && currentRoundGeneration == _roundGeneration) {
            setState(() => _leagueRankNotice = null);
          }
        });
      });
    }
    _leagueRoundUpdateFuture = null;
    final seating = LeagueSeating.forRound(dailyLeague.completedRounds);
    if (widget.launchConfig.entryPoint == GameEntryPoint.quickPlay &&
        dailyLeague.initialized &&
        !dailyLeague.complete) {
      final scores = {
        for (final entry in dailyLeague.standings) entry.id: entry.penalty,
      };
      _totalPenalty = scores[0]!;
      for (var seat = 0; seat < 3; seat++) {
        final id = seating.table(0)[seat + 1];
        final style = LeagueBotStyle.forRival(id - 1);
        _bots[seat] = BotPlayer(
          name: 'Oyuncu ${seat + 2}',
          displayName: leagueBotNames[id - 1],
          leagueId: id,
          difficulty: style.difficulty,
          personality: style.personality,
          penalty: scores[id]!,
        );
      }
    }
    if (widget.launchConfig.entryPoint == GameEntryPoint.quickPlay &&
        !dailyLeague.complete) {
      final tables = LeagueRoundTables(seating: seating);
      _leagueRoundTables = tables;
      tables.scores = _prepareLeagueTables(tables, currentRoundGeneration);
    } else {
      _leagueRoundTables = null;
    }
    _elCount++;
    if (widget.launchConfig.entryPoint == GameEntryPoint.quickPlay &&
        (_elCount - 1) % 3 == 0) {
      _quickDifficultyOrder = quickPlayDifficulties(Random());
    }
    if (widget.launchConfig.entryPoint == GameEntryPoint.quickPlay ||
        _hasThreeRoundLimit) {
      final difficulty =
          widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
          ? _quickDifficultyOrder[(_elCount - 1) % 3]
          : widget.launchConfig.difficulty ?? BotDifficulty.medium;
      for (final bot in _bots) {
        bot.difficulty = difficulty;
      }
    }
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

    Rules.applyIndicator(_deck, _indicator!);

    _startingPlayer = _isTutorialGame
        ? 0
        : widget.startingPlayer ?? Random().nextInt(4);

    // Önce herkese 21, ardından başlayan oyuncuya 22. taş dağıtılır.
    _rack = List<Tile>.from(_deck.take(21));
    _deck = _deck.sublist(21);
    for (final bot in _bots) {
      bot.hand = List<Tile>.from(_deck.take(21));
      _deck = _deck.sublist(21);
      bot.hasOpened = false;
      bot.openType = '';
      bot.turnsPlayed = 0;
      bot.seenDiscards = <Tile>[];
      bot.opponentTakes = <Tile>[];
    }
    final extraTile = _deck.removeLast();
    if (_startingPlayer == 0) {
      _rack.add(extraTile);
    } else {
      _bots[_startingPlayer - 1].hand.add(extraTile);
    }
    _compactRackSlots();
    if (_gameSettings.autoPlay || gameAutoArrangeRackEnabled) {
      _arrangeAutoPlayerRack();
    }
    for (final bot in _bots) {
      bot.tileCount = bot.hand.length;
    }

    _tableMetds = [];
    if (_isTutorialGame) {
      // Eğitim eli oyunun ortasındaymış gibi az taşla başlar. Dört hazır per
      // 105 puan eder; kırmızı 7 işlenir, çekilen sarı 13 ise son taş olarak atılır.
      _rack = [
        for (final color in [TileColor.red, TileColor.blue, TileColor.black])
          for (var number = 10; number <= 12; number++)
            Tile(number: number, color: color, id: _idCounter++),
        for (var number = 1; number <= 3; number++)
          Tile(number: number, color: TileColor.yellow, id: _idCounter++),
        Tile(number: 7, color: TileColor.red, id: _idCounter++),
      ];
      final tutorialFinishTile = Tile(
        number: 13,
        color: TileColor.yellow,
        id: _idCounter++,
      );
      _deck.add(tutorialFinishTile);
      _tutorialFinishTileId = tutorialFinishTile.id;
      _tableMetds.add(
        Meld(
          tiles: [
            Tile(number: 4, color: TileColor.red, id: _idCounter++),
            Tile(number: 5, color: TileColor.red, id: _idCounter++),
            Tile(number: 6, color: TileColor.red, id: _idCounter++),
          ],
          type: 'seri',
        ),
      );
      _tutorialStep = 0;
      _tutorialFinishSlot = null;
      _rackSlots = List<int?>.filled(_rackSlotCount, null);
      void placeTutorialTiles(Iterable<Tile> tiles, int startSlot) {
        var slot = startSlot;
        for (final tile in tiles) {
          _rackSlots[slot++] = tile.id;
        }
      }

      placeTutorialTiles(
        _rack.where((tile) => tile.color == TileColor.red && tile.number >= 10),
        0,
      );
      placeTutorialTiles(
        _rack.where((tile) => tile.color == TileColor.blue),
        4,
      );
      placeTutorialTiles(
        _rack.where((tile) => tile.color == TileColor.black),
        8,
      );
      placeTutorialTiles(
        _rack.where(
          (tile) => tile.color == TileColor.yellow && tile.number <= 2,
        ),
        12,
      );
      final yellowThree = _rack.firstWhere(
        (tile) => tile.color == TileColor.yellow && tile.number == 3,
      );
      _tutorialArrangeTileId = yellowThree.id;
      _rackSlots[20] = yellowThree.id;
      final processTile = _rack.firstWhere(
        (tile) => tile.color == TileColor.red && tile.number == 7,
      );
      _tutorialProcessTileId = processTile.id;
      _rackSlots[22] = processTile.id;
    }
    _markTableChanged();
    _discarded = null;
    _discardPiles = List.generate(4, (_) => <Tile>[]);
    _playerOpened = false;
    _roundPlayerPenaltyStart = _totalPenalty;
    _openedThisPlayerTurn = false;
    _playerOpenType = '';
    _processedInEarlierTurns = false;
    _drawnThisTurn = false;
    _tookDiscard = false;
    _takenDiscardTile = null;
    _botBusy = false;
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
    _draggingProcessableTile = false;
    _drawAttentionTileId = null;
    _botDiscardMotion = null;
    _processedHighlightTimer?.cancel();
    _processedTileHighlight.value = null;
    _tableTileMotion.value = null;
    _uiMode = 'normal';
    _processedMoves.clear();
    _gameOverShown = false;
    _autoPlayerBusy = false;
    _autoPlayerGeneration++;
    _autoPlayerTurns = 0;
    _showFinishCelebration = false;
    _finishGridTiles = const [];
    _finishHiddenTileIds.value = const {};
    _onFinishCelebrationComplete = null;
    _finishCelebrationSerial++;
    _endDialogVisible = false;

    // Her el rastgele bir koltuktan başlar; başlayan oyuncu zaten 22 taşlıdır.
    _turn = _startingPlayer;
    _drawnThisTurn = _isTutorialGame ? false : _turn == 0;
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
          _beginPlayerTurn(alreadyHasExtraTile: true);
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
          _beginPlayerTurn(alreadyHasExtraTile: true);
        }
      });
    }
  }

  void _cancelTimedPlayerTurn() {
    _playerTurnGeneration++;
    _playerTurnTimer?.cancel();
    _playerTurnTimer = null;
  }

  void _hidePlayerTurnAttention() {
    _playerTurnAttentionTimer?.cancel();
    _playerTurnAttentionTimer = null;
    _playerTurnAttention.value = false;
  }

  void _beginPlayerTurn({bool alreadyHasExtraTile = false}) {
    if (!mounted || _turn != 0 || _dealInProgress || _gameOverShown) return;
    if (!_isTutorialGame && !_gameSettings.autoPlay) {
      _playerTurnAttentionTimer?.cancel();
      _playerTurnAttention.value = true;
      _playerTurnAttentionTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) _hidePlayerTurnAttention();
      });
    }
    _startTimedPlayerTurn();
    _scheduleAutoPlayer(alreadyHasExtraTile: alreadyHasExtraTile);
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
    _playerTurnSeconds.value = _resumeTimedSeconds ?? 7;
    _resumeTimedSeconds = null;
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
    Map<int, Rect>? sourceRectsOverride,
  }) {
    final isBotMotion = playerIndex > 0;
    final visibleTileLimit = switch (kind) {
      _TableTileMotionKind.drawDeck || _TableTileMotionKind.drawDiscard => 1,
      _TableTileMotionKind.discard => 1,
      _TableTileMotionKind.process => isBotMotion ? 1 : tiles.length,
      _TableTileMotionKind.open =>
        isBotMotion ? min(4, tiles.length) : tiles.length,
    };
    final visibleTiles = tiles.take(visibleTileLimit).toList();
    if (visibleTiles.isEmpty) return;
    if (kind == _TableTileMotionKind.open ||
        kind == _TableTileMotionKind.process) {
      _playInteractionFeedback(
        haptic: !isBotMotion,
        strong: kind == _TableTileMotionKind.open,
        sound: _GameSound.arrange,
      );
    }
    if (!_useGameplayAnimations) return;
    final serial = ++_tableTileMotionSerial;
    final motion = _TableTileMotion(
      sourceRects:
          sourceRectsOverride ??
          {
            if (!isBotMotion)
              for (final tile in visibleTiles)
                if (_gameRectForKey(
                      context,
                      kind == _TableTileMotionKind.drawDeck
                          ? const ValueKey('grid-deck-slot')
                          : kind == _TableTileMotionKind.drawDiscard
                          ? const ValueKey('discard-Oyuncu 4')
                          : ValueKey('rack-tile-${tile.id}'),
                    )
                    case final Rect rect)
                  tile.id: rect,
          },
      tiles: visibleTiles,
      kind: kind,
      playerIndex: playerIndex,
      targetAlignment: targetAlignment,
      serial: serial,
    );
    final clearDelay = switch (kind) {
      _TableTileMotionKind.drawDeck || _TableTileMotionKind.drawDiscard =>
        Duration(milliseconds: isBotMotion ? 380 : 520),
      _TableTileMotionKind.discard => const Duration(milliseconds: 520),
      _TableTileMotionKind.process => Duration(
        milliseconds: isBotMotion
            ? _botProcessTravelDuration.inMilliseconds + 40
            : 540,
      ),
      _TableTileMotionKind.open => Duration(
        milliseconds: isBotMotion
            ? _botOpenTravelDuration.inMilliseconds + 40
            : 620,
      ),
    };
    _tableTileMotion.value = motion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _tableTileMotionSerial) return;
      // Newly created rack/table targets receive their size during this frame.
      // Refresh the overlay once layout is ready, keeping landing tiles hidden.
      _tableTileMotion.value = _TableTileMotion(
        tiles: motion.tiles,
        kind: motion.kind,
        playerIndex: motion.playerIndex,
        targetAlignment: motion.targetAlignment,
        serial: motion.serial,
        sourceRects: motion.sourceRects,
      );
      _tableMotionTimer?.cancel();
      _tableMotionTimer = Timer(clearDelay, () {
        if (!mounted || _tableTileMotion.value?.serial != serial) return;
        _tableTileMotion.value = null;
      });
    });
  }

  // ── Mesaj ─────────────────────────────────────────────────────────────
  void _msg_(
    String m, {
    Duration duration = const Duration(milliseconds: 1400),
    bool opening = false,
  }) {
    if (_msg == m) return;
    _warningTimer?.cancel();
    _warningTimer = null;
    _messageTimer?.cancel();
    setState(() {
      _warningMsg = null;
      _msg = m;
      _openingMessage = opening;
    });
    _messageTimer = Timer(duration, () {
      _messageTimer = null;
      if (mounted && _msg == m) setState(() => _msg = null);
    });
  }

  void _announceOpening(String name, String type) {
    final text = type == 'cift'
        ? appText(
            '$name çift açtı',
            '$name opened pairs',
            german: '$name hat Paare eröffnet',
          )
        : appText(
            '$name elini açtı',
            '$name opened their hand',
            german: '$name hat eröffnet',
          );
    _msg_(text, opening: true, duration: const Duration(milliseconds: 2400));
  }

  void _warn_(String message) {
    if (_warningMsg != message) {
      _playInteractionFeedback(sound: _GameSound.warning);
    }
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

  void _tapTile(int tileId) {
    if (_isTutorialGame && _tutorialStep < 3) {
      _msg_('Önce ekrandaki öğretici adımını tamamla.');
      return;
    }
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Önce taş çek, ardından bir taş at.');
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
    if (_isTutorialGame && _tutorialStep != 1) {
      _msg_('Önce ekrandaki sürükleme adımını tamamla.');
      return;
    }
    if (_isTutorialGame && tileId != _tutorialArrangeTileId) {
      _msg_('Bu adımda yalnız sarı 3 taşını sarı 1-2 taşlarının yanına taşı.');
      return;
    }
    final from = _rackSlots.indexOf(tileId);
    if (from == -1) return;
    final target = targetIndex.clamp(0, _rackSlotCount - 1);
    if (from == target) return;
    var moved = false;
    final slotsBeforeMove = List<int?>.from(_rackSlots);
    setState(() {
      // Kaynak taşı önce kaldır. Böylece taşın bıraktığı gerçek boşluk da
      // zincirleme yerleştirme hesabına dahil edilir.
      _rackSlots[from] = null;
      if (_rackSlots[target] == null) {
        _rackSlots[target] = tileId;
        moved = true;
      } else if (moveKind == _RackMoveKind.swap) {
        _rackSlots[from] = _rackSlots[target];
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
        final vacancy = _rackPushVacancy(
          _rackSlots,
          from,
          target,
          towardRight: moveKind == _RackMoveKind.pushRight,
        );
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
      if (_isTutorialGame && moved) {
        final allIds = _rack.map((tile) => tile.id).toSet();
        final arranged = _rackGroups(allIds).any(
          (group) =>
              group.any((tile) => tile.id == _tutorialArrangeTileId) &&
              Rules.isValidRun(group),
        );
        if (!arranged) {
          _rackSlots = slotsBeforeMove;
          moved = false;
        }
      }
      if (moved) {
        _rackAnalysisSignature = null;
        _rackShiftSerial++;
        // Only displaced neighbours slide one slot. The released tile follows
        // the finger directly; no lift, bounce or long travel animation.
        _rackShiftOrigins = {
          for (var index = 0; index < _rackSlots.length; index++)
            if (_rackSlots[index] != null &&
                _rackSlots[index] != tileId &&
                slotsBeforeMove.contains(_rackSlots[index]) &&
                (slotsBeforeMove.indexOf(_rackSlots[index]) - index).abs() ==
                    1 &&
                slotsBeforeMove.indexOf(_rackSlots[index]) ~/ _rackRowLength ==
                    index ~/ _rackRowLength)
              _rackSlots[index]!:
                  slotsBeforeMove.indexOf(_rackSlots[index]) - index,
        };
        _rackShiftLayoutSignature = _rackSlots.join(',');
      }
    });
    if (_isTutorialGame && !moved) {
      _msg_('Sarı 3 taşını sarı 1-2 dizisinin hemen yanına bırak.');
      return;
    }
    if (moved) {
      _playInteractionFeedback(sound: _GameSound.place);
      if (_isTutorialGame &&
          _tutorialStep == 1 &&
          tileId == _tutorialArrangeTileId) {
        final allIds = _rack.map((tile) => tile.id).toSet();
        final arranged = _rackGroups(allIds).any(
          (group) =>
              group.any((tile) => tile.id == _tutorialArrangeTileId) &&
              Rules.isValidRun(group),
        );
        if (arranged) _finishTutorialStep(1);
      }
    }
  }

  int get _currentRackSignature => Object.hash(
    Object.hashAll(
      _rack.map(
        (tile) => Object.hash(
          tile.id,
          tile.number,
          tile.color,
          tile.isOkey,
          tile.isIndicator,
        ),
      ),
    ),
    Object.hashAll(_rackSlots),
  );

  void _ensureRackAnalysis() {
    final signature = Object.hash(_currentRackSignature, _playerOpened);
    if (_rackAnalysisSignature == signature) return;
    final allIds = _rack.map((tile) => tile.id).toSet();
    final groups = _rackGroups(allIds);
    _cachedRackPerPoints = _isColorBonusMode
        ? Rules.coloredOpeningValue(groups, _roundBonusColor)
        : Rules.validMeldTotal(groups);
    _cachedRackPairCount = RackSolver.pairs(
      _rack,
      allowIndicator: !_playerOpened,
    ).length;
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
    if (!_tutorialStepRequired(0, 'Önce ortadaki kapalı desteden taş çek.')) {
      return;
    }
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (_isTutorialGame && targetSlot == null) {
      _msg_('Kapalı taşı ortadan tutup ıstakadaki boş yere sürükle.');
      return;
    }
    if (_drawnThisTurn) {
      _warn_('Taşını çektin; şimdi bir taş at.');
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
      if (_isTutorialGame) {
        _tutorialFinishSlot = _rackSlots.indexOf(tile.id);
      }
      _drawAttentionTileId = targetSlot == null ? tile.id : null;
      if (_drawAttentionTileId != null) _drawAttentionSerial++;
      if (targetSlot == null) {
        _beginTableTileMotion(_TableTileMotionKind.drawDeck, [tile]);
      }
      _drawnThisTurn = true;
      _tookDiscard = false;
    });
    _playInteractionFeedback(sound: _GameSound.pick);
    _finishTutorialStep(0);
  }

  // ── Atılan Taşı Al (soldan çek) ───────────────────────────────────────
  void _takeDiscarded([int? targetSlot]) {
    if (_isTutorialGame) {
      _msg_('Bu adımda ortadaki kapalı desteden taş çek.');
      return;
    }
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (_drawnThisTurn) {
      _warn_('Taşını çektin; şimdi bir taş at.');
      return;
    }
    if (_discarded == null) {
      _warn_('Solda alınabilecek taş yok; desteden çek.');
      return;
    }

    setState(() {
      _takenDiscardTile = _discarded;
      final tile = _discarded!;
      _recordDiscardTaken(0, tile);
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
  void _discardTile({bool timedOut = false, bool tutorialDrag = false}) {
    if (!_tutorialStepRequired(4, 'Önce işlek kırmızı 7 taşını işle.')) {
      return;
    }
    if (_isTutorialGame && !tutorialDrag) {
      _msg_('Son taşı tutup ortadaki taş atma alanına sürükle.');
      return;
    }
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Önce taş çek, ardından bir taş at.');
      return;
    }
    if (_tookDiscard && !_playerOpened && !timedOut) {
      _warn_('Soldan aldığın taşı açılışta kullan veya geri bırak.');
      return;
    }

    final sel = _rack.where((t) => t.selected).toList();
    if (sel.length != 1) {
      _warn_('Atmak istediğin tek taşı seç.');
      return;
    }

    final tile = sel.first;
    final finishedFromHand = _openedThisPlayerTurn;
    final finishedWithProcessing =
        _processedInEarlierTurns || _processedMoves.isNotEmpty;
    _processedInEarlierTurns = finishedWithProcessing;
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
      if (!tutorialDrag) {
        _beginTableTileMotion(_TableTileMotionKind.discard, [tile]);
      }
    });
    _releaseTurnTransients();
    _playInteractionFeedback(strong: true);

    if (_rack.isEmpty) {
      _playApplause();
      if (_isTutorialGame) {
        setState(() {
          _showFinishCelebration = true;
          _botBusy = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.of(context).pop(true);
        });
        return;
      }

      _endRoundPlayerWins(
        finishedFromHand: finishedFromHand,
        finishedWithProcessing: finishedWithProcessing,
      );
      return;
    }
    if (!tutorialDrag && _useGameplayAnimations) {
      final generation = _roundGeneration;
      setState(() => _botBusy = true);
      _playerDiscardTimer?.cancel();
      _playerDiscardTimer = Timer(const Duration(milliseconds: 540), () {
        if (!mounted ||
            generation != _roundGeneration ||
            _turn != 0 ||
            _gameOverShown) {
          return;
        }
        _nextTurn();
      });
    } else {
      _nextTurn();
    }
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
    if (_isTutorialGame && _tutorialStep != 2) {
      _msg_('Önce ekrandaki öğretici adımını tamamla.');
      return;
    }
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Önce desteden veya soldan bir taş çek.');
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
      _warn_('En az 3 taş: aynı renkte sıra veya farklı renklerde aynı sayı.');
      return;
    }
    final openingValue = _isColorBonusMode
        ? Rules.coloredOpeningValue(groups, _roundBonusColor)
        : Rules.validMeldTotal(groups);
    if (!_playerOpened && openingValue < _minimumStandardOpeningScore) {
      _warn_(
        'Açılış için ${_minimumStandardOpeningScore - openingValue} puan eksik. '
        'Seçili: $openingValue / $_minimumStandardOpeningScore',
      );
      return;
    }
    if (selected.length >= _rack.length) {
      _warn_('Açarken veya işlerken, son atış için elinde 1 taş bırak.');
      return;
    }

    // Soldan taş aldıysa kullanılmış olmalı
    if (_tookDiscard && _takenDiscardTile != null) {
      if (!tileIds.contains(_takenDiscardTile!.id)) {
        _warn_('Soldan aldığın taşı açılışta kullan veya geri bırak.');
        return;
      }
    }

    final wasAlreadyOpened = _playerOpened;
    final openedMelds = <Meld>[
      for (int i = 0; i < groups.length; i++)
        Meld(tiles: Rules.orderedMeld(groups[i], types[i]!), type: types[i]!),
    ];
    setState(() {
      for (final tile in selected) {
        tile.selected = false;
      }
      _tableMetds.addAll(openedMelds);
      _markTableChanged();
      _clearRackSlots(tileIds);
      _rack.removeWhere((tile) => tileIds.contains(tile.id));
      if (!_playerOpened) {
        _openedThisPlayerTurn = true;
        _recordProgressiveOpening('seri', openingValue);
      }
      _playerOpened = true;
      _playerOpenType = 'seri';
      _tookDiscard = false;
      _takenDiscardTile = null;
      _beginTableTileMotion(_TableTileMotionKind.open, selected);
    });
    _finishTutorialStep(2);
    if (!wasAlreadyOpened) {
      if (!_isTutorialGame) playerProgress.recordOpening(openingValue);
      _announceOpening(playerProgress.playerName, 'seri');
    } else {
      _msg_('${groups.length} per açıldı! ✓ ($openingValue puan)');
    }
  }

  // ── El Aç (Çift) ─────────────────────────────────────────────────────
  List<List<Tile>>? _pairGroups(Set<int> tileIds) {
    final selected = _rack.where((tile) => tileIds.contains(tile.id)).toList();
    if (selected.isEmpty || selected.length.isOdd) return null;

    final pairs = RackSolver.pairs(selected, allowIndicator: !_playerOpened);
    final pairedIds = pairs
        .expand((pair) => pair)
        .map((tile) => tile.id)
        .toSet();
    return pairedIds.length == selected.length ? pairs : null;
  }

  void _openPairs(
    Set<int> tileIds, {
    List<List<Tile>>? detectedPairs,
    bool animateMotion = true,
  }) {
    if (_turn != 0) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Önce desteden veya soldan bir taş çek.');
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
    if (pairs == null ||
        pairs.any(
          (pair) => !Rules.isValidPair(pair, allowIndicator: !_playerOpened),
        )) {
      _warn_('Çiftler aynı sayı ve renkte olmalı.');
      return;
    }
    if (!_playerOpened && pairs.length < _minimumPairOpeningCount) {
      _warn_(
        'Açılış için ${_minimumPairOpeningCount - pairs.length} çift eksik. '
        'Seçili: ${pairs.length} / $_minimumPairOpeningCount',
      );
      return;
    }
    if (selected.length >= _rack.length) {
      _warn_('Açarken veya işlerken, son atış için elinde 1 taş bırak.');
      return;
    }
    if (_tookDiscard && _takenDiscardTile != null) {
      if (!tileIds.contains(_takenDiscardTile!.id)) {
        _warn_('Soldan aldığın taşı açılışta kullan veya geri bırak.');
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
        _openedThisPlayerTurn = true;
        _recordProgressiveOpening('cift', pairs.length);
      }
      _playerOpened = true;
      if (!layingPairsAfterStandard) _playerOpenType = 'cift';
      _tookDiscard = false;
      _takenDiscardTile = null;
      if (animateMotion) {
        _beginTableTileMotion(
          wasAlreadyOpened
              ? _TableTileMotionKind.process
              : _TableTileMotionKind.open,
          selected,
          targetAlignment: wasAlreadyOpened ? const Alignment(0, -0.18) : null,
        );
      }
    });
    if (!wasAlreadyOpened) {
      _announceOpening(playerProgress.playerName, 'cift');
    } else {
      _msg_(
        wasAlreadyOpened
            ? '${pairs.length} çift, açık çift alanına işlendi! ✓'
            : '${pairs.length} çift açıldı! ✓',
      );
    }
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
    if (_rack.isEmpty || _tableMetds.isEmpty) {
      return const <int>{};
    }
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
    for (var index = 0; index < _bots.length; index++) {
      if (index + 1 == seat) continue;
      final memory = _bots[index].seenDiscards;
      memory.add(tile);
      if (memory.length > 32) memory.removeAt(0);
    }
  }

  void _recordDiscardTaken(int seat, Tile tile) {
    for (var index = 0; index < _bots.length; index++) {
      if (index + 1 == seat) continue;
      final memory = _bots[index].opponentTakes;
      memory.add(tile);
      if (memory.length > 16) memory.removeAt(0);
    }
  }

  void _markTableChanged() {
    _tableRevision++;
    _processableSignature = null;
    _clearDragMeldPlan();
  }

  void _clearDragMeldPlan() {
    _dragPlanData = null;
    _dragPlanRevision = null;
    _dragPlanTiles = null;
    _dragPlanColumns = null;
  }

  double? _meldColumnForDrag(int index, _RackDragData data) {
    if (index < 0 || index >= _tableMetds.length) return null;
    // A pointer can produce many updates in one frame. Rules and insertion
    // order stay the same until the dragged tiles or the table change.
    if (!identical(_dragPlanData, data) ||
        _dragPlanRevision != _tableRevision) {
      _dragPlanData = data;
      _dragPlanRevision = _tableRevision;
      _dragPlanTiles = _tilesForDrag(data);
      _dragPlanColumns = <int, double?>{};
    }
    final columns = _dragPlanColumns!;
    if (!columns.containsKey(index)) {
      columns[index] = _meldPlacementColumn(
        _tableMetds[index],
        _dragPlanTiles!,
        data.tileId,
      );
    }
    return columns[index];
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
    _clearDragMeldPlan();
    _currentMeldDragTarget = null;
    _meldDragSnap = Offset.zero;
    _manualMeldDropHandled = false;
    _meldDragGeometry = _captureMeldDragGeometry();
    _rackDragSourceRect = _gameRectForKey(
      context,
      ValueKey('rack-slot-${data.sourceSlot}'),
    );
    _rackDragRowRects = [
      _gameRectForKey(context, const ValueKey('rack-slot-0')),
      _gameRectForKey(context, ValueKey('rack-slot-$_rackRowLength')),
    ];
    _lastRackDragGlobalPosition = null;
    _lastRackDragPointerPosition = _rackDragSourceRect?.center;
    _draggingProcessableTile = data.liftedForMeld;
    if (!_draggingProcessableTile) {
      _pendingGridDragPosition = null;
      _rackDragVisual.value = const _RackDragVisualState();
    }
  }

  List<_MeldDragGeometry> _captureMeldDragGeometry() {
    final geometries = <_MeldDragGeometry>[];
    final pattern = RegExp(r'^(?:run|pair)-meld-(\d+)$');
    void visit(Element element) {
      final key = element.widget.key;
      final match = key is ValueKey<String>
          ? pattern.firstMatch(key.value)
          : null;
      if (match != null) {
        final face = element.findRenderObject();
        RenderBox? viewport;
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is! InteractiveViewer) return true;
          final render = ancestor.findRenderObject();
          if (render is RenderBox && render.hasSize) viewport = render;
          return false;
        });
        if (face is RenderBox && face.hasSize && viewport != null) {
          geometries.add(
            _MeldDragGeometry(int.parse(match.group(1)!), element, viewport!),
          );
        }
      }
      element.visitChildren(visit);
    }

    visit(context as Element);
    return geometries;
  }

  void _resolveMeldDragTarget(_RackDragData data, Offset position) {
    if (!_playerOpened || _turn != 0 || !_drawnThisTurn) {
      _currentMeldDragTarget = null;
      _meldDragSnap = Offset.zero;
      return;
    }
    final candidates = <_MeldDragTarget>[];
    final viewportRects = <RenderBox, Rect>{};
    for (final geometry in _meldDragGeometry) {
      final face = geometry.face;
      if (face == null ||
          !face.attached ||
          !face.hasSize ||
          !geometry.viewport.attached ||
          geometry.index >= _tableMetds.length) {
        continue;
      }
      final viewport = viewportRects.putIfAbsent(
        geometry.viewport,
        () => geometry.viewportRect,
      );
      if (!viewport.contains(position)) continue;
      final meld = _tableMetds[geometry.index];
      final column = _meldColumnForDrag(geometry.index, data);
      if (column == null) continue;
      final rect = MatrixUtils.transformRect(
        face.getTransformTo(null),
        Offset.zero & face.size,
      );
      final cellWidth = rect.width / max(1, meld.tiles.length);
      // Keep a usable touch margin even when the table is zoomed out.
      final verticalPadding = (rect.height * .65).clamp(12.0, 26.0);
      final point = Offset(
        rect.left + (column + .5) * cellWidth,
        rect.center.dy,
      );
      if (!viewport.contains(point)) continue;
      final horizontalPadding = max(16.0, cellWidth * 3);
      final placementRect = Rect.fromCenter(
        center: point,
        width: cellWidth,
        height: rect.height,
      );
      final landingArea = rect.expandToInclude(placementRect);
      final hitRect = Rect.fromLTRB(
        landingArea.left - horizontalPadding,
        landingArea.top - verticalPadding,
        landingArea.right + horizontalPadding,
        landingArea.bottom + verticalPadding,
      ).intersect(viewport);
      candidates.add(
        _MeldDragTarget(
          index: geometry.index,
          point: point,
          faceRect: rect,
          viewport: viewport,
          cellWidth: cellWidth,
          hitRect: hitRect,
        ),
      );
    }
    if (candidates.isEmpty) {
      _currentMeldDragTarget = null;
      _meldDragSnap = Offset.zero;
      return;
    }
    // Preserve distant preview guides, but only nearby legal targets compete
    // once the tile enters a landing area.
    final nearby = candidates
        .where((candidate) => candidate.hitRect.contains(position))
        .toList();
    final selectable = nearby.isEmpty ? candidates : nearby;
    var target = selectable.first;
    var targetDistance = target.distanceFrom(position);
    for (final candidate in selectable.skip(1)) {
      final distance = candidate.distanceFrom(position);
      if (distance < targetDistance) {
        target = candidate;
        targetDistance = distance;
      }
    }
    for (final previous in selectable) {
      if (previous.index != _currentMeldDragTarget?.index) continue;
      final margin = (previous.cellWidth * .80).clamp(14.0, 30.0);
      final leavingHitArea =
          !previous.hitRect.contains(position) &&
          target.hitRect.contains(position);
      final directNewTarget =
          target.faceRect.contains(position) &&
          !previous.faceRect.contains(position);
      if (!leavingHitArea &&
          !directNewTarget &&
          targetDistance + margin >= previous.distanceFrom(position)) {
        target = previous;
      }
      break;
    }
    _currentMeldDragTarget = target;
    final delta = target.point - position;
    final radius = (target.cellWidth * 1.1).clamp(24.0, 44.0);
    final distance = delta.distance;
    _meldDragSnap = target.hitRect.contains(position) && distance < radius
        ? delta * (.60 * (1 - distance / radius))
        : Offset.zero;
  }

  void _updateGridDragZoom(_RackDragData data, DragUpdateDetails details) {
    _lastRackDragPointerPosition = details.globalPosition;
    if (_draggingProcessableTile) _rackPushPreview.value = null;
    final targetTilt = (details.delta.dx * 0.020).clamp(-0.10, 0.10);
    final tilt = _pendingRackDragTilt * 0.70 + targetTilt.toDouble() * 0.30;
    Offset? localPosition;
    var lift = 0.0;
    final renderObject = _meldGridKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      // İşlenebilir taşın görseli ve hedef noktası sürükleme boyunca aynı sabit
      // uzaklıkta kalır; masaya girerken hit-test konumu sıçramaz.
      lift = _draggingProcessableTile ? _meldDragLift : 0;
      // Keep placement halfway between the raised tile and the fingertip.
      // Preview and release use the same point without changing the visual lift.
      final rawCenter = details.globalPosition.translate(
        0,
        _draggingProcessableTile ? -_meldDragPlacementLift : 0,
      );
      var placementCenter = rawCenter;
      if (_draggingProcessableTile) {
        _resolveMeldDragTarget(data, rawCenter);
        final visualTarget = _currentMeldDragTarget;
        final visualSnap = _meldDragSnap;
        if (visualTarget == null || !visualTarget.hitRect.contains(rawCenter)) {
          _resolveMeldDragTarget(data, details.globalPosition);
          final fingerTarget = _currentMeldDragTarget;
          if (fingerTarget == null ||
              !fingerTarget.faceRect
                  .inflate(4)
                  .contains(details.globalPosition)) {
            _currentMeldDragTarget = visualTarget;
            _meldDragSnap = visualSnap;
          } else {
            placementCenter = details.globalPosition;
          }
        }
      }
      final tileCenter = renderObject.globalToLocal(
        placementCenter + _meldDragSnap,
      );
      // The magnifier and release share the placement coordinate.
      _lastRackDragGlobalPosition = placementCenter;
      final inside =
          tileCenter.dx >= 0 &&
          tileCenter.dy >= 0 &&
          tileCenter.dx <= renderObject.size.width &&
          tileCenter.dy <= renderObject.size.height;
      if (_gameSettings.gridMagnifier && _draggingProcessableTile && inside) {
        const positionStep = 6.0;
        localPosition = Offset(
          (tileCenter.dx / positionStep).round() * positionStep,
          (tileCenter.dy / positionStep).round() * positionStep,
        );
      }
    }
    _lastRackDragGlobalPosition ??= details.globalPosition;
    final steppedTilt = (tilt / 0.0125).round() * 0.0125;
    _scheduleDragVisualFrame(localPosition, steppedTilt, lift);
    _previewCrossRowMove(data, details.globalPosition);
    final rackLocation = _rackDropLocation(details.globalPosition);
    if (rackLocation != null &&
        rackLocation.slot ~/ _rackRowLength !=
            data.sourceSlot ~/ _rackRowLength) {
      return;
    }
    _resolveRackEdgeOverlap(
      data,
      _draggingProcessableTile
          ? details.globalPosition
          : _lastRackDragGlobalPosition!,
      details.delta.dx,
    );
  }

  void _resolveRackEdgeOverlap(
    _RackDragData data,
    Offset center,
    double deltaX,
  ) {
    if (deltaX.abs() < 0.1) return;
    final source = _rackDragSourceRect;
    if (source == null) return;
    for (final rowStart in [0, _rackRowLength]) {
      final first = _rackDragRowRects[rowStart ~/ _rackRowLength];
      if (first == null || center.dy < first.top || center.dy > first.bottom) {
        continue;
      }
      final localX = center.dx - first.left;
      if (localX < 0 || localX >= first.width * _rackRowLength) return;
      final fraction = (localX / first.width) % 1;
      // Keep the narrow between-tile seam available for insertion.
      if (fraction <= 0.08 || fraction >= 0.92) return;
      final dragged = Rect.fromCenter(
        center: center,
        width: source.width - 1.2,
        height: source.height,
      );
      final towardRight = deltaX > 0;
      for (var index = rowStart; index < rowStart + _rackRowLength; index++) {
        if (_rackSlots[index] == null || _rackSlots[index] == data.tileId) {
          continue;
        }
        final target = first.shift(Offset((index - rowStart) * first.width, 0));
        if (towardRight
            ? target.center.dx <= center.dx
            : target.center.dx >= center.dx) {
          continue;
        }
        if (dragged.intersect(target).width < dragged.width * 0.05) continue;
        final previewSlots = List<int?>.from(_rackSlots)
          ..[data.sourceSlot] = null;
        final vacancy = _rackPushVacancy(
          previewSlots,
          data.sourceSlot,
          index,
          towardRight: towardRight,
        );
        if (vacancy < 0) continue;
        _rackPushPreview.value = _RackPushPreview(
          tileId: data.tileId,
          sourceSlot: data.sourceSlot,
          targetSlot: index,
          vacancySlot: vacancy,
          kind: towardRight ? _RackMoveKind.pushRight : _RackMoveKind.pushLeft,
        );
        return;
      }
      return;
    }
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
    // Yüksek yenileme hızlarında da parmağı akıcı biçimde izle. Önceki 66 ms sınırı
    // sürüklenen taşın kademe kademe sıçrıyormuş gibi görünmesine yol açıyordu.
    if (nowMicros - _lastDragVisualUpdateMicros < 8000) return;
    _lastDragVisualUpdateMicros = nowMicros;
    if (_dragVisualFrameScheduled) return;
    _dragVisualFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _dragVisualFrameScheduled = false;
      if (!mounted) return;
      final current = _rackDragVisual.value;
      if (current.gridPosition != _pendingGridDragPosition ||
          current.globalGridPosition !=
              (_lastRackDragGlobalPosition == null
                  ? null
                  : _lastRackDragGlobalPosition! + _meldDragSnap) ||
          current.target?.index != _currentMeldDragTarget?.index ||
          current.snapOffset != _meldDragSnap ||
          current.tilt != _pendingRackDragTilt ||
          current.lift != _pendingRackDragLift) {
        _rackDragVisual.value = _RackDragVisualState(
          gridPosition: _pendingGridDragPosition,
          globalGridPosition: _lastRackDragGlobalPosition == null
              ? null
              : _lastRackDragGlobalPosition! + _meldDragSnap,
          target: _currentMeldDragTarget,
          snapOffset: _meldDragSnap,
          dragData: _activeRackDragData,
          tiles: _activeRackDragData == null
              ? const []
              : identical(_dragPlanData, _activeRackDragData)
              ? _dragPlanTiles!
              : _tilesForDrag(_activeRackDragData!),
          color: _activeRackDragData?.tile.displayColor ?? OC.okeyGold,
          tilt: _pendingRackDragTilt,
          lift: _pendingRackDragLift,
        );
      }
    });
  }

  ({int slot, double fraction, bool nearEdge})? _rackDropLocation(
    Offset pointer,
  ) {
    ({int slot, double fraction, bool nearEdge})? best;
    var bestDistance = double.infinity;
    for (final rowStart in [0, _rackRowLength]) {
      final first = _rackDragRowRects[rowStart ~/ _rackRowLength];
      if (first == null) continue;
      final row = Rect.fromLTWH(
        first.left,
        first.top,
        first.width * _rackRowLength,
        first.height,
      );
      final tolerance = min(22.0, first.height * 0.30);
      if (!Rect.fromLTRB(
        row.left - first.width * .25,
        row.top - tolerance,
        row.right + first.width * .25,
        row.bottom + tolerance,
      ).contains(pointer)) {
        continue;
      }
      final distance = (pointer.dy - row.center.dy).abs();
      if (distance >= bestDistance) continue;
      final cell = ((pointer.dx - first.left) / first.width).clamp(
        0.0,
        _rackRowLength - .001,
      );
      best = (
        slot: rowStart + cell.floor(),
        fraction: cell % 1,
        nearEdge: !row.contains(pointer),
      );
      bestDistance = distance;
    }
    return best;
  }

  bool _allowsMeldDropNearRack(int meldIndex, _RackDragData data) {
    if (!data.liftedForMeld) return true;
    final pointer = _lastRackDragPointerPosition;
    final upperRow = _rackDragRowRects.isEmpty ? null : _rackDragRowRects.first;
    if (pointer == null || upperRow == null) return false;
    final edgeTolerance = min(22.0, upperRow.height * .30);
    if (pointer.dy < upperRow.top - edgeTolerance) return true;
    // Only the upper edge of the rack may overlap a lifted grid tile.
    if (pointer.dy > upperRow.top + min(22.0, upperRow.height * .30)) {
      return false;
    }
    final meld = _tableMetds[meldIndex];
    final target = _gameRectForKey(
      context,
      ValueKey('${meld.type == 'cift' ? 'pair' : 'run'}-meld-$meldIndex'),
      transformed: true,
    );
    if (target == null) return false;
    final visualCenter = pointer.translate(0, -_meldDragPlacementLift);
    final tolerance = min(10.0, upperRow.width * .20);
    final cellWidth = target.width / max(1, meld.tiles.length);
    final expanded = Rect.fromLTRB(
      target.left - cellWidth * 3,
      target.top - target.height * .65,
      target.right + cellWidth * 3,
      target.bottom + target.height * .65,
    );
    return expanded.contains(visualCenter) &&
        pointer.dy - target.bottom <= _meldDragLift + tolerance;
  }

  void _previewCrossRowMove(_RackDragData data, Offset pointer) {
    final location = _rackDropLocation(pointer);
    final current = _rackPushPreview.value;
    if (location == null ||
        location.slot ~/ _rackRowLength == data.sourceSlot ~/ _rackRowLength) {
      if (current != null &&
          current.targetSlot ~/ _rackRowLength !=
              data.sourceSlot ~/ _rackRowLength) {
        _rackPushPreview.value = null;
      }
      return;
    }
    final slots = List<int?>.from(_rackSlots)..[data.sourceSlot] = null;
    final vacancy = _nearestRackVacancy(slots, location.slot);
    final kind = vacancy < 0 ? _RackMoveKind.swap : _RackMoveKind.insert;
    if (current?.targetSlot == location.slot &&
        current?.kind == kind &&
        current?.vacancySlot == vacancy) {
      return;
    }
    _rackPushPreview.value = _RackPushPreview(
      tileId: data.tileId,
      sourceSlot: data.sourceSlot,
      targetSlot: location.slot,
      vacancySlot: vacancy,
      kind: kind,
    );
  }

  // Rack moves follow the finger; processing melds follows the raised tile.
  bool _dropRackTileAtPointer(_RackDragData data) {
    final pointer = _lastRackDragPointerPosition;
    if (pointer == null || _rackSlots[data.sourceSlot] != data.tileId) {
      return false;
    }
    final location = _rackDropLocation(pointer);
    if (location == null) return false;
    final target = location.slot;
    final crossRow =
        target ~/ _rackRowLength != data.sourceSlot ~/ _rackRowLength;
    if (!crossRow && !data.liftedForMeld && !location.nearEdge) return false;
    if (crossRow) {
      final slots = List<int?>.from(_rackSlots)..[data.sourceSlot] = null;
      _reorderRack(
        data.tileId,
        target,
        _nearestRackVacancy(slots, target) < 0
            ? _RackMoveKind.swap
            : _RackMoveKind.insert,
      );
    } else if (_rackSlots[target] == null) {
      _reorderRack(data.tileId, target, _RackMoveKind.insert);
    } else {
      final preview = _rackPushPreview.value;
      final fraction = location.fraction;
      if (preview?.tileId == data.tileId &&
          preview!.targetSlot ~/ _rackRowLength == target ~/ _rackRowLength) {
        _reorderRack(data.tileId, preview.targetSlot, preview.kind);
      } else if (fraction <= .08) {
        _reorderRack(data.tileId, target, _RackMoveKind.insert);
      } else if (fraction >= .92 &&
          target % _rackRowLength + 1 < _rackRowLength) {
        _reorderRack(data.tileId, target + 1, _RackMoveKind.insert);
      } else if (fraction <= .30 || fraction >= .70) {
        _reorderRack(
          data.tileId,
          target,
          fraction <= .30 ? _RackMoveKind.pushRight : _RackMoveKind.pushLeft,
        );
      }
    }
    return true;
  }

  void _endGridDragZoom() {
    final dragData = _activeRackDragData;
    final discardBox = _playerDiscardTargetKey.currentContext
        ?.findRenderObject();
    final pointer = _lastRackDragPointerPosition;
    if (!_manualMeldDropHandled &&
        dragData != null &&
        pointer != null &&
        discardBox is RenderBox &&
        discardBox.hasSize &&
        (discardBox.localToGlobal(Offset.zero) & discardBox.size).contains(
          pointer,
        )) {
      _dropToDiscard(dragData);
    }
    if (!_manualMeldDropHandled &&
        dragData != null &&
        _currentMeldDragTarget != null) {
      _dropOnMeld(_currentMeldDragTarget!.index, dragData);
    }
    final droppedOnRack =
        !_manualMeldDropHandled &&
        dragData != null &&
        _dropRackTileAtPointer(dragData);
    if (_isTutorialGame &&
        _tutorialStep == 3 &&
        !_manualMeldDropHandled &&
        !droppedOnRack &&
        dragData != null &&
        dragData.tileId == _tutorialProcessTileId) {
      _msg_(
        'Kırmızı 7’yi parlayan kırmızı 4–5–6 perinin üzerine veya sonuna bırak.',
      );
    }
    final edgePreview = _rackPushPreview.value;
    if (!_manualMeldDropHandled &&
        !droppedOnRack &&
        dragData != null &&
        edgePreview?.tileId == dragData.tileId &&
        _rackSlots[dragData.sourceSlot] == dragData.tileId) {
      _reorderRack(dragData.tileId, edgePreview!.targetSlot, edgePreview.kind);
    }
    final globalPosition = _lastRackDragGlobalPosition;
    final discardRenderObject = _playerDiscardTargetKey.currentContext
        ?.findRenderObject();
    if (!_manualMeldDropHandled &&
        !droppedOnRack &&
        dragData != null &&
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
    _clearDragMeldPlan();
    _currentMeldDragTarget = null;
    _meldDragGeometry = const [];
    _meldDragSnap = Offset.zero;
    _lastRackDragGlobalPosition = null;
    _lastRackDragPointerPosition = null;
    _pendingGridDragPosition = null;
    _pendingRackDragTilt = 0;
    _pendingRackDragLift = 0;
    _rackDragVisual.value = const _RackDragVisualState();
    _rackPushPreview.value = null;
  }

  bool _canDropOnMeld(int meldIndex, _RackDragData data) {
    if (!_playerOpened || _turn != 0 || !_drawnThisTurn) return false;
    return _meldColumnForDrag(meldIndex, data) != null;
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
    if (candidates.length != 1) return -1;
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
    if (_isTutorialGame) {
      _msg_('Bu eğitimde yalnız gösterilen seri açma adımlarını kullan.');
      return;
    }
    final tiles = _tilesForDrag(data);
    final replacementTarget = _pairReplacementTarget(tiles);
    if (replacementTarget >= 0) {
      _tryAddToMeld(
        replacementTarget,
        tiles.map((tile) => tile.id).toSet(),
        animateMotion: false,
      );
      return;
    }
    if (!_canLayTilesInPairArea(tiles)) return;
    final ids = tiles.map((tile) => tile.id).toSet();
    _openPairs(ids, detectedPairs: _pairGroups(ids), animateMotion: false);
  }

  void _enterAddMode() {
    if (!_tutorialStepRequired(
      3,
      'Önce elini açmak için soldaki SERİ AÇ düğmesine bas.',
    )) {
      return;
    }
    if (_isTutorialGame) {
      _msg_('Kırmızı 7 taşını tutup masadaki kırmızı 4-5-6 perine sürükle.');
      return;
    }
    if (_turn != 0 || _botBusy) {
      _warn_('Sıra sende değil; rakibin hamlesini bekle.');
      return;
    }
    if (!_playerOpened) {
      _warn_('Önce kendi perlerini aç, sonra masaya işle.');
      return;
    }
    if (!_drawnThisTurn) {
      _warn_('Önce desteden veya soldan bir taş çek.');
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
    final processingTileIds = _rack.map((tile) => tile.id).toSet();
    var processed = 0;
    final processedTiles = <Tile>[];
    Alignment? processMotionTarget;
    setState(() {
      while (_rack.isNotEmpty) {
        Tile? tileToProcess;
        var targetMeldIndex = -1;
        final orderedTiles = _rackSlots
            .map(_rackTileById)
            .whereType<Tile>()
            .where((tile) => processingTileIds.contains(tile.id))
            .where((tile) => !limitToSelection || selectedIds.contains(tile.id))
            .toList();
        for (final tile in orderedTiles) {
          targetMeldIndex = _automaticTargetMeldIndex(tile);
          // Okey değişimi taş sayısını azaltmaz: son taş da yerine konup
          // geri gelen okey son atış için ıstakada bırakılabilir.
          if (targetMeldIndex >= 0 &&
              _rack.length == 1 &&
              Rules.okeyReplacementIndex(_tableMetds[targetMeldIndex], tile) ==
                  null) {
            targetMeldIndex = -1;
          }
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
      _finishTutorialStep(3);
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
    if (_isTutorialGame) {
      _msg_('Öğretici hamleleri geri alınamaz. Gösterilen adıma devam et.');
      return;
    }
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

  void _showProcessedTileHighlight(List<Tile> tiles, {bool botMove = false}) {
    if (!_useGameplayAnimations || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final serial = ++_processedHighlightSerial;
    _processedHighlightTimer?.cancel();
    _processedTileHighlight.value = _ProcessedTileHighlight(
      serial,
      tiles.map((tile) => tile.id).toSet(),
      duration: Duration(milliseconds: botMove ? 1400 : 650),
      color: botMove ? OC.goldLight : null,
    );
    _processedHighlightTimer = Timer(
      Duration(milliseconds: botMove ? 1450 : 700),
      () {
        if (mounted && _processedTileHighlight.value?.serial == serial) {
          _processedTileHighlight.value = null;
        }
      },
    );
  }

  void _tryAddToMeld(
    int meldIdx,
    Set<int> tileIds, {
    bool animateMotion = true,
  }) {
    final selected = _rack.where((tile) => tileIds.contains(tile.id)).toList();
    if (selected.isEmpty) {
      setState(() => _uiMode = 'normal');
      return;
    }
    final meld = _tableMetds[meldIdx];
    final swappedOkey =
        selected.length == 1 &&
        Rules.okeyReplacementIndex(meld, selected.single) != null;
    if (selected.length >= _rack.length && !swappedOkey) {
      _warn_('Açarken veya işlerken, son atış için elinde 1 taş bırak.');
      setState(() => _uiMode = 'normal');
      return;
    }

    if (!_meldCanUseTiles(meld, selected)) {
      _warn_('Taşlar bu pere uymuyor; sayı ve renk sırasını kontrol et.');
      setState(() => _uiMode = 'normal');
      return;
    }
    Tile? returningOkey;
    Rect? returningOkeySource;
    if (!animateMotion && swappedOkey) {
      returningOkey =
          meld.tiles[Rules.okeyReplacementIndex(meld, selected.single)!];
      returningOkeySource = _gameRectForKey(
        context,
        ValueKey('table-visible-tile-${returningOkey.id}'),
        transformed: true,
      );
    }
    setState(() {
      _placeTilesIntoMeld(meldIdx, selected);
      _uiMode = 'normal';
      // A dropped tile already travelled with the pointer. Only button/tap
      // processing needs an additional rack-to-table flight.
      if (animateMotion) {
        _beginTableTileMotion(
          _TableTileMotionKind.process,
          selected,
          targetAlignment: _motionTargetForMeld(meld),
        );
      }
    });
    if (!animateMotion) {
      _playInteractionFeedback(sound: _GameSound.place, placement: true);
      _showProcessedTileHighlight(selected);
      if (returningOkey != null &&
          returningOkeySource != null &&
          !MediaQuery.disableAnimationsOf(context)) {
        _beginTableTileMotion(
          _TableTileMotionKind.drawDiscard,
          [returningOkey],
          sourceRectsOverride: {returningOkey.id: returningOkeySource},
        );
      }
    }
    _msg_(
      swappedOkey
          ? 'Taş yerine işlendi, okey ıstakana alındı.'
          : '${selected.length} taş pere işlendi.',
    );
  }

  void _dropOnMeld(int meldIndex, _RackDragData data) {
    if (_manualMeldDropHandled) return;
    final chosen = _currentMeldDragTarget;
    final position = _lastRackDragGlobalPosition;
    if (data.liftedForMeld) {
      if (chosen == null ||
          position == null ||
          !chosen.hitRect.contains(position)) {
        return;
      }
      meldIndex = chosen.index;
    }
    if (!_allowsMeldDropNearRack(meldIndex, data)) return;
    final tutorialDragIds = data.tileIds.isEmpty
        ? <int>{data.tileId}
        : data.tileIds;
    if (_isTutorialGame &&
        (_tutorialStep != 3 ||
            tutorialDragIds.length != 1 ||
            data.tileId != _tutorialProcessTileId ||
            meldIndex < 0 ||
            meldIndex >= _tableMetds.length ||
            !_tableMetds[meldIndex].tiles.any(
              (tile) => tile.color == TileColor.red && tile.number == 6,
            ))) {
      _msg_('Yalnız kırmızı 7 taşını kırmızı 4-5-6 perine sürükle.');
      return;
    }
    if (!_playerOpened) {
      _msg_('Başka bir pere işlemeden önce elini açmalısın.');
      return;
    }
    if (_turn != 0 || !_drawnThisTurn) {
      _msg_('Taş işlemek için sıra sende olmalı ve taş çekmelisin.');
      return;
    }
    final ids = _tilesForDrag(data).map((tile) => tile.id).toSet();
    final rackLengthBefore = _rack.length;
    _tryAddToMeld(meldIndex, ids, animateMotion: false);
    if (ids.any((id) => !_rack.any((tile) => tile.id == id))) {
      _manualMeldDropHandled = true;
      if (_rack.length < rackLengthBefore) _finishTutorialStep(3);
    }
  }

  void _dropToDiscard(_RackDragData data) {
    if (_gameOverShown) return;
    // The discard target is authoritative even when the raised tile still
    // overlaps the rack's generous reorder hit area.
    if (_isTutorialGame &&
        (_tutorialStep != 4 || data.tileId != _tutorialFinishTileId)) {
      _msg_('Son olarak çektiğin sarı 13 taşını ortaya bırak.');
      return;
    }
    final index = _rack.indexWhere((tile) => tile.id == data.tileId);
    if (index == -1) return;
    setState(() {
      for (final tile in _rack) {
        tile.selected = tile.id == data.tileId;
      }
    });
    _discardTile(tutorialDrag: true);
    if (!_rack.any((tile) => tile.id == data.tileId)) {
      _manualMeldDropHandled = true;
    }
  }

  void _finishByCenterDrop(_RackDragData data) {
    if (_isTutorialGame &&
        (_tutorialStep != 4 || data.tileId != _tutorialFinishTileId)) {
      _msg_('Son olarak çektiğin sarı 13 taşını ortaya bırak.');
      return;
    }
    if (_turn != 0 || !_drawnThisTurn || _rack.length != 1) return;
    if (_rack.single.id != data.tileId || data.tileIds.length != 1) return;
    setState(() => _rack.single.selected = true);
    _discardTile(tutorialDrag: true);
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
    final pairs = RackSolver.pairs(_rack, allowIndicator: !_playerOpened);
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
    if (!_tutorialStepRequired(1, 'Önce ortadaki kapalı desteden taş çek.')) {
      return;
    }
    if (_isTutorialGame) {
      _msg_('Sarı 3 taşını tutup sarı 1-2 taşlarının yanına sürükle.');
      return;
    }
    setState(() => _showRackPairCount = false);
    final groups = RackSolver.standardMelds(_rack);
    if (groups.isEmpty) {
      _layoutRackGroups(const []);
      _warn_('Seri dizmek için en az 3 uyumlu taş gerekiyor.');
      return;
    }
    _layoutRackGroups(groups);
    _playInteractionFeedback(sound: _GameSound.arrange);
    _finishTutorialStep(1);
  }

  void _arrangePairs() {
    if (_isTutorialGame) {
      _msg_('Bu eğitim elinde SERİ DİZ düğmesini kullan.');
      return;
    }
    final pairs = RackSolver.pairs(_rack, allowIndicator: !_playerOpened);
    setState(() => _showRackPairCount = true);
    if (pairs.isEmpty) {
      _layoutRackGroups(const []);
      _warn_('Çift dizmek için aynı sayı ve renkte iki taş gerekiyor.');
      return;
    }
    _layoutRackGroups(pairs);
    _playInteractionFeedback(sound: _GameSound.arrange);
  }

  void _autoOpenStandardMelds() {
    if (!_tutorialStepRequired(
      2,
      'Önce vurgulanan sarı 3 taşını sarı 1 ve 2 taşlarının yanına sürükle.',
    )) {
      return;
    }
    final allIds = _rack.map((tile) => tile.id).toSet();
    final groups = RackSolver.standardMeldsFromLayout(_rackGroups(allIds));
    if (groups.isEmpty) {
      _msg_('Istakada boşluklarla ayırdığın geçerli bir per bulunamadı.');
      return;
    }
    final ids = groups.expand((group) => group).map((tile) => tile.id).toSet();
    _openStandardMelds(ids, detectedGroups: groups);
  }

  bool get _canAutoOpenStandardMelds {
    if (_isTutorialGame && _tutorialStep != 2) return false;
    if (_playerOpened && _playerOpenType == 'cift') return false;
    final groups = RackSolver.standardMeldsFromLayout(
      _rackGroups(_rack.map((tile) => tile.id).toSet()),
    );
    final ids = groups.expand((group) => group).map((tile) => tile.id).toSet();
    if (groups.isEmpty || ids.length >= _rack.length) return false;
    if (_tookDiscard &&
        _takenDiscardTile != null &&
        !ids.contains(_takenDiscardTile!.id)) {
      return false;
    }
    final score = _isColorBonusMode
        ? Rules.coloredOpeningValue(groups, _roundBonusColor)
        : Rules.validMeldTotal(groups);
    return _playerOpened || score >= _minimumStandardOpeningScore;
  }

  bool get _canAutoOpenPairs {
    if (_isTutorialGame) return false;
    final pairs = RackSolver.pairsFromLayout(
      _rackGroups(_rack.map((tile) => tile.id).toSet()),
      allowIndicator: !_playerOpened,
    );
    return pairs.isNotEmpty &&
        _canLayTilesInPairArea(pairs.expand((pair) => pair));
  }

  void _autoOpenPairs() {
    if (_isTutorialGame) {
      _msg_('Bu eğitim elinde SERİ AÇ düğmesini kullan.');
      return;
    }
    final allIds = _rack.map((tile) => tile.id).toSet();
    final pairs = RackSolver.pairsFromLayout(
      _rackGroups(allIds),
      allowIndicator: !_playerOpened,
    );
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
      if (computation.result.openedType != null) {
        _announceOpening(
          playerProgress.playerName,
          computation.result.openedType!,
        );
      }
      setState(() {
        final openedType = computation.result.openedType;
        final openingValue = computation.result.openingValue;
        if (openedType != null && openingValue != null) {
          _openedThisPlayerTurn = true;
          _recordProgressiveOpening(openedType, openingValue);
        }
        _rack = computation.bot.hand;
        _processedInEarlierTurns =
            _processedInEarlierTurns ||
            computation.result.processedTileCount > 0;
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
        _endRoundPlayerWins(finishedWithProcessing: _processedInEarlierTurns);
      } else {
        _nextTurn();
      }
    });
  }

  void _nextTurn() {
    _hidePlayerTurnAttention();
    _cancelTimedPlayerTurn();
    final nextTurn = (_turn + 1) % 4;
    setState(() {
      _turn = nextTurn;
      _botBusy = nextTurn != 0;
      _botDiscardMotion = null;
      if (nextTurn == 0) {
        _drawnThisTurn = false;
        _openedThisPlayerTurn = false;
      }
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
          _beginPlayerTurn();
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
    _rememberResumeState(force: true);
    final roundGeneration = _roundGeneration;
    if (!alreadyMarkedBusy) setState(() => _botBusy = true);

    // Let the previous discard land, pause briefly, then show the draw.
    final botThinkTime =
        _instantBotTurns || !_useGameplayAnimations || alreadyHasExtraTile
        ? Duration.zero
        : _botDrawLeadIn;
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
      final isLeague =
          widget.launchConfig.entryPoint == GameEntryPoint.quickPlay;
      final earliestOpeningTurns = isLeague
          ? List.generate(
              3,
              (index) => LeagueBotStyle.forRival(
                (_bots[index].leagueId ?? index + 1) - 1,
              ).openingTurn,
            )
          : const [3, 4, 3];
      const standardOpeningTargets = [105, 110, 103];
      const pairOpeningTargets = [5, 6, 5];
      final minimumStandardScore = _isProgressiveMode
          ? _minimumStandardOpeningScore
          : isLeague
          ? 101
          : standardOpeningTargets[botIdx];
      final minimumPairCount = _isProgressiveMode
          ? _minimumPairOpeningCount
          : isLeague
          ? 5
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
              pairAreaLimit: _playerOpened ? 20 : 24,
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
      if (!alreadyHasExtraTile) {
        setState(() {
          if (canTakeDiscard) {
            drawnTile = _discarded!;
            _recordDiscardTaken(botIdx + 1, drawnTile!);
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
        });
      }

      final thinkingClock = Stopwatch()..start();
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
          pairAreaLimit: _playerOpened ? 20 : 24,
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
        void applyComputedTurn() {
          if (!mounted ||
              roundGeneration != _roundGeneration ||
              _gameOverShown ||
              _turn != botIdx + 1) {
            return;
          }
          result = computation.result;
          if (result.openedType != null) {
            _announceOpening(bot.displayName, result.openedType!);
          }
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
                if (nextTurn == 0) {
                  _drawnThisTurn = false;
                  _openedThisPlayerTurn = false;
                }
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
                    _beginPlayerTurn();
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
              Future.delayed(_botDiscardTravelDuration, finishTurn);
            } else {
              finishTurn();
            }
          }

          final tableMotionDelay =
              _useGameplayAnimations && movedToTable.isNotEmpty
              ? (result.openedMeldCount > 0
                        ? _botOpenTravelDuration
                        : _botProcessTravelDuration) +
                    const Duration(milliseconds: 50)
              : Duration.zero;
          if (tableMotionDelay == Duration.zero) {
            startDiscard();
          } else {
            _botThinkTimer = Timer(tableMotionDelay, () {
              _botThinkTimer = null;
              if (!mounted ||
                  roundGeneration != _roundGeneration ||
                  _gameOverShown ||
                  _turn != botIdx + 1) {
                return;
              }
              _showProcessedTileHighlight(movedToTable, botMove: true);
              startDiscard();
            });
          }
        }

        final thinkingTime = _instantBotTurns
            ? const Duration(milliseconds: 25)
            : botTurnThinkingTime(
                openedMeldCount: computation.result.openedMeldCount,
                processedTileCount: computation.result.processedTileCount,
                variation: Random().nextInt(101),
              );
        final remaining = thinkingTime - thinkingClock.elapsed;
        if (remaining > Duration.zero) {
          _botThinkTimer = Timer(remaining, () {
            _botThinkTimer = null;
            applyComputedTurn();
          });
        } else {
          applyComputedTurn();
        }
      }

      if (kIsWeb && _useGameplayAnimations && !alreadyHasExtraTile) {
        // Let the draw land before browser AI shares the UI thread.
        _botThinkTimer = Timer(_botDrawTravelDuration, () {
          _botThinkTimer = null;
          playAndDiscard();
        });
      } else {
        playAndDiscard();
      }
    });
  }

  Future<List<int>> _prepareLeagueTables(
    LeagueRoundTables tables,
    int generation,
  ) async {
    await dailyLeague.load();
    if (dailyLeague.complete) return [];
    if (kIsWeb) {
      // Let the scene entrance and rack deal paint before starting browser AI.
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    }
    return playLeagueTables(
      seed: DateTime.now().microsecondsSinceEpoch,
      seating: tables.seating,
      isActive: () =>
          tables.humanCompleted || (mounted && generation == _roundGeneration),
      shouldPause: () =>
          !tables.humanCompleted &&
          (_dealInProgress ||
              _settingsPanelOpen.value ||
              _activeRackDragData != null ||
              _tableTileMotion.value != null),
    );
  }

  Future<LeagueRoundUpdate?> _recordLeagueRound(
    LeagueRoundTables tables,
    String roundId,
    List<int> tablePenalties,
  ) async {
    final penalties = await tables.scores;
    if (penalties.length != 16) return null;
    final counted = await dailyLeague.recordRound(
      config: widget.launchConfig,
      roundId: roundId,
      tablePenalties: tablePenalties,
      simulatedPenalties: penalties,
      participantIds: tables.seating.participantIds,
    );
    return counted
        ? dailyLeague.lastRoundUpdate
        : LeagueRoundUpdate(
            roundId: roundId,
            rank: dailyLeague.playerRank,
            counted: false,
          );
  }

  // ── El Bitti: Oyuncu Kazandı ──────────────────────────────────────────
  void _endRoundPlayerWins({
    bool? finishedFromHand,
    bool finishedWithProcessing = false,
  }) {
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
    _showEndDialog(
      winner: 'Oyuncu 1',
      playerPen: -101,
      botPens: botPenList,
      finishedFromHand: finishedFromHand ?? _openedThisPlayerTurn,
      finishedWithProcessing: finishedWithProcessing,
    );
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
    bool afterCelebration = false,
    bool? finishedFromHand,
    bool finishedWithProcessing = false,
    GameReward? recordedReward,
  }) {
    if (!mounted) return;
    _hidePlayerTurnAttention();
    final playerWon = winner == 'Oyuncu 1' || winner == 'Sen';
    if (recordedReward == null &&
        widget.launchConfig.entryPoint == GameEntryPoint.quickPlay) {
      // Result totals belong to this game session. League totals also include
      // earlier sessions and the rival's games at other tables.
      _resultPlayerPenalty =
          (_resultPlayerPenalty ?? 0) +
          _totalPenalty -
          _roundPlayerPenaltyStart;
      final totals = _resultBotPenalties ??= <int, int>{};
      for (var index = 0; index < _bots.length; index++) {
        final id = _bots[index].leagueId ?? -(index + 1);
        totals[id] = (totals[id] ?? 0) + botPens[index];
      }
    }
    if (!afterCelebration &&
        recordedReward == null &&
        _resumeLeagueEligible &&
        widget.launchConfig.entryPoint == GameEntryPoint.quickPlay) {
      final roundId = '$_leagueSessionId/$_roundGeneration';
      var tables = _leagueRoundTables;
      if (tables == null && !dailyLeague.complete) {
        tables = LeagueRoundTables(
          seating: LeagueSeating.forRound(dailyLeague.completedRounds),
        );
        _leagueRoundTables = tables;
        tables.scores = _prepareLeagueTables(tables, _roundGeneration);
      }
      if (tables != null) {
        tables.humanCompleted = true;
        _leagueRoundUpdateFuture = _recordLeagueRound(tables, roundId, [
          _totalPenalty - _roundPlayerPenaltyStart,
          ...botPens,
        ]);
      } else {
        _leagueRoundUpdateFuture = Future.value(
          LeagueRoundUpdate(
            roundId: roundId,
            rank: dailyLeague.playerRank,
            counted: false,
          ),
        );
      }
    }
    final roundLimit = _hasThreeRoundLimit ? _roomAndModeRoundLimit : null;
    final matchComplete = roundLimit != null && _elCount >= roundLimit;
    bool? roomMatchWon;
    if (recordedReward == null &&
        matchComplete &&
        widget.launchConfig.entryPoint == GameEntryPoint.room &&
        !_roomMatchSettled) {
      _roomMatchSettled = true;
      roomMatchWon = _bots.indexed.every(
        (entry) => _totalPenalty <= entry.$2.penalty + botPens[entry.$1],
      );
    }
    if (recordedReward == null) {
      _pendingResume = null;
      _resumeSaveTimer?.cancel();
      if (!_isTutorialGame && !_isTournamentGame) unawaited(savedGame.clear());
      unawaited(
        dailyChallenge.recordRound(config: widget.launchConfig, won: playerWon),
      );
    }
    final reward =
        recordedReward ??
        playerProgress.recordCompletedGame(
          config: widget.launchConfig,
          won: playerWon,
          openedHand: _playerOpened,
          finishedHand: playerWon,
          roundNumber: _elCount,
          roomMatchWon: roomMatchWon,
        );
    if (recordedReward == null &&
        !matchComplete &&
        !_isTutorialGame &&
        !_isTournamentGame) {
      final checkpoint = _captureSavedGame();
      checkpoint['betweenRounds'] = true;
      final checkpointBots = checkpoint['bots'] as List;
      for (var index = 0; index < checkpointBots.length; index++) {
        checkpointBots[index]['penalty'] =
            _bots[index].penalty + botPens[index];
      }
      unawaited(savedGame.save(checkpoint));
    }
    final openingTurnFinish =
        playerWon && (finishedFromHand ?? _openedThisPlayerTurn);
    // Every completed player hand earns -101 and the confetti celebration.
    // Opening in this same turn only changes the celebration's caption.
    final spectacular = playerWon;
    if (!afterCelebration &&
        (_useGameplayAnimations || (spectacular && _gameSettings.animations)) &&
        !MediaQuery.disableAnimationsOf(context) &&
        !(_gameSettings.autoPlay && !matchComplete && !spectacular)) {
      final serial = ++_finishCelebrationSerial;
      final gridTiles = spectacular
          ? const <_GridFinishTile>[]
          : _captureGridFinishTiles(context);
      _finishHiddenTileIds.value = Set<int>.unmodifiable(
        gridTiles.map((entry) => entry.tile.id),
      );
      setState(() {
        _showFinishCelebration = true;
        _finishCelebrationSpectacular = spectacular;
        _finishCelebrationFromHand = openingTurnFinish;
        _finishCelebrationWithProcessing = finishedWithProcessing;
        _finishGridTiles = gridTiles;
        _botBusy = true;
        _onFinishCelebrationComplete = () {
          if (!mounted || serial != _finishCelebrationSerial) return;
          setState(() {
            _showFinishCelebration = false;
            _onFinishCelebrationComplete = null;
          });
          _showEndDialog(
            winner: winner,
            playerPen: playerPen,
            botPens: botPens,
            afterCelebration: true,
            finishedFromHand: openingTurnFinish,
            finishedWithProcessing: finishedWithProcessing,
            recordedReward: reward,
          );
        };
      });
      return;
    }

    if (_gameSettings.autoPlay && !matchComplete) {
      final completedRound = _roundGeneration;
      for (var i = 0; i < _bots.length; i++) {
        _bots[i].penalty += botPens[i];
      }
      Future.delayed(const Duration(milliseconds: 900), () async {
        await _leagueRoundUpdateFuture;
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
        bots: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
            ? [
                for (var index = 0; index < _bots.length; index++)
                  BotPlayer(
                    name: _bots[index].name,
                    displayName: _bots[index].displayName,
                    leagueId: _bots[index].leagueId,
                    penalty:
                        (_resultBotPenalties?[_bots[index].leagueId ??
                                -(index + 1)] ??
                            botPens[index]) -
                        botPens[index],
                  ),
              ]
            : _bots,
        botPens: botPens,
        elCount: _elCount,
        maxRounds: roundLimit,
        matchComplete: matchComplete,
        totalPenalty: widget.launchConfig.entryPoint == GameEntryPoint.quickPlay
            ? _resultPlayerPenalty ?? (_totalPenalty - _roundPlayerPenaltyStart)
            : _totalPenalty,
        reward: reward,
        leagueUpdate: _leagueRoundUpdateFuture,
        homeLabel: _isTournamentGame
            ? appText('TURNUVAYA DÖN', 'TOURNAMENT')
            : appText('ANA SAYFA', 'HOME'),
        onNewRound: () async {
          if (_startingNextRound) return;
          _startingNextRound = true;
          await _leagueRoundUpdateFuture;
          _startingNextRound = false;
          if (!mounted) return;
          Navigator.pop(context);
          setState(() {
            for (var i = 0; i < _bots.length; i++) {
              _bots[i].penalty += botPens[i];
            }
            _startNewRound();
          });
        },
        onResetMatch: () {
          _restartGameFromToolbar(closeResult: true);
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
    final processableTileIds = _processableTileIds;
    final centerNotice =
        _warningMsg ??
        _msg ??
        (_uiMode == 'addMeld' ? 'İşlemek istediğin perdeye dokun' : null);

    return _TileMotionScope(
      motion: _tableTileMotion,
      finishHiddenTileIds: _finishHiddenTileIds,
      processedHighlight: _processedTileHighlight,
      drawAttentionTileId: _drawAttentionTileId,
      drawAttentionSerial: _drawAttentionSerial,
      dragVisual: _rackDragVisual,
      child: Scaffold(
        backgroundColor: const Color(0xFF071B14),
        body: Listener(
          onPointerDown: (_) {
            if (_drawAttentionTileId != null) {
              setState(() => _drawAttentionTileId = null);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _clearRackSelection,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: MediaQuery.textScalerOf(context)),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final sceneWidth = viewport.maxWidth;
                    final sceneHeight = viewport.maxHeight;
                    final edgeInset = sceneWidth * 0.012;
                    final actionPanelWidth = sceneWidth * 0.115;
                    final controlGap = max(3.0, sceneWidth * 0.003);
                    // Keep the rack proportional on 4:3 tablets and tall windows.
                    final rackHeight = min(
                      sceneHeight * 0.29,
                      sceneWidth * 0.18,
                    );
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
                      min(
                        ((rackContentWidth - 4) *
                                    (1 -
                                        2 *
                                            storeCosmetics
                                                .rackHorizontalInset)) /
                                _rackRowLength -
                            1.6,
                        max(1.0, (rackHeight - 6) / 2) / 1.58,
                      ),
                    );
                    final rackVisualTileHeight = rackVisualTileWidth * 1.58;
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
                                      cacheWidth: _backgroundDecodeWidth(
                                        context,
                                      ),
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.low,
                                    ),
                            ),
                          ),
                          SettingsSceneActivity(
                            panelOpen: _settingsPanelOpen,
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
                                          eligibleMeldIndexes:
                                              eligibleMeldIndexes,
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
                                              !_playerOpened &&
                                                  _showRackPairCount
                                              ? _rackPairCount
                                              : null,
                                          canDraw: myTurn && !_drawnThisTurn,
                                          onDraw: _drawFromDeck,
                                          canFinishByCenterDrop:
                                              canAct && _rack.length == 1,
                                          onFinishByCenterDrop:
                                              _finishByCenterDrop,
                                          dragTileWidth: rackVisualTileWidth,
                                          dragTileHeight: rackVisualTileHeight,
                                          showGrid: _gameSettings.showGrid,
                                          showBots: _gameSettings.showBots,
                                        ),
                                      ),
                                    ),

                                    if (_isColorBonusMode &&
                                        _showColorBonusIntro)
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
                                            if (!mounted ||
                                                !_showColorBonusIntro) {
                                              return;
                                            }
                                            setState(
                                              () =>
                                                  _showColorBonusIntro = false,
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
                                      key: const ValueKey('game-rack-controls'),
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
                                                    buttonKey: const ValueKey(
                                                      'tutorial-open-button',
                                                    ),
                                                    label: appText(
                                                      'SERİ AÇ',
                                                      'OPEN MELD',
                                                      german: 'SATZ ÖFFNEN',
                                                    ),
                                                    active:
                                                        canAct &&
                                                        _canAutoOpenStandardMelds,
                                                    color: const Color(
                                                      0xFF19862B,
                                                    ),
                                                    onTap:
                                                        _autoOpenStandardMelds,
                                                  ),
                                                  _RackAction(
                                                    buttonKey: const ValueKey(
                                                      'open-pairs-button',
                                                    ),
                                                    label: appText(
                                                      'ÇİFT AÇ',
                                                      'OPEN PAIRS',
                                                      german: 'PAARE ÖFFNEN',
                                                    ),
                                                    active:
                                                        canAct &&
                                                        _canAutoOpenPairs,
                                                    color: const Color(
                                                      0xFF9A650E,
                                                    ),
                                                    onTap: _autoOpenPairs,
                                                  ),
                                                  _RackAction(
                                                    label: appText(
                                                      'İŞLE',
                                                      'ADD',
                                                      german: 'ANLEGEN',
                                                    ),
                                                    active: !_dealInProgress,
                                                    color: const Color(
                                                      0xFF08658F,
                                                    ),
                                                    onTap: _enterAddMode,
                                                    secondaryLabel:
                                                        _processedMoves
                                                            .isNotEmpty
                                                        ? appText(
                                                            'GERİ AL',
                                                            'UNDO',
                                                            german:
                                                                'RÜCKGÄNGIG',
                                                          )
                                                        : null,
                                                    secondaryActive:
                                                        !_dealInProgress &&
                                                        _processedMoves
                                                            .isNotEmpty,
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
                                                        key: const ValueKey(
                                                          'game-rack-area',
                                                        ),
                                                        turnAttention:
                                                            _playerTurnAttention,
                                                        rack: _rack,
                                                        slots: _rackSlots,
                                                        dealAnimationSerial:
                                                            _useGameplayAnimations
                                                            ? _dealAnimationSerial
                                                            : null,
                                                        onTileTap: _tapTile,
                                                        onReorder: _reorderRack,
                                                        shiftSerial:
                                                            _rackShiftSerial,
                                                        shiftOrigins:
                                                            _rackShiftLayoutSignature ==
                                                                _rackSlots.join(
                                                                  ',',
                                                                )
                                                            ? _rackShiftOrigins
                                                            : const {},
                                                        onTileDragStart:
                                                            _startGridDragZoom,
                                                        onTileDragUpdate:
                                                            _updateGridDragZoom,
                                                        onTileDragEnd:
                                                            _endGridDragZoom,
                                                        dragVisual:
                                                            _rackDragVisual,
                                                        pushPreview:
                                                            _rackPushPreview,
                                                        processableTileIds:
                                                            processableTileIds,
                                                        tutorialTileId:
                                                            _isTutorialGame &&
                                                                _tutorialStep ==
                                                                    1
                                                            ? _tutorialArrangeTileId
                                                            : null,
                                                        processableColor:
                                                            _playerOpened
                                                            ? OC.numGreen
                                                            : OC.numRed,
                                                        minimumStandardOpeningScore:
                                                            _isProgressiveMode
                                                            ? _minimumStandardOpeningScore
                                                            : null,
                                                        minimumPairOpeningCount:
                                                            _isProgressiveMode
                                                            ? _minimumPairOpeningCount
                                                            : null,
                                                        canAcceptDeckDrop:
                                                            myTurn &&
                                                            !_drawnThisTurn,
                                                        canAcceptDiscardDrop:
                                                            myTurn &&
                                                            !_drawnThisTurn &&
                                                            _discarded != null,
                                                        onDeckDropAt:
                                                            _drawFromDeck,
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
                                                    label: appText(
                                                      'SERİ DİZ',
                                                      'SORT MELDS',
                                                      german: 'SÄTZE SORTIEREN',
                                                    ),
                                                    active:
                                                        !_dealInProgress &&
                                                        _rack.length >= 3,
                                                    color: const Color(
                                                      0xFF19862B,
                                                    ),
                                                    onTap:
                                                        _arrangeStandardMelds,
                                                  ),
                                                  _RackAction(
                                                    label: appText(
                                                      'ÇİFT DİZ',
                                                      'SORT PAIRS',
                                                      german: 'PAARE SORTIEREN',
                                                    ),
                                                    active:
                                                        !_dealInProgress &&
                                                        _rack.length >= 2,
                                                    color: const Color(
                                                      0xFF9A650E,
                                                    ),
                                                    onTap: _arrangePairs,
                                                  ),
                                                  _RackAction(
                                                    label: _drawnThisTurn
                                                        ? appText(
                                                            'TAŞ AT',
                                                            'DISCARD',
                                                            german: 'ABLEGEN',
                                                          )
                                                        : appText(
                                                            'TAŞ ÇEK',
                                                            'DRAW',
                                                            german: 'ZIEHEN',
                                                          ),
                                                    active: _drawnThisTurn
                                                        ? canAct && sel == 1
                                                        : myTurn &&
                                                              _deck.isNotEmpty,
                                                    color: const Color(
                                                      0xFF08658F,
                                                    ),
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
                            child: _TopBar(onPressed: _openGameSettings),
                          ),

                          Positioned(
                            top: 0,
                            left: 0,
                            child: _TopBar(
                              onPressed: _openGameHelp,
                              help: true,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 58,
                            right: 70,
                            height: 24,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 13,
                                  child: _isProgressiveMode
                                      ? const SizedBox.shrink()
                                      : _GridTopCaption(
                                          key: const ValueKey(
                                            'opening-rule-caption',
                                          ),
                                          text: appText(
                                            'EL AÇMA: 101 PER • 5 ÇİFT',
                                            'OPEN: 101 MELD • 5 PAIRS',
                                            german:
                                                'ÖFFNEN: 101 SATZ • 5 PAARE',
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                ),
                                const Expanded(
                                  flex: 8,
                                  child: SizedBox.shrink(),
                                ),
                                Expanded(
                                  flex: 13,
                                  child: _GridTopCaption(
                                    key: const ValueKey('game-mode-caption'),
                                    text:
                                        _isColorBonusMode &&
                                            _showColorBonusIntro
                                        ? ''
                                        : _tableModeLabel.toUpperCase(),
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 2,
                            left: 48,
                            right: 60,
                            child: Center(
                              child: _PlayerInfo(
                                showAvatar: _gameSettings.showBots,
                                bot: _bots[1],
                                fakeOkeyValue: Rules.okeyNumberForIndicator(
                                  _indicator?.number ?? 1,
                                ),
                                active: _turn == 2,
                                horizontal: true,
                              ),
                            ),
                          ),
                          // Sıra bildirimi çift gridine yakın, çekme alanının üstünde kalır.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: const Alignment(0, -.20),
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _playerTurnAttention,
                                  builder: (context, active, _) => active
                                      ? const RepaintBoundary(
                                          child: _PlayerTurnBadge(),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: const Alignment(0, -0.48),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child:
                                      _leagueRankNotice == null ||
                                          _gameOverShown
                                      ? const SizedBox.shrink()
                                      : LeagueRankPopup(
                                          notice: _leagueRankNotice!,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          if (centerNotice != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: const Alignment(0, -0.25),
                                  child: RepaintBoundary(
                                    child:
                                        _openingMessage &&
                                            _warningMsg == null &&
                                            _msg != null
                                        ? _GameOpeningNotice(text: centerNotice)
                                        : _GameCenterNotice(text: centerNotice),
                                  ),
                                ),
                              ),
                            ),

                          Positioned.fill(
                            child: ValueListenableBuilder<_TableTileMotion?>(
                              valueListenable: _tableTileMotion,
                              builder: (context, motion, _) =>
                                  motion == null || motion.playerIndex != 0
                                  ? const SizedBox.shrink()
                                  : _FlyingPlayerTiles(motion: motion),
                            ),
                          ),
                          if (_showFinishCelebration)
                            Positioned.fill(
                              child: _FinishCelebration(
                                tutorial: _isTutorialGame,
                                spectacular: _finishCelebrationSpectacular,
                                finishedFromHand: _finishCelebrationFromHand,
                                finishedWithProcessing:
                                    _finishCelebrationWithProcessing,
                                gridTiles: _finishGridTiles,
                                onComplete: _onFinishCelebrationComplete,
                              ),
                            ),

                          if (_isTutorialGame && !_showFinishCelebration)
                            InGameTutorialOverlay(
                              step: _tutorialStep,
                              finishSourceSlot: _tutorialFinishSlot,
                              onExit: () => Navigator.of(context).pop(false),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
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

class _GameOpeningNotice extends StatelessWidget {
  final String text;
  const _GameOpeningNotice({required this.text});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('game-opening-popup-$text'),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
    child: Container(
      key: const ValueKey('game-opening-popup'),
      constraints: BoxConstraints(
        maxWidth: min(620, MediaQuery.sizeOf(context).width - 36),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          child: Text(
            text,
            maxLines: 3,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: MediaQuery.sizeOf(context).width < 420 ? 15 : 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

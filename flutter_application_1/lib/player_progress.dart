import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';
import 'app_language.dart';

const defaultPlayerProfileName = 'Evren';
const initialPlayerCoins = 25600;
const playerAvatarAssets = <String>[
  'görseller/pp/01_tilki.png',
  'görseller/pp/02_kurt.png',
  'görseller/pp/03_aslan.png',
  'görseller/pp/04_kaplan.png',
  'görseller/pp/05_ayi.png',
  'görseller/pp/06_panda.png',
  'görseller/pp/07_tavsan.png',
  'görseller/pp/08_rakun.png',
  'görseller/pp/09_baykus.png',
  'görseller/pp/10_kartal.png',
  'görseller/pp/11_timsah.png',
  'görseller/pp/12_kopekbaligi.png',
  'görseller/pp/13_goril.png',
  'görseller/pp/14_keci.png',
  'görseller/pp/15_koc.png',
  'görseller/pp/16_fil.png',
  'görseller/pp/17_zurafa.png',
  'görseller/pp/18_suaygiri.png',
  'görseller/pp/19_penguen.png',
  'görseller/pp/20_ejderha.png',
  'görseller/pp/mm_av0_tavuk.png',
  'görseller/pp/mm_av1_boga.png',
  'görseller/pp/mm_av2_domuz.png',
  'görseller/pp/mm_av3_yaban_domuzu.png',
];

String rivalAvatarAsset(int rivalIndex) =>
    playerAvatarAssets[(rivalIndex + 1) % playerAvatarAssets.length];

class LevelBand {
  final int minLevel;
  final int maxLevel;
  final String title;

  const LevelBand(this.minLevel, this.maxLevel, this.title);

  bool contains(int level) => level >= minLevel && level <= maxLevel;

  String localizedTitle(AppLanguage language) {
    final (tr, de) = switch (title) {
      'Beginner' => ('Başlangıç', 'Anfänger'),
      'Rookie' => ('Çaylak', 'Neuling'),
      'Learner' => ('Öğrenen', 'Lernender'),
      'Novice' => ('Acemi', 'Einsteiger'),
      'Trainee' => ('Aday', 'Anwärter'),
      'Initiate' => ('Yeni Yetenek', 'Nachwuchstalent'),
      'Apprentice' => ('Çırak', 'Lehrling'),
      'Graduate' => ('Deneyimli', 'Erfahrener'),
      'Aficionado' => ('Oyun Tutkunu', 'Spielbegeisterter'),
      'Talented' => ('Yetenekli', 'Talentierter'),
      'Skilled' => ('Becerikli', 'Versierter'),
      'Pro' => ('Profesyonel', 'Profi'),
      'Specialist' => ('Uzman', 'Spezialist'),
      'All-Star' => ('Yıldız', 'Star'),
      'Superstar' => ('Süper Yıldız', 'Superstar'),
      'Genius' => ('Dahi', 'Genie'),
      'Master' => ('Usta', 'Meister'),
      'Maestro' => ('Üstat', 'Maestro'),
      'Expert' => ('Üst Düzey Uzman', 'Experte'),
      'Champion' => ('Şampiyon', 'Champion'),
      'Grandmaster' => ('Büyük Usta', 'Großmeister'),
      _ => (title, title),
    };
    return localizedText(language, tr, title, german: de);
  }
}

const levelBands = <LevelBand>[
  LevelBand(0, 2, 'Beginner'),
  LevelBand(3, 4, 'Rookie'),
  LevelBand(5, 9, 'Learner'),
  LevelBand(10, 14, 'Novice'),
  LevelBand(15, 19, 'Trainee'),
  LevelBand(20, 24, 'Initiate'),
  LevelBand(25, 29, 'Apprentice'),
  LevelBand(30, 34, 'Graduate'),
  LevelBand(35, 39, 'Aficionado'),
  LevelBand(40, 44, 'Talented'),
  LevelBand(45, 49, 'Skilled'),
  LevelBand(50, 54, 'Pro'),
  LevelBand(55, 59, 'Specialist'),
  LevelBand(60, 64, 'All-Star'),
  LevelBand(65, 69, 'Superstar'),
  LevelBand(70, 74, 'Genius'),
  LevelBand(75, 79, 'Master'),
  LevelBand(80, 84, 'Maestro'),
  LevelBand(85, 89, 'Expert'),
  LevelBand(90, 94, 'Champion'),
  LevelBand(95, 99, 'Grandmaster'),
];

class GameReward {
  final int xp;
  final int coins;
  final int levelsGained;
  final List<String> xpBreakdown;

  const GameReward({
    required this.xp,
    required this.coins,
    required this.levelsGained,
    required this.xpBreakdown,
  });
}

class PlayerProgressController extends ChangeNotifier {
  static const _playerNameKey = 'profile.player_name';
  static const _playerAvatarKey = 'profile.avatar_index';
  static const _playerAvatarAssetKey = 'profile.avatar_asset';
  static const _coinsKey = 'progress.coins';
  static const _levelKey = 'progress.level';
  static const _levelXpKey = 'progress.level_xp';
  static const _gamesPlayedKey = 'progress.games_played';
  static const _gamesWonKey = 'progress.games_won';
  static const _handsOpenedKey = 'progress.hands_opened';
  static const _highestOpeningKey = 'progress.highest_opening';
  static const _handsFinishedKey = 'progress.hands_finished';
  static const _totalXpKey = 'progress.total_xp';
  static const _economyV2MigrationKey = 'progress.economy_v2';
  static const _walletKey = 'progress.wallet_v1';

  SharedPreferencesAsync? _preferences;

  int _coins = initialPlayerCoins;
  int _leagueStars = 0;
  final List<String> _leagueAwards = [];
  Future<void> _walletWrites = Future.value();
  int _level = 0;
  int _levelXp = 0;
  int _gamesPlayed = 0;
  int _gamesWon = 0;
  int _handsOpened = 0;
  int _highestOpening = 0;
  int _handsFinished = 0;
  int _totalXpEarned = 0;
  String _playerName = defaultPlayerProfileName;
  int _playerAvatarIndex = 0;
  String? _selectedAvatarAsset;

  int get coins => _coins;
  int get leagueStars => _leagueStars;
  int get level => _level;
  int get levelXp => _levelXp;
  int get gamesPlayed => _gamesPlayed;
  int get gamesWon => _gamesWon;
  int get handsOpened => _handsOpened;
  int get highestOpening => _highestOpening;
  int get handsFinished => _handsFinished;
  int get totalXpEarned => _totalXpEarned;
  String get playerName => _playerName;
  int get playerAvatarIndex => playerAvatarAssets.indexOf(playerAvatarAsset);
  String get playerAvatarAsset {
    final asset =
        _selectedAvatarAsset ?? _legacyAvatarAsset(_playerAvatarIndex);
    return playerAvatarAssets.contains(asset)
        ? asset
        : playerAvatarAssets.first;
  }

  static String _legacyAvatarAsset(int index) {
    final migrated = switch (index) {
      >= 0 && < 20 => index,
      21 => 20,
      23 => 21,
      25 => 22,
      27 => 23,
      _ => 0,
    };
    return playerAvatarAssets[migrated];
  }

  bool get isMaxLevel => _level >= 99;

  LevelBand get levelBand => levelBands.firstWhere(
    (band) => band.contains(_level),
    orElse: () => levelBands.last,
  );

  String get title => levelBand.title;
  int get xpForNextLevel => isMaxLevel ? 0 : xpRequiredForLevel(_level);
  double get levelProgress =>
      isMaxLevel ? 1 : (_levelXp / xpForNextLevel).clamp(0.0, 1.0);
  double get winRate => _gamesPlayed == 0 ? 0 : _gamesWon / _gamesPlayed;

  bool canAfford(int amount) => amount >= 0 && _coins >= amount;

  Future<void> load() async {
    final preferences = _preferences ??= SharedPreferencesAsync();

    _coins = (await preferences.getInt(_coinsKey) ?? initialPlayerCoins).clamp(
      0,
      1 << 31,
    );
    final wallet = await preferences.getString(_walletKey);
    if (wallet != null) {
      try {
        final data = jsonDecode(wallet) as Map<String, dynamic>;
        _coins = (data['coins'] as int).clamp(0, 1 << 31);
        _leagueStars = (data['leagueStars'] as int).clamp(0, 1 << 31);
        _leagueAwards
          ..clear()
          ..addAll((data['leagueAwards'] as List).cast<String>());
      } catch (_) {}
    }
    _level = (await preferences.getInt(_levelKey) ?? _level).clamp(0, 99);
    _levelXp = (await preferences.getInt(_levelXpKey) ?? _levelXp).clamp(
      0,
      1 << 31,
    );
    _gamesPlayed = (await preferences.getInt(_gamesPlayedKey) ?? _gamesPlayed)
        .clamp(0, 1 << 31);
    _gamesWon = (await preferences.getInt(_gamesWonKey) ?? _gamesWon).clamp(
      0,
      _gamesPlayed,
    );
    _handsOpened = (await preferences.getInt(_handsOpenedKey) ?? _handsOpened)
        .clamp(0, 1 << 31);
    _highestOpening = (await preferences.getInt(_highestOpeningKey) ?? 0).clamp(
      0,
      1 << 31,
    );
    _handsFinished =
        (await preferences.getInt(_handsFinishedKey) ?? _handsFinished).clamp(
          0,
          1 << 31,
        );
    _totalXpEarned = (await preferences.getInt(_totalXpKey) ?? _totalXpEarned)
        .clamp(0, 1 << 31);
    if (await preferences.getBool(_economyV2MigrationKey) != true) {
      final untouchedLegacyProfile =
          _coins == 100000 &&
          _level == 0 &&
          _levelXp == 0 &&
          _gamesPlayed == 0 &&
          _totalXpEarned == 0;
      if (untouchedLegacyProfile) {
        _coins = initialPlayerCoins;
        await preferences.setInt(_coinsKey, _coins);
      }
      await preferences.setBool(_economyV2MigrationKey, true);
    }
    final savedPlayerName = (await preferences.getString(_playerNameKey))
        ?.trim();
    if (savedPlayerName != null && savedPlayerName.isNotEmpty) {
      _playerName = savedPlayerName;
    }
    final savedAvatar = await preferences.getString(_playerAvatarAssetKey);
    final savedIndex = await preferences.getInt(_playerAvatarKey) ?? 0;
    final requestedAsset = savedAvatar ?? _legacyAvatarAsset(savedIndex);
    _selectedAvatarAsset = playerAvatarAssets.contains(requestedAsset)
        ? requestedAsset
        : playerAvatarAssets.first;
    _playerAvatarIndex = playerAvatarIndex;

    // Eski geliştirme sürümünde boş profiller seviye 9 ile başlıyordu.
    if (_level == 9 &&
        _levelXp == 0 &&
        _gamesPlayed == 0 &&
        _totalXpEarned == 0) {
      _level = 0;
    }

    while (!isMaxLevel && _levelXp >= xpForNextLevel) {
      _levelXp -= xpForNextLevel;
      _level++;
    }
    if (isMaxLevel) _levelXp = 0;
    notifyListeners();
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await _persistWallet();
    await preferences.setInt(_coinsKey, _coins);
    await preferences.setInt(_levelKey, _level);
    await preferences.setInt(_levelXpKey, _levelXp);
    await preferences.setInt(_gamesPlayedKey, _gamesPlayed);
    await preferences.setInt(_gamesWonKey, _gamesWon);
    await preferences.setInt(_handsOpenedKey, _handsOpened);
    await preferences.setInt(_highestOpeningKey, _highestOpening);
    await preferences.setInt(_handsFinishedKey, _handsFinished);
    await preferences.setInt(_totalXpKey, _totalXpEarned);
    await preferences.setString(_playerNameKey, _playerName);
    await preferences.setInt(_playerAvatarKey, playerAvatarIndex);
    await preferences.setString(_playerAvatarAssetKey, playerAvatarAsset);
  }

  void _schedulePersist() => unawaited(_persist());

  void recordOpening(int points) {
    if (points <= _highestOpening) return;
    _highestOpening = points;
    notifyListeners();
    _schedulePersist();
  }

  Future<void> _persistWallet() {
    final preferences = _preferences;
    if (preferences == null) return Future.value();
    final snapshot = jsonEncode({
      'coins': _coins,
      'leagueStars': _leagueStars,
      'leagueAwards': _leagueAwards,
    });
    final write = _walletWrites.then(
      (_) => preferences.setString(_walletKey, snapshot),
    );
    _walletWrites = write.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return write;
  }

  Future<void> grantLeagueReward({
    required String id,
    required int coins,
    required int stars,
  }) async {
    if (_leagueAwards.contains(id)) {
      // A previous attempt may have credited memory before storage failed.
      await _persistWallet();
      return;
    }
    _leagueAwards.add(id);
    _coins += coins.clamp(0, 1 << 30);
    _leagueStars += stars.clamp(0, 1 << 30);
    notifyListeners();
    // Award token, currency and stars are saved together in one wallet record.
    await _persistWallet();
    _schedulePersist();
  }

  bool updatePlayerName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 18) return false;
    if (_playerName == normalized) return true;
    _playerName = normalized;
    notifyListeners();
    _schedulePersist();
    return true;
  }

  void updatePlayerAvatar(int index) {
    final safeIndex = index.clamp(0, playerAvatarAssets.length - 1);
    if (playerAvatarIndex == safeIndex) return;
    _playerAvatarIndex = safeIndex;
    _selectedAvatarAsset = playerAvatarAssets[safeIndex];
    notifyListeners();
    _schedulePersist();
  }

  bool trySpendCoins(int amount) {
    if (!canAfford(amount)) return false;
    _coins -= amount;
    notifyListeners();
    _schedulePersist();
    return true;
  }

  void refundCoins(int amount) {
    if (amount <= 0) return;
    _coins += amount;
    notifyListeners();
    _schedulePersist();
  }

  GameReward grantDailyReward({required int coins, required int xp}) {
    final safeCoins = coins.clamp(0, 1 << 30);
    final safeXp = xp.clamp(0, 1 << 30);
    final oldLevel = _level;
    _coins += safeCoins;
    _levelXp += safeXp;
    _totalXpEarned += safeXp;
    while (!isMaxLevel && _levelXp >= xpForNextLevel) {
      _levelXp -= xpForNextLevel;
      _level++;
    }
    if (isMaxLevel) _levelXp = 0;
    notifyListeners();
    _schedulePersist();
    return GameReward(
      xp: safeXp,
      coins: safeCoins,
      levelsGained: _level - oldLevel,
      xpBreakdown: safeXp == 0 ? const [] : [appDailyRewardBreakdown(safeXp)],
    );
  }

  GameReward recordCompletedGame({
    required GameLaunchConfig config,
    required bool won,
    required bool openedHand,
    required bool finishedHand,
    int roundNumber = 1,
    bool? roomMatchWon,
  }) {
    assert(roundNumber >= 1);
    final breakdown = <String>[];
    final baseXp = switch (config.entryPoint) {
      GameEntryPoint.quickPlay => 30,
      GameEntryPoint.gameMode => 30,
      GameEntryPoint.room => 35,
      GameEntryPoint.tournament => 50,
      GameEntryPoint.tutorial => 0,
    };
    var earnedXp = baseXp;
    breakdown.add('Oyun tamamlama +$baseXp XP');

    // Hemen Oyna bilinçli olarak yalnız sabit tamamlama XP'si verir.
    if (config.entryPoint != GameEntryPoint.quickPlay &&
        config.entryPoint != GameEntryPoint.tutorial) {
      if (won) {
        final bonus = config.isTournament ? 50 : 30;
        earnedXp += bonus;
        breakdown.add('Galibiyet +$bonus XP');
      }
      if (openedHand) {
        final bonus = config.isTournament ? 20 : 15;
        earnedXp += bonus;
        breakdown.add('El açma +$bonus XP');
      }
      if (finishedHand) {
        final bonus = config.isTournament ? 30 : 20;
        earnedXp += bonus;
        breakdown.add('Eli bitirme +$bonus XP');
      }
    }

    final baseCoinReward = config.entryPoint == GameEntryPoint.room
        ? (roomMatchWon == true ? (config.entryFee ?? 0) * 2 : 0)
        : won
        ? switch (config.entryPoint) {
            GameEntryPoint.quickPlay => 150,
            GameEntryPoint.gameMode => 300,
            GameEntryPoint.room => 0,
            GameEntryPoint.tournament =>
              1000 * ((config.tournamentRound ?? 0) + 1),
            GameEntryPoint.tutorial => 0,
          }
        : 0;
    final coinReward = baseCoinReward;

    final oldLevel = _level;
    _levelXp += earnedXp;
    _totalXpEarned += earnedXp;
    while (!isMaxLevel && _levelXp >= xpForNextLevel) {
      _levelXp -= xpForNextLevel;
      _level++;
    }
    if (isMaxLevel) _levelXp = 0;
    _coins += coinReward;
    _gamesPlayed++;
    if (won) _gamesWon++;
    if (openedHand) _handsOpened++;
    if (finishedHand) _handsFinished++;
    notifyListeners();
    _schedulePersist();

    return GameReward(
      xp: earnedXp,
      coins: coinReward,
      levelsGained: _level - oldLevel,
      xpBreakdown: List.unmodifiable(breakdown),
    );
  }

  @visibleForTesting
  void reset({int coins = initialPlayerCoins, int level = 0, int levelXp = 0}) {
    _coins = coins;
    _leagueStars = 0;
    _leagueAwards.clear();
    _level = level.clamp(0, 99);
    _levelXp = levelXp;
    _gamesPlayed = 0;
    _gamesWon = 0;
    _handsOpened = 0;
    _highestOpening = 0;
    _handsFinished = 0;
    _totalXpEarned = 0;
    _playerName = defaultPlayerProfileName;
    _playerAvatarIndex = 0;
    _selectedAvatarAsset = playerAvatarAssets.first;
    notifyListeners();
  }
}

final playerProgress = PlayerProgressController();

/// XP eşiği unvandan bağımsız olarak doğrudan sayısal seviyeye göre büyür.
/// Seviye 2'de 30 XP, seviye 3'e gelindiğinde 50 XP gerekir.
int xpRequiredForLevel(int level) {
  if (level <= 3) return 30;
  if (level <= 7) return 50;
  if (level <= 12) return 75;
  if (level <= 19) return 100;
  if (level <= 29) return 130;
  if (level <= 44) return 170;
  if (level <= 59) return 220;
  if (level <= 74) return 280;
  if (level <= 89) return 350;
  return 450;
}

String appDailyRewardBreakdown(int xp) => 'Günlük giriş +$xp XP';

String formatGameNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

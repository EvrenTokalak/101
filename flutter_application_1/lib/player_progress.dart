import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';

class LevelBand {
  final int minLevel;
  final int maxLevel;
  final String title;
  final int xpPerLevel;

  const LevelBand(this.minLevel, this.maxLevel, this.title, this.xpPerLevel);

  bool contains(int level) => level >= minLevel && level <= maxLevel;
}

const levelBands = <LevelBand>[
  LevelBand(0, 2, 'Beginner', 30),
  LevelBand(3, 4, 'Rookie', 30),
  LevelBand(5, 9, 'Learner', 50),
  LevelBand(10, 14, 'Novice', 50),
  LevelBand(15, 19, 'Trainee', 50),
  LevelBand(20, 24, 'Initiate', 50),
  LevelBand(25, 29, 'Apprentice', 50),
  LevelBand(30, 34, 'Graduate', 50),
  LevelBand(35, 39, 'Aficionado', 50),
  LevelBand(40, 44, 'Talented', 50),
  LevelBand(45, 49, 'Skilled', 50),
  LevelBand(50, 54, 'Pro', 100),
  LevelBand(55, 59, 'Specialist', 100),
  LevelBand(60, 64, 'All-Star', 100),
  LevelBand(65, 69, 'Superstar', 100),
  LevelBand(70, 74, 'Genius', 100),
  LevelBand(75, 79, 'Master', 100),
  LevelBand(80, 84, 'Maestro', 100),
  LevelBand(85, 89, 'Expert', 100),
  LevelBand(90, 94, 'Champion', 100),
  LevelBand(95, 99, 'Grandmaster', 150),
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
  static const _coinsKey = 'progress.coins';
  static const _levelKey = 'progress.level';
  static const _levelXpKey = 'progress.level_xp';
  static const _gamesPlayedKey = 'progress.games_played';
  static const _gamesWonKey = 'progress.games_won';
  static const _handsOpenedKey = 'progress.hands_opened';
  static const _handsFinishedKey = 'progress.hands_finished';
  static const _totalXpKey = 'progress.total_xp';

  SharedPreferencesAsync? _preferences;

  int _coins = 25600;
  int _level = 0;
  int _levelXp = 0;
  int _gamesPlayed = 0;
  int _gamesWon = 0;
  int _handsOpened = 0;
  int _handsFinished = 0;
  int _totalXpEarned = 0;

  int get coins => _coins;
  int get level => _level;
  int get levelXp => _levelXp;
  int get gamesPlayed => _gamesPlayed;
  int get gamesWon => _gamesWon;
  int get handsOpened => _handsOpened;
  int get handsFinished => _handsFinished;
  int get totalXpEarned => _totalXpEarned;
  bool get isMaxLevel => _level >= 99;

  LevelBand get levelBand => levelBands.firstWhere(
    (band) => band.contains(_level),
    orElse: () => levelBands.last,
  );

  String get title => levelBand.title;
  int get xpForNextLevel => isMaxLevel ? 0 : levelBand.xpPerLevel;
  double get levelProgress =>
      isMaxLevel ? 1 : (_levelXp / xpForNextLevel).clamp(0.0, 1.0);
  double get winRate => _gamesPlayed == 0 ? 0 : _gamesWon / _gamesPlayed;

  bool canAfford(int amount) => amount >= 0 && _coins >= amount;

  Future<void> load() async {
    final preferences = _preferences ??= SharedPreferencesAsync();

    _coins = (await preferences.getInt(_coinsKey) ?? _coins).clamp(0, 1 << 31);
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
    _handsFinished =
        (await preferences.getInt(_handsFinishedKey) ?? _handsFinished).clamp(
          0,
          1 << 31,
        );
    _totalXpEarned = (await preferences.getInt(_totalXpKey) ?? _totalXpEarned)
        .clamp(0, 1 << 31);

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
    await preferences.setInt(_coinsKey, _coins);
    await preferences.setInt(_levelKey, _level);
    await preferences.setInt(_levelXpKey, _levelXp);
    await preferences.setInt(_gamesPlayedKey, _gamesPlayed);
    await preferences.setInt(_gamesWonKey, _gamesWon);
    await preferences.setInt(_handsOpenedKey, _handsOpened);
    await preferences.setInt(_handsFinishedKey, _handsFinished);
    await preferences.setInt(_totalXpKey, _totalXpEarned);
  }

  void _schedulePersist() => unawaited(_persist());

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

  GameReward recordCompletedGame({
    required GameLaunchConfig config,
    required bool won,
    required bool openedHand,
    required bool finishedHand,
  }) {
    final breakdown = <String>[];
    final baseXp = switch (config.entryPoint) {
      GameEntryPoint.quickPlay => 30,
      GameEntryPoint.gameMode => 30,
      GameEntryPoint.room => 35,
      GameEntryPoint.tournament => 50,
    };
    var earnedXp = baseXp;
    breakdown.add('Oyun tamamlama +$baseXp XP');

    // Hemen Oyna bilinçli olarak yalnız sabit tamamlama XP'si verir.
    if (config.entryPoint != GameEntryPoint.quickPlay) {
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

    final coinReward = won
        ? switch (config.entryPoint) {
            GameEntryPoint.quickPlay => 150,
            GameEntryPoint.gameMode => 300,
            GameEntryPoint.room => (config.entryFee ?? 0) * 4,
            GameEntryPoint.tournament =>
              1000 * ((config.tournamentRound ?? 0) + 1),
          }
        : 0;

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
  void reset({int coins = 25600, int level = 0, int levelXp = 0}) {
    _coins = coins;
    _level = level.clamp(0, 99);
    _levelXp = levelXp;
    _gamesPlayed = 0;
    _gamesWon = 0;
    _handsOpened = 0;
    _handsFinished = 0;
    _totalXpEarned = 0;
    notifyListeners();
  }
}

final playerProgress = PlayerProgressController();

String formatGameNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

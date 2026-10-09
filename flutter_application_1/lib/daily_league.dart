import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';
import 'league_reminder.dart';
import 'player_progress.dart';

const leagueBotNames = [
  'Ayşe',
  'Mehmet',
  'Zeynep',
  'Ali',
  'Deniz',
  'Arda',
  'Can',
  'Kerem',
  'Ece',
  'Mert',
  'Selin',
  'Burak',
  'Derya',
  'Ozan',
  'Elif',
  'Emre',
  'Cem',
  'Aslı',
  'Eren',
];
const leagueRoundLimit = 20;
const leagueTierNames = ['Beginner', 'Amateur', 'Skilled', 'Pro', 'Master'];
const leagueTierThresholds = [0, 5, 15, 30, 50];

class LeagueEntry {
  final int id;
  final String name;
  final int penalty;
  final int rank;
  const LeagueEntry(this.id, this.name, this.penalty, this.rank);
  bool get isPlayer => id == 0;
  String get avatar => isPlayer
      ? playerProgress.playerAvatarAsset
      : playerAvatarAssets[1 + (id - 1) % 3];
}

class LeaguePrize {
  final int coins;
  final int stars;
  const LeaguePrize(this.coins, this.stars);
  static LeaguePrize forRank(int rank) => switch (rank) {
    1 => const LeaguePrize(3000, 3),
    2 => const LeaguePrize(2000, 2),
    3 => const LeaguePrize(1000, 1),
    _ => const LeaguePrize(0, 0),
  };
}

class DailyLeagueController extends ChangeNotifier {
  DailyLeagueController({
    DateTime Function()? now,
    PlayerProgressController? wallet,
    SharedPreferencesAsync? preferences,
    this.reminder,
  }) : _now = now ?? DateTime.now,
       _wallet = wallet ?? playerProgress,
       _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'league.daily_v1';
  static const cycleDuration = Duration(hours: 24);
  final DateTime Function() _now;
  final PlayerProgressController _wallet;
  final SharedPreferencesAsync _preferences;
  final LeagueReminder? reminder;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  DateTime? _deadline;
  List<int> _totals = List.filled(20, 0);
  List<String> _roundIds = [];
  int? _finalRank;
  bool _notificationsEnabled = true;

  bool get initialized => _deadline != null;
  DateTime? get deadline => _deadline;
  int get completedRounds => _roundIds.length;
  bool get complete => completedRounds == leagueRoundLimit;
  int? get finalRank => _finalRank;
  int get stars => _wallet.leagueStars;
  int get tierIndex => leagueTierThresholds.lastIndexWhere((n) => stars >= n);
  String get tier => leagueTierNames[tierIndex];
  int? get nextTierStars => tierIndex == leagueTierNames.length - 1
      ? null
      : leagueTierThresholds[tierIndex + 1];
  String get cycleId => (_deadline?.millisecondsSinceEpoch ?? 0).toString();
  String get settlementId => 'league-$cycleId';
  LeaguePrize get finalPrize => LeaguePrize.forRank(_finalRank ?? 20);
  int get playerRank =>
      _finalRank ?? standings.firstWhere((e) => e.isPlayer).rank;

  List<LeagueEntry> get standings {
    final ids = List.generate(20, (i) => i)
      ..sort((a, b) {
        final byPenalty = _totals[a].compareTo(_totals[b]);
        return byPenalty != 0 ? byPenalty : a.compareTo(b);
      });
    return [
      for (final id in ids)
        LeagueEntry(
          id,
          id == 0 ? _wallet.playerName : leagueBotNames[id - 1],
          _totals[id],
          1 + _totals.where((score) => score < _totals[id]).length,
        ),
    ];
  }

  Duration get remaining {
    final duration = _deadline?.difference(_now()) ?? cycleDuration;
    return duration.isNegative ? Duration.zero : duration;
  }

  String get remainingText {
    if (!initialized) return '--:--:--';
    final seconds = remaining.inSeconds.clamp(0, 86400);
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = (seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }

  Future<void> load() => _loading ??= _load();

  @visibleForTesting
  Future<void> resetForTesting() async {
    await _writes;
    _loading = null;
    _deadline = null;
    _totals = List.filled(20, 0);
    _roundIds = [];
    _finalRank = null;
  }

  Future<void> _load() async {
    final raw = await _read(() => _preferences.getString(storageKey));
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final totals = (data['totals'] as List).cast<int>();
        final ids = (data['roundIds'] as List).cast<String>();
        if (totals.length == 20 &&
            ids.length <= leagueRoundLimit &&
            ids.toSet().length == ids.length) {
          _deadline = DateTime.fromMillisecondsSinceEpoch(
            data['deadline'] as int,
          );
          _totals = totals;
          _roundIds = ids;
          _finalRank = complete ? data['finalRank'] as int? : null;
        }
      } catch (_) {
        // A damaged league save starts a fresh cycle; the wallet is independent.
      }
    }
    // Finish a pending award before resetting an expired, completed cycle.
    if (complete) {
      _finalRank ??= standings.firstWhere((e) => e.isPlayer).rank;
      await _grantPrize();
    }
    if (_deadline == null) {
      final taskDeadline = await _read(() => _preferences.getInt('tasks.deadline_ms'));
      _deadline = taskDeadline == null
          ? _now().add(cycleDuration)
          : DateTime.fromMillisecondsSinceEpoch(taskDeadline);
    }
    _rollover();
    await _persist();
    await _updateReminder();
    notifyListeners();
  }

  bool _rollover() {
    final previous = _deadline;
    if (previous == null || previous.isAfter(_now())) return false;
    final elapsed = _now().difference(previous).inMilliseconds;
    _deadline = previous.add(
      Duration(
        milliseconds:
            (elapsed ~/ cycleDuration.inMilliseconds + 1) *
            cycleDuration.inMilliseconds,
      ),
    );
    _totals = List.filled(20, 0);
    _roundIds = [];
    _finalRank = null;
    return true;
  }

  void refresh() {
    if (!initialized || !_rollover()) return;
    unawaited(_persist());
    unawaited(_updateReminder());
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    if (initialized) await _updateReminder();
  }

  Future<void> _updateReminder() async {
    final service = reminder;
    final end = _deadline;
    if (service == null || end == null) return;
    await service.update(
      deadline: end,
      enabled: _notificationsEnabled && !complete,
    );
  }

  /// Only completed quick-play rounds are accepted. Every entry advances once.
  Future<bool> recordRound({
    required GameLaunchConfig config,
    required String roundId,
    required List<int> tablePenalties,
    required List<int> simulatedPenalties,
  }) async {
    if (config.entryPoint != GameEntryPoint.quickPlay) return false;
    if (tablePenalties.length != 4 || simulatedPenalties.length != 16) {
      throw ArgumentError(
        'A league round needs 4 table and 16 simulated scores.',
      );
    }
    await load();
    refresh();
    if (complete || _roundIds.contains(roundId)) return false;
    final scores = [...tablePenalties, ...simulatedPenalties];
    for (var i = 0; i < 20; i++) {
      _totals[i] += scores[i];
    }
    _roundIds.add(roundId);
    if (complete) _finalRank = standings.firstWhere((e) => e.isPlayer).rank;
    final award = complete ? finalPrize : null;
    final awardId = settlementId;
    notifyListeners();
    // Save the result first. Wallet awards use the cycle ID for crash recovery.
    await _persist();
    if (award != null) {
      await _wallet.grantLeagueReward(
        id: awardId, coins: award.coins, stars: award.stars);
    }
    await _updateReminder();
    notifyListeners();
    return true;
  }

  Future<void> _grantPrize() async {
    final prize = finalPrize;
    await _wallet.grantLeagueReward(
      id: settlementId,
      coins: prize.coins,
      stars: prize.stars,
    );
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'deadline': _deadline!.millisecondsSinceEpoch,
      'totals': _totals,
      'roundIds': _roundIds,
      'finalRank': _finalRank,
    });
    final write = _writes.then((_) async {
      try {
        await _preferences.setString(storageKey, snapshot);
      } on MissingPluginException {
        // Unit/widget test runners have no device storage plugin.
      } on PlatformException {
        // Keep the current session usable if device storage is unavailable.
      }
    });
    _writes = write.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return write;
  }

  Future<T?> _read<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final dailyLeague = DailyLeagueController(reminder: leagueReminder);

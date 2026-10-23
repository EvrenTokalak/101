import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';
import 'player_progress.dart';

class ChallengeDefinition {
  final String title;
  final int target;
  final int coins;
  final OkeyGameMode? mode;
  final bool winsOnly;
  const ChallengeDefinition(
    this.title,
    this.target,
    this.coins, {
    this.mode,
    this.winsOnly = false,
  });
}

class DailyChallengeController extends ChangeNotifier {
  final PlayerProgressController progress;
  final DateTime Function() now;
  DailyChallengeController(this.progress, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  static const storageKey = 'challenge.daily_v1';
  static const definitions = [
    ChallengeDefinition(
      'Katlamalıda bir el kazan',
      1,
      500,
      mode: OkeyGameMode.progressive,
      winsOnly: true,
    ),
    ChallengeDefinition('İki el kazan', 2, 500, winsOnly: true),
    ChallengeDefinition('Üç el tamamla', 3, 350),
    ChallengeDefinition(
      'Renkli 101’de bir el tamamla',
      1,
      400,
      mode: OkeyGameMode.colorBonus101,
    ),
  ];
  String _day = '';
  int _current = 0;
  bool _claimed = false;
  Future<void>? _loading;
  Future<void>? _writes;
  bool _loaded = false;
  String get _today {
    final date = now();
    return '${date.year}-${date.month}-${date.day}';
  }

  ChallengeDefinition get definition {
    final date = now();
    return definitions[DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay %
        definitions.length];
  }

  int get current => _day == _today ? _current : 0;
  bool get claimed => _day == _today && _claimed;
  bool get canClaim => !claimed && current >= definition.target;
  Duration get remaining {
    final currentTime = now();
    return DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day + 1,
    ).difference(currentTime);
  }

  Future<void> load() => _loaded ? Future.value() : _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = await SharedPreferencesAsync().getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _day = data['day'] as String;
        _current = data['current'] as int;
        _claimed = data['claimed'] as bool;
      }
    } catch (_) {}
    _loaded = true;
    refresh();
  }

  void refresh() {
    if (_day != _today) {
      _day = _today;
      _current = 0;
      _claimed = false;
      unawaited(_persist());
    }
    notifyListeners();
  }

  Future<void> recordRound({
    required GameLaunchConfig config,
    required bool won,
  }) async {
    if (config.entryPoint == GameEntryPoint.tutorial) return;
    await load();
    refresh();
    final challenge = definition;
    if (_claimed ||
        (challenge.winsOnly && !won) ||
        (challenge.mode != null && config.mode != challenge.mode)) {
      return;
    }
    _current = (_current + 1).clamp(0, challenge.target);
    notifyListeners();
    await _persist();
  }

  Future<int> claim() async {
    await load();
    refresh();
    if (!canClaim) return 0;
    _claimed = true;
    final reward = definition.coins;
    progress.grantDailyReward(coins: reward, xp: 0);
    notifyListeners();
    await _persist();
    return reward;
  }

  Future<void> _persist() {
    final raw = jsonEncode({
      'day': _day,
      'current': _current,
      'claimed': _claimed,
    });
    Future<void> write() async {
      try {
        await SharedPreferencesAsync().setString(storageKey, raw);
      } catch (_) {}
    }

    final previous = _writes;
    final next = previous == null ? write() : previous.then((_) => write());
    _writes = next;
    unawaited(
      next.then((_) {
        if (identical(_writes, next)) _writes = null;
      }),
    );
    return next;
  }
}

final dailyChallenge = DailyChallengeController(playerProgress);

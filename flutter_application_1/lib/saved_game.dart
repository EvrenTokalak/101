import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';

class SavedGameController extends ChangeNotifier {
  static const storageKey = 'game.suspended_v1';
  Map<String, dynamic>? _snapshot;
  Future<void>? _loading;
  Future<void>? _writes;
  bool _loaded = false;
  String? _encodedSnapshot;
  int _revision = 0;
  Map<String, dynamic>? get snapshot => _snapshot;
  bool get hasGame => _snapshot != null;
  GameLaunchConfig? get config => _snapshot == null
      ? null
      : GameLaunchConfig.fromJson(_snapshot!['config'] as Map<String, dynamic>);

  static bool valid(Map<String, dynamic> value) {
    try {
      if (value['version'] != 1) return false;
      final config = GameLaunchConfig.fromJson(
        value['config'] as Map<String, dynamic>,
      );
      if (config.entryPoint == GameEntryPoint.tutorial ||
          config.entryPoint == GameEntryPoint.tournament) {
        return false;
      }
      final tiles = (value['tiles'] as List).cast<Map<String, dynamic>>();
      final ids = tiles.map((tile) => tile['id'] as int).toSet();
      if (ids.length != tiles.length || tiles.isEmpty || tiles.length > 160) {
        return false;
      }
      for (final tile in tiles) {
        if ((tile['number'] as int) < 1 ||
            (tile['number'] as int) > 13 ||
            (tile['color'] as int) < 0 ||
            (tile['color'] as int) > 3) {
          return false;
        }
      }
      final held = <int>[
        ...(value['deck'] as List).cast<int>(),
        ...(value['rack'] as List).cast<int>(),
        for (final bot in value['bots'] as List)
          ...(bot['hand'] as List).cast<int>(),
        for (final meld in value['melds'] as List)
          ...(meld['tiles'] as List).cast<int>(),
        for (final pile in value['discards'] as List)
          ...(pile as List).cast<int>(),
      ];
      if (held.any((id) => !ids.contains(id)) ||
          held.toSet().length != held.length) {
        return false;
      }
      if ((value['bots'] as List).length != 3 ||
          (value['discards'] as List).length != 4 ||
          (value['slots'] as List).length != 30) {
        return false;
      }
      final rack = (value['rack'] as List).cast<int>();
      final slots = (value['slots'] as List).whereType<int>().toList();
      if (slots.length != rack.length ||
          slots.toSet().length != slots.length ||
          !slots.toSet().containsAll(rack)) {
        return false;
      }
      if ((value['turn'] as int) < 0 ||
          (value['turn'] as int) > 3 ||
          (value['el'] as int) < 1) {
        return false;
      }
      for (final key in [
        'drawn',
        'tookDiscard',
        'opened',
        'openedThisTurn',
        'showPairs',
        'roomSettled',
      ]) {
        if (value[key] is! bool) return false;
      }
      for (final key in [
        'starting',
        'penalty',
        'penaltyStart',
        'minimumScore',
        'minimumPairs',
        'bonusColor',
        'roundGeneration',
      ]) {
        if (value[key] is! int) return false;
      }
      if ((value['starting'] as int) < 0 ||
          (value['starting'] as int) > 3 ||
          (value['bonusColor'] as int) < 0 ||
          (value['bonusColor'] as int) > 3 ||
          value['session'] is! String ||
          value['openType'] is! String ||
          value['processed'] is! List) {
        return false;
      }
      final order = (value['difficultyOrder'] as List).cast<String>();
      if (order.length != 3 ||
          order.toSet().length != 3 ||
          !order.every(
            (name) => BotDifficulty.values.any((level) => level.name == name),
          )) {
        return false;
      }
      if (value['indicator'] == null || !ids.contains(value['indicator'])) {
        return false;
      }
      for (final bot in value['bots'] as List) {
        if (bot['name'] is! String ||
            bot['display'] is! String ||
            bot['penalty'] is! int ||
            bot['opened'] is! bool ||
            bot['openType'] is! String ||
            bot['turns'] is! int ||
            ![
              'aggressive',
              'cautious',
              'pairFocused',
            ].contains(bot['personality']) ||
            !BotDifficulty.values.any(
              (level) => level.name == bot['difficulty'],
            )) {
          return false;
        }
        for (final id in [...bot['seen'], ...bot['takes']]) {
          if (!ids.contains(id)) return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> load() => _loaded ? Future.value() : _loading ??= _load();
  Future<void> _load() async {
    final revision = _revision;
    try {
      final raw = await SharedPreferencesAsync().getString(storageKey);
      if (raw != null && _snapshot == null && revision == _revision) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (valid(value)) {
          _snapshot = value;
          _encodedSnapshot = raw;
        }
      }
    } catch (_) {
      /* Missing or invalid saves must never block the menu. */
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(Map<String, dynamic> value) {
    if (!valid(value)) return Future.value();
    final wasAvailable = hasGame;
    _snapshot = value;
    _revision++;
    if (!wasAvailable) notifyListeners();
    final encoded = jsonEncode(value);
    if (encoded == _encodedSnapshot) return flushed;
    _encodedSnapshot = encoded;
    return _enqueue(() async {
      try {
        await SharedPreferencesAsync().setString(storageKey, encoded);
      } catch (_) {}
    });
  }

  Future<void> clear() {
    final wasAvailable = hasGame;
    _snapshot = null;
    _encodedSnapshot = null;
    _revision++;
    if (wasAvailable) notifyListeners();
    return _enqueue(() async {
      try {
        await SharedPreferencesAsync().remove(storageKey);
      } catch (_) {}
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final previous = _writes;
    final next = previous == null ? action() : previous.then((_) => action());
    _writes = next;
    unawaited(
      next.then((_) {
        if (identical(_writes, next)) _writes = null;
      }),
    );
    return next;
  }

  Future<void> get flushed => _writes ?? Future.value();
}

final savedGame = SavedGameController();

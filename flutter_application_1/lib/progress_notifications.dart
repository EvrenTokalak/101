import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_progress.dart';

class ProgressNotice {
  final String id;
  final String title;
  final bool room;
  const ProgressNotice(this.id, this.title, {this.room = false});
}

class DailyMission {
  final String id;
  final int slot;
  final bool claimed;
  final String title;
  final int target;
  final int reward;
  final int current;
  const DailyMission(
    this.title,
    this.target,
    this.reward,
    this.current, {
    required this.id,
    required this.slot,
    this.claimed = false,
  });
  bool get complete => current >= target;
}

/// Tracks real progress and keeps unread notices across app restarts.
class ProgressNotifications extends ChangeNotifier {
  final PlayerProgressController progress;
  final DateTime Function() now;
  ProgressNotifications(this.progress, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  static const _key = 'inbox.progress_events_v1';
  static const rooms = [(5, 'Standart'), (15, 'VIP'), (25, 'Elit')];
  final List<ProgressNotice> _unread = [];
  final List<ProgressNotice> _notices = [];
  final List<ProgressNotice> _toasts = [];
  final Set<String> _completed = {};
  final List<int> _generations = [0, 0, 0];
  final List<bool> _claimed = [false, false, false];
  int _games = 0, _opens = 0, _wins = 0, _level = 0;
  DateTime? _deadline;
  bool _ready = false;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  List<ProgressNotice> get unread => List.unmodifiable(_unread);
  List<ProgressNotice> get notices => List.unmodifiable(_notices);
  void refresh() => _sync();
  List<DailyMission> get missions => List.generate(3, (slot) {
    final generation = _generations[slot];
    final target = [3, 5, 1][slot] + generation.clamp(0, 7);
    final title = switch (slot) {
      0 => '$target oyun oyna',
      1 => '$target kez per aç',
      _ => target == 1 ? 'Bir oyun kazan' : '$target oyun kazan',
    };
    final count = [
      progress.gamesPlayed - _games,
      progress.handsOpened - _opens,
      progress.gamesWon - _wins,
    ][slot];
    return DailyMission(
      title,
      target,
      [350, 500, 750][slot] + generation.clamp(0, 20) * 100,
      count.clamp(0, target),
      id: '${_deadline?.millisecondsSinceEpoch}-$slot-$generation',
      slot: slot,
      claimed: _claimed[slot],
    );
  });

  DailyMission? claimMission(String id) {
    if (!_ready) return null;
    final matches = missions.where((m) => m.id == id);
    if (matches.isEmpty) return null;
    final mission = matches.single;
    if (!mission.complete || mission.claimed) return null;
    _claimed[mission.slot] = true;
    _unread.removeWhere(
      (entry) => entry.title == 'Görev tamamlandı: ${mission.title}',
    );
    _toasts.removeWhere(
      (entry) => entry.title == 'Görev tamamlandı: ${mission.title}',
    );
    progress.grantDailyReward(coins: mission.reward, xp: 0);
    return mission;
  }

  bool replaceClaimedMission(String id) {
    final matches = missions.where((m) => m.id == id && m.claimed);
    if (matches.isEmpty) return false;
    final slot = matches.single.slot;
    switch (slot) {
      case 0:
        _games = progress.gamesPlayed;
      case 1:
        _opens = progress.handsOpened;
      case 2:
        _wins = progress.gamesWon;
    }
    _completed.remove('$slot-${_generations[slot]}');
    _generations[slot]++;
    _claimed[slot] = false;
    _sync();
    return true;
  }

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_key);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        _games = data['games'] as int;
        _opens = data['opens'] as int;
        _wins = data['wins'] as int;
        _level = data['level'] as int;
        _deadline = DateTime.fromMillisecondsSinceEpoch(
          data['deadline'] as int,
        );
        _completed.addAll(
          (data['completed'] as List).cast<String>().map(
            (id) => id.contains('-') ? id : '$id-0',
          ),
        );
        if (data['generations'] != null) {
          for (var i = 0; i < 3; i++) {
            _generations[i] = data['generations'][i] as int;
            _claimed[i] = data['claimed'][i] as bool;
          }
        }
        for (final entry in data['unread'] as List) {
          _unread.add(
            ProgressNotice(entry['id'], entry['title'], room: entry['room']),
          );
        }
        for (final entry in (data['notices'] ?? data['unread']) as List) {
          _notices.add(
            ProgressNotice(entry['id'], entry['title'], room: entry['room']),
          );
        }
      } else {
        _level = progress.level;
      }
    } catch (_) {
      _level = progress.level;
    }
    if (_deadline == null || !now().isBefore(_deadline!)) {
      int? savedDeadline;
      try {
        savedDeadline = await SharedPreferencesAsync().getInt(
          'tasks.deadline_ms',
        );
      } catch (_) {}
      _resetDay(
        deadline: savedDeadline == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(savedDeadline),
      );
    }
    _ready = true;
    progress.addListener(_sync);
    _sync();
  }

  void _resetDay({DateTime? deadline}) {
    _games = progress.gamesPlayed;
    _opens = progress.handsOpened;
    _wins = progress.gamesWon;
    _completed.clear();
    _generations.fillRange(0, 3, 0);
    _claimed.fillRange(0, 3, false);
    _deadline = deadline != null && deadline.isAfter(now())
        ? deadline
        : now().add(const Duration(hours: 24));
  }

  void _sync() {
    if (!_ready) return;
    if (progress.gamesPlayed < _games ||
        progress.handsOpened < _opens ||
        progress.gamesWon < _wins ||
        progress.level < _level) {
      _unread.clear();
      _notices.clear();
      _toasts.clear();
      _level = progress.level;
      _resetDay();
    }
    if (!now().isBefore(_deadline!)) _resetDay();
    for (final room in rooms) {
      if (_level < room.$1 && progress.level >= room.$1) {
        _add(
          ProgressNotice(
            'room-${room.$1}',
            '${room.$2} masası açıldı!',
            room: true,
          ),
        );
      }
    }
    _level = progress.level;
    for (var i = 0; i < missions.length; i++) {
      final mission = missions[i];
      if (mission.complete && _completed.add('$i-${_generations[i]}')) {
        _add(
          ProgressNotice(
            'mission-${mission.id}',
            'Görev tamamlandı: ${mission.title}',
          ),
        );
      }
    }
    notifyListeners();
    unawaited(_persist());
  }

  void _add(ProgressNotice notice) {
    if (_unread.any((entry) => entry.id == notice.id)) return;
    _unread.add(notice);
    if (!_notices.any((entry) => entry.id == notice.id)) _notices.add(notice);
    _toasts.add(notice);
  }

  List<ProgressNotice> takeToasts() {
    final result = List<ProgressNotice>.of(_toasts);
    _toasts.clear();
    return result;
  }

  void markRead(String title) {
    _unread.removeWhere((entry) => entry.title == title);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> markAllRead() async {
    await load();
    _unread.clear();
    _toasts.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> dismissNotice(String id) async {
    if (!_ready) await load();
    _notices.removeWhere((notice) => notice.id == id);
    _unread.removeWhere((notice) => notice.id == id);
    _toasts.removeWhere((notice) => notice.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearNotices() async {
    await load();
    _notices.clear();
    _unread.clear();
    _toasts.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    if (_deadline == null) return Future.value();
    final value = jsonEncode({
      'games': _games,
      'opens': _opens,
      'wins': _wins,
      'level': _level,
      'deadline': _deadline!.millisecondsSinceEpoch,
      'completed': _completed.toList(),
      'generations': _generations,
      'claimed': _claimed,
      'notices': _notices
          .map((e) => {'id': e.id, 'title': e.title, 'room': e.room})
          .toList(),
      'unread': _unread
          .map((e) => {'id': e.id, 'title': e.title, 'room': e.room})
          .toList(),
    });
    return _writes = _writes.then((_) async {
      try {
        await SharedPreferencesAsync().setString(_key, value);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    progress.removeListener(_sync);
    super.dispose();
  }
}

final progressNotifications = ProgressNotifications(playerProgress);

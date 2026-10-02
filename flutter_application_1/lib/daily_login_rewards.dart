import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_progress.dart';

class DailyLoginReward {
  final int coins;
  final int xp;

  const DailyLoginReward(this.coins, this.xp);
}

const dailyLoginRewards = <DailyLoginReward>[
  DailyLoginReward(150, 0),
  DailyLoginReward(250, 0),
  DailyLoginReward(400, 10),
  DailyLoginReward(600, 20),
  DailyLoginReward(850, 30),
  DailyLoginReward(1200, 45),
  DailyLoginReward(1800, 70),
];

class DailyLoginController extends ChangeNotifier {
  static const _lastClaimKey = 'daily_login.last_claim_day';
  static const _streakKey = 'daily_login.streak';

  int _streak = 0;
  int? _lastClaimDay;
  bool _loaded = false;

  int get streak => _streak;
  int get displayDay => canClaimToday
      ? (_isYesterday(_lastClaimDay) ? (_streak % 7) + 1 : 1)
      : ((_streak - 1) % 7) + 1;
  bool get canClaimToday => _lastClaimDay != _dayNumber(DateTime.now());
  bool get loaded => _loaded;

  Future<void> load() async {
    var resetMissedStreak = false;
    try {
      final prefs = SharedPreferencesAsync();
      _lastClaimDay = await prefs.getInt(_lastClaimKey);
      _streak = (await prefs.getInt(_streakKey) ?? 0).clamp(0, 1000000);
      final today = _dayNumber(DateTime.now());
      if (_lastClaimDay != null && _lastClaimDay! < today - 1) {
        _streak = 0;
        resetMissedStreak = true;
      }
      if (resetMissedStreak) await prefs.setInt(_streakKey, 0);
    } catch (_) {
      // Depolama yoksa ödül sistemi mevcut oturumda çalışmayı sürdürür.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<DailyLoginReward?> claim() async {
    if (!_loaded) await load();
    if (!canClaimToday) return null;
    final today = _dayNumber(DateTime.now());
    _streak = _isYesterday(_lastClaimDay) ? _streak + 1 : 1;
    _lastClaimDay = today;
    final reward = dailyLoginRewards[(_streak - 1) % 7];
    playerProgress.grantDailyReward(coins: reward.coins, xp: reward.xp);
    try {
      final prefs = SharedPreferencesAsync();
      await prefs.setInt(_lastClaimKey, today);
      await prefs.setInt(_streakKey, _streak);
    } catch (_) {}
    notifyListeners();
    return reward;
  }

  bool _isYesterday(int? value) =>
      value != null && value == _dayNumber(DateTime.now()) - 1;

  static int _dayNumber(DateTime value) {
    final calendarDay = DateTime.utc(value.year, value.month, value.day);
    return calendarDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }
}

final dailyLogin = DailyLoginController();

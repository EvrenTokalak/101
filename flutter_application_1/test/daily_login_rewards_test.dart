import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/daily_login_rewards.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    playerProgress.reset(coins: 1000);
  });

  test('günlük ödül aynı gün yalnız bir kez alınır', () async {
    final controller = DailyLoginController();
    await controller.load();

    expect(controller.canClaimToday, isTrue);
    final reward = await controller.claim();

    expect(reward?.coins, dailyLoginRewards.first.coins);
    expect(reward?.xp, 0);
    expect(playerProgress.coins, 1000 + dailyLoginRewards.first.coins);
    expect(controller.canClaimToday, isFalse);
    expect(await controller.claim(), isNull);
  });

  test('bir gün kaçırılan giriş serisi birinci güne sıfırlanır', () async {
    final missedDay = DateTime.now().subtract(const Duration(days: 2));
    final missedDayNumber =
        DateTime.utc(
          missedDay.year,
          missedDay.month,
          missedDay.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    SharedPreferences.setMockInitialValues({
      'daily_login.last_claim_day': missedDayNumber,
      'daily_login.streak': 4,
    });
    final controller = DailyLoginController();

    await controller.load();

    expect(controller.streak, 0);
    expect(controller.displayDay, 1);
    final reward = await controller.claim();
    expect(reward?.coins, dailyLoginRewards.first.coins);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/daily_login_rewards.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesAsync().clear();
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
    final reopened = DailyLoginController();
    await reopened.load();
    expect(reopened.canClaimToday, isFalse);
    expect(await reopened.claim(), isNull);
    expect(playerProgress.coins, 1000 + dailyLoginRewards.first.coins);
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
    await SharedPreferencesAsync().setInt(
      'daily_login.last_claim_day',
      missedDayNumber,
    );
    await SharedPreferencesAsync().setInt('daily_login.streak', 4);
    final controller = DailyLoginController();

    await controller.load();

    expect(controller.streak, 0);
    expect(controller.displayDay, 1);
    final reward = await controller.claim();
    expect(reward?.coins, dailyLoginRewards.first.coins);
  });

  test(
    'repeatable cycle credits all seven rewards and then starts over',
    () async {
      final controller = DailyLoginController(waitForNextDay: false);
      await controller.load();
      var totalCoins = 1000;
      for (var day = 1; day <= 7; day++) {
        expect(controller.displayDay, day);
        expect(controller.isDayClaimed(day), isFalse);
        final reward = await controller.claim();
        expect(reward, same(dailyLoginRewards[day - 1]));
        totalCoins += dailyLoginRewards[day - 1].coins;
        expect(playerProgress.coins, totalCoins);
        if (day < 7) expect(controller.isDayClaimed(day), isTrue);
      }
      expect(controller.displayDay, 1);
      expect(controller.canClaimToday, isTrue);
      expect([
        for (var day = 1; day <= 7; day++) controller.isDayClaimed(day),
      ], everyElement(isFalse));
      final reloaded = DailyLoginController(waitForNextDay: false);
      await reloaded.load();
      expect(reloaded.displayDay, 1);
      expect((await reloaded.claim())?.coins, dailyLoginRewards.first.coins);
      expect(playerProgress.coins, totalCoins + dailyLoginRewards.first.coins);
    },
  );

  test(
    'next calendar day unlocks the next reward and wraps after day seven',
    () async {
      final now = DateTime.now();
      final yesterday =
          DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
              Duration.millisecondsPerDay -
          1;
      final preferences = SharedPreferencesAsync();
      for (final streak in [1, 6, 7]) {
        await preferences.setInt('daily_login.last_claim_day', yesterday);
        await preferences.setInt('daily_login.streak', streak);
        final controller = DailyLoginController();
        await controller.load();
        expect(controller.canClaimToday, isTrue);
        expect(controller.displayDay, streak % 7 + 1);
        expect(await controller.claim(), same(dailyLoginRewards[streak % 7]));
        expect(controller.canClaimToday, isFalse);
        expect(await controller.claim(), isNull);
      }
    },
  );

  test('repeatable cycle preserves progress after missing days', () async {
    final missed = DateTime.now().subtract(const Duration(days: 4));
    final day =
        DateTime.utc(
          missed.year,
          missed.month,
          missed.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    await SharedPreferencesAsync().setInt('daily_login.last_claim_day', day);
    await SharedPreferencesAsync().setInt('daily_login.streak', 4);
    final controller = DailyLoginController(waitForNextDay: false);
    await controller.load();
    expect(controller.displayDay, 5);
    expect((await controller.claim())?.coins, dailyLoginRewards[4].coins);
    final reloaded = DailyLoginController(waitForNextDay: false);
    await reloaded.load();
    expect(reloaded.displayDay, 6);
  });

  test('overlapping taps cannot collect two rewards at once', () async {
    final controller = DailyLoginController(waitForNextDay: false);
    await controller.load();
    final results = await Future.wait([controller.claim(), controller.claim()]);
    expect(results.whereType<DailyLoginReward>(), hasLength(1));
    expect(playerProgress.coins, 1000 + dailyLoginRewards.first.coins);
    expect(controller.displayDay, 2);
  });
}

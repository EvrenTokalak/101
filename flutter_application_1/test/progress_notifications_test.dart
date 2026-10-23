import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/progress_notifications.dart';

void main() {
  preparePanelArtwork();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => progressNotifications.load());
  setUp(() async => SharedPreferencesAsync().clear());

  void completeGame(PlayerProgressController player, {bool won = false}) {
    player.recordCompletedGame(
      config: const GameLaunchConfig.quickPlay(),
      won: won,
      openedHand: true,
      finishedHand: won,
    );
  }

  test('mark all read persists without consuming mission rewards or future notices', () async {
    final player = PlayerProgressController();
    final notices = ProgressNotifications(player);
    addTearDown(notices.dispose);
    await notices.load();
    completeGame(player, won: true);
    expect(notices.unread, isNotEmpty);
    final coins = player.coins;
    final noticeTitles = notices.notices.map((entry) => entry.title).toList();
    await notices.markAllRead();
    expect(notices.unread, isEmpty);
    expect(notices.notices.map((entry) => entry.title), noticeTitles);
    expect(notices.takeToasts(), isEmpty);
    expect(player.coins, coins);
    expect(notices.missions.last.complete, isTrue);
    expect(notices.missions.last.claimed, isFalse);
    final reopened = ProgressNotifications(player);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.unread, isEmpty);
    expect(reopened.notices.map((entry) => entry.title), noticeTitles);
    completeGame(player);
    completeGame(player);
    expect(
      reopened.unread.any((entry) => entry.title.contains('3 oyun oyna')),
      isTrue,
    );
  });

  test(
    'completed missions emit one notice each using actual game progress',
    () async {
      final player = PlayerProgressController();
      final notices = ProgressNotifications(player);
      addTearDown(notices.dispose);
      await notices.load();
      for (var i = 0; i < 5; i++) {
        completeGame(player, won: true);
      }
      expect(notices.missions.map((m) => m.current), [3, 5, 1]);
      expect(notices.unread.where((n) => !n.room), hasLength(3));
      notices.refresh();
      expect(notices.unread.where((n) => !n.room), hasLength(3));
      final title = notices.unread.first.title;
      notices.markRead(title);
      notices.refresh();
      expect(notices.unread.where((n) => n.title == title), isEmpty);
    },
  );

  test('deleting inbox notices persists without resetting completion or consuming rewards', () async {
    final player = PlayerProgressController();
    final notices = ProgressNotifications(player);
    addTearDown(notices.dispose);
    await notices.load();
    completeGame(player, won: true);
    final id = notices.notices.single.id;
    final coins = player.coins;
    await notices.dismissNotice(id);
    expect(notices.notices, isEmpty);
    expect(notices.unread, isEmpty);
    notices.refresh();
    expect(notices.notices, isEmpty);
    completeGame(player);
    completeGame(player);
    expect(notices.notices, isNotEmpty);
    await notices.clearNotices();
    final reopened = ProgressNotifications(player);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.notices, isEmpty);
    expect(reopened.unread, isEmpty);
    expect(reopened.missions.last.complete, isTrue);
    expect(reopened.missions.last.claimed, isFalse);
    expect(player.coins, greaterThanOrEqualTo(coins));
  });

  test(
    'new table notice follows actual level unlock and is not repeated',
    () async {
      final player = PlayerProgressController()..reset(level: 4);
      final notices = ProgressNotifications(player);
      addTearDown(notices.dispose);
      await notices.load();
      player.grantDailyReward(coins: 0, xp: 50);
      expect(notices.unread.single.title, 'Standart masası açıldı!');
      notices.markRead(notices.unread.single.title);
      player.grantDailyReward(coins: 0, xp: 1);
      expect(notices.unread, isEmpty);
    },
  );

  test(
    'mission reward is granted once and replacement starts from zero',
    () async {
      final player = PlayerProgressController();
      final notices = ProgressNotifications(player);
      addTearDown(notices.dispose);
      await notices.load();
      final incomplete = notices.missions.last;
      expect(notices.claimMission(incomplete.id), isNull);
      completeGame(player, won: true);
      final mission = notices.missions.last;
      final balance = player.coins;
      expect(notices.claimMission(mission.id)?.reward, 750);
      expect(player.coins, balance + 750);
      expect(notices.claimMission(mission.id), isNull);
      expect(player.coins, balance + 750);
      expect(notices.missions.last.id, mission.id);
      expect(notices.missions.last.claimed, isTrue);
      expect(notices.replaceClaimedMission(mission.id), isTrue);
      final replacement = notices.missions.last;
      expect(replacement.id, isNot(mission.id));
      expect(replacement.title, '2 oyun kazan');
      expect(replacement.current, 0);
      expect(replacement.claimed, isFalse);
      expect(notices.replaceClaimedMission(mission.id), isFalse);
      expect(notices.claimMission(mission.id), isNull);
    },
  );

  test(
    'daily rollover restarts mission progress and permits new completions',
    () async {
      var time = DateTime(2026, 10, 6);
      final player = PlayerProgressController();
      final notices = ProgressNotifications(player, clock: () => time);
      addTearDown(notices.dispose);
      await notices.load();
      completeGame(player, won: true);
      expect(notices.missions.last.complete, isTrue);
      time = time.add(const Duration(hours: 25));
      notices.refresh();
      expect(notices.missions.map((m) => m.current), [0, 0, 0]);
      completeGame(player, won: true);
      expect(
        notices.unread.where((n) => n.title.contains('Bir oyun kazan')),
        hasLength(2),
      );
    },
  );

  testWidgets('home shows completion toast and unread inbox entry', (
    tester,
  ) async {
    playerProgress.reset();
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byKey(const ValueKey('home-missions-badge')), findsNothing);
    completeGame(playerProgress, won: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Görev tamamlandı: Bir oyun kazan'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-missions-badge')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump(const Duration(milliseconds: 350));
    final entry = find.byKey(
      const ValueKey('feature-entry-Görev tamamlandı: Bir oyun kazan'),
    );
    expect(entry, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    final inboxBounds = tester.getRect(
      find.byKey(const ValueKey('feature-content-viewport-GELEN KUTUSU')),
    );
    final inboxCardWidth = tester.getSize(entry).width;
    await tester.tap(entry);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      progressNotifications.unread.where(
        (n) => n.title.contains('Bir oyun kazan'),
      ),
      isEmpty,
    );
    expect(find.text('GÖREVLER'), findsWidgets);
    expect(find.textContaining('YENİLENME'), findsNothing);
    final claim = find.byKey(const ValueKey('mission-claim-Bir oyun kazan'));
    expect(claim, findsOneWidget);
    expect(
      tester.getRect(
        find.byKey(const ValueKey('feature-content-viewport-GÖREVLER')),
      ),
      inboxBounds,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('mission-progress-Bir oyun kazan')),
          )
          .width,
      closeTo(inboxCardWidth, .1),
    );
    final reward = find.byKey(const ValueKey('mission-reward-Bir oyun kazan'));
    final bar = find.byKey(
      const ValueKey('mission-progress-bar-Bir oyun kazan'),
    );
    expect(tester.getCenter(reward).dx, lessThan(tester.getCenter(bar).dx));
    expect(tester.getCenter(reward).dy, closeTo(tester.getCenter(bar).dy, .1));
    expect(
      tester.getCenter(claim).dx,
      greaterThan(tester.getCenter(find.text('Bir oyun kazan')).dx),
    );
    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(1280, 720),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      await tester.ensureVisible(claim);
      expect(claim.hitTestable(), findsOneWidget);
      final error = tester.takeException();
      expect(
        error,
        isNull,
        reason:
            'At $size: ${error is FlutterError ? error.toDiagnosticsNode().toStringDeep() : error}',
      );
    }
    final balance = playerProgress.coins;
    await tester.tap(claim);
    await tester.pump();
    await tester.tap(claim);
    await tester.pump(const Duration(milliseconds: 300));
    expect(playerProgress.coins, balance + 750);
    expect(find.byKey(const ValueKey('home-missions-badge')), findsNothing);
    final claimedButton = tester.widget<FilledButton>(claim);
    const disabled = {WidgetState.disabled};
    expect(
      claimedButton.style!.backgroundColor!.resolve(disabled),
      const Color(0xFF2E7D32),
    );
    expect(
      claimedButton.style!.foregroundColor!.resolve(disabled),
      Colors.white,
    );
    expect(find.byKey(const ValueKey('reward-coin-flight')), findsOneWidget);
    expect(find.text('Bir oyun kazan'), findsOneWidget);
    expect(find.text('2 oyun kazan'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bir oyun kazan'), findsNothing);
    expect(find.text('2 oyun kazan'), findsOneWidget);
    expect(find.text('ÖDÜLÜ AL'), findsNothing);
    expect(progressNotifications.missions.last.current, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    playerProgress.reset();
  });
  testWidgets(
    'different completed rewards can be claimed during coin flights',
    (tester) async {
      playerProgress.reset();
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
      await tester.pump(const Duration(milliseconds: 750));
      for (var i = 0; i < 5; i++) {
        completeGame(playerProgress, won: true);
      }
      await tester.pump();
      await tester.tap(find.text('GÖREVLER').first);
      await tester.pump(const Duration(milliseconds: 350));
      final missions = progressNotifications.missions.toList();
      final before = playerProgress.coins;
      for (final mission in missions) {
        final button = find.byKey(ValueKey('mission-claim-${mission.title}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          progressNotifications.missions
              .singleWhere((m) => m.id == mission.id)
              .claimed,
          isTrue,
        );
      }
      expect(
        playerProgress.coins,
        before + missions.fold<int>(0, (sum, mission) => sum + mission.reward),
      );
      expect(
        find.byKey(const ValueKey('reward-coin-flight')),
        findsNWidgets(3),
      );
      // Closing mid-animation must preserve the credited rewards and clear each claim.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(progressNotifications.missions.every((m) => !m.claimed), isTrue);
      expect(tester.takeException(), isNull);
      playerProgress.reset();
    },
  );
}

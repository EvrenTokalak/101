import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/daily_challenge.dart';
import 'package:flutter_application_1/daily_challenge_card.dart';
import 'package:flutter_application_1/game_launch.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  testWidgets(
    'countdown updates, stays at the top right and renews at midnight',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferencesAsync().clear();
      var now = DateTime(2026, 10, 19, 23, 59, 58);
      final progress = PlayerProgressController();
      final challenge = DailyChallengeController(progress, clock: () => now);
      await challenge.load();
      final config = GameLaunchConfig.gameMode(
        mode: challenge.definition.mode ?? OkeyGameMode.standard,
        id: 'test',
        label: 'Test',
      );
      await challenge.recordRound(config: config, won: true);
      expect(challenge.current, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 300,
                child: DailyChallengeCard(controller: challenge),
              ),
            ),
          ),
        ),
      );
      final countdown = find.byKey(const ValueKey('daily-challenge-countdown'));
      expect(find.text('00:00:02'), findsOneWidget);
      final title = find.text('GÜNLÜK MEYDAN OKUMA');
      expect(
        tester.getCenter(countdown).dx,
        greaterThan(tester.getCenter(title).dx),
      );
      expect(
        tester.getCenter(countdown).dy,
        closeTo(tester.getCenter(title).dy, 1),
      );
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00:01'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('24:00:00'), findsOneWidget);
      expect(challenge.current, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      challenge.dispose();
      progress.dispose();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/daily_league.dart';
import 'package:flutter_application_1/league_screen.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/game_launch.dart';

void main() {
  setUp(() async {
    await dailyLeague.resetForTesting();
    await SharedPreferencesAsync().clear();
    playerProgress.reset();
    await dailyLeague.load();
  });

  testWidgets(
    'competition card shows actual leader gap and changes on taking the lead',
    (tester) async {
      await tester.runAsync(
        () => dailyLeague.recordRound(
          config: const GameLaunchConfig.quickPlay(),
          roundId: 'competition-first',
          tablePenalties: [80, 50, 60, 70],
          simulatedPenalties: List.filled(16, 202),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1180, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: LeagueScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SEN · 4. sıra'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('league-competition-gap')),
        findsNothing,
      );
      await tester.runAsync(
        () => dailyLeague.recordRound(
          config: const GameLaunchConfig.quickPlay(),
          roundId: 'competition-second',
          tablePenalties: [-101, 202, 202, 202],
          simulatedPenalties: List.filled(16, 202),
        ),
      );
      await tester.pump();
      expect(find.text('SEN · 1. sıra'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('league-competition-rank')),
        findsNothing,
      );
      expect(find.text('BUGÜNKÜ OYUNLARIN'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('league standings adapt to desktop tablet and phone sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [
      Size(1180, 700),
      Size(1024, 768),
      Size(768, 1024),
      Size(568, 320),
      Size(320, 568),
      Size(320, 360),
      Size(390, 844),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: LeagueScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
      expect(find.text('GÜNLÜK LİG'), findsOneWidget);
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.text('20 YARIŞMACI'), findsNothing);
      expect(find.text('HAZIR MISIN?'), findsNothing);
      expect(find.text('LİG BİTİMİNE'), findsOneWidget);
      expect(find.text('YENİLENMEYE'), findsNothing);
      expect(find.text('İlk 3’e 3.000 · 2.000 · 1.000 altın'), findsNothing);
      expect(find.text('Son 1 saat hatırlatıcısı'), findsNothing);
      expect(find.byKey(const ValueKey('league-scroll-hint')), findsOneWidget);
      expect(find.text('20 yarışmacı · Kaydır'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('league-penalty-0')))
            .data,
        '—',
      );
      expect(
        find.text('Süre bitene kadar oynadığın eller ligine sayılır'),
        findsOneWidget,
      );
      expect(find.textContaining('Beginner'), findsNothing);
      expect(find.textContaining('BEGINNER'), findsNothing);
      expect(find.text('GÜNLÜK ÖDÜLLER'), findsNothing);
      expect(
        find.byKey(const ValueKey('league-competition-rank')),
        findsNothing,
      );
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('league-standings')),
      );
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate)
            .estimatedChildCount,
        20,
      );
      expect(find.byKey(const ValueKey('league-entry-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('league-scroll-hint')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('league-scroll-hint')), findsNothing);
      list.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('league-scroll-hint')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('league-play')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('league-play')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home league action opens standings and shows saved progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byKey(const ValueKey('home-league-summary')), findsOneWidget);
    await tester.tap(find.text('LİG'));
    await tester.pumpAndSettle();
    expect(find.byType(LeagueScreen), findsOneWidget);
    expect(find.text('GÜNLÜK LİG'), findsOneWidget);
    expect(find.text('ÇEYREK FİNAL'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

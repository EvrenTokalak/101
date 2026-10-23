import 'dart:async';

import 'package:flutter/material.dart';

import 'game.dart';
import 'game_launch.dart';
import 'daily_league.dart';
import 'league_reminder.dart';
import 'app_settings_dialog.dart';
import 'performance_overlay.dart';
import 'route_activity.dart';
import 'difficulty_picker.dart';
import 'saved_game.dart';
import 'player_progress.dart';

Future<T?> openGameScreen<T>(
  BuildContext context, {
  required GameLaunchConfig config,
  Map<String, dynamic>? savedState,
}) async {
  if (!context.mounted) return null;
  if (savedState == null &&
      (config.entryPoint == GameEntryPoint.room ||
          config.entryPoint == GameEntryPoint.gameMode)) {
    final selected = config.difficulty ?? await pickBotDifficulty(context);
    if (selected == null || !context.mounted) return null;
    config = config.withDifficulty(selected);
  }
  if (config.entryPoint == GameEntryPoint.quickPlay) {
    await dailyLeague.load();
    dailyLeague.refresh();
    if (appSettings.value.notifications) {
      await leagueReminder.requestPermission();
    }
    if (!context.mounted) return null;
  }

  if (!context.mounted) return null;
  if (savedState == null &&
      config.entryPoint == GameEntryPoint.room &&
      !playerProgress.trySpendCoins(config.entryFee ?? 0)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        dismissDirection: DismissDirection.horizontal,
        content: Text('Yeterli altın yok.'),
      ),
    );
    return null;
  }
  if (savedState == null &&
      config.entryPoint != GameEntryPoint.tutorial &&
      config.entryPoint != GameEntryPoint.tournament) {
    unawaited(savedGame.clear());
  }

  final result = await Navigator.of(context).push<T>(
    AppSceneRoute<T>(
      builder: (_) => GameScreen(launchConfig: config, savedState: savedState),
      reverseCurve: Curves.easeInCubic,
      reverseDuration: const Duration(milliseconds: 100),
    ),
  );

  // Run after the game route has disposed, while the menu is idle.
  PaintingBinding.instance.imageCache.clearLiveImages();
  await requestMemoryTrim(aggressive: true);
  return result;
}

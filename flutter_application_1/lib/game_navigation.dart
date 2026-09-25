import 'package:flutter/material.dart';

import 'game.dart';
import 'game_launch.dart';
import 'performance_overlay.dart';
import 'route_activity.dart';

Future<T?> openGameScreen<T>(
  BuildContext context, {
  required GameLaunchConfig config,
}) async {
  if (!context.mounted) return null;

  final result = await Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (_, _, _) =>
          ActiveRouteScene(child: GameScreen(launchConfig: config)),
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // Opacity iki tam ekran sahneyi GPU'da birlestirir. Kisa ve opak kayma
        // gecisi ayni akiciligi daha dusuk raster maliyetiyle verir.
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );

  // Run after the game route has disposed, while the menu is idle.
  PaintingBinding.instance.imageCache.clearLiveImages();
  await requestMemoryTrim(aggressive: true);
  return result;
}

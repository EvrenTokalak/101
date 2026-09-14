import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'game_launch.dart';

Future<T?> openGameScreen<T>(
  BuildContext context, {
  required GameLaunchConfig config,
}) async {
  unawaited(
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  if (!context.mounted) return null;

  final result = await Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => GameScreen(launchConfig: config),
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );

  unawaited(
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]),
  );
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  return result;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LeagueReminder {
  const LeagueReminder();
  static const channel = MethodChannel('okey/league_reminder');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> update({
    required DateTime deadline,
    required bool enabled,
  }) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('schedule', {
        'deadline': deadline.millisecondsSinceEpoch,
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Widget tests and web builds have no Android channel.
    } on PlatformException {
      // Notification availability must not prevent playing offline.
    }
  }
}

const leagueReminder = LeagueReminder();

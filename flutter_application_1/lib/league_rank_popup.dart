import 'dart:math';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'daily_league.dart';

class LeagueRankPopup extends StatelessWidget {
  const LeagueRankPopup({super.key, required this.notice});
  final LeagueRankNotice notice;

  @override
  Widget build(BuildContext context) => AppGenericPanel(
    key: const ValueKey('league-rank-popup'),
    width: min(330, MediaQuery.sizeOf(context).width - 32),
    height: 190,
    title: const Text('GÜNLÜK LİG'),

    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${notice.rank}. sıradasın',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '20 yarışmacı · ${notice.completedRounds} el tamamlandı',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

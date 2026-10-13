import 'dart:math';

import 'package:flutter/material.dart';

import 'daily_league.dart';

class LeagueRankPopup extends StatelessWidget {
  const LeagueRankPopup({super.key, required this.notice});
  final LeagueRankNotice notice;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('league-rank-popup'),
    width: min(330, MediaQuery.sizeOf(context).width - 32),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
    decoration: BoxDecoration(
      color: const Color(0xEE0C2D21),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEBD268), width: 1.4),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 6)),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFEBD268),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'GÜNLÜK LİG',
              style: TextStyle(
                color: Color(0xFFEBD268),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${notice.rank}. sıradasın',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '20 yarışmacı · ${notice.completedRounds}/20 el tamamlandı',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'daily_challenge.dart';

class DailyChallengeCard extends StatefulWidget {
  final DailyChallengeController? controller;
  const DailyChallengeCard({super.key, this.controller});
  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  DailyChallengeController get _challenge =>
      widget.controller ?? dailyChallenge;
  Timer? _timer;
  late DateTime _shownDay;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _shownDay = _challenge.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final date = _challenge.now();
      if (date.year != _shownDay.year ||
          date.month != _shownDay.month ||
          date.day != _shownDay.day) {
        _shownDay = date;
        _challenge.refresh();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remainingLabel {
    final seconds = (_challenge.remaining.inMilliseconds / 1000).ceil();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final reward = await _challenge.claim();
      if (mounted && reward > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            dismissDirection: DismissDirection.horizontal,
            content: Text('+$reward altın'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _challenge,
    builder: (context, _) => Container(
      key: const ValueKey('daily-challenge-card'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0A4835),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _challenge.claimed
              ? const Color(0xFF62C981)
              : const Color(0xFFD9BC6A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'GÜNLÜK MEYDAN OKUMA',
                    style: TextStyle(
                      color: Color(0xFFFFEFBD),
                      fontFamily: 'Baloo 2',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Günlük meydan okumanın yenilenmesine kalan süre',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: Color(0xFFF2D36C),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _remainingLabel,
                      key: const ValueKey('daily-challenge-countdown'),
                      style: const TextStyle(
                        color: Color(0xFFF2D36C),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _challenge.definition.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Image.asset('images/ui/coin.png', width: 16, height: 16),
              Text(
                ' +${_challenge.definition.coins}',
                style: const TextStyle(
                  color: Color(0xFFF2D36C),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_challenge.canClaim)
                TextButton(
                  key: const ValueKey('daily-challenge-claim'),
                  onPressed: _claiming ? null : _claim,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'TOPLA',
                    style: TextStyle(
                      color: Color(0xFFF2D36C),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                Text(
                  _challenge.claimed
                      ? 'ALINDI'
                      : '${_challenge.current}/${_challenge.definition.target}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'daily_login_rewards.dart';
import 'player_progress.dart';

class DailyLoginRewardCard extends StatelessWidget {
  final int day;
  final DailyLoginReward reward;
  final bool active, completed, tomorrow;
  final double width, height;

  const DailyLoginRewardCard({
    super.key,
    required this.day,
    required this.reward,
    required this.active,
    required this.completed,
    this.tomorrow = false,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.fromLTRB(5, 6, 5, 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF183C25), Color(0xFF061B13)],
      ),
      border: Border.all(
        color: active && !completed
            ? const Color(0xFF7EE893)
            : const Color(0xFFE1B449),
        width: 1.4,
      ),
      boxShadow: [
        const BoxShadow(
          color: Colors.black54,
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
        if (active && !completed)
          const BoxShadow(color: Color(0x664EE76A), blurRadius: 7),
      ],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x556CA568), width: .7),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 21,
            width: double.infinity,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diamond_outlined,
                      color: Color(0xFFFFD778),
                      size: 7,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appText('GÜN $day', 'DAY $day'),
                      key: ValueKey('daily-login-label-$day'),
                      style: const TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFE7A1),
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.diamond_outlined,
                      color: Color(0xFFFFD778),
                      size: 7,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 18,
            child: active && !completed
                ? Container(
                    key: ValueKey('daily-login-today-$day'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF307D46),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7EE893),
                        width: .7,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        appText('BUGÜN', 'TODAY'),
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE5FFD9),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Opacity(
                    opacity: completed ? .6 : 1,
                    child: DailyRewardArtwork(day: day),
                  ),
                ),
                if (completed)
                  const Positioned(
                    right: 1,
                    bottom: 1,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: Color(0xFF6DDE67),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            key: ValueKey('daily-login-reward-$day'),
            height: 40,
            child: Column(
              children: [
                SizedBox(
                  height: 26,
                  child: Center(
                    child: _RewardAmount(day: day, coins: reward.coins),
                  ),
                ),
                SizedBox(
                  height: 14,
                  child: reward.xp > 0
                      ? Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '+${reward.xp} XP',
                              style: const TextStyle(
                                fontFamily: 'Baloo 2',
                                fontSize: 12,
                                height: 1.1,
                                color: Color(0xFF91EBFB),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: 44,
              maxHeight: 44,
              child: SizedBox(
                key: ValueKey('daily-login-collect-$day'),
                height: 44,
                width: double.infinity,
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .9,
                    child: Container(
                      key: ValueKey('daily-login-collect-visual-$day'),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: active && !completed
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF7ECD48), Color(0xFF267931)],
                              )
                            : null,
                        color: completed
                            ? const Color(0xFF535A59)
                            : active
                            ? null
                            : const Color(0xFF2C3933),
                        border: Border.all(
                          color: active && !completed
                              ? const Color(0xFFFFE77F)
                              : const Color(0xFF7C8A79),
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!active && !completed) ...[
                                const Icon(
                                  Icons.lock_rounded,
                                  color: Color(0xFFE6DEC6),
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                completed
                                    ? appText('ALINDI', 'CLAIMED')
                                    : active
                                    ? appText('TOPLA', 'CLAIM')
                                    : tomorrow
                                    ? appText('YARIN', 'TOMORROW')
                                    : appText('KİLİTLİ', 'LOCKED'),
                                style: TextStyle(
                                  fontFamily: 'Baloo 2',
                                  fontSize: 12,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: active && !completed
                                      ? Colors.white
                                      : const Color(0xFFC7CEC7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Samples only unmarked reward artwork. Claim indicators are drawn from the
/// real controller state, so the reference's first-day check is never baked in.
class DailyRewardArtwork extends StatelessWidget {
  final int day;
  const DailyRewardArtwork({super.key, required this.day});

  static const _crops = [
    // A smaller, clean pile replaces the reference's checked first-day art.
    Rect.fromLTWH(505, 350, 114, 118),
    Rect.fromLTWH(505, 350, 114, 118),
    Rect.fromLTWH(657, 350, 114, 118),
    Rect.fromLTWH(813, 350, 115, 118),
    Rect.fromLTWH(966, 350, 126, 118),
    Rect.fromLTWH(1115, 347, 136, 123),
    Rect.fromLTWH(1275, 342, 214, 146),
  ];

  @override
  Widget build(BuildContext context) {
    final crop = _crops[day - 1];
    return FractionallySizedBox(
      widthFactor: day == 1 ? .9 : 1,
      heightFactor: day == 1 ? .9 : 1,
      child: SizedBox(
        key: ValueKey('daily-login-coins-$day'),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: crop.width,
            height: crop.height,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                radius: .7,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .65, 1],
              ).createShader(rect),
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: -crop.left,
                      top: -crop.top,
                      width: 1844,
                      height: 853,
                      child: Image.asset(
                        'images/ui/icons/daily-rewards-reference.webp',
                        width: 1844,
                        height: 853,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardAmount extends StatelessWidget {
  final int day, coins;
  const _RewardAmount({required this.day, required this.coins});

  static const style = TextStyle(
    fontFamily: 'Baloo 2',
    fontSize: 23,
    height: 1,
    color: Color(0xFFFFF2BE),
    fontWeight: FontWeight.w900,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final measurement = TextPainter(
      text: const TextSpan(text: '8.888', style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final size = measurement.size;
    measurement.dispose();
    // All amounts share the longest number's bounds, including days without XP
    // and the wider final card, so text scaling cannot move their baseline.
    return SizedBox(
      width: 84,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox.fromSize(
          size: size,
          child: Center(
            child: Text(
              formatGameNumber(coins),
              key: ValueKey('daily-login-amount-$day'),
              style: style,
              textScaler: scaler,
              semanticsLabel: appText('$coins Altın', '$coins Gold'),
            ),
          ),
        ),
      ),
    );
  }
}

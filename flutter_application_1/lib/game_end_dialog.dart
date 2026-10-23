part of 'game.dart';

class GameEndDialog extends StatelessWidget {
  final String winner;
  final String playerName;
  final int playerPen;
  final List<BotPlayer> bots;
  final List<int> botPens;
  final int elCount;
  final int? maxRounds;
  final bool matchComplete;
  final int totalPenalty;
  final GameReward? reward;
  final Future<LeagueRoundUpdate?>? leagueUpdate;
  final String homeLabel;
  final VoidCallback onNewRound;
  final VoidCallback onResetMatch;
  final VoidCallback onHome;

  const GameEndDialog({
    super.key,
    required this.winner,
    this.playerName = defaultPlayerProfileName,
    required this.playerPen,
    required this.bots,
    required this.botPens,
    required this.elCount,
    this.maxRounds,
    this.matchComplete = false,
    required this.totalPenalty,
    this.reward,
    this.leagueUpdate,
    this.homeLabel = 'ANA SAYFA',
    required this.onNewRound,
    required this.onResetMatch,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final won = winner == 'Sen' || winner == 'Oyuncu 1';
    final scoreRows =
        <
            ({
              String name,
              int roundScore,
              int total,
              bool highlighted,
              bool isPlayer,
              String avatarAsset,
            })
          >[
            (
              name: playerName,
              roundScore: playerPen,
              total: totalPenalty,
              highlighted: won,
              isPlayer: true,
              avatarAsset: playerProgress.playerAvatarAsset,
            ),
            for (var index = 0; index < bots.length; index++)
              (
                name: bots[index].displayName,
                roundScore: botPens[index],
                total: bots[index].penalty + botPens[index],
                highlighted: winner == bots[index].name,
                isPlayer: false,
                avatarAsset: bots[index].avatarAsset,
              ),
          ]
          ..sort((left, right) {
            final totalComparison = left.total.compareTo(right.total);
            if (totalComparison != 0) return totalComparison;
            return left.roundScore.compareTo(right.roundScore);
          });

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final panelSize = appArtworkPanelSize(
            bounds.copyWith(maxWidth: min(540, bounds.maxWidth)),
          );
          return RepaintBoundary(
            child: AppPopupSurface(
              key: const ValueKey('game-end-panel'),
              width: panelSize.width,
              height: panelSize.height,
              artworkAsset: appGameEndPanelAsset,
              padding: EdgeInsets.fromLTRB(
                panelSize.width * .035,
                panelSize.height * .255,
                panelSize.width * .035,
                panelSize.height * .10,
              ),

              child: LayoutBuilder(
                builder: (context, area) {
                  // Size the layout to both axes so height fitting cannot pull
                  // the score table and rewards into a narrow central column.
                  // Larger text needs extra room for the header and reward
                  // labels while keeping the taller score rows visible.
                  final textScaleSpace =
                      max(
                        0.0,
                        MediaQuery.textScalerOf(context).scale(16) - 16,
                      ) *
                      3.5;
                  final designHeight =
                      (reward == null ? 334.0 : 404.0) + textScaleSpace;
                  final scale = min(
                    area.maxWidth / 640,
                    area.maxHeight / designHeight,
                  );
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: area.maxWidth / scale,
                      height: designHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (reward != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _GameRewardCard(
                                reward: reward!,
                                round: elCount,
                                maxRounds: maxRounds,
                                leagueUpdate: leagueUpdate,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B281D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: OC.gold.withValues(alpha: 0.42),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    color: Colors.black.withValues(alpha: 0.22),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 42,
                                          child: _ScoreHeading(
                                            appText('SIRA', 'RANK'),
                                            alignment: Alignment.center,
                                          ),
                                        ),
                                        Expanded(
                                          child: _ScoreHeading(
                                            appText('OYUNCU', 'PLAYER'),
                                            alignment: Alignment.centerLeft,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 62,
                                          child: _ScoreHeading(
                                            appText('BU TUR', 'ROUND'),
                                            alignment: Alignment.center,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 62,
                                          child: _ScoreHeading(
                                            appText('TOPLAM', 'TOTAL'),
                                            alignment: Alignment.centerRight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...scoreRows.indexed.map((entry) {
                                    final rank = entry.$1 + 1;
                                    final row = entry.$2;
                                    return _ScoreRow(
                                      key: ValueKey('score-row-${row.name}'),
                                      rank: rank,
                                      name: row.name,
                                      avatarAsset: row.avatarAsset,
                                      elPen: row.roundScore,
                                      total: row.total,
                                      hi: row.highlighted,
                                      isPlayer: row.isPlayer,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: area.maxWidth / scale,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(60, 4, 68, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _EndActionButton(
                                      icon: Icons.restart_alt_rounded,
                                      label: appText(
                                        'YENİDEN BAŞLAT',
                                        'RESTART',
                                      ),
                                      artworkAsset: AppButtonAssets.restart,
                                      singleLine: true,
                                      onPressed: onResetMatch,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: matchComplete ? 3 : 4,
                                    child: _EndActionButton(
                                      icon: Icons.home_rounded,
                                      label: homeLabel,
                                      artworkAsset: AppButtonAssets.home,
                                      onPressed: onHome,
                                    ),
                                  ),
                                  if (!matchComplete) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 5,
                                      child: _EndActionButton(
                                        icon: Icons.play_arrow_rounded,
                                        label: appText('DEVAM ET', 'CONTINUE'),
                                        artworkAsset:
                                            AppButtonAssets.continueGame,
                                        onPressed: onNewRound,
                                        primary: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScoreHeading extends StatelessWidget {
  final String text;
  final Alignment alignment;
  const _ScoreHeading(this.text, {required this.alignment});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _GameRewardCard extends StatelessWidget {
  final GameReward reward;
  final int round;
  final int? maxRounds;
  final Future<LeagueRoundUpdate?>? leagueUpdate;

  const _GameRewardCard({
    required this.reward,
    required this.round,
    this.maxRounds,
    this.leagueUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final rewards =
        <({IconData icon, Color color, String value, String label})>[
          (
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF63C7FF),
            value: '+${reward.xp}',
            label: 'XP',
          ),
          (
            icon: Icons.monetization_on_rounded,
            color: OC.coinGold,
            value: '+${formatGameNumber(reward.coins)}',
            label: appText('ALTIN', 'GOLD'),
          ),
          (
            icon: Icons.flag_rounded,
            color: const Color(0xFF70DB80),
            value: maxRounds == null ? '$round' : '$round/$maxRounds',
            label: appText('TUR', 'ROUND'),
          ),
          (
            icon: Icons.leaderboard_rounded,
            color: OC.goldLight,
            value: '—',
            label: 'LİG',
          ),
        ];

    return Container(
      key: const ValueKey('game-reward-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF164A34), Color(0xFF0B2D20)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OC.gold.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < rewards.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 38,
                color: OC.gold.withValues(alpha: 0.22),
              ),
            Expanded(
              child: index == 3
                  ? _LeagueStandingCell(update: leagueUpdate)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (index == 1)
                          Image.asset(
                            'images/ui/coin.png',
                            width: 23,
                            height: 23,
                            cacheWidth: 62,
                            cacheHeight: 62,
                          )
                        else
                          Icon(
                            rewards[index].icon,
                            color: rewards[index].color,
                            size: 23,
                          ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${rewards[index].value} ${rewards[index].label}',
                              maxLines: 1,
                              style: TextStyle(
                                color: rewards[index].color,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeagueStandingCell extends StatelessWidget {
  const _LeagueStandingCell({this.update});
  final Future<LeagueRoundUpdate?>? update;
  @override
  Widget build(BuildContext context) => FutureBuilder<LeagueRoundUpdate?>(
    future: update,
    builder: (context, snapshot) {
      final result = snapshot.data;
      final delta = result?.placesGained ?? 0;
      final message = result == null
          ? update == null
                ? 'Bu masa lig dışı'
                : 'Sonuçlar hesaplanıyor'
          : !result.counted
          ? 'Lig tamamlandı'
          : result.previousRank == null
          ? 'İlk el tamamlandı'
          : delta > 0
          ? '$delta sıra yükseldin'
          : delta < 0
          ? '${-delta} sıra geriledin'
          : 'Sıran değişmedi';
      final color = delta > 0
          ? const Color(0xFF70DB80)
          : delta < 0
          ? OC.numRed
          : OC.goldLight;
      return Padding(
        key: const ValueKey('game-end-league-cell'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                result == null ? '— LİG' : '${result.rank}/20 LİG',
                style: TextStyle(
                  color: OC.goldLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ScoreRow extends StatelessWidget {
  final int rank;
  final String name;
  final String avatarAsset;
  final int elPen;
  final int total;
  final bool hi;
  final bool isPlayer;

  const _ScoreRow({
    super.key,
    required this.rank,
    required this.name,
    required this.avatarAsset,
    required this.elPen,
    required this.total,
    this.hi = false,
    this.isPlayer = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: isPlayer
          ? const Color(0xFF17633C).withValues(alpha: 0.52)
          : Colors.transparent,
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 2
                ? const Color(0xFFB9CAE0)
                : rank == 3
                ? const Color(0xFFC8794E)
                : rank == 1
                ? OC.goldLight
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: rank <= 3 ? Colors.white38 : Colors.white24,
            ),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: rank <= 3 ? const Color(0xFF33200A) : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 31,
          height: 31,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: hi ? OC.gold : Colors.white38),
          ),
          child: ClipOval(
            child: Image.asset(
              avatarAsset,
              fit: BoxFit.cover,
              cacheWidth: 62,
              cacheHeight: 62,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              if (isPlayer) ...[
                const Icon(
                  Icons.push_pin_rounded,
                  color: OC.goldLight,
                  size: 17,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: isPlayer || hi
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: isPlayer ? OC.gold : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 62,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              elPen > 0 ? '+$elPen' : '$elPen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: elPen > 0
                    ? const Color(0xFFFF7E74)
                    : const Color(0xFF70DB80),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 62,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$total',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EndActionButton extends StatelessWidget {
  final String artworkAsset;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool singleLine;

  const _EndActionButton({
    required this.artworkAsset,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) => _PressScale(
    child: AppArtworkButton(
      width: null,
      height: AppButtonMetrics.resultHeight,
      artworkAsset: artworkAsset,
      icon: icon,
      label: label,
      fontSize: singleLine ? 17 : (primary ? 22 : 20),
      outlinedText: true,
      maxLines: singleLine ? 1 : 2,
      onPressed: onPressed,
    ),
  );
}

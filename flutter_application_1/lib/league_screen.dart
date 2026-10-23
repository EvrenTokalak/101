import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'daily_league.dart';
import 'game_launch.dart';
import 'game_navigation.dart';
import 'player_progress.dart';
import 'store_cosmetics.dart';

const _leagueGold = Color(0xFFF0D563);
const _leagueCream = Color(0xFFFFF4DD);

class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});
  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _opening = false;
  ScrollController? _standingsScroll;
  ScrollController get _listScroll => _standingsScroll ??= ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(dailyLeague.load());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      dailyLeague.refresh();
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) dailyLeague.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _standingsScroll?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openGameScreen<void>(
        context,
        config: const GameLaunchConfig.quickPlay(),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([dailyLeague, playerProgress]),
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFF071B12),
      body: Stack(
        children: [
          Positioned.fill(child: StoreBackground(cacheWidth: 1440)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.18),
                  radius: 1.08,
                  colors: [
                    const Color(0xFF08763E).withValues(alpha: .12),
                    const Color(0xFF001B10).withValues(alpha: .42),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth > box.maxHeight * 1.25;
                final compact = box.maxHeight < 620 || box.maxWidth < 650;
                final summary = _sidebar(compact: compact);
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (box.maxWidth * .02).clamp(10.0, 32.0),
                    vertical: compact ? 8 : 16,
                  ),
                  child: Column(
                    children: [
                      _header(compact, short: box.maxHeight < 450),
                      SizedBox(height: compact ? 8 : 14),
                      Expanded(
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 20,
                                    child: _standings(
                                      compact,
                                      showPlayerSummary: box.maxHeight >= 500,
                                    ),
                                  ),
                                  SizedBox(width: compact ? 10 : 18),
                                  Expanded(flex: 9, child: summary),
                                ],
                              )
                            : Column(
                                children: [
                                  SizedBox(
                                    height: (box.maxHeight * .25).clamp(
                                      80.0,
                                      240.0,
                                    ),
                                    child: summary,
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: _standings(
                                      true,
                                      showPlayerSummary: box.maxHeight >= 500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(bool compact, {bool short = false}) => SizedBox(
    height: compact ? 48 : 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(left: compact ? 52 : 108, right: 108),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('GÜNLÜK LİG', style: _title(compact ? 26 : 40)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppBackButton(
            buttonKey: const ValueKey('league-back'),
            size: compact ? 44 : 52,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _leagueGold, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('images/ui/coin.png', width: compact ? 20 : 28),
                const SizedBox(width: 6),
                Text(
                  formatGameNumber(playerProgress.coins),
                  style: TextStyle(
                    color: _leagueCream,
                    fontSize: compact ? 12 : 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget _standings(
    bool compact, {
    bool showPlayerSummary = true,
  }) => _LeagueCard(
    compact: compact,
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.leaderboard_rounded,
              color: _leagueGold,
              size: compact ? 24 : 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIRALAMA', style: _title(compact ? 19 : 25)),
                  Text(
                    'En düşük ceza puanı lider olur',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 10 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 10),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0x442A6731),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 35 : 48,
                child: Text('SIRA', style: _label(compact)),
              ),
              Expanded(child: Text('OYUNCU', style: _label(compact))),
              Text('CEZA', style: _label(compact)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _listScroll,
                  key: const ValueKey('league-standings'),
                  itemCount: dailyLeague.standings.length,
                  itemBuilder: (context, index) {
                    final entry = dailyLeague.standings[index];
                    final highlight = entry.isPlayer;
                    final leading =
                        dailyLeague.completedRounds > 0 && entry.rank == 1;
                    final medalColor = dailyLeague.completedRounds == 0
                        ? Colors.white54
                        : switch (entry.rank) {
                            1 => _leagueGold,
                            2 => const Color(0xFFCCD7DC),
                            3 => const Color(0xFFD79B55),
                            _ => Colors.white70,
                          };
                    return Container(
                      key: ValueKey('league-entry-${entry.id}'),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: compact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: highlight || leading
                              ? const [Color(0x99558128), Color(0x6628431C)]
                              : const [Color(0x33234E30), Color(0x44001810)],
                        ),
                        borderRadius: BorderRadius.circular(highlight ? 10 : 0),
                        border: highlight
                            ? Border.all(color: _leagueGold, width: 1.5)
                            : Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: .08),
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: compact ? 35 : 48,
                            child: Text(
                              dailyLeague.completedRounds == 0
                                  ? '—'
                                  : '${entry.rank}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: medalColor,
                                fontSize: compact ? 18 : 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: compact ? 16 : 23,
                            backgroundColor: const Color(0xFF355341),
                            backgroundImage: ResizeImage(
                              AssetImage(entry.avatar),
                              width: 64,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              highlight ? '${entry.name} · SEN' : entry.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: highlight ? _leagueGold : _leagueCream,
                                fontSize: compact ? 13 : 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            dailyLeague.completedRounds == 0
                                ? '—'
                                : formatGameNumber(entry.penalty),
                            key: ValueKey('league-penalty-${entry.id}'),
                            style: TextStyle(
                              color: _leagueCream,
                              fontSize: compact ? 15 : 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _listScroll,
                    builder: (context, _) {
                      final position = _listScroll.hasClients
                          ? _listScroll.positions.last
                          : null;
                      final atTop =
                          position == null ||
                          !position.hasPixels ||
                          position.pixels <= 1;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: !atTop
                            ? const SizedBox.shrink(
                                key: ValueKey('league-arrow-hidden'),
                              )
                            : SizedBox(
                                key: const ValueKey('league-arrow-visible'),
                                width: 48,
                                height: 28,
                                child: Material(
                                  key: const ValueKey('league-scroll-hint'),
                                  color: _leagueGold,
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      if (!_listScroll.hasClients) return;
                                      final position =
                                          _listScroll.positions.last;
                                      if (!position.hasContentDimensions) {
                                        return;
                                      }
                                      _listScroll.animateTo(
                                        (position.pixels +
                                                position.viewportDimension * .7)
                                            .clamp(
                                              0.0,
                                              position.maxScrollExtent,
                                            ),
                                        duration: const Duration(
                                          milliseconds: 320,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    },
                                    child: const Center(
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                        size: 27,
                                        semanticLabel:
                                            'Diğer yarışmacıları göster',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (showPlayerSummary) ...[
          _playerStanding(compact),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Tümü ${dailyLeague.completedRounds} el oynadı',
                style: _label(compact),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _playerStanding(bool compact) {
    final player = dailyLeague.standings.firstWhere((entry) => entry.isPlayer);
    return Container(
      key: const ValueKey('league-player-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF244C35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _leagueGold.withValues(alpha: .6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: _leagueGold, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              dailyLeague.completedRounds == 0
                  ? 'SEN · Henüz el oynamadın'
                  : 'SEN · ${player.rank}. sıra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _label(compact).copyWith(color: _leagueGold),
            ),
          ),
          if (dailyLeague.completedRounds > 0)
            Text(
              '${formatGameNumber(player.penalty)} ceza',
              style: _label(compact).copyWith(color: _leagueCream),
            ),
        ],
      ),
    );
  }

  Widget _sidebar({required bool compact}) => LayoutBuilder(
    builder: (context, bounds) => FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: bounds.maxWidth,
        height: compact ? 332 : 390,
        child: Column(
          children: [
            _LeagueCard(
              compact: true,
              gold: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: _leagueGold,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LİG BİTİMİNE', style: _label(false)),
                        FittedBox(
                          child: Text(
                            dailyLeague.remainingText,
                            key: const ValueKey('league-countdown'),
                            style: _title(compact ? 28 : 36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _LeagueCard(
                compact: true,
                gold: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İLK 3 ÖDÜLLERİ', style: _title(compact ? 17 : 21)),
                    const SizedBox(height: 6),
                    for (final rank in [1, 2, 3])
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: rank.isOdd
                                ? const Color(0x243F7A3A)
                                : Colors.transparent,
                            border: const Border(
                              bottom: BorderSide(color: Color(0x334B8B46)),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: compact ? 21 : 26,
                                  color: rank == 1
                                      ? _leagueGold
                                      : rank == 2
                                      ? const Color(0xFFCCD7DC)
                                      : const Color(0xFFD79B55),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$rank. sıra',
                                    style: _label(false),
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${formatGameNumber(LeaguePrize.forRank(rank).coins)} altın',
                                      style: TextStyle(
                                        color: _leagueCream,
                                        fontSize: compact ? 15 : 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: compact ? 54 : 66,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF287C22), Color(0xFF6BD944)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _leagueGold, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x444DD72C), blurRadius: 10),
                  ],
                ),
                child: TextButton(
                  key: const ValueKey('league-play'),
                  onPressed: _opening ? null : _play,
                  style: TextButton.styleFrom(
                    foregroundColor: _leagueCream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 32),
                        const SizedBox(width: 8),
                        Text('HEMEN OYNA', style: _title(compact ? 23 : 28)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Süre bitene kadar oynadığın eller ligine sayılır',
              textAlign: TextAlign.center,
              style: _label(compact),
            ),
          ],
        ),
      ),
    ),
  );

  TextStyle _title(double size) => TextStyle(
    color: _leagueCream,
    fontFamily: 'Baloo 2',
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );
  TextStyle _label(bool compact) => TextStyle(
    color: const Color(0xFFB5CCAB),
    fontSize: compact ? 10 : 13,
    fontWeight: FontWeight.w700,
  );
}

class _LeagueCard extends StatelessWidget {
  final Widget child;
  final bool gold;
  final bool compact;
  const _LeagueCard({
    required this.child,
    this.gold = false,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(compact ? 8 : 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xEF193D25), Color(0xF00A1D12)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _leagueGold, width: 1.7),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x665C9B50)),
      ),
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    ),
  );
}

/// Shared home summary. A saved deadline survives closing and reopening the app.
class HomeLeagueSummary extends StatefulWidget {
  final VoidCallback onTap;
  const HomeLeagueSummary({super.key, required this.onTap});
  @override
  State<HomeLeagueSummary> createState() => _HomeLeagueSummaryState();
}

class _HomeLeagueSummaryState extends State<HomeLeagueSummary>
    with WidgetsBindingObserver {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(dailyLeague.load());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      dailyLeague.refresh();
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) dailyLeague.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([dailyLeague, appLanguage]),
    builder: (context, _) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AppPressable(
          onTap: widget.onTap,
          child: Container(
            key: const ValueKey('home-league-summary'),
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xC0103220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _leagueGold.withValues(alpha: .55)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: _leagueGold,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '${appText('Lig', 'League', german: 'Liga')} · '
                    '${dailyLeague.completedRounds == 0 ? appText('İlk elini tamamla', 'Complete your first hand', german: 'Spiele deine erste Runde') : appText('${dailyLeague.playerRank}. sıra', 'Rank ${dailyLeague.playerRank}', german: 'Platz ${dailyLeague.playerRank}')} · '
                    '${dailyLeague.completedRounds} ${appText('el', 'hands', german: 'Runden')} · ${dailyLeague.remainingText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _leagueCream,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

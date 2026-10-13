import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'app_settings_dialog.dart';
import 'daily_league.dart';
import 'game_launch.dart';
import 'game_navigation.dart';
import 'league_reminder.dart';
import 'player_progress.dart';

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
          Positioned.fill(
            child: Image.asset(
              'images/anamenu/menubg.png',
              fit: BoxFit.cover,
              cacheWidth: 1440,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF071B12).withValues(alpha: .58),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final wide =
                    box.maxWidth / box.maxHeight > 1.2 || box.maxHeight < 480;
                final compact = box.maxHeight < 620 || box.maxWidth < 650;
                final summary = _sidebar(compact: compact);
                return Padding(
                  padding: EdgeInsets.all(compact ? 10 : 20),
                  child: Column(
                    children: [
                      _header(compact),
                      SizedBox(height: compact ? 8 : 14),
                      Expanded(
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 17,
                                    child: _standings(compact),
                                  ),
                                  SizedBox(width: compact ? 10 : 18),
                                  Expanded(flex: 10, child: summary),
                                ],
                              )
                            : Column(
                                children: [
                                  SizedBox(
                                    height: box.maxHeight < 650 ? 190 : 270,
                                    child: summary,
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(child: _standings(true)),
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

  Widget _header(bool compact) => SizedBox(
    height: compact ? 78 : 106,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 42 : 60,
          child: AppBackButton(
            buttonKey: const ValueKey('league-back'),
            size: compact ? 38 : 52,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GÜNLÜK LİG',
                  style: TextStyle(
                    color: _leagueCream,
                    fontFamily: 'Baloo 2',
                    fontSize: compact ? 26 : 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(0, 3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '20 YARIŞMACI',
                  style: TextStyle(
                    color: _leagueCream,
                    fontSize: compact ? 11 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: compact ? 13 : 17,
                      color: const Color(0xFFB7C7AD),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'İlk 3’e ${[1, 2, 3].map((rank) => formatGameNumber(LeaguePrize.forRank(rank).coins)).join(' · ')} altın',
                      key: const ValueKey('league-prize-summary'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: compact ? 10 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _leagueGold, width: 1.2),
          ),
          child: Row(
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
      ],
    ),
  );

  Widget _standings(bool compact) => _LeagueCard(
    compact: compact,
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.leaderboard_rounded,
              color: const Color(0xFF9AB29D),
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
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              Scrollbar(
                controller: _listScroll,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _listScroll,
                  key: const ValueKey('league-standings'),
                  itemCount: dailyLeague.standings.length,
                  itemBuilder: (context, index) {
                    final entry = dailyLeague.standings[index];
                    final highlight = entry.isPlayer;
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
                        color: highlight
                            ? const Color(0x553F783C)
                            : Colors.black12,
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
                          if (!highlight && !compact)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BOT',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
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

  Widget _summary({required bool compact}) => Column(
    children: [
      _LeagueCard(
        compact: compact,
        gold: true,
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              color: const Color(0xFF9AB29D),
              size: compact ? 25 : 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LİG BİTİMİNE', style: _label(compact)),
                  Text(
                    dailyLeague.remainingText,
                    key: const ValueKey('league-countdown'),
                    style: _title(compact ? 23 : 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: compact ? 6 : 10),
      _LeagueCard(
        compact: compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dailyLeague.complete
                  ? 'GÜNLÜK SONUCUN KESİNLEŞTİ'
                  : 'BUGÜNKÜ İLERLEMEN',
              style: _title(compact ? 13 : 17),
            ),
            const SizedBox(height: 4),
            Text(
              '${dailyLeague.completedRounds} / 20 EL',
              key: const ValueKey('league-progress'),
              style: _title(compact ? 25 : 36),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: dailyLeague.completedRounds / leagueRoundLimit,
                minHeight: compact ? 9 : 14,
                backgroundColor: Colors.black38,
                color: const Color(0xFF6DA77E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dailyLeague.completedRounds == 0
                  ? 'İlk elini oyna, sıralamaya katıl'
                  : 'Sıran: ${dailyLeague.playerRank} / 20',
              style: TextStyle(
                color: _leagueCream,
                fontSize: compact ? 14 : 18,
              ),
            ),
          ],
        ),
      ),
      if (leagueReminder.supported)
        TextButton.icon(
          onPressed: appSettings.value.notifications
              ? () async {
                  final allowed = await leagueReminder.requestPermission();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        allowed ? 'Son 1 saat için hatırlatıcı açık.' : 'Hatırlatıcı için telefon ayarlarından bildirim izni ver.',
                      ),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.notifications_active_outlined, size: 17),
          label: const Text('Son 1 saat hatırlatıcısı'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF9AB29D)),
        ),
    ],
  );

  Widget _sidebar({required bool compact}) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(child: _summary(compact: compact)),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: compact ? 46 : 62,
        child: ElevatedButton(
          key: const ValueKey('league-play'),
          onPressed: _opening ? null : _play,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF409B32),
            foregroundColor: _leagueCream,
            side: const BorderSide(color: _leagueGold, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HEMEN OYNA',
              maxLines: 1,
              style: _title(compact ? 19 : 27),
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        dailyLeague.complete
            ? 'Oynamaya devam et · Lig toplamın sabit'
            : 'Oynadığın ilk 20 el günlük ligine sayılır',
        textAlign: TextAlign.center,
        style: _label(compact),
      ),
    ],
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
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: gold ? _leagueGold : const Color(0xFFB5A641),
        width: 1.4,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: child,
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
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                '${dailyLeague.completedRounds}/20 ${appText('el', 'hands', german: 'Runden')} · ${dailyLeague.remainingText}',
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
  );
}

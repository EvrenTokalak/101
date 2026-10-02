import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_controls.dart';
import 'game_launch.dart';
import 'game_navigation.dart';

const _tournamentCycleDuration = Duration(hours: 24);
const _tournamentDeadlineKey = 'tournament.deadline_ms';

Future<DateTime> initializeTournamentCycle() async {
  final now = DateTime.now();
  SharedPreferencesAsync? preferences;
  int? saved;
  try {
    preferences = SharedPreferencesAsync();
    saved = await preferences.getInt(_tournamentDeadlineKey);
  } catch (_) {}
  var deadline = saved == null
      ? now.add(_tournamentCycleDuration)
      : DateTime.fromMillisecondsSinceEpoch(saved);
  while (!deadline.isAfter(now)) {
    deadline = deadline.add(_tournamentCycleDuration);
  }
  try {
    if (preferences == null) return deadline;
    await preferences.setInt(
      _tournamentDeadlineKey,
      deadline.millisecondsSinceEpoch,
    );
  } catch (_) {}
  return deadline;
}

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  static const _roundNames = ['ÇEYREK FİNAL', 'YARI FİNAL', 'FİNAL'];
  int _round = 0;
  bool _eliminated = false;
  bool _champion = false;
  bool _matchStarted = false;
  DateTime? _deadline;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadDeadline();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeadline() async {
    final deadline = await initializeTournamentCycle();
    if (!mounted) return;
    setState(() => _deadline = deadline);
    _startTicker();
  }

  Future<void> _activateCountdown() async {
    if (_deadline != null && _deadline!.isAfter(DateTime.now())) return;
    final deadline = await initializeTournamentCycle();
    if (!mounted) return;
    setState(() => _deadline = deadline);
    _startTicker();
  }

  void _startTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _deadline == null) return;
      if (!TickerMode.valuesOf(context).enabled) return;
      if (!_deadline!.isAfter(DateTime.now())) {
        final nextDeadline = await initializeTournamentCycle();
        if (!mounted) return;
        setState(() {
          _deadline = nextDeadline;
          _round = 0;
          _eliminated = false;
          _champion = false;
          _matchStarted = false;
        });
      } else {
        setState(() {});
      }
    });
  }

  String get _remainingText {
    final deadline = _deadline;
    if (deadline == null) return '--:--:--';
    final seconds = deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 86400);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    final time =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return appText('$time kaldı', '$time left');
  }

  Future<void> _startMatch() async {
    await _activateCountdown();
    if (!mounted) return;
    setState(() => _matchStarted = true);
    final won = await openGameScreen<bool>(
      context,
      config: GameLaunchConfig.tournament(
        round: _round,
        roundLabel: _roundNames[_round],
      ),
    );
    if (!mounted || won == null) return;
    setState(() {
      _matchStarted = false;
      if (!won) {
        _eliminated = true;
      } else if (_round == 2) {
        _champion = true;
      } else {
        _round++;
      }
    });
  }

  void _restart() => setState(() {
    _round = 0;
    _eliminated = false;
    _champion = false;
    _matchStarted = false;
  });

  Future<void> _restartAndStart() async {
    _restart();
    await _startMatch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061B13),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 760;
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [Color(0xFF12623B), Color(0xFF04130E)],
                ),
              ),
              child: Column(
                children: [
                  _TournamentHeader(
                    onBack: () => Navigator.of(context).pop(),
                    remainingText: _remainingText,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 920,
                            height: 360,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  appText(
                                    '${_round + 1}. AŞAMA · 3 TUR',
                                    'STAGE ${_round + 1} · 3 ROUNDS',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  appText(
                                    'Üç turun sonunda toplam puanı en düşük oyuncu bir sonraki aşamaya yükselir.',
                                    'After three rounds, the player with the lowest total score advances.',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const _TournamentInfoStrip(),
                                const SizedBox(height: 22),
                                _StageTrack(
                                  activeRound: _round,
                                  eliminated: _eliminated,
                                  champion: _champion,
                                  compact: compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      box.maxWidth * 0.06,
                      8,
                      box.maxWidth * 0.06,
                      box.maxHeight * 0.035,
                    ),
                    child: _TournamentAction(
                      roundName: _roundNames[_round],
                      eliminated: _eliminated,
                      champion: _champion,
                      matchStarted: _matchStarted,
                      onStart: _startMatch,
                      onRestart: _restart,
                      onRestartAndStart: _restartAndStart,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TournamentInfoStrip extends StatelessWidget {
  const _TournamentInfoStrip();

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      children: [
        _TournamentInfoChip(
          icon: Icons.groups_rounded,
          title: appText('4 OYUNCU', '4 PLAYERS'),
          subtitle: appText('Bireysel masa', 'Solo table'),
        ),
        const SizedBox(width: 10),
        _TournamentInfoChip(
          icon: Icons.stacked_bar_chart_rounded,
          title: appText('3 TUR', '3 ROUNDS'),
          subtitle: appText('Her aşamada', 'Each stage'),
        ),
        const SizedBox(width: 10),
        _TournamentInfoChip(
          icon: Icons.south_rounded,
          title: appText('EN DÜŞÜK PUAN', 'LOWEST SCORE'),
          subtitle: appText('Aşamayı geçer', 'Advances'),
        ),
        const SizedBox(width: 10),
        _TournamentInfoChip(
          icon: Icons.emoji_events_rounded,
          title: appText('ALTIN ÖDÜL', 'GOLD REWARD'),
          subtitle: appText('Aşamayla artar', 'Grows by stage'),
        ),
      ],
    ),
  );
}

class _TournamentInfoChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TournamentInfoChip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 222,
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x66FFD76A)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD76A), size: 32),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StageTrack extends StatelessWidget {
  final int activeRound;
  final bool eliminated;
  final bool champion;
  final bool compact;

  const _StageTrack({
    required this.activeRound,
    required this.eliminated,
    required this.champion,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: compact ? 680 : 920,
      height: 135,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 70,
            right: 70,
            top: 42,
            child: Container(height: 7, color: const Color(0xFF34443C)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final reached = (index <= activeRound && !eliminated) || champion;
              return SizedBox(
                width: 140,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? const Color(0xFFC99B2E)
                            : const Color(0xFF17201C),
                        border: Border.all(
                          color: reached
                              ? const Color(0xFFFFDD68)
                              : Colors.white24,
                          width: reached ? 5 : 3,
                        ),
                        boxShadow: reached
                            ? const [
                                BoxShadow(
                                  color: Color(0x88F5C84A),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: reached ? Colors.white : Colors.white38,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      appLanguage.isEnglish
                          ? const [
                              'QUARTER FINAL',
                              'SEMI FINAL',
                              'FINAL',
                            ][index]
                          : _TournamentScreenState._roundNames[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: reached
                            ? const Color(0xFFFFD85F)
                            : Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
}

class _TournamentHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String remainingText;
  const _TournamentHeader({required this.onBack, required this.remainingText});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: const BoxDecoration(
      color: Color(0xDD09130F),
      border: Border(bottom: BorderSide(color: Color(0xFFC99632))),
    ),
    child: Row(
      children: [
        AppBackButton(
          buttonKey: const ValueKey('tournament-back'),
          onTap: onBack,
          size: 42,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                appText('ALTIN ISTAKA TURNUVASI', 'GOLD RACK TOURNAMENT'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                appText(
                  '3 aşama · Her aşamada 3 tur · $remainingText',
                  '3 stages · 3 rounds each · $remainingText',
                ),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 48,
          child: Icon(Icons.emoji_events, color: Color(0xFFFFD45A)),
        ),
      ],
    ),
  );
}

class _TournamentAction extends StatelessWidget {
  final String roundName;
  final bool eliminated;
  final bool champion;
  final bool matchStarted;
  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onRestartAndStart;
  const _TournamentAction({
    required this.roundName,
    required this.eliminated,
    required this.champion,
    required this.matchStarted,
    required this.onStart,
    required this.onRestart,
    required this.onRestartAndStart,
  });

  @override
  Widget build(BuildContext context) {
    final title = champion
        ? appText('TURNUVA ŞAMPİYONU!', 'TOURNAMENT CHAMPION!')
        : eliminated
        ? appText('TURNUVADAN ELENDİN', 'ELIMINATED')
        : appText('$roundName · 4 KİŞİLİK MASA', '$roundName · 4 PLAYER TABLE');
    final titleWidget = Text(
      title,
      style: TextStyle(
        color: champion ? const Color(0xFFFFD45A) : Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    );
    final primaryButton = FilledButton.icon(
      key: const ValueKey('tournament-action'),
      onPressed: eliminated || champion ? onRestart : onStart,
      style: FilledButton.styleFrom(
        backgroundColor: eliminated || champion
            ? const Color(0xFF8B5A17)
            : const Color(0xFF16863C),
        foregroundColor: Colors.white,
      ),
      icon: Icon(
        eliminated || champion
            ? Icons.refresh
            : matchStarted
            ? Icons.play_arrow_rounded
            : Icons.sports_esports,
      ),
      label: Text(
        eliminated || champion
            ? appText('YENİDEN BAŞLA', 'START OVER')
            : matchStarted
            ? appText('DEVAM ET', 'CONTINUE')
            : appText('MAÇA BAŞLA', 'START MATCH'),
      ),
    );

    if (matchStarted && !eliminated && !champion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('tournament-restart'),
                onPressed: onRestartAndStart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD76A),
                  side: const BorderSide(color: Color(0xFFC99632)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(appText('TEKRAR BAŞLA', 'RESTART')),
              ),
              const SizedBox(width: 8),
              primaryButton,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleWidget),
        primaryButton,
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_launch.dart';
import 'game_navigation.dart';

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
  static const _deadlineKey = 'tournament.deadline_ms';
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
    final preferences = SharedPreferencesAsync();
    final millis = await preferences.getInt(_deadlineKey);
    if (!mounted || millis == null) return;
    final deadline = DateTime.fromMillisecondsSinceEpoch(millis);
    if (deadline.isAfter(DateTime.now())) {
      setState(() => _deadline = deadline);
      _startTicker();
    } else {
      await preferences.remove(_deadlineKey);
    }
  }

  Future<void> _activateCountdown() async {
    if (_deadline != null && _deadline!.isAfter(DateTime.now())) return;
    final deadline = DateTime.now().add(const Duration(hours: 24));
    setState(() => _deadline = deadline);
    await SharedPreferencesAsync().setInt(
      _deadlineKey,
      deadline.millisecondsSinceEpoch,
    );
    _startTicker();
  }

  void _startTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _deadline == null) return;
      if (!TickerMode.valuesOf(context).enabled) return;
      if (!_deadline!.isAfter(DateTime.now())) {
        _countdownTimer?.cancel();
        setState(() {
          _deadline = null;
          _round = 0;
          _eliminated = false;
          _champion = false;
          _matchStarted = false;
        });
        SharedPreferencesAsync().remove(_deadlineKey);
      } else {
        setState(() {});
      }
    });
  }

  String get _remainingText {
    final deadline = _deadline;
    if (deadline == null) return 'İlk maçla 24 saat başlar';
    final seconds = deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 86400);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} kaldı';
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: box.maxWidth * 0.04,
                        vertical: box.maxHeight * 0.025,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_round + 1}. AŞAMA · 3 EL',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '3 el sonunda toplam puanı en düşük oyuncu ilerler.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          _StageTrack(
                            activeRound: _round,
                            eliminated: _eliminated,
                            champion: _champion,
                            compact: compact,
                          ),
                          const Spacer(),
                        ],
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
                      _TournamentScreenState._roundNames[index],
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
        IconButton(
          key: const ValueKey('tournament-back'),
          onPressed: onBack,
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'ALTIN ISTAKA TURNUVASI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '3 aşama · Her aşamada 3 el · $remainingText',
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
        ? 'TURNUVA ŞAMPİYONU!'
        : eliminated
        ? 'TURNUVADAN ELENDİN'
        : '$roundName · 4 KİŞİLİK MASA';
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
            ? 'YENİDEN BAŞLA'
            : matchStarted
            ? 'DEVAM ET'
            : 'MAÇA BAŞLA',
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
                label: const Text('TEKRAR BAŞLA'),
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

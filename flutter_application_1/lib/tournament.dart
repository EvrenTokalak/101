import 'package:flutter/material.dart';

import 'game_launch.dart';
import 'game_navigation.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  static const _roundNames = ['ÇEYREK FİNAL', 'YARI FİNAL', 'FİNAL'];
  static const _opponents = ['Deniz', 'Efe', 'Şampiyon Ada'];
  int _round = 0;
  bool _eliminated = false;
  bool _champion = false;

  Future<void> _startMatch() async {
    final won = await openGameScreen<bool>(
      context,
      config: GameLaunchConfig.tournament(
        round: _round,
        roundLabel: _roundNames[_round],
        opponent: _opponents[_round],
      ),
    );
    if (!mounted || won == null) return;
    setState(() {
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
  });

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
                  _TournamentHeader(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: box.maxWidth * 0.04,
                        vertical: box.maxHeight * 0.025,
                      ),
                      child: compact
                          ? _CompactBracket(
                              activeRound: _round,
                              eliminated: _eliminated,
                              champion: _champion,
                            )
                          : _WideBracket(
                              activeRound: _round,
                              eliminated: _eliminated,
                              champion: _champion,
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
                      opponent: _opponents[_round],
                      eliminated: _eliminated,
                      champion: _champion,
                      onStart: _startMatch,
                      onRestart: _restart,
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

class _TournamentHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _TournamentHeader({required this.onBack});

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
        const Expanded(
          child: Column(
            children: [
              Text(
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
                'Üç maç · Tek şampiyon',
                style: TextStyle(color: Colors.white60, fontSize: 10),
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

class _WideBracket extends StatelessWidget {
  final int activeRound;
  final bool eliminated;
  final bool champion;
  const _WideBracket({
    required this.activeRound,
    required this.eliminated,
    required this.champion,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (round) {
      final reached = round <= activeRound && !eliminated || champion;
      final won = round < activeRound || champion;
      return Expanded(
        child: Row(
          children: [
            Expanded(
              child: _RoundColumn(round: round, reached: reached, won: won),
            ),
            if (round < 2)
              Expanded(
                flex: 0,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 34,
                  color: won ? const Color(0xFFFFCF52) : Colors.white24,
                ),
              ),
          ],
        ),
      );
    }),
  );
}

class _CompactBracket extends StatelessWidget {
  final int activeRound;
  final bool eliminated;
  final bool champion;
  const _CompactBracket({
    required this.activeRound,
    required this.eliminated,
    required this.champion,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(3, (round) {
      final reached = round <= activeRound && !eliminated || champion;
      final won = round < activeRound || champion;
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: _RoundColumn(round: round, reached: reached, won: won),
            ),
            if (round < 2)
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: won ? const Color(0xFFFFCF52) : Colors.white24,
              ),
          ],
        ),
      );
    }),
  );
}

class _RoundColumn extends StatelessWidget {
  final int round;
  final bool reached;
  final bool won;
  const _RoundColumn({
    required this.round,
    required this.reached,
    required this.won,
  });

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _TournamentScreenState._roundNames[round],
          style: TextStyle(
            color: reached ? const Color(0xFFFFD76A) : Colors.white38,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _MatchCard(
          player: 'OYUNCU 1',
          opponent: _TournamentScreenState._opponents[round],
          reached: reached,
          won: won,
        ),
        if (round == 0) ...[
          const SizedBox(height: 10),
          const _MatchCard(
            player: 'Mert',
            opponent: 'Selin',
            reached: true,
            won: false,
          ),
        ],
      ],
    ),
  );
}

class _MatchCard extends StatelessWidget {
  final String player;
  final String opponent;
  final bool reached;
  final bool won;
  const _MatchCard({
    required this.player,
    required this.opponent,
    required this.reached,
    required this.won,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 190,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: reached ? const Color(0xEE121A16) : const Color(0x99101412),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: won
            ? const Color(0xFFFFD45A)
            : reached
            ? const Color(0xFF55936C)
            : Colors.white12,
        width: won ? 2 : 1,
      ),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
    ),
    child: Column(
      children: [
        _Competitor(name: player, highlighted: reached),
        const Divider(color: Colors.white12, height: 10),
        _Competitor(name: opponent, highlighted: false),
      ],
    ),
  );
}

class _Competitor extends StatelessWidget {
  final String name;
  final bool highlighted;
  const _Competitor({required this.name, required this.highlighted});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.person_rounded,
        size: 17,
        color: highlighted ? const Color(0xFFFFD45A) : Colors.white54,
      ),
      const SizedBox(width: 7),
      Text(
        name,
        style: TextStyle(
          color: highlighted ? Colors.white : Colors.white60,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    ],
  );
}

class _TournamentAction extends StatelessWidget {
  final String roundName;
  final String opponent;
  final bool eliminated;
  final bool champion;
  final VoidCallback onStart;
  final VoidCallback onRestart;
  const _TournamentAction({
    required this.roundName,
    required this.opponent,
    required this.eliminated,
    required this.champion,
    required this.onStart,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final title = champion
        ? 'TURNUVA ŞAMPİYONU!'
        : eliminated
        ? 'TURNUVADAN ELENDİN'
        : '$roundName · Rakip: $opponent';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: champion ? const Color(0xFFFFD45A) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('tournament-action'),
          onPressed: eliminated || champion ? onRestart : onStart,
          style: FilledButton.styleFrom(
            backgroundColor: eliminated || champion
                ? const Color(0xFF8B5A17)
                : const Color(0xFF16863C),
            foregroundColor: Colors.white,
          ),
          icon: Icon(
            eliminated || champion ? Icons.refresh : Icons.sports_esports,
          ),
          label: Text(eliminated || champion ? 'YENİDEN BAŞLA' : 'MAÇA BAŞLA'),
        ),
      ],
    );
  }
}

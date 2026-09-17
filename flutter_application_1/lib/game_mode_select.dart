import 'package:flutter/material.dart';

import 'game_launch.dart';
import 'game_navigation.dart';
import 'main.dart';
import 'player_progress.dart';

class GameModeSelectScreen extends StatefulWidget {
  const GameModeSelectScreen({super.key});

  @override
  State<GameModeSelectScreen> createState() => _GameModeSelectScreenState();
}

class _GameModeSelectScreenState extends State<GameModeSelectScreen>
    with SingleTickerProviderStateMixin {
  static const _modes = [
    _GameModeData(
      id: 'elimination-101',
      label: 'Eliminasyon 101',
      subtitle: 'Tekli mücadele · Standart 101 kuralları',
      badge: 'KLASİK TEMPO',
      icon: Icons.filter_1_rounded,
      accent: Color(0xFF4CAF50),
      accentDark: Color(0xFF174F25),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.classic101,
        id: 'elimination-101',
        label: 'Eliminasyon 101',
      ),
      features: ['4 kişilik masa', '101 puanla açılış', 'Bireysel sıralama'],
    ),
    _GameModeData(
      id: 'paired-101',
      label: 'Eşli 101',
      subtitle: 'Takım arkadaşınla birlikte mücadele et',
      badge: 'TAKIM MODU',
      icon: Icons.groups_2_rounded,
      accent: Color(0xFF2196F3),
      accentDark: Color(0xFF0D3D73),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.paired101,
        id: 'paired-101',
        label: 'Eşli 101',
      ),
      features: ['2 kişilik takımlar', 'Ortak takım puanı', 'Stratejik oyun'],
    ),
    _GameModeData(
      id: 'progressive',
      label: 'Katlamalı',
      subtitle: 'Her elde riskin ve ödülün yükseldiği oyun',
      badge: 'YÜKSEK RİSK',
      icon: Icons.add_chart_rounded,
      accent: Color(0xFFE0A126),
      accentDark: Color(0xFF704308),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      ),
      features: ['Artan oyun değeri', 'Katlanan ceza', 'Yüksek ödül'],
    ),
  ];

  late final AnimationController _controller;
  late final Animation<double> _entrance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSelectedMode() async {
    await openGameScreen<void>(context, config: _modes[_selectedIndex].config);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _modes[_selectedIndex];
    return Scaffold(
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/anamenu/menubg.png',
              fit: BoxFit.cover,
              cacheWidth: 1440,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.24)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final canvasWidth = maxOf(viewport.maxWidth, 900);
                final canvasHeight = maxOf(viewport.maxHeight, 600);
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: FadeTransition(
                        opacity: _entrance,
                        child: Column(
                          children: [
                            const _ModeTopBar(),
                            const SizedBox(height: 16),
                            const _ModeTitle(),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 34,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: List.generate(_modes.length, (
                                    index,
                                  ) {
                                    final isSelected = index == _selectedIndex;
                                    return Expanded(
                                      flex: isSelected ? 11 : 10,
                                      child: _ModeCard(
                                        mode: _modes[index],
                                        selected: isSelected,
                                        onTap: () => setState(
                                          () => _selectedIndex = index,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ModeBottomBar(
                              mode: selected,
                              onStart: _startSelectedMode,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

double maxOf(double value, double minimum) => value < minimum ? minimum : value;

class _GameModeData {
  final String id;
  final String label;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accent;
  final Color accentDark;
  final GameLaunchConfig config;
  final List<String> features;

  const _GameModeData({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.accentDark,
    required this.config,
    required this.features,
  });
}

class _ModeTopBar extends StatelessWidget {
  const _ModeTopBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        GestureDetector(
          key: const ValueKey('game-mode-back'),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: OkeyColors.gold.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: OkeyColors.cream,
              size: 16,
            ),
          ),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: playerProgress,
          builder: (_, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OkeyColors.gold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: OkeyColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  formatGameNumber(playerProgress.coins),
                  style: const TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ModeTitle extends StatelessWidget {
  const _ModeTitle();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text(
        'Oyun Modu Seç',
        style: TextStyle(
          color: OkeyColors.goldLight,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        width: 170,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              OkeyColors.gold.withValues(alpha: 0.75),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ],
  );
}

class _ModeCard extends StatelessWidget {
  final _GameModeData mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('game-mode-card-${mode.id}'),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.fromLTRB(8, selected ? 0 : 13, 8, selected ? 0 : 13),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selected
              ? [
                  mode.accentDark.withValues(alpha: 0.92),
                  OkeyColors.tableDark.withValues(alpha: 0.97),
                ]
              : [
                  OkeyColors.tableMid.withValues(alpha: 0.76),
                  OkeyColors.tableDark.withValues(alpha: 0.9),
                ],
        ),
        border: Border.all(
          color: selected
              ? mode.accent
              : OkeyColors.gold.withValues(alpha: 0.28),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: mode.accent.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: 3,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: mode.accent.withValues(alpha: selected ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mode.accent.withValues(alpha: selected ? 0.8 : 0.35),
              ),
            ),
            child: Text(
              mode.badge,
              style: TextStyle(
                color: mode.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Column(
            children: [
              Icon(mode.icon, color: mode.accent, size: selected ? 60 : 52),
              const SizedBox(height: 14),
              Text(
                mode.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : OkeyColors.cream,
                  fontSize: selected ? 20 : 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Georgia',
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mode.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OkeyColors.cream.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
          Column(
            children: mode.features
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: mode.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: OkeyColors.cream.withValues(alpha: 0.82),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class _ModeBottomBar extends StatelessWidget {
  final _GameModeData mode;
  final VoidCallback onStart;

  const _ModeBottomBar({required this.mode, required this.onStart});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 34),
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mode.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Icon(mode.icon, color: mode.accent, size: 24),
                const SizedBox(width: 11),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        color: OkeyColors.cream,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    Text(
                      mode.badge,
                      style: TextStyle(color: mode.accent, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          key: const ValueKey('game-mode-start'),
          onTap: onStart,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [mode.accentDark, mode.accent, mode.accentDark],
              ),
              border: Border.all(color: mode.accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: mode.accent.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 23),
                SizedBox(width: 8),
                Text(
                  'MODU SEÇ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

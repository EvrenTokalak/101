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
      label: 'Klasik 101',
      subtitle: 'Standart 101 kuralları',
      badge: 'KLASİK',
      icon: Icons.filter_1_rounded,
      accent: Color(0xFF4CAF50),
      accentDark: Color(0xFF174F25),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.classic101,
        id: 'elimination-101',
        label: 'Eliminasyon 101',
      ),
      features: ['4 Oyuncu', 'Bireysel', 'Normal Puanlama'],
    ),
    _GameModeData(
      id: 'paired-101',
      label: 'Eşli 101',
      subtitle: 'Eşinle birlikte kazan',
      badge: 'TAKIM',
      icon: Icons.groups_2_rounded,
      accent: Color(0xFF2196F3),
      accentDark: Color(0xFF0D3D73),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.paired101,
        id: 'paired-101',
        label: 'Eşli 101',
      ),
      features: ["2'ye 2", 'Ortak Puan', 'Takım Oyunu'],
    ),
    _GameModeData(
      id: 'progressive',
      label: 'Katlamalı',
      subtitle: 'Rakip açtıkça hedef yükselir',
      badge: 'YÜKSEK RİSK',
      icon: Icons.add_chart_rounded,
      accent: Color(0xFFE0A126),
      accentDark: Color(0xFF704308),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      ),
      features: ['4 Oyuncu', 'Bireysel', 'Yükselen Hedef'],
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
        'OYUN MODLARI',
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
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
              if (selected)
                Positioned(
                  right: -12,
                  top: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: OkeyColors.gold,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 5),
                      ],
                    ),
                    child: const Text(
                      'SEÇİLİ',
                      style: TextStyle(
                        color: Color(0xFF342006),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Column(
            children: [
              _ModeArtwork(mode: mode, selected: selected),
              const SizedBox(height: 10),
              Text(
                mode.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : OkeyColors.cream,
                  fontSize: selected ? 24 : 21,
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
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
          Text(
            mode.features.join('  •  '),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OkeyColors.cream.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModeArtwork extends StatelessWidget {
  final _GameModeData mode;
  final bool selected;

  const _ModeArtwork({required this.mode, required this.selected});

  Widget _tile(String value, Color color) => Container(
    width: 34,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E7),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD9C79C)),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
    ),
    child: Text(
      value,
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
    ),
  );

  Widget _rack(List<Widget> tiles) => Stack(
    alignment: Alignment.bottomCenter,
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 122,
        height: 13,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6B3D17), Color(0xFFC08A43), Color(0xFF6B3D17)],
          ),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      Positioned(
        bottom: 7,
        child: Row(mainAxisSize: MainAxisSize.min, children: tiles),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final content = switch (mode.id) {
      'paired-101' => SizedBox(
        width: 220,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rack([_tile('7', Colors.red), _tile('10', Colors.blue)]),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              _rack([_tile('7', Colors.red), _tile('10', Colors.blue)]),
            ],
          ),
        ),
      ),
      'progressive' => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _tile('101', const Color(0xFF18723A)),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white54,
            size: 17,
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: _tile('202', const Color(0xFFB87513)),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white54,
            size: 17,
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            child: _tile('303', const Color(0xFFB93A2E)),
          ),
        ],
      ),
      _ => _rack([
        _tile('7', Colors.red),
        _tile('10', Colors.blue),
        _tile('13', const Color(0xFF1C1C1C)),
      ]),
    };
    return AnimatedScale(
      scale: selected ? 1.05 : 0.96,
      duration: const Duration(milliseconds: 240),
      child: SizedBox(height: 92, child: Center(child: content)),
    );
  }
}

class _ModeBottomBar extends StatelessWidget {
  final _GameModeData mode;
  final VoidCallback onStart;

  const _ModeBottomBar({required this.mode, required this.onStart});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 34),
    child: Center(
      child: GestureDetector(
        key: const ValueKey('game-mode-start'),
        onTap: onStart,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 54),
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
                'BU MODDA OYNA',
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
    ),
  );
}

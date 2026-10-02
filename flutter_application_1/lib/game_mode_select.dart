import 'dart:math' show min;

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_controls.dart';
import 'game_launch.dart';
import 'game_navigation.dart';
import 'main.dart';
import 'player_progress.dart';

class GameModeSelectScreen extends StatefulWidget {
  const GameModeSelectScreen({super.key});

  @override
  State<GameModeSelectScreen> createState() => _GameModeSelectScreenState();
}

class _GameModeSelectScreenState extends State<GameModeSelectScreen> {
  static const _modes = [
    _GameModeData(
      id: 'classic-101',
      badge: 'KLASİK',
      artworkAsset: 'images/ui/icons/klasik.png',
      accent: Color(0xFF4CAF50),
      accentDark: Color(0xFF174F25),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.classic101,
        id: 'classic-101',
        label: 'Klasik 101',
      ),
    ),
    _GameModeData(
      id: 'timed-101',
      badge: 'HIZLI',
      artworkAsset: 'images/ui/icons/zamanli.png',
      accent: Color(0xFF2196F3),
      accentDark: Color(0xFF0D3D73),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.timed101,
        id: 'timed-101',
        label: 'Zamanlı 101',
      ),
    ),
    _GameModeData(
      id: 'color-bonus-101',
      badge: 'RENK BONUSU',
      artworkAsset: 'images/ui/icons/renk_bonusu.png',
      accent: Color(0xFFE05252),
      accentDark: Color(0xFF4F244E),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.colorBonus101,
        id: 'color-bonus-101',
        label: 'Renkli 101',
      ),
    ),
    _GameModeData(
      id: 'progressive',
      badge: 'YÜKSEK RİSK',
      artworkAsset: 'images/ui/icons/katlamali.png',
      accent: Color(0xFFE0A126),
      accentDark: Color(0xFF704308),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      ),
    ),
  ];

  int _selectedIndex = 0;

  Future<void> _startSelectedMode() async {
    await openGameScreen<void>(context, config: _modes[_selectedIndex].config);
  }

  Future<void> _showModeInfo(_GameModeData mode) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: appText('Mod bilgisini kapat', 'Close mode information'),
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => _ModeInfoDialog(mode: mode),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation.drive(
          TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.99), weight: 62),
            TweenSequenceItem(tween: Tween(begin: 0.99, end: 1), weight: 38),
          ]),
        ),
        child: child,
      ),
    ),
  );

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
                final widthScale = 900 / viewport.maxWidth;
                final heightScale = 600 / viewport.maxHeight;
                final requiredScale = widthScale > heightScale
                    ? widthScale
                    : heightScale;
                final canvasScale = requiredScale < 1 ? 1.0 : requiredScale;
                final canvasWidth = viewport.maxWidth * canvasScale;
                final canvasHeight = viewport.maxHeight * canvasScale;
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(_modes.length, (index) {
                                  final isSelected = index == _selectedIndex;
                                  return Expanded(
                                    flex: isSelected ? 11 : 10,
                                    child: _ModeCard(
                                      mode: _modes[index],
                                      selected: isSelected,
                                      onTap: () => setState(
                                        () => _selectedIndex = index,
                                      ),
                                      onInfo: () =>
                                          _showModeInfo(_modes[index]),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GameModeData {
  final String id;
  final String badge;
  final String artworkAsset;
  final Color accent;
  final Color accentDark;
  final GameLaunchConfig config;

  const _GameModeData({
    required this.id,
    required this.badge,
    required this.artworkAsset,
    required this.accent,
    required this.accentDark,
    required this.config,
  });
}

String _localizedModeLabel(String id) => switch (id) {
  'classic-101' => appText('KLASİK 101', 'CLASSIC 101'),
  'timed-101' => appText('ZAMANLI 101', 'TIMED 101'),
  'color-bonus-101' => appText('RENKLİ 101', 'COLOR BONUS 101'),
  'progressive' => appText('KATLAMALI', 'PROGRESSIVE'),
  _ => id.toUpperCase(),
};

String _localizedModeSubtitle(String id) => switch (id) {
  'classic-101' => appText('Standart 101 kuralları', 'Standard 101 rules'),
  'timed-101' => appText('Her hamle için 7 saniye', '7 seconds per move'),
  'color-bonus-101' => appText('Bonus perler 2 kat', 'Bonus melds score 2x'),
  'progressive' => appText(
    'Rakip açtıkça hedef yükselir',
    'The target rises after each opening',
  ),
  _ => '',
};

String _localizedModeDescription(String id) => switch (id) {
  'classic-101' => appText(
    'Standart 101 kurallarıyla üç tur oynanır. En düşük toplam puan avantaj sağlar.',
    'Play three rounds with standard 101 rules. The lowest total score has the advantage.',
  ),
  'timed-101' => appText(
    'Her hamle için 7 saniyen vardır. Süre biterse oyun uygun bir taşı otomatik çeker ve atar.',
    'You have 7 seconds for each move. When time expires, the game draws and discards automatically.',
  ),
  'color-bonus-101' => appText(
    'Her tur bir bonus renk seçilir. O renkle açılan perler iki kat değer kazanır.',
    'A bonus color is selected each round. Melds opened in that color score double.',
  ),
  'progressive' => appText(
    'Bir oyuncu kaç puanla veya kaç çiftle açarsa sonraki oyuncunun hedefi bir artar.',
    'Each opening raises the next player’s score or pair target by one.',
  ),
  _ => '',
};

List<String> _localizedModeFeatures(String id) => switch (id) {
  'classic-101' => [
    appText('4 Oyuncu', '4 Players'),
    appText('Bireysel', 'Solo'),
    appText('Normal Puanlama', 'Normal Scoring'),
  ],
  'timed-101' => [
    appText('4 Oyuncu', '4 Players'),
    appText('7 Saniye', '7 Seconds'),
    appText('Otomatik Hamle', 'Auto Move'),
  ],
  'color-bonus-101' => [
    appText('4 Oyuncu', '4 Players'),
    appText('Her El Yeni Renk', 'New Color Each Round'),
    appText('Renkli Per 2x', 'Color Meld 2x'),
  ],
  'progressive' => [
    appText('4 Oyuncu', '4 Players'),
    appText('Bireysel', 'Solo'),
    appText('Yükselen Hedef', 'Rising Target'),
  ],
  _ => const [],
};

class _ModeTopBar extends StatelessWidget {
  const _ModeTopBar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        AppBackButton(
          buttonKey: const ValueKey('game-mode-back'),
          onTap: () => Navigator.of(context).pop(),
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
      Text(
        appText('OYUN MODLARI', 'GAME MODES'),
        style: const TextStyle(
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
  final VoidCallback onInfo;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.onInfo,
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
              blurRadius: 12,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                key: ValueKey('game-mode-info-${mode.id}'),
                onTap: onInfo,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mode.accent.withValues(alpha: 0.75),
                    ),
                  ),
                  child: Text(
                    'i',
                    style: TextStyle(
                      color: mode.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (selected)
                Container(
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
                )
              else
                const SizedBox(width: 54),
            ],
          ),
          Column(
            children: [
              _ModeArtwork(mode: mode, selected: selected),
              const SizedBox(height: 7),
              Text(
                _localizedModeLabel(mode.id),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : OkeyColors.cream,
                  fontSize: selected ? 31 : 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Georgia',
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          Text(
            _localizedModeFeatures(mode.id).take(2).join('  •  '),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OkeyColors.cream.withValues(alpha: 0.9),
              fontSize: 14,
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

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.05 : 0.96,
    duration: const Duration(milliseconds: 240),
    child: SizedBox(
      height: 116,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            mode.artworkAsset,
            width: mode.id == 'timed-101' ? 108 : 144,
            height: 112,
            fit: BoxFit.contain,
            cacheWidth: 224,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    ),
  );
}

class _ModeInfoDialog extends StatelessWidget {
  final _GameModeData mode;

  const _ModeInfoDialog({required this.mode});

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Colors.transparent,
      child: Container(
        key: ValueKey('game-mode-info-dialog-${mode.id}'),
        width: min(470, MediaQuery.sizeOf(context).width - 30),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123C2E), Color(0xFF071B14)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: OkeyColors.gold, width: 2.4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Image.asset(
                  mode.artworkAsset,
                  width: 72,
                  height: 68,
                  fit: BoxFit.contain,
                  cacheWidth: 144,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localizedModeLabel(mode.id),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _localizedModeSubtitle(mode.id),
                        style: TextStyle(
                          color: mode.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                AppCloseButton(
                  onTap: () => Navigator.of(context).pop(),
                  size: 40,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: mode.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mode.accent.withValues(alpha: 0.5)),
              ),
              child: Text(
                mode.badge,
                style: TextStyle(
                  color: mode.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _localizedModeDescription(mode.id),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OkeyColors.cream,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _localizedModeFeatures(mode.id)
                  .map(
                    (feature) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mode.accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
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
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 23),
              SizedBox(width: 8),
              Text(
                appText('BU MODDA OYNA', 'PLAY THIS MODE'),
                style: const TextStyle(
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

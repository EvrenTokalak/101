import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_controls.dart';
import 'game_launch.dart';
import 'game_navigation.dart';
import 'app_colors.dart';
import 'selection_page.dart';
import 'difficulty_picker.dart';

part 'game_mode_select_widgets.dart';

class GameModeSelectScreen extends StatefulWidget {
  const GameModeSelectScreen({super.key});

  @override
  State<GameModeSelectScreen> createState() => _GameModeSelectScreenState();
}

class _GameModeSelectScreenState extends State<GameModeSelectScreen> {
  static const _modes = [
    _GameModeData(
      id: 'classic-101',
      accent: Color(0xFF4CAF50),
      accentDark: Color(0xFF003D09),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.classic101,
        id: 'classic-101',
        label: 'Kuralı Sen Belirle',
      ),
    ),
    _GameModeData(
      id: 'timed-101',
      accent: Color(0xFF2196F3),
      accentDark: Color(0xFF00263B),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.timed101,
        id: 'timed-101',
        label: 'Zamanlı 101',
      ),
    ),
    _GameModeData(
      id: 'color-bonus-101',
      accent: Color(0xFFE05252),
      accentDark: Color(0xFF32000B),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.colorBonus101,
        id: 'color-bonus-101',
        label: 'Renkli 101',
      ),
    ),
    _GameModeData(
      id: 'progressive',
      accent: Color(0xFFE0A126),
      accentDark: Color(0xFF292300),
      config: GameLaunchConfig.gameMode(
        mode: OkeyGameMode.progressive,
        id: 'progressive',
        label: 'Katlamalı',
      ),
    ),
  ];

  int _selectedIndex = 0;
  bool _starting = false;

  Future<void> _startSelectedMode() async {
    if (_starting) return;
    final config = _modes[_selectedIndex].config;
    _starting = true;
    try {
      final difficulty = await pickBotDifficulty(context);
      if (difficulty == null || !mounted) return;
      await openGameScreen<void>(
        context,
        config: config.withDifficulty(difficulty),
      );
    } finally {
      _starting = false;
    }
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
  Widget build(BuildContext context) => SelectionPage(
    title: appText('OYUN MODLARI', 'GAME MODES'),
    onBack: () => Navigator.of(context).pop(),
    backButtonKey: const ValueKey('game-mode-back'),
    gridKey: const ValueKey('game-mode-grid'),
    cards: [
      for (var index = 0; index < _modes.length; index++)
        _ModeCard(
          mode: _modes[index],
          selected: index == _selectedIndex,
          onTap: () => setState(() => _selectedIndex = index),
          onInfo: () => _showModeInfo(_modes[index]),
        ),
    ],
    actionBuilder: (height, width) => _ModeStartButton(
      onTap: _startSelectedMode,
      width: (width * .25).clamp(220.0, 400.0),
      height: (height * .78).clamp(40.0, 66.0),
    ),
  );
}

class _GameModeData {
  final String id;
  final Color accent;
  final Color accentDark;
  final GameLaunchConfig config;

  const _GameModeData({
    required this.id,
    required this.accent,
    required this.accentDark,
    required this.config,
  });
}

String _localizedModeLabel(String id) => switch (id) {
  'classic-101' => appText('KURALI SEN BELİRLE', 'SET YOUR RULES'),
  'timed-101' => appText('ZAMANLI 101', 'TIMED 101'),
  'color-bonus-101' => appText('RENKLİ 101', 'COLOR BONUS 101'),
  'progressive' => appText('KATLAMALI', 'PROGRESSIVE'),
  _ => id.toUpperCase(),
};

String _localizedModeDescription(String id) => switch (id) {
  'classic-101' => appText(
    'Dört oyuncuyla bireysel olarak, normal 101 puanlamasıyla üç tur oynanır. Kendi masa kurallarını seçme özelliği ileride eklenecektir; şimdilik mevcut 101 kuralları geçerlidir. Bu moddaki eller günlük lige sayılmaz.',
    'Play three individual rounds with four players and normal 101 scoring. Custom table rules will be added later; the existing 101 rules apply for now. Rounds in this mode do not count toward the daily league.',
  ),
  'timed-101' => appText(
    'Dört oyuncuyla oynanan bu modda her hamle için 7 saniyen vardır. Süre dolduğunda henüz taş çekmediysen oyun otomatik taş çeker ve uygun bir taşı senin yerine atar. Ardından sıra sonraki oyuncuya geçer.',
    'In this four-player mode, you have 7 seconds for each move. When time expires, the game draws a tile if you have not drawn one yet, then discards a suitable tile for you. Play then passes to the next player.',
  ),
  'color-bonus-101' => appText(
    'Dört oyuncuyla oynanır ve her el yeni bir bonus renk belirlenir. Bu renkte açılan perlerin açılış puanı iki kat hesaplanır; diğer perler normal değerindedir. Elini açarken seçilen rengi değerlendirerek gereken puana daha kolay ulaşabilirsin.',
    'Play with four players and a new bonus color each round. Melds opened in that color count double toward your opening score; other melds keep their normal value. Use the selected color to reach the required opening score more easily.',
  ),
  'progressive' => appText(
    'Dört oyuncuyla bireysel oynanır. Bir oyuncu seri açtığında seri hedefi açtığı puanın bir fazlasına, çift açtığında çift hedefi açtığı çift sayısının bir fazlasına yükselir. Seri ve çift hedefleri ayrı ilerler; sonraki oyuncular güncel hedefe ulaşmalıdır.',
    'Play individually with four players. A meld opening raises the meld target to one above its score; a pair opening raises the pair target to one above its pair count. The two targets rise separately, and later players must meet the current target.',
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

class _ModeInfoDialog extends StatelessWidget {
  final _GameModeData mode;
  const _ModeInfoDialog({required this.mode});

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final size = Size(
      math.min(420, math.max(0, viewport.width - 32)),
      math.min(300, math.max(0, viewport.height - 32)),
    );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: AppGenericPanel(
          key: ValueKey('game-mode-info-dialog-${mode.id}'),
          width: size.width,
          height: size.height,
          title: Text(_localizedModeLabel(mode.id), maxLines: 1),
          onClose: () => Navigator.of(context).pop(),
          child: LayoutBuilder(
            builder: (context, bounds) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: bounds.maxWidth,
                  child: Text(
                    _localizedModeDescription(mode.id),
                    key: ValueKey('game-mode-info-paragraph-${mode.id}'),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: OkeyColors.cream,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

part of 'game.dart';

class GameSettings {
  final bool sound;
  final bool vibration;
  final bool moveHints;
  final bool gridMagnifier;
  final bool animations;
  final bool autoPlay;
  final bool showRack;
  final bool showGrid;
  final bool showBots;
  final double fontScale;

  const GameSettings({
    this.sound = true,
    this.vibration = true,
    this.moveHints = true,
    this.gridMagnifier = true,
    this.animations = true,
    this.autoPlay = false,
    this.showRack = true,
    this.showGrid = true,
    this.showBots = true,
    this.fontScale = 1,
  });

  GameSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? moveHints,
    bool? gridMagnifier,
    bool? animations,
    bool? autoPlay,
    bool? showRack,
    bool? showGrid,
    bool? showBots,
    double? fontScale,
  }) => GameSettings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    moveHints: moveHints ?? this.moveHints,
    gridMagnifier: gridMagnifier ?? this.gridMagnifier,
    animations: animations ?? this.animations,
    autoPlay: autoPlay ?? this.autoPlay,
    showRack: showRack ?? this.showRack,
    showGrid: showGrid ?? this.showGrid,
    showBots: showBots ?? this.showBots,
    fontScale: (fontScale ?? this.fontScale).clamp(0.9, 1.25),
  );
}

class GameSettingsDialog extends StatefulWidget {
  final GameSettings initial;
  final GameLaunchConfig launchConfig;
  final ValueChanged<GameSettings> onRestart;
  final VoidCallback onExitToMenu;
  final ValueChanged<GameSettings> onChanged;

  const GameSettingsDialog({
    super.key,
    required this.initial,
    required this.launchConfig,
    required this.onRestart,
    required this.onExitToMenu,
    required this.onChanged,
  });

  @override
  State<GameSettingsDialog> createState() => _GameSettingsDialogState();
}

class _GameSettingsDialogState extends State<GameSettingsDialog> {
  late GameSettings settings;

  @override
  void initState() {
    super.initState();
    settings = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final height = max(
      320.0,
      min(590.0, MediaQuery.sizeOf(context).height - 28),
    );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: min(760, MediaQuery.sizeOf(context).width - 24),
          height: height,
          child: Row(
            children: [
              SizedBox(width: 300, child: _performancePanel()),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123C2E), Color(0xFF071B14)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OC.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.48),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            border: Border(
                              bottom: BorderSide(
                                color: OC.gold.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 9, 8, 9),
                          child: Row(
                            children: [
                              Image.asset(
                                'images/ui/settings.png',
                                width: 38,
                                height: 38,
                                cacheWidth: 72,
                                cacheHeight: 72,
                                filterQuality: FilterQuality.low,
                              ),
                              const SizedBox(width: 11),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'OYUN AYARLARI',
                                      style: TextStyle(
                                        color: OC.goldLight,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Georgia',
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      'Masa deneyimini kendine göre düzenle',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppCloseButton(
                                onTap: () => Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(),
                                size: 38,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('MASA BİLGİSİ'),
                                _matchInfo(),
                                const SizedBox(height: 12),
                                _sectionTitle('OYUN DENEYİMİ'),
                                _switch(
                                  Icons.volume_up_rounded,
                                  'Ses Efektleri',
                                  settings.sound,
                                  (value) => settings = settings.copyWith(
                                    sound: value,
                                  ),
                                ),
                                _switch(
                                  Icons.vibration_rounded,
                                  'Titreşim',
                                  settings.vibration,
                                  (value) => settings = settings.copyWith(
                                    vibration: value,
                                  ),
                                ),
                                _switch(
                                  Icons.lightbulb_rounded,
                                  'Hamle İpuçları',
                                  settings.moveHints,
                                  (value) => settings = settings.copyWith(
                                    moveHints: value,
                                  ),
                                ),
                                _switch(
                                  Icons.zoom_in_map_rounded,
                                  'Grid Büyüteci',
                                  settings.gridMagnifier,
                                  (value) => settings = settings.copyWith(
                                    gridMagnifier: value,
                                  ),
                                ),
                                _switch(
                                  Icons.animation_rounded,
                                  'Animasyonlar',
                                  settings.animations,
                                  (value) => settings = settings.copyWith(
                                    animations: value,
                                  ),
                                ),
                                _switch(
                                  Icons.smart_toy_rounded,
                                  'Otomatik Oyna',
                                  settings.autoPlay,
                                  (value) => settings = settings.copyWith(
                                    autoPlay: value,
                                  ),
                                ),
                                _switch(
                                  Icons.monitor_heart_rounded,
                                  'CPU/GPU/RAM Göstergesi',
                                  performanceOverlayEnabled.value,
                                  (value) =>
                                      performanceOverlayEnabled.value = value,
                                ),
                                const SizedBox(height: 12),
                                _sectionTitle('ERİŞİLEBİLİRLİK'),
                                _fontScaleSetting(),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.24),
                            border: Border(
                              top: BorderSide(
                                color: OC.gold.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onExitToMenu,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFB7A7),
                                    side: BorderSide(
                                      color: OC.numRed.withValues(alpha: 0.8),
                                    ),
                                    backgroundColor: OC.numRed.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 17,
                                  ),
                                  label: const FittedBox(
                                    child: Text('ANA MENÜ'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => widget.onRestart(settings),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: OC.goldLight,
                                    side: BorderSide(
                                      color: OC.gold.withValues(alpha: 0.82),
                                    ),
                                    backgroundColor: OC.gold.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.restart_alt_rounded,
                                    size: 17,
                                  ),
                                  label: const FittedBox(
                                    child: Text('RESTART'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop(settings),
                                  style: FilledButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF16863C),
                                    side: BorderSide(
                                      color: OC.gold.withValues(alpha: 0.7),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  icon: Image.asset(
                                    'images/ui/settings_ok.png',
                                    width: 22,
                                    height: 22,
                                    cacheWidth: 44,
                                    cacheHeight: 44,
                                    filterQuality: FilterQuality.low,
                                  ),
                                  label: const FittedBox(child: Text('KAYDET')),
                                ),
                              ),
                            ],
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
    );
  }

  Widget _performancePanel() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123C2E), Color(0xFF071B14)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: OC.gold, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 13, 14, 9),
          child: Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: OC.okeyGold, size: 23),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PERFORMANS TESTİ',
                  style: TextStyle(
                    color: OC.okeyGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Bir seçeneği kapatıp CPU/GPU değişimini birkaç saniye izle.',
            style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.25),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: [
                _diagnosticSwitch(
                  Icons.view_stream_rounded,
                  'Istaka ve taşlar',
                  settings.showRack,
                  (v) => settings = settings.copyWith(showRack: v),
                ),
                _diagnosticSwitch(
                  Icons.grid_on_rounded,
                  'Grid ve perler',
                  settings.showGrid,
                  (v) => settings = settings.copyWith(showGrid: v),
                ),
                _diagnosticSwitch(
                  Icons.smart_toy_rounded,
                  'Bot görselleri',
                  settings.showBots,
                  (v) => settings = settings.copyWith(showBots: v),
                ),
                _diagnosticSwitch(
                  Icons.animation_rounded,
                  'Tüm animasyonlar',
                  settings.animations,
                  (v) => settings = settings.copyWith(animations: v),
                ),
                _diagnosticSwitch(
                  Icons.zoom_in_rounded,
                  'Grid büyüteci',
                  settings.gridMagnifier,
                  (v) => settings = settings.copyWith(gridMagnifier: v),
                ),
                _diagnosticSwitch(
                  Icons.lightbulb_rounded,
                  'Hamle ipuçları',
                  settings.moveHints,
                  (v) => settings = settings.copyWith(moveHints: v),
                ),
                _diagnosticSwitch(
                  Icons.volume_up_rounded,
                  'Ses efektleri',
                  settings.sound,
                  (v) => settings = settings.copyWith(sound: v),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _diagnosticSwitch(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: value
          ? const Color(0xFF174C35)
          : Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: value ? OC.gold.withValues(alpha: 0.48) : Colors.white10,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => update(!value));
          widget.onChanged(settings);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Icon(icon, color: value ? OC.okeyGold : Colors.white38, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _toggleImage(value, width: 48),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: OC.goldLight,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    ),
  );

  Widget _matchInfo() {
    final config = widget.launchConfig;
    final details = <(IconData, String, String)>[
      (Icons.sports_esports_rounded, 'Mod', config.modeLabel),
      (Icons.login_rounded, 'Giriş', config.entryPointLabel),
      if (config.entryPoint == GameEntryPoint.room)
        (Icons.meeting_room_rounded, 'Oda', config.selectionLabel),
      if (config.entryFee != null)
        (Icons.monetization_on_rounded, 'Giriş Ücreti', '${config.entryFee}'),
      if (config.isTournament)
        (Icons.emoji_events_rounded, 'Aşama', config.selectionLabel),
      if (config.opponent != null)
        (Icons.person_rounded, 'Rakip', config.opponent!),
    ];
    return Container(
      key: const ValueKey('game-match-info'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OC.gold.withValues(alpha: 0.38)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final detail in details)
            SizedBox(
              width: 170,
              child: Row(
                children: [
                  Icon(detail.$1, size: 17, color: OC.goldLight),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${detail.$2}: ',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: detail.$3,
                            style: const TextStyle(
                              color: OC.cream,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fontScaleSetting() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OC.gold.withValues(alpha: 0.38)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.text_fields_rounded, color: OC.goldLight),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yazı Boyutu',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: OC.cream,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Taş sayıları sabit kalır',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 9, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Text(
              '${(settings.fontScale * 100).round()}%',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: OC.goldLight,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.fontScale,
          min: 0.9,
          max: 1.25,
          divisions: 7,
          activeColor: OC.gold,
          inactiveColor: Colors.white12,
          onChanged: (value) => setState(() {
            settings = settings.copyWith(fontScale: value);
            widget.onChanged(settings);
          }),
        ),
        Text(
          'Önizleme: 101 Okey',
          textScaler: TextScaler.linear(settings.fontScale),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _switch(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: value
          ? const Color(0xFF174C35)
          : Colors.black.withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value ? OC.gold.withValues(alpha: 0.58) : Colors.white12,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() => update(!value));
          widget.onChanged(settings);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: value ? OC.goldLight : Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: OC.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _toggleImage(value),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _toggleImage(bool value, {double width = 56}) => Image.asset(
    value
        ? 'images/ui/settings_switch_on.png'
        : 'images/ui/settings_switch_off.png',
    width: width,
    height: width * 0.45,
    cacheWidth: (width * 2).round(),
    filterQuality: FilterQuality.low,
  );
}

part of 'game.dart';

class GameSettings {
  final bool sound;
  final bool vibration;
  final bool moveHints;
  final bool gridMagnifier;
  final bool animations;
  final double fontScale;

  const GameSettings({
    this.sound = true,
    this.vibration = true,
    this.moveHints = true,
    this.gridMagnifier = true,
    this.animations = true,
    this.fontScale = 1,
  });

  GameSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? moveHints,
    bool? gridMagnifier,
    bool? animations,
    double? fontScale,
  }) => GameSettings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    moveHints: moveHints ?? this.moveHints,
    gridMagnifier: gridMagnifier ?? this.gridMagnifier,
    animations: animations ?? this.animations,
    fontScale: fontScale ?? this.fontScale,
  );
}

class GameSettingsDialog extends StatefulWidget {
  final GameSettings initial;
  final GameLaunchConfig launchConfig;
  final VoidCallback onExitToMenu;

  const GameSettingsDialog({
    super.key,
    required this.initial,
    required this.launchConfig,
    required this.onExitToMenu,
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
        child: Container(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: height),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: OC.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OC.gold, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 28)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      color: OC.gold,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'OYUN AYARLARI',
                        style: TextStyle(
                          color: OC.panelBrown,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
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
                        (value) => settings = settings.copyWith(sound: value),
                      ),
                      _switch(
                        Icons.vibration_rounded,
                        'Titreşim',
                        settings.vibration,
                        (value) =>
                            settings = settings.copyWith(vibration: value),
                      ),
                      _switch(
                        Icons.lightbulb_rounded,
                        'Hamle İpuçları',
                        settings.moveHints,
                        (value) =>
                            settings = settings.copyWith(moveHints: value),
                      ),
                      _switch(
                        Icons.zoom_in_map_rounded,
                        'Grid Büyüteci',
                        settings.gridMagnifier,
                        (value) =>
                            settings = settings.copyWith(gridMagnifier: value),
                      ),
                      _switch(
                        Icons.animation_rounded,
                        'Animasyonlar',
                        settings.animations,
                        (value) =>
                            settings = settings.copyWith(animations: value),
                      ),
                      const SizedBox(height: 12),
                      _sectionTitle('ERİŞİLEBİLİRLİK'),
                      _fontScaleSetting(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onExitToMenu,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OC.numRed,
                        side: const BorderSide(color: OC.numRed),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('ANA MENÜYE DÖN'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(settings),
                      style: FilledButton.styleFrom(
                        backgroundColor: OC.btnBrown,
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('KAYDET'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: OC.btnBrown,
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
        color: OC.tableGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OC.numGreen.withValues(alpha: 0.45)),
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
                  Icon(detail.$1, size: 17, color: OC.numGreen),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${detail.$2}: ',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: detail.$3,
                            style: const TextStyle(
                              color: OC.panelBrown,
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
      color: Colors.white.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OC.tileBdr),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.text_fields_rounded, color: OC.numGreen),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Yazı Boyutu',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${(settings.fontScale * 100).round()}%',
              style: const TextStyle(
                color: OC.btnBrown,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.fontScale,
          min: 0.85,
          max: 1.25,
          divisions: 4,
          activeColor: OC.numGreen,
          onChanged: (value) => setState(() {
            settings = settings.copyWith(fontScale: value);
          }),
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
      color: Colors.white.withValues(alpha: 0.48),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OC.tileBdr),
      ),
      child: SwitchListTile(
        dense: true,
        secondary: Icon(icon, color: value ? OC.numGreen : Colors.grey),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: value,
        activeTrackColor: OC.numGreen,
        onChanged: (next) => setState(() => update(next)),
      ),
    ),
  );
}

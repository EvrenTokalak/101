part of 'game.dart';

class GameSettings {
  final bool sound;
  final bool music;
  final bool vibration;
  final bool moveHints;
  final bool animations;
  final double fontScale;

  const GameSettings({
    this.sound = true,
    this.music = true,
    this.vibration = true,
    this.moveHints = true,
    this.animations = true,
    this.fontScale = 1,
  });

  GameSettings copyWith({
    bool? sound,
    bool? music,
    bool? vibration,
    bool? moveHints,
    bool? animations,
    double? fontScale,
  }) => GameSettings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    vibration: vibration ?? this.vibration,
    moveHints: moveHints ?? this.moveHints,
    animations: animations ?? this.animations,
    fontScale: fontScale ?? this.fontScale,
  );
}

class GameSettingsDialog extends StatefulWidget {
  final GameSettings initial;
  final VoidCallback onExitToMenu;

  const GameSettingsDialog({
    super.key,
    required this.initial,
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
                    children: [
                      _switch(
                        Icons.volume_up_rounded,
                        'Ses Efektleri',
                        settings.sound,
                        (value) => settings = settings.copyWith(sound: value),
                      ),
                      _switch(
                        Icons.music_note_rounded,
                        'Müzik',
                        settings.music,
                        (value) => settings = settings.copyWith(music: value),
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
                        Icons.animation_rounded,
                        'Animasyonlar',
                        settings.animations,
                        (value) =>
                            settings = settings.copyWith(animations: value),
                      ),
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

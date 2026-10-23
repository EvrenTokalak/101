import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'performance_overlay.dart';

/// Settings percentages are relative to this baseline: the former 105% is
/// now 100%. Keep stored/displayed values nominal instead of scaling twice.
const double appBaseFontScale = 1.05;

TextScaler appTextScaler(double relativeScale) =>
    TextScaler.linear(appBaseFontScale * relativeScale);

/// Pause the cached scene for settings without rebuilding the whole screen.
class SettingsSceneActivity extends StatelessWidget {
  final ValueListenable<bool> panelOpen;
  final bool enabled;
  final Widget child;
  const SettingsSceneActivity({
    super.key,
    required this.panelOpen,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: panelOpen,
    child: child,
    builder: (context, open, scene) =>
        TickerMode(enabled: enabled && !open, child: scene!),
  );
}

const appSettingsPanelAsset = 'images/ui/panels/ayarlar.png';

const appSettingsArtwork = ResizeImage(
  AssetImage(appSettingsPanelAsset),
  width: 1280,
);

Size appSettingsPanelSize(BoxConstraints bounds) {
  return appArtworkPanelSize(bounds);
}

Widget appSettingsTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(
  opacity: animation,
  child: ScaleTransition(
    scale: Tween<double>(
      begin: .98,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
    child: RepaintBoundary(child: child),
  ),
);

/// Decode the frame before a settings popup is requested, using the same
/// provider as the visible artwork so no second decode is necessary.
class SettingsArtworkWarmup extends StatefulWidget {
  final Widget child;
  const SettingsArtworkWarmup({super.key, required this.child});

  @override
  State<SettingsArtworkWarmup> createState() => _SettingsArtworkWarmupState();
}

class _SettingsArtworkWarmupState extends State<SettingsArtworkWarmup> {
  bool _started = false;
  final _pinnedArtwork = <(ImageStream, ImageStreamListener)>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _warmArtwork();
    }
  }

  Future<void> _warmArtwork() async {
    for (final image in [
      appSettingsArtwork,
      appCloseArtwork,
      appHomeActionArtwork,
      appHomePlayArtwork,
      ...appPopupArtworkProviders.values,
    ]) {
      // Spread decoding across frames so warming other panels does not stall
      // the initial scene or delay an already interactive popup.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await precacheImage(image, context, onError: (_, _) {});
      if (!mounted) return;
      // Keep these few shared frames alive while scene/profile photos churn
      // through the LRU cache. precacheImage alone releases its listener.
      final stream = image.resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener(
        (image, _) => image.dispose(),
        onError: (_, _) {},
      );
      stream.addListener(listener);
      _pinnedArtwork.add((stream, listener));
    }
  }

  @override
  void dispose() {
    for (final (stream, listener) in _pinnedArtwork) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppSettings {
  final bool soundEffects;
  final bool notifications;
  final bool vibration;
  final bool showOpponentPictures;
  final bool autoArrangeRack;
  // Hot reload öncesinde oluşturulmuş AppSettings örneklerinde yeni alan null
  // kalabilir. Nullable backing field eski oturumları güvenle varsayılana taşır.
  final bool? _moveHints;
  bool get moveHints => _moveHints ?? true;
  final double fontScale;
  final AppLanguage language;

  const AppSettings({
    this.soundEffects = true,
    this.notifications = true,
    this.vibration = true,
    this.showOpponentPictures = true,
    this.autoArrangeRack = false,
    this._moveHints = true,
    this.fontScale = 1,
    this.language = AppLanguage.turkish,
  });

  AppSettings copyWith({
    bool? soundEffects,
    bool? notifications,
    bool? vibration,
    bool? showOpponentPictures,
    bool? autoArrangeRack,
    bool? moveHints,
    double? fontScale,
    AppLanguage? language,
  }) => AppSettings(
    soundEffects: soundEffects ?? this.soundEffects,
    notifications: notifications ?? this.notifications,
    vibration: vibration ?? this.vibration,
    showOpponentPictures: showOpponentPictures ?? this.showOpponentPictures,
    autoArrangeRack: autoArrangeRack ?? this.autoArrangeRack,
    moveHints: moveHints ?? this.moveHints,
    fontScale: (fontScale ?? this.fontScale).clamp(0.85, 1.25),
    language: language ?? this.language,
  );
}

final ValueNotifier<AppSettings> appSettings = ValueNotifier(
  const AppSettings(),
);

class AppSettingsDialog extends StatefulWidget {
  final AppSettings initial;
  final VoidCallback? onHome;
  final VoidCallback? onRestart;
  final VoidCallback? onTutorial;

  const AppSettingsDialog({
    super.key,
    required this.initial,
    this.onHome,
    this.onRestart,
    this.onTutorial,
  });

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  static const _goldLight = Color(0xFFF0CC5A);
  static const _cream = Color(0xFFF5EDD6);
  late AppSettings settings;
  bool _tutorialLaunching = false;

  @override
  void initState() {
    super.initState();
    settings = widget.initial;
  }

  String _text(String tr, String en, {String? de}) =>
      localizedText(settings.language, tr, en, german: de);

  // Keep the artwork and controls on the same canvas so the gold frame
  // never covers a button, even on small screens or at maximum text size.
  static const _canvasWidth = 900.0;
  static const _metricScale = _canvasWidth / appPopupWidth;
  static const _canvasHeight = _canvasWidth / 1.5;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final panelSize = appSettingsPanelSize(bounds);
          return Center(
            child: SizedBox(
              key: const ValueKey('settings-dialog'),
              width: panelSize.width,
              height: panelSize.height,
              child: AppArtworkReady(
                image: appSettingsArtwork,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FittedBox(
                        child: SizedBox(
                          width: _canvasWidth,
                          height: _canvasHeight,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: appTextScaler(settings.fontScale),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: Stack(
                                key: const ValueKey('settings-panel-ready'),
                                children: [
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: _SettingsArtworkCrop(
                                        child: Image(
                                          image: appSettingsArtwork,
                                          key: const ValueKey(
                                            'settings-panel-artwork',
                                          ),
                                          fit: BoxFit.fill,
                                          excludeFromSemantics: true,
                                          frameBuilder:
                                              (
                                                _,
                                                artwork,
                                                frame,
                                                synchronous,
                                              ) => synchronous || frame != null
                                              ? artwork
                                              : _artworkFallback(),
                                          errorBuilder: (_, _, _) =>
                                              _artworkFallback(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 88,
                                    right: 88,
                                    top: 142,
                                    bottom: 78,
                                    child: LayoutBuilder(
                                      builder: (context, inner) {
                                        final options = <Widget>[
                                          _toggle(
                                            'Ses Efektleri',
                                            'Sound Effects',
                                            Icons.volume_up_rounded,
                                            settings.soundEffects,
                                            (v) => settings = settings.copyWith(
                                              soundEffects: v,
                                            ),
                                          ),
                                          if (widget.onTutorial != null)
                                            _option(
                                              key: const ValueKey(
                                                'settings-tutorial-button',
                                              ),
                                              label: _text(
                                                'Öğretici',
                                                'TUTORIAL',
                                                de: 'ANLEITUNG',
                                              ),
                                              icon: Icons.menu_book_rounded,
                                              enabled: _tutorialLaunching,
                                              toggle: true,
                                              onTap: _launchTutorial,
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          _toggle(
                                            'Bildirimler',
                                            'NOTIFICATIONS',
                                            Icons.notifications_active_rounded,
                                            settings.notifications,
                                            (v) => settings = settings.copyWith(
                                              notifications: v,
                                            ),
                                          ),
                                          _toggle(
                                            'Hamle İpuçları',
                                            'MOVE HINTS',
                                            Icons.lightbulb_rounded,
                                            settings.moveHints,
                                            (v) => settings = settings.copyWith(
                                              moveHints: v,
                                            ),
                                          ),
                                          _toggle(
                                            'Titreşim',
                                            'VIBRATION',
                                            Icons.vibration_rounded,
                                            settings.vibration,
                                            (v) => settings = settings.copyWith(
                                              vibration: v,
                                            ),
                                          ),
                                          _toggle(
                                            'Otomatik Istaka Dizimi',
                                            'AUTO ARRANGE RACK',
                                            Icons.view_week_rounded,
                                            settings.autoArrangeRack,
                                            (v) => settings = settings.copyWith(
                                              autoArrangeRack: v,
                                            ),
                                          ),
                                          _toggle(
                                            'Rakip Resimleri',
                                            'OPPONENT PICTURES',
                                            Icons.person_rounded,
                                            settings.showOpponentPictures,
                                            (v) => settings = settings.copyWith(
                                              showOpponentPictures: v,
                                            ),
                                          ),
                                          _languageCard(),
                                        ];
                                        return Column(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: _settingsGroup(
                                                      _text(
                                                        'Ses ve titreşim',
                                                        'Sound and vibration',
                                                        de: 'Ton und Vibration',
                                                      ),
                                                      [
                                                        options[0],
                                                        options[4],
                                                        options[2],
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: _settingsGroup(
                                                      _text(
                                                        'Oynanış',
                                                        'Gameplay',
                                                        de: 'Spielablauf',
                                                      ),
                                                      [
                                                        options[3],
                                                        options[5],
                                                        options[1],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _groupHeading(
                                              _text(
                                                'Görünüm',
                                                'Appearance',
                                                de: 'Darstellung',
                                              ),
                                            ),
                                            SizedBox(
                                              height: 48,
                                              child: Row(
                                                children: [
                                                  Expanded(child: options[6]),
                                                  const SizedBox(width: 16),
                                                  Expanded(child: options[7]),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            _fontScaleCard(),
                                            const SizedBox(height: 4),
                                            _footer(),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AppArtworkTitle(
                        asset: appSettingsPanelAsset,
                        child: Text(
                          _text('AYARLAR', 'SETTINGS', de: 'EINSTELLUNGEN'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AppArtworkClose(
                        asset: appSettingsPanelAsset,
                        buttonKey: const ValueKey('settings-close-button'),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> _launchTutorial() async {
    if (_tutorialLaunching || widget.onTutorial == null) return;
    setState(() => _tutorialLaunching = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) _closeThen(widget.onTutorial!);
  }

  Widget _groupHeading(String title) => SizedBox(
    height: 22,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: _goldLight,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _settingsGroup(String title, List<Widget> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _groupHeading(title),
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(height: 42, child: options[i]),
          ),
        ),
      ],
    ],
  );

  Widget _artworkFallback() => Stack(
    key: const ValueKey('settings-panel-fallback'),
    children: [
      Positioned.fill(
        child: Container(
          margin: const EdgeInsets.fromLTRB(42, 18, 42, 30),
          decoration: BoxDecoration(
            color: const Color(0xFF241609),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _goldLight, width: 3),
          ),
        ),
      ),
      if (settings.language == AppLanguage.turkish)
        Positioned(
          left: 310,
          right: 310,
          top: 24,
          height: 40,
          child: Center(
            child: ExcludeSemantics(
              child: RichText(
                text: const TextSpan(
                  text: 'AYARLAR',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 19 * _metricScale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
  Widget _toggle(
    String tr,
    String en,
    IconData icon,
    bool value,
    ValueChanged<bool> update,
  ) => _option(
    label: _text(tr, en),
    icon: icon,
    enabled: value,
    toggle: true,
    onTap: () => setState(() => update(!value)),
  );

  Widget _option({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
    bool toggle = false,
  }) => Semantics(
    button: true,
    toggled: toggle ? enabled : null,
    label: label,
    child: InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: _settingCard(
        child: Row(
          children: [
            _rowIcon(icon),
            const SizedBox(width: 9),
            Expanded(child: _rowLabel(label)),
            const SizedBox(width: 6),
            _switchIndicator(enabled),
          ],
        ),
      ),
    ),
  );

  Widget _rowIcon(IconData icon) => Icon(
    icon,
    size: 26,
    color: _goldLight,
    shadows: const [
      Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 3),
    ],
  );

  Widget _rowLabel(String label) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: const TextStyle(
        color: _cream,
        fontSize: appPopupBodyFontSize * _metricScale,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _settingCard({required Widget child}) => Container(
    key: const ValueKey('settings-option-card'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF163C29), Color(0xFF092D20), Color(0xFF052619)],
      ),
      border: Border.all(color: const Color(0xFF407454), width: 0.8),
      boxShadow: const [
        BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 3),
      ],
    ),
    child: child,
  );

  Widget _switchIndicator(bool enabled) => AnimatedContainer(
    key: const ValueKey('settings-switch-indicator'),
    duration: const Duration(milliseconds: 160),
    width: 50,
    height: 24,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: enabled
            ? const [Color(0xFF63DC47), Color(0xFF119237)]
            : const [Color(0xFF213D32), Color(0xFF09291F)],
      ),
      border: Border.all(
        color: enabled ? _goldLight : const Color(0xFF6D806D),
        width: 1.4,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 3),
      ],
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFEDB6), Color(0xFFD5B875)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 2)],
        ),
        child: enabled
            ? const Icon(
                Icons.check_rounded,
                size: 13,
                color: Color(0xFF145037),
              )
            : null,
      ),
    ),
  );

  Widget _languageCard() => _settingCard(
    child: Row(
      key: const ValueKey('language-setting'),
      children: [
        _rowIcon(Icons.language_rounded),
        const SizedBox(width: 12),
        Expanded(child: _rowLabel(_text('Dil', 'Language', de: 'Sprache'))),
        const SizedBox(width: 8),
        PopupMenuButton<AppLanguage>(
          key: const ValueKey('settings-language-dropdown'),
          tooltip: _text('Dil seç', 'Choose language', de: 'Sprache wählen'),
          initialValue: settings.language,
          color: const Color(0xFF123B2B),
          onSelected: (language) =>
              setState(() => settings = settings.copyWith(language: language)),
          itemBuilder: (_) => [
            for (final entry in const [
              ('TR', 'Türkçe', AppLanguage.turkish),
              ('EN', 'English', AppLanguage.english),
              ('DE', 'Deutsch', AppLanguage.german),
            ])
              PopupMenuItem(
                key: ValueKey('language-${entry.$1}'),
                value: entry.$3,
                child: Text(
                  entry.$2,
                  style: const TextStyle(
                    color: _cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
          child: Container(
            width: 126,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF102D21),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _goldLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      switch (settings.language) {
                        AppLanguage.turkish => 'Türkçe',
                        AppLanguage.english => 'English',
                        AppLanguage.german => 'Deutsch',
                      },
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  color: _goldLight,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fontScaleCard() => SizedBox(
    height: 48,
    child: _settingCard(
      child: Row(
        children: [
          SizedBox(
            width: 164,
            child: _rowLabel(_text('Yazı Boyutu', 'Text Size')),
          ),
          const SizedBox(width: 12),
          const Text(
            'A',
            style: TextStyle(
              color: _goldLight,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              ),
              child: Slider(
                value: settings.fontScale,
                min: 0.85,
                max: 1.25,
                divisions: 8,
                label: '${(settings.fontScale * 100).round()}%',
                activeColor: _goldLight,
                inactiveColor: const Color(0xFF285B43),
                onChanged: (value) => setState(
                  () => settings = settings.copyWith(fontScale: value),
                ),
              ),
            ),
          ),
          const Text(
            'A',
            style: TextStyle(
              color: _goldLight,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(
            width: 130,
            child: ValueListenableBuilder<bool>(
              valueListenable: performanceOverlayEnabled,
              builder: (context, enabled, _) => TextButton.icon(
                key: const ValueKey('settings-performance-button'),
                onPressed: () => performanceOverlayEnabled.value = !enabled,
                icon: Icon(
                  enabled ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                  size: 19,
                ),
                label: Text(
                  _text('Performans', 'Performance', de: 'Leistung'),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _goldLight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _footer() {
    final navigationCount =
        (widget.onHome != null ? 1 : 0) + (widget.onRestart != null ? 1 : 0);
    // Widen in-game actions within the existing panel, keeping equal heights.
    final actionWidth = navigationCount == 0
        ? AppButtonMetrics.menuWidth
        : AppButtonMetrics.gameWidth;
    Widget action({
      required String key,
      required String label,
      required VoidCallback onPressed,
      String? artworkAsset,
      bool yellow = false,
    }) => AppArtworkButton(
      key: ValueKey(key),
      width: actionWidth,
      height: AppButtonMetrics.height,
      fontSize: appPopupBodyFontSize * _metricScale,
      label: label,
      artworkAsset: artworkAsset,
      yellow: yellow,
      onPressed: onPressed,
    );

    final actions = [
      if (widget.onHome != null)
        action(
          key: 'settings-home-button',
          label: _text('ANA SAYFA', 'HOME', de: 'STARTSEITE'),
          artworkAsset: AppButtonAssets.home,
          onPressed: () => _closeThen(widget.onHome!),
        ),
      if (widget.onRestart != null)
        action(
          key: 'settings-restart-button',
          label: _text('YENİDEN BAŞLAT', 'RESTART', de: 'NEU STARTEN'),
          artworkAsset: AppButtonAssets.restart,
          onPressed: () => _closeThen(widget.onRestart!),
        ),
      action(
        key: 'settings-default-button',
        label: _text('VARSAYILAN', 'DEFAULT'),
        yellow: true,
        onPressed: () => setState(() => settings = const AppSettings()),
      ),
      action(
        key: 'settings-save-button',
        label: _text('KAYDET', 'SAVE', de: 'SPEICHERN'),
        onPressed: () => Navigator.of(context).pop(settings),
      ),
    ];
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          key: const ValueKey('settings-footer-row'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}

/// Display only the frame area, preserving the supplied asset unchanged.
class _SettingsArtworkCrop extends StatelessWidget {
  final Widget child;
  const _SettingsArtworkCrop({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

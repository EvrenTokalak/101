import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';

/// Settings percentages are relative to this baseline: the former 105% is
/// now 100%. Keep stored/displayed values nominal instead of scaling twice.
const double appBaseFontScale = 1.05;

TextScaler appTextScaler(double relativeScale) =>
    TextScaler.linear(appBaseFontScale * relativeScale);

const appSettingsPanelAsset =
    'görseller/icon/Ornate AYARLAR Game Settings Panel.png';

const appSettingsArtwork = ResizeImage(
  AssetImage(appSettingsPanelAsset),
  width: 1000,
);

Size appSettingsPanelSize(BoxConstraints bounds) {
  final width = bounds.maxWidth.clamp(0.0, appPopupWidth);
  final height = bounds.maxHeight.clamp(
    0.0,
    (width * 941 / 1671).clamp(0.0, appPopupHeight),
  );
  return Size(height * 1671 / 941, height);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      precacheImage(appSettingsArtwork, context, onError: (_, _) {});
    }
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
    bool moveHints = true,
    this.fontScale = 1,
    this.language = AppLanguage.turkish,
  }) : _moveHints = moveHints;

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
  static const _canvasHeight = _canvasWidth * 941 / 1671;

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
              child: FittedBox(
                child: SizedBox(
                  width: _canvasWidth,
                  height: _canvasHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: appTextScaler(settings.fontScale)),
                    child: Material(
                      color: Colors.transparent,
                      child: Stack(
                        key: const ValueKey('settings-panel-ready'),
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: ClipPath(
                                clipper: const _SettingsArtworkClipper(),
                                child: Image(
                                  image: appSettingsArtwork,
                                  key: const ValueKey('settings-panel-artwork'),
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                  frameBuilder:
                                      (_, artwork, frame, synchronous) =>
                                          synchronous || frame != null
                                          ? artwork
                                          : _artworkFallback(),
                                  errorBuilder: (_, _, _) => _artworkFallback(),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 310,
                            right: 310,
                            top: 24,
                            height: 40,
                            child: Center(
                              child: Text(
                                _text(
                                  'AYARLAR',
                                  'SETTINGS',
                                  de: 'EINSTELLUNGEN',
                                ),
                                style: TextStyle(
                                  color:
                                      settings.language == AppLanguage.turkish
                                      ? Colors.transparent
                                      : _cream,
                                  backgroundColor:
                                      settings.language == AppLanguage.turkish
                                      ? Colors.transparent
                                      : const Color(0xFF63300D),
                                  fontSize: 19 * _metricScale,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 42,
                            top: 52,
                            child: AppCloseButton(
                              buttonKey: const ValueKey(
                                'settings-close-button',
                              ),
                              size: 40 * _metricScale,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Positioned(
                            left: 88,
                            right: 88,
                            top: 100,
                            bottom: 48,
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
        if (i > 0) const SizedBox(height: 6),
        Expanded(child: options[i]),
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
            const SizedBox(width: 12),
            Expanded(child: _rowLabel(label)),
            const SizedBox(width: 8),
            _switchIndicator(enabled),
          ],
        ),
      ),
    ),
  );

  Widget _rowIcon(IconData icon) => Icon(
    icon,
    size: 34,
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    width: 62,
    height: 29,
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
        width: 23,
        height: 23,
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
                size: 17,
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
            height: 34,
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
                  size: 21,
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
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
          const SizedBox(width: 130),
        ],
      ),
    ),
  );

  Widget _footer() => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        key: const ValueKey('settings-footer-row'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onHome != null)
            FilledButton.icon(
              key: const ValueKey('settings-home-button'),
              onPressed: () => _closeThen(widget.onHome!),
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  160,
                  appPopupButtonHeight * _metricScale,
                ),
                textStyle: const TextStyle(
                  fontSize: appPopupBodyFontSize * _metricScale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(Icons.home_rounded),
              label: Text(_text('ANA SAYFA', 'HOME', de: 'STARTSEITE')),
            ),
          if (widget.onHome != null) const SizedBox(width: 8),
          if (widget.onRestart != null)
            FilledButton.icon(
              key: const ValueKey('settings-restart-button'),
              onPressed: () => _closeThen(widget.onRestart!),
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  160,
                  appPopupButtonHeight * _metricScale,
                ),
                textStyle: const TextStyle(
                  fontSize: appPopupBodyFontSize * _metricScale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(
                _text('YENİDEN BAŞLAT', 'RESTART', de: 'NEU STARTEN'),
              ),
            ),
          if (widget.onRestart != null) const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => setState(() => settings = const AppSettings()),
            style: OutlinedButton.styleFrom(
              foregroundColor: _cream,
              backgroundColor: const Color(0xFF093B30),
              side: const BorderSide(color: Color(0xFF6CA498), width: 2),
              shape: const StadiumBorder(),
              elevation: 5,
              shadowColor: Colors.black87,
              minimumSize: Size(
                widget.onHome == null ? 340 : 160,
                appPopupButtonHeight * _metricScale,
              ),
              textStyle: const TextStyle(
                fontSize: appPopupBodyFontSize * _metricScale,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(_text('VARSAYILAN', 'DEFAULT')),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(settings),
            style: FilledButton.styleFrom(
              elevation: 4,
              shadowColor: Colors.black87,
              backgroundColor: _goldLight,
              foregroundColor: const Color(0xFF5C3A1E),
              shape: const StadiumBorder(),
              side: const BorderSide(color: Color(0xFFFFEDAD), width: 2),
              minimumSize: Size(
                widget.onHome == null ? 340 : 160,
                appPopupButtonHeight * _metricScale,
              ),
            ),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              _text('KAYDET', 'SAVE', de: 'SPEICHERN'),
              style: const TextStyle(
                fontSize: appPopupBodyFontSize * _metricScale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}

/// The supplied RGB image has a baked-in checkerboard outside the frame.
/// Mask that area in the UI, without modifying the original artwork.
class _SettingsArtworkClipper extends CustomClipper<Path> {
  const _SettingsArtworkClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(174, 95)
      ..lineTo(187, 83)
      ..lineTo(243, 61)
      ..lineTo(244, 48)
      ..quadraticBezierTo(241, 35, 254, 32)
      ..lineTo(322, 18)
      ..quadraticBezierTo(334, 17, 340, 31)
      ..lineTo(350, 76)
      ..lineTo(350, 28)
      ..quadraticBezierTo(348, 15, 361, 12)
      ..lineTo(427, 1)
      ..quadraticBezierTo(442, 0, 446, 16)
      ..lineTo(453, 57)
      ..lineTo(486, 57)
      ..lineTo(487, 52)
      ..lineTo(523, 64)
      ..lineTo(545, 44)
      ..quadraticBezierTo(556, 9, 598, 9)
      ..lineTo(1077, 9)
      ..quadraticBezierTo(1115, 9, 1129, 44)
      ..lineTo(1152, 65)
      ..lineTo(1183, 53)
      ..lineTo(1184, 57)
      ..lineTo(1210, 57)
      ..lineTo(1220, 16)
      ..quadraticBezierTo(1224, 0, 1240, 2)
      ..lineTo(1305, 15)
      ..quadraticBezierTo(1318, 17, 1315, 31)
      ..lineTo(1307, 68)
      ..lineTo(1318, 38)
      ..quadraticBezierTo(1322, 23, 1336, 25)
      ..lineTo(1402, 42)
      ..quadraticBezierTo(1416, 45, 1411, 59)
      ..lineTo(1427, 65)
      ..quadraticBezierTo(1464, 70, 1491, 94)
      ..lineTo(1513, 95)
      ..quadraticBezierTo(1550, 95, 1563, 143)
      ..quadraticBezierTo(1590, 158, 1590, 189)
      ..lineTo(1590, 783)
      ..quadraticBezierTo(1590, 818, 1559, 839)
      ..quadraticBezierTo(1551, 899, 1492, 899)
      ..lineTo(175, 899)
      ..quadraticBezierTo(125, 899, 112, 841)
      ..quadraticBezierTo(81, 820, 81, 783)
      ..lineTo(81, 189)
      ..quadraticBezierTo(81, 159, 107, 144)
      ..quadraticBezierTo(116, 96, 151, 95)
      ..close();
    return path.transform(
      Matrix4.diagonal3Values(size.width / 1671, size.height / 941, 1).storage,
    );
  }

  @override
  bool shouldReclip(_SettingsArtworkClipper oldClipper) => false;
}

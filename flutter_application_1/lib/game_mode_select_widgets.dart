part of 'game_mode_select.dart';

class _ModeCard extends StatelessWidget {
  final _GameModeData mode;
  final bool selected;
  final VoidCallback onTap, onInfo;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: _localizedModeLabel(mode.id),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final scale = math.min(bounds.maxWidth / 400, bounds.maxHeight / 550);
        final offset = Offset(
          (bounds.maxWidth - 400 * scale) / 2,
          (bounds.maxHeight - 550 * scale) / 2,
        );
        final infoHitSize = math.max(44.0, 62 * scale);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: ValueKey('game-mode-card-${mode.id}'),
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 400,
                    height: 550,
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [mode.accentDark, const Color(0xFF000A05)],
                        ),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFF2FFA6)
                              : const Color(0xFFE3CE75),
                          width: selected ? 3 : 2,
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: mode.accent.withValues(alpha: .75),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          const BoxShadow(
                            color: Colors.black87,
                            blurRadius: 7,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(painter: _ModeShinePainter()),
                            ),
                            Positioned(
                              left: 3,
                              right: 3,
                              top: 80,
                              height: 254,
                              child: RepaintBoundary(
                                child: _ModeReferenceArtwork(id: mode.id),
                              ),
                            ),
                            if (selected)
                              Positioned(
                                top: 18,
                                right: 18,
                                width: 102,
                                height: 44,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFF290),
                                        Color(0xFFF4B728),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFFFED8F),
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Center(
                                      child: _ModeText(
                                        appText('SEÇİLİ', 'SELECTED'),
                                        fontSize: 24,
                                        color: const Color(0xFF211900),
                                        shadow: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 343,
                              left: 15,
                              right: 15,
                              height: 100,
                              child: Center(
                                child: _ModeText(
                                  mode.id == 'classic-101'
                                      ? appText(
                                          'KURALI SEN\nBELİRLE',
                                          'SET YOUR\nRULES',
                                        )
                                      : _localizedModeLabel(mode.id),
                                  fontSize: 42,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 18,
                              top: 448,
                              height: 70,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  color: const Color(0xC9000B06),
                                  border: Border.all(
                                    color: mode.accent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.people_rounded,
                                      color: Color(0xFFFFF6DC),
                                      size: 40,
                                    ),
                                    const SizedBox(width: 14),
                                    Flexible(
                                      child: _ModeText(
                                        _localizedModeFeatures(mode.id)
                                            .take(2)
                                            .join('  •  '),
                                        fontSize: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Keep the information control at least 44 screen pixels even when
            // the artwork canvas scales down on a landscape phone.
            Positioned(
              left: offset.dx + 48 * scale - infoHitSize / 2,
              top: offset.dy + 46 * scale - infoHitSize / 2,
              width: infoHitSize,
              height: infoHitSize,
              child: Semantics(
                button: true,
                label:
                    '${_localizedModeLabel(mode.id)} ${appText('bilgisi', 'information')}',
                child: GestureDetector(
                  key: ValueKey('game-mode-info-${mode.id}'),
                  onTap: onInfo,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: (58 * scale).clamp(24.0, 58.0),
                      height: (58 * scale).clamp(24.0, 58.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xB3001007),
                        border: Border.all(color: mode.accent, width: 1.5),
                      ),
                      child: _ModeText(
                        'i',
                        fontSize: (42 * scale).clamp(20.0, 42.0),
                        color: mode.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Only the illustrations are sampled; card copy and controls remain live.
class _ModeReferenceArtwork extends StatelessWidget {
  final String id;
  const _ModeReferenceArtwork({required this.id});

  static const _crops = {
    'classic-101': Rect.fromLTWH(104, 245, 394, 254),
    'timed-101': Rect.fromLTWH(534, 245, 380, 254),
    'color-bonus-101': Rect.fromLTWH(949, 245, 381, 254),
    'progressive': Rect.fromLTWH(1365, 245, 398, 254),
  };

  @override
  Widget build(BuildContext context) {
    final crop = _crops[id]!;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .06, .94, 1],
      ).createShader(rect),
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: crop.width,
          height: crop.height,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -crop.left,
                  top: -crop.top,
                  width: 1862,
                  height: 845,
                  child: Image.asset(
                    'images/ui/icons/mode-reference.webp',
                    key: ValueKey('game-mode-art-$id'),
                    width: 1862,
                    height: 845,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final int maxLines;
  final bool shadow;
  const _ModeText(
    this.text, {
    required this.fontSize,
    this.color = const Color(0xFFFFF4CB),
    this.maxLines = 1,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: maxLines,
      softWrap: false,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontFamily: 'Baloo 2',
        fontSize: fontSize,
        height: 1.1,
        fontWeight: FontWeight.w900,
        shadows: shadow
            ? const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ]
            : const [],
      ),
    ),
  );
}

class _ModeStartButton extends StatelessWidget {
  final double width, height;
  final VoidCallback onTap;
  const _ModeStartButton({
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: const LinearGradient(
        colors: [Color(0xFF0C741B), Color(0xFF397B14)],
      ),
      border: Border.all(color: const Color(0xFFFFED78), width: 1.6),
      boxShadow: const [
        BoxShadow(color: Color(0x555EDD37), blurRadius: 9),
        BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
      ],
    ),
    child: TextButton(
      key: const ValueKey('game-mode-start'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: _ModeText(
              appText('BU MODDA OYNA', 'PLAY THIS MODE'),
              fontSize: 23,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModeShinePainter extends CustomPainter {
  const _ModeShinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(-20, 200)
        ..lineTo(120, 0)
        ..lineTo(170, 0)
        ..lineTo(-20, 270)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .035),
    );
  }

  @override
  bool shouldRepaint(_ModeShinePainter oldDelegate) => false;
}

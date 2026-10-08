part of 'game.dart';

class _TileMotionScope extends InheritedWidget {
  final ValueNotifier<_TableTileMotion?> motion;
  const _TileMotionScope({required this.motion, required super.child});
  @override
  bool updateShouldNotify(_TileMotionScope oldWidget) =>
      motion != oldWidget.motion;
}

Rect? _gameRectForKey(BuildContext context, Key key) {
  Element root = context as Element;
  context.visitAncestorElements((element) {
    root = element;
    return true;
  });
  RenderBox? match;
  void visit(Element element) {
    if (match != null) return;
    if (element.widget.key == key) {
      final render = element.findRenderObject();
      if (render is RenderBox && render.hasSize) match = render;
      return;
    }
    element.visitChildren(visit);
  }

  visit(root);
  final box = match;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}

class _FlyingPlayerTiles extends StatelessWidget {
  final _TableTileMotion motion;
  const _FlyingPlayerTiles({required this.motion});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final origin = (context.findRenderObject() as RenderBox).localToGlobal(
          Offset.zero,
        );
        final isDraw =
            motion.kind == _TableTileMotionKind.drawDeck ||
            motion.kind == _TableTileMotionKind.drawDiscard;
        return Stack(
          children: [
            for (final tile in motion.tiles)
              if (motion.sourceRects[tile.id] case final Rect source)
                if (_gameRectForKey(
                      context,
                      isDraw
                          ? ValueKey('rack-tile-${tile.id}')
                          : motion.kind == _TableTileMotionKind.discard
                          ? const ValueKey('discard-Oyuncu 1')
                          : ValueKey('table-visible-tile-${tile.id}'),
                    )
                    case final Rect target)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(
                      'player-tile-flight-${motion.serial}-${tile.id}',
                    ),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: motion.kind == _TableTileMotionKind.open
                          ? 580
                          : motion.kind == _TableTileMotionKind.process
                          ? 500
                          : 480,
                    ),
                    curve: Curves.easeInOutCubic,
                    builder: (context, value, _) {
                      final rect = Rect.lerp(
                        source,
                        target,
                        value,
                      )!.shift(-origin);
                      return Positioned(
                        left: rect.left,
                        top: rect.top,
                        width: rect.width,
                        height: rect.height,
                        child: _TileWidget(
                          tile: tile,
                          w: rect.width,
                          h: rect.height,
                          onTap: null,
                          hideOkey: true,
                          allowOkeyFaceToggle: false,
                          motionCopy: true,
                          emphasized: true,
                        ),
                      );
                    },
                  ),
          ],
        );
      },
    ),
  );
}

/// Oyun sahnesindeki dokunulabilir öğelere ortak, hafif bir basma hissi verir.
class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressScale({required this.child, this.enabled = true});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTapDown: (_) => _setPressed(true),
    onTapUp: (_) => _setPressed(false),
    onTapCancel: () => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? 0.93 : 1,
      duration: const Duration(milliseconds: 105),
      curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// Masa açılırken tüm sahneyi tek parça halinde yumuşakça yerine getirir.
class _GameSceneEntrance extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const _GameSceneEntrance({required this.child, required this.enabled});

  @override
  Widget build(BuildContext context) => child;
}

/// Button-drawn tiles retain a gentle pulse until the next pointer down.
class _DrawnTileAttention extends StatefulWidget {
  final Widget child;

  const _DrawnTileAttention({super.key, required this.child});

  @override
  State<_DrawnTileAttention> createState() => _DrawnTileAttentionState();
}

class _DrawnTileAttentionState extends State<_DrawnTileAttention>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final pulse = Curves.easeInOut.transform(_controller.value);
      return Stack(
        fit: StackFit.passthrough,
        children: [
          child!,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('drawn-tile-pulse-frame'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: OC.okeyGold.withValues(alpha: 0.45 + pulse * 0.55),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OC.okeyGold.withValues(alpha: 0.10 + pulse * 0.28),
                      blurRadius: 3 + pulse * 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _FinishCelebration extends StatefulWidget {
  final bool tutorial;
  const _FinishCelebration({this.tutorial = false});

  @override
  State<_FinishCelebration> createState() => _FinishCelebrationState();
}

class _FinishCelebrationState extends State<_FinishCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rawProgress = _controller.value;
          final value = Curves.easeOutCubic.transform(rawProgress);
          final badgeScale = sin(min(1, rawProgress) * pi).clamp(0, 1);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CelebrationPainter(progress: value),
                ),
              ),
              Center(
                child: Transform.scale(
                  scale: 0.72 + badgeScale * 0.46,
                  child: Opacity(
                    opacity: (1 - max(0, rawProgress - 0.82) / 0.18).clamp(
                      0,
                      1,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE62A1705),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: OC.okeyGold, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: OC.okeyGold.withValues(alpha: 0.65),
                            blurRadius: 28,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.tutorial
                                ? Icons.check_circle_rounded
                                : Icons.emoji_events_rounded,
                            key: widget.tutorial
                                ? const ValueKey('tutorial-completion-check')
                                : null,
                            color: widget.tutorial
                                ? const Color(0xFF66DB75)
                                : OC.okeyGold,
                            size: 52,
                          ),
                          Text(
                            widget.tutorial
                                ? 'ÖĞRETİCİ TAMAMLANDI!'
                                : 'ELDEN BİTTİN!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _CelebrationPainter extends CustomPainter {
  final double progress;

  const _CelebrationPainter({required this.progress});

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFFFF8A65),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var index = 0; index < 36; index++) {
      final angle = index * (2 * pi / 36) + (index.isEven ? 0.08 : -0.08);
      final ringScale = index.isEven ? 1.0 : 0.72;
      final distance =
          min(size.shortestSide * 0.52, 270) * progress * ringScale;
      final gravity = (index.isEven ? 44 : 30) * progress * progress;
      final point =
          center +
          Offset(cos(angle) * distance, sin(angle) * distance + gravity);
      paint.color = _colors[index % _colors.length].withValues(
        alpha: (1 - progress * 0.72).clamp(0, 1),
      );
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + progress * (index.isEven ? 3.2 : -2.5));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: index.isEven ? 9 : 7,
            height: index.isEven ? 17 : 12,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Çekilen, açılan veya işlenen taşları kaynak konumdan hedefe uçurur.
class _FlyingTableTiles extends StatelessWidget {
  final _TableTileMotion motion;

  const _FlyingTableTiles({required this.motion});

  Alignment get _playerSource => switch (motion.playerIndex) {
    1 => const Alignment(0.9, 0),
    2 => const Alignment(0, -0.92),
    3 => const Alignment(-0.9, 0),
    _ => const Alignment(0, 0.98),
  };

  @override
  Widget build(BuildContext context) {
    final isDraw =
        motion.kind == _TableTileMotionKind.drawDeck ||
        motion.kind == _TableTileMotionKind.drawDiscard;
    final source = switch (motion.kind) {
      _TableTileMotionKind.drawDeck => const Alignment(0, 0.56),
      _TableTileMotionKind.drawDiscard => const Alignment(-0.82, 0.74),
      _ => _playerSource,
    };
    final target = isDraw
        ? (motion.playerIndex > 0 ? _playerSource : const Alignment(0, 0.98))
        : motion.targetAlignment ?? Alignment.center;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final fullTravel = Offset(
            (source.x - target.x) * box.maxWidth / 2,
            (source.y - target.y) * box.maxHeight / 2,
          );
          final travel = motion.playerIndex == 0
              ? fullTravel
              : isDraw
              ? switch (motion.playerIndex) {
                  1 => const Offset(-64, 0),
                  2 => const Offset(0, 64),
                  _ => const Offset(64, 0),
                }
              : switch (motion.playerIndex) {
                  1 => const Offset(64, 0),
                  2 => const Offset(0, -64),
                  _ => const Offset(-64, 0),
                };
          return Align(
            alignment: target,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('table-tile-motion-${motion.serial}'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(
                milliseconds: isDraw
                    ? (motion.playerIndex > 0 ? 120 : 220)
                    : motion.kind == _TableTileMotionKind.process
                    ? (motion.playerIndex > 0 ? 140 : 230)
                    : (motion.playerIndex > 0 ? 170 : 310),
              ),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: travel * (1 - value),
                child: child,
              ),
              child: RepaintBoundary(
                child: _MotionTileFan(
                  tiles: motion.tiles,
                  faceDown: motion.kind == _TableTileMotionKind.drawDeck,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MotionTileFan extends StatelessWidget {
  final List<Tile> tiles;
  final bool faceDown;

  const _MotionTileFan({required this.tiles, required this.faceDown});

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return const _TileBack(width: 30, height: 39, showBorder: false);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < tiles.length; index++)
          Transform.translate(
            offset: Offset(index == 0 ? 0 : -index * 5.0, 0),
            child: _TileWidget(
              tile: tiles[index],
              w: 25,
              h: 32,
              onTap: null,
              hideOkey: true,
              allowOkeyFaceToggle: false,
              showShadow: false,
            ),
          ),
      ],
    );
  }
}

/// Yeni elde oyuncu taşlarını tek tek kapalı getirir, ardından sırayla çevirir.
class _DealtRackTile extends StatelessWidget {
  final int dealIndex;
  final double width;
  final double height;
  final Widget front;
  final ValueListenable<double> progress;

  const _DealtRackTile({
    super.key,
    required this.dealIndex,
    required this.width,
    required this.height,
    required this.front,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: progress,
    child: front,
    builder: (context, progressValue, frontChild) {
      const totalMs = 1650.0;
      final elapsed = progressValue * totalMs;
      final arrivalStart = dealIndex * 34.0;
      final revealStart = 820.0 + arrivalStart;
      if (elapsed < arrivalStart) {
        return SizedBox(width: width, height: height);
      }
      if (elapsed < revealStart) {
        final raw = ((elapsed - arrivalStart) / 150).clamp(0.0, 1.0);
        final value = Curves.easeOutCubic.transform(raw);
        return Transform.translate(
          offset: Offset(0, -height * 0.75 * (1 - value)),
          child: Transform.scale(
            scale: 0.9 + value * 0.1,
            child: _TileBack(width: width, height: height, showBorder: false),
          ),
        );
      }
      final raw = ((elapsed - revealStart) / 110).clamp(0.0, 1.0);
      final value = Curves.easeOutCubic.transform(raw);
      return Transform.scale(scaleX: 0.92 + value * 0.08, child: frontChild);
    },
  );
}

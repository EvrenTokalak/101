part of 'game.dart';

class _TileMotionScope extends InheritedWidget {
  final ValueNotifier<_TableTileMotion?> motion;
  final ValueNotifier<Set<int>> finishHiddenTileIds;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final ValueNotifier<_ProcessedTileHighlight?> processedHighlight;
  const _TileMotionScope({
    required this.motion,
    required this.finishHiddenTileIds,
    required this.dragVisual,
    required this.processedHighlight,
    required super.child,
  });
  @override
  bool updateShouldNotify(_TileMotionScope oldWidget) =>
      motion != oldWidget.motion ||
      finishHiddenTileIds != oldWidget.finishHiddenTileIds ||
      dragVisual != oldWidget.dragVisual ||
      processedHighlight != oldWidget.processedHighlight;
}

class _ProcessedTileHighlight {
  final int serial;
  final Set<int> tileIds;
  const _ProcessedTileHighlight(this.serial, this.tileIds);
}

class _ProcessedTileAccent extends StatelessWidget {
  final Tile tile;
  final ValueListenable<_ProcessedTileHighlight?> highlight;
  final Widget child;
  const _ProcessedTileAccent({
    required this.tile,
    required this.highlight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<_ProcessedTileHighlight?>(
        valueListenable: highlight,
        child: child,
        builder: (context, value, child) {
          if (value == null || !value.tileIds.contains(tile.id)) return child!;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(
                      'processed-tile-highlight-${tile.id}-${value.serial}',
                    ),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 280),
                    builder: (context, progress, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(
                          alpha: sin(progress * pi) * .28,
                        ),
                        border: Border.all(
                          color: tile.displayColor.withValues(
                            alpha: sin(progress * pi) * .65,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

Rect? _gameRectForKey(
  BuildContext context,
  Key key, {
  bool transformed = false,
}) {
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
  if (box == null) return null;
  return transformed
      ? MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        )
      : box.localToGlobal(Offset.zero) & box.size;
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
                      transformed: true,
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

/// Tiles spring out of the rack and lock into a fan for an opening-turn finish.
/// Both variants finish on the game table before the result popup opens.
class _FinishCelebration extends StatelessWidget {
  final bool tutorial;
  final bool spectacular;
  final List<_GridFinishTile> gridTiles;
  final VoidCallback? onComplete;
  const _FinishCelebration({
    this.tutorial = false,
    this.spectacular = true,
    this.gridTiles = const [],
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) => tutorial
      ? const _TutorialFinishCelebration(tutorial: true)
      : spectacular
      ? _TileFinishMotion(spectacular: true, onComplete: onComplete)
      : _GridFinishMotion(tiles: gridTiles, onComplete: onComplete);
}

class _GridFinishTile {
  final Tile tile;
  final Rect sourceRect;
  const _GridFinishTile({required this.tile, required this.sourceRect});
}

/// Capture only faces actually visible in one of the three meld grids.
List<_GridFinishTile> _captureGridFinishTiles(BuildContext context) {
  final tiles = <_GridFinishTile>[];
  const viewers = [
    ValueKey('run-grid-viewer'),
    ValueKey('pair-grid-viewer'),
    ValueKey('group-grid-viewer'),
  ];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is _TileWidget &&
        widget.key == ValueKey('table-visible-tile-${widget.tile.id}')) {
      final box = element.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        Rect? viewport;
        element.visitAncestorElements((ancestor) {
          if (!viewers.contains(ancestor.widget.key)) return true;
          final render = ancestor.findRenderObject();
          if (render is RenderBox && render.hasSize) {
            viewport = render.localToGlobal(Offset.zero) & render.size;
          }
          return false;
        });
        if (viewport != null && viewport!.contains(rect.center)) {
          tiles.add(_GridFinishTile(tile: widget.tile, sourceRect: rect));
        }
      }
      return;
    }
    element.visitChildren(visit);
  }

  visit(context as Element);
  tiles.sort((a, b) {
    final row = a.sourceRect.center.dy.compareTo(b.sourceRect.center.dy);
    return row != 0
        ? row
        : a.sourceRect.center.dx.compareTo(b.sourceRect.center.dx);
  });
  return List.unmodifiable(tiles);
}

/// The played tiles lift from their own cells and fold into a closing ribbon.
class _GridFinishMotion extends StatefulWidget {
  final List<_GridFinishTile> tiles;
  final VoidCallback? onComplete;
  const _GridFinishMotion({required this.tiles, this.onComplete});

  @override
  State<_GridFinishMotion> createState() => _GridFinishMotionState();
}

class _GridFinishMotionState extends State<_GridFinishMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1400),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onComplete?.call();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final origin = (context.findRenderObject() as RenderBox)
              .localToGlobal(Offset.zero);
          final sources = [
            for (final entry in widget.tiles) entry.sourceRect.shift(-origin),
          ];
          final region = sources.isEmpty
              ? (Offset.zero & bounds.biggest)
              : sources.reduce((a, b) => a.expandToInclude(b));
          return Stack(
            key: const ValueKey('round-end-tile-accent'),
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < widget.tiles.length; index++)
                _GridFinishTileFlight(
                  key: ValueKey(
                    'grid-finish-tile-${widget.tiles[index].tile.id}',
                  ),
                  tile: widget.tiles[index].tile,
                  sourceRect: sources[index],
                  region: region,
                  index: index,
                  count: widget.tiles.length,
                  animation: _controller,
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _GridFinishTileFlight extends StatelessWidget {
  final Tile tile;
  final Rect sourceRect;
  final Rect region;
  final int index;
  final int count;
  final Animation<double> animation;

  const _GridFinishTileFlight({
    super.key,
    required this.tile,
    required this.sourceRect,
    required this.region,
    required this.index,
    required this.count,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: _TileWidget(
      tile: tile,
      w: sourceRect.width,
      h: sourceRect.height,
      onTap: null,
      borderRadius: 2,
      hideOkey: true,
      allowOkeyFaceToggle: false,
      emphasized: true,
      numberScale: 1.08,
      showShadow: false,
      motionCopy: true,
    ),
    builder: (context, child) {
      final t = animation.value;
      final u = count <= 1 ? 0.5 : index / (count - 1);
      final move = Curves.easeInOutCubic.transform(
        ((t - u * 0.09) / 0.68).clamp(0.0, 1.0),
      );
      final close = Curves.easeInCubic.transform(
        ((t - 0.74) / 0.26).clamp(0.0, 1.0),
      );
      final width = min(region.width * 0.76, 390.0);
      final target =
          region.center +
          Offset(
            (u - 0.5) * width,
            sin(u * pi * 2) * min(30.0, region.height * 0.18),
          );
      final point =
          Offset.lerp(sourceRect.center, target, move)! +
          Offset(0, -sin(move * pi) * 24 - close * 12);
      final opacity = 1 - ((t - 0.78) / 0.22).clamp(0.0, 1.0);
      return Positioned(
        left: point.dx - sourceRect.width / 2,
        top: point.dy - sourceRect.height / 2,
        width: sourceRect.width,
        height: sourceRect.height,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: sin(u * pi * 2) * move * 0.22,
            child: Transform.scale(
              scale: 1 + sin(move * pi) * 0.10 - close * 0.12,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class _TileFinishMotion extends StatefulWidget {
  final bool spectacular;
  final VoidCallback? onComplete;
  const _TileFinishMotion({required this.spectacular, this.onComplete});

  @override
  State<_TileFinishMotion> createState() => _TileFinishMotionState();
}

class _TileFinishMotionState extends State<_TileFinishMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: widget.spectacular ? 1100 : 720),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onComplete?.call();
          })
          ..forward();
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
          final t = _controller.value;
          if (t >= 1) return const SizedBox.shrink();
          final opacity = (1 - ((t - 0.72) / 0.28).clamp(0.0, 1.0));
          return Stack(
            key: ValueKey(
              widget.spectacular
                  ? 'elden-tile-celebration'
                  : 'round-end-tile-accent',
            ),
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FinishTilesPainter(
                    progress: t,
                    spectacular: widget.spectacular,
                  ),
                ),
              ),
              if (widget.spectacular)
                Positioned.fill(
                  child: CustomPaint(
                    key: const ValueKey('elden-finish-confetti'),
                    painter: _EldenConfettiPainter(t),
                  ),
                ),
              if (widget.spectacular)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 74),
                    child: Opacity(
                      opacity: opacity * (t / 0.16).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale:
                            0.82 +
                            0.18 *
                                Curves.easeOutBack.transform(
                                  (t / 0.4).clamp(0.0, 1.0),
                                ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              appText('ELDEN BİTTİN!', 'ONE-TURN FINISH!'),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.8,
                                color: Color(0xFFFFF1B5),
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFAB28),
                                    blurRadius: 22,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
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
    ),
  );
}

/// Two side bursts frame the opening-turn finish without covering its text.
class _EldenConfettiPainter extends CustomPainter {
  final double progress;
  const _EldenConfettiPainter(this.progress);

  static const colors = [
    Color(0xFFFFD45A),
    Color(0xFFFFF2CD),
    Color(0xFF65E5B1),
    Color(0xFF65B8FF),
    Color(0xFFFF7373),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 96; i++) {
      final delay = (i % 6) * .022;
      if (progress <= delay) continue;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final seed = ((i * 37 + 11) % 101) / 100;
      final side = i.isEven ? 1.0 : -1.0;
      final origin = Offset(
        size.width * (i.isEven ? .18 : .82),
        size.height * .66,
      );
      final point =
          origin +
          Offset(
            side * (size.width * (.08 + seed * .46)) * t +
                sin(i * 1.7 + t * pi * 3) * 14 * t,
            -size.height * (.55 + seed * .40) * t + size.height * .85 * t * t,
          );
      final opacity =
          (t / .10).clamp(0.0, 1.0) * (1 - ((t - .70) / .30).clamp(0.0, 1.0));
      paint.color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(i * 2.4 + side * t * (5 + seed * 8));
      canvas.scale(.55 + .45 * cos(t * pi * 4 + i).abs(), 1);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: 4 + seed * 5,
          height: 3 + (i % 3) * 2,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EldenConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FinishTilesPainter extends CustomPainter {
  final double progress;
  final bool spectacular;
  const _FinishTilesPainter({
    required this.progress,
    required this.spectacular,
  });

  static const _colors = [
    Color(0xFFD13C32),
    Color(0xFF245CAF),
    Color(0xFFBD8B18),
    Color(0xFF232323),
  ];
  static final _numbers = List<TextPainter>.generate(52, (index) {
    return TextPainter(
      text: TextSpan(
        text: '${index % 13 + 1}',
        style: TextStyle(
          fontFamily: 'Baloo 2',
          color: _colors[index ~/ 13],
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });

  void _tile(
    Canvas canvas,
    Offset center,
    double width,
    double rotation,
    int number,
    int color,
    double alpha,
  ) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(width / 30);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, -22, 30, 44),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 3)),
      Paint()..color = const Color(0xFF8B7046).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFFFFF5DF).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = OC.goldLight.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    // A layer fades both the face number and its small suit mark together.
    canvas.saveLayer(
      const Rect.fromLTWH(-15, -22, 30, 44),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    final label = _numbers[color * 13 + number - 1];
    label.paint(canvas, Offset(-label.width / 2, -18));
    canvas.drawCircle(
      const Offset(0, 13),
      2.5,
      Paint()..color = _colors[color],
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final fade = 1 - ((t - 0.72) / 0.28).clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final radius = min(size.shortestSide * 0.34, 150.0);
    final pulse = sin(t * pi) * fade;
    canvas.drawCircle(
      center,
      radius * 1.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            OC.goldLight.withValues(alpha: pulse * 0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.45)),
    );
    for (var i = 0; i < 21; i++) {
      final local = ((t - (i % 7) * 0.012) / 0.42).clamp(0.0, 1.0);
      final arrival = Curves.easeOutBack.transform(local);
      final angle = pi + i * pi / 20;
      final target =
          center + Offset(cos(angle) * radius * 1.45, sin(angle) * radius - 30);
      final source = Offset(
        center.dx + (i - 10) * 4,
        min(size.height - 30, center.dy + radius * 1.2),
      );
      final position = Offset.lerp(source, target, arrival)!;
      final depart = Curves.easeInCubic.transform(
        ((t - 0.74) / 0.26).clamp(0.0, 1.0),
      );
      final outward = (target - center) * depart * 0.4;
      if (local > 0 && local < 1) {
        final trail = Path()
          ..moveTo(source.dx, source.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy - radius,
            position.dx,
            position.dy,
          );
        canvas.drawPath(
          trail,
          Paint()
            ..color = OC.goldLight.withValues(alpha: (1 - local) * fade * 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      _tile(
        canvas,
        position + outward,
        (radius / 4.6).clamp(18.0, 30.0),
        (angle - 1.5 * pi) * 0.46 * arrival,
        i % 13 + 1,
        i % 4,
        fade * (local / 0.2).clamp(0.0, 1.0),
      );
    }
    final underline =
        radius * Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    canvas.drawLine(
      center + Offset(-underline, 67),
      center + Offset(underline, 67),
      Paint()
        ..color = OC.goldLight.withValues(alpha: pulse * 0.8)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FinishTilesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.spectacular != spectacular;
}

class _TutorialFinishCelebration extends StatefulWidget {
  final bool tutorial;
  const _TutorialFinishCelebration({this.tutorial = false});

  @override
  State<_TutorialFinishCelebration> createState() =>
      _TutorialFinishCelebrationState();
}

class _TutorialFinishCelebrationState extends State<_TutorialFinishCelebration>
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

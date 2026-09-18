part of 'game.dart';

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

/// Sırası gelen oyuncunun çerçevesi zaten vurgulandığı için ek kare üretmez.
class _ActiveTurnPulse extends StatelessWidget {
  final Widget child;
  final bool active;

  const _ActiveTurnPulse({required this.child, required this.active});

  @override
  Widget build(BuildContext context) => child;
}

/// Istakanın iki dış kenarı da doluysa yeni çekilen taşı kısa süre vurgular.
class _DrawnTileAttention extends StatefulWidget {
  final Widget child;

  const _DrawnTileAttention({super.key, required this.child});

  @override
  State<_DrawnTileAttention> createState() => _DrawnTileAttentionState();
}

class _DrawnTileAttentionState extends State<_DrawnTileAttention>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(count: 2);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.13), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.13, end: 0.97), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.97, end: 1), weight: 35),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    child: RepaintBoundary(child: widget.child),
    builder: (context, child) =>
        Transform.scale(scale: _scale.value, child: child),
  );
}

class _FinishCelebration extends StatefulWidget {
  const _FinishCelebration();

  @override
  State<_FinishCelebration> createState() => _FinishCelebrationState();
}

class _FinishCelebrationState extends State<_FinishCelebration> {
  static const _frameInterval = Duration(milliseconds: 50);
  static const _durationMs = 850;
  Timer? _timer;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_frameInterval, (timer) {
      if (!mounted) return;
      final next = min(_durationMs, _elapsedMs + _frameInterval.inMilliseconds);
      if (next == _elapsedMs) return;
      setState(() => _elapsedMs = next);
      if (_elapsedMs >= _durationMs) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: Builder(
        builder: (context) {
          final rawProgress = _elapsedMs / _durationMs;
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
                  scale: 0.72 + badgeScale * 0.38,
                  child: Opacity(
                    opacity: (1 - max(0, rawProgress - 0.72) / 0.28).clamp(
                      0,
                      1,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xE62A1705),
                        shape: BoxShape.circle,
                        border: Border.all(color: OC.okeyGold, width: 3),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: OC.okeyGold,
                        size: 42,
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
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var index = 0; index < 18; index++) {
      final angle = index * (2 * pi / 18) + (index.isEven ? 0.08 : -0.08);
      final distance = min(size.shortestSide * 0.44, 210) * progress;
      final gravity = 32 * progress * progress;
      final point =
          center +
          Offset(cos(angle) * distance, sin(angle) * distance + gravity);
      paint.color = _colors[index % _colors.length].withValues(
        alpha: (1 - progress * 0.72).clamp(0, 1),
      );
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + progress * 2.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: index.isEven ? 8 : 6,
            height: index.isEven ? 14 : 10,
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
        : Alignment.center;

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
                    ? (motion.playerIndex > 0 ? 160 : 220)
                    : motion.kind == _TableTileMotionKind.process
                    ? (motion.playerIndex > 0 ? 180 : 230)
                    : (motion.playerIndex > 0 ? 240 : 310),
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
class _DealtRackTile extends StatefulWidget {
  final int dealIndex;
  final double width;
  final double height;
  final Widget front;

  const _DealtRackTile({
    super.key,
    required this.dealIndex,
    required this.width,
    required this.height,
    required this.front,
  });

  @override
  State<_DealtRackTile> createState() => _DealtRackTileState();
}

class _DealtRackTileState extends State<_DealtRackTile> {
  Timer? _arrivalTimer;
  Timer? _revealTimer;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _arrivalTimer = Timer(Duration(milliseconds: widget.dealIndex * 34), () {
      if (mounted) setState(() => _phase = 1);
    });
    _revealTimer = Timer(
      Duration(milliseconds: 820 + widget.dealIndex * 34),
      () {
        if (mounted) setState(() => _phase = 2);
      },
    );
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: switch (_phase) {
      0 => SizedBox(width: widget.width, height: widget.height),
      1 => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: _TileBack(
          width: widget.width,
          height: widget.height,
          showBorder: false,
        ),
        builder: (context, value, child) => Transform.translate(
          offset: Offset(0, -widget.height * 0.75 * (1 - value)),
          child: Transform.scale(scale: 0.9 + value * 0.1, child: child),
        ),
      ),
      _ => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) =>
            Transform.scale(scaleX: value, child: child),
        child: widget.front,
      ),
    },
  );
}

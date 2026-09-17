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
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Transform.scale(scale: 0.985 + value * 0.015, child: child),
        ),
      ),
    );
  }
}

/// Sırası gelen oyuncuyu sabit bir çerçeve yerine nefes alan vurguyla belirtir.
class _ActiveTurnPulse extends StatefulWidget {
  final Widget child;
  final bool active;

  const _ActiveTurnPulse({required this.child, required this.active});

  @override
  State<_ActiveTurnPulse> createState() => _ActiveTurnPulseState();
}

class _ActiveTurnPulseState extends State<_ActiveTurnPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse();
  }

  void _pulse() => _controller.repeat(reverse: true, count: 2);

  @override
  void didUpdateWidget(covariant _ActiveTurnPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    widget.active ? _pulse() : _controller.reset();
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
    builder: (context, child) => Transform.scale(
      scale: widget.active ? 1 + _controller.value * 0.025 : 1,
      child: child,
    ),
  );
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
    final target = isDraw ? const Alignment(0, 0.98) : Alignment.center;

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('table-tile-motion-${motion.serial}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          final arc = sin(value * pi);
          return Align(
            alignment: Alignment.lerp(source, target, value)!,
            child: Transform.translate(
              offset: Offset(0, -arc * 28),
              child: Transform.rotate(
                angle: (0.5 - value) * (isDraw ? 0.16 : 0.08),
                child: Transform.scale(
                  scale: 0.9 + value * 0.1 + arc * 0.12,
                  child: Opacity(
                    opacity: value < 0.88 ? 1 : (1 - value) / 0.12,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
        child: _MotionTileFan(
          tiles: motion.tiles,
          faceDown: motion.kind == _TableTileMotionKind.drawDeck,
        ),
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
              w: 27,
              h: 35,
              onTap: null,
              hideOkey: true,
              allowOkeyFaceToggle: false,
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

class _DealtRackTileState extends State<_DealtRackTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final value = _controller.value;
      final arrivalStart = widget.dealIndex * 0.018;
      final arrival = ((value - arrivalStart) / 0.11).clamp(0.0, 1.0);
      final arrivalCurve = Curves.easeOutBack.transform(arrival);
      final revealStart = 0.55 + widget.dealIndex * 0.016;
      final flip = ((value - revealStart) / 0.075).clamp(0.0, 1.0);
      final showFront = flip >= 0.5;
      final angle = showFront ? pi * (flip - 1) : pi * flip;

      return Opacity(
        opacity: value < arrivalStart ? 0 : 1,
        child: Transform.translate(
          offset: Offset(0, -widget.height * 1.8 * (1 - arrivalCurve)),
          child: Transform.scale(
            scale: 0.84 + arrivalCurve * 0.16,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
              child: showFront
                  ? widget.front
                  : _TileBack(
                      width: widget.width,
                      height: widget.height,
                      showBorder: false,
                    ),
            ),
          ),
        ),
      );
    },
  );
}

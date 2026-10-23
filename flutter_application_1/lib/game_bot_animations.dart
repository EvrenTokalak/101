part of 'game.dart';

class _FlyingBotDiscard extends StatelessWidget {
  final _BotDiscardMotion motion;
  final double bottomReservedSpace;

  const _FlyingBotDiscard({
    required this.motion,
    required this.bottomReservedSpace,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          const tileWidth = 27.0;
          const tileHeight = 35.0;
          final startCenter = switch (motion.botIndex) {
            0 => Offset(box.maxWidth - 28, box.maxHeight / 2),
            1 => Offset(box.maxWidth / 2, 24),
            _ => Offset(28, box.maxHeight / 2),
          };
          final endTop = switch (motion.botIndex) {
            0 => const Offset(0, 46),
            1 => const Offset(8, 46),
            _ => Offset(
              8,
              box.maxHeight - max(2, bottomReservedSpace - 104) - tileHeight,
            ),
          };
          final targetLeft = motion.botIndex == 0
              ? box.maxWidth - 8 - tileWidth
              : endTop.dx;
          final targetTop = endTop.dy;
          final targetCenter = Offset(
            targetLeft + tileWidth / 2,
            targetTop + tileHeight / 2,
          );
          final travel = startCenter - targetCenter;
          return Stack(
            children: [
              Positioned(
                left: targetLeft,
                top: targetTop,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('bot-discard-motion-${motion.serial}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: _botDiscardTravelDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: travel * (1 - value),
                    child: child,
                  ),
                  child: RepaintBoundary(
                    child: _TileWidget(
                      tile: motion.tile,
                      w: tileWidth,
                      h: tileHeight,
                      onTap: null,
                      showShadow: false,
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
}

/// Resolve the real deck, seat and grid geometry once per motion, not per frame.
class _FlyingTableTiles extends StatelessWidget {
  final _TableTileMotion motion;
  const _FlyingTableTiles({required this.motion});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final origin = (context.findRenderObject() as RenderBox).localToGlobal(
          Offset.zero,
        );
        final isDraw =
            motion.kind == _TableTileMotionKind.drawDeck ||
            motion.kind == _TableTileMotionKind.drawDiscard;
        final seat = _gameRectForKey(
          context,
          ValueKey('seat-Oyuncu ${motion.playerIndex + 1}'),
          transformed: true,
        );
        final fallbackSeat = switch (motion.playerIndex) {
          1 => Offset(bounds.maxWidth - 28, bounds.maxHeight / 2),
          2 => Offset(bounds.maxWidth / 2, 24),
          _ => Offset(28, bounds.maxHeight / 2),
        };
        final seatCenter = seat == null ? fallbackSeat : seat.center - origin;
        final drawSource = isDraw
            ? _gameRectForKey(
                context,
                motion.kind == _TableTileMotionKind.drawDeck
                    ? const ValueKey('grid-deck-slot')
                    : ValueKey('discard-Oyuncu ${motion.playerIndex}'),
                transformed: true,
              )
            : null;
        return Stack(
          children: [
            for (var index = 0; index < motion.tiles.length; index++)
              _BotTableTileFlight(
                key: ValueKey(
                  'table-tile-motion-${motion.serial}-${motion.tiles[index].id}',
                ),
                tile: motion.tiles[index],
                source: Rect.fromCenter(
                  center: isDraw
                      ? (drawSource?.center ??
                                (origin + bounds.biggest.center(Offset.zero))) -
                            origin
                      : seatCenter,
                  width: 27,
                  height: 35,
                ),
                target: isDraw
                    ? Rect.fromCenter(center: seatCenter, width: 27, height: 35)
                    : (_gameRectForKey(
                            context,
                            ValueKey(
                              'table-visible-tile-${motion.tiles[index].id}',
                            ),
                            transformed: true,
                          )?.shift(-origin) ??
                          Rect.fromCenter(
                            center:
                                bounds.biggest.center(Offset.zero) +
                                Offset(index * 18.0, 0),
                            width: 25,
                            height: 32,
                          )),
                faceDown: motion.kind == _TableTileMotionKind.drawDeck,
                duration: isDraw
                    ? _botDrawTravelDuration
                    : motion.kind == _TableTileMotionKind.process
                    ? _botProcessTravelDuration
                    : _botOpenTravelDuration,
                index: index,
              ),
          ],
        );
      },
    ),
  );
}

class _BotTableTileFlight extends StatelessWidget {
  final Tile tile;
  final Rect source, target;
  final bool faceDown;
  final Duration duration;
  final int index;
  const _BotTableTileFlight({
    super.key,
    required this.tile,
    required this.source,
    required this.target,
    required this.faceDown,
    required this.duration,
    required this.index,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    child: RepaintBoundary(
      child: faceDown
          ? const _TileBack(width: 27, height: 35, showBorder: false)
          : _TileWidget(
              tile: tile,
              w: 27,
              h: 35,
              onTap: null,
              hideOkey: true,
              allowOkeyFaceToggle: false,
              showShadow: false,
              motionCopy: true,
            ),
    ),
    builder: (context, progress, child) {
      final value = Curves.easeInOutCubic.transform(
        ((progress - index * .045) / (1 - index * .045)).clamp(0.0, 1.0),
      );
      final rect = Rect.lerp(
        source,
        target,
        value,
      )!.translate(0, -sin(value * pi) * 18);
      return Positioned.fromRect(
        rect: rect,
        child: Transform.rotate(
          angle:
              sin(value * pi) *
              (source.center.dx > target.center.dx ? -.12 : .12),
          child: FittedBox(fit: BoxFit.fill, child: child),
        ),
      );
    },
  );
}

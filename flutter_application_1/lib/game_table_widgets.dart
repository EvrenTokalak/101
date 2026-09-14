part of 'game.dart';

class _DeckDragData {
  const _DeckDragData();
}

class _DiscardDragData {
  const _DiscardDragData();
}

class _DiscardDrawHandle extends StatelessWidget {
  final Tile tile;
  final bool enabled;
  final VoidCallback onTake;

  const _DiscardDrawHandle({
    super.key,
    required this.tile,
    required this.enabled,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    final content = _TileWidget(tile: tile, w: 27, h: 35, onTap: null);
    if (!enabled) return content;
    return Draggable<_DiscardDragData>(
      data: const _DiscardDragData(),
      feedback: Material(color: Colors.transparent, child: content),
      childWhenDragging: const SizedBox(width: 27, height: 35),
      child: GestureDetector(onTap: onTake, child: content),
    );
  }
}

class _DeckDrawHandle extends StatelessWidget {
  final bool enabled;
  final int count;
  final VoidCallback onDraw;
  final double feedbackWidth;
  final double feedbackHeight;

  const _DeckDrawHandle({
    required this.enabled,
    required this.count,
    required this.onDraw,
    required this.feedbackWidth,
    required this.feedbackHeight,
  });

  @override
  Widget build(BuildContext context) {
    final stack = _DeckStack(count: count);
    if (!enabled) return Opacity(opacity: 0.72, child: stack);
    return Tooltip(
      message: 'Dokun veya ıstakaya sürükleyerek taş çek',
      child: Draggable<_DeckDragData>(
        data: const _DeckDragData(),
        feedback: Material(
          color: Colors.transparent,
          child: _TileBack(
            width: feedbackWidth,
            height: feedbackHeight,
            showBorder: false,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.78,
          child: _DeckStack(count: max(0, count - 1)),
        ),
        child: _PressScale(
          child: GestureDetector(onTap: onDraw, child: stack),
        ),
      ),
    );
  }
}

class _TileBack extends StatelessWidget {
  final double width;
  final double height;
  final bool showBorder;

  const _TileBack({this.width = 40, this.height = 52, this.showBorder = true});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      image: const DecorationImage(
        image: AssetImage('images/tas_ters.png'),
        fit: BoxFit.fill,
      ),
      borderRadius: BorderRadius.circular(6),
      border: showBorder ? Border.all(color: OC.gold, width: 2) : null,
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
    ),
  );
}

class _TableDiscardPile extends StatelessWidget {
  final List<Tile> tiles;
  final String label;
  final bool active;
  final ValueChanged<_RackDragData>? onDrop;
  final bool takeEnabled;
  final VoidCallback? onTake;
  final bool showReturnButton;
  final VoidCallback? onReturn;

  const _TableDiscardPile({
    required this.tiles,
    required this.label,
    this.active = false,
    this.onDrop,
    this.takeEnabled = false,
    this.onTake,
    this.showReturnButton = false,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) => DragTarget<_RackDragData>(
    onWillAcceptWithDetails: (_) => active && onDrop != null,
    onAcceptWithDetails: (details) => onDrop?.call(details.data),
    builder: (context, candidates, rejected) {
      final highlighted = active || candidates.isNotEmpty;
      return SizedBox(
        key: ValueKey('discard-$label'),
        width: 34,
        height: 46,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 34,
            height: 46,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: highlighted
                    ? OC.numRed.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: highlighted ? OC.gold : Colors.white24,
                  width: highlighted ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: showReturnButton && onReturn != null
                        ? SizedBox(
                            key: const ValueKey('return-taken-discard'),
                            width: 27,
                            height: 35,
                            child: FilledButton(
                              onPressed: onReturn,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                backgroundColor: const Color(0xFF9A650E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: const BorderSide(color: OC.gold),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'TAŞI\nGERİ BIRAK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : tiles.isEmpty
                        ? const SizedBox(
                            key: ValueKey('empty-discard'),
                            width: 27,
                            height: 35,
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white24,
                            ),
                          )
                        : takeEnabled && onTake != null
                        ? _DiscardDrawHandle(
                            key: ValueKey('take-discard-${tiles.last.id}'),
                            tile: tiles.last,
                            enabled: true,
                            onTake: onTake!,
                          )
                        : _TileWidget(
                            key: ValueKey(tiles.last.id),
                            tile: tiles.last,
                            w: 27,
                            h: 35,
                            onTap: null,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

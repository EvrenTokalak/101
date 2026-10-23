part of 'game.dart';

class _RackArea extends StatefulWidget {
  final ValueListenable<bool> turnAttention;
  final int shiftSerial;
  final Map<int, int> shiftOrigins;
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final Function(int) onTileTap;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final Set<int> processableTileIds;
  final int? tutorialTileId;
  final Color processableColor;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;

  const _RackArea({
    super.key,
    required this.turnAttention,
    required this.shiftSerial,
    required this.shiftOrigins,
    required this.rack,
    required this.slots,
    required this.dealAnimationSerial,
    required this.onTileTap,
    required this.onReorder,
    required this.onTileDragStart,
    required this.onTileDragUpdate,
    required this.onTileDragEnd,
    required this.dragVisual,
    required this.pushPreview,
    required this.processableTileIds,
    this.tutorialTileId,
    required this.processableColor,
    this.minimumStandardOpeningScore,
    this.minimumPairOpeningCount,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  State<_RackArea> createState() => _RackAreaState();
}

class _RackAreaState extends State<_RackArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  );
  final ValueNotifier<double> _dealProgress = ValueNotifier<double>(1);

  void _syncDealProgress() {
    final next = _dealController.value;
    // Follow display frames instead of limiting the entire deal to 36 steps.
    _dealProgress.value = next;
  }

  @override
  void initState() {
    super.initState();
    _dealController.addListener(_syncDealProgress);
    if (widget.dealAnimationSerial != null) {
      _dealProgress.value = 0;
      _dealController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _RackArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dealAnimationSerial != null &&
        widget.dealAnimationSerial != oldWidget.dealAnimationSerial) {
      _dealProgress.value = 0;
      _dealController.forward(from: 0);
    } else if (widget.dealAnimationSerial == null) {
      _dealController.stop();
      _dealController.value = 1;
      _dealProgress.value = 1;
    }
  }

  @override
  void dispose() {
    _dealController.removeListener(_syncDealProgress);
    _dealController.dispose();
    _dealProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rackImage = ResizeImage(
      AssetImage(storeCosmetics.rackAsset),
      width: _rackDecodeWidth(context),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Stack(
        key: const ValueKey('rack-area-surface'),
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: rackImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, rackBox) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    rackBox.maxWidth * storeCosmetics.rackHorizontalInset,
                vertical: 2,
              ),
              child: DragTarget<_DeckDragData>(
                onWillAcceptWithDetails: (_) => false,
                onAcceptWithDetails: (_) {},
                builder: (context, candidates, rejected) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: candidates.isNotEmpty
                      ? const EdgeInsets.all(3)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? OC.numGreen.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: candidates.isNotEmpty
                        ? Border.all(color: OC.numGreen, width: 2)
                        : null,
                  ),
                  child: DragTarget<_DiscardDragData>(
                    onWillAcceptWithDetails: (_) => false,
                    onAcceptWithDetails: (_) {},
                    builder: (context, discardCandidates, rejected) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: discardCandidates.isNotEmpty
                                ? OC.gold.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: _RackRows(
                            shiftSerial: widget.shiftSerial,
                            shiftOrigins: widget.shiftOrigins,
                            rack: widget.rack,
                            slots: widget.slots,
                            dealAnimationSerial: widget.dealAnimationSerial,
                            dealProgress: _dealProgress,
                            processableTileIds: widget.processableTileIds,
                            tutorialTileId: widget.tutorialTileId,
                            processableColor: widget.processableColor,
                            onTileTap: widget.onTileTap,
                            onReorder: widget.onReorder,
                            onTileDragStart: widget.onTileDragStart,
                            onTileDragUpdate: widget.onTileDragUpdate,
                            onTileDragEnd: widget.onTileDragEnd,
                            dragVisual: widget.dragVisual,
                            pushPreview: widget.pushPreview,
                            canAcceptDeckDrop: widget.canAcceptDeckDrop,
                            canAcceptDiscardDrop: widget.canAcceptDiscardDrop,
                            onDeckDropAt: widget.onDeckDropAt,
                            onDiscardDropAt: widget.onDiscardDropAt,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RackSlotDropTarget extends StatelessWidget {
  final int slotIndex;
  final int rowEnd;
  final int? occupiedTileId;
  final double tileWidth;
  final double tileHeight;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final List<int?> rackSlots;
  final Widget child;

  const _RackSlotDropTarget({
    required this.slotIndex,
    required this.rowEnd,
    required this.occupiedTileId,
    required this.tileWidth,
    required this.tileHeight,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
    required this.onReorder,
    required this.pushPreview,
    required this.rackSlots,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    BuildContext? hitTestContext;

    ({int target, _RackMoveKind kind})? moveFor(
      Offset feedbackOffset,
      _RackDragData data,
    ) {
      if (occupiedTileId == null) {
        return (target: slotIndex, kind: _RackMoveKind.insert);
      }
      final renderObject = hitTestContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return null;
      }
      final center = feedbackOffset + Offset(tileWidth / 2, tileHeight / 2);
      final local = renderObject.globalToLocal(center);
      final overlap =
          min(local.dx + tileWidth / 2, renderObject.size.width) -
          max(local.dx - tileWidth / 2, 0.0);
      if (overlap < tileWidth * 0.05) return null;
      final seamWidth = renderObject.size.width * 0.08;
      final pushEdgeWidth = renderObject.size.width * 0.30;
      // The narrow seam inserts between tiles; the adjacent side bands push.
      // The centre is deliberately neutral to avoid accidental chain moves.
      if (local.dx <= seamWidth) {
        return slotIndex == data.sourceSlot
            ? null
            : (target: slotIndex, kind: _RackMoveKind.insert);
      }
      if (local.dx >= renderObject.size.width - seamWidth &&
          slotIndex + 1 < rowEnd) {
        final afterSlot = slotIndex + 1;
        return afterSlot == data.sourceSlot
            ? null
            : (target: afterSlot, kind: _RackMoveKind.insert);
      }
      if (local.dx > pushEdgeWidth &&
          local.dx < renderObject.size.width - pushEdgeWidth) {
        return null;
      }
      return slotIndex == data.sourceSlot
          ? null
          : (
              target: slotIndex,
              kind: local.dx <= renderObject.size.width / 2
                  ? _RackMoveKind.pushRight
                  : _RackMoveKind.pushLeft,
            );
    }

    return DragTarget<Object>(
      key: ValueKey('rack-slot-$slotIndex'),
      onWillAcceptWithDetails: (details) => switch (details.data) {
        _DeckDragData() => canAcceptDeckDrop,
        _DiscardDragData() => canAcceptDiscardDrop,
        _RackDragData(:final tileId, :final liftedForMeld, :final sourceSlot) =>
          !liftedForMeld &&
              sourceSlot ~/ _GameScreenState._rackRowLength ==
                  slotIndex ~/ _GameScreenState._rackRowLength &&
              tileId != occupiedTileId,
        _ => false,
      },
      onMove: (details) {
        final data = details.data;
        if (data is _RackDragData &&
            (data.liftedForMeld ||
                data.sourceSlot ~/ _GameScreenState._rackRowLength !=
                    slotIndex ~/ _GameScreenState._rackRowLength)) {
          return;
        }
        if (data is! _RackDragData || occupiedTileId == null) {
          if (pushPreview.value != null) pushPreview.value = null;
          return;
        }
        final move = moveFor(details.offset, data);
        if (move == null || move.target == data.sourceSlot) {
          if (pushPreview.value != null) pushPreview.value = null;
          return;
        }
        final previewSlots = List<int?>.from(rackSlots);
        previewSlots[data.sourceSlot] = null;
        final sameRow =
            data.sourceSlot ~/ _GameScreenState._rackRowLength ==
            move.target ~/ _GameScreenState._rackRowLength;
        int vacancy;
        var valid = true;
        if (move.kind == _RackMoveKind.insert) {
          vacancy = _nearestRackVacancy(previewSlots, move.target);
          final destination = vacancy < move.target
              ? move.target - 1
              : move.target;
          valid = vacancy >= 0 && destination != data.sourceSlot;
        } else {
          vacancy = _rackPushVacancy(
            previewSlots,
            data.sourceSlot,
            move.target,
            towardRight: move.kind == _RackMoveKind.pushRight,
          );
          valid = sameRow && vacancy >= 0;
        }
        final next = !valid
            ? null
            : _RackPushPreview(
                tileId: data.tileId,
                sourceSlot: data.sourceSlot,
                targetSlot: move.target,
                vacancySlot: vacancy,
                kind: move.kind,
              );
        final current = pushPreview.value;
        if (current?.tileId != next?.tileId ||
            current?.targetSlot != next?.targetSlot ||
            current?.vacancySlot != next?.vacancySlot ||
            current?.kind != next?.kind) {
          pushPreview.value = next;
        }
      },
      onLeave: (data) {
        if (data is _RackDragData &&
            !data.liftedForMeld &&
            data.sourceSlot ~/ _GameScreenState._rackRowLength ==
                slotIndex ~/ _GameScreenState._rackRowLength &&
            (pushPreview.value?.targetSlot ?? data.sourceSlot) ~/
                    _GameScreenState._rackRowLength ==
                data.sourceSlot ~/ _GameScreenState._rackRowLength &&
            pushPreview.value?.tileId == data.tileId) {
          pushPreview.value = null;
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is _DeckDragData) {
          onDeckDropAt(slotIndex);
          return;
        }
        if (data is _DiscardDragData) {
          onDiscardDropAt(slotIndex);
          return;
        }
        if (data is! _RackDragData) return;
        final preview = pushPreview.value;
        pushPreview.value = null;
        final move = preview?.tileId == data.tileId
            ? (target: preview!.targetSlot, kind: preview.kind)
            : moveFor(details.offset, data);
        if (move == null) return;
        onReorder(data.tileId, move.target, move.kind);
      },
      builder: (_, _, _) => Builder(
        builder: (context) {
          hitTestContext = context;
          return child;
        },
      ),
    );
  }
}

/// GitHub sürümündeki raf duruşunu ve sürükleme görünümünü yönetir.
/// Yer değiştirme, araya sokma ve zincir ittirme kararları ayrı tutulur.
class _RackTileDraggable extends StatelessWidget {
  final bool highlighted;
  final Color highlightColor;
  final Key draggableKey;
  final Tile tile;
  final _RackDragData data;
  final double width;
  final double height;
  final Widget child;
  final ValueChanged<_RackDragData> onDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final bool liftForMeld;

  const _RackTileDraggable({
    required this.highlighted,
    required this.highlightColor,
    required this.draggableKey,
    required this.tile,
    required this.data,
    required this.width,
    required this.height,
    required this.child,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.dragVisual,
    required this.liftForMeld,
  });

  @override
  Widget build(BuildContext context) => Draggable<_RackDragData>(
    key: draggableKey,
    data: data,
    dragAnchorStrategy: (_, _, _) =>
        Offset(width / 2, height / 2 + (liftForMeld ? _meldDragLift : 0)),
    // Processing uses the midpoint; rack drops keep their existing finger anchor.
    feedbackOffset: Offset(0, liftForMeld ? -_meldDragPlacementLift : 0),
    onDragStarted: () => onDragStart(data),
    onDragUpdate: (details) => onDragUpdate(data, details),
    onDragEnd: (_) => onDragEnd(),
    feedback: TweenAnimationBuilder<double>(
      // Keep the tile close to the finger while leaving its face visible.
      tween: Tween(begin: 0, end: liftForMeld ? 0 : height / 2 + 6),
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      builder: (context, lift, feedback) =>
          Transform.translate(offset: Offset(0, -lift), child: feedback),
      // Lift the visual clear of the fingertip while preserving the rack
      // drop position, so insertion/pushing does not jump rows.
      child: ValueListenableBuilder<_RackDragVisualState>(
        valueListenable: dragVisual,
        child: Material(
          key: const ValueKey('rack-drag-feedback-tile'),
          color: Colors.transparent,
          child: _TileWidget(
            tile: tile,
            w: width,
            h: height,
            onTap: null,
            hideOkey: true,
            emphasized: true,
            showShadow: false,
            processable: highlighted,
            processableColor: highlightColor,
          ),
        ),
        builder: (context, visual, feedbackChild) =>
            TweenAnimationBuilder<Offset>(
              tween: Tween(begin: Offset.zero, end: visual.snapOffset),
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) => Transform.translate(
                key: const ValueKey('rack-drag-target-alignment'),
                offset: offset,
                child: child,
              ),
              child: AnimatedRotation(
                turns: visual.tilt / (2 * pi),
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOutQuad,
                alignment: Alignment.bottomCenter,
                child: AnimatedScale(
                  scale: visual.gridPosition == null ? 1 : 1.04,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOutQuad,
                  child: feedbackChild,
                ),
              ),
            ),
      ),
    ),
    // Yalnızca aktif sürükleme süresince kaynak yuva boş görünür. Taş yeni
    // yuvaya geçince kendi görünümü otomatik olarak ve kalıcı gizleme olmadan döner.
    childWhenDragging: SizedBox(width: width, height: height),
    child: child,
  );
}

class _RackRows extends StatelessWidget {
  final int? tutorialTileId;
  final int shiftSerial;
  final Map<int, int> shiftOrigins;
  final List<Tile> rack;
  final List<int?> slots;
  final int? dealAnimationSerial;
  final ValueListenable<double> dealProgress;
  final Set<int> processableTileIds;
  final Color processableColor;
  final Function(int) onTileTap;
  final void Function(int, int, _RackMoveKind) onReorder;
  final ValueChanged<_RackDragData> onTileDragStart;
  final void Function(_RackDragData, DragUpdateDetails) onTileDragUpdate;
  final VoidCallback onTileDragEnd;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final ValueNotifier<_RackPushPreview?> pushPreview;
  final bool canAcceptDeckDrop;
  final bool canAcceptDiscardDrop;
  final ValueChanged<int> onDeckDropAt;
  final ValueChanged<int> onDiscardDropAt;
  const _RackRows({
    this.tutorialTileId,
    required this.shiftSerial,
    required this.shiftOrigins,
    required this.rack,
    required this.slots,
    required this.dealAnimationSerial,
    required this.dealProgress,
    required this.processableTileIds,
    required this.processableColor,
    required this.onTileTap,
    required this.onReorder,
    required this.onTileDragStart,
    required this.onTileDragUpdate,
    required this.onTileDragEnd,
    required this.dragVisual,
    required this.pushPreview,
    required this.canAcceptDeckDrop,
    required this.canAcceptDiscardDrop,
    required this.onDeckDropAt,
    required this.onDiscardDropAt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final avail = box.maxWidth;
        // Sürükleme sırasında hedef yuvalar 3'er piksel yatay vurgu alır.
        // En dar web görünümünde dahi satırın taşmaması için bu payı baştan ayır.
        final widthBasedTile = avail / _GameScreenState._rackRowLength - 1.6;
        final rowHeight = max(1.0, (box.maxHeight - 2) / 2);
        // Fit both dimensions together so short tablet windows cannot flatten tiles.
        final tw = max(1.0, min(widthBasedTile, rowHeight / 1.58));
        final th = tw * 1.58;
        return Column(
          children: [
            SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: _buildRow(0, tw, th),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: _buildRow(_GameScreenState._rackRowLength, tw, th),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Tile? _tileById(int? id) {
    if (id == null) return null;
    for (final tile in rack) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  Widget _buildRow(int offset, double tw, double th) {
    final selectedIds = rack
        .where((tile) => tile.selected)
        .map((tile) => tile.id)
        .toSet();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...List.generate(_GameScreenState._rackRowLength, (rowIndex) {
          final slotIndex = offset + rowIndex;
          final tile = _tileById(slots[slotIndex]);
          if (tile == null) {
            return _RackSlotDropTarget(
              slotIndex: slotIndex,
              rowEnd: offset + _GameScreenState._rackRowLength,
              occupiedTileId: null,
              tileWidth: tw,
              tileHeight: th,
              canAcceptDeckDrop: canAcceptDeckDrop,
              canAcceptDiscardDrop: canAcceptDiscardDrop,
              onDeckDropAt: onDeckDropAt,
              onDiscardDropAt: onDiscardDropAt,
              onReorder: onReorder,
              pushPreview: pushPreview,
              rackSlots: slots,
              child: Container(
                width: tw,
                height: th,
                margin: const EdgeInsets.symmetric(horizontal: 0.6),
              ),
            );
          }

          final dragData = _RackDragData(
            tileId: tile.id,
            sourceSlot: slotIndex,
            liftedForMeld: processableTileIds.contains(tile.id),
            tileIds: tile.selected ? selectedIds : {tile.id},
            tile: tile,
          );
          final visibleTile = _TileWidget(
            key: ValueKey('rack-visible-tile-$slotIndex'),
            tile: tile,
            w: tw,
            h: th,
            onTap: () => onTileTap(tile.id),
            hideOkey: true,
            emphasized: true,
            processable:
                processableTileIds.contains(tile.id) ||
                tile.id == tutorialTileId,
            processableColor: tile.id == tutorialTileId
                ? const Color(0xFFF0C64E)
                : processableColor,
          );
          final dealIndex =
              slots.take(slotIndex + 1).whereType<int>().length - 1;
          final baseTileWidget = dealAnimationSerial == null
              ? visibleTile
              : _DealtRackTile(
                  key: ValueKey('rack-deal-$dealAnimationSerial-${tile.id}'),
                  dealIndex: dealIndex,
                  width: tw,
                  height: th,
                  front: visibleTile,
                  progress: dealProgress,
                );
          final tileWidget = ValueListenableBuilder<_RackPushPreview?>(
            valueListenable: pushPreview,
            child: baseTileWidget,
            builder: (context, preview, child) {
              var turns = 0.0;
              if (preview != null &&
                  preview.kind == _RackMoveKind.insert &&
                  tile.id != preview.tileId &&
                  preview.targetSlot ~/ _GameScreenState._rackRowLength ==
                      slotIndex ~/ _GameScreenState._rackRowLength) {
                // Open only the two faces bordering the actual insertion seam.
                // Drop targets remain still, so the preview cannot move the seam.
                if (slotIndex == preview.targetSlot - 1) turns = -0.004;
                if (slotIndex == preview.targetSlot) turns = 0.004;
              }
              return AnimatedRotation(
                key: ValueKey('rack-insertion-tilt-$slotIndex'),
                turns: turns,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOutQuad,
                child: child,
              );
            },
          );
          return _RackSlotDropTarget(
            slotIndex: slotIndex,
            rowEnd: offset + _GameScreenState._rackRowLength,
            occupiedTileId: tile.id,
            tileWidth: tw,
            tileHeight: th,
            canAcceptDeckDrop: canAcceptDeckDrop,
            canAcceptDiscardDrop: canAcceptDiscardDrop,
            onDeckDropAt: onDeckDropAt,
            onDiscardDropAt: onDiscardDropAt,
            onReorder: onReorder,
            pushPreview: pushPreview,
            rackSlots: slots,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.6),
              child: _RackTileDraggable(
                highlighted:
                    processableTileIds.contains(tile.id) ||
                    tile.id == tutorialTileId,
                highlightColor: tile.id == tutorialTileId
                    ? const Color(0xFFF0C64E)
                    : processableColor,
                draggableKey: ValueKey('rack-tile-${tile.id}'),
                tile: tile,
                data: dragData,
                width: tw,
                height: th,
                onDragStart: onTileDragStart,
                onDragUpdate: onTileDragUpdate,
                onDragEnd: onTileDragEnd,
                dragVisual: dragVisual,
                liftForMeld: processableTileIds.contains(tile.id),
                child: shiftOrigins.containsKey(tile.id)
                    ? TweenAnimationBuilder<double>(
                        key: ValueKey('rack-shift-$shiftSerial-${tile.id}'),
                        tween: Tween(
                          begin: shiftOrigins[tile.id]! * (tw + 1.2),
                          end: 0,
                        ),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeInOutSine,
                        child: tileWidget,
                        builder: (context, dx, child) => Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        ),
                      )
                    : tileWidget,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RackAction {
  final Key? buttonKey;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final bool isUndo;
  final String? secondaryLabel;
  final bool secondaryActive;
  final Color? secondaryColor;
  final VoidCallback? secondaryOnTap;

  const _RackAction({
    this.buttonKey,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    this.isUndo = false,
    this.secondaryLabel,
    this.secondaryActive = false,
    this.secondaryColor,
    this.secondaryOnTap,
  });
}

class _RackActionPanel extends StatelessWidget {
  final List<_RackAction> actions;

  const _RackActionPanel({required this.actions});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF111815),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF8A6027), width: 1.5),
    ),
    child: Column(
      children: [
        ...actions.asMap().entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _SceneActionButton(action: entry.value),
            ),
          );
        }),
      ],
    ),
  );
}

class _ProgressiveOpeningBadge extends StatelessWidget {
  final int standardScore;
  final int pairCount;

  const _ProgressiveOpeningBadge({
    required this.standardScore,
    required this.pairCount,
  });

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('progressive-opening-target'),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: _number('$standardScore', 28)),
        Expanded(flex: 2, child: _number('$pairCount', 34)),
      ],
    ),
  );

  Widget _number(String value, double fontSize) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      value,
      style: TextStyle(
        color: Color(0xFFFFEFBD),
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

class _RackPerSummary extends StatelessWidget {
  final int points;
  final bool showRemaining;
  final int? pairCount;

  const _RackPerSummary({
    required this.points,
    required this.showRemaining,
    required this.pairCount,
  });

  @override
  Widget build(BuildContext context) {
    final label = showRemaining
        ? appText('KALAN', 'REMAINING', german: 'REST')
        : pairCount != null
        ? appText('ÇİFT', 'PAIRS', german: 'PAARE')
        : appText('SERİ', 'MELD', german: 'SATZ');
    final value = pairCount ?? points;
    final highlighted =
        (pairCount != null && pairCount! >= 5) ||
        (!showRemaining && pairCount == null && points >= 101);

    return _SceneReferenceFrame(
      region: const Rect.fromLTWH(769, 440, 96, 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,

                style: const TextStyle(
                  color: Color(0xFFFFFFCF),
                  fontFamily: 'Scene Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',

                style: TextStyle(
                  color: highlighted ? OC.numGreen : Colors.white,
                  fontFamily: 'Scene Sans',
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneActionButton extends StatelessWidget {
  final _RackAction action;

  const _SceneActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    if (action.secondaryLabel == null) {
      return SizedBox.expand(child: _SceneActionButtonFace(action: action));
    }
    return SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _SceneActionButtonFace(action: action)),
          const SizedBox(width: 4),
          Expanded(
            child: _SceneActionButtonFace(
              action: _RackAction(
                label: action.secondaryLabel!,
                active: action.secondaryActive,
                color: action.secondaryColor ?? const Color(0xFF9A650E),
                onTap: action.secondaryOnTap ?? action.onTap,
                isUndo: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneActionButtonFace extends StatelessWidget {
  final _RackAction action;

  const _SceneActionButtonFace({required this.action});

  String get _backgroundAsset {
    if (action.color == const Color(0xFF19862B)) {
      return 'images/ui/action_green.png';
    }
    if (action.color == const Color(0xFF08658F)) {
      return 'images/ui/action_blue.png';
    }
    return 'images/ui/action_gold.png';
  }

  @override
  Widget build(BuildContext context) => _PressScale(
    enabled: action.active,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: action.active ? 1 : 0.42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: action.buttonKey,
          onTap: action.active ? action.onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_backgroundAsset),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: FittedBox(
                  key: ValueKey('${action.label}-${action.isUndo}'),
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        action.isUndo
                            ? action.label.replaceFirst(' ', '\n')
                            : action.label,
                        maxLines: action.isUndo ? 2 : 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Scene Button',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.25,
                          height: action.isUndo ? 0.9 : 1,
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
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TAŞ WİDGET
// ═══════════════════════════════════════════════════════════════════════════
class _TileWidget extends StatelessWidget {
  final bool motionCopy;
  final Tile tile;
  final double w, h;
  final VoidCallback? onTap;
  final bool hideOkey;
  final bool allowOkeyFaceToggle;
  final bool emphasized;
  final bool processable;
  final Color processableColor;
  final double numberScale;
  final bool showShadow;
  final double borderRadius;
  const _TileWidget({
    this.motionCopy = false,
    super.key,
    required this.tile,
    required this.w,
    required this.h,
    required this.onTap,
    this.hideOkey = false,
    this.allowOkeyFaceToggle = true,
    this.emphasized = false,
    this.processable = false,
    this.processableColor = OC.numGreen,
    this.numberScale = 1,
    this.showShadow = true,
    this.borderRadius = 5,
  });

  String get _label {
    if (tile.isFakeOkey) return '★';
    if (tile.isOkey) return '${tile.number}';
    return '${tile.number}';
  }

  Widget _buildTile(VoidCallback? onToggleOkey) {
    final isSelected = tile.selected;
    final fakeOkeyAsset = tile.isFakeOkey ? storeCosmetics.fakeOkeyAsset : null;
    final content = hideOkey && tile.isOkey && !tile.okeyFaceRevealed
        ? null
        : Transform.translate(
            offset: Offset(0, -h * 0.15),
            child: Stack(
              children: [
                Center(
                  child: fakeOkeyAsset != null
                      ? Image.asset(
                          fakeOkeyAsset,
                          width: w * 0.54,
                          height: h * 0.42,
                          cacheWidth: 64,
                          cacheHeight: 64,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                        )
                      : SizedBox(
                          width: w * 0.82,
                          height: h * 0.55,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              _label,
                              maxLines: 1,
                              softWrap: false,

                              style: TextStyle(
                                color: tile.displayColor,
                                fontSize:
                                    h *
                                    (tile.isFakeOkey ? 0.50 : 0.47) *
                                    (emphasized ? 1.13 : 1) *
                                    numberScale,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.25,
                              ),
                            ),
                          ),
                        ),
                ),
                if (fakeOkeyAsset == null)
                  Positioned(
                    bottom: 3,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: w * 0.21,
                        height: w * 0.21,
                        decoration: BoxDecoration(
                          color: tile.displayColor.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
    final decoration = BoxDecoration(
      image: DecorationImage(
        image: AssetImage(storeCosmetics.tileAsset),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
    final tileFace = Stack(
      fit: StackFit.expand,
      children: [
        ?content,
        if (processable)
          IgnorePointer(
            child: DecoratedBox(
              key: ValueKey('processable-highlight-${tile.id}'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: processableColor, width: 2),
              ),
            ),
          ),
      ],
    );
    final visual = onTap == null
        ? Container(
            width: w,
            height: h,
            transform: Matrix4.translationValues(0, isSelected ? -11 : 0, 0),
            decoration: decoration,
            child: tileFace,
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: w,
            height: h,
            transform: Matrix4.translationValues(0, isSelected ? -11 : 0, 0),
            decoration: decoration,
            child: tileFace,
          );
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onToggleOkey,
      child: visual,
    );
  }

  Widget _buildOkeyAnimation(Widget tileWidget) =>
      TweenAnimationBuilder<double>(
        key: ValueKey(tile.okeyFaceRevealed),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: tileWidget,
        builder: (context, value, child) {
          final bounce = sin(value * pi);
          return Transform.translate(
            offset: Offset(0, -h * 0.22 * bounce),
            child: Transform.scale(scale: 1 + bounce * 0.08, child: child),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    if (!hideOkey || !allowOkeyFaceToggle || !tile.isOkey) {
      return _withMotionVisibility(context, _buildTile(null));
    }
    return _withMotionVisibility(
      context,
      StatefulBuilder(
        builder: (context, setOkeyState) {
          final tileWidget = _buildTile(
            () => setOkeyState(() {
              tile.okeyFaceRevealed = !tile.okeyFaceRevealed;
            }),
          );
          return _buildOkeyAnimation(tileWidget);
        },
      ),
    );
  }

  Widget _withMotionVisibility(BuildContext context, Widget child) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TileMotionScope>();
    if (scope == null) return child;
    Widget withDrawAttention(Widget face) =>
        scope.drawAttentionTileId == tile.id
        ? _DrawnTileAttention(
            key: ValueKey('draw-attention-${scope.drawAttentionSerial}'),
            child: face,
          )
        : face;
    if (motionCopy) return withDrawAttention(child);
    child = _ProcessedTileAccent(
      tile: tile,
      highlight: scope.processedHighlight,
      child: child,
    );
    return ValueListenableBuilder<Set<int>>(
      valueListenable: scope.finishHiddenTileIds,
      child: child,
      builder: (context, finishingIds, child) =>
          ValueListenableBuilder<_TableTileMotion?>(
            valueListenable: scope.motion,
            child: child,
            builder: (context, motion, child) {
              final hidden =
                  finishingIds.contains(tile.id) ||
                  (motion != null &&
                      (motion.sourceRects.containsKey(tile.id) ||
                          (motion.playerIndex > 0 &&
                              (motion.kind == _TableTileMotionKind.open ||
                                  motion.kind ==
                                      _TableTileMotionKind.process) &&
                              motion.tiles.any(
                                (moving) => moving.id == tile.id,
                              ))));
              return IgnorePointer(
                ignoring: hidden,
                child: Opacity(
                  opacity: hidden ? 0 : 1,
                  child: hidden ? child : withDrawAttention(child!),
                ),
              );
            },
          ),
    );
  }
}

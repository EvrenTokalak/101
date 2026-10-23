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
    const tileWidth = 30.0;
    const tileHeight = tileWidth * 1.58;
    final content = _TileWidget(
      tile: tile,
      w: tileWidth,
      h: tileHeight,
      onTap: null,
    );
    if (!enabled) return content;
    return Draggable<_DiscardDragData>(
      data: const _DiscardDragData(),
      dragAnchorStrategy: (_, _, _) =>
          const Offset(tileWidth / 2, tileHeight + 16),
      feedbackOffset: const Offset(0, -12),
      feedback: Material(color: Colors.transparent, child: content),
      childWhenDragging: const SizedBox(width: tileWidth, height: tileHeight),
      child: GestureDetector(onTap: onTake, child: content),
    );
  }
}

class _DeckDrawHandle extends StatelessWidget {
  final Widget? child;
  final bool enabled;
  final int count;
  final VoidCallback onDraw;
  final double feedbackWidth;
  final double feedbackHeight;
  final double displayWidth;
  final double displayHeight;

  const _DeckDrawHandle({
    this.child,
    required this.enabled,
    required this.count,
    required this.onDraw,
    required this.feedbackWidth,
    required this.feedbackHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  Widget build(BuildContext context) {
    final stack =
        child ??
        _DeckStack(
          count: count,
          tileWidth: displayWidth,
          tileHeight: displayHeight,
        );
    if (!enabled) return Opacity(opacity: 0.72, child: stack);
    return Draggable<_DeckDragData>(
      data: const _DeckDragData(),
      dragAnchorStrategy: (_, _, _) =>
          Offset(feedbackWidth / 2, feedbackHeight + 16),
      feedbackOffset: const Offset(0, -12),
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
        child:
            child ??
            _DeckStack(
              count: max(0, count - 1),
              tileWidth: displayWidth,
              tileHeight: displayHeight,
            ),
      ),
      child: _PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDraw,
          child: stack,
        ),
      ),
    );
  }
}

class _TileBack extends StatelessWidget {
  final double width;
  final double height;
  final bool showBorder;

  const _TileBack({
    super.key,
    this.width = 40,
    this.height = 52,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      image: const DecorationImage(
        image: ResizeImage(AssetImage('images/tas_ters.png'), width: 128),
        fit: BoxFit.fill,
      ),
      borderRadius: BorderRadius.circular(6),
      border: showBorder ? Border.all(color: OC.gold, width: 2) : null,
    ),
  );
}

class _TableDiscardPile extends StatelessWidget {
  final Key? targetKey;
  final List<Tile> tiles;
  final String label;
  final String? keyLabel;
  final bool active;
  final bool showTurnHighlight;
  final ValueChanged<_RackDragData>? onDrop;
  final bool takeEnabled;
  final VoidCallback? onTake;
  final bool showReturnButton;
  final int? returnTileId;
  final VoidCallback? onReturn;
  final double hitWidth;
  final double? hitHeight;
  final Alignment visualAlignment;

  const _TableDiscardPile({
    this.targetKey,
    required this.tiles,
    required this.label,
    this.keyLabel,
    this.active = false,
    this.showTurnHighlight = false,
    this.onDrop,
    this.takeEnabled = false,
    this.onTake,
    this.showReturnButton = false,
    this.returnTileId,
    this.onReturn,
    this.hitWidth = 102,
    this.hitHeight,
    this.visualAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('discard-target-${keyLabel ?? label}'),
    width: hitWidth,
    height: hitHeight ?? 66,
    child: DragTarget<_RackDragData>(
      key: targetKey,
      onWillAcceptWithDetails: (details) {
        final returningTakenTile =
            returnTileId != null &&
            details.data.tileIds.length == 1 &&
            details.data.tileIds.contains(returnTileId);
        return returningTakenTile || (active && onDrop != null);
      },
      onAcceptWithDetails: (details) {
        final returningTakenTile =
            returnTileId != null &&
            details.data.tileIds.length == 1 &&
            details.data.tileIds.contains(returnTileId);
        if (returningTakenTile) {
          onReturn?.call();
        } else {
          onDrop?.call(details.data);
        }
      },
      builder: (context, candidates, rejected) {
        final highlighted = showTurnHighlight || candidates.isNotEmpty;
        return Align(
          alignment: visualAlignment,
          child: SizedBox(
            key: ValueKey('discard-${keyLabel ?? label}'),
            width: 38,
            height: 60,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 38,
                height: 60,
                child: AnimatedContainer(
                  key: ValueKey('discard-turn-highlight-${keyLabel ?? label}'),
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: highlighted
                        ? const [
                            BoxShadow(color: Color(0xAAFFD23F), blurRadius: 8),
                          ]
                        : null,
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: highlighted
                          ? const Color(0xFFFFD54F)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _SceneReferenceFrame(
                    region: const Rect.fromLTWH(46, 132, 88, 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: showReturnButton && onReturn != null
                              ? Material(
                                  key: const ValueKey('return-taken-discard'),
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onReturn,
                                    borderRadius: BorderRadius.circular(7),
                                    child: Ink(
                                      width: 30,
                                      height: 47.4,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFFBE8325),
                                            Color(0xFF714308),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: const Color(0xFFFFD47A),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.undo_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(height: 1),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'GERİ\nBIRAK',
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                height: 1,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : tiles.isEmpty
                              ? const SizedBox(
                                  key: ValueKey('empty-discard'),
                                  width: 30,
                                  height: 47.4,
                                  child: Icon(
                                    Icons.arrow_downward_rounded,
                                    color: Colors.white24,
                                  ),
                                )
                              : takeEnabled && onTake != null
                              ? _DiscardDrawHandle(
                                  key: ValueKey(
                                    'take-discard-${tiles.last.id}',
                                  ),
                                  tile: tiles.last,
                                  enabled: true,
                                  onTake: onTake!,
                                )
                              : _TileWidget(
                                  key: ValueKey(tiles.last.id),
                                  tile: tiles.last,
                                  w: 30,
                                  h: 47.4,
                                  onTap: null,
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
  );
}

class _PlayerTurnBadge extends StatelessWidget {
  const _PlayerTurnBadge();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1500),
    child: Container(
      key: const ValueKey('player-turn-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xE60A3025),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: OC.goldLight.withValues(alpha: .8),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: OC.goldLight, size: 23),
          const SizedBox(width: 7),
          Text(
            appText('SIRA SENDE', 'YOUR TURN', german: 'DU BIST DRAN'),
            style: const TextStyle(
              color: OC.cream,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
    builder: (context, progress, child) => Opacity(
      opacity: (min(1.0, progress * 7) * min(1.0, (1 - progress) * 4)).clamp(
        0.0,
        1.0,
      ),
      child: Transform.translate(
        offset: Offset(0, 6 * (1 - min(1.0, progress * 7))),
        child: child,
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  final VoidCallback onPressed;
  final bool help;
  const _TopBar({required this.onPressed, this.help = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _PressScale(
        child: IconButton(
          key: ValueKey(help ? 'game-help-button' : 'game-settings-button'),
          tooltip: help
              ? appText(
                  'Nasıl oynanır?',
                  'How to play?',
                  german: 'Wie spielt man?',
                )
              : appText(
                  'Oyun ayarları',
                  'Game settings',
                  german: 'Spieleinstellungen',
                ),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            minimumSize: Size.square(help ? 40 : 56),
            maximumSize: Size.square(help ? 40 : 56),
            padding: EdgeInsets.zero,
          ),
          icon: Image.asset(
            help ? 'images/ui/home/help.png' : 'images/ui/home/settings.png',
            width: 38,
            height: 38,
            cacheWidth: 76,
            cacheHeight: 76,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// OYUNCU BİLGİSİ (avatar + isim + taş sayısı)
// ═══════════════════════════════════════════════════════════════════════════
class _PlayerInfo extends StatelessWidget {
  final BotPlayer bot;
  final int fakeOkeyValue;
  final bool active;
  final bool horizontal;
  final bool showAvatar;

  const _PlayerInfo({
    required this.bot,
    required this.fakeOkeyValue,
    required this.active,
    this.horizontal = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = bot.hasOpened ? const Color(0xFF83E5A0) : OC.numRed;
    final remainingPoints = bot.hasOpened
        ? Rules.penaltyFor(bot.hand, fakeOkeyValue: fakeOkeyValue)
        : null;
    final displayName = bot.displayName;
    final details = Container(
      width: horizontal ? 90 : 54,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16432F), Color(0xFF061C11)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OC.okeyGold,
          // Border width also participates in layout; keep it fixed on turn changes.
          width: 1.4,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayName,
          key: ValueKey('bot-name-${bot.name}'),
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OC.cream,
            fontFamily: 'Scene Sans',
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    final avatarSize = horizontal ? 41.0 : 43.0;
    // Paint-scale around the existing center; names, layout and hit areas stay put.
    final avatar = AnimatedScale(
      key: ValueKey('profile-turn-scale-${bot.name}'),
      scale: active ? 1 : .86,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              key: ValueKey('bot-avatar-${bot.name}'),
              width: avatarSize,
              height: avatarSize,
              child: ClipOval(
                child: Image.asset(
                  bot.avatarAsset,
                  fit: BoxFit.cover,
                  cacheWidth: 64,
                  cacheHeight: 64,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              top: -3,
              bottom: -3,
              left: -3,
              right: -3,
              child: IgnorePointer(
                child: Container(
                  key: ValueKey('bot-avatar-frame-${bot.name}'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 3),
                  ),
                ),
              ),
            ),
            if (remainingPoints != null)
              Positioned(
                top: -4,
                right: -6,
                child: Tooltip(
                  message: 'Açtı · $remainingPoints kalan puan',
                  child: Container(
                    key: ValueKey('bot-remaining-badge-${bot.name}'),
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF092018),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor, width: 1.5),
                    ),
                    child: Text(
                      '$remainingPoints',
                      key: ValueKey('bot-remaining-${bot.name}'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Container(
      key: ValueKey('seat-${bot.name}'),
      padding: const EdgeInsets.all(2),
      child: horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAvatar) ...[avatar, const SizedBox(width: 4)],
                details,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAvatar) ...[avatar, const SizedBox(height: 3)],
                details,
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MASA ALANI
// ═══════════════════════════════════════════════════════════════════════════
class _TableArea extends StatelessWidget {
  final List<Meld> melds;
  final List<BotPlayer> bots;
  final String playerName;
  final int activeTurn;
  final List<List<Tile>> discardPiles;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;
  final bool myTurn;
  final bool drawnThisTurn;
  final ValueChanged<_RackDragData> onPlayerDiscardDrop;
  final GlobalKey playerDiscardTargetKey;
  final bool canTakeDiscard;
  final VoidCallback onTakeDiscard;
  final bool canReturnDiscard;
  final int? returnDiscardTileId;
  final VoidCallback onReturnDiscard;
  final double gridTileWidth;
  final GlobalKey gridKey;
  final ValueNotifier<_RackDragVisualState> dragVisual;
  final _BotDiscardMotion? botDiscardMotion;
  final ValueNotifier<_TableTileMotion?> tableTileMotion;
  final double bottomReservedSpace;
  final String gameModeLabel;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;
  final bool showGrid;
  final bool showBots;

  const _TableArea({
    required this.melds,
    required this.bots,
    required this.playerName,
    required this.activeTurn,
    required this.discardPiles,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
    required this.myTurn,
    required this.drawnThisTurn,
    required this.onPlayerDiscardDrop,
    required this.playerDiscardTargetKey,
    required this.canTakeDiscard,
    required this.onTakeDiscard,
    required this.canReturnDiscard,
    required this.returnDiscardTileId,
    required this.onReturnDiscard,
    required this.gridTileWidth,
    required this.gridKey,
    required this.dragVisual,
    required this.botDiscardMotion,
    required this.tableTileMotion,
    required this.bottomReservedSpace,
    required this.gameModeLabel,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
    required this.showGrid,
    required this.showBots,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, tableBox) {
        final playerTwoBottom =
            (tableBox.maxHeight + 112 - bottomReservedSpace) / 2 + 32;
        final discardZoneTop = min(
          tableBox.maxHeight - 72,
          max(96.0, playerTwoBottom),
        );
        final sideDiscardHitWidth = 38 + gridTileWidth * 2;
        const sideDiscardInset = 8.0;
        const upperDiscardTop = 46.0;
        final lowerLeftDiscardBottom = max(2.0, bottomReservedSpace - 104);
        const discardHitHeight = 66.0;
        final minimumProfileTop = upperDiscardTop + discardHitHeight + 8;
        final leftLowerDiscardTop =
            tableBox.maxHeight - lowerLeftDiscardBottom - discardHitHeight;
        final sideProfileHeight = tableBox.maxHeight < 430 ? 86.0 : 110.0;
        double profileTopBefore(double lowerDiscardTop) {
          final maximumProfileTop = max(
            minimumProfileTop,
            lowerDiscardTop - sideProfileHeight - 8,
          );
          return ((minimumProfileTop + maximumProfileTop) / 2).clamp(
            minimumProfileTop,
            maximumProfileTop,
          );
        }

        final leftProfileTop = profileTopBefore(leftLowerDiscardTop);
        final rightProfileTop = profileTopBefore(discardZoneTop);
        return Row(
          children: [
            // Seçilen görsel doğrudan masa yüzeyidir. Ek renk katmanı çizmek
            // hem temayı kapatır hem de gereksiz GPU overdraw oluşturur.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(58, 20, 58, 8),
                        child: SizedBox.expand(
                          key: gridKey,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              if (showGrid)
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: _MeldGridBoard(
                                      tileWidth: gridTileWidth,
                                      melds: melds,
                                      uiMode: uiMode,
                                      eligibleMeldIndexes: eligibleMeldIndexes,
                                      onMeldTap: onMeldTap,
                                      onMeldDrop: onMeldDrop,
                                      canAcceptMeldDrop: canAcceptMeldDrop,
                                      onPairDrop: onPairDrop,
                                      canAcceptPairDrop: canAcceptPairDrop,
                                      deckCount: deckCount,
                                      indicator: indicator,
                                      perPoints: perPoints,
                                      showRemainingPoints: showRemainingPoints,
                                      pairCount: pairCount,
                                      minimumStandardOpeningScore:
                                          minimumStandardOpeningScore,
                                      minimumPairOpeningCount:
                                          minimumPairOpeningCount,
                                      canDraw: canDraw,
                                      onDraw: onDraw,
                                      canFinishByCenterDrop:
                                          canFinishByCenterDrop,
                                      onFinishByCenterDrop:
                                          onFinishByCenterDrop,
                                      dragTileWidth: dragTileWidth,
                                      dragTileHeight: dragTileHeight,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child:
                                    ValueListenableBuilder<
                                      _RackDragVisualState
                                    >(
                                      valueListenable: dragVisual,
                                      builder: (context, visual, _) {
                                        return _GridDragMagnifier(
                                          position: visual.gridPosition,
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: leftProfileTop,
                        child: SizedBox(
                          width: 58,
                          height: sideProfileHeight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: showBots
                                ? Alignment.topCenter
                                : Alignment.center,
                            child: _PlayerInfo(
                              showAvatar: showBots,
                              bot: bots[2],
                              fakeOkeyValue: Rules.okeyNumberForIndicator(
                                indicator?.number ?? 1,
                              ),
                              active: activeTurn == 3,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: rightProfileTop,
                        child: SizedBox(
                          width: 58,
                          height: sideProfileHeight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: showBots
                                ? Alignment.topCenter
                                : Alignment.center,
                            child: _PlayerInfo(
                              showAvatar: showBots,
                              bot: bots[0],
                              fakeOkeyValue: Rules.okeyNumberForIndicator(
                                indicator?.number ?? 1,
                              ),
                              active: activeTurn == 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: upperDiscardTop,
                        right: sideDiscardInset,
                        child: _TableDiscardPile(
                          tiles: discardPiles[1],
                          label: bots[0].displayName,
                          keyLabel: bots[0].name,
                          hitWidth: sideDiscardHitWidth,
                          visualAlignment: Alignment.topRight,
                        ),
                      ),
                      Positioned(
                        top: discardZoneTop,
                        bottom: 0,
                        right: sideDiscardInset,
                        width: sideDiscardHitWidth,
                        child: _TableDiscardPile(
                          targetKey: playerDiscardTargetKey,
                          tiles: discardPiles[0],
                          label: playerName,
                          keyLabel: 'Oyuncu 1',
                          active: myTurn && drawnThisTurn,
                          showTurnHighlight: myTurn,
                          onDrop: onPlayerDiscardDrop,
                          hitWidth: sideDiscardHitWidth,
                          hitHeight: tableBox.maxHeight - discardZoneTop,
                          visualAlignment: Alignment.bottomRight,
                        ),
                      ),
                      Positioned(
                        top: upperDiscardTop,
                        left: 8,
                        child: _TableDiscardPile(
                          tiles: discardPiles[2],
                          label: bots[1].displayName,
                          keyLabel: bots[1].name,
                          hitWidth: 38 + gridTileWidth * 2,
                          visualAlignment: Alignment.topLeft,
                        ),
                      ),
                      Positioned(
                        bottom: lowerLeftDiscardBottom,
                        left: 8,
                        child: _TableDiscardPile(
                          tiles: discardPiles[3],
                          label: bots[2].displayName,
                          keyLabel: bots[2].name,
                          takeEnabled: canTakeDiscard,
                          onTake: onTakeDiscard,
                          showReturnButton: canReturnDiscard,
                          returnTileId: returnDiscardTileId,
                          onReturn: onReturnDiscard,
                          hitWidth: 38 + gridTileWidth * 2,
                          visualAlignment: Alignment.bottomLeft,
                        ),
                      ),
                      if (botDiscardMotion != null)
                        Positioned.fill(
                          child: _FlyingBotDiscard(
                            motion: botDiscardMotion!,
                            bottomReservedSpace: bottomReservedSpace,
                          ),
                        ),
                      Positioned.fill(
                        child: ValueListenableBuilder<_TableTileMotion?>(
                          valueListenable: tableTileMotion,
                          builder: (context, motion, _) =>
                              motion == null || motion.playerIndex == 0
                              ? const SizedBox.shrink()
                              : RepaintBoundary(
                                  child: _FlyingTableTiles(motion: motion),
                                ),
                        ),
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
}

class _GridTopCaption extends StatelessWidget {
  final String text;
  final Alignment alignment;

  const _GridTopCaption({
    super.key,
    required this.text,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final Rect? artwork = appLanguage.value != AppLanguage.turkish
        ? null
        : text == 'EL AÇMA: 101 PER • 5 ÇİFT'
        ? const Rect.fromLTWH(163, 14, 482, 58)
        : text == 'SIRADAN'
        ? const Rect.fromLTWH(1495, 14, 209, 58)
        : null;
    return Align(
      alignment: alignment,
      child: artwork != null
          ? Semantics(
              label: text,
              child: SizedBox(
                height: 24,
                child: AspectRatio(
                  aspectRatio: artwork.width / artwork.height,
                  child: _SceneReferenceCrop(region: artwork),
                ),
              ),
            )
          : text.isEmpty
          ? const SizedBox.shrink()
          : Container(
              constraints: const BoxConstraints(maxHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF163828), Color(0xFF07170E)],
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFF0D563), width: 1.2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFFFF0BD),
                    fontFamily: 'Scene Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
    );
  }
}

class _TimedRackCountdown extends StatefulWidget {
  final ValueListenable<int> seconds;
  final bool active;

  const _TimedRackCountdown({
    super.key,
    required this.seconds,
    required this.active,
  });

  @override
  State<_TimedRackCountdown> createState() => _TimedRackCountdownState();
}

class _TimedRackCountdownState extends State<_TimedRackCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _lastSeconds;

  @override
  void initState() {
    super.initState();
    _lastSeconds = widget.seconds.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
      value: widget.active && widget.seconds.value <= 0
          ? 1
          : (widget.seconds.value / 7).clamp(0.0, 1.0),
    );
    if (widget.active && widget.seconds.value > 0) {
      _controller.reverse(from: _controller.value);
    }
    widget.seconds.addListener(_handleSecondsChanged);
  }

  void _handleSecondsChanged() {
    final currentSeconds = widget.seconds.value;
    if (widget.active && currentSeconds > _lastSeconds) {
      _controller.duration = const Duration(seconds: 7);
      _controller.reverse(from: (currentSeconds / 7).clamp(0.0, 1.0));
    }
    _lastSeconds = currentSeconds;
  }

  @override
  void didUpdateWidget(covariant _TimedRackCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      oldWidget.seconds.removeListener(_handleSecondsChanged);
      _lastSeconds = widget.seconds.value;
      widget.seconds.addListener(_handleSecondsChanged);
    }
    if (!widget.active) {
      _controller.stop();
      return;
    }
    if (!oldWidget.active && widget.seconds.value > 0) {
      _controller.duration = const Duration(seconds: 7);
      _controller.reverse(from: (widget.seconds.value / 7).clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    widget.seconds.removeListener(_handleSecondsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: const Color(0xE6000000),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          key: const ValueKey('timed-turn-countdown'),
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => SizedBox(
                  key: const ValueKey('timed-turn-countdown-fill'),
                  width: constraints.maxWidth * _controller.value,
                  height: constraints.maxHeight,
                  child: const ColoredBox(color: Color(0xFFFFD33D)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CenteredGridViewer extends StatefulWidget {
  final Widget child;
  final bool alignRight;

  const _CenteredGridViewer({
    super.key,
    required this.child,
    required this.alignRight,
  });

  @override
  State<_CenteredGridViewer> createState() => _CenteredGridViewerState();
}

class _CenteredGridViewerState extends State<_CenteredGridViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformation = TransformationController();
  late final AnimationController _centeringController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      )..addListener(() {
        final animation = _centeringAnimation;
        if (animation != null) _transformation.value = animation.value;
      });
  Animation<Matrix4>? _centeringAnimation;
  bool _lockingBasePan = false;
  bool _showResetButton = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_handleTransformChanged);
  }

  void _handleTransformChanged() {
    _lockPanAtBaseScale();
    final matrix = _transformation.value;
    final translation = matrix.getTranslation();
    final shouldShow =
        matrix.getMaxScaleOnAxis() > 1.002 ||
        translation.x.abs() > 0.5 ||
        translation.y.abs() > 0.5;
    if (shouldShow != _showResetButton && mounted) {
      setState(() => _showResetButton = shouldShow);
    }
  }

  void _lockPanAtBaseScale() {
    if (_lockingBasePan) return;
    final matrix = _transformation.value;
    if (matrix.getMaxScaleOnAxis() > 1.001) return;
    final translation = matrix.getTranslation();
    if (translation.x.abs() < 0.01 && translation.y.abs() < 0.01) return;
    _lockingBasePan = true;
    _transformation.value = Matrix4.identity();
    _lockingBasePan = false;
  }

  @override
  void dispose() {
    _transformation.removeListener(_handleTransformChanged);
    _centeringController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails _) {
    _centeringController.stop();
  }

  void _resetView() {
    _centeringAnimation =
        Matrix4Tween(
          begin: _transformation.value.clone(),
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: _centeringController,
            curve: Curves.easeOutCubic,
          ),
        );
    _centeringController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      return Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: 1,
              maxScale: 3.4,
              panEnabled: true,
              scaleEnabled: true,
              panAxis: PanAxis.free,
              boundaryMargin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              onInteractionStart: _onInteractionStart,
              child: widget.child,
            ),
          ),
          if (_showResetButton)
            Positioned(
              left: widget.alignRight ? null : 5,
              right: widget.alignRight ? 5 : null,
              bottom: 5,
              child: _GridResetButton(onPressed: _resetView),
            ),
        ],
      );
    },
  );
}

class _GridResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GridResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => _PressScale(
    child: Material(
      color: const Color(0xE615211E),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        key: const ValueKey('grid-reset-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: OC.gold.withValues(alpha: 0.8)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fit_screen_rounded, size: 13, color: OC.okeyGold),
              SizedBox(width: 4),
              Text(
                'TAM GÖRÜNÜM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GridDragMagnifier extends StatelessWidget {
  final Offset? position;

  const _GridDragMagnifier({required this.position});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) {
        final activePosition = position;
        final lensWidth = min(
          box.maxWidth,
          min(180.0, max(112.0, box.maxWidth * 0.24)),
        );
        final lensHeight = min(
          box.maxHeight,
          min(112.0, max(74.0, box.maxHeight * 0.31)),
        );
        final left = ((activePosition?.dx ?? 0) - lensWidth / 2)
            .clamp(0.0, max(0.0, box.maxWidth - lensWidth))
            .toDouble();
        final top = ((activePosition?.dy ?? 0) - lensHeight / 2)
            .clamp(0.0, max(0.0, box.maxHeight - lensHeight))
            .toDouble();
        final lensCenter = Offset(left + lensWidth / 2, top + lensHeight / 2);

        // RawMagnifier'ı sürükleme aralarında ağaçtan çıkarmıyoruz. Böylece
        // engine her taş kaldırılışında yeni bir offscreen yüzey ayırmak yerine
        // aynı küçük yüzeyi yeniden kullanıyor.
        return Offstage(
          offstage: activePosition == null,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                key: const ValueKey('grid-drag-magnifier'),
                left: left,
                top: top,
                child: RawMagnifier(
                  size: Size(lensWidth, lensHeight),
                  magnificationScale: 1.45,
                  focalPointOffset:
                      (activePosition ?? Offset.zero) - lensCenter,
                  clipBehavior: Clip.hardEdge,
                  decoration: MagnifierDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: OC.numGreen.withValues(alpha: 0.88),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DeckStack extends StatelessWidget {
  final int count;
  final double tileWidth;
  final double tileHeight;

  const _DeckStack({
    required this.count,
    this.tileWidth = 48,
    this.tileHeight = 62,
  });
  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return SizedBox(
        key: const ValueKey('draw-deck-stack'),
        width: tileWidth,
        height: tileHeight,
      );
    }

    final layers = min((count - 1) ~/ 12 + 1, 4);
    final layerOffset = tileWidth * 0.046;
    return SizedBox(
      key: const ValueKey('draw-deck-stack'),
      width: tileWidth,
      height: tileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...List.generate(
            layers,
            (i) => Positioned(
              left: -(layers - 1 - i) * layerOffset,
              top: -(layers - 1 - i) * layerOffset,
              child: _TileBack(
                key: i == layers - 1 ? const ValueKey('draw-deck-tile') : null,
                width: tileWidth,
                height: tileHeight,
                showBorder: false,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: tileWidth,
            height: tileHeight,
            child: Center(
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: tileHeight * 0.26,
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

class _GridPainter extends CustomPainter {
  final double cellWidth;
  final double cellHeight;
  final int majorColumnInterval;

  const _GridPainter({
    required this.cellWidth,
    required this.cellHeight,
    this.majorColumnInterval = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x2E7CA0A0)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += cellWidth) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += cellHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    if (majorColumnInterval > 0) {
      final divider = Paint()
        ..color = const Color(0xB8C59B52)
        ..strokeWidth = 2.2;
      final step = cellWidth * majorColumnInterval;
      for (double x = step; x < size.width - 0.5; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), divider);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.majorColumnInterval != majorColumnInterval;
}

class _MeldGridBoard extends StatelessWidget {
  final double tileWidth;
  final List<Meld> melds;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;

  const _MeldGridBoard({
    required this.tileWidth,
    required this.melds,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const frameWidth = 2.0;
      const perRows = 8;
      const pairRows = 6;
      const runColumns = 13;
      const groupColumns = 13;
      const pairColumns = 8;
      final stacked = box.maxWidth / box.maxHeight < 1.4;
      final totalGridColumns =
          runColumns + groupColumns + (stacked ? 0 : pairColumns);
      final maximumCellHeight = max(
        2.0,
        (box.maxHeight - frameWidth * (stacked ? 4 : 2)) /
            (perRows * (stacked ? 2 : 1)),
      );
      final maximumCellWidth = max(
        2.0,
        (box.maxWidth - frameWidth * (stacked ? 4 : 6)) / totalGridColumns,
      );
      final fittedTileWidth = min(
        tileWidth,
        min(
          // Gridin yatay ölçüsü ve üç bölümün eski genişlik dengesi korunur.
          // Taşın kendi dikdörtgen oranı aşağıdaki _MeldRow içinde küçültülür.
          max(1.0, (maximumCellHeight - 1) / 1.28),
          max(1.0, maximumCellWidth - 1),
        ),
      );
      final cellWidth = fittedTileWidth + 1;
      // Extra tablet height must not stretch the meld cells vertically.
      final cellHeight = min(maximumCellHeight, cellWidth * 1.58);
      final runEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'seri')
          .toList();
      final groupEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'grup')
          .toList();
      final pairEntries = melds
          .asMap()
          .entries
          .where((entry) => entry.value.type == 'cift')
          .toList();
      final viewportWidth =
          totalGridColumns * cellWidth + frameWidth * (stacked ? 4 : 6);
      final viewportHeight = max(perRows * cellHeight + frameWidth * 2, 56.0);

      final panels = <Widget>[
        SizedBox(
          width: runColumns * cellWidth + frameWidth * 2,
          height: perRows * cellHeight + frameWidth * 2,
          child: _CenteredGridViewer(
            key: const ValueKey('run-grid-viewer'),
            alignRight: false,
            child: _RunMeldGrid(
              key: const ValueKey('run-meld-grid'),
              columns: runColumns,
              rows: perRows,
              cellWidth: cellWidth,
              cellHeight: cellHeight,
              frameWidth: frameWidth,
              entries: runEntries,
              uiMode: uiMode,
              eligibleMeldIndexes: eligibleMeldIndexes,
              onMeldTap: onMeldTap,
              onMeldDrop: onMeldDrop,
              canAcceptMeldDrop: canAcceptMeldDrop,
              meldGapColumns: 1,
            ),
          ),
        ),
        SizedBox(
          width: pairColumns * cellWidth + frameWidth * 2,
          height: viewportHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: cellHeight * 0.72,
                height: pairRows * cellHeight * 0.86 + frameWidth * 2,
                child: _CenteredGridViewer(
                  key: const ValueKey('pair-grid-viewer'),
                  alignRight: false,
                  child: _PairMeldGrid(
                    key: const ValueKey('pair-meld-grid'),
                    columns: pairColumns,
                    rows: pairRows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight * 0.86,
                    frameWidth: frameWidth,
                    entries: pairEntries,
                    uiMode: uiMode,
                    eligibleMeldIndexes: eligibleMeldIndexes,
                    onMeldTap: onMeldTap,
                    onMeldDrop: onMeldDrop,
                    canAcceptMeldDrop: canAcceptMeldDrop,
                    onPairDrop: onPairDrop,
                    canAcceptPairDrop: canAcceptPairDrop,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: cellHeight * (perRows - pairRows),
                child: _GridDrawColumn(
                  width: pairColumns * cellWidth + frameWidth * 2,
                  height: cellHeight * (perRows - pairRows),
                  deckCount: deckCount,
                  indicator: indicator,
                  perPoints: perPoints,
                  showRemainingPoints: showRemainingPoints,
                  pairCount: pairCount,
                  minimumStandardOpeningScore: minimumStandardOpeningScore,
                  minimumPairOpeningCount: minimumPairOpeningCount,
                  canDraw: canDraw,
                  onDraw: onDraw,
                  canFinishByCenterDrop: canFinishByCenterDrop,
                  onFinishByCenterDrop: onFinishByCenterDrop,
                  dragTileWidth: dragTileWidth,
                  dragTileHeight: dragTileHeight,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: groupColumns * cellWidth + frameWidth * 2,
          height: perRows * cellHeight + frameWidth * 2,
          child: _CenteredGridViewer(
            key: const ValueKey('group-grid-viewer'),
            alignRight: true,
            child: _RunMeldGrid(
              key: const ValueKey('group-meld-grid'),
              columns: groupColumns,
              rows: perRows,
              cellWidth: cellWidth,
              cellHeight: cellHeight,
              frameWidth: frameWidth,
              entries: groupEntries,
              uiMode: uiMode,
              eligibleMeldIndexes: eligibleMeldIndexes,
              onMeldTap: onMeldTap,
              onMeldDrop: onMeldDrop,
              canAcceptMeldDrop: canAcceptMeldDrop,
              meldGapColumns: 1,
            ),
          ),
        ),
      ];

      return Align(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            key: const ValueKey('meld-grid-viewport'),
            width: viewportWidth,
            height: viewportHeight * (stacked ? 2 : 1),
            child: stacked
                ? Column(
                    children: [
                      Row(children: [panels[0], panels[2]]),
                      panels[1],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: panels,
                  ),
          ),
        ),
      );
    },
  );
}

class _GridDrawColumn extends StatelessWidget {
  final double width;
  final double height;
  final int deckCount;
  final Tile? indicator;
  final int perPoints;
  final bool showRemainingPoints;
  final int? pairCount;
  final int? minimumStandardOpeningScore;
  final int? minimumPairOpeningCount;
  final bool canDraw;
  final VoidCallback onDraw;
  final bool canFinishByCenterDrop;
  final ValueChanged<_RackDragData> onFinishByCenterDrop;
  final double dragTileWidth;
  final double dragTileHeight;

  const _GridDrawColumn({
    required this.width,
    required this.height,
    required this.deckCount,
    required this.indicator,
    required this.perPoints,
    required this.showRemainingPoints,
    required this.pairCount,
    required this.minimumStandardOpeningScore,
    required this.minimumPairOpeningCount,
    required this.canDraw,
    required this.onDraw,
    required this.canFinishByCenterDrop,
    required this.onFinishByCenterDrop,
    required this.dragTileWidth,
    required this.dragTileHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Keep the rack tile's proportions when the draw area is smaller.
    final stackOverhang =
        min(max(0, (deckCount - 1) ~/ 12), 3) * dragTileWidth * 0.046;
    final summaryWidth = (width - 4) / 4;
    final openingWidth = minimumStandardOpeningScore != null
        ? summaryWidth
        : 0.0;
    final availableWidth = max(
      1.0,
      width - 4 - summaryWidth - openingWidth - 8,
    );
    final displayScale = min(
      1.0,
      min(
        max(1.0, height - 14) / dragTileHeight,
        availableWidth / (dragTileWidth * 2 + stackOverhang + 2),
      ),
    );
    final displayTileHeight = dragTileHeight * displayScale;
    final displayTileWidth = dragTileWidth * displayScale;
    final itemWidth = displayTileWidth;
    return Container(
      key: const ValueKey('table-draw-column'),
      width: width,
      height: height,
      decoration: const BoxDecoration(color: Color(0xD90B403B)),
      child: LayoutBuilder(
        builder: (context, area) => Stack(
          children: [
            if (minimumStandardOpeningScore != null &&
                minimumPairOpeningCount != null)
              Positioned(
                left: 2,
                bottom: 2,
                width: openingWidth,
                height: min(displayTileHeight * 1.22, area.maxHeight - 4),
                child: IgnorePointer(
                  child: _ProgressiveOpeningBadge(
                    standardScore: minimumStandardOpeningScore!,
                    pairCount: minimumPairOpeningCount!,
                  ),
                ),
              ),
            Positioned(
              left: openingWidth + 2,
              bottom: 2,
              child: SizedBox(
                key: const ValueKey('grid-per-summary'),
                width: summaryWidth,
                height: min(displayTileHeight * 1.22, area.maxHeight - 4),
                child: _RackPerSummary(
                  points: perPoints,
                  showRemaining: showRemainingPoints,
                  pairCount: pairCount,
                ),
              ),
            ),
            Positioned(
              left: openingWidth + summaryWidth + 6,
              right: 2,
              bottom: 2,
              height: min(displayTileHeight * 1.22, area.maxHeight - 4),
              child: SizedBox(
                key: const ValueKey('expanded-deck-draw-hit-area'),
                child: _DeckDrawHandle(
                  enabled: canDraw,
                  count: deckCount,
                  onDraw: onDraw,
                  feedbackWidth: dragTileWidth,
                  feedbackHeight: dragTileHeight,
                  displayWidth: displayTileWidth,
                  displayHeight: displayTileHeight,
                  child: DragTarget<_RackDragData>(
                    key: const ValueKey('center-finish-drop-target'),
                    onWillAcceptWithDetails: (details) =>
                        canFinishByCenterDrop &&
                        details.data.tileIds.length == 1,
                    onAcceptWithDetails: (details) =>
                        onFinishByCenterDrop(details.data),
                    builder: (context, candidates, rejected) => Container(
                      key: const ValueKey('indicator-deck-draw-hit-area'),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? const Color(0x2257A978)
                            : Colors.transparent,

                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: candidates.isNotEmpty
                              ? OC.okeyGold
                              : Colors.transparent,
                          width: candidates.isNotEmpty ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (indicator != null)
                            SizedBox(
                              key: const ValueKey('grid-indicator'),
                              width: itemWidth,
                              height: displayTileHeight,
                              child: _TileWidget(
                                tile: indicator!,
                                emphasized: true,
                                w: displayTileWidth,
                                h: displayTileHeight,
                                onTap: null,
                              ),
                            ),
                          SizedBox(
                            width:
                                2 +
                                min(max(0, (deckCount - 1) ~/ 12), 3) *
                                    displayTileWidth *
                                    0.046,
                          ),
                          SizedBox(
                            key: const ValueKey('grid-deck-slot'),
                            width: itemWidth,
                            height: displayTileHeight,
                            child: _DeckStack(
                              count: deckCount,
                              tileWidth: displayTileWidth,
                              tileHeight: displayTileHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairMeldGrid extends StatelessWidget {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double frameWidth;
  final List<MapEntry<int, Meld>> entries;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final ValueChanged<_RackDragData> onPairDrop;
  final bool Function(_RackDragData) canAcceptPairDrop;

  const _PairMeldGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.frameWidth,
    required this.entries,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    required this.onPairDrop,
    required this.canAcceptPairDrop,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('pair-meld-grid-surface'),
    width: columns * cellWidth + frameWidth * 2,
    height: rows * cellHeight + frameWidth * 2,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xFF082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GridPainter(
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                majorColumnInterval: 0,
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: RepaintBoundary(child: _GridCursorGuides()),
        ),
        Positioned.fill(
          child: DragTarget<_RackDragData>(
            key: const ValueKey('pair-area-drop-target'),
            onWillAcceptWithDetails: (details) =>
                canAcceptPairDrop(details.data),
            onAcceptWithDetails: (details) => onPairDrop(details.data),
            builder: (context, candidates, rejected) {
              final acceptedHover = candidates.isNotEmpty;
              final rejectedHover = rejected.isNotEmpty;
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: acceptedHover
                        ? OC.numGreen.withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: acceptedHover || rejectedHover
                        ? Border.all(
                            color: acceptedHover ? OC.okeyGold : OC.numRed,
                            width: 2.5,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        for (final entry in entries)
          Positioned(
            left:
                (entries.indexOf(entry) % (columns ~/ 2)) * cellWidth * 2 -
                cellWidth * 2,
            top:
                (entries.indexOf(entry) ~/ (columns ~/ 2)) * cellHeight -
                min(18.0, cellHeight * .30),
            width: cellWidth * 6,
            height: cellHeight + min(18.0, cellHeight * .30) * 2,
            child: DragTarget<_RackDragData>(
              key: ValueKey('pair-meld-target-${entry.key}'),
              onWillAcceptWithDetails: (details) =>
                  canAcceptMeldDrop(entry.key, details.data),
              onAcceptWithDetails: (details) =>
                  onMeldDrop(entry.key, details.data),
              builder: (context, candidates, rejected) {
                final isEligible =
                    uiMode == 'addMeld' &&
                    eligibleMeldIndexes.contains(entry.key);
                final acceptedHover = candidates.isNotEmpty;
                final rejectedHover = rejected.isNotEmpty;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cellWidth * 2,
                    vertical: min(18.0, cellHeight * .30),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isEligible ? () => onMeldTap(entry.key) : null,
                    child: Container(
                      key: ValueKey('pair-meld-${entry.key}'),
                      decoration: BoxDecoration(
                        color: acceptedHover
                            ? OC.gold.withValues(alpha: 0.30)
                            : isEligible
                            ? OC.numGreen.withValues(alpha: 0.25)
                            : Colors.transparent,
                        border: acceptedHover || rejectedHover
                            ? Border.all(
                                color: acceptedHover ? OC.okeyGold : OC.numRed,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, pairBox) => _CachedMeldRow(
                                meld: entry.value,
                                cellWidth:
                                    pairBox.maxWidth /
                                    max(1, entry.value.tiles.length),
                                cellHeight: pairBox.maxHeight,
                              ),
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
      ],
    ),
  );
}

class _RunMeldGrid extends StatelessWidget {
  static final Map<int, List<({int row, int column})>> _layoutCache = {};
  static final Map<int, Map<int, int>> _stableRunRows = {};

  static void clearLayoutCache() {
    _layoutCache.clear();
    _stableRunRows.clear();
  }

  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double frameWidth;
  final List<MapEntry<int, Meld>> entries;
  final String uiMode;
  final Set<int> eligibleMeldIndexes;
  final Function(int) onMeldTap;
  final void Function(int, _RackDragData) onMeldDrop;
  final bool Function(int, _RackDragData) canAcceptMeldDrop;
  final int meldGapColumns;

  const _RunMeldGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.frameWidth,
    required this.entries,
    required this.uiMode,
    required this.eligibleMeldIndexes,
    required this.onMeldTap,
    required this.onMeldDrop,
    required this.canAcceptMeldDrop,
    this.meldGapColumns = 0,
  });

  List<({MapEntry<int, Meld> entry, int row, int column})> _placements() {
    final cacheKey = Object.hash(
      columns,
      rows,
      meldGapColumns,
      Object.hashAll(
        entries.map(
          (entry) => Object.hash(
            entry.key,
            entry.value.type,
            Object.hashAll(entry.value.tiles.map((tile) => tile.id)),
          ),
        ),
      ),
    );
    final cached = _layoutCache[cacheKey];
    if (cached != null && cached.length == entries.length) {
      return [
        for (var index = 0; index < entries.length; index++)
          (
            entry: entries[index],
            row: cached[index].row,
            column: cached[index].column,
          ),
      ];
    }

    List<({MapEntry<int, Meld> entry, int row, int column})> remember(
      List<({MapEntry<int, Meld> entry, int row, int column})> result,
    ) {
      if (_layoutCache.length >= 3) _layoutCache.clear();
      _layoutCache[cacheKey] = [
        for (final placement in result)
          (row: placement.row, column: placement.column),
      ];
      return result;
    }

    if (entries.isNotEmpty && entries.first.value.type == 'grup') {
      final result = <({MapEntry<int, Meld> entry, int row, int column})>[];
      // Right-hand groups occupy their actual length plus one empty cell.
      var row = 0;
      var column = 0;
      for (final entry in entries) {
        final length = entry.value.tiles.length;
        if (column > 0 && column + length > columns) {
          row++;
          column = 0;
        }
        if (row >= rows) break;
        result.add((entry: entry, row: row, column: column));
        column += length + meldGapColumns;
      }
      return remember(result);
    }

    final occupied = <int, Set<int>>{};
    final rowsByColor = <TileColor, List<int>>{
      for (final color in TileColor.values) color: [min(color.index, rows - 1)],
    };
    final rowOwners = <int, TileColor>{
      for (final color in TileColor.values)
        if (color.index < rows) color.index: color,
    };
    final result = <({MapEntry<int, Meld> entry, int row, int column})>[];
    final stableKey = Object.hash(columns, rows, meldGapColumns, 'runs');
    final stableRows = _stableRunRows.putIfAbsent(
      stableKey,
      () => <int, int>{},
    );

    for (final entry in entries) {
      final meld = entry.value;
      final color = meld.tiles
          .firstWhere((tile) => !tile.isOkey, orElse: () => meld.tiles.first)
          .color;
      final anchorIndex = meld.tiles.indexWhere((tile) => !tile.isOkey);
      final rawStart = anchorIndex < 0
          ? 0
          : meld.tiles[anchorIndex].number - 1 - anchorIndex;
      final column = rawStart
          .clamp(0, max(0, columns - meld.tiles.length))
          .toInt();
      final reservedColumns = {
        for (
          var reserved = max(0, column - meldGapColumns);
          reserved <=
              min(columns - 1, column + meld.tiles.length - 1 + meldGapColumns);
          reserved++
        )
          reserved,
      };
      final colorRows = rowsByColor[color]!;
      int? targetRow;
      final previousRow = stableRows[entry.key];
      if (previousRow != null && previousRow >= 0 && previousRow < rows) {
        final previousColumns = occupied[previousRow] ?? const <int>{};
        final owner = rowOwners[previousRow];
        final colorBaseRow = min(color.index, rows - 1);
        final acceptsColor =
            previousRow == colorBaseRow ||
            (previousRow >= TileColor.values.length &&
                (owner == null || owner == color));
        if (acceptsColor &&
            previousColumns.intersection(reservedColumns).isEmpty) {
          targetRow = previousRow;
          rowOwners[previousRow] = color;
          if (!colorRows.contains(previousRow)) colorRows.add(previousRow);
        }
      }
      for (final row in colorRows) {
        if (targetRow != null) break;
        final rowColumns = occupied[row] ?? const <int>{};
        if (rowColumns.intersection(reservedColumns).isEmpty) {
          targetRow = row;
          break;
        }
      }

      if (targetRow == null) {
        for (var row = rows - 1; row >= TileColor.values.length; row--) {
          if (rowOwners.containsKey(row)) continue;
          rowOwners[row] = color;
          colorRows.add(row);
          targetRow = row;
          break;
        }
      }
      targetRow ??= colorRows.last;
      stableRows[entry.key] = targetRow;
      occupied.putIfAbsent(targetRow, () => <int>{}).addAll(reservedColumns);
      result.add((entry: entry, row: targetRow, column: column));
    }
    return remember(result);
  }

  Widget _meldWidget(MapEntry<int, Meld> entry) {
    final isEligible =
        uiMode == 'addMeld' && eligibleMeldIndexes.contains(entry.key);
    final horizontalPadding = cellWidth * 3;
    final verticalPadding = min(32.0, cellHeight * .65);
    return Transform.translate(
      offset: Offset(-horizontalPadding, -verticalPadding),
      child: SizedBox(
        width: cellWidth * entry.value.tiles.length + horizontalPadding * 2,
        height: cellHeight + verticalPadding * 2,
        child: DragTarget<_RackDragData>(
          onWillAcceptWithDetails: (details) =>
              canAcceptMeldDrop(entry.key, details.data),
          onAcceptWithDetails: (details) => onMeldDrop(entry.key, details.data),
          builder: (context, candidates, rejected) {
            final acceptedCandidates = candidates
                .whereType<_RackDragData>()
                .toList();
            final acceptedHover = acceptedCandidates.isNotEmpty;
            final hovering = acceptedHover || rejected.isNotEmpty;
            final focusColor = acceptedHover ? OC.okeyGold : OC.numRed;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Container(
                key: ValueKey('run-meld-${entry.key}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isEligible ? () => onMeldTap(entry.key) : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hovering || isEligible)
                        Positioned.fill(
                          child: ColoredBox(
                            color: hovering
                                ? (acceptedHover ? OC.gold : OC.numRed)
                                      .withValues(alpha: 0.30)
                                : OC.numGreen.withValues(alpha: 0.25),
                          ),
                        ),
                      Positioned.fill(
                        child: _CachedMeldRow(
                          meld: entry.value,
                          cellWidth: cellWidth,
                          cellHeight: cellHeight,
                        ),
                      ),
                      if (hovering)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: focusColor, width: 2),
                              ),
                            ),
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
  }

  @override
  Widget build(BuildContext context) => Container(
    width: columns * cellWidth + frameWidth * 2,
    height: rows * cellHeight + frameWidth * 2,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xFF082E32),
      border: Border.all(color: const Color(0xFF718D83), width: frameWidth),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GridPainter(
                cellWidth: cellWidth,
                cellHeight: cellHeight,
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: RepaintBoundary(child: _GridCursorGuides()),
        ),
        for (final placement in _placements())
          Positioned(
            left: placement.column * cellWidth,
            top: placement.row * cellHeight,
            child: _meldWidget(placement.entry),
          ),
      ],
    ),
  );
}

class _GridCursorGuides extends StatelessWidget {
  const _GridCursorGuides();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (gridContext, bounds) =>
          ValueListenableBuilder<_RackDragVisualState>(
            valueListenable: context
                .dependOnInheritedWidgetOfExactType<_TileMotionScope>()!
                .dragVisual,
            builder: (context, visual, _) {
              final target = visual.target;
              final render = gridContext.findRenderObject();
              if (target == null || render is! RenderBox || !render.hasSize) {
                return const SizedBox.shrink();
              }
              final point = render.globalToLocal(target.point);
              if (!(Offset.zero & bounds.biggest).contains(point)) {
                return const SizedBox.shrink();
              }
              final near = target.hitRect.contains(
                visual.globalGridPosition ?? target.point,
              );
              final face = Rect.fromPoints(
                render.globalToLocal(target.faceRect.topLeft),
                render.globalToLocal(target.faceRect.bottomRight),
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (visual.gridPosition != null)
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey('grid-meld-coordinate-guide'),
                        painter: _MeldCoordinatePainter(
                          point,
                          visual.color,
                          const [],
                        ),
                      ),
                    ),
                  if (near)
                    Positioned.fromRect(
                      rect: face.inflate(3),
                      child: DecoratedBox(
                        key: const ValueKey('meld-drop-target-glow'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: visual.color.withValues(alpha: .85),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: visual.color.withValues(alpha: .24),
                              blurRadius: 12,
                            ),
                          ],
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

class _MeldCoordinatePainter extends CustomPainter {
  final Offset target;
  final Color color;
  final List<Rect> occludedRects;
  const _MeldCoordinatePainter(this.target, this.color, this.occludedRects);

  void _drawAxis(
    Canvas canvas,
    Size size,
    Offset point,
    Paint paint, {
    required bool horizontal,
  }) {
    final extent = horizontal ? size.width : size.height;
    final coordinate = horizontal ? point.dy : point.dx;
    final intervals = <(double, double)>[];
    for (final rect in occludedRects) {
      if (coordinate < (horizontal ? rect.top : rect.left) ||
          coordinate > (horizontal ? rect.bottom : rect.right)) {
        continue;
      }
      intervals.add((
        (horizontal ? rect.left : rect.top).clamp(0.0, extent),
        (horizontal ? rect.right : rect.bottom).clamp(0.0, extent),
      ));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    void segment(double from, double to) {
      if (to <= from) return;
      canvas.drawLine(
        horizontal ? Offset(from, coordinate) : Offset(coordinate, from),
        horizontal ? Offset(to, coordinate) : Offset(coordinate, to),
        paint,
      );
    }

    var cursor = 0.0;
    for (final interval in intervals) {
      segment(cursor, interval.$1);
      cursor = max(cursor, interval.$2);
    }
    segment(cursor, extent);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Leave gaps behind melds without allocating a clipping mask.
    final point = Offset(
      target.dx.clamp(0.0, size.width),
      target.dy.clamp(0.0, size.height),
    );
    for (final paint in [
      Paint()
        ..color = Colors.white.withValues(alpha: .35)
        ..strokeWidth = 3.0,
      Paint()
        ..color = color.withValues(alpha: .90)
        ..strokeWidth = 1.3,
    ]) {
      _drawAxis(canvas, size, point, paint, horizontal: true);
      _drawAxis(canvas, size, point, paint, horizontal: false);
    }
  }

  @override
  bool shouldRepaint(_MeldCoordinatePainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.occludedRects, occludedRects);
}

class _MeldRow extends StatelessWidget {
  final Meld meld;
  final double cellWidth;
  final double cellHeight;

  const _MeldRow({
    required this.meld,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    final tileWidth = max(1.0, min(cellWidth - 1, (cellHeight - 1) / 1.46));
    final tileHeight = max(1.0, tileWidth * 1.46);
    return Row(
      children: meld.tiles
          .map(
            (tile) => SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: Center(
                child: _TileWidget(
                  key: ValueKey('table-visible-tile-${tile.id}'),
                  tile: tile,
                  w: tileWidth,
                  h: tileHeight,
                  onTap: null,
                  borderRadius: 2,
                  hideOkey: true,
                  allowOkeyFaceToggle: false,
                  emphasized: true,
                  numberScale: 1.08,
                  showShadow: false,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ALT ALAN (Sen + Atılan/Çekilen)
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// ISTAKA
// ═══════════════════════════════════════════════════════════════════════════
class _CachedMeldRow extends StatefulWidget {
  final Meld meld;
  final double cellWidth;
  final double cellHeight;

  const _CachedMeldRow({
    required this.meld,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  State<_CachedMeldRow> createState() => _CachedMeldRowState();
}

class _CachedMeldRowState extends State<_CachedMeldRow> {
  late int _signature;
  late Widget _row;

  int _calculateSignature() => Object.hash(
    widget.cellWidth,
    widget.cellHeight,
    widget.meld.type,
    Object.hashAll(widget.meld.tiles.map((tile) => tile.id)),
  );

  Widget _buildRow() => _MeldRow(
    meld: widget.meld,
    cellWidth: widget.cellWidth,
    cellHeight: widget.cellHeight,
  );

  @override
  void initState() {
    super.initState();
    _signature = _calculateSignature();
    _row = _buildRow();
  }

  @override
  void didUpdateWidget(covariant _CachedMeldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _calculateSignature();
    if (next == _signature) return;
    _signature = next;
    _row = _buildRow();
  }

  @override
  Widget build(BuildContext context) => _row;
}

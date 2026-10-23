part of 'oda.dart';

class _RoomCard extends StatelessWidget {
  final _RoomData room;
  final bool isSelected, canAfford, unlocked;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.isSelected,
    required this.canAfford,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isSelected,
    label:
        '${room.label}, ${room.feeLabel} altın${unlocked ? '' : ', seviye ${room.requiredLevel} gerekli'}',
    child: GestureDetector(
      key: ValueKey('room-card-${room.tier}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
                colors: [room.accentDark, const Color(0xFF001A0B)],
              ),
              border: Border.all(
                color: isSelected ? const Color(0xFFF1FFA7) : room.accentColor,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: room.accentColor.withValues(alpha: .7),
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
                    child: CustomPaint(painter: _RoomShinePainter()),
                  ),
                  Positioned(
                    top: 80,
                    left: 3,
                    right: 3,
                    height: 282,
                    child: _RoomTableArtwork(room: room, unlocked: unlocked),
                  ),
                  Positioned(
                    top: 18,
                    left: 14,
                    right: 14,
                    height: 62,
                    child: Center(
                      child: _RoomText(
                        room.tier == 3 ? 'ELİT' : room.label.toUpperCase(),
                        fontSize: 42,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 48,
                    right: 48,
                    top: 365,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xD9001008),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: room.accentColor.withValues(alpha: .85),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'images/ui/coin.png',
                            width: 42,
                            height: 42,
                            cacheWidth: 84,
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: _RoomText(
                              room.feeLabel,
                              fontSize: 42,
                              color: room.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!unlocked)
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 447,
                      height: 65,
                      child: Center(
                        child: _RoomText(
                          "SEVİYE ${room.requiredLevel}'TE AÇILIR",
                          fontSize: 28,
                          color: const Color(0xFFFFEC72),
                        ),
                      ),
                    )
                  else ...[
                    Positioned(
                      top: 460,
                      left: 62,
                      right: 62,
                      height: 52,
                      child: Center(
                        child: isSelected
                            ? const _RoomStatusBadge('SEÇİLİ', selected: true)
                            : room.recommended
                            ? const _RoomStatusBadge(
                                'ÖNERİLEN',
                                recommended: true,
                              )
                            : !canAfford
                            ? const _RoomText(
                                'YETERSİZ ALTIN',
                                fontSize: 22,
                                color: Color(0xFFFFBE9A),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Read only the table illustration from the supplied reference. Titles, fees,
/// selection and lock state remain live widgets, not baked labels.
class _RoomTableArtwork extends StatelessWidget {
  final _RoomData room;
  final bool unlocked;
  const _RoomTableArtwork({required this.room, required this.unlocked});

  static const _crops = [
    Rect.fromLTWH(100, 250, 408, 280),
    Rect.fromLTWH(531, 250, 391, 280),
    Rect.fromLTWH(947, 250, 387, 280),
    Rect.fromLTWH(1360, 250, 408, 280),
  ];

  @override
  Widget build(BuildContext context) {
    final crop = _crops[room.tier];
    final originalBadgeApplies =
        (room.tier < 2 && unlocked) || (room.tier >= 2 && !unlocked);
    return Stack(
      fit: StackFit.expand,
      children: [
        ShaderMask(
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
            stops: [0, .09, .95, 1],
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
                        'images/rooms/room-reference.webp',
                        key: ValueKey('room-table-art-${room.tier}'),
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
        ),
        if (!originalBadgeApplies)
          Positioned(
            top: 6,
            right: 10,
            width: 184,
            height: 184,
            child: DecoratedBox(
              key: ValueKey('room-dynamic-emblem-${room.tier}'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [room.accentDark, const Color(0xFF001009)],
                ),
                border: Border.all(
                  color: unlocked ? room.accentColor : const Color(0xFFFFE47E),
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 10),
                ],
              ),
              child: Icon(
                unlocked ? room.tierIcon : Icons.lock_rounded,
                size: 96,
                color: unlocked ? room.accentColor : const Color(0xFFFFDC66),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoomText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  const _RoomText(
    this.text, {
    required this.fontSize,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: 'Baloo 2',
        color: color,
        fontSize: fontSize,
        height: 1.1,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
    ),
  );
}

class _RoomStatusBadge extends StatelessWidget {
  final String label;
  final bool selected, recommended;
  const _RoomStatusBadge(
    this.label, {
    this.selected = false,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    decoration: BoxDecoration(
      color: recommended ? const Color(0xFF0943C6) : const Color(0xFF00220B),
      border: Border.all(
        color: recommended ? const Color(0xFFA8DAFF) : const Color(0xFFFFE850),
        width: 2,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          const Icon(Icons.check_rounded, color: Color(0xFFFFEB6B), size: 32),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: _RoomText(
            label,
            fontSize: 28,
            color: selected ? const Color(0xFFFFEB6B) : Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _EnterRoomButton extends StatelessWidget {
  final bool enabled;
  final double width, height;
  final VoidCallback onTap;
  const _EnterRoomButton({
    required this.enabled,
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
      gradient: LinearGradient(
        colors: enabled
            ? const [Color(0xFF087A23), Color(0xFF79E960)]
            : const [Color(0xFF273C2A), Color(0xFF4E6950)],
      ),
      border: Border.all(
        color: enabled ? const Color(0xFFC0FF91) : const Color(0xFF859B79),
        width: 1.5,
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: TextButton(
      key: const ValueKey('room-enter-button'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 26),
          const SizedBox(width: 8),
          const Flexible(child: _RoomText('Odaya Gir', fontSize: 24)),
        ],
      ),
    ),
  );
}

class _RoomShinePainter extends CustomPainter {
  const _RoomShinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(-40, 210)
        ..lineTo(140, 0)
        ..lineTo(190, 0)
        ..lineTo(-40, 270)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .035),
    );
  }

  @override
  bool shouldRepaint(_RoomShinePainter oldDelegate) => false;
}

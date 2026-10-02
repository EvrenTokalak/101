import 'package:flutter/material.dart';

import 'game_launch.dart';
import 'app_controls.dart';
import 'game_navigation.dart';
import 'main.dart';
import 'player_progress.dart';

class RoomSelectScreen extends StatefulWidget {
  const RoomSelectScreen({super.key});

  @override
  State<RoomSelectScreen> createState() => _RoomSelectScreenState();
}

class _RoomSelectScreenState extends State<RoomSelectScreen> {
  int _selectedIndex = 0;

  static const _rooms = [
    _RoomData(
      label: 'Başlangıç',
      entryFee: 500,
      feeLabel: '500',
      maxPlayers: 8,
      currentPlayers: 6,
      tier: 0,
      accentColor: Color(0xFF55C96A),
      accentDark: Color(0xFF174E28),
      tierLabel: 'KOLAY',
      tierIcon: Icons.spa_rounded,
      imageAsset: 'images/rooms/room_start.jpg',
      requiredLevel: 0,
    ),
    _RoomData(
      label: 'Standart',
      entryFee: 1000,
      feeLabel: '1.000',
      maxPlayers: 8,
      currentPlayers: 5,
      tier: 1,
      accentColor: Color(0xFF54A8F5),
      accentDark: Color(0xFF174A78),
      tierLabel: 'NORMAL',
      tierIcon: Icons.shield_rounded,
      imageAsset: 'images/rooms/room_standard.jpg',
      recommended: true,
      requiredLevel: 5,
    ),
    _RoomData(
      label: 'VIP',
      entryFee: 5000,
      feeLabel: '5.000',
      maxPlayers: 6,
      currentPlayers: 3,
      tier: 2,
      accentColor: Color(0xFFF0C64E),
      accentDark: Color(0xFF735613),
      tierLabel: 'VIP',
      tierIcon: Icons.workspace_premium_rounded,
      imageAsset: 'images/rooms/room_vip.jpg',
      requiredLevel: 15,
    ),
    _RoomData(
      label: 'Elit',
      entryFee: 10000,
      feeLabel: '10.000',
      maxPlayers: 4,
      currentPlayers: 2,
      tier: 3,
      accentColor: Color(0xFFD48AF4),
      accentDark: Color(0xFF63327A),
      tierLabel: 'ELİT',
      tierIcon: Icons.diamond_rounded,
      imageAsset: 'images/rooms/room_elite.jpg',
      requiredLevel: 25,
    ),
  ];

  void _selectRoom(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _enterRoom() async {
    final room = _rooms[_selectedIndex];
    if (playerProgress.level < room.requiredLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${room.label} masası ${room.requiredLevel}. seviyede açılır.',
          ),
          backgroundColor: const Color(0xFF6B4714),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!playerProgress.trySpendCoins(room.entryFee)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${room.label} masası için ${formatGameNumber(room.entryFee)} altın gerekiyor.',
          ),
          backgroundColor: const Color(0xFF8B1E1E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${room.label} masasına giriliyor • Giriş: ${room.feeLabel} altın',
          style: const TextStyle(color: OkeyColors.cream),
        ),
        backgroundColor: OkeyColors.tableMid,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: OkeyColors.gold),
        ),
      ),
    );
    await openGameScreen<void>(
      context,
      config: GameLaunchConfig.room(
        id: 'room-${room.tier}',
        label: room.label,
        entryFee: room.entryFee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoom = _rooms[_selectedIndex];
    return Scaffold(
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Image.asset(
                'images/anamenu/menubg.png',
                fit: BoxFit.cover,
                cacheWidth: 1440,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.24)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final widthScale = 900 / viewport.maxWidth;
                final heightScale = 600 / viewport.maxHeight;
                final requiredScale = widthScale > heightScale
                    ? widthScale
                    : heightScale;
                final canvasScale = requiredScale < 1 ? 1.0 : requiredScale;
                final canvasWidth = viewport.maxWidth * canvasScale;
                final canvasHeight = viewport.maxHeight * canvasScale;
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: playerProgress,
                            builder: (_, _) => _RoomTopBar(
                              coinBalance: playerProgress.coins,
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _RoomSectionTitle(),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 34,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(_rooms.length, (index) {
                                  final room = _rooms[index];
                                  final isSelected = index == _selectedIndex;
                                  return Expanded(
                                    flex: isSelected ? 11 : 10,
                                    child: _RoomCard(
                                      room: room,
                                      isSelected: isSelected,
                                      canAfford:
                                          playerProgress.coins >= room.entryFee,
                                      unlocked:
                                          playerProgress.level >=
                                          room.requiredLevel,
                                      onTap: () => _selectRoom(index),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _BottomActionBar(
                            room: selectedRoom,
                            onEnter: _enterRoom,
                          ),
                          const SizedBox(height: 16),
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
}

class _RoomData {
  final String label;
  final int entryFee;
  final String feeLabel;
  final int maxPlayers;
  final int currentPlayers;
  final int tier;
  final Color accentColor;
  final Color accentDark;
  final String tierLabel;
  final IconData tierIcon;
  final String imageAsset;
  final bool recommended;
  final int requiredLevel;

  const _RoomData({
    required this.label,
    required this.entryFee,
    required this.feeLabel,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.tier,
    required this.accentColor,
    required this.accentDark,
    required this.tierLabel,
    required this.tierIcon,
    required this.imageAsset,
    this.recommended = false,
    required this.requiredLevel,
  });
}

class _RoomTopBar extends StatelessWidget {
  final int coinBalance;
  final VoidCallback onBack;
  const _RoomTopBar({required this.coinBalance, required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        AppBackButton(onTap: onBack),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OkeyColors.gold),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'images/ui/coin.png',
                width: 18,
                height: 18,
                cacheWidth: 36,
                cacheHeight: 36,
                filterQuality: FilterQuality.low,
              ),
              const SizedBox(width: 6),
              Text(
                formatGameNumber(coinBalance),
                style: const TextStyle(
                  color: OkeyColors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoomSectionTitle extends StatelessWidget {
  const _RoomSectionTitle();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text(
        'MASA SEÇ',
        style: TextStyle(
          color: OkeyColors.goldLight,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 4),
      Container(
        width: 170,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              OkeyColors.gold.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ],
  );
}

class _RoomCard extends StatelessWidget {
  final _RoomData room;
  final bool isSelected;
  final bool canAfford;
  final bool unlocked;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.isSelected,
    required this.canAfford,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('room-card-${room.tier}'),
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.fromLTRB(
        8,
        isSelected ? 0 : 13,
        8,
        isSelected ? 0 : 13,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSelected
              ? [
                  room.accentDark.withValues(alpha: 0.92),
                  OkeyColors.tableDark.withValues(alpha: 0.97),
                ]
              : [
                  OkeyColors.tableMid.withValues(alpha: 0.76),
                  OkeyColors.tableDark.withValues(alpha: 0.9),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? room.accentColor
              : OkeyColors.gold.withValues(alpha: 0.28),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: room.accentColor.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  room.imageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: 360,
                  cacheHeight: 230,
                  filterQuality: FilterQuality.low,
                  color: Colors.black.withValues(alpha: canAfford ? 0.25 : 0.6),
                  colorBlendMode: BlendMode.darken,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF09251A).withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: room.accentColor.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Icon(
                      room.tierIcon,
                      color: room.accentColor,
                      size: 34,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _RoomBadge(
                    text: room.tierLabel,
                    color: room.accentColor,
                  ),
                ),
                if (room.recommended)
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: _RoomBadge(
                      text: 'ÖNERİLEN',
                      color: OkeyColors.goldLight,
                    ),
                  ),
                if (!unlocked)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xB5081510),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: OkeyColors.gold),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                color: OkeyColors.goldLight,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'SEVİYE ${room.requiredLevel}',
                                style: const TextStyle(
                                  color: OkeyColors.goldLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isSelected)
                  const Positioned(
                    right: 10,
                    bottom: 8,
                    child: _RoomBadge(
                      text: '✓ SEÇİLİ',
                      color: OkeyColors.goldLight,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      room.label.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        color: isSelected ? Colors.white : OkeyColors.cream,
                        fontSize: isSelected ? 22 : 19,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Georgia',
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: room.accentColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: room.accentColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'images/ui/coin.png',
                          width: 17,
                          height: 17,
                          cacheWidth: 34,
                          cacheHeight: 34,
                          filterQuality: FilterQuality.low,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          room.feeLabel,
                          style: TextStyle(
                            color: room.accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!unlocked)
                    Text(
                      '${room.requiredLevel}. SEVİYEDE AÇILIR',
                      style: const TextStyle(
                        color: OkeyColors.goldLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else if (!canAfford)
                    const Text(
                      'YETERSİZ ALTIN',
                      style: TextStyle(
                        color: Color(0xFFFF8D8D),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    _PlayerBar(room: room),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _RoomBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xDD071B14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.75)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _PlayerBar extends StatelessWidget {
  final _RoomData room;
  const _PlayerBar({required this.room});

  @override
  Widget build(BuildContext context) {
    final ratio = room.currentPlayers / room.maxPlayers;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_rounded, color: Colors.white54, size: 14),
            const SizedBox(width: 5),
            Text(
              '${room.currentPlayers}/${room.maxPlayers} DOLU',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(room.accentColor),
          ),
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final _RoomData room;
  final VoidCallback onEnter;
  const _BottomActionBar({required this.room, required this.onEnter});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playerProgress,
    builder: (context, _) {
      final unlocked = playerProgress.level >= room.requiredLevel;
      final canAfford = playerProgress.coins >= room.entryFee;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Center(
          child: _EnterRoomButton(
            room: room,
            enabled: canAfford && unlocked,
            onTap: onEnter,
          ),
        ),
      );
    },
  );
}

class _EnterRoomButton extends StatefulWidget {
  final _RoomData room;
  final bool enabled;
  final VoidCallback onTap;
  const _EnterRoomButton({
    required this.room,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_EnterRoomButton> createState() => _EnterRoomButtonState();
}

class _EnterRoomButtonState extends State<_EnterRoomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 85),
      vsync: this,
    );
    _scale = _controller.drive(Tween<double>(begin: 1, end: 0.97));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
    child: GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: Container(
        height: 54,
        constraints: const BoxConstraints(minWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 54),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: widget.enabled
                ? [widget.room.accentDark, widget.room.accentColor]
                : [const Color(0xFF333333), const Color(0xFF4A4A4A)],
          ),
          border: Border.all(
            color: widget.enabled ? widget.room.accentColor : Colors.white24,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.enabled
                  ? widget.room.accentColor.withValues(alpha: 0.32)
                  : Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 7),
            Text(
              'Odaya Gir',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

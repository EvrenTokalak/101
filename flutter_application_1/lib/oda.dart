import 'package:flutter/material.dart';

import 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ODA SEÇ EKRANIColors.black.withOpacity(0.5
// ═══════════════════════════════════════════════════════════════════════════════

class RoomSelectScreen extends StatefulWidget {
  const RoomSelectScreen({super.key});

  @override
  State<RoomSelectScreen> createState() => _RoomSelectScreenState();
}

class _RoomSelectScreenState extends State<RoomSelectScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late AnimationController _enterCtrl;
  late Animation<double> _fadeIn;

  // Her kart için ayrı "seçim pulse" controller
  late List<AnimationController> _pulseControllers;

  static const _rooms = [
    _RoomData(
      label: 'Başlangıç',
      entryFee: 500,
      feeLabel: '500',
      playerCount: '2–4',
      minPlayers: 1,
      maxPlayers: 8,
      currentPlayers: 6,
      tier: 0,
      accentColor: Color(0xFF4CAF50), // yeşil — kolay giriş
      accentDark: Color(0xFF1B5E20),
      glowColor: Color(0x4A4CAF50),
      tierLabel: 'Başlangıç',
      tierIcon: '♟',
    ),
    _RoomData(
      label: 'Standart',
      entryFee: 1000,
      feeLabel: '1K',
      playerCount: '2–4',
      minPlayers: 1,
      maxPlayers: 8,
      currentPlayers: 5,
      tier: 1,
      accentColor: Color(0xFF2196F3), // mavi — orta seviye
      accentDark: Color(0xFF0D47A1),
      glowColor: Color(0x4A2196F3),
      tierLabel: 'Standart',
      tierIcon: '♜',
    ),
    _RoomData(
      label: 'VIP',
      entryFee: 5000,
      feeLabel: '5K',
      playerCount: '2–4',
      minPlayers: 1,
      maxPlayers: 6,
      currentPlayers: 3,
      tier: 2,
      accentColor: Color(0xFFD4A017), // altın — yüksek
      accentDark: Color(0xFF7A5800),
      glowColor: Color(0x5AD4A017),
      tierLabel: 'VIP',
      tierIcon: '♛',
    ),
    _RoomData(
      label: 'Elit',
      entryFee: 10000,
      feeLabel: '10K',
      playerCount: '2–4',
      minPlayers: 1,
      maxPlayers: 4,
      currentPlayers: 2,
      tier: 3,
      accentColor: Color(0xFFE040FB), // mor/pırlanta — elite
      accentDark: Color(0xFF6A0080),
      glowColor: Color(0x55E040FB),
      tierLabel: 'Elit',
      tierIcon: '♚',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
    _enterCtrl.forward();

    _pulseControllers = List.generate(
      _rooms.length,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 1400),
        vsync: this,
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    for (final c in _pulseControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectRoom(int index) {
    setState(() => _selectedIndex = index);
  }

  void _enterRoom() {
    final room = _rooms[_selectedIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${room.label} odasına giriliyor... Giriş: ${room.feeLabel} 🪙',
          style: const TextStyle(
            color: OkeyColors.cream,
            fontFamily: 'Georgia',
          ),
        ),
        backgroundColor: OkeyColors.tableMid,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: OkeyColors.gold, width: 1),
        ),
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
            child: Image.asset(
              'images/anamenu/menubg.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                // Dört oda kartı ve alt aksiyon butonu için gereken minimum
                // alanı koru. Küçük/kısa web pencerelerinde içerik kırpılmak
                // yerine tek parça hâlinde ölçeklenir.
                final canvasWidth = viewport.maxWidth < 900
                    ? 900.0
                    : viewport.maxWidth;
                final canvasHeight = viewport.maxHeight < 600
                    ? 600.0
                    : viewport.maxHeight;

                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: Column(
                          children: [
                            // ── Üst bar ─────────────────────────────────────────
                            _TopBar(coinBalance: 25600),

                            // ── Başlık ───────────────────────────────────────────
                            const SizedBox(height: 16),
                            _SectionTitle(),

                            // ── Oda kartları ─────────────────────────────────────
                            const SizedBox(height: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: List.generate(_rooms.length, (i) {
                                    return Expanded(
                                      flex: i == _selectedIndex ? 5 : 4,
                                      child: AnimatedBuilder(
                                        animation: _pulseControllers[i],
                                        builder: (_, _) => _RoomCard(
                                          room: _rooms[i],
                                          isSelected: i == _selectedIndex,
                                          pulseValue:
                                              _pulseControllers[i].value,
                                          onTap: () => _selectRoom(i),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            // ── Alt aksiyon alanı ────────────────────────────────
                            const SizedBox(height: 16),
                            _BottomActionBar(
                              room: selectedRoom,
                              onEnter: _enterRoom,
                              onBack: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
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

// ─── Veri Modeli ──────────────────────────────────────────────────────────────
class _RoomData {
  final String label;
  final int entryFee;
  final String feeLabel;
  final String playerCount;
  final int minPlayers;
  final int maxPlayers;
  final int currentPlayers;
  final int tier;
  final Color accentColor;
  final Color accentDark;
  final Color glowColor;
  final String tierLabel;
  final String tierIcon;

  const _RoomData({
    required this.label,
    required this.entryFee,
    required this.feeLabel,
    required this.playerCount,
    required this.minPlayers,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.tier,
    required this.accentColor,
    required this.accentDark,
    required this.glowColor,
    required this.tierLabel,
    required this.tierIcon,
  });
}

// ─── Üst Bar ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int coinBalance;
  const _TopBar({required this.coinBalance});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Geri butonu
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: OkeyColors.gold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: OkeyColors.cream,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          // Coin gösterge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OkeyColors.gold, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: OkeyColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatCoins(coinBalance),
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

  static String _formatCoins(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }
}

// ─── Başlık ──────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Oda Seç',
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
          width: 120,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                OkeyColors.gold.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Oda Kartı ───────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final _RoomData room;
  final bool isSelected;
  final double pulseValue;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.isSelected,
    required this.pulseValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glowStrength = isSelected ? (0.55 + pulseValue * 0.25) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        margin: EdgeInsets.fromLTRB(
          6,
          isSelected ? 0 : 12,
          6,
          isSelected ? 0 : 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isSelected
                ? [
                    room.accentDark.withValues(alpha: 0.85),
                    OkeyColors.tableDark.withValues(alpha: 0.95),
                  ]
                : [
                    OkeyColors.tableMid.withValues(alpha: 0.7),
                    OkeyColors.tableDark.withValues(alpha: 0.85),
                  ],
          ),
          border: Border.all(
            color: isSelected
                ? room.accentColor
                : OkeyColors.gold.withValues(alpha: 0.25),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: room.glowColor.withValues(alpha: glowStrength),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Tier ikonu ─────────────────────────────────────
              _TierBadge(room: room, isSelected: isSelected),

              // ── Orta: Giriş ücreti ─────────────────────────────
              Column(
                children: [
                  Text(
                    room.tierIcon,
                    style: TextStyle(
                      fontSize: isSelected ? 36 : 28,
                      color: room.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : OkeyColors.cream,
                      fontSize: isSelected ? 15 : 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Giriş ücreti
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: room.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: room.accentColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: room.accentColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room.feeLabel,
                          style: TextStyle(
                            color: room.accentColor,
                            fontSize: isSelected ? 17 : 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Alt: Oyuncu durumu ──────────────────────────────
              _PlayerBar(room: room, isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tier Rozeti ─────────────────────────────────────────────────────────────
class _TierBadge extends StatelessWidget {
  final _RoomData room;
  final bool isSelected;
  const _TierBadge({required this.room, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: room.accentColor.withValues(alpha: isSelected ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: room.accentColor.withValues(alpha: isSelected ? 0.8 : 0.35),
          width: 1,
        ),
      ),
      child: Text(
        room.tierLabel.toUpperCase(),
        style: TextStyle(
          color: room.accentColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ─── Oyuncu Doluluk Barı ──────────────────────────────────────────────────────
class _PlayerBar extends StatelessWidget {
  final _RoomData room;
  final bool isSelected;
  const _PlayerBar({required this.room, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final ratio = room.currentPlayers / room.maxPlayers;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              color: OkeyColors.cream.withValues(alpha: 0.6),
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '${room.currentPlayers}/${room.maxPlayers}',
              style: TextStyle(
                color: OkeyColors.cream.withValues(alpha: 0.7),
                fontSize: 11,
                fontFamily: 'Georgia',
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
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              room.accentColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Alt Aksiyon Barı ─────────────────────────────────────────────────────────
class _BottomActionBar extends StatefulWidget {
  final _RoomData room;
  final VoidCallback onEnter;
  final VoidCallback onBack;

  const _BottomActionBar({
    required this.room,
    required this.onEnter,
    required this.onBack,
  });

  @override
  State<_BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends State<_BottomActionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _btnCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      duration: const Duration(milliseconds: 110),
      vsync: this,
    );
    _scale = _btnCtrl.drive(Tween<double>(begin: 1.0, end: 0.95));
  }

  @override
  void dispose() {
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Seçili oda özeti (solda)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: room.accentColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    room.tierIcon,
                    style: TextStyle(color: room.accentColor, fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.label,
                        style: const TextStyle(
                          color: OkeyColors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: OkeyColors.gold,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Giriş: ${room.feeLabel}',
                            style: TextStyle(
                              color: OkeyColors.gold,
                              fontSize: 11,
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Odaya Gir butonu (sağda)
          AnimatedBuilder(
            animation: _scale,
            builder: (_, child) =>
                Transform.scale(scale: _scale.value, child: child),
            child: GestureDetector(
              onTapDown: (_) => _btnCtrl.forward(),
              onTapUp: (_) async {
                await _btnCtrl.reverse();
                widget.onEnter();
              },
              onTapCancel: () => _btnCtrl.reverse(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      room.accentDark,
                      room.accentColor,
                      room.accentDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: room.accentColor.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: room.glowColor.withValues(alpha: 0.55),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Odaya Gir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

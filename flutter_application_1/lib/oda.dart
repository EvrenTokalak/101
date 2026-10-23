import 'package:flutter/material.dart';

import 'game_launch.dart';
import 'game_navigation.dart';
import 'player_progress.dart';
import 'selection_page.dart';
import 'difficulty_picker.dart';

part 'room_selection_widgets.dart';

class RoomSelectScreen extends StatefulWidget {
  const RoomSelectScreen({super.key});

  @override
  State<RoomSelectScreen> createState() => _RoomSelectScreenState();
}

class _RoomSelectScreenState extends State<RoomSelectScreen> {
  int _selectedIndex = 0;
  bool _entering = false;

  static const _rooms = [
    _RoomData(
      label: 'Başlangıç',
      entryFee: 1500,
      feeLabel: '1.500',
      tier: 0,
      accentColor: Color(0xFF55C96A),
      accentDark: Color(0xFF00420C),
      tierIcon: Icons.spa_rounded,
      requiredLevel: 0,
    ),
    _RoomData(
      label: 'Standart',
      entryFee: 3750,
      feeLabel: '3.750',
      tier: 1,
      accentColor: Color(0xFF54A8F5),
      accentDark: Color(0xFF002B49),
      tierIcon: Icons.shield_rounded,
      recommended: true,
      requiredLevel: 5,
    ),
    _RoomData(
      label: 'VIP',
      entryFee: 7500,
      feeLabel: '7.500',
      tier: 2,
      accentColor: Color(0xFFF0C64E),
      accentDark: Color(0xFF191D0E),
      tierIcon: Icons.workspace_premium_rounded,
      requiredLevel: 15,
    ),
    _RoomData(
      label: 'Elit',
      entryFee: 12000,
      feeLabel: '12.000',
      tier: 3,
      accentColor: Color(0xFFD48AF4),
      accentDark: Color(0xFF190D25),
      tierIcon: Icons.diamond_rounded,
      requiredLevel: 25,
    ),
  ];

  void _selectRoom(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _enterRoom() async {
    if (_entering) return;
    final room = _rooms[_selectedIndex];
    if (playerProgress.level < room.requiredLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          dismissDirection: DismissDirection.horizontal,
          content: Text(
            '${room.label} masası ${room.requiredLevel}. seviyede açılır.',
          ),
          backgroundColor: const Color(0xFF6B4714),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (playerProgress.coins < room.entryFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          dismissDirection: DismissDirection.horizontal,
          content: Text(
            '${room.label} masası için ${formatGameNumber(room.entryFee)} altın gerekiyor.',
          ),
          backgroundColor: const Color(0xFF8B1E1E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _entering = true;
    try {
      final difficulty = await pickBotDifficulty(context);
      if (difficulty == null || !mounted) return;
      await openGameScreen<void>(
        context,
        config: GameLaunchConfig.room(
          id: 'room-${room.tier}',
          label: room.label,
          entryFee: room.entryFee,
        ).withDifficulty(difficulty),
      );
    } finally {
      _entering = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playerProgress,
    builder: (context, _) => SelectionPage(
      title: 'MASA SEÇ',
      onBack: () => Navigator.of(context).pop(),
      gridKey: const ValueKey('room-card-grid'),
      cards: [
        for (var index = 0; index < _rooms.length; index++)
          _RoomCard(
            room: _rooms[index],
            isSelected: index == _selectedIndex,
            canAfford: playerProgress.coins >= _rooms[index].entryFee,
            unlocked: playerProgress.level >= _rooms[index].requiredLevel,
            onTap: () => _selectRoom(index),
          ),
      ],
      actionBuilder: (height, width) => _EnterRoomButton(
        enabled:
            playerProgress.level >= _rooms[_selectedIndex].requiredLevel &&
            playerProgress.coins >= _rooms[_selectedIndex].entryFee,
        width: (width * .24).clamp(210.0, 380.0),
        height: (height * .78).clamp(40.0, 66.0),
        onTap: _enterRoom,
      ),
    ),
  );
}

class _RoomData {
  final String label, feeLabel;
  final int entryFee, tier, requiredLevel;
  final Color accentColor, accentDark;
  final IconData tierIcon;
  final bool recommended;

  const _RoomData({
    required this.label,
    required this.entryFee,
    required this.feeLabel,
    required this.tier,
    required this.accentColor,
    required this.accentDark,
    required this.tierIcon,
    required this.requiredLevel,
    this.recommended = false,
  });
}

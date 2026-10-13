import 'dart:math';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'player_progress.dart';

class AvatarPickerDialog extends StatefulWidget {
  const AvatarPickerDialog({super.key});
  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  late int _selected = playerProgress.playerAvatarIndex;
  final _scroll = ScrollController();
  static const _gold = Color(0xFFEBD268);
  static const _names = [
    'Tilki',
    'Kurt',
    'Aslan',
    'Kaplan',
    'Ayı',
    'Panda',
    'Tavşan',
    'Rakun',
    'Baykuş',
    'Kartal',
    'Timsah',
    'Köpekbalığı',
    'Goril',
    'Keçi',
    'Koç',
    'Fil',
    'Zürafa',
    'Su aygırı',
    'Penguen',
    'Ejderha',
    'Tavuk',
    'Boğa',
    'Domuz',
    'Yaban domuzu',
  ];
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = appPopupSize(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        key: const ValueKey('profile-avatar-picker'),
        width: min(620, size.width * .9),
        height: min(480, size.height * .82),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF174C36), Color(0xFF071F18)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle_rounded,
                    color: _gold,
                    size: 25,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText('PROFİL FOTOĞRAFI', 'PROFILE PICTURE'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFF4D0),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${playerAvatarAssets.length} resim · Seç ve kullan',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppCloseButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final columns = (bounds.maxWidth / 82).floor().clamp(3, 7);
                  return Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: GridView.builder(
                      key: const ValueKey('profile-avatar-grid'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 9,
                        mainAxisSpacing: 9,
                      ),
                      itemCount: playerAvatarAssets.length,
                      itemBuilder: (context, index) {
                        final selected = index == _selected;
                        return Semantics(
                          label: _names[index],
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('profile-avatar-$index'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _selected = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _gold.withValues(alpha: .18)
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? _gold : Colors.white12,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: Image.asset(
                                        playerAvatarAssets[index],
                                        fit: BoxFit.cover,
                                        cacheWidth: 144,
                                        cacheHeight: 144,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _gold,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 17,
                                            color: Color(0xFF143629),
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
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0B281D),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      playerAvatarAssets[_selected],
                      key: const ValueKey('profile-avatar-preview'),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      cacheHeight: 96,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _names[_selected],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('profile-avatar-confirm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4A943E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(96, 42),
                    ),
                    onPressed: () {
                      playerProgress.updatePlayerAvatar(_selected);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(appText('KULLAN', 'USE')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

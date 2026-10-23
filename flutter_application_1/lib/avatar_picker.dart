import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'player_progress.dart';

class AvatarPickerDialog extends StatefulWidget {
  final int? selectedIndex;
  const AvatarPickerDialog({super.key, this.selectedIndex});
  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
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
    return SafeArea(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final size = appArtworkPanelSize(bounds) * .92;
            return AppGenericPanel(
              key: const ValueKey('profile-avatar-picker'),
              width: size.width,
              height: size.height,
              title: Text(appText('PROFİL FOTOĞRAFI', 'PROFILE PICTURE')),
              onClose: () => Navigator.pop(context),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final columns = (bounds.maxWidth / 82).floor().clamp(
                          3,
                          7,
                        );
                        return Scrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          child: GridView.builder(
                            key: const ValueKey('profile-avatar-grid'),
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 9,
                                  mainAxisSpacing: 9,
                                ),
                            itemCount: playerAvatarAssets.length,
                            itemBuilder: (context, index) {
                              final selected =
                                  index ==
                                  (widget.selectedIndex ??
                                      playerProgress.playerAvatarIndex);
                              return Semantics(
                                label: _names[index],
                                selected: selected,
                                button: true,
                                child: InkWell(
                                  key: ValueKey('profile-avatar-$index'),
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.pop(context, index);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? _gold.withValues(alpha: .18)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? _gold
                                            : Colors.white12,
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

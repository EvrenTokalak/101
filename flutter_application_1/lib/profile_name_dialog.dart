import 'dart:math';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';

/// Returns a name draft. The profile's Save button commits it with the avatar.
class ProfileNameDialog extends StatefulWidget {
  final String initialName;

  const ProfileNameDialog({super.key, required this.initialName});

  @override
  State<ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<ProfileNameDialog> {
  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE7C465), width: 2),
  );
  late final _controller = TextEditingController(text: widget.initialName);
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 18) {
      setState(
        () => _errorText = appText(
          'İsim 1-18 karakter arasında olmalı.',
          'Use a name with 1-18 characters.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedPadding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: LayoutBuilder(
        builder: (context, bounds) {
          // Bound both dimensions together so the frame never stretches across
          // the screen when a landscape keyboard leaves little height.
          final width = max(
            0.0,
            min(420.0, min(bounds.maxWidth, bounds.maxHeight * 2.2)),
          );
          return Center(
            child: Material(
              color: Colors.transparent,
              child: TextSelectionTheme(
                data: const TextSelectionThemeData(
                  cursorColor: Color(0xFF173F31),
                  selectionColor: Color(0x66559368),
                  selectionHandleColor: Color(0xFF397765),
                ),
                child: AppGenericPanel(
                  key: const ValueKey('profile-name-dialog'),
                  width: width,
                  height: width / 2.2,
                  title: Text(appText('OYUNCU ADI', 'PLAYER NAME')),
                  onClose: () => Navigator.of(context).pop(),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            key: const ValueKey('profile-name-field'),
                            controller: _controller,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLength: 18,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            scrollPadding: const EdgeInsets.all(8),
                            onSubmitted: (_) => _confirm(),
                            onChanged: (value) => setState(() {
                              _errorText = value.characters.length >= 18
                                  ? appText(
                                      '18 karakter sınırına ulaştın.',
                                      '18-character limit reached.',
                                    )
                                  : null;
                            }),
                            style: const TextStyle(
                              fontFamily: 'Baloo 2',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: Color(0xFF173F31),
                            ),
                            decoration: InputDecoration(
                              hintText: appText(
                                'İsmini yaz',
                                'Enter your name',
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFF687467),
                              ),
                              counterText: '',
                              errorText: _errorText,
                              errorMaxLines: 2,
                              errorStyle: const TextStyle(
                                color: Color(0xFFFFE4B4),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFFFF0D5),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: _fieldBorder,
                              enabledBorder: _fieldBorder,
                              focusedBorder: _fieldBorder,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppArtworkButton(
                            key: const ValueKey('profile-name-confirm'),
                            width: min(230.0, width * .78),
                            height: 36,
                            fontSize: 17,
                            label: appText('DEVAM ET', 'CONTINUE'),
                            onPressed: _confirm,
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
    ),
  );
}

import 'panel_artwork_test_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/avatar_picker.dart';
import 'package:flutter_application_1/app_controls.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  preparePanelArtwork();
  for (final size in [
    const Size(1280, 720),
    const Size(568, 320),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('avatar gallery returns a draft without saving at $size', (
      tester,
    ) async {
      int? chosen;
      playerProgress.reset();
      addTearDown(playerProgress.reset);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  chosen = await showDialog<int>(
                    context: context,
                    builder: (_) => const AvatarPickerDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final gallery = tester.getSize(
        find.byKey(const ValueKey('profile-avatar-picker')),
      );
      final profile = appArtworkPanelSize(
        BoxConstraints(maxWidth: size.width - 24, maxHeight: size.height - 24),
      );
      expect(gallery.width, lessThanOrEqualTo(profile.width));
      expect(gallery.height, lessThanOrEqualTo(profile.height));
      expect(
        find.byKey(const ValueKey('profile-avatar-preview')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-avatar-confirm')),
        findsNothing,
      );
      expect(find.text('Kurt'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-avatar-1')));
      await tester.pumpAndSettle();
      expect(chosen, 1);
      expect(playerProgress.playerAvatarIndex, 0);
      expect(find.byKey(const ValueKey('profile-avatar-picker')), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-avatar-23')),
        120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('profile-avatar-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-avatar-23')));
      await tester.pumpAndSettle();
      expect(chosen, 23);
      expect(playerProgress.playerAvatarIndex, 0);
      expect(find.byKey(const ValueKey('profile-avatar-picker')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

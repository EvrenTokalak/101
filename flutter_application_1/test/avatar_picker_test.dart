import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/avatar_picker.dart';
import 'package:flutter_application_1/player_progress.dart';

void main() {
  for (final size in [
    const Size(1280, 720),
    const Size(568, 320),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('avatar gallery previews and confirms selection at $size', (
      tester,
    ) async {
      playerProgress.reset();
      addTearDown(playerProgress.reset);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AvatarPickerDialog(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('profile-avatar-1')));
      await tester.pumpAndSettle();
      expect(playerProgress.playerAvatarIndex, 0);
      expect(find.text('Kurt'), findsOneWidget);
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
      expect(find.text('Yaban domuzu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-avatar-confirm')));
      await tester.pumpAndSettle();
      expect(playerProgress.playerAvatarIndex, 23);
      expect(find.byKey(const ValueKey('profile-avatar-picker')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

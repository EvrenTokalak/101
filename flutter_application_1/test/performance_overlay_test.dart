import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/performance_overlay.dart';

class _StatefulScene extends StatefulWidget {
  const _StatefulScene();
  @override
  State<_StatefulScene> createState() => _StatefulSceneState();
}

class _StatefulSceneState extends State<_StatefulScene> {
  @override
  Widget build(BuildContext context) => const Text('Oyun sahnesi');
}

void main() {
  testWidgets(
    'diagnostics toggle without replacing the scene or leaving timers',
    (tester) async {
      const channel = MethodChannel('okey/performance');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'cpuPercent': 7, 'memoryMb': 32},
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            child: const _StatefulScene(),
            builder: (_, value, child) =>
                AppPerformanceOverlay(enabled: value, child: child!),
          ),
        ),
      );
      final scene = tester.state(find.byType(_StatefulScene));
      expect(find.byKey(const ValueKey('performance-readout')), findsNothing);
      enabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.state(find.byType(_StatefulScene)), same(scene));
      expect(find.textContaining('P95'), findsOneWidget);
      expect(find.textContaining('DEBUG'), findsOneWidget);
      enabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.state(find.byType(_StatefulScene)), same(scene));
      expect(find.byKey(const ValueKey('performance-readout')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

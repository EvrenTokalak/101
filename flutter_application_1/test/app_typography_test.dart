import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app_settings_dialog.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('new 100 percent equals the former 105 percent', () {
    const defaults = AppSettings();
    expect(defaults.fontScale, 1);
    expect(appTextScaler(defaults.fontScale).scale(20), 21);
    expect(appTextScaler(1.05).scale(20), closeTo(22.05, 0.001));
    expect(appTextScaler(0.85).scale(20), closeTo(17.85, 0.001));
    expect(appTextScaler(1.25).scale(20), closeTo(26.25, 0.001));
  });

  testWidgets(
    'application and settings share the new baseline without doubling',
    (tester) async {
      appSettings.value = const AppSettings();
      addTearDown(() => appSettings.value = const AppSettings());
      await tester.pumpWidget(
        const OkeyApp(home: Scaffold(body: Text('Typography baseline'))),
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('Typography baseline')),
        ).scale(20),
        21,
      );
      appSettings.value = const AppSettings(fontScale: 1.2);
      await tester.pump();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('Typography baseline')),
        ).scale(20),
        closeTo(25.2, 0.001),
      );
      await tester.pumpWidget(
        const OkeyApp(home: AppSettingsDialog(initial: AppSettings())),
      );
      expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Ses Efektleri')))
            .scale(20),
        21,
      );
    },
  );
}

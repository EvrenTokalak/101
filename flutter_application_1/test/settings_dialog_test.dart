import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('settings icon opens the animated settings dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const OkeyApp(home: MainMenuScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('main-xp-chip')), findsOneWidget);
    expect(find.textContaining('SV. 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AYARLAR'), findsOneWidget);
    expect(find.text('Ses Efektleri'), findsOneWidget);
    expect(find.text('Yazı Boyutu'), findsOneWidget);
    expect(find.text('Oyun Davetleri'), findsNothing);
    expect(find.text('Bildirimler'), findsNothing);
    expect(find.text('Akıcı Animasyonlar'), findsNothing);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.2);
    await tester.pump();
    await tester.tap(find.text('KAYDET'));
    await tester.pump(const Duration(milliseconds: 300));

    final menuTextContext = tester.element(find.text('HEMEN OYNA'));
    expect(
      MediaQuery.textScalerOf(menuTextContext).scale(10),
      closeTo(12, 0.01),
    );

    await tester.tap(find.byIcon(Icons.mail_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('GELEN KUTUSU'), findsOneWidget);
    expect(find.text('Günlük ödülün hazır'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.text('25.600'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('CÜZDAN'), findsOneWidget);
    expect(find.text('25.600 Altın'), findsOneWidget);
    expect(find.text('Günlük Bonus'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.text('Evren'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('PROFİLİM'), findsOneWidget);
    expect(find.textContaining('Seviye 0'), findsOneWidget);
    expect(find.text('Kazanma Oranı'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.text('ODA SEÇ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Oda Seç'), findsOneWidget);
    expect(find.text('Odaya Gir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

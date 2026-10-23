import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/store_cosmetics.dart';
import 'package:flutter_application_1/player_progress.dart';
import 'package:flutter_application_1/main.dart' as app;

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    await SharedPreferencesAsync().clear();
  });

  test('migration keeps an existing purchased background and concurrent loads agree', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList('store.owned_backgrounds', ['bg25']);
    await prefs.setString('store.selected_background', 'bg25');
    final cosmetics = StoreCosmeticsController();
    await Future.wait([cosmetics.load(), cosmetics.load()]);
    expect(cosmetics.selected(CosmeticKind.background), 'bg25');
    expect(cosmetics.backgroundAsset, 'images/store/backgrounds/bg25.jpg');
    final reopened = StoreCosmeticsController();
    await reopened.load();
    expect(reopened.selected(CosmeticKind.background), 'bg25');
  });

  test('rapid changes preserve ownership and the latest selection in all categories', () async {
    final cosmetics = StoreCosmeticsController();
    await cosmetics.load();
    cosmetics.unlockAndSelect(CosmeticKind.rack, 'rack1');
    cosmetics.unlockAndSelect(CosmeticKind.tile, 'tile2');
    cosmetics.unlockAndSelect(CosmeticKind.background, 'bg26');
    cosmetics.unlockAndSelect(CosmeticKind.rack, 'rack4');
    cosmetics.unlockAndSelect(CosmeticKind.background, 'solid_blue');
    await cosmetics.flush();
    final reopened = StoreCosmeticsController();
    await reopened.load();
    expect(reopened.rackAsset, 'images/store/rack_skins/rack4.jpg');
    expect(reopened.tileAsset, 'images/store/tile_skins/tile2.png');
    expect(
      reopened.fakeOkeyAsset,
      'images/store/fake_okeys/tile2_fake_okey.png',
    );
    expect(reopened.backgroundColor, const Color(0xFF123D5A));
    expect(reopened.backgroundAsset, isEmpty);
    expect(reopened.owns(CosmeticKind.rack, 'rack1'), isTrue);
    expect(reopened.owns(CosmeticKind.background, 'bg26'), isTrue);
  });

  testWidgets(
    'store purchases apply immediately and owned items never charge twice',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('okey/league_reminder'),
            (_) async => false,
          );
      await storeCosmetics.load();
      playerProgress.reset(coins: 100000);
      await tester.pumpWidget(const app.OkeyApp(home: app.MainMenuScreen()));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('main-store-button')));
      await frames(tester);
      Future<void> select(String id) async {
        final action = find.byKey(ValueKey('store-action-$id'));
        final scrollable = find.byType(Scrollable).last;
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.minScrollExtent);
        await frames(tester);
        await tester.scrollUntilVisible(action, 200, scrollable: scrollable);
        await tester.ensureVisible(action);
        await frames(tester);
        await tester.tap(action);
        await frames(tester);
      }

      await select('rack1');
      final afterRack = playerProgress.coins;
      expect(storeCosmetics.rackAsset, 'images/store/rack_skins/rack1.jpg');
      await select('rack0');
      await select('rack1');
      expect(playerProgress.coins, afterRack);
      await tester.tap(find.byKey(const ValueKey('store-tiles-tab')));
      await frames(tester);
      await select('tile1');
      expect(storeCosmetics.tileAsset, 'images/store/tile_skins/tile1.png');
      await tester.tap(find.byKey(const ValueKey('store-backgrounds-tab')));
      await frames(tester);
      await select('bg24');
      expect(
        find.byKey(const ValueKey('images/store/backgrounds/bg24.jpg')),
        findsOneWidget,
      );
      await select('solid_green');
      expect(find.byKey(const ValueKey('solid_green')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await frames(tester);
      expect(find.byKey(const ValueKey('solid_green')), findsOneWidget);
      await storeCosmetics.flush();
      final reopened = StoreCosmeticsController();
      await reopened.load();
      expect(reopened.selected(CosmeticKind.background), 'solid_green');
      expect(reopened.selected(CosmeticKind.rack), 'rack1');
      expect(reopened.selected(CosmeticKind.tile), 'tile1');
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

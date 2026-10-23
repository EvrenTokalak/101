import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/store_screen.dart';
import 'package:flutter_application_1/store_cosmetics.dart';

Future<void> settleStore(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Finder galleryScroll(String category) => find.descendant(
  of: find.byKey(ValueKey('store-$category-list')),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('store cards and controls fit wide and phone screens', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(1280, 720),
      const Size(800, 360),
      const Size(568, 320),
      const Size(390, 844),
      const Size(320, 568),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
          home: const StoreScreen(),
        ),
      );
      await settleStore(tester);
      expect(
        find.byKey(const ValueKey('store-racks-tab')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('store-backgrounds-tab')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('store-scroll-left')), findsNothing);
      expect(
        find.byKey(const ValueKey('store-scroll-right')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('store-action-rack0')).hitTestable(),
        findsOneWidget,
      );
      final frame = tester.getRect(
        find.byKey(const ValueKey('store-gallery-frame')),
      );
      expect(frame.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets(
    'scroll arrows follow the start, middle, end, resize and category',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: StoreScreen()));
      await settleStore(tester);
      final left = find.byKey(const ValueKey('store-scroll-left'));
      final right = find.byKey(const ValueKey('store-scroll-right'));
      expect(left, findsNothing);
      expect(right, findsOneWidget);
      final position = tester
          .state<ScrollableState>(galleryScroll('racks'))
          .position;
      position.jumpTo(position.maxScrollExtent / 2);
      await settleStore(tester);
      expect(left, findsOneWidget);
      expect(right, findsOneWidget);
      await tester.tap(right);
      await settleStore(tester);
      expect(left, findsOneWidget);
      expect(right, findsNothing);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await settleStore(tester);
      expect(left, findsOneWidget);
      expect(right, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('store-backgrounds-tab')));
      await settleStore(tester);
      expect(left, findsNothing);
      expect(right, findsOneWidget);
      expect(
        find.byKey(ValueKey(storeCosmetics.backgroundAsset)),
        findsOneWidget,
      );
      final backgrounds = tester
          .state<ScrollableState>(galleryScroll('backgrounds'))
          .position;
      backgrounds.jumpTo(backgrounds.maxScrollExtent);
      await settleStore(tester);
      expect(left, findsOneWidget);
      expect(right, findsNothing);
      await tester.tap(find.byKey(const ValueKey('store-racks-tab')));
      await settleStore(tester);
      expect(left, findsNothing);
      expect(right, findsOneWidget);
      await tester.tap(right);
      await settleStore(tester);
      await tester.tap(left);
      await settleStore(tester);
      expect(
        tester.state<ScrollableState>(galleryScroll('racks')).position.pixels,
        closeTo(0, .1),
      );
      expect(left, findsNothing);
      expect(right, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_controls.dart';

void main() {
  testWidgets('cold artwork never exposes its text or actions first', (
    tester,
  ) async {
    final decoded = Completer<ImageInfo>();
    final provider = _DeferredArtwork(decoded.future);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppArtworkReady(
          image: provider,
          child: GestureDetector(
            onTap: () => taps++,
            child: const Text('Panel content'),
          ),
        ),
      ),
    );
    final content = find.text('Panel content');
    expect(content.hitTestable(), findsNothing);
    final opacity = find.ancestor(of: content, matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 0);

    final image = await tester.runAsync<ui.Image>(() => createTestImage());
    decoded.complete(ImageInfo(image: image!));
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    await tester.tap(content);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

class _DeferredArtwork extends ImageProvider<_DeferredArtwork> {
  final Future<ImageInfo> decoded;
  const _DeferredArtwork(this.decoded);

  @override
  Future<_DeferredArtwork> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DeferredArtwork key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(decoded);
}

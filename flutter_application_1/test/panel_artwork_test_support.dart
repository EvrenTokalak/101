import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app_controls.dart';
import 'package:flutter_application_1/app_settings_dialog.dart';

/// Widget tests use a fake clock; decode frame assets before entering it.
void preparePanelArtwork() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    for (final provider in [
      appSettingsArtwork,
      appCloseArtwork,
      ...appPopupArtworkProviders.values,
    ]) {
      final ready = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, _) {
          image.dispose();
          if (!ready.isCompleted) ready.complete();
        },
        onError: (Object error, StackTrace? stack) =>
            ready.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        await ready.future;
      } finally {
        stream.removeListener(listener);
      }
    }
  });
}

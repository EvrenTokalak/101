import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/bot_turn_pacing.dart';

void main() {
  test('simple actions are faster than processing and opening', () {
    for (final jitter in [0, 50, 100]) {
      final simple = botTurnThinkingTime(
        openedMeldCount: 0,
        processedTileCount: 0,
        variation: jitter,
      );
      final processing = botTurnThinkingTime(
        openedMeldCount: 0,
        processedTileCount: 1,
        variation: jitter,
      );
      final opening = botTurnThinkingTime(
        openedMeldCount: 2,
        processedTileCount: 0,
        variation: jitter,
      );
      expect(simple, lessThan(processing));
      expect(processing, lessThan(opening));
      expect(simple, greaterThan(const Duration(milliseconds: 320)));
      expect(opening, lessThanOrEqualTo(const Duration(milliseconds: 2200)));
    }
  });
}

/// Visible thinking time, separate from AI difficulty and decision quality.
Duration botTurnThinkingTime({
  required int openedMeldCount,
  required int processedTileCount,
  required int variation,
}) {
  final jitter = variation.clamp(0, 100);
  if (openedMeldCount > 0) {
    return Duration(milliseconds: 1800 + jitter * 4);
  }
  if (processedTileCount > 0) {
    return Duration(milliseconds: 1200 + jitter * 3);
  }
  return Duration(milliseconds: 700 + jitter * 2);
}

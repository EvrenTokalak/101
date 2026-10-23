import 'dart:math' as math;

/// A bounded sampling window; measurements exist only while diagnostics run.
class FramePerformanceMetrics {
  static const maximumSamples = 240;
  final List<int> _costs = [];
  int _buildMicros = 0;
  int _rasterMicros = 0;

  void record({required Duration build, required Duration raster}) {
    if (_costs.length == maximumSamples) _costs.removeAt(0);
    _costs.add(math.max(build.inMicroseconds, raster.inMicroseconds));
    _buildMicros += build.inMicroseconds;
    _rasterMicros += raster.inMicroseconds;
  }

  FramePerformanceSample takeSample({
    required Duration elapsed,
    double refreshRate = 60,
  }) {
    final rate = refreshRate.isFinite && refreshRate > 0 ? refreshRate : 60.0;
    final micros = math.max(1, elapsed.inMicroseconds);
    final sorted = List<int>.of(_costs)..sort();
    final sample = FramePerformanceSample(
      frames: sorted.length,
      fps: sorted.length < 2
          ? null
          : math.min(rate, sorted.length * 1e6 / micros),
      p95Milliseconds: sorted.isEmpty
          ? 0
          : sorted[(sorted.length * .95).ceil() - 1] / 1000,
      slowFramePercent: sorted.isEmpty
          ? 0
          : sorted.where((cost) => cost > 1e6 / rate).length *
                100 /
                sorted.length,
      buildBusyPercent: _buildMicros * 100 / micros,
      rasterBusyPercent: _rasterMicros * 100 / micros,
      budgetMilliseconds: 1000 / rate,
    );
    clear();
    return sample;
  }

  void clear() {
    _costs.clear();
    _buildMicros = 0;
    _rasterMicros = 0;
  }
}

class FramePerformanceSample {
  final int frames;
  final double? fps;
  final double p95Milliseconds, slowFramePercent;
  final double buildBusyPercent, rasterBusyPercent, budgetMilliseconds;
  const FramePerformanceSample({
    required this.frames,
    required this.fps,
    required this.p95Milliseconds,
    required this.slowFramePercent,
    required this.buildBusyPercent,
    required this.rasterBusyPercent,
    required this.budgetMilliseconds,
  });
}

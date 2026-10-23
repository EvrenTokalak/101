import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/frame_performance.dart';

void main() {
  test('percentile and slow frames use the slower pipeline stage', () {
    final metrics = FramePerformanceMetrics();
    for (var i = 0; i < 19; i++) {
      metrics.record(
        build: const Duration(milliseconds: 4),
        raster: const Duration(milliseconds: 12),
      );
    }
    metrics.record(
      build: const Duration(milliseconds: 30),
      raster: const Duration(milliseconds: 5),
    );
    final sample = metrics.takeSample(elapsed: const Duration(seconds: 1));
    expect(sample.fps, 20);
    expect(sample.p95Milliseconds, 12);
    expect(sample.slowFramePercent, 5);
    expect(sample.buildBusyPercent, closeTo(10.6, .001));
    expect(sample.rasterBusyPercent, closeTo(23.3, .001));
    final idle = metrics.takeSample(elapsed: const Duration(seconds: 1));
    expect(idle.fps, isNull);
    expect(idle.frames, 0);
    expect(idle.p95Milliseconds, 0);
  });

  test('120 Hz has its own budget and paused samples do not leak', () {
    final metrics = FramePerformanceMetrics();
    metrics.record(
      build: const Duration(milliseconds: 9),
      raster: Duration.zero,
    );
    final sample = metrics.takeSample(
      elapsed: const Duration(seconds: 1),
      refreshRate: 120,
    );
    expect(sample.budgetMilliseconds, closeTo(8.3333, .001));
    expect(sample.slowFramePercent, 100);
    metrics.record(build: const Duration(seconds: 1), raster: Duration.zero);
    metrics.clear();
    final resumed = metrics.takeSample(elapsed: Duration.zero, refreshRate: 0);
    expect(resumed.frames, 0);
    expect(resumed.buildBusyPercent, 0);
    expect(resumed.budgetMilliseconds, closeTo(16.6667, .001));
  });

  test('a stalled sample consumer cannot grow timing storage indefinitely', () {
    final metrics = FramePerformanceMetrics();
    for (var i = 0; i < 1000; i++) {
      metrics.record(
        build: const Duration(milliseconds: 1),
        raster: Duration.zero,
      );
    }
    expect(
      metrics.takeSample(elapsed: const Duration(seconds: 10)).frames,
      FramePerformanceMetrics.maximumSamples,
    );
  });
}

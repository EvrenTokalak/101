import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;

import 'frame_performance.dart';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const MethodChannel _performanceChannel = MethodChannel('okey/performance');

/// Kapalıyken ölçüm zamanlayıcısı ve ek ekran çizimi oluşturulmaz.
final ValueNotifier<bool> performanceOverlayEnabled = ValueNotifier(false);

/// Requests collection of resources which are no longer used. Aggressive
/// trimming is reserved for route exit and app background transitions.
Future<void> requestMemoryTrim({bool aggressive = false}) async {
  try {
    await _performanceChannel.invokeMethod<void>('trimMemory', {
      'aggressive': aggressive,
    });
  } on PlatformException {
    // Web and unsupported platforms do not expose the native channel.
  } on MissingPluginException {
    // Web and unsupported platforms do not expose the native channel.
  }
}

/// Frame timings use the current display refresh rate; raster load is not a
/// physical GPU utilization measurement.
class AppPerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const AppPerformanceOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<AppPerformanceOverlay> createState() => _AppPerformanceOverlayState();
}

class _AppPerformanceOverlayState extends State<AppPerformanceOverlay>
    with WidgetsBindingObserver {
  late final TimingsCallback _timingsCallback;
  final Stopwatch _sampleClock = Stopwatch()..start();
  Timer? _sampleTimer;
  final ValueNotifier<String> _text = ValueNotifier(
    'FPS -- · P95 -- ms\nUI --% · Raster --%\nRAM --MB',
  );
  final _metrics = FramePerformanceMetrics();
  bool _sampling = false;
  bool _timingsAttached = false;
  bool _publishing = false;
  double _refreshRate = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timingsCallback = _updateMetrics;
    if (widget.enabled) _startSampling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRate = View.of(context).display.refreshRate;
  }

  @override
  void didUpdateWidget(covariant AppPerformanceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (widget.enabled) {
      _startSampling();
    } else {
      _stopSampling();
    }
  }

  void _stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _sampling = false;
    _metrics.clear();
    if (_timingsAttached) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
      _timingsAttached = false;
    }
  }

  void _startSampling() {
    if (!_timingsAttached) {
      SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
      _timingsAttached = true;
    }
    _sampling = true;
    _metrics.clear();
    _sampleTimer?.cancel();
    _sampleClock
      ..reset()
      ..start();
    _sampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_publishMetrics());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_sampleTimer == null || !_sampleTimer!.isActive) _startSampling();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopSampling();
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        unawaited(requestMemoryTrim(aggressive: true));
      case AppLifecycleState.hidden:
        // Tarayıcı odağı kısa süre kaybettiğinde canlı oyun dokularını silmek,
        // dönüşte CanvasKit yüzeyi hazırlanırken alttaki HTML rengini bir kare
        // görünür bırakıyordu. Ölçümü durdur, sahne dokularını koru.
        _stopSampling();
      case AppLifecycleState.inactive:
        // Do not rebuild caches for short interruptions such as system panels.
        break;
    }
  }

  void _updateMetrics(List<FrameTiming> timings) {
    if (!mounted || !_sampling || timings.isEmpty) return;
    for (final timing in timings) {
      _metrics.record(
        build: timing.buildDuration,
        raster: timing.rasterDuration,
      );
    }
  }

  Future<void> _publishMetrics() async {
    if (!mounted || !_sampling || _publishing) return;
    _publishing = true;
    final sample = _metrics.takeSample(
      elapsed: _sampleClock.elapsed,
      refreshRate: _refreshRate,
    );
    _sampleClock.reset();
    double? nativeCpu;
    double? memoryMb;
    try {
      final metrics = await _performanceChannel
          .invokeMapMethod<String, dynamic>('sample');
      nativeCpu = (metrics?['cpuPercent'] as num?)?.toDouble();
      memoryMb = (metrics?['memoryMb'] as num?)?.toDouble();
    } on PlatformException {
      // Web ve desteklenmeyen platformlarda kare süreleri kullanılır.
    } on MissingPluginException {
      // Web ve desteklenmeyen platformlarda kare süreleri kullanılır.
    }

    _publishing = false;
    if (!mounted || !_sampling) return;
    final mode = kDebugMode
        ? 'DEBUG'
        : kProfileMode
        ? 'PROFILE'
        : 'RELEASE';
    final cpu = nativeCpu ?? sample.buildBusyPercent;
    final nextText =
        '$mode · FPS ${sample.fps?.toStringAsFixed(0) ?? '--'} · P95 ${sample.p95Milliseconds.toStringAsFixed(1)} ms\n'
        'Takılma ${sample.slowFramePercent.toStringAsFixed(0)}% · Bütçe ${sample.budgetMilliseconds.toStringAsFixed(1)} ms\n'
        '${nativeCpu == null ? 'UI' : 'CPU'} ${cpu.clamp(0, 100).toStringAsFixed(0)}% · Raster ${sample.rasterBusyPercent.clamp(0, 100).toStringAsFixed(0)}%\n'
        'RAM ${memoryMb?.toStringAsFixed(0) ?? '--'} MB';
    if (nextText != _text.value) _text.value = nextText;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSampling();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: widget.child),
      if (widget.enabled)
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: Container(
                    key: const ValueKey('performance-readout'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _text,
                      builder: (_, value, _) => Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF8EF0A5),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

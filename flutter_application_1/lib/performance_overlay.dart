import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const MethodChannel _performanceChannel = MethodChannel('okey/performance');

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

/// Uygulamanın Flutter kare üretim yükünü 60 FPS kare bütçesine göre gösterir.
class AppPerformanceOverlay extends StatefulWidget {
  final Widget child;

  const AppPerformanceOverlay({super.key, required this.child});

  @override
  State<AppPerformanceOverlay> createState() => _AppPerformanceOverlayState();
}

class _AppPerformanceOverlayState extends State<AppPerformanceOverlay>
    with WidgetsBindingObserver {
  late final TimingsCallback _timingsCallback;
  final Stopwatch _sampleClock = Stopwatch()..start();
  Timer? _sampleTimer;
  final ValueNotifier<String> _text = ValueNotifier(
    'CPU --%\nGPU --%\nRAM --MB',
  );
  int _buildMicros = 0;
  int _rasterMicros = 0;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timingsCallback = _updateMetrics;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    _startSampling();
  }

  void _startSampling() {
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
    switch (state) {
      case AppLifecycleState.resumed:
        if (_sampleTimer == null || !_sampleTimer!.isActive) _startSampling();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _sampleTimer?.cancel();
        _sampleTimer = null;
        _buildMicros = 0;
        _rasterMicros = 0;
        _frameCount = 0;
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        unawaited(requestMemoryTrim(aggressive: true));
      case AppLifecycleState.inactive:
        // Do not rebuild caches for short interruptions such as system panels.
        break;
    }
  }

  void _updateMetrics(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;
    for (final timing in timings) {
      _buildMicros += timing.buildDuration.inMicroseconds;
      _rasterMicros += timing.rasterDuration.inMicroseconds;
      _frameCount++;
    }
  }

  Future<void> _publishMetrics() async {
    if (!mounted) return;
    double? nativeCpu;
    double? memoryMb;
    var refreshRate = 60.0;
    try {
      final metrics = await _performanceChannel
          .invokeMapMethod<String, dynamic>('sample');
      nativeCpu = (metrics?['cpuPercent'] as num?)?.toDouble();
      memoryMb = (metrics?['memoryMb'] as num?)?.toDouble();
      refreshRate =
          (metrics?['refreshRate'] as num?)?.toDouble().clamp(30, 240) ?? 60;
    } on PlatformException {
      // Web ve desteklenmeyen platformlarda kare süreleri kullanılır.
    } on MissingPluginException {
      // Web ve desteklenmeyen platformlarda kare süreleri kullanılır.
    }

    final elapsedMicros = _sampleClock.elapsedMicroseconds <= 0
        ? 1
        : _sampleClock.elapsedMicroseconds;
    // Bir saniyelik gerçek zaman içinde Flutter UI ve raster iş parçacıklarının
    // ne kadar meşgul kaldığını gösterir. Tek bir ağır kareyi %100 gibi
    // göstermediği için cihazın süre içindeki gerçek yüküne daha yakındır.
    final fallbackCpu = _buildMicros / elapsedMicros * 100;
    // GPU satırı fiziksel GPU sensörü değildir. Tamamlanan kare sayısı azaldığında
    // yapay olarak düşmemesi için ortalama raster süresini cihazın kare bütçesine
    // oranlar. Böylece düşük FPS, düşük yük gibi görünmez.
    final frameBudgetMicros = 1000000 / refreshRate;
    final averageRasterMicros = _frameCount == 0
        ? 0.0
        : _rasterMicros / _frameCount;
    final gpuPercent = averageRasterMicros / frameBudgetMicros * 100;
    final cpuPercent = nativeCpu ?? fallbackCpu;
    final nextText =
        'CPU ${cpuPercent.clamp(0, 100).toStringAsFixed(0)}%\n'
        'GPU ${gpuPercent.clamp(0, 100).toStringAsFixed(0)}%\n'
        'RAM ${memoryMb?.toStringAsFixed(0) ?? '--'}MB';
    if (nextText != _text.value) _text.value = nextText;
    _buildMicros = 0;
    _rasterMicros = 0;
    _frameCount = 0;
    _sampleClock.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    _sampleTimer?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: widget.child),
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

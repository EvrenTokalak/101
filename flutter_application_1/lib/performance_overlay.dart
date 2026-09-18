import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Uygulamanın Flutter kare üretim yükünü 60 FPS kare bütçesine göre gösterir.
class AppPerformanceOverlay extends StatefulWidget {
  final Widget child;

  const AppPerformanceOverlay({super.key, required this.child});

  @override
  State<AppPerformanceOverlay> createState() => _AppPerformanceOverlayState();
}

class _AppPerformanceOverlayState extends State<AppPerformanceOverlay> {
  final Stopwatch _updateClock = Stopwatch()..start();
  late final TimingsCallback _timingsCallback;
  String _text = 'CPU --%\nGPU --%';
  int _buildMicros = 0;
  int _rasterMicros = 0;

  @override
  void initState() {
    super.initState();
    _timingsCallback = _updateMetrics;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  void _updateMetrics(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;
    for (final timing in timings) {
      _buildMicros += timing.buildDuration.inMicroseconds;
      _rasterMicros += timing.rasterDuration.inMicroseconds;
    }
    if (_updateClock.elapsedMilliseconds < 500) return;

    final elapsedMicros = _updateClock.elapsedMicroseconds;
    final cpuPercent = (_buildMicros / elapsedMicros * 100).clamp(0, 100);
    final gpuPercent = (_rasterMicros / elapsedMicros * 100).clamp(0, 100);
    final nextText =
        'CPU ${cpuPercent.toStringAsFixed(0)}%\nGPU ${gpuPercent.toStringAsFixed(0)}%';
    if (nextText != _text) setState(() => _text = nextText);
    _buildMicros = 0;
    _rasterMicros = 0;
    _updateClock.reset();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Web compositor yeni yüzeyi hazırlarken şeffaf bir kare üretse bile
      // tarayıcının beyaz zeminini göstermeyen kalıcı uygulama tabanı.
      const ColoredBox(color: Color(0xFF003E2A)),
      widget.child,
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
                  child: Text(
                    _text,
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
    ],
  );
}

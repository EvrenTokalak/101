part of 'game.dart';

/// Oyun sahnesindeki dokunulabilir öğelere ortak, hafif bir basma hissi verir.
class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressScale({required this.child, this.enabled = true});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTapDown: (_) => _setPressed(true),
    onTapUp: (_) => _setPressed(false),
    onTapCancel: () => _setPressed(false),
    child: AnimatedScale(
      scale: _pressed ? 0.93 : 1,
      duration: const Duration(milliseconds: 105),
      curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

/// Masa açılırken tüm sahneyi tek parça halinde yumuşakça yerine getirir.
class _GameSceneEntrance extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const _GameSceneEntrance({required this.child, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Transform.scale(scale: 0.985 + value * 0.015, child: child),
        ),
      ),
    );
  }
}

/// Sırası gelen oyuncuyu sabit bir çerçeve yerine nefes alan vurguyla belirtir.
class _ActiveTurnPulse extends StatefulWidget {
  final Widget child;
  final bool active;

  const _ActiveTurnPulse({required this.child, required this.active});

  @override
  State<_ActiveTurnPulse> createState() => _ActiveTurnPulseState();
}

class _ActiveTurnPulseState extends State<_ActiveTurnPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ActiveTurnPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    widget.active ? _controller.repeat(reverse: true) : _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: widget.active ? 1 + _controller.value * 0.025 : 1,
      child: child,
    ),
  );
}

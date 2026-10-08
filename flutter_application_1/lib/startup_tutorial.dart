import 'dart:math';

import 'package:flutter/material.dart';

import 'app_controls.dart';

class TutorialPromptDialog extends StatelessWidget {
  const TutorialPromptDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('tutorial-question'),
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(22),
    child: Container(
      width: appPopupSize(context, horizontalInset: 44).width,
      height: appPopupSize(context, verticalInset: 44).height,
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF174C35), Color(0xFF071B14)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4A017), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4A017).withValues(alpha: 0.16),
              border: Border.all(color: const Color(0xFFF0CC5A), width: 2),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFFF0CC5A),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ÖĞRETİCİYİ GÖRMEK İSTER MİSİN?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF5EDD6),
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kontrollü bir eğitim elinde taş çekmeyi, dizmeyi, açmayı, işlemeyi ve bitmeyi sen uygulayacaksın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('tutorial-skip-button'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('ŞİMDİLİK GEÇ'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('tutorial-start-button'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF2D1C08),
                    backgroundColor: const Color(0xFFF0CC5A),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'EVET, GÖSTER',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class InGameTutorialOverlay extends StatelessWidget {
  final int step;
  final int? finishSourceSlot;
  final VoidCallback onExit;

  const InGameTutorialOverlay({
    super.key,
    required this.step,
    required this.finishSourceSlot,
    required this.onExit,
  });

  static const _steps = <_VisualTutorialStep>[
    _VisualTutorialStep(
      title: '1. TAŞI SÜRÜKLEYEREK ÇEK',
      description: 'Ortadaki kapalı taşı basılı tut, parmağınla ıstakadaki boş alana sürükle ve bırak.',
      icon: Icons.add_circle_rounded,
      accent: Color(0xFF54A8F5),
      target: _TutorialTarget.deck,
    ),
    _VisualTutorialStep(
      title: '2. SERİYİ ELLE DİZ',
      description: 'Sağda ayrı duran sarı 3 taşını tutup sarı 1-2 taşlarının yanına sürükle. Böylece 1-2-3 serisini tamamla.',
      icon: Icons.view_week_rounded,
      accent: Color(0xFFF0C64E),
      target: _TutorialTarget.rackArrange,
    ),
    _VisualTutorialStep(
      title: '3. ELİNİ AÇ',
      description: 'TOPLAM en az 101 olduğunda SERİ AÇ düğmesine bas.',
      emphasis: 'TOPLAM ≥ 101',
      icon: Icons.grid_view_rounded,
      accent: Color(0xFFD48AF4),
      target: _TutorialTarget.openButtons,
    ),
    _VisualTutorialStep(
      title: '4. İŞLEK TAŞI İŞLE',
      description: 'Yeşil çerçeveli kırmızı 7 taşını basılı tut ve masadaki kırmızı 4-5-6 perinin üzerine sürükleyip bırak.',
      icon: Icons.lightbulb_rounded,
      accent: Color(0xFF55C96A),
      target: _TutorialTarget.processDrag,
    ),
    _VisualTutorialStep(
      title: '5. SON TAŞI AT VE BİT',
      description: 'Kalan sarı 13 taşını basılı tutup ortadaki taş atma yuvasına sürükle ve elini bitir.',
      icon: Icons.flag_rounded,
      accent: Color(0xFFFF8D73),
      target: _TutorialTarget.discardButton,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _steps[step.clamp(0, _steps.length - 1)];
    return Positioned.fill(
      key: const ValueKey('in-game-tutorial-overlay'),
      child: LayoutBuilder(
        builder: (context, box) {
          final (startKey, endKey) = _targetKeys(current.target);
          final cardWidth = min(460.0, box.maxWidth * 0.42);
          final cardLeft = switch (current.target) {
            _TutorialTarget.deck ||
            _TutorialTarget.discardButton => box.maxWidth * 0.015,
            _TutorialTarget.rackArrange ||
            _TutorialTarget.openButtons ||
            _TutorialTarget.processDrag => box.maxWidth * 0.29,
          };
          return Stack(
            children: [
              IgnorePointer(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x33000000)),
                    ),
                    _TutorialFingerGuide(
                      key: ValueKey('tutorial-finger-${current.target.name}'),
                      target: current.target,
                      startKey: startKey,
                      endKey: endKey,
                      overlayContext: context,
                      size: box.biggest,
                      color: current.accent,
                    ),
                    Positioned(
                      top: 6,
                      left: cardLeft,
                      child: _InstructionCard(
                        step: step,
                        totalSteps: _steps.length,
                        data: current,
                        maxWidth: cardWidth,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 10,
                child: TextButton.icon(
                  key: const ValueKey('tutorial-close-button'),
                  onPressed: onExit,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('ÖĞRETİCİDEN ÇIK'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  (Key, Key) _targetKeys(_TutorialTarget target) => switch (target) {
    _TutorialTarget.deck => (
      const ValueKey('grid-deck-slot'),
      const ValueKey('rack-slot-23'),
    ),
    _TutorialTarget.rackArrange => (
      const ValueKey('rack-slot-20'),
      const ValueKey('rack-slot-14'),
    ),
    _TutorialTarget.openButtons => (
      const ValueKey('grid-per-summary'),
      const ValueKey('tutorial-open-button'),
    ),
    _TutorialTarget.processDrag => (
      const ValueKey('rack-slot-22'),
      const ValueKey('run-meld-0'),
    ),
    _TutorialTarget.discardButton => (
      ValueKey('rack-slot-${finishSourceSlot ?? 23}'),
      const ValueKey('center-finish-drop-target'),
    ),
  };
}

class _TutorialFingerGuide extends StatefulWidget {
  final _TutorialTarget target;
  final Key startKey;
  final Key endKey;
  final BuildContext overlayContext;
  final Size size;
  final Color color;

  const _TutorialFingerGuide({
    super.key,
    required this.target,
    required this.startKey,
    required this.endKey,
    required this.overlayContext,
    required this.size,
    required this.color,
  });

  @override
  State<_TutorialFingerGuide> createState() => _TutorialFingerGuideState();
}

class _TutorialFingerGuideState extends State<_TutorialFingerGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Rect? _resolvedStartRect;
  Rect? _resolvedEndRect;
  Offset? _resolvedBegin;
  Offset? _resolvedEnd;
  bool _anchorLookupScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.target == _TutorialTarget.openButtons
            ? 2160
            : 1150,
      ),
    );
    _scheduleAnchorLookup();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _rectForKey(Key key) {
    final overlayBox = widget.overlayContext.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return null;

    Element root = widget.overlayContext as Element;
    widget.overlayContext.visitAncestorElements((ancestor) {
      root = ancestor;
      return true;
    });
    Element? match;
    void search(Element element) {
      if (match != null) return;
      if (element.widget.key == key) {
        match = element;
        return;
      }
      element.visitChildren(search);
    }

    search(root);
    final targetBox = match?.findRenderObject();
    if (targetBox is! RenderBox || !targetBox.hasSize) return null;
    final globalTopLeft = targetBox.localToGlobal(Offset.zero);
    return overlayBox.globalToLocal(globalTopLeft) & targetBox.size;
  }

  void _scheduleAnchorLookup() {
    if (_anchorLookupScheduled) return;
    _anchorLookupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorLookupScheduled = false;
      if (!mounted) return;
      _resolveAnchors();
    });
  }

  void _resolveAnchors() {
    final startRect = _rectForKey(widget.startKey);
    final endRect = _rectForKey(widget.endKey);
    if (startRect == null || endRect == null) {
      _scheduleAnchorLookup();
      return;
    }
    setState(() {
      _resolvedStartRect = startRect;
      _resolvedEndRect = endRect;
      _resolvedBegin = startRect.center;
      _resolvedEnd = endRect.center;
      _controller
        ..value = 0
        ..repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final begin = _resolvedBegin;
    final end = _resolvedEnd;
    if (begin == null || end == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opening = widget.target == _TutorialTarget.openButtons;
        final phase = _controller.value;
        // Pause at the total first, travel to the button, then pause there.
        final progress = Curves.easeInOutCubic.transform(
          opening ? ((phase - 0.32) / 0.34).clamp(0.0, 1.0) : phase,
        );
        final position = Offset.lerp(begin, end, progress)!;
        final pulse = sin(phase * pi);
        final finger = Positioned(
          key: const ValueKey('tutorial-finger'),
          left: position.dx - 8,
          top: position.dy - 8,
          child: SizedBox.square(
            dimension: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.28),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.65),
                        blurRadius: 12 + pulse * 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 5,
                  top: 5,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: 1 + pulse * 0.06,
                    child: Image.asset(
                      'görseller/icon/hand.png',
                      key: const ValueKey('tutorial-hand-image'),
                      width: 64,
                      height: 64,
                      cacheWidth: 128,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!opening) return finger;
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: _resolvedStartRect!.inflate(4),
                child: Container(
                  key: const ValueKey('tutorial-total-highlight'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.color.withValues(
                        alpha: 1 - progress * 0.65,
                      ),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: _resolvedEndRect!.inflate(3),
                child: Container(
                  key: const ValueKey('tutorial-open-highlight'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.color.withValues(alpha: progress),
                      width: 3,
                    ),
                  ),
                ),
              ),
              finger,
            ],
          ),
        );
      },
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final int step;
  final int totalSteps;
  final _VisualTutorialStep data;
  final double maxWidth;

  const _InstructionCard({
    required this.step,
    required this.totalSteps,
    required this.data,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: maxWidth,
    constraints: const BoxConstraints(maxWidth: 720),
    padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0xF20A2119),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: data.accent, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 18)],
    ),
    child: Row(
      children: [
        Icon(data.icon, color: data.accent, size: 29),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  color: data.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (data.emphasis != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: data.accent.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Text(
                    data.emphasis!,
                    style: TextStyle(
                      color: data.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                data.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  height: 1.18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: data.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: data.accent),
          ),
          child: Text(
            '${step + 1}/$totalSteps\nŞİMDİ SEN YAP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

enum HomeFeatureTourAction { openDailyReward, openMissions }

class HomeFeatureTourDialog extends StatelessWidget {
  final bool daily;

  const HomeFeatureTourDialog({super.key, required this.daily});

  @override
  Widget build(BuildContext context) {
    final accent = daily ? const Color(0xFFF0CC5A) : const Color(0xFF55C96A);
    return Material(
      key: const ValueKey('home-feature-tour'),
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final target = daily
                ? Rect.fromLTWH(
                    box.maxWidth * 0.012,
                    box.maxHeight * 0.22,
                    box.maxWidth * 0.105,
                    box.maxHeight * 0.18,
                  )
                : Rect.fromLTWH(
                    box.maxWidth * 0.50,
                    box.maxHeight * 0.26,
                    box.maxWidth * 0.22,
                    box.maxHeight * 0.14,
                  );
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: target,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: accent, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.76),
                            blurRadius: 28,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: daily ? target.right + 8 : target.center.dx - 20,
                  top: daily ? target.center.dy - 20 : target.bottom + 4,
                  child: Transform.rotate(
                    angle: daily ? -1.5708 : 0,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: accent,
                      size: 42,
                    ),
                  ),
                ),
                Align(
                  alignment: daily
                      ? const Alignment(0.18, 0.20)
                      : const Alignment(0, 0.42),
                  child: Container(
                    width: 520,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xF20A2119),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accent, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black87, blurRadius: 26),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          daily
                              ? Icons.card_giftcard_rounded
                              : Icons.task_alt_rounded,
                          color: accent,
                          size: 48,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          daily ? 'GÜNLÜK ÖDÜL' : 'GÖREVLER',
                          style: TextStyle(
                            color: accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          daily
                              ? 'Okla gösterilen hediye düğmesi günlük ödül alanıdır. Şimdi paneli açıp ilk ödülünü birlikte alalım.'
                              : 'Okla gösterilen GÖREVLER düğmesinden günlük hedeflerini ve ilerlemeni takip edebilirsin.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: const ValueKey('home-feature-next'),
                          onPressed: () => Navigator.of(context).pop(
                            daily
                                ? HomeFeatureTourAction.openDailyReward
                                : HomeFeatureTourAction.openMissions,
                          ),
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF2D1C08),
                            backgroundColor: accent,
                          ),
                          icon: Icon(
                            daily
                                ? Icons.open_in_new_rounded
                                : Icons.task_alt_rounded,
                          ),
                          label: Text(
                            daily ? 'PANELİ AÇ' : 'GÖREVLERİ AÇ',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _TutorialTarget {
  deck,
  rackArrange,
  openButtons,
  processDrag,
  discardButton,
}

class _VisualTutorialStep {
  final String title;
  final String description;
  final String? emphasis;
  final IconData icon;
  final Color accent;
  final _TutorialTarget target;

  const _VisualTutorialStep({
    required this.title,
    required this.description,
    this.emphasis,
    required this.icon,
    required this.accent,
    required this.target,
  });
}

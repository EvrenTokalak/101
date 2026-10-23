import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_controls.dart';
import 'store_cosmetics.dart';

/// Common layout for table and game-mode selection, over the home background.
class SelectionPage extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Key? backButtonKey;
  final Key? gridKey;
  final List<Widget> cards;
  final Widget Function(double footerHeight, double pageWidth) actionBuilder;

  const SelectionPage({
    super.key,
    required this.title,
    required this.onBack,
    this.backButtonKey,
    this.gridKey,
    required this.cards,
    required this.actionBuilder,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OkeyColors.tableDark,
    body: Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: StoreBackground(cacheWidth: 1440)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.18),
                radius: 1.08,
                colors: [
                  const Color(0xFF08763E).withValues(alpha: .12),
                  const Color(0xFF001B10).withValues(alpha: .42),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final wide = bounds.maxWidth > bounds.maxHeight * 1.25;
              final inset = (bounds.maxWidth * .028).clamp(12.0, 48.0);
              final gap = (bounds.maxWidth * .008).clamp(6.0, 16.0);
              final headerHeight = (bounds.maxHeight * .14).clamp(52.0, 112.0);
              final footerHeight = (bounds.maxHeight * .12).clamp(50.0, 94.0);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: _SelectionTopBar(
                        title: title,
                        onBack: onBack,
                        backButtonKey: backButtonKey,
                      ),
                    ),
                    Expanded(
                      child: CustomPaint(
                        painter: const _SelectionFramePainter(),
                        child: Padding(
                          padding: EdgeInsets.all(
                            (inset * .65).clamp(10.0, 26.0),
                          ),
                          child: LayoutBuilder(
                            builder: (context, gridBounds) {
                              final columns = wide ? 4 : 2;
                              final rows = (cards.length / columns).ceil();
                              final cardWidth =
                                  (gridBounds.maxWidth - gap * (columns - 1)) /
                                  columns;
                              final cardHeight =
                                  (gridBounds.maxHeight - gap * (rows - 1)) /
                                  rows;
                              return GridView.count(
                                key: gridKey,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: columns,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: gap,
                                childAspectRatio: cardWidth / cardHeight,
                                children: cards,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: footerHeight,
                      child: Center(
                        child: actionBuilder(footerHeight, bounds.maxWidth),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _SelectionTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final Key? backButtonKey;
  const _SelectionTopBar({
    required this.onBack,
    required this.title,
    this.backButtonKey,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppBackButton(
            onTap: onBack,
            size: 44,
            buttonKey: backButtonKey,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: bounds.maxWidth < 500 ? 54 : 190,
            right: bounds.maxWidth < 500 ? 108 : 190,
          ),
          child: Align(
            alignment: bounds.maxWidth < 500
                ? Alignment.centerLeft
                : Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  color: const Color(0xFFFFEC83),
                  fontFamily: 'Baloo 2',
                  fontSize: (bounds.maxWidth * .028).clamp(23.0, 48.0),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: (bounds.maxWidth * .13).clamp(100.0, 220.0),
            height: (bounds.maxHeight * .7).clamp(34.0, 72.0),
            child: const FittedBox(child: AppCoinBalance()),
          ),
        ),
      ],
    ),
  );
}

class _SelectionFramePainter extends CustomPainter {
  const _SelectionFramePainter();
  Path _frame(Rect rect, double corner) => Path()
    ..moveTo(rect.left + corner, rect.top)
    ..lineTo(rect.right - corner, rect.top)
    ..quadraticBezierTo(
      rect.right - corner,
      rect.top + corner,
      rect.right,
      rect.top + corner,
    )
    ..lineTo(rect.right, rect.bottom - corner)
    ..quadraticBezierTo(
      rect.right - corner,
      rect.bottom - corner,
      rect.right - corner,
      rect.bottom,
    )
    ..lineTo(rect.left + corner, rect.bottom)
    ..quadraticBezierTo(
      rect.left + corner,
      rect.bottom - corner,
      rect.left,
      rect.bottom - corner,
    )
    ..lineTo(rect.left, rect.top + corner)
    ..quadraticBezierTo(
      rect.left + corner,
      rect.top + corner,
      rect.left + corner,
      rect.top,
    )
    ..close();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final path = _frame(rect, 16);
    canvas.drawPath(path, Paint()..color = const Color(0xD9001607));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF594000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFFFE554),
    );
    canvas.drawPath(
      _frame(rect.deflate(6), 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFB69427),
    );
  }

  @override
  bool shouldRepaint(_SelectionFramePainter oldDelegate) => false;
}

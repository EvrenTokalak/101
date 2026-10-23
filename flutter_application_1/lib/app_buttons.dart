import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppButtonAssets {
  static const save = 'görseller/kaydet';
  static const neutral = 'görseller/sarı buton';
  static const home = 'görseller/ana sayfa.png';
  static const restart = 'görseller/yeniden başlat.png';
  static const continueGame = 'görseller/devam et.png';
}

abstract final class AppButtonMetrics {
  static const height = 42.0;
  static const resultHeight = 66.0;
  static const gameWidth = 160.0;
  static const menuWidth = 230.0;
  static const gap = 8.0;
}

/// Shared artwork, label fitting and touch feedback for panel actions.
class AppArtworkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool yellow;
  final String? artworkAsset;
  final double? width;
  final double height, fontSize;
  final IconData? icon;
  final bool outlinedText;
  final int maxLines;
  const AppArtworkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.yellow = false,
    this.artworkAsset,
    this.width = 150,
    this.height = AppButtonMetrics.height,
    this.fontSize = 16,
    this.icon,
    this.outlinedText = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final color = yellow
        ? const Color(0xFF18120B)
        : outlinedText
        ? Colors.white
        : const Color(0xFFFFF2D0);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AppButtonArtwork(
              asset:
                  artworkAsset ??
                  (yellow ? AppButtonAssets.neutral : AppButtonAssets.save),
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: math.min(23, fontSize + 1), color: color),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: AppButtonLabel(
                    label: label,
                    fontSize: fontSize,
                    color: color,
                    outlined: outlinedText,
                    maxLines: maxLines,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fit localized labels with bounded work, including large accessibility text.
class AppButtonLabel extends StatelessWidget {
  final String label;
  final double fontSize;
  final Color color;
  final bool outlined;
  final int maxLines;
  const AppButtonLabel({
    super.key,
    required this.label,
    required this.fontSize,
    required this.color,
    this.outlined = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final style = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: outlined ? 'Baloo 2' : null,
          height: 1.1,
        ),
      );
      bool fits(double font) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: style.copyWith(fontSize: font),
          ),
          maxLines: maxLines,
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: math.max(1, bounds.maxWidth - 3));
        final result =
            !painter.didExceedMaxLines &&
            painter.height <= bounds.maxHeight - 3;
        painter.dispose();
        return result;
      }

      var font = fontSize;
      if (!fits(font)) {
        var low = math.min(8.0, fontSize), high = fontSize;
        for (var i = 0; i < 8; i++) {
          final middle = (low + high) / 2;
          if (fits(middle)) {
            low = middle;
          } else {
            high = middle;
          }
        }
        font = low;
      }
      final fill = style.copyWith(fontSize: font);
      return Padding(
        padding: const EdgeInsets.all(1.5),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.max(1, bounds.maxWidth - 3),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (outlined)
                  ExcludeSemantics(
                    child: RichText(
                      maxLines: maxLines,
                      textAlign: TextAlign.center,
                      textScaler: scaler,
                      text: TextSpan(
                        text: label,
                        style: fill.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2.4
                            ..strokeJoin = StrokeJoin.round
                            ..color = Colors.black,
                        ),
                      ),
                    ),
                  ),
                Text(
                  label,
                  maxLines: maxLines,
                  textAlign: TextAlign.center,
                  style: fill,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AppButtonArtwork extends StatelessWidget {
  final String asset;
  const AppButtonArtwork({super.key, required this.asset});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, bounds) {
        const crop = Rect.fromLTRB(.055, .15, .95, .80);
        return Stack(
          children: [
            Positioned(
              left: -crop.left * bounds.maxWidth / crop.width,
              top: -crop.top * bounds.maxHeight / crop.height,
              width: bounds.maxWidth / crop.width,
              height: bounds.maxHeight / crop.height,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
                // These controls are at most 230 logical pixels wide. Keep
                // enough detail for 2x displays without decoding 1K textures.
                cacheWidth: 512,
              ),
            ),
          ],
        );
      },
    ),
  );
}

import 'package:flutter/material.dart';

/// Sayfa başlıklarında kullanılan ortak geri düğmesi.
class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final Key? buttonKey;
  final double size;

  const AppBackButton({
    super.key,
    required this.onTap,
    this.buttonKey,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Geri',
    child: GestureDetector(
      key: buttonKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: size + 2,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF061D12).withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD76A), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 7,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: const Color(0xFFFFF4E8),
              size: size * 0.54,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Popup başlıklarında kullanılan ortak kırmızı-altın kapatma düğmesi.
class AppCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Key? buttonKey;

  const AppCloseButton({
    super.key,
    required this.onTap,
    this.size = 40,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Kapat',
    child: GestureDetector(
      key: buttonKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: size + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'images/ui/settings_close.png',
              width: size,
              height: size,
              cacheWidth: 80,
              cacheHeight: 80,
              filterQuality: FilterQuality.medium,
            ),
            // Mevcut klavye/otomasyon hedefini korurken ekranda yalnız ortak
            // kırmızı-altın görsel görünür.
            const Opacity(opacity: 0.001, child: Icon(Icons.close_rounded)),
          ],
        ),
      ),
    ),
  );
}

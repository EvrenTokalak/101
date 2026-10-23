import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'player_progress.dart';

export 'app_buttons.dart';

/// Keeps the hit area still while the button artwork presses inward.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = .96,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 75),
    reverseDuration: const Duration(milliseconds: 140),
  );

  void _activate() {
    // Quick taps also show the pressed frame without delaying navigation.
    _press.value = 1;
    _press.reverse();
    widget.onTap();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _press.forward(),
    onTapCancel: () => _press.reverse(),
    onTap: _activate,
    child: AnimatedBuilder(
      animation: _press,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale:
            1 -
            (1 - widget.pressedScale) *
                Curves.easeOutQuad.transform(_press.value),
        child: child,
      ),
    ),
  );
}

/// Shared wallet dimensions follow the store header.
class AppCoinBalance extends StatelessWidget {
  const AppCoinBalance({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playerProgress,
    builder: (context, _) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4A017)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'images/ui/coin.png',
            width: 19,
            height: 19,
            cacheWidth: 38,
            cacheHeight: 38,
            filterQuality: FilterQuality.low,
          ),
          const SizedBox(width: 6),
          Text(
            formatGameNumber(playerProgress.coins),
            style: const TextStyle(
              color: Color(0xFFF5EDD6),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

const double appPopupWidth = 620;
const double appPopupHeight = 540;
const double appPopupBodyFontSize = 15;
const double appPopupButtonHeight = 48;
const double appPopupContentInset = 18;
const double appPopupGap = 8;
const double appArtworkCloseSpace = 52;
const appHelpPanelAsset = 'images/ui/panels/nasil-oynanir.png';
const appTutorialPanelAsset = 'images/ui/panels/ogretici.png';
const appGameEndPanelAsset = 'images/ui/panels/tur-bitti.png';
const appGenericPanelAsset = 'images/ui/panels/bos-panel.png';
const appHomeActionArtwork = ResizeImage(
  AssetImage('images/ui/home/action_button.png'),
  width: 1024,
);
const appHomePlayArtwork = ResizeImage(
  AssetImage('images/ui/home/play_button.png'),
  width: 1024,
);

/// Trim transparent source margins at display time; keep original PNGs intact.
class AppHomeButtonArtwork extends StatelessWidget {
  final bool play;
  const AppHomeButtonArtwork({super.key, this.play = false});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final crop = play
            ? const Rect.fromLTRB(.05, .20, .95, .79)
            : const Rect.fromLTRB(.05, .16, .95, .84);
        return Stack(
          children: [
            Positioned(
              left: -crop.left * bounds.maxWidth / crop.width,
              top: -crop.top * bounds.maxHeight / crop.height,
              width: bounds.maxWidth / crop.width,
              height: bounds.maxHeight / crop.height,
              child: Image(
                image: play ? appHomePlayArtwork : appHomeActionArtwork,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// All seven supplied frames share the original 1536:1024 aspect ratio.
Size appArtworkPanelSize(BoxConstraints bounds) {
  final width = min(
    appPopupWidth,
    min(bounds.maxWidth, bounds.maxHeight * 1.5),
  );
  return Size(max(0, width), max(0, width / 1.5));
}

// Warm-up and visible panels must share image-cache keys. Cap HD frames at
// twice their displayed width rather than decoding the full source bitmap.
const appPopupArtworkProviders = <String, ImageProvider>{
  appGenericPanelAsset: ResizeImage(
    AssetImage(appGenericPanelAsset),
    width: 1280,
  ),
  appGameEndPanelAsset: ResizeImage(
    AssetImage(appGameEndPanelAsset),
    width: 1280,
  ),
  appHelpPanelAsset: ResizeImage(AssetImage(appHelpPanelAsset), width: 1280),
  appTutorialPanelAsset: ResizeImage(
    AssetImage(appTutorialPanelAsset),
    width: 1280,
  ),
  'images/ui/panels/profilim.png': ResizeImage(
    AssetImage('images/ui/panels/profilim.png'),
    width: 1280,
  ),
  'images/ui/panels/gorevler.png': ResizeImage(
    AssetImage('images/ui/panels/gorevler.png'),
    width: 1280,
  ),
  'images/ui/panels/gelen-kutusu.png': ResizeImage(
    AssetImage('images/ui/panels/gelen-kutusu.png'),
    width: 1280,
  ),
  'images/ui/panels/gunluk-odul.png': ResizeImage(
    AssetImage('images/ui/panels/gunluk-odul.png'),
    width: 1280,
  ),
};

ImageProvider appPopupArtwork(String asset) =>
    appPopupArtworkProviders[asset] ?? AssetImage(asset);

const appCloseArtwork = ResizeImage(
  AssetImage('images/ui/settings_close.png'),
  width: 120,
  height: 120,
);

/// Reveal the frame and its contents together, including on a cold image cache.
class AppArtworkReady extends StatefulWidget {
  final ImageProvider image;
  final Widget child;
  const AppArtworkReady({super.key, required this.image, required this.child});

  @override
  State<AppArtworkReady> createState() => _AppArtworkReadyState();
}

class _AppArtworkReadyState extends State<AppArtworkReady> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AppArtworkReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _ready = false;
    _stream = stream;
    _listener = ImageStreamListener(
      (image, synchronous) {
        image.dispose();
        if (!mounted || _ready) return;
        if (synchronous) {
          _ready = true;
        } else {
          setState(() => _ready = true);
        }
      },
      // Let the panel's existing fallback handle a missing asset.
      onError: (_, _) {
        if (mounted && !_ready) setState(() => _ready = true);
      },
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_ready,
    child: ExcludeSemantics(
      excluding: !_ready,
      child: Opacity(opacity: _ready ? 1 : 0, child: widget.child),
    ),
  );
}

// Coordinates belong to the supplied 1536 x 1024 artwork, rather than to
// surrounding dialog padding. The wood plaques differ between the seven files.
Rect appPanelTitleRect(String asset, Size size) {
  final bounds = switch (asset.split('/').last) {
    'ayarlar.png' => const Rect.fromLTRB(.27, .084, .64, .165),
    'gelen-kutusu.png' => const Rect.fromLTRB(.31, .12, .69, .195),
    'gunluk-odul.png' => const Rect.fromLTRB(
      .31,
      (.153 - .10) / .82,
      .69,
      (.226 - .10) / .82,
    ),
    'ogretici.png' => const Rect.fromLTRB(.30, .116, .69, .19),
    'nasil-oynanir.png' => const Rect.fromLTRB(.29, .087, .66, .17),
    _ => const Rect.fromLTRB(.30, .086, .69, .17),
  };
  return Rect.fromLTRB(
    bounds.left * size.width,
    bounds.top * size.height,
    bounds.right * size.width,
    bounds.bottom * size.height,
  );
}

Rect appPanelCloseRect(String asset, Size size) {
  const extent = 46.0;
  final daily = asset == 'images/ui/panels/gunluk-odul.png';
  final profile = asset == 'images/ui/panels/profilim.png';
  final rimY = switch (asset.split('/').last) {
    'gelen-kutusu.png' => .225,
    'gunluk-odul.png' => (.255 - .10) / .82 + .018,
    'ogretici.png' => .24,
    'profilim.png' => .17,
    _ => .205,
  };
  final center = Offset(
    (size.width * (daily || profile ? .935 : .958)).clamp(
      extent / 2,
      max(extent / 2, size.width - extent / 2 - 2),
    ),
    (size.height * rimY).clamp(
      extent / 2,
      max(extent / 2, size.height - extent / 2),
    ),
  );
  return Rect.fromCenter(center: center, width: extent, height: extent);
}

class AppArtworkTitle extends StatelessWidget {
  final String asset;
  final Widget child;
  const AppArtworkTitle({super.key, required this.asset, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          Positioned.fromRect(
            rect: appPanelTitleRect(asset, bounds.biggest),
            child: ClipRect(
              key: const ValueKey('panel-title-region'),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Color(0xFFFFEFBD),
                      fontFamily: 'Baloo 2',
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0xFF542808),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AppArtworkClose extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final Key? buttonKey;
  const AppArtworkClose({
    super.key,
    required this.asset,
    required this.onTap,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      children: [
        Positioned.fromRect(
          rect: appPanelCloseRect(asset, bounds.biggest),
          child: AppCloseButton(
            onTap: onTap,
            buttonKey: buttonKey,
            size:
                asset == 'images/ui/panels/gunluk-odul.png' ||
                    asset == 'images/ui/panels/profilim.png'
                ? 32
                : 40,
          ),
        ),
      ],
    ),
  );
}

/// Profil panelinin zümrüt yüzeyi, altın çerçevesi ve yumuşak ışık yansıması.
class AppPopupSurface extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double frameWidth;
  final String? artworkAsset;
  final VoidCallback? onOutsideClose;
  final bool closeOnFrame;
  final Widget? artworkTitle;

  const AppPopupSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.constraints,
    this.padding,
    this.margin,
    this.frameWidth = 3,
    this.artworkAsset,
    this.onOutsideClose,
    this.closeOnFrame = false,
    this.artworkTitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    constraints: constraints,
    margin: margin,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: artworkAsset == null
          ? const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ]
          : null,
    ),
    child: artworkAsset != null
        ? AppArtworkReady(
            image: appPopupArtwork(artworkAsset!),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  top: onOutsideClose == null || closeOnFrame
                      ? 0
                      : appArtworkCloseSpace,
                  child: RepaintBoundary(
                    child: _PanelArtwork(asset: artworkAsset!),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: onOutsideClose == null || closeOnFrame
                        ? 0
                        : appArtworkCloseSpace,
                  ),
                  child: Padding(
                    padding: padding ?? EdgeInsets.zero,
                    child: KeyedSubtree(
                      key: const ValueKey('artwork-panel-content'),
                      child: child,
                    ),
                  ),
                ),
                if (artworkTitle != null)
                  Positioned.fill(
                    child: AppArtworkTitle(
                      asset: artworkAsset!,
                      child: artworkTitle!,
                    ),
                  ),
                if (onOutsideClose != null && closeOnFrame)
                  Positioned.fill(
                    child: AppArtworkClose(
                      asset: artworkAsset!,
                      buttonKey: const ValueKey('popup-outside-close'),
                      onTap: onOutsideClose!,
                    ),
                  ),
                if (onOutsideClose != null && !closeOnFrame)
                  Positioned(
                    top: closeOnFrame ? 8 : 0,
                    right: closeOnFrame ? 10 : 0,
                    child: AppCloseButton(
                      buttonKey: const ValueKey('popup-outside-close'),
                      onTap: onOutsideClose!,
                    ),
                  ),
              ],
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(
              foregroundPainter: _PopupLightPainter(frameWidth),
              child: Container(
                padding: EdgeInsets.all(frameWidth),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B5140), Color(0xFF032B20)],
                  ),
                ),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
            ),
          ),
  );
}

class _PanelArtwork extends StatelessWidget {
  final String asset;
  const _PanelArtwork({required this.asset});

  @override
  Widget build(BuildContext context) {
    final image = Image(
      key: const ValueKey('popup-panel-artwork'),
      image: appPopupArtwork(asset),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
    final daily = asset == 'images/ui/panels/gunluk-odul.png';
    if (asset != appGenericPanelAsset && !daily) return image;
    // Use the daily artwork's transparent margins to extend the visible frame
    // vertically inside the screen, keeping the source PNG unchanged.
    final cropTop = daily ? .10 : .16;
    final cropHeight = daily ? .82 : .64;
    return LayoutBuilder(
      builder: (_, bounds) => ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -bounds.maxHeight * cropTop / cropHeight,
              height: bounds.maxHeight / cropHeight,
              child: image,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared frame for dialogs that do not have dedicated artwork.
class AppGenericPanel extends StatelessWidget {
  final Widget title;
  final Widget child;
  final double width;
  final double height;
  final VoidCallback? onClose;
  final bool scrollable;

  const AppGenericPanel({
    super.key,
    required this.title,
    required this.child,
    this.width = 520,
    this.height = 340,
    this.onClose,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final screen = MediaQuery.sizeOf(context);
      final panelWidth = min(
        width,
        min(bounds.maxWidth, max(0.0, screen.width - 24)),
      );
      final panelHeight = min(
        height,
        min(bounds.maxHeight, max(0.0, screen.height - 24)),
      );
      return AppPopupSurface(
        width: panelWidth,
        height: panelHeight,
        artworkAsset: appGenericPanelAsset,
        artworkTitle: title,
        closeOnFrame: true,
        onOutsideClose: onClose,
        padding: EdgeInsets.fromLTRB(
          panelWidth * .055,
          panelHeight * .22,
          panelWidth * .055,
          panelHeight * .08,
        ),
        child: ClipRect(
          child: scrollable ? AppPanelScrollView(child: child) : child,
        ),
      );
    },
  );
}

/// Touch, wheel, trackpad and mouse dragging use the same bounded viewport.
class AppPanelScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showScrollbar;
  final bool showScrollHint;
  const AppPanelScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.showScrollbar = true,
    this.showScrollHint = false,
  });

  @override
  State<AppPanelScrollView> createState() => _AppPanelScrollViewState();
}

class _AppPanelScrollViewState extends State<AppPanelScrollView> {
  final _controller = ScrollController();
  bool _canScrollDown = false;
  bool _hintUpdatePending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleHintUpdate);
    _scheduleHintUpdate();
  }

  void _scheduleHintUpdate() {
    if (!widget.showScrollHint || _hintUpdatePending) return;
    _hintUpdatePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hintUpdatePending = false;
      if (!mounted) return;
      final canScroll =
          _controller.hasClients &&
          _controller.position.hasContentDimensions &&
          _controller.position.extentAfter > 1;
      if (canScroll != _canScrollDown) {
        setState(() => _canScrollDown = canScroll);
      }
    });
  }

  void _scrollDown() {
    final position = _controller.position;
    _controller.animateTo(
      (position.pixels + position.viewportDimension * .65).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(
      dragDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      },
      scrollbars: false,
    ),
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleHintUpdate();
        return false;
      },
      child: widget.showScrollHint
          ? Stack(
              children: [
                Positioned.fill(child: _scrollbarView()),
                if (widget.showScrollHint && _canScrollDown)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Tooltip(
                        message: 'Diğer görevleri göster',
                        child: Material(
                          color: const Color(0xFF0B4935),
                          shape: const StadiumBorder(
                            side: BorderSide(color: Color(0xFFD9BC6A)),
                          ),
                          child: InkWell(
                            key: const ValueKey('panel-scroll-hint'),
                            customBorder: const StadiumBorder(),
                            onTap: _scrollDown,
                            child: const SizedBox(
                              width: 46,
                              height: 24,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFFFFE395),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : _scrollbarView(),
    ),
  );

  Widget _scrollbarView() => widget.showScrollbar
      ? Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          interactive: true,
          child: _scrollView(),
        )
      : _scrollView();

  Widget _scrollView() => SingleChildScrollView(
    controller: _controller,
    primary: false,
    physics: const ClampingScrollPhysics(),
    padding: widget.padding.add(
      EdgeInsets.only(bottom: widget.showScrollHint ? 18 : 0),
    ),
    child: widget.child,
  );
}

class _PopupLightPainter extends CustomPainter {
  final double frameWidth;
  const _PopupLightPainter(this.frameWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.save();
    canvas.clipRRect(outer);
    // A broad reflection follows the same upper-left light as the profile rim.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.85, -1),
          radius: 1.25,
          colors: [Color(0x1FFFFFFF), Color(0x06FFF4CE), Colors.transparent],
          stops: [0, .45, 1],
        ).createShader(rect),
    );
    final inner = RRect.fromRectAndRadius(
      rect.deflate(frameWidth + .5),
      Radius.circular(24 - frameWidth),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF41856D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(frameWidth / 2),
        Radius.circular(24 - frameWidth / 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = frameWidth
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEBA2), Color(0xFFC39132), Color(0xFFE7BD59)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PopupLightPainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth;
}

/// Uygulamadaki ana pop-up'ların profil penceresiyle aynı ölçüde kalmasını
/// sağlar; dar ekranlarda güvenli boşlukları koruyarak küçülür.
Size appPopupSize(
  BuildContext context, {
  double horizontalInset = 24,
  double verticalInset = 24,
}) {
  final screen = MediaQuery.sizeOf(context);
  return Size(
    min(appPopupWidth, max(0, screen.width - horizontalInset)),
    min(appPopupHeight, max(0, screen.height - verticalInset)),
  );
}

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

/// Keeps popup titles at the panel center, independent of the side controls.
class AppPopupHeader extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback onClose;
  final bool showClose;

  const AppPopupHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.subtitle,
    this.leading,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [title, ?subtitle],
              ),
            ),
          ),
        ),
        if (leading != null)
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: 46,
              child: Center(child: leading),
            ),
          ),
        if (showClose)
          Align(
            alignment: Alignment.centerRight,
            child: AppCloseButton(onTap: onClose),
          ),
      ],
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
            Image(
              image: appCloseArtwork,
              width: size,
              height: size,
              filterQuality: FilterQuality.high,
              frameBuilder: (_, child, frame, synchronous) =>
                  synchronous || frame != null ? child : _fallback(),
              errorBuilder: (_, _, _) => _fallback(),
            ),
            // Mevcut klavye/otomasyon hedefini korurken ekranda yalnız ortak
            // kırmızı-altın görsel görünür.
            const Opacity(opacity: 0.001, child: Icon(Icons.close_rounded)),
          ],
        ),
      ),
    ),
  );

  Widget _fallback() => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF9F2525),
      border: Border.all(color: const Color(0xFFF0CC5A), width: 2),
    ),
    child: Icon(Icons.close, color: const Color(0xFFFFEFBD), size: size * .6),
  );
}

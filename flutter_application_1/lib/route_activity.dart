import 'package:flutter/material.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Üstüne başka bir tam sayfa açıldığında sahnenin widget ağacını pasife alır.
/// Popup ve dialog rotaları bu gözlemciye dahil değildir.
class ActiveRouteScene extends StatefulWidget {
  final Widget child;

  const ActiveRouteScene({super.key, required this.child});

  @override
  State<ActiveRouteScene> createState() => _ActiveRouteSceneState();
}

class _ActiveRouteSceneState extends State<ActiveRouteScene> with RouteAware {
  PageRoute<dynamic>? _route;
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic> || identical(route, _route)) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (_active) setState(() => _active = false);
  }

  @override
  void didPopNext() {
    if (!_active) setState(() => _active = true);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: _active,
    // Sayfa geçişi başlar başlamaz çocuğu ağaçtan çıkarmak, yeni rota ilk
    // karesini hazırlarken pencerenin beyaz yüzeyini kısa süre görünür
    // bırakıyordu. Navigator kapalı rotayı zaten offstage tutar; burada
    // yalnız ticker'ları durdurmak hem kaynak kullanımını keser hem son hazır
    // karenin geçiş boyunca korunmasını sağlar.
    child: RepaintBoundary(child: widget.child),
  );
}

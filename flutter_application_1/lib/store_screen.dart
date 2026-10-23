import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_controls.dart';
import 'performance_overlay.dart';
import 'player_progress.dart';
import 'store_cosmetics.dart';

class _StoreItem {
  final String id;
  final String name;
  final String subtitle;
  final String asset;
  final Color? color;
  final int price;

  const _StoreItem({
    required this.id,
    required this.name,
    required this.subtitle,
    this.asset = '',
    this.color,
    required this.price,
  });
}

const _storeRacks = [
  _StoreItem(
    id: 'rack0',
    name: 'KLASİK AHŞAP',
    subtitle: 'Sıcak ceviz dokusu',
    asset: 'images/store/racks/rack0.png',
    price: 0,
  ),
  _StoreItem(
    id: 'rack1',
    name: 'KOYU CEVİZ',
    subtitle: 'Koyu ve sade görünüm',
    asset: 'images/store/racks/rack1.png',
    price: 2500,
  ),
  _StoreItem(
    id: 'rack2',
    name: 'BAL RENGİ',
    subtitle: 'Parlak ahşap yüzey',
    asset: 'images/store/racks/rack2.png',
    price: 3500,
  ),
  _StoreItem(
    id: 'rack3',
    name: 'GECE SİYAHI',
    subtitle: 'Koyu ve zarif görünüm',
    asset: 'images/store/racks/rack3.png',
    price: 5000,
  ),
  _StoreItem(
    id: 'rack4',
    name: 'USTA SERİSİ',
    subtitle: 'Özel masa koleksiyonu',
    asset: 'images/store/racks/rack4.png',
    price: 7500,
  ),
];

const _storeTiles = [
  _StoreItem(
    id: 'tile0',
    name: 'KLASİK TAŞ',
    subtitle: 'Geleneksel 101 görünümü',
    asset: 'images/store/tiles/tile0.png',
    price: 0,
  ),
  _StoreItem(
    id: 'tile1',
    name: 'YUMUŞAK KÖŞE',
    subtitle: 'Pastel ve yuvarlak hatlar',
    asset: 'images/store/tiles/tile1.png',
    price: 2000,
  ),
  _StoreItem(
    id: 'tile2',
    name: 'MODERN',
    subtitle: 'Net sayı ve güçlü renk',
    asset: 'images/store/tiles/tile2.png',
    price: 3000,
  ),
  _StoreItem(
    id: 'tile3',
    name: 'GECE TAŞI',
    subtitle: 'Koyu masa için özel set',
    asset: 'images/store/tiles/tile3.png',
    price: 4500,
  ),
  _StoreItem(
    id: 'tile4',
    name: 'ALTIN SERİ',
    subtitle: 'Premium turnuva seti',
    asset: 'images/store/tiles/tile4.png',
    price: 6500,
  ),
];

const _storeBackgrounds = [
  _StoreItem(
    id: 'bg_menu',
    name: 'ANA MENÜ',
    subtitle: 'Ana sayfanın özel masa deseni',
    asset: 'images/anamenu/menubg.png',
    price: 4500,
  ),
  _StoreItem(
    id: 'bg24',
    name: 'GECE MAVİSİ',
    subtitle: 'Sakin ve koyu masa',
    asset: 'images/store/backgrounds/bg24.jpg',
    price: 0,
  ),
  _StoreItem(
    id: 'bg25',
    name: 'KIZIL SALON',
    subtitle: 'Kırmızı sinek deseni',
    asset: 'images/store/backgrounds/bg25.jpg',
    price: 1800,
  ),
  _StoreItem(
    id: 'bg26',
    name: 'ZÜMRÜT',
    subtitle: 'Yeşil sinek deseni',
    asset: 'images/store/backgrounds/bg26.jpg',
    price: 2400,
  ),
  _StoreItem(
    id: 'bg27',
    name: 'TURKUAZ',
    subtitle: 'Turkuaz sinek deseni',
    asset: 'images/store/backgrounds/bg27.jpg',
    price: 3200,
  ),
  _StoreItem(
    id: 'bg28',
    name: 'KEHRİBAR',
    subtitle: 'Sıcak kehribar sinek deseni',
    asset: 'images/store/backgrounds/bg28.jpg',
    price: 4000,
  ),
  _StoreItem(
    id: 'bg29',
    name: 'MOR SALON',
    subtitle: 'Mor sinek deseni',
    asset: 'images/store/backgrounds/bg29.jpg',
    price: 5200,
  ),
  _StoreItem(
    id: 'bg30',
    name: 'ZEYTİN ALTINI',
    subtitle: 'Altın yeşili sinek deseni',
    asset: 'images/store/backgrounds/bg30.jpg',
    price: 7000,
  ),
  _StoreItem(
    id: 'solid_green',
    name: 'DÜZ YEŞİL',
    subtitle: 'Sade koyu yeşil masa',
    color: Color(0xFF075733),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_blue',
    name: 'DÜZ LACİVERT',
    subtitle: 'Sade lacivert masa',
    color: Color(0xFF123D5A),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_burgundy',
    name: 'DÜZ BORDO',
    subtitle: 'Sade bordo masa',
    color: Color(0xFF54252B),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_black',
    name: 'DÜZ SİYAH',
    subtitle: 'Sade antrasit masa',
    color: Color(0xFF151917),
    price: 1200,
  ),
];

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _selectedTab = 0;

  List<_StoreItem> _itemsForTab(int index) => switch (index) {
    0 => _storeRacks,
    1 => _storeTiles,
    _ => _storeBackgrounds,
  };

  void _evictPreviews(Iterable<_StoreItem> items) {
    PaintingBinding.instance.imageCache.evict(
      const AssetImage('images/store/racks/store-reference.webp'),
    );
    for (final item in items) {
      if (item.asset.isEmpty) continue;
      PaintingBinding.instance.imageCache.evict(
        ResizeImage(AssetImage(item.asset), width: 220),
      );
    }
  }

  void _changeTab(int index) {
    if (index == _selectedTab) return;
    _evictPreviews(_itemsForTab(_selectedTab));
    setState(() => _selectedTab = index);
  }

  @override
  void dispose() {
    // Mağaza kartları yalnız bu sahnede kullanılır. Oyun sahnesine geçerken
    // küçük önizleme bitmaplerini önbellekte tutmayarak RAM ve GPU texture
    // belleğini seçilen gerçek oyun görsellerine bırak.
    _evictPreviews([..._storeRacks, ..._storeTiles, ..._storeBackgrounds]);
    unawaited(requestMemoryTrim());
    super.dispose();
  }

  void _selectOrBuy(_StoreItem item, CosmeticKind kind) {
    if (!storeCosmetics.owns(kind, item.id) &&
        !playerProgress.trySpendCoins(item.price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          dismissDirection: DismissDirection.horizontal,
          content: Text('Bu ürün için yeterli altının yok.'),
        ),
      );
      return;
    }
    storeCosmetics.unlockAndSelect(kind, item.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      key: const ValueKey('store-screen'),
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          Positioned.fill(child: StoreBackground(cacheWidth: 960)),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final singleRow = bounds.maxWidth >= 500;
                      final tabWidth = singleRow
                          ? (bounds.maxWidth - 236).clamp(270.0, 650.0)
                          : bounds.maxWidth;
                      final tabs = Container(
                        width: tabWidth,
                        height: 46,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xEE001B10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE1BB53)),
                        ),
                        child: TabBar(
                          onTap: _changeTab,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFC89C37), Color(0xFF805511)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFDC70),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          labelStyle: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w900,
                          ),
                          tabs: const [
                            Tab(
                              key: ValueKey('store-racks-tab'),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [Text('ISTAKALAR')],
                                ),
                              ),
                            ),
                            Tab(
                              key: ValueKey('store-tiles-tab'),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [Text('TAŞLAR')],
                                ),
                              ),
                            ),
                            Tab(
                              key: ValueKey('store-backgrounds-tab'),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [Text('ARKA PLAN')],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      final navigation = Row(
                        children: [
                          AppBackButton(
                            onTap: () => Navigator.of(context).pop(),
                            size: 44,
                          ),
                          const Spacer(),
                          const AppCoinBalance(),
                        ],
                      );
                      return singleRow
                          ? SizedBox(
                              height: 52,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [navigation, tabs],
                              ),
                            )
                          : Column(
                              children: [
                                navigation,
                                const SizedBox(height: 6),
                                tabs,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: switch (_selectedTab) {
                      0 => _StoreItemList(
                        key: const ValueKey('store-racks-list'),
                        items: _storeRacks,
                        ownedIds: storeCosmetics.owned(CosmeticKind.rack),
                        selectedId: storeCosmetics.selected(CosmeticKind.rack),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.rack),
                      ),
                      1 => _StoreItemList(
                        key: const ValueKey('store-tiles-list'),
                        items: _storeTiles,
                        ownedIds: storeCosmetics.owned(CosmeticKind.tile),
                        selectedId: storeCosmetics.selected(CosmeticKind.tile),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.tile),
                      ),
                      _ => _StoreItemList(
                        key: const ValueKey('store-backgrounds-list'),
                        items: _storeBackgrounds,
                        ownedIds: storeCosmetics.owned(CosmeticKind.background),
                        selectedId: storeCosmetics.selected(
                          CosmeticKind.background,
                        ),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.background),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StoreItemList extends StatefulWidget {
  final List<_StoreItem> items;
  final Set<String> ownedIds;
  final String selectedId;
  final ValueChanged<_StoreItem> onPressed;

  const _StoreItemList({
    super.key,
    required this.items,
    required this.ownedIds,
    required this.selectedId,
    required this.onPressed,
  });

  @override
  State<_StoreItemList> createState() => _StoreItemListState();
}

class _StoreItemListState extends State<_StoreItemList> {
  final _scroll = ScrollController();
  bool _canGoLeft = false;
  bool _canGoRight = false;
  bool _metricsPending = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateArrows);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions) {
      return;
    }
    final position = _scroll.position;
    final left = position.pixels > position.minScrollExtent + 1;
    final right = position.pixels < position.maxScrollExtent - 1;
    if (left == _canGoLeft && right == _canGoRight) return;
    setState(() {
      _canGoLeft = left;
      _canGoRight = right;
    });
  }

  void _scheduleMetricsUpdate() {
    if (_metricsPending) return;
    _metricsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsPending = false;
      _updateArrows();
    });
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * .85).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      unawaited(
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _scheduleMetricsUpdate();
      final contentWidth = box.maxWidth - 68;
      final visibleCards = contentWidth >= 620
          ? 4
          : contentWidth >= 430
          ? 3
          : 2;
      final cardWidth =
          (contentWidth - 8 - (visibleCards - 1) * 12) / visibleCards;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              key: const ValueKey('store-gallery-frame'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xDB001C10),
                border: Border.all(color: const Color(0xFFE6C75E), width: 1.7),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x775E8D52)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _scheduleMetricsUpdate();
                return false;
              },
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  scrollbars: false,
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _StoreItemCard(
                        item: item,
                        owned: widget.ownedIds.contains(item.id),
                        selected: widget.selectedId == item.id,
                        onPressed: () => widget.onPressed(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (_canGoLeft)
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              width: 44,
              child: Center(
                child: _StoreScrollArrow(
                  key: const ValueKey('store-scroll-left'),
                  left: true,
                  onTap: () => _move(-1),
                ),
              ),
            ),
          if (_canGoRight)
            Positioned(
              right: -8,
              top: 0,
              bottom: 0,
              width: 44,
              child: Center(
                child: _StoreScrollArrow(
                  key: const ValueKey('store-scroll-right'),
                  left: false,
                  onTap: () => _move(1),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _StoreScrollArrow extends StatelessWidget {
  final bool left;
  final VoidCallback onTap;
  const _StoreScrollArrow({super.key, required this.left, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: left ? 'Önceki ürünler' : 'Sonraki ürünler',
    child: SizedBox(
      width: 44,
      height: 48,
      child: Center(
        child: IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 44),
            padding: const EdgeInsets.all(4),
            backgroundColor: const Color(0xFF124F32),
            foregroundColor: const Color(0xFFFFE99A),
            side: const BorderSide(color: Color(0xFFFFD75F), width: 1.5),
            shape: const StadiumBorder(),
          ),
          icon: Icon(
            left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 30,
          ),
        ),
      ),
    ),
  );
}

class _StoreItemCard extends StatelessWidget {
  final _StoreItem item;
  final bool owned;
  final bool selected;
  final VoidCallback onPressed;

  const _StoreItemCard({
    required this.item,
    required this.owned,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF063A24), Color(0xFF031C12)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFFFFDF72) : const Color(0xFF427B56),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            const BoxShadow(color: Color(0x88F5D75E), blurRadius: 8),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        radius: .85,
                        colors: [Color(0xFF004B2D), Color(0xFF001C0F)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFF2F5C40),
                        width: .8,
                      ),
                    ),
                    child: item.color != null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: _RackReferencePreview.hasArtwork(item.id)
                                ? _RackReferencePreview(id: item.id)
                                : Image.asset(
                                    item.asset,
                                    fit: BoxFit.contain,
                                    cacheWidth: 220,
                                    filterQuality: FilterQuality.medium,
                                  ),
                          ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _SelectedStoreBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.name,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFFFF1CE),
                  fontSize: 17,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 17,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.subtitle,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFDBDDC9),
                  fontSize: 12,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? const [Color(0xFFBE9533), Color(0xFF76520D)]
                      : const [Color(0xFF368E48), Color(0xFF075528)],
                ),
                border: Border.all(color: const Color(0xFFE3BD54), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton(
                key: ValueKey('store-action-${item.id}'),
                onPressed: selected ? null : onPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: const Color(0xFFFFF3CC),
                  disabledForegroundColor: const Color(0xFFFFE997),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: owned
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) ...[
                              const Icon(Icons.check_rounded, size: 21),
                              const SizedBox(width: 6),
                            ],
                            Text(selected ? 'SEÇİLİ' : 'KULLAN'),
                          ],
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'images/ui/coin.png',
                            width: 15,
                            height: 15,
                            cacheWidth: 30,
                            cacheHeight: 30,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(formatGameNumber(item.price)),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SelectedStoreBadge extends StatelessWidget {
  const _SelectedStoreBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB68A2D), Color(0xFF78500D)],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: OkeyColors.goldLight),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 15,
          color: Color(0xFFFFE899),
        ),
        SizedBox(width: 4),
        Text(
          'AKTİF',
          style: TextStyle(
            color: Color(0xFFFFF0BD),
            fontSize: 11,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _RackReferencePreview extends StatelessWidget {
  final String id;
  const _RackReferencePreview({required this.id});

  static const _crops = {
    'rack0': Rect.fromLTWH(82, 128, 240, 108),
    'rack1': Rect.fromLTWH(360, 128, 225, 108),
    'rack2': Rect.fromLTWH(618, 128, 225, 108),
    'rack3': Rect.fromLTWH(882, 128, 225, 108),
  };
  static bool hasArtwork(String id) => _crops.containsKey(id);

  @override
  Widget build(BuildContext context) {
    final crop = _crops[id]!;
    final sprite = ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: -crop.left,
            top: -crop.top,
            width: 1195,
            height: 426,
            child: Image.asset(
              'images/store/racks/store-reference.webp',
              width: 1195,
              height: 426,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: crop.width,
        height: crop.height,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, .1, .9, 1],
          ).createShader(rect),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, .03, .97, 1],
            ).createShader(rect),
            child: sprite,
          ),
        ),
      ),
    );
  }
}

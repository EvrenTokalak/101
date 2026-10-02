import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CosmeticKind { rack, tile, background }

class StoreCosmeticsController extends ChangeNotifier {
  static const _ownedRacksKey = 'store.owned_racks';
  static const _ownedTilesKey = 'store.owned_tiles';
  static const _ownedBackgroundsKey = 'store.owned_backgrounds';
  static const _selectedRackKey = 'store.selected_rack';
  static const _selectedTileKey = 'store.selected_tile';
  static const _selectedBackgroundKey = 'store.selected_background';
  static const _menuBackgroundDefaultKey = 'store.menu_background_default_v1';

  final Set<String> _ownedRacks = {'rack0'};
  final Set<String> _ownedTiles = {'tile0'};
  final Set<String> _ownedBackgrounds = {'bg_menu'};
  String _selectedRack = 'rack0';
  String _selectedTile = 'tile0';
  String _selectedBackground = 'bg_menu';
  bool _loaded = false;

  Set<String> owned(CosmeticKind kind) => Set.unmodifiable(switch (kind) {
    CosmeticKind.rack => _ownedRacks,
    CosmeticKind.tile => _ownedTiles,
    CosmeticKind.background => _ownedBackgrounds,
  });

  String selected(CosmeticKind kind) => switch (kind) {
    CosmeticKind.rack => _selectedRack,
    CosmeticKind.tile => _selectedTile,
    CosmeticKind.background => _selectedBackground,
  };

  bool owns(CosmeticKind kind, String id) => switch (kind) {
    CosmeticKind.rack => _ownedRacks.contains(id),
    CosmeticKind.tile => _ownedTiles.contains(id),
    CosmeticKind.background => _ownedBackgrounds.contains(id),
  };

  String get rackAsset => _selectedRack == 'rack0'
      ? 'images/rack2.jpg'
      : 'images/store/rack_skins/$_selectedRack.jpg';

  String get tileAsset => _selectedTile == 'tile0'
      ? 'images/tas_ters.png'
      : 'images/store/tile_skins/$_selectedTile.png';

  String? get fakeOkeyAsset => _selectedTile == 'tile0'
      ? null
      : 'images/store/fake_okeys/${_selectedTile}_fake_okey.png';

  String get backgroundAsset => _selectedBackground == 'bg_menu'
      ? 'images/anamenu/menubg.png'
      : _selectedBackground.startsWith('solid_')
      ? ''
      : 'images/store/backgrounds/$_selectedBackground.jpg';

  Color? get backgroundColor => switch (_selectedBackground) {
    'solid_green' => const Color(0xFF075733),
    'solid_blue' => const Color(0xFF123D5A),
    'solid_burgundy' => const Color(0xFF54252B),
    'solid_black' => const Color(0xFF151917),
    _ => null,
  };

  // Market rack rails start at roughly 8% of the source image, while their
  // inner edge is close to 9.8%. Align tiles to that edge so they sit close to
  // the black rails without overlapping them.
  double get rackHorizontalInset => _selectedRack == 'rack0' ? 0.074 : 0.098;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = SharedPreferencesAsync();
      _ownedRacks.addAll(
        await preferences.getStringList(_ownedRacksKey) ?? const [],
      );
      _ownedTiles.addAll(
        await preferences.getStringList(_ownedTilesKey) ?? const [],
      );
      _ownedBackgrounds.addAll(
        await preferences.getStringList(_ownedBackgroundsKey) ?? const [],
      );
      final rack = await preferences.getString(_selectedRackKey);
      final tile = await preferences.getString(_selectedTileKey);
      final background = await preferences.getString(_selectedBackgroundKey);
      if (rack != null && _ownedRacks.contains(rack)) _selectedRack = rack;
      if (tile != null && _ownedTiles.contains(tile)) _selectedTile = tile;
      if (background != null && _ownedBackgrounds.contains(background)) {
        _selectedBackground = background;
      }
      if (await preferences.getBool(_menuBackgroundDefaultKey) != true) {
        _ownedBackgrounds.add('bg_menu');
        _selectedBackground = 'bg_menu';
        await preferences.setBool(_menuBackgroundDefaultKey, true);
        await preferences.setString(
          _selectedBackgroundKey,
          _selectedBackground,
        );
      }
    } on StateError {
      // Saf widget testlerinde platform deposu kurulmayabilir.
    }
    notifyListeners();
  }

  void unlockAndSelect(CosmeticKind kind, String id) {
    switch (kind) {
      case CosmeticKind.rack:
        _ownedRacks.add(id);
        _selectedRack = id;
      case CosmeticKind.tile:
        _ownedTiles.add(id);
        _selectedTile = id;
      case CosmeticKind.background:
        _ownedBackgrounds.add(id);
        _selectedBackground = id;
    }
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final preferences = SharedPreferencesAsync();
      await Future.wait([
        preferences.setStringList(_ownedRacksKey, _ownedRacks.toList()),
        preferences.setStringList(_ownedTilesKey, _ownedTiles.toList()),
        preferences.setStringList(
          _ownedBackgroundsKey,
          _ownedBackgrounds.toList(),
        ),
        preferences.setString(_selectedRackKey, _selectedRack),
        preferences.setString(_selectedTileKey, _selectedTile),
        preferences.setString(_selectedBackgroundKey, _selectedBackground),
      ]);
    } on StateError {
      // Test ortamında seçim, süreç ömrü boyunca denetleyicide kalır.
    }
  }
}

final storeCosmetics = StoreCosmeticsController();

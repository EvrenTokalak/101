import 'dart:math';

/// Bir oyun oturumu boyunca rakip adlarini sabit tutar.
///
/// Ana sayfaya donuldugunda [reset] cagrilir. Sonraki oyun acildiginda yeni
/// bir isim grubu uretilir; ayni macin turlari ve turnuva asamalari boyunca
/// mevcut grup korunur.
class OpponentNameSession {
  OpponentNameSession({Random? random}) : _random = random ?? Random();

  static const _namePool = <String>[
    'Mert',
    'Selin',
    'Emre',
    'Ece',
    'Arda',
    'Deniz',
    'Ceren',
    'Burak',
    'Elif',
    'Kerem',
    'Zeynep',
    'Can',
  ];

  final Random _random;
  List<String>? _currentNames;

  List<String> get names => _currentNames ??= _createNames();

  void reset() => _currentNames = null;

  List<String> _createNames() {
    final candidates = List<String>.of(_namePool)..shuffle(_random);
    return List<String>.unmodifiable(candidates.take(3));
  }
}

final opponentNameSession = OpponentNameSession();

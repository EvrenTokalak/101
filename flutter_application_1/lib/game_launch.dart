enum GameEntryPoint { quickPlay, gameMode, room, tournament, tutorial }

enum OkeyGameMode { standard, classic101, timed101, colorBonus101, progressive }

enum BotDifficulty { easy, medium, hard }

/// Bir oyun masasının hangi ekrandan ve hangi seçimle açıldığını taşır.
/// Moda/odaya özel kurallar ileride bu nesne üzerinden ayrıştırılabilir.
class GameLaunchConfig {
  final GameEntryPoint entryPoint;
  final OkeyGameMode mode;
  final String selectionId;
  final String selectionLabel;
  final int? entryFee;
  final int? tournamentRound;
  final String? opponent;
  final BotDifficulty? difficulty;

  const GameLaunchConfig._({
    required this.entryPoint,
    required this.mode,
    required this.selectionId,
    required this.selectionLabel,
    this.entryFee,
    this.tournamentRound,
    this.opponent,
    this.difficulty,
  });

  const GameLaunchConfig.quickPlay()
    : this._(
        entryPoint: GameEntryPoint.quickPlay,
        mode: OkeyGameMode.standard,
        selectionId: 'quick-play',
        selectionLabel: 'Hemen Oyna',
      );

  const GameLaunchConfig.tutorial()
    : this._(
        entryPoint: GameEntryPoint.tutorial,
        mode: OkeyGameMode.standard,
        selectionId: 'tutorial',
        selectionLabel: 'Öğretici',
      );

  const GameLaunchConfig.gameMode({
    required OkeyGameMode mode,
    required String id,
    required String label,
  }) : this._(
         entryPoint: GameEntryPoint.gameMode,
         mode: mode,
         selectionId: id,
         selectionLabel: label,
       );

  const GameLaunchConfig.room({
    required String id,
    required String label,
    required int entryFee,
  }) : this._(
         entryPoint: GameEntryPoint.room,
         mode: OkeyGameMode.classic101,
         selectionId: id,
         selectionLabel: label,
         entryFee: entryFee,
       );

  const GameLaunchConfig.tournament({
    required int round,
    required String roundLabel,
    String? opponent,
  }) : this._(
         entryPoint: GameEntryPoint.tournament,
         mode: OkeyGameMode.classic101,
         selectionId: 'tournament-round-$round',
         selectionLabel: roundLabel,
         tournamentRound: round,
         opponent: opponent,
       );

  bool get isTournament => entryPoint == GameEntryPoint.tournament;

  GameLaunchConfig withDifficulty(BotDifficulty value) => GameLaunchConfig._(
    entryPoint: entryPoint,
    mode: mode,
    selectionId: selectionId,
    selectionLabel: selectionLabel,
    entryFee: entryFee,
    tournamentRound: tournamentRound,
    opponent: opponent,
    difficulty: value,
  );

  Map<String, dynamic> toJson() => {
    'entry': entryPoint.name,
    'mode': mode.name,
    'id': selectionId,
    'label': selectionLabel,
    'fee': entryFee,
    'round': tournamentRound,
    'opponent': opponent,
    'difficulty': difficulty?.name,
  };

  factory GameLaunchConfig.fromJson(Map<String, dynamic> data) =>
      GameLaunchConfig._(
        entryPoint: GameEntryPoint.values.byName(data['entry'] as String),
        mode: OkeyGameMode.values.byName(data['mode'] as String),
        selectionId: data['id'] as String,
        selectionLabel: data['label'] as String,
        entryFee: data['fee'] as int?,
        tournamentRound: data['round'] as int?,
        opponent: data['opponent'] as String?,
        difficulty: data['difficulty'] == null
            ? null
            : BotDifficulty.values.byName(data['difficulty'] as String),
      );

  String get modeLabel => switch (mode) {
    OkeyGameMode.standard => 'Sıradan',
    OkeyGameMode.classic101 => 'Klasik 101',
    OkeyGameMode.timed101 => 'Zamanlı 101',
    OkeyGameMode.colorBonus101 => 'Renkli 101',
    OkeyGameMode.progressive => 'Katlamalı',
  };

  String get entryPointLabel => switch (entryPoint) {
    GameEntryPoint.quickPlay => 'Hemen Oyna',
    GameEntryPoint.gameMode => 'Oyun Modları',
    GameEntryPoint.room => 'Oda',
    GameEntryPoint.tournament => 'Turnuva',
    GameEntryPoint.tutorial => 'Öğretici',
  };
}

enum GameEntryPoint { quickPlay, gameMode, room, tournament }

enum OkeyGameMode { standard, classic101, paired101, progressive }

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

  const GameLaunchConfig._({
    required this.entryPoint,
    required this.mode,
    required this.selectionId,
    required this.selectionLabel,
    this.entryFee,
    this.tournamentRound,
    this.opponent,
  });

  const GameLaunchConfig.quickPlay()
    : this._(
        entryPoint: GameEntryPoint.quickPlay,
        mode: OkeyGameMode.standard,
        selectionId: 'quick-play',
        selectionLabel: 'Hemen Oyna',
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

  String get modeLabel => switch (mode) {
    OkeyGameMode.standard => 'Sıradan',
    OkeyGameMode.classic101 => 'Eliminasyon 101',
    OkeyGameMode.paired101 => 'Eşli 101',
    OkeyGameMode.progressive => 'Katlamalı',
  };

  String get entryPointLabel => switch (entryPoint) {
    GameEntryPoint.quickPlay => 'Hemen Oyna',
    GameEntryPoint.gameMode => 'Oyun Modları',
    GameEntryPoint.room => 'Oda',
    GameEntryPoint.tournament => 'Turnuva',
  };
}

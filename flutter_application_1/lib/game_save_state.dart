part of 'game.dart';

extension _GameSaving on _GameScreenState {
  bool get _canResumeSave =>
      _resumeReady && !_isTutorialGame && !_isTournamentGame && !_gameOverShown;

  void _scheduleResumeSave() {
    if (!_canResumeSave) return;
    _resumeSaveTimer?.cancel();
    _resumeSaveTimer = Timer(
      const Duration(milliseconds: 300),
      _flushResumeSave,
    );
  }

  void _rememberResumeState({bool force = false}) {
    if (!_canResumeSave || (!force && (_botBusy || _autoPlayerBusy))) return;
    _pendingResume = _captureSavedGame();
    _scheduleResumeSave();
  }

  void _flushResumeSave() {
    _resumeSaveTimer?.cancel();
    if (!_canResumeSave) return;
    if (!_botBusy && !_autoPlayerBusy) _pendingResume = _captureSavedGame();
    final snapshot = _pendingResume;
    if (snapshot != null) {
      // A completed game cannot be rewritten by a delayed dispose callback.
      unawaited(savedGame.save(snapshot));
    }
  }

  Map<String, dynamic> _captureSavedGame() {
    final tiles = <int, Tile>{};
    int single(Tile tile) {
      tiles[tile.id] = tile;
      return tile.id;
    }

    List<int> refs(Iterable<Tile> list) => [
      for (final tile in list) single(tile),
    ];

    int? optional(Tile? tile) => tile == null ? null : single(tile);
    final result = <String, dynamic>{
      'version': 1,
      'config': widget.launchConfig.toJson(),
      'deck': refs(_deck),
      'rack': refs(_rack),
      'slots': List<int?>.of(_rackSlots),
      'indicator': optional(_indicator),
      'discarded': optional(_discarded),
      'takenDiscard': optional(_takenDiscardTile),
      'discards': [for (final pile in _discardPiles) refs(pile)],
      'melds': [
        for (final meld in _tableMetds)
          {'type': meld.type, 'tiles': refs(meld.tiles)},
      ],
      'bots': [
        for (final bot in _bots)
          {
            'name': bot.name,
            'display': bot.displayName,
            'difficulty': bot.difficulty.name,
            'personality': bot.personality.name,
            'league': bot.leagueId,
            'penalty': bot.penalty,
            'opened': bot.hasOpened,
            'openType': bot.openType,
            'turns': bot.turnsPlayed,
            'hand': refs(bot.hand),
            'seen': refs(bot.seenDiscards),
            'takes': refs(bot.opponentTakes),
          },
      ],
      'turn': _turn,
      'starting': _startingPlayer,
      'el': _elCount,
      'drawn': _drawnThisTurn,
      'tookDiscard': _tookDiscard,
      'opened': _playerOpened,
      'openType': _playerOpenType,
      'openedThisTurn': _openedThisPlayerTurn,
      'processedEarlierTurns': _processedInEarlierTurns,
      'penalty': _totalPenalty,
      'penaltyStart': _roundPlayerPenaltyStart,
      'resultPenalty': _resultPlayerPenalty,
      'resultBots': _resultBotPenalties?.map(
        (key, value) => MapEntry('$key', value),
      ),
      'minimumScore': _minimumStandardOpeningScore,
      'minimumPairs': _minimumPairOpeningCount,
      'bonusColor': _roundBonusColor.index,
      'showPairs': _showRackPairCount,
      'session': _leagueSessionId,
      'leagueDeadline': dailyLeague.deadline?.millisecondsSinceEpoch,
      'remainingSeconds': _playerTurnSeconds.value,
      'roundGeneration': _roundGeneration,
      'difficultyOrder': _quickDifficultyOrder
          .map((level) => level.name)
          .toList(),
      'roomSettled': _roomMatchSettled,
      'processed': [
        for (final move in _processedMoves)
          {
            'meld': _tableMetds.indexOf(move.meld),
            'previous': refs(move.previousMeldTiles),
            'added': refs(move.addedTiles),
            'returned': refs(move.returnedTiles),
            'remove': move.removeMeldOnUndo,
            'slots': move.originalSlots.map(
              (id, slot) => MapEntry('$id', slot),
            ),
            'took': move.tookDiscardBefore,
            'taken': optional(move.takenDiscardTileBefore),
          },
      ],
    };
    result['tiles'] = [
      for (final tile in tiles.values)
        {
          'id': tile.id,
          'number': tile.number,
          'color': tile.color.index,
          'fake': tile.isFakeOkey,
          'okey': tile.isOkey,
          'indicator': tile.isIndicator,
          'revealed': tile.okeyFaceRevealed,
        },
    ];
    return result;
  }

  bool _restoreSavedGame(Map<String, dynamic> data) {
    if (!SavedGameController.valid(data)) return false;
    try {
      final tiles = <int, Tile>{
        for (final raw in data['tiles'] as List)
          raw['id'] as int: Tile(
            id: raw['id'] as int,
            number: raw['number'] as int,
            color: TileColor.values[raw['color'] as int],
            isFakeOkey: raw['fake'] as bool,
            isOkey: raw['okey'] as bool,
            isIndicator: raw['indicator'] as bool,
            okeyFaceRevealed: raw['revealed'] as bool,
          ),
      };
      List<Tile> refs(dynamic ids) => [
        for (final id in ids as List) tiles[id]!,
      ];
      Tile? optional(dynamic id) => id == null ? null : tiles[id];
      _deck = refs(data['deck']);
      _rack = refs(data['rack']);
      _rackSlots = (data['slots'] as List).cast<int?>().toList();
      _indicator = optional(data['indicator']);
      _discarded = optional(data['discarded']);
      _takenDiscardTile = optional(data['takenDiscard']);
      _discardPiles = [for (final pile in data['discards'] as List) refs(pile)];
      _tableMetds = [
        for (final meld in data['melds'] as List)
          Meld(type: meld['type'] as String, tiles: refs(meld['tiles'])),
      ];
      final bots = [
        for (final bot in data['bots'] as List)
          BotPlayer(
            name: bot['name'] as String,
            displayName: bot['display'] as String,
            difficulty: BotDifficulty.values.byName(
              bot['difficulty'] as String,
            ),
            personality: BotPersonality.values.byName(
              bot['personality'] as String,
            ),
            leagueId: bot['league'] as int?,
            penalty: bot['penalty'] as int,
            hasOpened: bot['opened'] as bool,
            openType: bot['openType'] as String,
            turnsPlayed: bot['turns'] as int,
            hand: refs(bot['hand']),
            seenDiscards: refs(bot['seen']),
            opponentTakes: refs(bot['takes']),
          ),
      ];
      for (var index = 0; index < 3; index++) {
        _bots[index] = bots[index]..tileCount = bots[index].hand.length;
      }
      _turn = data['turn'] as int;
      _startingPlayer = data['starting'] as int;
      _elCount = data['el'] as int;
      _drawnThisTurn = data['drawn'] as bool;
      _tookDiscard = data['tookDiscard'] as bool;
      _playerOpened = data['opened'] as bool;
      _playerOpenType = data['openType'] as String;
      _openedThisPlayerTurn = data['openedThisTurn'] as bool;
      _processedInEarlierTurns =
          data['processedEarlierTurns'] as bool? ?? false;
      _totalPenalty = data['penalty'] as int;
      _roundPlayerPenaltyStart = data['penaltyStart'] as int;
      _resultPlayerPenalty = data['resultPenalty'] as int?;
      _resultBotPenalties = (data['resultBots'] as Map<String, dynamic>?)?.map(
        (id, score) => MapEntry(int.parse(id), score as int),
      );
      _minimumStandardOpeningScore = data['minimumScore'] as int;
      _minimumPairOpeningCount = data['minimumPairs'] as int;
      _roundBonusColor = TileColor.values[data['bonusColor'] as int];
      _showRackPairCount = data['showPairs'] as bool;
      _leagueSessionId = data['session'] as String;
      _roundGeneration = data['roundGeneration'] as int;
      _quickDifficultyOrder = [
        for (final level in data['difficultyOrder'] as List)
          BotDifficulty.values.byName(level as String),
      ];
      _roomMatchSettled = data['roomSettled'] as bool;
      _resumeTimedSeconds = (data['remainingSeconds'] as int?)?.clamp(1, 7);
      _playerTurnSeconds.value = _resumeTimedSeconds ?? 7;
      _resumeLeagueEligible =
          data['leagueDeadline'] ==
          dailyLeague.deadline?.millisecondsSinceEpoch;
      _processedMoves.clear();
      for (final move in data['processed'] as List) {
        final index = move['meld'] as int;
        if (index < 0 || index >= _tableMetds.length) continue;
        _processedMoves.add(
          _ProcessedMove(
            meld: _tableMetds[index],
            previousMeldTiles: refs(move['previous']),
            addedTiles: refs(move['added']),
            returnedTiles: refs(move['returned']),
            removeMeldOnUndo: move['remove'] as bool,
            originalSlots: (move['slots'] as Map<String, dynamic>).map(
              (id, slot) => MapEntry(int.parse(id), slot as int),
            ),
            tookDiscardBefore: move['took'] as bool,
            takenDiscardTileBefore: optional(move['taken']),
          ),
        );
      }
      _idCounter = max(_idCounter, tiles.keys.reduce(max) + 1);
      if (data['betweenRounds'] == true) {
        _startNewRound();
        return true;
      }
      if (_resumeLeagueEligible &&
          widget.launchConfig.entryPoint == GameEntryPoint.quickPlay &&
          !dailyLeague.complete) {
        final tables = LeagueRoundTables(
          seating: LeagueSeating.forRound(dailyLeague.completedRounds),
        );
        _leagueRoundTables = tables;
        tables.scores = _prepareLeagueTables(tables, _roundGeneration);
      }
      _markTableChanged();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_turn == 0) {
          _beginPlayerTurn(alreadyHasExtraTile: _drawnThisTurn);
        } else {
          final bot = _bots[_turn - 1];
          final extra = bot.openType == 'cift'
              ? bot.hand.length.isEven
              : bot.hand.length % 3 == 1;
          _runBot(_turn - 1, alreadyHasExtraTile: extra);
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

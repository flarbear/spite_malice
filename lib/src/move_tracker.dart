import 'package:boardgame_io/boardgame.dart';

import 'cards.dart';
import 'game_state.dart';

typedef SpiteMaliceCheckMove = bool Function(SpiteMaliceGameState state);
typedef SpiteMaliceExecuteMove = void Function(Client gameClient);

class SpiteMaliceMove {
  SpiteMaliceMove({
    required this.from,
    required this.to,
    required this.canMove,
    required this.execute,
  });

  SpiteMaliceStackId from;
  SpiteMaliceStackId to;
  SpiteMaliceCheckMove canMove;
  SpiteMaliceExecuteMove execute;

  bool get isDirectMove => from == to;
}

class SpiteMaliceMoveTracker {
  SpiteMaliceMoveTracker(this.state) { setupMoves(); }

  SpiteMaliceGameState state;

  Map<SpiteMaliceStackId, Map<SpiteMaliceStackId, SpiteMaliceMove>> allMoves = {};

  void _register(SpiteMaliceMove move) {
    Map<SpiteMaliceStackId, SpiteMaliceMove>? moveMap = allMoves[move.from];
    if (moveMap == null) {
      allMoves[move.from] = moveMap = {};
    }
    moveMap[move.to] = move;
  }

  void _registerHandDiscard(SpiteMaliceStackId hand, SpiteMaliceStackId discard) {
    _register(
      SpiteMaliceMove(
        from: hand,
        to: discard,
        canMove: (state) => (state.myTableau.hand![hand.index] != null),
        execute: (client) => client.makeMove('discard', [ hand.index, discard.index ]),
      ),
    );
  }

  static bool _canBuild(SpiteMaliceGameState state, SpiteMaliceCard? card, int buildIndex) {
    if (card == null) return false;
    if (card.isWild) return true;
    if (card.rank == state.buildSizes[buildIndex] + 1) return true;
    return false;
  }

  void _registerHandBuild(SpiteMaliceStackId hand, SpiteMaliceStackId build) {
    _register(
      SpiteMaliceMove(
        from: hand,
        to: build,
        canMove: (state) => _canBuild(state, state.myTableau.hand![hand.index], build.index),
        execute: (client) => client.makeMove('buildFromHand', [ hand.index, build.index ]),
      ),
    );
  }

  void _registerStockBuild(SpiteMaliceStackId build) {
    _register(
      SpiteMaliceMove(
        from: SpiteMaliceStackId.stockId,
        to: build,
        canMove: (state) => _canBuild(state, state.myTableau.stockTop, build.index),
        execute: (client) => client.makeMove('buildFromStock', [ build.index ]),
      ),
    );
  }

  void _registerDiscardBuild(SpiteMaliceStackId discard, SpiteMaliceStackId build) {
    _register(
      SpiteMaliceMove(
        from: discard,
        to: build,
        canMove: (state) => _canBuild(state, state.discardTop(discard.index), build.index),
        execute: (client) => client.makeMove('buildFromDiscard', [ discard.index, build.index ]),
      ),
    );
  }

  void _registerDraw(SpiteMaliceStackId draw) {
    _register(
      SpiteMaliceMove(
        from: draw,
        to: draw,
        canMove: (state) => state.myTableau.hand!.every((card) => card == null),
        execute: (client) => client.makeMove('draw', []),
      ),
    );
  }

  void setupMoves() {
    var allHand = SpiteMaliceStackId.handIds;
    var allBuild = SpiteMaliceStackId.buildIds;
    var allDiscard = SpiteMaliceStackId.discardIds;
    _registerDraw(SpiteMaliceStackId.drawId);
    allHand.forEach((hand) => allDiscard.forEach((discard) => _registerHandDiscard(hand, discard)));
    allHand.forEach((hand) => allBuild.forEach((build) => _registerHandBuild(hand, build)));
    allBuild.forEach((build) => _registerStockBuild(build));
    allDiscard.forEach((discard) => allBuild.forEach((build) => _registerDiscardBuild(discard, build)));
  }

  void leaving(SpiteMaliceStackId type) {
    if (state.validMoves != null) {
      if (state.highlightTo == type) {
        state.setHighlightTo(null);
      }
    } else if (state.highlightFrom == type) {
      state.setHighlightFrom(null);
    }
  }

  void hoveringOver(SpiteMaliceStackId type, bool click) {
    // print('hovering over $type (click = $click)');
    Map<SpiteMaliceStackId, SpiteMaliceMove>? validMoves = state.validMoves;
    if (validMoves != null) {
      SpiteMaliceMove? move = validMoves[type];
      if (move == null) {
        state.setHighlightTo(null);
        if (click) {
          state.setSelected(null);
        }
      } else {
        if (click) {
          move.execute(state.gameClient);
          state.clearHighlight();
        } else {
          state.setHighlightTo(type);
        }
      }
    } else {
      Map<SpiteMaliceStackId, SpiteMaliceMove>? movesFrom = allMoves[type];
      Iterable<SpiteMaliceMove>? validMoves = movesFrom?.values.where((move) => move.canMove(state));
      if (validMoves != null && validMoves.isNotEmpty) {
        state.setHighlightFrom(type);
        if (click) {
          if (validMoves.length == 1 && validMoves.first.isDirectMove) {
            validMoves.first.execute(state.gameClient);
            state.clearHighlight();
          } else {
            state.setSelected(
                Map.fromIterable(validMoves,
                  key: (move) => move.to,
                  value: (move) => move,
                )
            );
          }
        }
      } else {
        state.clearHighlight();
      }
    }
  }
}

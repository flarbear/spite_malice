/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:boardgame_io/boardgame.dart';
import 'package:playing_cards/playing_cards.dart';

import 'move_tracker.dart';

enum SpiteMalicePhase {
  waiting,
  cutting,
  dealing,
  playing,
}

typedef SpiteMaliceGameStateListener = void Function();

typedef SpiteMaliceGameStateCancel = void Function();

class SpiteMaliceTableauState {
  PlayingCardStack stock = PlayingCardStack();
  List<List<PlayingCard>> discardPiles = List<List<PlayingCard>>.generate(4, (index) => <PlayingCard>[]);
  List<PlayingCard?> hand = List.filled(5, null);
}

class SpiteMaliceCutState {
  SpiteMaliceCutState(this.cutIndex, this.cutCard);
  const SpiteMaliceCutState.available() : this.cutIndex = 0, this.cutCard = PlayingCard.back;

  final int? cutIndex;
  final PlayingCard? cutCard;
}

class SpiteMaliceGameState extends CardGameState<SpiteMaliceId> {
  SpiteMaliceGameState(this.gameClient);

  final Client gameClient;

  SpiteMalicePhase phase = SpiteMalicePhase.waiting;

  int drawSize = 0;
  List<PlayingCardStack> buildPiles = List.generate(4, (index) => PlayingCardStack());
  int trashSize = 0;

  Map<String, SpiteMaliceTableauState> tableaux = {};
  List<String> opponentOrder = [];

  Map<String, SpiteMaliceCutState> cutStates = {};
  List<PlayingCard> cutCards = List.filled(12, PlayingCard.back);
  String? dealerId;

  late MoveState<SpiteMaliceId> currentMove = MoveState.empty();

  List<SpiteMaliceGameStateListener> listeners = <SpiteMaliceGameStateListener>[];

  SpiteMaliceGameStateCancel listen(SpiteMaliceGameStateListener listener) {
    listeners.add(listener);
    return () => listeners.remove(listener);
  }

  void notify() {
    listeners.forEach((listener) { listener(); });
  }

  SpiteMaliceTableauState get myTableau => tableaux[gameClient.playerID] ?? SpiteMaliceTableauState();

  bool isMyTurn = false;
  bool get hasCut => cutStates[gameClient.playerID]?.cutCard != null;
  bool get isMyDeal => dealerId == gameClient.playerID;
  bool get isHandEmpty => myTableau.hand.every((card) => card == null);

  PlayingCard? discardTop(int discardIndex) {
    return (myTableau.discardPiles[discardIndex].isEmpty ? null : myTableau.discardPiles[discardIndex].last);
  }

  void init() {
    phase = SpiteMalicePhase.waiting;
    notify();
  }

  MoveState<SpiteMaliceId> getCurrentMove() => currentMove;
  void setCurrentMove(MoveState<SpiteMaliceId> moveState) {
    // print('highlight from changed from $highlightFrom to $type');
    currentMove = moveState;
    notify();
  }

  PlayingCard? _getCard(Map<String,dynamic>? gCard) {
    if (gCard == null) return null;
    if (gCard['isWild']) return PlayingCard.wild;
    if (gCard['isBack']) return PlayingCard.back;
    int suitIndex = gCard['suit'];
    int rankIndex = gCard['rank'];
    return PlayingCard(suit: suitIndex, rank: rankIndex);
  }

  PlayingCardStack _getStack(Map<String, dynamic> gStack) {
    return PlayingCardStack(
      size: gStack['size'],
      top: _getCard(gStack['top']),
    );
  }

  void update(Map<String, dynamic> G, ClientContext ctx) {
    // print('update!');
    Map<String, dynamic> players = G['players'];
    if (ctx.phase == null) {
      drawSize = G['drawSize'];
      buildPiles = G['buildPiles'].map<PlayingCardStack>((entry) => _getStack(entry)).toList();
      trashSize = G['completedSize'];

      for (String playerID in players.keys) {
        SpiteMaliceTableauState? tableau = tableaux[playerID];
        if (tableau == null) {
          tableaux[playerID] = tableau = SpiteMaliceTableauState();
        }
        Map<String,dynamic> player = players[playerID];
        tableau.stock = _getStack(player['stock']);
        for (int i = 0; i < 4; i++) {
          tableau.discardPiles[i] = player['discardPiles'][i].map<PlayingCard>((card) => _getCard(card)!).toList();
        }
        tableau.hand = player['hand']?.map<PlayingCard?>((card) => _getCard(card)).toList();
      }
      assert(tableaux[gameClient.playerID] != null);
      isMyTurn = ctx.currentPlayer == gameClient.playerID;
      phase = SpiteMalicePhase.playing;
    } else {
      // print(ctx.phase);
      cutCards.fillRange(0, 12, PlayingCard.back);
      for (String playerId in players.keys) {
        int? index = players[playerId]['cutIndex'];
        PlayingCard? card = _getCard(players[playerId]['cutCard']);
        cutStates[playerId] = SpiteMaliceCutState(index, card);
        if (index != null) {
          cutCards[index] = card!;
        }
      }
      dealerId = G['dealer']?.toString();
      phase = ctx.phase == 'dealing'
          ? SpiteMalicePhase.dealing
          : SpiteMalicePhase.cutting;
    }
    notify();
  }

  static SpiteMaliceCutState unrevealedCut = SpiteMaliceCutState(0, PlayingCard.back);

  PlayingCard cutCard(SpiteMaliceId cutId) =>
    cutStates.values.firstWhere((state) => state.cutIndex == cutId.index,
      orElse: () => SpiteMaliceCutState.available(),
    ).cutCard!;

  PlayingCard? _pileTop(List<PlayingCard> pile) {
    return pile.isEmpty ? null : pile.last;
  }

  bool canCutOrDeal() => !hasCut || isMyDeal;
  void cutOrDeal(SpiteMaliceId id) => phase == SpiteMalicePhase.dealing
      ? gameClient.makeMove('deal')
      : gameClient.makeMove('cutDeck', [id.index]);

  bool canDraw() => isHandEmpty;
  void draw() => gameClient.makeMove('draw');

  bool canDiscard(SpiteMaliceId hand) => myTableau.hand[hand.index] != null;
  void discard(SpiteMaliceId hand, SpiteMaliceId discard) =>
      gameClient.makeMove('discard', [ hand.index, discard.index ]);

  bool canBuildFromHand(SpiteMaliceId hand, SpiteMaliceId build) => canBuild(build, myTableau.hand[hand.index]);
  void buildFromHand(SpiteMaliceId hand, SpiteMaliceId build) =>
      gameClient.makeMove('buildFromHand', [ hand.index, build.index ]);

  bool canBuildFromStock(SpiteMaliceId build) => canBuild(build, myTableau.stock.top);
  void buildFromStock(SpiteMaliceId build) =>
      gameClient.makeMove('buildFromStock', [ build.index ]);

  bool canBuildFromDiscard(SpiteMaliceId discard, SpiteMaliceId build) =>
      canBuild(build, _pileTop(myTableau.discardPiles[discard.index]));
  void buildFromDiscard(SpiteMaliceId discard, SpiteMaliceId build) =>
      gameClient.makeMove('buildFromDiscard', [ discard.index, build.index ]);

  bool canBuild(SpiteMaliceId build, PlayingCard? card) {
    if (card == null) return false;
    if (card.isBack) return false;
    if (card.isWild) return true;
    if (card.rank == buildPiles[build.index].size + 1) return true;
    return false;
  }
}

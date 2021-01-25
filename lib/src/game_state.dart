/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/foundation.dart';
import 'package:playing_cards/playing_cards.dart';

import 'move_tracker.dart';

enum SpiteMalicePhase {
  waiting,
  cutting,
  dealing,
  playing,
  winning,
}

typedef SpiteMaliceGameStateListener = void Function();

typedef SpiteMaliceGameStateCancel = void Function();

class SpiteMaliceTableauState {
  PlayingCardStack stock = PlayingCardStack();
  List<List<PlayingCard>> discardPiles = List<List<PlayingCard>>.generate(4, (index) => <PlayingCard>[]);
  List<PlayingCard?> hand = List.filled(5, null);
}

class SpiteMaliceGameState extends ChangeNotifier {
  SpiteMaliceGameState(this.gameClient) {
    gameClient.subscribe(update);
    moveTracker = MoveTracker(this, playingMoves);
    moveTracker.addListener(notifyListeners);
  }

  final Client gameClient;
  late final MoveTracker<SpiteMaliceId, SpiteMaliceGameState> moveTracker;

  SpiteMalicePhase phase = SpiteMalicePhase.waiting;

  int drawSize = 0;
  List<PlayingCardStack> buildPiles = List.generate(4, (index) => PlayingCardStack());
  int trashSize = 0;

  Map<String, SpiteMaliceTableauState> tableaux = {};
  List<String> opponentRelativeOrder = [];
  String? turnPlayerId;
  String get turnPlayerName => gameClient.players[turnPlayerId]?.name ?? 'another player';

  List<PlayingCard> cutCards = List.filled(12, PlayingCard.back);
  List<String> cutOwners = List.filled(12, '');
  String? dealerId;
  String get dealerName => gameClient.players[dealerId]?.name ?? 'another player';

  String? winnerId;
  String get winnerName => gameClient.players[winnerId]?.name ?? 'some wise guy';

  SpiteMaliceTableauState get myTableau => tableaux[gameClient.playerID] ?? SpiteMaliceTableauState();

  bool hasCut = false;
  bool get isMyDeal => gameClient.playerID == dealerId;
  bool get isMyTurn => gameClient.playerID == turnPlayerId;
  bool get isMyWin => gameClient.playerID == winnerId;
  bool get isHandEmpty => myTableau.hand.every((card) => card == null);

  PlayingCard? discardTop(int discardIndex) {
    return (myTableau.discardPiles[discardIndex].isEmpty ? null : myTableau.discardPiles[discardIndex].last);
  }

  void init() {
    phase = SpiteMalicePhase.waiting;
    gameClient.start();
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
      opponentRelativeOrder = [
        ...ctx.playerOrder.skipWhile((value) => value != gameClient.playerID).skip(1),
        ...ctx.playerOrder.takeWhile((value) => value != gameClient.playerID),
      ];
      if (ctx.isGameOver) {
        turnPlayerId = null;
        phase = SpiteMalicePhase.winning;
        winnerId = ctx.winnerID;
      } else {
        turnPlayerId = ctx.currentPlayer;
        phase = SpiteMalicePhase.playing;
      }
    } else {
      // print(ctx.phase);
      cutCards.fillRange(0, 12, PlayingCard.back);
      cutOwners.fillRange(0, 12, '');
      hasCut = false;
      for (String playerId in players.keys) {
        int? index = players[playerId]['cutIndex'];
        if (index != null) {
          cutCards[index] = _getCard(players[playerId]['cutCard'])!;
          cutOwners[index] = gameClient.players[playerId]?.name ?? 'Unknown player';
          hasCut = hasCut || gameClient.playerID == playerId;
        }
      }
      dealerId = G['dealer']?.toString();
      phase = ctx.phase == 'dealing'
          ? SpiteMalicePhase.dealing
          : SpiteMalicePhase.cutting;
    }
    notifyListeners();
  }

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
    return (card.rank == buildPiles[build.index].size + 1);
  }
}

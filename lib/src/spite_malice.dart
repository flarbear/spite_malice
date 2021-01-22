/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

import 'game_state.dart';
import 'lobby.dart';
import 'move_tracker.dart';

class SpiteMaliceScreen extends StatelessWidget {
  SpiteMaliceScreen(this.gameClient);

  final Client gameClient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('Spite & Malice Game'),
        actions: [
          LobbyName(client: gameClient,),
        ],
      ),
      body: Center(
        child: SpiteMalicePage(gameClient),
      ),
    );
  }
}

class SpiteMalicePage extends StatefulWidget {
  SpiteMalicePage(this.gameClient);

  final Client gameClient;

  @override
  State createState() => SpiteMalicePageState();
}

class SpiteMalicePageState extends State<SpiteMalicePage> {
  late SpiteMaliceGameState state;

  @override
  void initState() {
    super.initState();
    state = SpiteMaliceGameState(widget.gameClient);
    state.addListener(update);
    state.init();
  }

  @override
  void dispose() {
    state.removeListener(update);
    widget.gameClient.stop();
    widget.gameClient.leaveGame();
    super.dispose();
  }

  void update() => setState(() {});

  Widget _dealStatus() {
    if (state.phase == SpiteMalicePhase.cutting) {
      if (state.hasCut) {
        return Text('Waiting for others to pick a card...');
      } else {
        return Text('Pick a card to determine the dealer...');
      }
    } else if (state.isMyDeal) {
      return Text('Click on a card to deal!');
    } else {
      return Text('Waiting for ${state.dealerName} to deal...');
    }
  }

  Widget _playStatus() {
    if (state.phase == SpiteMalicePhase.winning) {
      if (state.winnerId == widget.gameClient.playerID) {
        return Text('You won!!!');
      } else {
        return Text('${state.winnerName} won...');
      }
    } else if (state.isMyTurn) {
      return Text('Your turn...');
    } else {
      return Text('Waiting for ${state.turnPlayerName} to move...');
    }
  }

  static Tableau cutDealTableau = Tableau(
    rows: List.generate(3, (rowIndex) =>
        TableauRow(
          items: List.generate(4, (colIndex) =>
              TableauItem(childId: SpiteMaliceId.cutIds[rowIndex * 4 + colIndex]),
          ),
          innerItemPad: 25,
        ),
    ),
    innerRowPad: 25,
  );

  static Tableau playTableau = Tableau(
    rows: [
      TableauRow(
        items: [
          TableauItem(childId: SpiteMaliceId.drawId, insets: EdgeInsets.only(right: 20)),
          ...SpiteMaliceId.buildIds.map((id) => TableauItem(childId: id)),
          TableauItem(childId: SpiteMaliceId.trashId, insets: EdgeInsets.only(left: 25)),
        ],
      ),
      TableauRow(
          items: [
            TableauItem(childId: SpiteMaliceId.stockId, insets: EdgeInsets.only(right: 20)),
            ...SpiteMaliceId.discardIds.map((id) => TableauItem(childId: id)),
          ]
      ),
      TableauRow(
        insets: EdgeInsets.only(left: 15),
        items: SpiteMaliceId.handIds.map((id) => TableauItem(childId: id)).toList(),
      ),
    ],
    innerRowPad: 25,
  );

  static Tableau opponentTableau = Tableau(
    rows: [
      TableauRow(
          items: [
            TableauItem(childId: SpiteMaliceId.stockId, insets: EdgeInsets.only(right: 20)),
            ...SpiteMaliceId.discardIds.map((id) => TableauItem(childId: id)),
          ]
      ),
      TableauRow(
        insets: EdgeInsets.only(left: 15),
        items: SpiteMaliceId.handIds.map((id) => TableauItem(childId: id)).toList(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // print('building for phase: ${state.phase}');
    switch (state.phase) {
      case SpiteMalicePhase.waiting:
        return Text('Waiting for game state to load');
      case SpiteMalicePhase.cutting:
      case SpiteMalicePhase.dealing:
        return PlayingCardTableau(
          status: _dealStatus(),
          tableauSpec: cutDealTableau,
          items: {
            for (final id in SpiteMaliceId.cutIds)
              id: SinglePlayingCard(state.cutCards[id.index], id: id),
          },
          tracker: state.moveTracker,
        );
      case SpiteMalicePhase.playing:
      case SpiteMalicePhase.winning:
        return Row(
          children: <Widget>[
            PlayingCardTableau(
              status: _playStatus(),
              tableauSpec: playTableau,
              items: {
                SpiteMaliceId.drawId: StackedPlayingCards.hidden(state.drawSize, id: SpiteMaliceId.drawId),
                for (final id in SpiteMaliceId.buildIds)
                  id: StackedPlayingCards(state.buildPiles[id.index], id: id),
                SpiteMaliceId.trashId: StackedPlayingCards.hidden(state.trashSize, id: SpiteMaliceId.trashId),
                SpiteMaliceId.stockId: StackedPlayingCards(state.myTableau.stock, id: SpiteMaliceId.stockId),
                for (final id in SpiteMaliceId.discardIds)
                  id: CascadedPlayingCards(state.myTableau.discardPiles[id.index], 4, id: id),
                for (final id in SpiteMaliceId.handIds)
                  id: SinglePlayingCard(state.myTableau.hand[id.index], id: id),
              },
              tracker: state.isMyTurn ? state.moveTracker : null,
            ),
            SizedBox(width: 75),
            Column(
              children: state.opponentRelativeOrder.map((pid) => PlayingCardTableau(
                status: Text("${state.gameClient.players[pid]!.name}'s cards"),
                tableauSpec: opponentTableau,
                items: {
                  SpiteMaliceId.stockId: StackedPlayingCards(state.tableaux[pid]!.stock, id: SpiteMaliceId.stockId),
                  for (final id in SpiteMaliceId.discardIds)
                    id: CascadedPlayingCards(state.tableaux[pid]!.discardPiles[id.index], 3, id: id),
                  for (final id in SpiteMaliceId.handIds)
                    id: SinglePlayingCard(state.tableaux[pid]!.hand[id.index], id: id),
                },
              )).toList(),
            )
          ],
        );
    }
  }
}

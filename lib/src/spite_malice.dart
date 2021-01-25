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

  Widget _makeCard({
    required String text,
    Color? textColor,
    Color? cardColor,
    double padding = 10,
  }) {
    TextStyle style = Theme.of(context).textTheme.caption ?? TextStyle();
    if (textColor != null) style = style.copyWith(color: textColor);
    style = style.copyWith(fontSize: 20);
    return Card(
      color: cardColor ?? Theme.of(context).canvasColor,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Text(text, style: style),
      ),
    );
  }

  Widget _dealStatus() {
    String statusString;
    Color? cardColor;
    if (state.phase == SpiteMalicePhase.cutting) {
      if (state.hasCut) {
        statusString = 'Waiting for others to pick a card...';
        cardColor = Theme.of(context).scaffoldBackgroundColor;
      } else {
        statusString = 'Pick a card to determine the dealer...';
      }
    } else if (state.isMyDeal) {
      statusString = 'Click on a card to deal!';
    } else {
      statusString = 'Waiting for ${state.dealerName} to deal...';
      cardColor = Theme.of(context).scaffoldBackgroundColor;
    }
    return _makeCard(text: statusString, cardColor: cardColor);
  }

  Widget _playStatus() {
    String statusString;
    Color? cardColor;
    Color? textColor;
    if (state.phase == SpiteMalicePhase.winning) {
      if (state.isMyWin) {
        statusString = 'You won!!!';
        cardColor = Colors.lightGreen;
        textColor = Colors.yellow.shade400;
      } else {
        statusString = state.winnerId == null ? 'Draw game...' : '${state.winnerName} won...';
        cardColor = Colors.indigoAccent;
      }
    } else if (state.isMyTurn) {
      statusString = 'Your turn...';
      cardColor = Theme.of(context).canvasColor;
    } else {
      statusString = 'Waiting for ${state.turnPlayerName} to move...';
      cardColor = Theme.of(context).scaffoldBackgroundColor;
    }
    return _makeCard(text: statusString, cardColor: cardColor, textColor: textColor);
  }

  Widget _opponentStatus(String id) {
    String name = state.gameClient.players[id]!.name;
    if (state.winnerId == id) return Text('$name won!', style: TextStyle(color: Colors.yellow));
    if (state.turnPlayerId == id) return Text("$name's turn...");
    return Text("$name's cards");
  }

  static Tableau cutDealTableau = Tableau(
    insets: EdgeInsets.all(10.0),
    innerRowPad: 25,
    rows: List.generate(3, (rowIndex) =>
        TableauRow(
          innerItemPad: 25,
          items: List.generate(4, (colIndex) =>
              TableauItem(childId: SpiteMaliceId.cutIds[rowIndex * 4 + colIndex]),
          ),
        ),
    ),
  );

  static Tableau playTableau = Tableau(
    insets: EdgeInsets.all(10.0).copyWith(bottom: 20.0),
    innerRowPad: 25,
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
        insets: EdgeInsets.only(left: 65),
        items: SpiteMaliceId.handIds.map((id) => TableauItem(childId: id)).toList(),
      ),
    ],
  );

  static Tableau opponentTableau = Tableau(
    insets: EdgeInsets.all(15.0).copyWith(top: 5),
    scale: 0.5,
    rows: [
      TableauRow(
          items: [
            TableauItem(childId: SpiteMaliceId.stockId, insets: EdgeInsets.only(right: 20)),
            ...SpiteMaliceId.discardIds.map((id) => TableauItem(childId: id)),
          ]
      ),
      TableauRow(
        scale: 0.5,
        insets: EdgeInsets.only(left: 240),
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
          backgroundColor: state.isMyDeal ? Theme.of(context).canvasColor : null,
        );
      case SpiteMalicePhase.playing:
      case SpiteMalicePhase.winning:
        StackedPlayingCardsCaption drawCaption;
        StackedPlayingCardsCaption buildCaption;
        if (defaultCardStyle.rendersWildRanks) {
          drawCaption = StackedPlayingCardsCaption.hover;
          buildCaption = StackedPlayingCardsCaption.ranked;
        } else {
          drawCaption = buildCaption = StackedPlayingCardsCaption.standard;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PlayingCardTableau(
              status: _playStatus(),
              tableauSpec: playTableau,
              items: {
                SpiteMaliceId.drawId: StackedPlayingCards.hidden(state.drawSize, id: SpiteMaliceId.drawId, caption: drawCaption,),
                for (final id in SpiteMaliceId.buildIds)
                  id: StackedPlayingCards(state.buildPiles[id.index], id: id, caption: buildCaption,),
                SpiteMaliceId.trashId: StackedPlayingCards.hidden(state.trashSize, id: SpiteMaliceId.trashId, caption: drawCaption,),
                SpiteMaliceId.stockId: StackedPlayingCards(state.myTableau.stock, id: SpiteMaliceId.stockId, caption: drawCaption),
                for (final id in SpiteMaliceId.discardIds)
                  id: CascadedPlayingCards(state.myTableau.discardPiles[id.index], 4, id: id),
                for (final id in SpiteMaliceId.handIds)
                  id: SinglePlayingCard(state.myTableau.hand[id.index], id: id),
              },
              tracker: state.isMyTurn ? state.moveTracker : null,
              backgroundColor: state.isMyTurn ? Theme.of(context).canvasColor : null,
            ),
            SizedBox(width: 75),
            Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: state.opponentRelativeOrder.map((pid) => PlayingCardTableau(
                    status: _opponentStatus(pid),
                    tableauSpec: opponentTableau,
                    items: {
                      SpiteMaliceId.stockId: StackedPlayingCards(
                        state.tableaux[pid]!.stock,
                        id: SpiteMaliceId.stockId,
                        caption: StackedPlayingCardsCaption.hover,
                      ),
                      for (final id in SpiteMaliceId.discardIds)
                        id: CascadedPlayingCards(state.tableaux[pid]!.discardPiles[id.index], 3, id: id),
                      for (final id in SpiteMaliceId.handIds)
                        id: SinglePlayingCard(state.tableaux[pid]!.hand[id.index], id: id),
                    },
                    backgroundColor: state.turnPlayerId == pid ? Colors.green.shade400 : null,
                  )).toList(),
                ),
              ),
            ),
          ],
        );
    }
  }
}

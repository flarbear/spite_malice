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

import 'card_widgets.dart';
import 'game_state.dart';
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
  late MoveTracker playingTracker;
  late MoveTracker cutDealTracker;
  late SpiteMaliceGameStateCancel listenCancel;

  @override
  void initState() {
    super.initState();
    state = SpiteMaliceGameState(widget.gameClient);
    playingTracker = MoveTracker<SpiteMaliceId, SpiteMaliceGameState>(state, SpiteMaliceMoveTracker.playingMoves);
    cutDealTracker = MoveTracker<SpiteMaliceId, SpiteMaliceGameState>(state, SpiteMaliceMoveTracker.cutDealMoves);
    listenCancel = state.listen(() => setState(() => {}));
    state.init();
    widget.gameClient.subscribe(state.update);
    widget.gameClient.start();
  }

  @override
  void dispose() {
    listenCancel();
    widget.gameClient.stop();
    widget.gameClient.leaveGame();
    super.dispose();
  }

  Widget _dealerLine() {
    if (state.phase == SpiteMalicePhase.cutting) {
      if (state.hasCut) {
        return Text('Waiting for others to pick a card...');
      } else {
        return Text('Pick a card to determine the dealer...');
      }
    } else if (state.isMyDeal) {
      return Text('Click on a card to deal!');
    } else {
      return Text('Waiting for ${widget.gameClient.players[state.dealerId]!.name} to deal...');
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('building for phase: ${state.phase}');
    switch (state.phase) {
      case SpiteMalicePhase.waiting:
        return Text('Waiting for game state to load');
      case SpiteMalicePhase.cutting:
      case SpiteMalicePhase.dealing:
        return Column(
          children: <Widget>[
            _dealerLine(),
            SpiteMaliceCutDeal(
              cards: state.cutCards,
              tracker: cutDealTracker,
            ),
          ],
        );
      case SpiteMalicePhase.playing:
        return Row(
          children: <Widget>[
            Column(
              children: <Widget>[
                SpiteMaliceBuild(
                  drawSize: state.drawSize,
                  buildTops: state.buildTops,
                  buildSizes: state.buildSizes,
                  trashSize: state.trashSize,
                  tracker: state.isMyTurn ? playingTracker : null,
                ),
                SizedBox(height: 20),
                SpiteMaliceTableau(
                  tableau: state.myTableau,
                  tracker: state.isMyTurn ? playingTracker : null,
                ),
              ],
            ),
            SizedBox(width: 200),
            Column(
              children: state.tableaux.keys
                  .where((id) => id != state.gameClient.playerID)
                  .map((id) => SpiteMaliceTableau(tableau: state.tableaux[id]!))
                  .toList(),
            )
          ],
        );
    }
  }
}

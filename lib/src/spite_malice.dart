import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/material.dart';
import 'package:spite_malice/src/move_tracker.dart';

import 'cards.dart';
import 'game_state.dart';
import 'card_widgets.dart';

class SpiteMaliceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Client gameClient = ModalRoute.of(context)!.settings.arguments! as Client;
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
  late SpiteMaliceMoveTracker tracker;

  @override
  void initState() {
    super.initState();
    state = SpiteMaliceGameState(widget.gameClient);
    tracker = SpiteMaliceMoveTracker(state);
    state.listen(() => setState(() => {}));
    state.init();
    widget.gameClient.subscribe(state.update);
    widget.gameClient.start();
  }

  @override
  void dispose() {
    widget.gameClient.stop();
    widget.gameClient.leaveGame();
    super.dispose();
  }

  Widget _cutCardWidget(List<SpiteMaliceCard> cards, int index) {
    return GestureDetector(
      onTap: () {
        print('chose $index');
        if (state.phase == SpiteMalicePhase.dealing) {
          state.deal();
        } else {
          state.cutDeck(index);
        }
      },
      child: Padding(
        padding: EdgeInsets.all(5.0),
        child: SizedBox(
          width:   90,
          height: 140,
          child: SpiteMaliceCardWidget(cards[index], highlighted: state.amDealer,),
        ),
      ),
    );
  }

  Widget _dealerLine() {
    if (state.phase == SpiteMalicePhase.cutting) {
      if (state.hasCut) {
        return Text('Waiting for others to pick a card...');
      } else {
        return Text('Pick a card to determine the dealer...');
      }
    } else if (state.amDealer) {
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
        return SizedBox(
          width: 500,
          height: 500,
          child: Column(
            children: <Widget>[
              _dealerLine(),
              ...[0, 4, 8].map((rowIndex) =>
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [0, 1, 2, 3].map((colIndex) =>
                        _cutCardWidget(state.cutCards, rowIndex + colIndex)
                    ).toList(),
                  )
              ).toList(),
            ],
          ),
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
                  tracker: state.isMyTurn ? tracker : null,
                ),
                SizedBox(height: 20),
                SpiteMaliceTableau(
                  tableau: state.myTableau,
                  tracker: state.isMyTurn ? tracker : null,
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

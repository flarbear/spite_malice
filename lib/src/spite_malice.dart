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
import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';
import 'lobby.dart';
import 'move_tracker.dart';

class SpiteMaliceScreen extends StatelessWidget {
  SpiteMaliceScreen({
    required Client gameClient,
    String? gameName,
  })
      : assert(gameClient.game.description.name == 'Spite-Malice'),
        this.gameClient = gameClient,
        this.gameState = SpiteMaliceGameState(gameClient),
        this.gameName = gameName ?? gameClient.game.description.name {
    gameState.init();
  }

  final Client gameClient;
  final String gameName;
  final ValueNotifier<CardStyle> cardStyleNotifier = ValueNotifier(defaultCardStyle);
  final SpiteMaliceGameState gameState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('$gameName Game'),
        actions: [
          if (allCardStyles.length > 1)
            CardStyleSelector(
              notifier: cardStyleNotifier,
              validator: (style) => style.numRanks >= 12,
            ),
          LobbyName(client: gameClient),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          print('tapped on nowhere');
          gameState.moveTracker.hoveringOver(null, true);
          },
        child: Center(
          child: SpiteMalicePage(
            gameState: gameState,
            cardStyleNotifier: cardStyleNotifier,
          ),
        ),
      ),
    );
  }
}

const String _pref_prefix = 'boardgame.io:spite-malice:';

Future<String> _getPrefString(String key, String defaultValue) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_pref_prefix$key') ?? defaultValue;
}

Future<void> _setPrefString(String key, String value) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('$_pref_prefix$key', value);
}

const String playingCardStyleKey = 'playing-card-style';

class CardStyleSelector extends StatefulWidget {
  CardStyleSelector({required this.notifier, this.validator = _defaultValidator});

  static bool _defaultValidator(CardStyle style) => true;

  final ValueNotifier<CardStyle> notifier;
  final bool Function(CardStyle) validator;

  @override
  State createState() => CardStyleSelectorState();
}

class CardStyleSelectorState extends State<CardStyleSelector> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_update);
    _initStyle();
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  CardStyle? _styleFor(String name) {
    for (final style in allCardStyles) {
      if (style.name == name) {
        return style;
      }
    }
    return null;
  }

  void _initStyle() async {
    String cardStyleName = await _getPrefString(playingCardStyleKey, widget.notifier.value.name);
    _updateStyle(_styleFor(cardStyleName));
  }

  void _updateStyle(CardStyle? newStyle) async {
    if (newStyle == null) return;
    await _setPrefString(playingCardStyleKey, newStyle.name);
    widget.notifier.value = newStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.0),
      child: IntrinsicWidth(
        child: DropdownButtonFormField<CardStyle>(
          value: widget.notifier.value,
          onChanged: _updateStyle,
          items: allCardStyles.where(widget.validator).map((style) {
            return DropdownMenuItem<CardStyle>(child: Text(style.name), value: style);
          }).toList(),
          decoration: InputDecoration(
            labelText: 'Card Style',
            contentPadding: EdgeInsets.only(top: 10),
            border: UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

class SpiteMalicePage extends StatefulWidget {
  SpiteMalicePage({required this.gameState, this.cardStyleNotifier});

  final ValueNotifier<CardStyle>? cardStyleNotifier;
  final SpiteMaliceGameState gameState;

  @override
  State createState() => SpiteMalicePageState();
}

class SpiteMalicePageState extends State<SpiteMalicePage> {
  SpiteMaliceGameState get state => widget.gameState;
  Client get client => state.gameClient;

  @override
  void initState() {
    super.initState();
    widget.cardStyleNotifier?.addListener(_update);
    state.addListener(_update);
  }

  @override
  void dispose() {
    state.removeListener(_update);
    client.stop();
    client.leaveGame();
    widget.cardStyleNotifier?.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  Widget _makeStatus({
    required String text,
    Color? textColor,
    Color? backgroundColor,
    double padding = 10,
  }) {
    TextStyle style = Theme.of(context).textTheme.caption ?? TextStyle();
    if (textColor != null) style = style.copyWith(color: textColor);
    style = style.copyWith(fontSize: 20);
    return Card(
      color: backgroundColor ?? Theme.of(context).canvasColor,
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
    return _makeStatus(text: statusString, backgroundColor: cardColor);
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
    return _makeStatus(text: statusString, backgroundColor: cardColor, textColor: textColor);
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
    scale: 0.75,
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
    CardStyle cardStyle = widget.cardStyleNotifier?.value ?? defaultCardStyle;
    switch (state.phase) {
      case SpiteMalicePhase.waiting:
        return Text('Waiting for game state to load');
      case SpiteMalicePhase.cutting:
      case SpiteMalicePhase.dealing:
        return PlayingCardTableau(
          style: cardStyle,
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
        if (cardStyle.rendersWildRanks) {
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
              style: cardStyle,
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
                    style: cardStyle,
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

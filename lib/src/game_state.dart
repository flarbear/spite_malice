import 'package:boardgame_io/boardgame.dart';
import 'package:spite_malice/src/move_tracker.dart';

import 'cards.dart';

enum SpiteMalicePhase {
  waiting,
  cutting,
  dealing,
  playing,
}

class SpiteMaliceStackId {
  const SpiteMaliceStackId._unique(this.name) : this.index = -1;
  const SpiteMaliceStackId._indexed(this.name, this.index);

  final String name;
  final int index;

  static List<SpiteMaliceStackId> _makeList(String baseName, int size) {
    return List.generate(size, (i) => SpiteMaliceStackId._indexed('$baseName${i+1}', i));
  }

  static List<SpiteMaliceStackId> cutIds = _makeList('cut', 12);

  static SpiteMaliceStackId drawId = SpiteMaliceStackId._unique('draw');
  static List<SpiteMaliceStackId> buildIds = _makeList('build', 4);
  static SpiteMaliceStackId trashId = SpiteMaliceStackId._unique('trash');

  static SpiteMaliceStackId stockId = SpiteMaliceStackId._unique('stock');
  static List<SpiteMaliceStackId> discardIds = _makeList('discard', 4);

  static List<SpiteMaliceStackId> handIds = _makeList('hand', 5);

  @override
  String toString() => 'SpiteMaliceStackId($name, $index)';
}

typedef SpiteMaliceGameStateListener = void Function();

typedef SpiteMaliceGameStateCancel = void Function();

class SpiteMaliceTableauState {
  SpiteMaliceCard? stockTop;
  int stockSize = 0;
  List<List<SpiteMaliceCard>> discardPiles = List<List<SpiteMaliceCard>>.generate(4, (index) => <SpiteMaliceCard>[]);
  List<SpiteMaliceCard?>? hand;
}

class SpiteMaliceGameState {
  SpiteMaliceGameState(this.gameClient);

  final Client gameClient;

  SpiteMalicePhase phase = SpiteMalicePhase.waiting;

  int drawSize = 0;
  List<SpiteMaliceCard?> buildTops = List<SpiteMaliceCard?>.generate(4, (index) => null);
  List<int> buildSizes = List<int>.generate(4, (index) => 0);
  int trashSize = 0;

  Map<String, SpiteMaliceTableauState> tableaux = {};

  List<SpiteMaliceCard> cutCards = List<SpiteMaliceCard>.generate(12, (index) => SpiteMaliceCard.back);
  String? dealerId;

  SpiteMaliceStackId? highlightFrom;
  Map<SpiteMaliceStackId, SpiteMaliceMove>? validMoves;
  bool get selected => validMoves != null;
  SpiteMaliceStackId? highlightTo;

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
  bool hasCut = false;
  bool amDealer = false;
  bool get isHandEmpty => myTableau.hand!.every((card) => card == null);

  SpiteMaliceCard? discardTop(int discardIndex) {
    return (myTableau.discardPiles[discardIndex].isEmpty ? null : myTableau.discardPiles[discardIndex].last);
  }

  void init() {
    phase = SpiteMalicePhase.waiting;
    notify();
  }

  void setHighlightFrom(SpiteMaliceStackId? type) {
    if (!selected && highlightFrom != type) {
      // print('highlight from changed from $highlightFrom to $type');
      highlightFrom = type;
      notify();
    }
  }

  void setSelected(Map<SpiteMaliceStackId, SpiteMaliceMove>? moves) {
    // print('setSelected($moves).length');
    this.validMoves = moves;
    notify();
  }

  void setHighlightTo(SpiteMaliceStackId? type) {
    if (selected && highlightTo != type) {
      // print('highlight to changed from $highlightFrom to $type');
      highlightTo = type;
      notify();
    }
  }

  void clearHighlight() {
    highlightFrom = highlightTo = null;
    validMoves = null;
    notify();
  }

  SpiteMaliceCard? _getCard(Map<String,dynamic>? gCard) {
    if (gCard == null) return null;
    if (gCard['isWild']) return SpiteMaliceCard.wild;
    int suitIndex = gCard['suit'];
    int rankIndex = gCard['rank'];
    return SpiteMaliceCard(suitIndex, rankIndex);
  }

  void update(Map<String, dynamic> G, ClientContext ctx) {
    // print('update!');
    Map<String, dynamic> players = G['players'];
    if (ctx.phase == null) {
      drawSize = G['drawSize'];
      List<dynamic> buildPiles = G['buildPiles'];
      for (int i = 0; i < 4; i++) {
        buildSizes[i] = buildPiles[i].length;
        buildTops[i] = buildSizes[i] == 0 ? null : _getCard(buildPiles[i].last as Map<String,dynamic>);
      }
      trashSize = G['completedSize'];
      for (String playerID in G['players'].keys) {
        SpiteMaliceTableauState? tableau = tableaux[playerID];
        if (tableau == null) {
          tableaux[playerID] = tableau = SpiteMaliceTableauState();
        }
        Map<String,dynamic> player = G['players'][playerID];
        tableau.stockSize = player['stockSize'];
        tableau.stockTop = tableau.stockSize == 0 ? null : _getCard(player['stockTop']);
        for (int i = 0; i < 4; i++) {
          tableau.discardPiles[i] = player['discardPiles'][i].map<SpiteMaliceCard>((card) => _getCard(card)!).toList();
        }
        tableau.hand = player['hand']?.map<SpiteMaliceCard?>((card) => _getCard(card)).toList();
      }
      assert(tableaux[gameClient.playerID] != null && tableaux[gameClient.playerID]!.hand != null);
      isMyTurn = ctx.currentPlayer == gameClient.playerID;
      // print('done processing update');
      // print('drawSize: $drawSize');
      // for (int i = 0; i < 4; i++) {
      //   print('build[$i] = ${buildTops[i]} / ${buildSizes[i]}');
      // }
      // print('trashSize: $trashSize');
      // print('stock: ${myTableau.stockTop} / ${myTableau.stockSize}');
      // for (int i = 0; i < 4; i++) {
      //   print('discard[$i] = ${myTableau.discardPiles[i].join(', ')}');
      // }
      // print('hand: ${myTableau.hand!.join(', ')}');
      phase = SpiteMalicePhase.playing;
    } else {
      print(ctx.phase);
      cutCards.fillRange(0, 12, SpiteMaliceCard.back);
      for (String playerId in players.keys) {
        int? index = players[playerId]['cutIndex'];
        if (index != null) {
          cutCards[index] = _getCard(players[playerId]['cutCard'])!;
        }
      }
      hasCut = players[gameClient.playerID]['cutIndex'] != null;
      dealerId = G['dealer'].toString();
      amDealer = dealerId == gameClient.playerID;
      phase = ctx.phase == 'dealing'
          ? SpiteMalicePhase.dealing
          : SpiteMalicePhase.cutting;
    }
    notify();
  }

  void deal() {
    gameClient.makeMove('deal', []);
  }

  void cutDeck(int i) {
    gameClient.makeMove('cutDeck', [ i ]);
  }
}

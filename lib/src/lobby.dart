import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/material.dart';

class LobbyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('Spite-Malice Lobby'),
      ),
      body: Center(
        child: LobbyPage(),
      ),
    );
  }
}

class LobbyPage extends StatefulWidget {
  @override
  State createState() => LobbyPageState();
}

Uri _getBase() {
  if (Uri.base.scheme == 'file') {
    return Uri.parse('http://localhost:8000/');
  }
  return Uri.base;
}

class LobbyPageState extends State<LobbyPage> {
  final Lobby lobby = Lobby(_getBase());

  List<String>? _allGames;
  String? _gameName;

  List<MatchData>? _allMatches;
  int _numPlayers = 2;
  int _stockSize = 20;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadGames() async {
    List<String> games = await lobby.listGames();
    setState(() {
      _allGames = games;
    });
    if (games.length == 1) {
      _pickedGame(games.first);
    }
  }

  void _pickedGame(String name) {
    setState(() {
      _gameName = name;
    });
    _loadMatches();
  }

  void _loadMatches() async {
    List<MatchData> matches = await lobby.listMatches(_gameName!);
    setState(() {
      _allMatches = matches;
    });
  }

  void _joinMatch(BuildContext context, MatchData match, String playerID) async {
    Client client = await lobby.joinMatch(match.toGame(), playerID, 'Bob');
    Navigator.pushNamed(context, '/play', arguments: client);
  }

  void _createMatch(BuildContext context) async {
    GameDescription desc = GameDescription(_gameName!, _numPlayers, setupData: {
      'stockSize': _stockSize,
    });
    MatchData match = await lobby.createMatch(desc);
    _joinMatch(context, match, match.players[0].id);
  }

  @override
  Widget build(BuildContext context) {
    if (_allGames == null) {
      return Center(child: Text('Loading list of games'));
    }
    if (_gameName == null) {
      return Center(
        child: DropdownButton<String>(
          onChanged: (name) => _pickedGame(name!),
          items: _allGames!.map((name) => DropdownMenuItem(child: Text(name), value: name,)).toList(),
        ),
      );
    }
    if (_allMatches == null) {
      return Center(child: Text('Loading list of matches'));
    }
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ..._allMatches!
              .where((match) => match.canJoin)
              .map((match) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text('${match.gameName} Match Created: ${match.createdAt}'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('Seats: '),
                    ...match.players.map((player) {
                      return RaisedButton(
                        onPressed: player.isSeated ? null : () => _joinMatch(context, match, player.id),
                        child: Text(player.isSeated ? player.seatedName! : 'Open Seat'),
                      );
                    }),
                  ],
                ),
              ],
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Number of Players: '),
              DropdownButton<int>(
                value: _numPlayers,
                onChanged: (value) => setState(() => _numPlayers = value!),
                items: [1, 2, 3, 4, 5, 6]
                    .map((n) => DropdownMenuItem(child: Text('$n Players'), value: n))
                    .toList(),
              ),
              Text('Size of stock pile: '),
              DropdownButton<int>(
                value: _stockSize,
                onChanged: (value) => setState(() => _stockSize = value!),
                items: [15, 20, 23, 25, 30]
                    .map((n) => DropdownMenuItem(child: Text('$n Cards'), value: n))
                    .toList(),
              ),
              RaisedButton(
                onPressed: () => _createMatch(context),
                child: Text('Create New Game'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

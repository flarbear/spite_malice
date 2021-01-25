/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'dart:async';

import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _pref_prefix = 'boardgame.io:';

Future<String> _getPrefString(String key, String defaultValue) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_pref_prefix$key') ?? defaultValue;
}

Future<void> _setPrefString(String key, String value) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString('$_pref_prefix$key', value);
}

const String playerNameKey = 'player-name';

class LobbyScreen extends StatelessWidget {
  LobbyScreen({
    required this.siteName,
    this.supportedGames = const [],
  });

  final String siteName;
  final List<String> supportedGames;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: color ?? Theme.of(context).backgroundColor,
      appBar: AppBar(
        title: Text('$siteName Lobby'),
        actions: [
          LobbyName(),
        ],
      ),
      body: Center(
        child: LobbyPage(
          supportedGames: supportedGames,
        ),
      ),
    );
  }
}

class LobbyName extends StatefulWidget {
  LobbyName({this.client});

  final Client? client;

  @override
  State createState() => LobbyNameState();
}

class LobbyNameState extends State<LobbyName> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _initName();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initName() async {
    _controller.text = await _getPrefString(playerNameKey, 'Unknown Player');
  }

  void _updateName(String newName) async {
    await _setPrefString(playerNameKey, newName);
    Client? client = widget.client;
    if (client != null) {
      await client.updateName(newName);
      client.stop();
      client.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      child: TextField(
        controller: _controller,
        maxLength: 30,
        decoration: InputDecoration(
          labelText: 'Player name',
          contentPadding: EdgeInsets.only(top: 10),
          border: UnderlineInputBorder(),
          focusedBorder: UnderlineInputBorder(),
          counter: Offstage(),
        ),
        onSubmitted: (value) => _updateName(value),
      ),
    );
  }
}

class LobbyPage extends StatefulWidget {
  LobbyPage({
    this.supportedGames = const [],
  });

  final List<String> supportedGames;

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

  Timer? _matchTimer;
  List<MatchData>? _allMatches;
  int _numPlayers = 2;
  int _stockSize = 20;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void didUpdateWidget(LobbyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _allMatches = null;
    _gameName = null;
    _allGames = null;
    _matchTimer?.cancel();
    _matchTimer = null;
    _loadGames();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _matchTimer = null;
    super.dispose();
  }

  void _loadGames() async {
    List<String> games = (await lobby.listGames())
        .where((gameName) => widget.supportedGames.contains(gameName))
        .toList();
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
      _allMatches = matches.where((match) => match.canJoin).toList();
      if (_matchTimer == null) {
        _matchTimer = Timer.periodic(Duration(seconds: 5), (timer) { _loadMatches(); });
      }
    });
  }

  void _joinMatch(BuildContext context, MatchData match, String playerID) async {
    String name = await _getPrefString(playerNameKey, 'Unknown Player');
    Client client = await lobby.joinMatch(match.toGame(), playerID, name);
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
        children: <Widget>[
          SizedBox(height: 20.0),
          if (_allMatches!.isNotEmpty)
            Text('Choose a seat in an existing match:'),
          ..._allMatches!.map((match) {
            return Card(
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text('${match.gameName} Match Created: ${match.createdAt}'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Seats: '),
                        ...match.players.map((player) {
                          return Padding(
                            padding: EdgeInsets.all(5.0),
                            child: ElevatedButton(
                              onPressed: player.isSeated ? null : () => _joinMatch(context, match, player.id),
                              child: Text(player.seatedName ?? 'Open Seat'),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 20.0),
          _allMatches!.isEmpty ? Text('Create a match:') : Text('Or, create a new match:'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Table(
                    defaultColumnWidth: IntrinsicColumnWidth(),
                    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <TableRow>[
                      TableRow(
                        children: <Widget>[
                          Text('Number of Players:', textAlign: TextAlign.end),
                          SizedBox(width: 5),
                          DropdownButton<int>(
                            value: _numPlayers,
                            onChanged: (value) => setState(() => _numPlayers = value!),
                            items: List.generate(6, (n) => DropdownMenuItem<int>(child: Text('${n+1} Players'), value: n+1)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          Text('Size of stock pile:', textAlign: TextAlign.end),
                          SizedBox(width: 5),
                          DropdownButton<int>(
                            value: _stockSize,
                            onChanged: (value) => setState(() => _stockSize = value!),
                            items: [15, 20, 23, 25, 30]
                                .map((n) => DropdownMenuItem(child: Text('$n Cards'), value: n))
                                .toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(width: 20.0),
                  ElevatedButton(
                    onPressed: () => _createMatch(context),
                    child: Text('Create New Game'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

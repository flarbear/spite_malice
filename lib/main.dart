/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:boardgame_io/boardgame.dart';
import 'package:flutter/material.dart';

import 'src/spite_malice.dart';

String _playerNameKey = 'boardgame.io:spite-malice:player-name';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({ this.name = 'Spite & Malice' });

  final String name;
  final Lobby lobby = Lobby(getDefaultLobbyBase(), playerNamePreferenceKey: _playerNameKey);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      title: name,
      routes: {
        '/': (context) => LobbyScreen(
          siteName: name,
          lobby: lobby,
          supportedGames: [
            GameProperties(
              protocolName: 'Spite-Malice',
              displayName: name,
              playerCountOption: PlayerCountOption(1, 6, 2),
              setupOptions: [
                IntListGameOption(
                  setupDataName: 'stockSize',
                  prompt: 'Size of Stock Pile',
                  values: [15, 20, 23, 25, 30],
                  itemName: 'Card',
                  defaultIndex: 1,
                ),
              ],
            ),
          ],
        ),
        '/play': (context) {
          Client client = ModalRoute.of(context)!.settings.arguments! as Client;
          switch (client.game.description.name) {
            case 'Spite-Malice': return SpiteMaliceScreen(gameClient: client, gameName: name);
            default: throw 'Unrecognized game "${client.game.description.name}"';
          }
        }
      },
      theme: ThemeData(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.green,
        cardTheme: CardTheme(
          color: Colors.green.shade600,
          margin: EdgeInsets.all(5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            side: BorderSide(
              color: Colors.green.shade700,
              width: 2.0,
            ),
          ),
        ),
        canvasColor: Colors.green.shade400,
        buttonColor: Colors.green.shade400,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.grey,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateColor.resolveWith((states) => Colors.green.shade400),
          ),
        ),
      ),
    );
  }
}

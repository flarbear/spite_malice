/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:flutter/material.dart';
import 'src/lobby.dart';
import 'src/spite_malice.dart';

import 'package:boardgame_io/boardgame.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      title: 'Spite & Malice',
      routes: {
        '/': (context) => LobbyScreen(supportedGames: const [ 'Spite-Malice' ]),
        '/play': (context) {
          Client client = ModalRoute.of(context)!.settings.arguments! as Client;
          switch (client.game.description.name) {
            case 'Spite-Malice': return SpiteMaliceScreen(client);
            default: throw 'Unrecognized game "${client.game.description.name}"';
          }
        }
      },
      theme: ThemeData(
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.grey,
          selectionColor: Colors.grey,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'src/lobby.dart';
import 'src/spite_malice.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      title: 'Spite & Malice',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/': (context) => LobbyScreen(),
        '/play': (context) => SpiteMaliceScreen(),
      },
    );
  }
}

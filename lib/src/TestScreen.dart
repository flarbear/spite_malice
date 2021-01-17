/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:flutter/material.dart';

import 'package:playing_cards/playing_cards.dart';

class TestScreen extends StatefulWidget {
  TestScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  Widget _wrap(Widget child) {
    return Padding(
      padding: EdgeInsets.all(5.0),
      child: SizedBox(
        width:   90,
        height: 140,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int suit = 0; suit < 4; suit++)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _wrap(PlayingCardWidget(null)),
                  _wrap(PlayingCardWidget(PlayingCard.back)),
                  for (int rank = 0; rank <= 12; rank++)
                    _wrap(PlayingCardWidget(PlayingCard(suit: suit, rank:rank))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

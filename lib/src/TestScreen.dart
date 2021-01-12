import 'package:flutter/material.dart';

import 'cards.dart';
import 'card_widgets.dart';

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
                  _wrap(SpiteMaliceCardWidget(null)),
                  _wrap(SpiteMaliceCardWidget(SpiteMaliceCard.back)),
                  for (int rank = 0; rank <= 12; rank++)
                    _wrap(SpiteMaliceCardWidget(SpiteMaliceCard(suit, rank))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

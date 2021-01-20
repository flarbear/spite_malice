/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

import 'game_state.dart';
import 'move_tracker.dart';

class SpiteMaliceTableauLayout extends TableauLayoutBase {
  static TableauSpec specWithHand = TableauSpec(
    rows: [
      TableauRowSpec(
          groups: [
            TableauEntry(childId: SpiteMaliceId.stockId, insets: EdgeInsets.only(right: 20)),
            ...SpiteMaliceId.discardIds.map((id) => TableauEntry(childId: id)),
          ]
      ),
      TableauRowSpec(
        insets: EdgeInsets.only(left: 15),
        groups: SpiteMaliceId.handIds.map((id) => TableauEntry(childId: id)).toList(),
      ),
    ],
    innerRowPad: 15,
  );

  static TableauSpec specWithoutHand = TableauSpec(
    rows: [
      TableauRowSpec(
          groups: [
            TableauEntry(childId: SpiteMaliceId.stockId, insets: EdgeInsets.only(right: 20)),
            ...SpiteMaliceId.discardIds.map((id) => TableauEntry(childId: id)),
          ]
      ),
    ],
  );

  SpiteMaliceTableauLayout(this.maxDiscard, this.hasHand, [ this.tracker ]) : super(
    hasHand ? specWithHand : specWithoutHand,
    defaultCardStyle,
    rowHeights: [
      max(maxDiscard - 1, 0) * defaultCardStyle.cascadeOffset + defaultCardStyle.height,
      if (hasHand) defaultCardStyle.height,
    ],
  );

  final MoveTracker? tracker;
  final int maxDiscard;
  final bool hasHand;

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) {
    if (super.shouldRelayout(oldDelegate))
      return true;
    if (oldDelegate is SpiteMaliceTableauLayout) {
      return oldDelegate.maxDiscard != this.maxDiscard
          || oldDelegate.hasHand != this.hasHand;
    }
    return true;
  }
}

class SpiteMaliceTableau extends StatelessWidget {
  SpiteMaliceTableau({
    required this.tableau,
    this.tracker,
  })
      : assert(tableau.discardPiles.length == 4),
        assert(tableau.hand.length == 5);

  final SpiteMaliceTableauState tableau;
  final MoveTracker? tracker;

  @override
  Widget build(BuildContext context) {
    int maxDiscard = tableau.discardPiles.fold<int>(3, (prev, pile) => max(prev, pile.length));
    List<PlayingCard?>? hand = tableau.hand;
    return CustomMultiChildLayout(
      delegate: SpiteMaliceTableauLayout(maxDiscard, true),
      children: <Widget>[
        PlayingCardStackWidget.tracked(tracker, SpiteMaliceId.stockId, true, tableau.stock),
        for (int i = 0; i < 4; i++)
          PlayingCardPileWidget.tracked(tracker, SpiteMaliceId.discardIds[i], true, tableau.discardPiles[i], 3),
        for (int i = 0; i < 5; i++)
          PlayingCardWidget.tracked(tracker, SpiteMaliceId.handIds[i], true, hand[i]),
      ],
    );
  }
}

class SpiteMaliceBuildLayout extends TableauLayoutBase {
  static TableauSpec buildSpec = TableauSpec(
    rows: [
      TableauRowSpec(
        groups: [
          TableauEntry(childId: SpiteMaliceId.drawId, insets: EdgeInsets.only(right: 20)),
          ...SpiteMaliceId.buildIds.map((id) => TableauEntry(childId: id)),
          TableauEntry(childId: SpiteMaliceId.trashId, insets: EdgeInsets.only(left: 25)),
        ],
        insets: EdgeInsets.only(bottom: 25),
      ),
    ],
  );

  SpiteMaliceBuildLayout() : super(buildSpec, defaultCardStyle);

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => oldDelegate is! SpiteMaliceBuildLayout;
}

class SpiteMaliceBuild extends StatelessWidget {
  SpiteMaliceBuild({
    required this.drawSize,
    required this.buildPiles,
    required this.trashSize,
    this.tracker,
  })
      : assert(buildPiles.length == 4);

  final int drawSize;
  final List<PlayingCardStack> buildPiles;
  final int trashSize;
  final MoveTracker? tracker;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: SpiteMaliceBuildLayout(),
      children: <Widget>[
        PlayingCardStackWidget.tracked(tracker, SpiteMaliceId.drawId, true, PlayingCardStack.hidden(drawSize)),
        for (int i = 0; i < 4; i++)
          PlayingCardStackWidget.tracked(tracker, SpiteMaliceId.buildIds[i], true, buildPiles[i]),
        PlayingCardStackWidget.tracked(tracker, SpiteMaliceId.trashId, true, PlayingCardStack.hidden(trashSize)),
      ],
    );
  }
}

class SpiteMaliceCutDealLayout extends TableauLayoutBase {
  static TableauSpec buildSpec = TableauSpec(
    rows: List.generate(3, (rowIndex) =>
        TableauRowSpec(
          groups: List.generate(4, (colIndex) =>
              TableauEntry(childId: SpiteMaliceId.cutIds[rowIndex * 4 + colIndex]),
          ),
          innerGroupPad: 25,
        ),
    ),
    innerRowPad: 25,
  );

  SpiteMaliceCutDealLayout() : super(buildSpec, defaultCardStyle);

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => oldDelegate is! SpiteMaliceCutDealLayout;
}

class SpiteMaliceCutDeal extends StatelessWidget {
  SpiteMaliceCutDeal({
    required this.cards,
    this.tracker,
  });

  final List<PlayingCard> cards;
  final MoveTracker? tracker;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: SpiteMaliceCutDealLayout(),
      children: List.generate(cards.length, (index) =>
          PlayingCardWidget.tracked(tracker, SpiteMaliceId.cutIds[index], true, cards[index])),
    );
  }
}

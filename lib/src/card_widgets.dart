import 'dart:math';

import 'package:flutter/material.dart';
import 'package:spite_malice/src/game_state.dart';
import 'package:spite_malice/src/move_tracker.dart';

import 'cards.dart';

/// A widget that paints a card for Spite & Malice. The artwork
/// will auto-scale to the size of the space allocated to it, but
/// the best results will occur when the space has an aspect ratio
/// of 9:14 w:h.
class SpiteMaliceCardWidget extends StatelessWidget {
  SpiteMaliceCardWidget(this.card, { this.highlighted = false });

  final SpiteMaliceCard? card;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: cardStyle.aspectRatio,
        child: CustomPaint(
          painter: SpiteMaliceCardPainter(cardStyle, card, highlighted),
          isComplex: true,
          willChange: false,
        ),
      ),
    );
  }
}

class SpiteMaliceCardStack extends StatelessWidget {
  SpiteMaliceCardStack(this.top, this.size, { this.highlighted = false });

  static LayoutId tracked(
      SpiteMaliceMoveTracker? tracker,
      SpiteMaliceStackId id,
      SpiteMaliceCard? top,
      int? size) {
    bool highlighted = tracker != null &&
        (tracker.state.highlightFrom == id || tracker.state.highlightTo == id);
    Widget child = SpiteMaliceCardStack(top, size, highlighted: highlighted);
    if (tracker != null) {
      child = GestureDetector(
        onTap: () => tracker.hoveringOver(id, true),
        child: MouseRegion(
          onHover: (event) => tracker.hoveringOver(id, false),
          child: child,
        ),
      );
    }
    return LayoutId(id: id, child: child);
  }

  final SpiteMaliceCard? top;
  final int? size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SpiteMaliceCardWidget(size == 0 ? null : top, highlighted: highlighted,),
        if (size != null)
          size == 0 ? Text('(empty)') : Text('($size cards)'),
      ],
    );
  }
}

class SpiteMaliceCardPile extends StatelessWidget {
  SpiteMaliceCardPile(this.cards, this.minimumCards, { this.highlighted = false });

  final List<SpiteMaliceCard> cards;
  final int minimumCards;
  final bool highlighted;

  static LayoutId tracked(
      SpiteMaliceMoveTracker? tracker,
      SpiteMaliceStackId id,
      List<SpiteMaliceCard> cards,
      int minimumSize) {
    bool highlighted = tracker != null &&
        (tracker.state.highlightFrom == id || tracker.state.highlightTo == id);
    Widget child = SpiteMaliceCardPile(cards, minimumSize, highlighted: highlighted,);
    if (tracker != null) {
      child = GestureDetector(
        onTap: () => tracker.hoveringOver(id, true),
        child: MouseRegion(
          onHover: (event) => tracker.hoveringOver(id, false),
          child: child,
        ),
      );
    }
    return LayoutId(id: id, child: child);
  }

  @override
  Widget build(BuildContext context) {
    int offsets = max(max(minimumCards, cards.length) - 1, 0);
    double relativeH = offsets * cardStyle.cascadeOffset + cardStyle.height;
    double alignOffset = min(2.0 / offsets, 2.0);
    return AspectRatio(
      aspectRatio: 90 / relativeH,
      child: Stack(
        children: <Widget>[
          if (cards.length == 0)
            Align(
              alignment: Alignment.topCenter,
              child: SpiteMaliceCardWidget(null, highlighted: highlighted,),
            ),
          for (int i = 0; i < cards.length; i++)
            Align(
              alignment: Alignment(0, i * alignOffset - 1),
              child: SpiteMaliceCardWidget(cards[i], highlighted: highlighted && i == cards.length - 1,),
            ),
        ],
      ),
    );
  }
}

class SpiteMaliceTableauEntry {
  SpiteMaliceTableauEntry({
    this.leftPad = 0.0,
    required this.id,
    this.rightPad = 0.0,
  });

  final double leftPad;
  final SpiteMaliceStackId id;
  final double rightPad;
}

class SpiteMaliceTableauRowSpec {
  SpiteMaliceTableauRowSpec({
    this.topPad = 5.0,
    this.leftPad = 5.0,
    required this.groups,
    this.innerGroupPad = 5.0,
    this.rightPad = 5.0,
    this.bottomPad = 5.0,
  });

  final double topPad;
  final double leftPad;
  final List<SpiteMaliceTableauEntry> groups;
  final double innerGroupPad;
  final double rightPad;
  final double bottomPad;
}

class SpiteMaliceTableauSpec {
  SpiteMaliceTableauSpec({
    required this.topRow,
    this.innerRowPad = 25.0,
    this.bottomRow,
  });

  final SpiteMaliceTableauRowSpec topRow;
  final double innerRowPad;
  final SpiteMaliceTableauRowSpec? bottomRow;
}

class SpiteMaliceLayoutBase extends MultiChildLayoutDelegate {
  SpiteMaliceLayoutBase(this.spec, this.style, {
    double? cardWidth,
    double? topRowHeight,
    double? bottomRowHeight,
  })
      : cardWidth = cardWidth ?? style.width,
        topRowHeight = topRowHeight ?? style.height,
        bottomRowHeight = bottomRowHeight ?? style.height;

  final SpiteMaliceTableauSpec spec;
  final CardStyle style;
  final double cardWidth;
  final double topRowHeight;
  final double bottomRowHeight;
  late Size prefSize = Size(
      max(_processRow(spec.topRow).dx, _processRow(spec.bottomRow).dx),
      _rowH(0, spec.topRow, topRowHeight) + _rowH(spec.innerRowPad, spec.bottomRow, bottomRowHeight),
  );

  Offset _processRow(SpiteMaliceTableauRowSpec? row, [
    Offset pos = Offset.zero,
    double h = 0,
    double cellW = -1
  ]) {
    if (row == null)
      return pos;
    pos = pos.translate(row.leftPad, row.topPad);
    double pad = 0;
    for (var entry in row.groups) {
      pos = pos.translate(pad + entry.leftPad, 0);
      if (cellW >= 0) positionChild(entry.id, pos * cellW);
      pos = pos.translate(cardWidth + entry.rightPad, 0);
      pad = row.innerGroupPad;
    }
    return pos.translate(row.rightPad, h + row.bottomPad);
  }

  double _rowH(double pad, SpiteMaliceTableauRowSpec? row, double rowHeight) {
    if (row == null)
      return 0;
    return pad + row.topPad + rowHeight + row.bottomPad;
  }

  @override
  Size getSize(BoxConstraints constraints) {
    double prefW = prefSize.width;
    double prefH = prefSize.height;

    if (prefW < constraints.minWidth) {
      prefH = constraints.minWidth * prefH / prefW;
      prefW = constraints.minWidth;
    }
    if (prefH < constraints.minHeight) {
      prefW = constraints.minHeight * prefW / prefH;
      prefH = constraints.minHeight;
    }
    if (prefW > constraints.maxWidth) {
      prefH = constraints.maxWidth * prefH / prefW;
      prefW = constraints.maxWidth;
    }
    if (prefH > constraints.maxHeight) {
      prefW = constraints.maxHeight * prefW / prefH;
      prefH = constraints.maxHeight;
    }

    return Size(prefW, prefH);
  }

  @override
  void performLayout(Size size) {
    double cellW = size.width / prefSize.width;
    BoxConstraints constraints = BoxConstraints.tightFor(width: cellW * cardWidth);

    for (var entry in spec.topRow.groups) {
      layoutChild(entry.id, constraints);
    }
    if (spec.bottomRow != null) {
      for (var entry in spec.bottomRow!.groups) {
        layoutChild(entry.id, constraints);
      }
    }

    Offset pos = _processRow(spec.topRow, Offset.zero, topRowHeight, cellW);
    pos = Offset(0, pos.dy + spec.innerRowPad);
    _processRow(spec.bottomRow, pos, bottomRowHeight, cellW);
  }

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) {
    if (oldDelegate is SpiteMaliceLayoutBase) {
      return oldDelegate.spec != this.spec
          || oldDelegate.cardWidth != this.cardWidth
          || oldDelegate.topRowHeight != this.topRowHeight
          || oldDelegate.bottomRowHeight != this.bottomRowHeight;
    }
    return true;
  }
}

class SpiteMaliceTableauLayout extends SpiteMaliceLayoutBase {
  static SpiteMaliceTableauSpec specWithHand = SpiteMaliceTableauSpec(
    topRow: SpiteMaliceTableauRowSpec(
      groups: [
        SpiteMaliceTableauEntry(id: SpiteMaliceStackId.stockId, rightPad: 20),
        ...SpiteMaliceStackId.discardIds.map((id) => SpiteMaliceTableauEntry(id: id)),
      ]
    ),
    innerRowPad: 15,
    bottomRow: SpiteMaliceTableauRowSpec(
      leftPad: 15,
      groups: SpiteMaliceStackId.handIds.map((id) => SpiteMaliceTableauEntry(id: id)).toList(),
    ),
  );

  static SpiteMaliceTableauSpec specWithoutHand = SpiteMaliceTableauSpec(
    topRow: SpiteMaliceTableauRowSpec(
        groups: [
          SpiteMaliceTableauEntry(id: SpiteMaliceStackId.stockId, rightPad: 20),
          ...SpiteMaliceStackId.discardIds.map((id) => SpiteMaliceTableauEntry(id: id)),
        ]
    ),
  );

  SpiteMaliceTableauLayout(this.maxDiscard, this.hasHand, [ this.tracker ]) : super(
    hasHand ? specWithHand : specWithoutHand,
    cardStyle,
    topRowHeight: max(maxDiscard - 1, 0) * cardStyle.cascadeOffset + cardStyle.height,
  );

  final SpiteMaliceMoveTracker? tracker;
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
        assert(tableau.hand == null || tableau.hand!.length == 5);

  final SpiteMaliceTableauState tableau;
  final SpiteMaliceMoveTracker? tracker;

  @override
  Widget build(BuildContext context) {
    int maxDiscard = tableau.discardPiles.fold<int>(3, (prev, pile) => max(prev, pile.length));
    List<SpiteMaliceCard?>? hand = tableau.hand;
    return CustomMultiChildLayout(
      delegate: SpiteMaliceTableauLayout(maxDiscard, hand != null),
      children: <LayoutId>[
        SpiteMaliceCardStack.tracked(tracker, SpiteMaliceStackId.stockId, tableau.stockTop, tableau.stockSize),
        for (int i = 0; i < 4; i++)
          SpiteMaliceCardPile.tracked(tracker, SpiteMaliceStackId.discardIds[i], tableau.discardPiles[i], 3),
        if (hand != null)
          for (int i = 0; i < 5; i++)
            SpiteMaliceCardStack.tracked(tracker, SpiteMaliceStackId.handIds[i], hand[i], null),
      ],
    );
  }
}

class SpiteMaliceBuildLayout extends SpiteMaliceLayoutBase {
  static SpiteMaliceTableauSpec buildSpec = SpiteMaliceTableauSpec(
    topRow: SpiteMaliceTableauRowSpec(
      groups: [
        SpiteMaliceTableauEntry(id: SpiteMaliceStackId.drawId, rightPad: 20),
        ...SpiteMaliceStackId.buildIds.map((id) => SpiteMaliceTableauEntry(id: id)),
        SpiteMaliceTableauEntry(id: SpiteMaliceStackId.trashId, leftPad: 25),
      ],
      bottomPad: 25,
    ),
  );

  SpiteMaliceBuildLayout() : super(buildSpec, cardStyle);

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => oldDelegate is! SpiteMaliceBuildLayout;
}

class SpiteMaliceBuild extends StatelessWidget {
  SpiteMaliceBuild({
    required this.drawSize,
    required this.buildTops,
    required this.buildSizes,
    required this.trashSize,
    this.tracker,
  })
      : assert(buildTops.length == 4),
        assert(buildSizes.length == 4);

  final int drawSize;
  final List<SpiteMaliceCard?> buildTops;
  final List<int> buildSizes;
  final int trashSize;
  final SpiteMaliceMoveTracker? tracker;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: SpiteMaliceBuildLayout(),
      children: <LayoutId>[
        SpiteMaliceCardStack.tracked(tracker, SpiteMaliceStackId.drawId, SpiteMaliceCard.back, drawSize),
        for (int i = 0; i < 4; i++)
          SpiteMaliceCardStack.tracked(tracker, SpiteMaliceStackId.buildIds[i], buildTops[i], buildSizes[i]),
        SpiteMaliceCardStack.tracked(tracker, SpiteMaliceStackId.trashId, SpiteMaliceCard.back, trashSize),
      ],
    );
  }
}

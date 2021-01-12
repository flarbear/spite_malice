import 'dart:math';
import 'dart:ui';

import 'package:flutter/rendering.dart';

abstract class CardStyle {
  const CardStyle();

  double get width;
  double get height;
  double get cascadeOffset;
  double get aspectRatio => width / height;

  String suitName(SpiteMaliceCard card);
  String rankName(SpiteMaliceCard card);
  String cardString(SpiteMaliceCard card);
  void drawCardBack(Canvas canvas);
  void drawCard(Canvas canvas, SpiteMaliceCard card);

  void _anchorText(Canvas canvas, double textHeight, Offset textAnchor, Offset cardAnchor, String text, Color color) {
    TextSpan span = TextSpan(text: text, style: TextStyle(color: color, fontFamily: 'Tahoma'));
    TextPainter tp = new TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    double scale = textHeight / tp.height;
    if (tp.width * scale > 0.9 * width) {
      scale = 0.9 * width / tp.width;
    }
    canvas.save();
    canvas.translate(cardAnchor.dx, cardAnchor.dy);
    canvas.scale(scale, scale);
    canvas.translate(-tp.width * textAnchor.dx, -tp.height * textAnchor.dy);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

class ClassicCardStyle extends CardStyle {
  const ClassicCardStyle() : super();

  double get width => 90;
  double get height => 14;
  double get cascadeOffset => 25;

  static final Path heart = Path()
    ..moveTo(45, 55)
    ..cubicTo(45, 50, 52, 40, 60, 40)
    ..cubicTo(68, 40, 75, 47, 75, 55)
    ..cubicTo(75, 73, 47, 95, 45, 110)
    ..cubicTo(43, 95, 15, 73, 15, 55)
    ..cubicTo(15, 47, 22, 40, 30, 40)
    ..cubicTo(38, 40, 45, 50, 45, 55)
    ..close();

  static final Path diamond = Path()
    ..moveTo(45, 30)
    ..arcToPoint(Offset(20,  70), radius: Radius.elliptical(50, 70))
    ..arcToPoint(Offset(45, 110), radius: Radius.elliptical(50, 70))
    ..arcToPoint(Offset(70,  70), radius: Radius.elliptical(50, 70))
    ..arcToPoint(Offset(45,  30), radius: Radius.elliptical(50, 70))
    ..close();

  static final Path spade = Path()
    ..moveTo(45, 25)
    ..cubicTo(45, 45, 75, 55, 75, 70)
    ..cubicTo(75, 78, 68, 85, 60, 85)
    ..cubicTo(50, 85, 48, 74, 46, 70)
    ..cubicTo(46, 90, 50, 100, 69, 100)
    ..lineTo(70, 102)
    ..lineTo(20, 102)
    ..lineTo(21, 100)
    ..cubicTo(40, 100, 44, 90, 44, 70)
    ..cubicTo(42, 74, 40, 85, 30, 85)
    ..cubicTo(22, 85, 15, 78, 15, 70)
    ..cubicTo(15, 55, 45, 45, 45, 25)
    ..close();

  static final Path club = Path()
    ..arcTo(Rect.fromCircle(center: Offset(45, 45), radius: 17), pi / 2, 1.9 * pi, true)
    ..arcTo(Rect.fromCircle(center: Offset(60, 70), radius: 17), pi, 1.9 * pi, true)
    ..arcTo(Rect.fromCircle(center: Offset(30, 70), radius: 17), pi, 1.9 * pi, true)
    ..moveTo(45, 70)
    ..cubicTo(46, 90, 50, 100, 69, 100)
    ..lineTo(70, 102)
    ..lineTo(20, 102)
    ..lineTo(21, 100)
    ..cubicTo(40, 100, 44, 90, 44, 70)
    ..close();

  @override
  String suitName(SpiteMaliceCard card) {
    if (card.isBack) return 'unknown';
    if (card.isWild) return 'Joker';
    return [ 'Spades', 'Hearts', 'Diamonds', 'Clubs' ][card.suit & 3];
  }

  @override
  String rankName(SpiteMaliceCard card) {
    if (card.isBack) return 'unknown';
    return [ 'Joker', 'Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen' ][card.rank];
  }

  @override
  String cardString(SpiteMaliceCard card) {
    if (card.isBack) return 'unknown';
    if (card.isWild) return 'Joker';
    return '${rankName(card)} of ${suitName(card)}';
  }

  static Path _makeZigZag() {
    Path p = Path();
    double x = 12.5;
    double y = 0;
    double xInc = 1.0;
    double yInc = 1.0;
    p.moveTo(x + 7.5, y + 7.5);
    for (int i = 0; i < 15; i++) {
      double dx = xInc > 0 ?  75 - x : x;
      double dy = yInc > 0 ? 125 - y : y;
      if (dx < dy) {
        x += xInc * dx; y += yInc * dx; xInc = -xInc;
      } else {
        x += xInc * dy; y += yInc * dy; yInc = -yInc;
      }
      p.lineTo(x + 7.5, y + 7.5);
    }
    p.close();
    return p;
  }

  static final Path zigzag = _makeZigZag();

  @override
  void drawCardBack(Canvas canvas) {
    Paint p = Paint();

    p.color = Color(0xFF1B5E20);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(7, 7, 83, 133), Radius.circular(5)), p);
    p.color = Color(0xFF795548);
    canvas.drawPath(zigzag, p);
  }

  @override
  void drawCard(Canvas canvas, SpiteMaliceCard card) {
    Paint p = Paint();

    String name;
    if (card.isWild) {
      name = r'$';
      p.color = Color(0xFF000000);
      _anchorText(canvas, 42, Offset(0.5, 0.5), Offset(45, 70), 'Joker', p.color);
    } else {
      Path suitPath = [ spade, heart, diamond, club ][card.suit & 3];
      p.color = [ Color(0xFF000000), Color(0xFFF44336), Color(0xFFF44336), Color(0xFF000000) ][card.suit & 3];
      canvas.drawPath(suitPath, p);
      name = rankName(card);
      if (name.length > 2) name = name.substring(0, 1);
    }

    _anchorText(canvas, 28, Offset.zero,  Offset( 7,   1), name, p.color);
    _anchorText(canvas, 28, Offset(1, 1), Offset(83, 137), name, p.color);
  }

  @override
  String toString() {
    return 'ClassicCardTheme()';
  }
}

CardStyle cardStyle = ClassicCardStyle();

class SpiteMaliceCard {
  static const SpiteMaliceCard back = const SpiteMaliceCard(0, -1);
  static const SpiteMaliceCard wild = const SpiteMaliceCard(0,  0);

  const SpiteMaliceCard(this.suit, this.rank);

  final int suit;
  final int rank;

  bool get isWild => rank == 0;
  bool get isBack => rank < 0;

  @override
  String toString() {
    return 'SpiteMaliceCard(${cardStyle.cardString(this)})';
  }

  @override
  int get hashCode {
    return hashValues(suit, rank);
  }

  @override
  bool operator ==(Object other) {
    return other is SpiteMaliceCard
        && other.suit == this.suit
        && other.rank == this.rank;
  }
}

class SpiteMaliceCardPainter extends CustomPainter {
  SpiteMaliceCardPainter(this.style, this.card, this.highlighted);

  final CardStyle style;
  final SpiteMaliceCard? card;
  bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()
      ..strokeWidth = 1.0;

    Rect outlineBounds = (Offset.zero & size).deflate(0.5);
    RRect outline = RRect.fromRectAndRadius(outlineBounds, Radius.circular(5));

    if (card != null) {
      p.color = highlighted ? Color(0xFFC8E6C9) : Color(0xFFFFFFFF);
      canvas.drawRRect(outline, p);
      p.style = PaintingStyle.stroke;
      p.color = Color(0x42000000);
      canvas.drawRRect(outline, p);

      canvas.scale(size.width / style.width, size.height / style.height);
      if (card!.isBack) {
        style.drawCardBack(canvas);
      } else {
        style.drawCard(canvas, card!);
      }
    } else {
      if (highlighted) {
        p.color = Color(0x7F9E9E9E);
        canvas.drawRRect(outline, p);
      }
      p.color = Color(0xFFFFFFFF);
      p.style = PaintingStyle.stroke;
      canvas.drawRRect(outline, p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is SpiteMaliceCardPainter) {
      return oldDelegate.style != this.style
          || oldDelegate.card != this.card
          || oldDelegate.highlighted != this.highlighted;
    }
    return true;
  }
}

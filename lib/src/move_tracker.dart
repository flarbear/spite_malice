/*
 * Copyright 2021 flarbear@github
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT.
 */

import 'package:playing_cards/playing_cards.dart';

import 'game_state.dart';

class SpiteMaliceId {
  const SpiteMaliceId._unique(this.name) : this.index = -1;
  const SpiteMaliceId._indexed(this.name, this.index);

  final String name;
  final int index;

  static List<SpiteMaliceId> _makeList(String baseName, int size) {
    return List.generate(size, (i) => SpiteMaliceId._indexed('$baseName${i+1}', i));
  }

  static List<SpiteMaliceId> cutIds = _makeList('cut', 12);

  static SpiteMaliceId drawId = SpiteMaliceId._unique('draw');
  static List<SpiteMaliceId> buildIds = _makeList('build', 4);
  static SpiteMaliceId trashId = SpiteMaliceId._unique('trash');

  static SpiteMaliceId stockId = SpiteMaliceId._unique('stock');
  static List<SpiteMaliceId> discardIds = _makeList('discard', 4);

  static List<SpiteMaliceId> handIds = _makeList('hand', 5);

  @override
  String toString() => 'SpiteMaliceId($name${index >= 0 ? ', $index' : ''})';
}

late final playingMoves = {
  for (final id in SpiteMaliceId.cutIds)
    id: {
      id: Move.unary(id,
        canMove: (SpiteMaliceGameState state) => state.canCutOrDeal(),
        execute: (SpiteMaliceGameState state) => state.cutOrDeal(id),
      ),
    },
  SpiteMaliceId.drawId: {
    SpiteMaliceId.drawId: Move.unary(SpiteMaliceId.drawId,
      canMove: (SpiteMaliceGameState state) => state.canDraw(),
      execute: (SpiteMaliceGameState state) => state.draw(),
    ),
  },
  for (final hand in SpiteMaliceId.handIds)
    hand: {
      for (final discard in SpiteMaliceId.discardIds)
        discard: Move.binary(hand, discard,
          canMove: (SpiteMaliceGameState state) => state.canDiscard(hand),
          execute: (SpiteMaliceGameState state) => state.discard(hand, discard),
        ),
      for (final build in SpiteMaliceId.buildIds)
        build: Move.binary(hand, build,
          canMove: (SpiteMaliceGameState state) => state.canBuildFromHand(hand, build),
          execute: (SpiteMaliceGameState state) => state.buildFromHand(hand, build),
        ),
    },
  SpiteMaliceId.stockId: {
    for (final build in SpiteMaliceId.buildIds)
      build: Move.binary(SpiteMaliceId.stockId, build,
        canMove: (SpiteMaliceGameState state) => state.canBuildFromStock(build),
        execute: (SpiteMaliceGameState state) => state.buildFromStock(build),
      ),
  },
  for (final discard in SpiteMaliceId.discardIds)
    discard: {
      for (final build in SpiteMaliceId.buildIds)
        build: Move.binary(discard, build,
          canMove: (SpiteMaliceGameState state) => state.canBuildFromDiscard(discard, build),
          execute: (SpiteMaliceGameState state) => state.buildFromDiscard(discard, build),
        ),
    },
};


const { INVALID_MOVE } = require('boardgame.io/core');
const { PlayerView } = require('boardgame.io/core');
const { TurnOrder } = require('boardgame.io/core');

class SpiteMaliceCard {
  constructor(suit, rank) {
    this.suit = suit;
    this.rank = rank;
    this.isWild = rank == 'Wild';
  }
}

const Wild = new SpiteMaliceCard(0, 'Wild');

function Transfer(source, dest) {
  while (source.length) {
    dest.push(source.pop());
  }
}

function DrawCard(ctx, deck, completed) {
  if (deck.length == 0) {
    const temp = [];
    Transfer(completed, temp);
    Transfer(ctx.random.Shuffle(temp), deck);
  }
  return deck.pop();
}

function DrawStack(ctx, deck, completed, n) {
  const stack = [];
  for (var i = 0; i < n; i++) {
    stack.push(DrawCard(ctx, deck, completed));
  }
  return stack;
}

function Build(build, card, completed) {
  if (card) {
    if (card.isWild || card.rank == build.length + 1) {
      build.push(card);
      if (build.length == 12) {
        while (build.length) {
          completed.push(build.pop());
        }
      }
      return true;
    }
  }
  return false;
}

function MakeCutDeck(ctx) {
  const deck = Array();
  for (var rank = 1; rank <= 12; rank++) {
    deck.push(new SpiteMaliceCard(ctx.random.Die(12) - 1, rank));
  }
  return deck;
}

function MakeDeck(numPlayers, stockSize) {
  const minCards = numPlayers * (stockSize + 5) + 48;
  const deck = Array();
  while (deck.length < minCards) {
    deck.push(Wild, Wild, Wild);
    for (var suit = 0; suit < 12; suit++) {
      for (var rank = 1; rank <= 12; rank++) {
        deck.push(new SpiteMaliceCard(suit, rank));
      }
      deck.push(Wild);
    }
    deck.push(Wild, Wild, Wild);
  }
  return deck;
}

function MakePiles(n) {
  const piles = [];
  for (var i = 0; i < n; i++) {
    piles.push(Array());
  }
  return piles;
}

function Deal(G, ctx) {
  G.draw = ctx.random.Shuffle(MakeDeck(ctx.numPlayers, G.stockSize));
  for (var i = 0; i < G.stockSize; i++) {
    for (var j = 0; j < ctx.numPlayers; j++) {
      G.players[j].stock.push(DrawCard(ctx, G.draw, G.completed));
    }
  }
}

const SpiteMaliceGame = {
  name: 'Spite-Malice',

  setup: (ctx, setupData) => {
    const stockSize = setupData ? setupData.stockSize : (ctx.numPlayers > 4 ? 20 : 30);
    const playersMap = {};
    for (var i = 0; i < ctx.numPlayers; i++) {
      playersMap[i] = {
        stock: [],
        hand: [ null, null, null, null, null ],
        discardPiles: MakePiles(4),
        cutCard: null,
        cutIndex: null,
      };
    }
    return {
      draw: [],
      completed: [],
      buildPiles: MakePiles(4),
      players: playersMap,
      stockSize: stockSize,
      cutCards: null,
      dealer: null,
    };
  },

  playerView: (G, ctx, playerId) => {
    const publicPlayers = {};
    for (var i = 0; i < ctx.numPlayers; i++) {
      const stock = G.players[i].stock;
      publicPlayers[i] = {
        stockTop: stock[stock.length - 1],
        stockSize: stock.length,
        discardPiles: G.players[i].discardPiles,
        cutIndex: G.players[i].cutIndex,
        cutCard: G.players[i].cutCard,
      }
    }
    publicPlayers[playerId].hand = G.players[playerId].hand;
    return {
      drawSize: G.draw.length,
      completedSize: G.completed.length,
      buildPiles: G.buildPiles,
      players: publicPlayers,
      dealer: G.dealer,
    };
  },

  moves: {
    draw: {
      move: (G, ctx) => {
        const hand = G.players[ctx.currentPlayer].hand;
        if (hand.every((card) => card === null || card === undefined)) {
          G.players[ctx.currentPlayer].hand = DrawStack(ctx, G.draw, G.completed, 5);
        }
      },
      client: false,
    },

    buildFromStock: {
      move: (G, ctx, buildIndex) => {
        const build = G.buildPiles[buildIndex];
        const stock = G.players[ctx.currentPlayer].stock;
        const card = stock[stock.length - 1];
        if (Build(build, card, G.completed)) {
          stock.pop();
        } else {
          return INVALID_MOVE;
        }
      },
      client: false,
    },

    buildFromHand: {
      move: (G, ctx, handIndex, buildIndex) => {
        const build = G.buildPiles[buildIndex];
        const hand = G.players[ctx.currentPlayer].hand;
        const card = hand[handIndex];
        if (Build(build, card, G.completed)) {
          hand[handIndex] = null;
        } else {
          return INVALID_MOVE;
        }
      },
      client: false,
    },

    buildFromDiscard: {
      move: (G, ctx, discardIndex, buildIndex) => {
        const build = G.buildPiles[buildIndex];
        const discard = G.players[ctx.currentPlayer].discardPiles[discardIndex];
        const card = discard[discard.length - 1];
        if (Build(build, card, G.completed)) {
          discard.pop();
        } else {
          return INVALID_MOVE;
        }
      },
      client: false,
    },

    discard: {
      move: (G, ctx, handIndex, discardIndex) => {
        const hand = G.players[ctx.currentPlayer].hand;
        const discard = G.players[ctx.currentPlayer].discardPiles[discardIndex];
        if (hand[handIndex]) {
          discard.push(hand[handIndex]);
          hand[handIndex] = null;
          ctx.events.endTurn();
        } else {
          return INVALID_MOVE;
        }
      },
      client: false,
    },
  },

  turn: {
    order: {
      first: (G, ctx) => (G.dealer + 1) % ctx.numPlayers,
      next: (G, ctx) => (ctx.playOrderPos + 1) % ctx.numPlayers,
    },

    onBegin: (G, ctx) => {
      const hand = G.players[ctx.currentPlayer].hand;
      for (var i = 0; i < hand.length; i++) {
        if (!hand[i]) {
          hand[i] = DrawCard(ctx, G.draw, G.completed);
        }
      }
      return G;
    },

    endIf: (G, ctx) => false,
  },

  endIf: (G, ctx) => {
    if (ctx.phase != 'preparing' && G.draw.length > 0) {
      if (G.players[ctx.currentPlayer].stock.length == 0) {
        return { winner: ctx.currentPlayer };
      }
    }
  },

  phases: {
    preparing: {
      onBegin: (G, ctx) => {
        if (ctx.numPlayers == 1) {
          ctx.events.setPhase('dealing');
        } else {
          ctx.events.setActivePlayers({ all: 'cutting', moveLimit: 1 });
        }
      },

      endIf: (G, ctx) => {
        for (var player in G.players) {
          if (G.players[player].cutCard == null) {
            return false;
          }
        }
        ctx.events.setPhase('dealing');
        return true;
      },

      onEnd: (G, ctx) => {
        G.dealer = 0;
        if (ctx.numPlayers > 1) {
          for (var i = 0; i < ctx.numPlayers; i++) {
            if (G.players[i].cutCard.rank > G.players[G.dealer].cutCard.rank) {
              G.dealer = i;
            }
          }
        }
      },

      turn: {
        stages: {
          'cutting': {
            moves: {
              cutDeck: {
                move: (G, ctx, index) => {
                  if (G.players[ctx.playerID].cutCard != null) {
                    return INVALID_MOVE;
                  }
                  for (var player in G.players) {
                    if (G.players[player].cutIndex == index) {
                      return INVALID_MOVE;
                    }
                  }
                  if (!G.cutCards) {
                    G.cutCards = ctx.random.Shuffle(MakeCutDeck(ctx));
                  }
                  G.players[ctx.playerID].cutIndex = index;
                  G.players[ctx.playerID].cutCard = G.cutCards[index];
                },
                client: false,
              },
            },
          },

        },
      },

      next: 'dealing',
      start: true,
    },

    dealing: {
      onBegin: (G, ctx) => {
        if (ctx.numPlayers == 1) {
          Deal(G, ctx);
          ctx.events.endPhase();
        }
      },

      endIf: (G, ctx) => (G.draw.length > 0),

      turn: {
        order: {
          playOrder: (G) => [ G.dealer.toString() ],
          first: () => 0,
          next: () => 0,
        },
      },

      moves: {
        deal: {
          move: (G, ctx) => {
            Deal(G, ctx);
            ctx.events.setPhase(null);
          },
          client: false,
        },
      },
    },
  },

  disableUndo: true,
};

exports.SpiteMaliceGame = SpiteMaliceGame;

import assert from 'node:assert/strict';

import {
  advanceDay,
  applyTool,
  createInitialGame,
  movePlayer,
  parseGame,
  sellProduce,
  type GameState,
} from '../lib/game.ts';

let game = createInitialGame();
game = applyTool(game, 'hoe');
assert.equal(game.milestones.tilled, true);
game = applyTool(game, 'seed');
assert.equal(game.milestones.planted, true);
game = applyTool(game, 'water');
game = advanceDay(game);
game = applyTool(game, 'water');
game = advanceDay(game);
game = applyTool(game, 'water');
game = advanceDay(game);
assert.equal(game.milestones.ripe, true);
game = applyTool(game, 'harvest');
assert.equal(game.produce, 1);

game = movePlayer(game, 'right');
game = movePlayer(game, 'right');
game = movePlayer(game, 'right');
game = movePlayer(game, 'down');
assert.equal(game.player.x, 10);
assert.equal(game.player.y, 4);
game = sellProduce(game);
assert.equal(game.produce, 0);
assert.equal(game.coins, 178);
assert.equal(game.milestones.sold, true);

const roundTrip = parseGame(JSON.stringify(game));
assert.deepEqual(roundTrip, game);
assert.equal(parseGame('{broken'), null);
assert.equal(parseGame(JSON.stringify({ version: 99 })), null);

const edge: GameState = {
  ...createInitialGame(),
  player: { x: 0, y: 0, direction: 'up' },
};
assert.deepEqual(movePlayer(edge, 'up').player, {
  x: 0,
  y: 0,
  direction: 'up',
});

console.log(
  'PASS core-loop=1 save-roundtrip=1 corrupt-save-fallback=1 bounds=1',
);

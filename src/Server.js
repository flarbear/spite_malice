const { Server } = require('boardgame.io/server');
const { SpiteMaliceGame } = require('./Game');

const path = require('path');
const serve = require('koa-static');

const server = Server({ games: [ SpiteMaliceGame ] });
const PORT = process.env.PORT || 8000;
console.log('PORT: '+PORT);

// Build path relative to the server.js file
const frontEndAppBuildPath = path.resolve(__dirname, '../build/web');
console.log('build path: '+frontEndAppBuildPath);
server.app.use(serve(frontEndAppBuildPath))

server.run(PORT, () => {
  server.app.use(
    async (ctx, next) => await serve(frontEndAppBuildPath)(
      Object.assign(ctx, { path: 'index.html' }),
      next
    )
  )
});

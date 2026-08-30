// Zikkit — game registry. Plain script (must load before every js/games/*.js file, since each
// one calls registerGame() at parse time) and before app.js (which reads GAMES to render the menu).
const GAMES = [];

function registerGame(meta) {
  GAMES.push(meta);
}

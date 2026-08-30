// Regression guard: scoreRound's generalized {attempts, maxAttempts} shape must reproduce the
// exact legacy Wordle {guessesUsed} scores whenever maxAttempts === 6.
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const assert = require('assert');

const BASE = path.resolve(__dirname, '..', '..');
const sandbox = { console };
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(BASE, 'js/data/words.js'), 'utf8'), sandbox);
vm.runInContext(fs.readFileSync(path.join(BASE, 'js/lib/leveling.js'), 'utf8'), sandbox);

const scoreRound = vm.runInContext('scoreRound', sandbox);
const bandForSkill = vm.runInContext('bandForSkill', sandbox);

let failures = 0;
function check(label, fn) {
  try {
    fn();
    console.log('PASS:', label);
  } catch (e) {
    failures++;
    console.log('FAIL:', label, '-', e.message);
  }
}

check('legacy Wordle SOLVE_SCORE table unchanged for maxAttempts=6', () => {
  const legacyTable = { 1: 18, 2: 15, 3: 12, 4: 8, 5: 4, 6: 1 };
  Object.entries(legacyTable).forEach(([attempts, expected]) => {
    // timeSeconds = attempts * 30 keeps avgSecPerAttempt at a neutral 30s (no fast/slow modifier)
    const got = scoreRound({ won: true, attempts: Number(attempts), maxAttempts: 6, timeSeconds: Number(attempts) * 30 });
    assert.strictEqual(got, expected, `attempts=${attempts}: got ${got}, expected ${expected}`);
  });
});

check('fail score unchanged for maxAttempts=6', () => {
  const got = scoreRound({ won: false, attempts: 6, maxAttempts: 6, timeSeconds: 180 });
  assert.strictEqual(got, -10);
});

check('band thresholds: beginner <=35, intermediate 36-70, advanced >70', () => {
  assert.strictEqual(bandForSkill(0), 'beginner');
  assert.strictEqual(bandForSkill(35), 'beginner');
  assert.strictEqual(bandForSkill(36), 'intermediate');
  assert.strictEqual(bandForSkill(70), 'intermediate');
  assert.strictEqual(bandForSkill(71), 'advanced');
  assert.strictEqual(bandForSkill(100), 'advanced');
});

check('generalized scoring: fewer attempts (relative to maxAttempts) never scores worse than more attempts', () => {
  const fast = scoreRound({ won: true, attempts: 1, maxAttempts: 4, timeSeconds: 30 });
  const slow = scoreRound({ won: true, attempts: 4, maxAttempts: 4, timeSeconds: 120 });
  assert.ok(fast >= slow, `fast=${fast} should be >= slow=${slow}`);
});

check('single-shot rounds (maxAttempts=1): win scores positively, loss scores FAIL_SCORE', () => {
  const won = scoreRound({ won: true, attempts: 1, maxAttempts: 1, timeSeconds: 30 });
  const lost = scoreRound({ won: false, attempts: 1, maxAttempts: 1, timeSeconds: 30 });
  assert.ok(won > 0, `expected a positive score for a single-shot win, got ${won}`);
  assert.strictEqual(lost, -10);
});

console.log(failures === 0 ? '\nALL LEVELING TESTS PASSED' : `\n${failures} TEST(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);

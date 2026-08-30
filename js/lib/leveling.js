// Zikkit (זיקית) — adaptive level detection. No placement test: the player's level is inferred
// purely from how each Wordle round goes. This is a simple, explainable v1 heuristic (bounded
// score + band thresholds), not machine learning.
const SKILL_MIN = 0;
const SKILL_MAX = 100;
const SKILL_START = 50; // first-ever visit => bandForSkill(50) === "intermediate"

const BAND_THRESHOLDS = { beginnerMax: 35, intermediateMax: 70 }; // > intermediateMax => advanced

const SOLVE_SCORE = { 1: 18, 2: 15, 3: 12, 4: 8, 5: 4, 6: 1 }; // legacy Wordle table, keyed by guesses (maxAttempts===6)
const FAIL_SCORE = -10; // used all attempts without solving
const MIN_ROUND_SCORE = 1;
const MAX_ROUND_SCORE = 18;

const TIME_BONUS_FAST = 2; // avg < 15s/attempt
const TIME_PENALTY_SLOW = -2; // avg > 45s/attempt

const BAND_LABELS = { beginner: "מתחילים", intermediate: "בינוני", advanced: "מתקדמים" };

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function bandForSkill(skill) {
  if (skill <= BAND_THRESHOLDS.beginnerMax) return "beginner";
  if (skill <= BAND_THRESHOLDS.intermediateMax) return "intermediate";
  return "advanced";
}

// Wordle (maxAttempts===6) keeps its exact legacy table; every other game (any other
// maxAttempts) scores by efficiency = how few of its attempts were used.
function scoreForAttempts(attempts, maxAttempts) {
  if (maxAttempts === 6 && SOLVE_SCORE[attempts] !== undefined) {
    return SOLVE_SCORE[attempts];
  }
  const efficiency = clamp(1 - (attempts - 1) / Math.max(1, maxAttempts - 1), 0, 1);
  return Math.round(MIN_ROUND_SCORE + efficiency * (MAX_ROUND_SCORE - MIN_ROUND_SCORE));
}

// roundResult: { won, attempts, maxAttempts, timeSeconds }
function scoreRound(roundResult) {
  const { won, attempts, maxAttempts, timeSeconds } = roundResult;
  const base = won ? scoreForAttempts(attempts, maxAttempts) : FAIL_SCORE;

  const avgSecPerAttempt = timeSeconds / attempts;
  let timeModifier = 0;
  if (avgSecPerAttempt < 15) timeModifier = TIME_BONUS_FAST;
  else if (avgSecPerAttempt > 45) timeModifier = TIME_PENALTY_SLOW;

  return clamp(base + timeModifier, -12, 20);
}

// Returns { skillAfter, bandAfter, bandChanged, delta } — does not mutate profile.
function updateProfileAfterRound(profile, roundResult) {
  const bandBefore = bandForSkill(profile.skill);
  const delta = scoreRound(roundResult);
  const skillAfter = clamp(profile.skill + delta, SKILL_MIN, SKILL_MAX);
  const bandAfter = bandForSkill(skillAfter);
  return { skillAfter, bandAfter, bandChanged: bandAfter !== bandBefore, delta };
}

function pickWord(profile) {
  const band = bandForSkill(profile.skill);
  const pool = WORD_LIST.filter((entry) => entry.difficulty === band);
  const unplayed = pool.filter((entry) => !profile.playedWords.includes(entry.word));
  const source = unplayed.length > 0 ? unplayed : pool;
  return source[Math.floor(Math.random() * source.length)];
}

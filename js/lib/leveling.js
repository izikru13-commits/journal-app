// Zikkit (זיקית) — adaptive level detection. No placement test: the player's level is inferred
// purely from how each Wordle round goes. This is a simple, explainable v1 heuristic (bounded
// score + band thresholds), not machine learning.
const SKILL_MIN = 0;
const SKILL_MAX = 100;
const SKILL_START = 50; // first-ever visit => bandForSkill(50) === "intermediate"

const BAND_THRESHOLDS = { beginnerMax: 35, intermediateMax: 70 }; // > intermediateMax => advanced

const SOLVE_SCORE = { 1: 18, 2: 15, 3: 12, 4: 8, 5: 4, 6: 1 }; // keyed by guesses used to win
const FAIL_SCORE = -10; // used all 6 guesses without solving

const TIME_BONUS_FAST = 2; // avg < 15s/guess
const TIME_PENALTY_SLOW = -2; // avg > 45s/guess

const BAND_LABELS = { beginner: "מתחילים", intermediate: "בינוני", advanced: "מתקדמים" };

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function bandForSkill(skill) {
  if (skill <= BAND_THRESHOLDS.beginnerMax) return "beginner";
  if (skill <= BAND_THRESHOLDS.intermediateMax) return "intermediate";
  return "advanced";
}

// roundResult: { won, guessesUsed, timeSeconds }
function scoreRound(roundResult) {
  const { won, guessesUsed, timeSeconds } = roundResult;
  const base = won ? SOLVE_SCORE[guessesUsed] : FAIL_SCORE;

  const avgSecPerGuess = timeSeconds / guessesUsed;
  let timeModifier = 0;
  if (avgSecPerGuess < 15) timeModifier = TIME_BONUS_FAST;
  else if (avgSecPerGuess > 45) timeModifier = TIME_PENALTY_SLOW;

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

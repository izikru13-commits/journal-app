// Zikkit (זיקית) — anonymous player profile persistence (localStorage only, no backend/account).
const ZIKKIT_PROFILE_KEY = "zikkit_profile_v1";
const ZIKKIT_HISTORY_LIMIT = 100;

function createDefaultProfile() {
  return {
    version: 1,
    createdAt: new Date().toISOString(),
    skill: SKILL_START,
    band: bandForSkill(SKILL_START),
    stats: {
      gamesPlayed: 0,
      gamesWon: 0,
      currentStreak: 0,
      bestStreak: 0,
      guessDistribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0 },
    },
    playedWords: [],
    history: [],
    lastPlayedAt: null,
  };
}

function getProfile() {
  try {
    const raw = localStorage.getItem(ZIKKIT_PROFILE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object" && typeof parsed.skill === "number") {
        return parsed;
      }
    }
  } catch (e) {
    console.error("Zikkit: failed to read profile from localStorage", e);
  }
  const fresh = createDefaultProfile();
  saveProfile(fresh);
  return fresh;
}

function saveProfile(profile) {
  try {
    localStorage.setItem(ZIKKIT_PROFILE_KEY, JSON.stringify(profile));
  } catch (e) {
    console.error("Zikkit: failed to save profile to localStorage", e);
  }
}

// roundInfo: { won, guesses, timeSeconds, word, difficulty }
// levelingResult: { skillAfter, bandAfter, bandChanged, delta } (see js/lib/leveling.js)
function recordRound(profile, roundInfo, levelingResult) {
  const stats = { ...profile.stats };
  stats.guessDistribution = { ...profile.stats.guessDistribution };
  stats.gamesPlayed += 1;
  if (roundInfo.won) {
    stats.gamesWon += 1;
    stats.currentStreak += 1;
    stats.bestStreak = Math.max(stats.bestStreak, stats.currentStreak);
    stats.guessDistribution[roundInfo.guesses] = (stats.guessDistribution[roundInfo.guesses] || 0) + 1;
  } else {
    stats.currentStreak = 0;
  }

  const historyEntry = {
    date: new Date().toISOString(),
    word: roundInfo.word,
    difficulty: roundInfo.difficulty,
    won: roundInfo.won,
    guesses: roundInfo.guesses,
    timeSeconds: roundInfo.timeSeconds,
    skillBefore: profile.skill,
    skillAfter: levelingResult.skillAfter,
    bandBefore: profile.band,
    bandAfter: levelingResult.bandAfter,
  };
  const history = [...profile.history, historyEntry].slice(-ZIKKIT_HISTORY_LIMIT);

  const playedWords = profile.playedWords.includes(roundInfo.word)
    ? profile.playedWords
    : [...profile.playedWords, roundInfo.word];

  return {
    ...profile,
    skill: levelingResult.skillAfter,
    band: levelingResult.bandAfter,
    stats,
    playedWords,
    history,
    lastPlayedAt: historyEntry.date,
  };
}

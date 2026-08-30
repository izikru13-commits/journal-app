// Zikkit — shared round-finishing + item-picking helpers used by every game except Wordle's
// own pickWord (kept untouched in js/lib/leveling.js to avoid touching already-verified code).

function finishGame({ profile, onProfileUpdate, gameId, won, attempts, maxAttempts, timeSeconds, itemId, difficulty, word }) {
  const roundResult = { won, attempts, maxAttempts, timeSeconds };
  const levelingResult = updateProfileAfterRound(profile, roundResult);
  const updatedProfile = recordRound(
    profile,
    {
      won,
      timeSeconds,
      difficulty,
      gameId,
      itemId,
      word,
      guesses: maxAttempts === 6 ? attempts : undefined,
    },
    levelingResult
  );
  saveProfile(updatedProfile);
  onProfileUpdate(updatedProfile);
  const levelChange = levelingResult.bandChanged ? (levelingResult.delta > 0 ? "up" : "down") : null;
  return { updatedProfile, levelingResult, levelChange };
}

// Fisher-Yates shuffle, does not mutate the input.
function shuffle(array) {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Generalizes Wordle's pickWord() for any data pool tagged with a difficulty field, tracking
// each game's own "already played" list under profile.playedItems[gameId].
function pickItem(pool, profile, gameId, difficultyKey = "difficulty") {
  const band = bandForSkill(profile.skill);
  const bandPool = pool.filter((item) => item[difficultyKey] === band);
  const played = (profile.playedItems && profile.playedItems[gameId]) || [];
  const idOf = (item) => item.id || item.word;
  const unplayed = bandPool.filter((item) => !played.includes(idOf(item)));
  const source = unplayed.length > 0 ? unplayed : bandPool;
  return source[Math.floor(Math.random() * source.length)];
}

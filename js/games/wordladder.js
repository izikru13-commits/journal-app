// Zikkit — סולם מילים (fixed word-ladder chains; fill blanked middle rungs from multiple choice).
function buildLadderOptions(correctWord, sameBandLadders, length) {
  const decoyPool = sameBandLadders.flatMap((l) => l.chain).filter((w) => w.length === length && w !== correctWord);
  const distractors = shuffle([...new Set(decoyPool)]).slice(0, 3);
  return shuffle([correctWord, ...distractors]);
}

function buildWordLadderRound(profile) {
  const item = pickItem(WORD_LADDERS, profile, "wordladder");
  const chain = item.chain;
  const middleIndices = chain.map((_, i) => i).slice(1, -1);
  const blankCount = Math.min(2, middleIndices.length);
  const blanks = shuffle(middleIndices).slice(0, blankCount).sort((a, b) => a - b);
  const sameBandLadders = WORD_LADDERS.filter((l) => l.difficulty === item.difficulty);
  const optionsByBlank = {};
  // options are computed once here (not on every render) so they stay stable while the round is in progress
  blanks.forEach((idx) => {
    optionsByBlank[idx] = buildLadderOptions(chain[idx], sameBandLadders, chain[idx].length);
  });
  return { item, chain, blanks, optionsByBlank };
}

function WordLadderGame({ profile, onProfileUpdate }) {
  const [round, setRound] = React.useState(() => buildWordLadderRound(profile));
  const [answers, setAnswers] = React.useState({});
  const [wrongCount, setWrongCount] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const maxAttempts = round.blanks.length + 3;
  const isWon = round.blanks.every((idx) => answers[idx] === round.chain[idx]);

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "wordladder", won,
      attempts: wrongCount, maxAttempts, timeSeconds,
      itemId: round.item.id, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (isWon) finish(true);
    else if (wrongCount >= maxAttempts) finish(false);
  }, [answers, wrongCount, status]);

  const choose = (blankIndex, word) => {
    if (status !== "playing" || answers[blankIndex] !== undefined) return;
    if (word === round.chain[blankIndex]) {
      setAnswers((a) => ({ ...a, [blankIndex]: word }));
    } else {
      setWrongCount((c) => c + 1);
    }
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildWordLadderRound(profile));
    setAnswers({});
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  const nextBlank = round.blanks.find((idx) => answers[idx] === undefined);

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">כל מילה משתנה באות אחת בלבד מקודמתה. השלימו את החוליות החסרות.</p>
      <div className="text-sm text-gray-400">טעויות: {wrongCount} / {maxAttempts}</div>
      <div dir="ltr" className="flex flex-col gap-2 items-center">
        {round.chain.map((word, i) => {
          const isBlank = round.blanks.includes(i);
          const revealed = !isBlank || answers[i] !== undefined;
          return (
            <div
              key={i}
              className={`px-4 py-2 rounded-lg text-xl font-bold tracking-widest ${
                revealed ? "bg-gray-700" : "bg-yellow-700/40 border-2 border-dashed border-yellow-500"
              }`}
            >
              {revealed ? word : "?".repeat(word.length)}
            </div>
          );
        })}
      </div>
      {status === "playing" && nextBlank !== undefined && (
        <div className="w-full max-w-sm grid grid-cols-2 gap-2" dir="ltr">
          {round.optionsByBlank[nextBlank].map((opt) => (
            <button
              key={opt}
              onClick={() => choose(nextBlank, opt)}
              className="bg-gray-700 hover:bg-gray-600 rounded-xl px-4 py-3 font-semibold transition-colors transform active:scale-95"
            >
              {opt}
            </button>
          ))}
        </div>
      )}
      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            סולם חדש
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "wordladder", label: "סולם מילים", icon: "🪜", category: "puzzle", component: WordLadderGame });

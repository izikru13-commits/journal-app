// Zikkit — רביעיות (find 4 hidden groups of 4 related words, Connections-style).
function buildQuartetsBoard(profile) {
  const band = bandForSkill(profile.skill);
  const bandCategories = shuffle(CATEGORY_LIST.filter((c) => c.difficulty === band)).slice(0, 4);
  const words = shuffle(bandCategories.flatMap((c) => c.words.map((w) => ({ word: w, categoryId: c.id }))));
  return { categories: bandCategories, words };
}

function QuartetsGame({ profile, onProfileUpdate }) {
  const MAX_WRONG = 6;
  const [board, setBoard] = React.useState(() => buildQuartetsBoard(profile));
  const [selected, setSelected] = React.useState([]);
  const [solved, setSolved] = React.useState([]);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [shakeWrong, setShakeWrong] = React.useState(false);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const isWon = solved.length === board.categories.length;

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "quartets", won,
      attempts: wrongCount, maxAttempts: MAX_WRONG, timeSeconds,
      difficulty: bandForSkill(profile.skill),
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (isWon) finish(true);
    else if (wrongCount >= MAX_WRONG) finish(false);
  }, [solved, wrongCount, status]);

  const toggleWord = (word) => {
    if (status !== "playing") return;
    setSelected((sel) => (sel.includes(word) ? sel.filter((w) => w !== word) : sel.length < 4 ? [...sel, word] : sel));
  };

  const submitGroup = () => {
    if (selected.length !== 4) return;
    const catIds = new Set(board.words.filter((w) => selected.includes(w.word)).map((w) => w.categoryId));
    if (catIds.size === 1) {
      setSolved((s) => [...s, [...catIds][0]]);
    } else {
      setWrongCount((c) => c + 1);
      setShakeWrong(true);
      setTimeout(() => setShakeWrong(false), 500);
    }
    setSelected([]);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setBoard(buildQuartetsBoard(profile));
    setSelected([]);
    setSolved([]);
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  const solvedWords = new Set(solved.flatMap((id) => board.categories.find((c) => c.id === id).words));

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">מצאו 4 קבוצות של 4 מילים הקשורות זו לזו</p>
      <div className="text-sm text-gray-400">טעויות: {wrongCount} / {MAX_WRONG}</div>

      {solved.length > 0 && (
        <div className="w-full max-w-md flex flex-col gap-2" dir="ltr">
          {solved.map((id) => {
            const cat = board.categories.find((c) => c.id === id);
            return (
              <div key={id} className="bg-green-700/60 rounded-lg p-2 text-center text-sm font-semibold">
                {cat.words.join(" · ")}
              </div>
            );
          })}
        </div>
      )}

      <div dir="ltr" className={`grid grid-cols-4 gap-2 max-w-md ${shakeWrong ? "shake" : ""}`}>
        {board.words
          .filter((w) => !solvedWords.has(w.word))
          .map((w) => (
            <button
              key={w.word}
              onClick={() => toggleWord(w.word)}
              disabled={status !== "playing"}
              className={`h-14 rounded-lg text-xs md:text-sm font-semibold transition-all transform active:scale-95 ${
                selected.includes(w.word) ? "bg-blue-600" : "bg-gray-700 hover:bg-gray-600"
              }`}
            >
              {w.word}
            </button>
          ))}
      </div>

      {status === "playing" && (
        <button
          onClick={submitGroup}
          disabled={selected.length !== 4}
          className="bg-gradient-to-r from-blue-600 to-purple-600 disabled:opacity-40 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95"
        >
          שלחו קבוצה ({selected.length}/4)
        </button>
      )}

      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            לוח חדש
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "quartets", label: "רביעיות", icon: "🃏", category: "puzzle", component: QuartetsGame });

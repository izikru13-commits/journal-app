// Zikkit — תשחץ מיני (hand-authored mini crossword puzzles, fill the grid and check).
function buildCrosswordRound(profile) {
  const item = pickItem(CROSSWORD_PUZZLES, profile, "crossword");
  const userGrid = item.solution.map((row) => row.map((cell) => (cell === null ? null : "")));
  return { item, userGrid };
}

function CrosswordGame({ profile, onProfileUpdate }) {
  const [round, setRound] = React.useState(() => buildCrosswordRound(profile));
  const [grid, setGrid] = React.useState(() => round.userGrid);
  const [checksUsed, setChecksUsed] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const [wrongCells, setWrongCells] = React.useState(new Set());
  const startTimeRef = React.useRef(Date.now());

  const maxAttempts = round.item.across.length + round.item.down.length + 2;

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "crossword", won,
      attempts: checksUsed, maxAttempts, timeSeconds,
      itemId: round.item.id, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  const updateCell = (r, c, value) => {
    if (status !== "playing") return;
    const letter = value.slice(-1).toUpperCase().replace(/[^A-Z]/g, "");
    setGrid((g) => {
      const copy = g.map((row) => [...row]);
      copy[r][c] = letter;
      return copy;
    });
  };

  const checkGrid = () => {
    const newChecks = checksUsed + 1;
    setChecksUsed(newChecks);
    const wrong = new Set();
    let allCorrect = true;
    for (let r = 0; r < round.item.solution.length; r++) {
      for (let c = 0; c < round.item.solution[r].length; c++) {
        const expected = round.item.solution[r][c];
        if (expected === null) continue;
        if (grid[r][c] !== expected) {
          allCorrect = false;
          wrong.add(`${r},${c}`);
        }
      }
    }
    setWrongCells(wrong);
    if (allCorrect) {
      finish(true);
    } else if (newChecks >= maxAttempts) {
      finish(false);
    }
  };

  const next = () => {
    startTimeRef.current = Date.now();
    const fresh = buildCrosswordRound(profile);
    setRound(fresh);
    setGrid(fresh.userGrid);
    setChecksUsed(0);
    setWrongCells(new Set());
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">מלאו את התשחץ לפי הרמזים ולחצו "בדקו"</p>
      <div className="text-sm text-gray-400">בדיקות: {checksUsed} / {maxAttempts}</div>

      <div dir="ltr" className="grid gap-1" style={{ gridTemplateColumns: `repeat(${round.item.size.cols}, minmax(0,1fr))` }}>
        {round.item.solution.map((row, r) =>
          row.map((cell, c) => {
            if (cell === null) {
              return <div key={`${r}-${c}`} className="w-9 h-9 md:w-10 md:h-10" />;
            }
            const isWrong = wrongCells.has(`${r},${c}`);
            return (
              <input
                key={`${r}-${c}`}
                value={grid[r][c] || ""}
                onChange={(e) => updateCell(r, c, e.target.value)}
                disabled={status !== "playing"}
                maxLength={1}
                className={`w-9 h-9 md:w-10 md:h-10 text-center text-lg font-bold rounded border-2 uppercase ${
                  isWrong ? "border-red-500 bg-red-900/40" : "border-gray-500 bg-gray-800"
                }`}
              />
            );
          })
        )}
      </div>

      <div dir="rtl" className="w-full max-w-md grid grid-cols-1 gap-1 text-sm text-gray-300">
        <div className="font-semibold text-gray-400 mt-2">מאוזן:</div>
        {round.item.across.map((w) => (
          <div key={`a-${w.number}`}>{w.number}. {w.clue} ({w.length})</div>
        ))}
        <div className="font-semibold text-gray-400 mt-2">מאונך:</div>
        {round.item.down.map((w) => (
          <div key={`d-${w.number}`}>{w.number}. {w.clue} ({w.length})</div>
        ))}
      </div>

      {status === "playing" && (
        <button onClick={checkGrid} className="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
          בדקו
        </button>
      )}

      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            תשחץ חדש
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "crossword", label: "תשחץ מיני", icon: "📝", category: "puzzle", component: CrosswordGame });

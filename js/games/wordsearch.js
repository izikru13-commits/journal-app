// Zikkit — תפזורת (word search: place words in a grid, click first+last letter to find each one).
const WORDSEARCH_GRID_SIZE = 10;
const WORDSEARCH_WORD_COUNT = 6;
const WORDSEARCH_DIRECTIONS = [
  [0, 1], [1, 0], [1, 1], [1, -1],
];

function placeWordsInGrid(words, size) {
  const grid = Array.from({ length: size }, () => Array(size).fill(null));
  const placements = [];

  function canPlace(word, row, col, dr, dc) {
    for (let i = 0; i < word.length; i++) {
      const r = row + dr * i, c = col + dc * i;
      if (r < 0 || r >= size || c < 0 || c >= size) return false;
      const cell = grid[r][c];
      if (cell !== null && cell !== word[i]) return false;
    }
    return true;
  }

  function place(word, row, col, dr, dc) {
    for (let i = 0; i < word.length; i++) {
      grid[row + dr * i][col + dc * i] = word[i];
    }
  }

  for (const word of words) {
    for (let attempt = 0; attempt < 100; attempt++) {
      const [dr, dc] = WORDSEARCH_DIRECTIONS[Math.floor(Math.random() * WORDSEARCH_DIRECTIONS.length)];
      const row = Math.floor(Math.random() * size);
      const col = Math.floor(Math.random() * size);
      if (canPlace(word, row, col, dr, dc)) {
        place(word, row, col, dr, dc);
        placements.push({ word, row, col, dr, dc });
        break;
      }
    }
  }

  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (grid[r][c] === null) grid[r][c] = alphabet[Math.floor(Math.random() * alphabet.length)];
    }
  }

  return { grid, placements };
}

function buildWordSearchRound(profile) {
  const band = bandForSkill(profile.skill);
  const words = shuffle(WORD_LIST.filter((w) => w.difficulty === band))
    .slice(0, WORDSEARCH_WORD_COUNT)
    .map((w) => w.word);
  const { grid, placements } = placeWordsInGrid(words, WORDSEARCH_GRID_SIZE);
  return { grid, placements, words };
}

function WordSearchGame({ profile, onProfileUpdate }) {
  const MAX_WRONG = 8;
  const [round, setRound] = React.useState(() => buildWordSearchRound(profile));
  const [selStart, setSelStart] = React.useState(null);
  const [found, setFound] = React.useState([]);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const isWon = round.placements.length > 0 && found.length === round.placements.length;

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "wordsearch", won,
      attempts: wrongCount, maxAttempts: MAX_WRONG, timeSeconds,
      difficulty: bandForSkill(profile.skill),
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (isWon) finish(true);
    else if (wrongCount >= MAX_WRONG) finish(false);
  }, [found, wrongCount, status]);

  const cellKey = (r, c) => `${r},${c}`;

  const foundCells = new Set();
  found.forEach((word) => {
    const p = round.placements.find((pl) => pl.word === word);
    for (let i = 0; i < word.length; i++) {
      foundCells.add(cellKey(p.row + p.dr * i, p.col + p.dc * i));
    }
  });

  const handleCellClick = (r, c) => {
    if (status !== "playing") return;
    if (!selStart) {
      setSelStart({ r, c });
      return;
    }
    const dr = Math.sign(r - selStart.r);
    const dc = Math.sign(c - selStart.c);
    const steps = Math.max(Math.abs(r - selStart.r), Math.abs(c - selStart.c));
    const isStraight = r === selStart.r || c === selStart.c || Math.abs(r - selStart.r) === Math.abs(c - selStart.c);
    if (isStraight && steps > 0) {
      let word = "";
      for (let i = 0; i <= steps; i++) {
        word += round.grid[selStart.r + dr * i][selStart.c + dc * i];
      }
      const reversed = word.split("").reverse().join("");
      const match = round.placements.find((p) => (p.word === word || p.word === reversed) && !found.includes(p.word));
      if (match) {
        setFound((f) => [...f, match.word]);
      } else {
        setWrongCount((c2) => c2 + 1);
      }
    }
    setSelStart(null);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildWordSearchRound(profile));
    setSelStart(null);
    setFound([]);
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-4" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">לחצו על האות הראשונה ואז על האחרונה של כל מילה (בקו ישר)</p>
      <div className="flex flex-wrap gap-2 justify-center max-w-md" dir="ltr">
        {round.words.map((w) => (
          <span key={w} className={`px-2 py-1 rounded text-sm ${found.includes(w) ? "bg-green-700 line-through" : "bg-gray-700"}`}>
            {w}
          </span>
        ))}
      </div>
      <div className="text-sm text-gray-400">טעויות: {wrongCount} / {MAX_WRONG}</div>
      <div dir="ltr" className="grid gap-1" style={{ gridTemplateColumns: `repeat(${WORDSEARCH_GRID_SIZE}, minmax(0,1fr))` }}>
        {round.grid.map((row, r) =>
          row.map((letter, c) => {
            const key = cellKey(r, c);
            const isFound = foundCells.has(key);
            const isSelected = selStart && selStart.r === r && selStart.c === c;
            return (
              <button
                key={key}
                onClick={() => handleCellClick(r, c)}
                disabled={status !== "playing" || isFound}
                className={`w-7 h-7 md:w-8 md:h-8 flex items-center justify-center text-xs md:text-sm font-bold rounded ${
                  isFound ? "bg-green-600" : isSelected ? "bg-blue-600" : "bg-gray-700 hover:bg-gray-600"
                }`}
              >
                {letter}
              </button>
            );
          })
        )}
      </div>
      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            תפזורת חדשה
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "wordsearch", label: "תפזורת", icon: "🔍", category: "puzzle", component: WordSearchGame });

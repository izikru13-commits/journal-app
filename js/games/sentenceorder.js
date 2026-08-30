// Zikkit — סדר את המשפט (rebuild a shuffled sentence by tapping its word tiles in order).
function buildSentenceOrderRound(profile) {
  const item = pickItem(SENTENCE_BANK, profile, "sentenceorder");
  const fullSentence = item.template.replace("___", item.answer);
  const words = fullSentence.replace(/\.$/, "").split(" ");
  return { item, words, tiles: shuffle(words.map((w, i) => ({ word: w, id: `${i}-${w}` }))) };
}

function SentenceOrderGame({ profile, onProfileUpdate }) {
  const MAX_ATTEMPTS = 3;
  const [round, setRound] = React.useState(() => buildSentenceOrderRound(profile));
  const [built, setBuilt] = React.useState([]);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "sentenceorder", won,
      attempts: wrongCount + 1, maxAttempts: MAX_ATTEMPTS, timeSeconds,
      itemId: round.item.id, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  const availableTiles = round.tiles.filter((t) => !built.includes(t.id));

  const addTile = (tileId) => {
    if (status !== "playing") return;
    setBuilt((b) => [...b, tileId]);
  };

  const removeTile = (tileId) => {
    if (status !== "playing") return;
    setBuilt((b) => b.filter((id) => id !== tileId));
  };

  const checkAnswer = () => {
    if (built.length !== round.words.length) return;
    const builtWords = built.map((id) => round.tiles.find((t) => t.id === id).word);
    const correct = builtWords.join(" ") === round.words.join(" ");
    if (correct) {
      finish(true);
      return;
    }
    const newWrong = wrongCount + 1;
    setWrongCount(newWrong);
    if (newWrong >= MAX_ATTEMPTS) {
      finish(false);
    } else {
      setBuilt([]);
    }
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildSentenceOrderRound(profile));
    setBuilt([]);
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">סדרו את המילים למשפט נכון באנגלית</p>
      <div className="text-sm text-gray-400">ניסיונות שגויים: {wrongCount} / {MAX_ATTEMPTS}</div>

      <div dir="ltr" className="min-h-14 w-full max-w-lg flex flex-wrap gap-2 justify-center bg-gray-800/60 rounded-xl p-3">
        {built.length === 0 && <span className="text-gray-500">הקישו על המילים למטה לפי הסדר</span>}
        {built.map((id) => {
          const tile = round.tiles.find((t) => t.id === id);
          return (
            <button key={id} onClick={() => removeTile(id)} className="bg-blue-600 hover:bg-blue-700 rounded-lg px-3 py-2 font-medium">
              {tile.word}
            </button>
          );
        })}
      </div>

      <div dir="ltr" className="flex flex-wrap gap-2 justify-center max-w-lg">
        {availableTiles.map((tile) => (
          <button
            key={tile.id}
            onClick={() => addTile(tile.id)}
            disabled={status !== "playing"}
            className="bg-gray-700 hover:bg-gray-600 rounded-lg px-3 py-2 font-medium transition-colors transform active:scale-95"
          >
            {tile.word}
          </button>
        ))}
      </div>

      {status === "playing" && (
        <button
          onClick={checkAnswer}
          disabled={built.length !== round.words.length}
          className="bg-gradient-to-r from-blue-600 to-purple-600 disabled:opacity-40 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95"
        >
          בדקו משפט
        </button>
      )}

      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          <p dir="ltr" className="mb-1">{round.words.join(" ")}.</p>
          <p className="text-teal-300 mb-3">{round.item.translation}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            משפט הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "sentenceorder", label: "סדר את המשפט", icon: "🧷", category: "grammar", component: SentenceOrderGame });

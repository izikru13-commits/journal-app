// Zikkit — אנגרמות (unscramble the shuffled letters of a word).
function scrambleWord(word) {
  let scrambled;
  do {
    scrambled = shuffle(word.split("")).join("");
  } while (scrambled === word && word.length > 1);
  return scrambled;
}

function AnagramGame({ profile, onProfileUpdate }) {
  const MAX_ATTEMPTS = 3;
  const buildRound = () => {
    const item = pickItem(WORD_LIST, profile, "anagram");
    return { item, scrambled: scrambleWord(item.word) };
  };

  const [round, setRound] = React.useState(buildRound);
  const [guesses, setGuesses] = React.useState([]);
  const [currentGuess, setCurrentGuess] = React.useState("");
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const [toast, setToast] = React.useState({ show: false, message: "" });
  const startTimeRef = React.useRef(Date.now());

  const finish = (won, attemptsUsed) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "anagram", won,
      attempts: attemptsUsed, maxAttempts: MAX_ATTEMPTS, timeSeconds,
      itemId: round.item.word, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  const submitGuess = () => {
    const guess = currentGuess.trim().toUpperCase();
    if (!guess || status !== "playing") return;
    const newGuesses = [...guesses, guess];
    setGuesses(newGuesses);
    setCurrentGuess("");
    if (guess === round.item.word) {
      finish(true, newGuesses.length);
    } else if (newGuesses.length >= MAX_ATTEMPTS) {
      finish(false, newGuesses.length);
    } else {
      setToast({ show: true, message: "לא נכון, נסו שוב" });
    }
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildRound());
    setGuesses([]);
    setCurrentGuess("");
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">פענחו את המילה מהאותיות המעורבבות</p>
      <div dir="ltr" className="text-3xl font-bold tracking-widest text-yellow-400">{round.scrambled}</div>
      <p className="text-teal-300 text-sm">רמז: {round.item.translation}</p>
      {status === "playing" && (
        <div dir="ltr" className="flex gap-2 w-full max-w-sm">
          <input
            type="text"
            value={currentGuess}
            onChange={(e) => setCurrentGuess(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && submitGuess()}
            className="flex-1 bg-gray-700 rounded-xl px-4 py-3 text-lg text-center focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button onClick={submitGuess} className="bg-blue-600 hover:bg-blue-700 px-5 py-3 rounded-xl font-semibold">אישור</button>
        </div>
      )}
      <Toast message={toast.message} show={toast.show} onClose={() => setToast((t) => ({ ...t, show: false }))} />
      {status !== "playing" && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          <p dir="ltr" className="text-lg mb-3">{round.item.word}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            מילה הבאה
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "anagram", label: "אנגרמות", icon: "🔠", category: "puzzle", component: AnagramGame });

// Zikkit — תלייה (classic hangman: guess the word one letter at a time).
const HANGMAN_MAX_WRONG = 6;
const HANGMAN_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

function HangmanGame({ profile, onProfileUpdate }) {
  const [item, setItem] = React.useState(() => pickItem(WORD_LIST, profile, "hangman"));
  const [guessed, setGuessed] = React.useState([]);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const letters = item.word.split("");
  const isWon = letters.every((l) => guessed.includes(l));

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "hangman", won,
      attempts: wrongCount, maxAttempts: HANGMAN_MAX_WRONG, timeSeconds,
      itemId: item.word, difficulty: item.difficulty,
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (isWon) finish(true);
    else if (wrongCount >= HANGMAN_MAX_WRONG) finish(false);
  }, [guessed, wrongCount, status]);

  const guessLetter = (letter) => {
    if (status !== "playing" || guessed.includes(letter)) return;
    setGuessed((g) => [...g, letter]);
    if (!letters.includes(letter)) setWrongCount((c) => c + 1);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setItem(pickItem(WORD_LIST, profile, "hangman"));
    setGuessed([]);
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6">
      <p dir="rtl" className="text-gray-400 text-sm text-center max-w-md">נחשו את המילה אות אחר אות. מקסימום {HANGMAN_MAX_WRONG} טעויות.</p>
      <div dir="rtl" className="text-lg">טעויות: {wrongCount} / {HANGMAN_MAX_WRONG}</div>
      <div dir="ltr" className="flex gap-2 flex-wrap justify-center">
        {letters.map((l, i) => (
          <div key={i} className="w-10 h-12 flex items-end justify-center border-b-4 border-gray-500 text-2xl font-bold">
            {guessed.includes(l) || status !== "playing" ? l : ""}
          </div>
        ))}
      </div>
      <div dir="ltr" className="grid grid-cols-7 gap-1.5 max-w-md">
        {HANGMAN_ALPHABET.map((l) => {
          const used = guessed.includes(l);
          const correct = used && letters.includes(l);
          const wrong = used && !letters.includes(l);
          let style = "bg-gray-700 hover:bg-gray-600";
          if (correct) style = "bg-green-600";
          if (wrong) style = "bg-red-600 opacity-50";
          return (
            <button
              key={l}
              disabled={used || status !== "playing"}
              onClick={() => guessLetter(l)}
              className={`${style} h-10 rounded-lg font-semibold transition-colors`}
            >
              {l}
            </button>
          );
        })}
      </div>
      {status !== "playing" && (
        <div dir="rtl" className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          <p dir="ltr" className="text-lg mb-1">{item.word}</p>
          <p className="text-teal-300 mb-3">{item.translation}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            מילה הבאה
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "hangman", label: "תלייה", icon: "🪢", category: "spelling", component: HangmanGame });

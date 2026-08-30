// Zikkit — מירוץ הקלדה (60-second sprint: type as many correctly-translated words as possible).
const TYPING_SPRINT_SECONDS = 60;
const TYPING_SPRINT_WIN_THRESHOLD = 5;

function TypingSprintGame({ profile, onProfileUpdate }) {
  const [item, setItem] = React.useState(() => pickItem(WORD_LIST, profile, "typingsprint"));
  const [currentGuess, setCurrentGuess] = React.useState("");
  const [correctCount, setCorrectCount] = React.useState(0);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [timeLeft, setTimeLeft] = React.useState(TYPING_SPRINT_SECONDS);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);

  const finish = () => {
    setStatus("done");
    const totalAttempted = correctCount + wrongCount;
    const won = correctCount >= TYPING_SPRINT_WIN_THRESHOLD;
    // No single target word for a whole sprint, so "attempts" is repurposed as an
    // accuracy ratio (wrong / total) fed into the same efficiency formula as other games.
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "typingsprint", won,
      attempts: wrongCount, maxAttempts: Math.max(1, totalAttempted), timeSeconds: TYPING_SPRINT_SECONDS,
      difficulty: bandForSkill(profile.skill),
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (timeLeft <= 0) {
      finish();
      return;
    }
    const timer = setTimeout(() => setTimeLeft((t) => t - 1), 1000);
    return () => clearTimeout(timer);
  }, [timeLeft, status]);

  const submitGuess = () => {
    const guess = currentGuess.trim().toUpperCase();
    if (!guess || status !== "playing") return;
    if (guess === item.word) setCorrectCount((c) => c + 1);
    else setWrongCount((c) => c + 1);
    setCurrentGuess("");
    setItem(pickItem(WORD_LIST, profile, "typingsprint"));
  };

  const next = () => {
    setItem(pickItem(WORD_LIST, profile, "typingsprint"));
    setCurrentGuess("");
    setCorrectCount(0);
    setWrongCount(0);
    setTimeLeft(TYPING_SPRINT_SECONDS);
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">הקלידו את המילה באנגלית לפי התרגום, כמה שיותר מהר!</p>
      <div className="text-2xl font-bold text-yellow-400">⏱ {timeLeft}</div>
      <div className="flex gap-6 text-lg">
        <span className="text-green-400">✓ {correctCount}</span>
        <span className="text-red-400">✗ {wrongCount}</span>
      </div>
      {status === "playing" ? (
        <>
          <div className="text-2xl font-bold text-teal-300">{item.translation}</div>
          <div dir="ltr" className="flex gap-2 w-full max-w-sm">
            <input
              autoFocus
              type="text"
              value={currentGuess}
              onChange={(e) => setCurrentGuess(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && submitGuess()}
              className="flex-1 bg-gray-700 rounded-xl px-4 py-3 text-lg text-center focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button onClick={submitGuess} className="bg-blue-600 hover:bg-blue-700 px-5 py-3 rounded-xl font-semibold">אישור</button>
          </div>
        </>
      ) : (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">הזמן נגמר!</p>
          <p className="mb-3">ענית נכון על {correctCount} מילים</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            עוד סיבוב
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "typingsprint", label: "מירוץ הקלדה", icon: "⌨️", category: "speed", component: TypingSprintGame });

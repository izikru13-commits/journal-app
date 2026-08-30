// Zikkit — משחק זיכרון (flip cards, match an English word to its Hebrew translation).
function buildMemoryDeck(profile) {
  const band = bandForSkill(profile.skill);
  const pool = shuffle(WORD_LIST.filter((w) => w.difficulty === band)).slice(0, 8);
  const cards = [];
  pool.forEach((item, i) => {
    cards.push({ id: `w-${i}`, pairId: i, label: item.word, dir: "ltr" });
    cards.push({ id: `t-${i}`, pairId: i, label: item.translation, dir: "rtl" });
  });
  return { cards: shuffle(cards), pool };
}

function MemoryGame({ profile, onProfileUpdate }) {
  const MAX_WRONG = 10;
  const [deck, setDeck] = React.useState(() => buildMemoryDeck(profile));
  const [flipped, setFlipped] = React.useState([]);
  const [matched, setMatched] = React.useState([]);
  const [wrongCount, setWrongCount] = React.useState(0);
  const [status, setStatus] = React.useState("playing");
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const isWon = matched.length === deck.pool.length;

  const finish = (won) => {
    setStatus(won ? "won" : "lost");
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    // Memory has no single "item" identity (a fresh 8-word board each round), so itemId is
    // intentionally omitted — recordRound() skips playedItems tracking when itemId is absent.
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "memory", won,
      attempts: wrongCount, maxAttempts: MAX_WRONG, timeSeconds,
      difficulty: bandForSkill(profile.skill),
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (status !== "playing") return;
    if (isWon) finish(true);
    else if (wrongCount >= MAX_WRONG) finish(false);
  }, [matched, wrongCount, status]);

  const handleFlip = (card) => {
    if (status !== "playing" || flipped.length === 2) return;
    if (flipped.includes(card.id) || matched.includes(card.pairId)) return;
    const newFlipped = [...flipped, card.id];
    setFlipped(newFlipped);
    if (newFlipped.length === 2) {
      const [firstId, secondId] = newFlipped;
      const first = deck.cards.find((c) => c.id === firstId);
      const second = deck.cards.find((c) => c.id === secondId);
      if (first.pairId === second.pairId) {
        setTimeout(() => {
          setMatched((m) => [...m, first.pairId]);
          setFlipped([]);
        }, 500);
      } else {
        setWrongCount((c) => c + 1);
        setTimeout(() => setFlipped([]), 800);
      }
    }
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setDeck(buildMemoryDeck(profile));
    setFlipped([]);
    setMatched([]);
    setWrongCount(0);
    setStatus("playing");
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6">
      <p dir="rtl" className="text-gray-400 text-sm text-center max-w-md">מצאו את הזוגות התואמים - מילה באנגלית והתרגום שלה</p>
      <div dir="rtl" className="text-sm text-gray-400">טעויות: {wrongCount} / {MAX_WRONG}</div>
      <div className="grid grid-cols-4 gap-2 max-w-md" dir="ltr">
        {deck.cards.map((card) => {
          const isFaceUp = flipped.includes(card.id) || matched.includes(card.pairId);
          return (
            <button
              key={card.id}
              onClick={() => handleFlip(card)}
              dir={card.dir}
              className={`h-16 md:h-20 rounded-lg flex items-center justify-center text-sm md:text-base font-semibold p-1 text-center transition-all transform active:scale-95 ${
                matched.includes(card.pairId) ? "bg-green-600" : isFaceUp ? "bg-blue-600" : "bg-gray-700 hover:bg-gray-600"
              }`}
            >
              {isFaceUp ? card.label : "❓"}
            </button>
          );
        })}
      </div>
      {status !== "playing" && (
        <div dir="rtl" className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-xl font-bold mb-2">{status === "won" ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            משחק חדש
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "memory", label: "משחק זיכרון", icon: "🧠", category: "vocab", component: MemoryGame });

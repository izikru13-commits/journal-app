// Zikkit (זיקית) — English Wordle, first playable game. Hebrew UI chrome around an English word.
const { useState, useEffect, useRef } = React;

const WORD_LENGTH = 5;
const MAX_GUESSES = 6;
const KEYBOARD_ROWS = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["ENTER", "Z", "X", "C", "V", "B", "N", "M", "BACKSPACE"],
];

const TILE_COLORS = {
  green: "bg-green-600 border-green-600 text-white",
  yellow: "bg-yellow-500 border-yellow-500 text-gray-900",
  gray: "bg-gray-700 border-gray-700 text-gray-300",
  empty: "border-gray-600 text-white",
};

const KEY_COLORS = {
  green: "bg-green-600 text-white",
  yellow: "bg-yellow-500 text-gray-900",
  gray: "bg-gray-700 text-gray-400",
  empty: "bg-gray-500 text-white hover:bg-gray-400",
};

// Two-pass Wordle feedback: greens are locked in first (and consumed from the letter pool)
// so a duplicate letter in the guess doesn't wrongly earn two yellows against a single
// occurrence in the answer.
function computeFeedback(guess, answer) {
  const result = Array(WORD_LENGTH).fill("gray");
  const letterCount = {};
  for (const ch of answer) letterCount[ch] = (letterCount[ch] || 0) + 1;

  for (let i = 0; i < WORD_LENGTH; i++) {
    if (guess[i] === answer[i]) {
      result[i] = "green";
      letterCount[guess[i]] -= 1;
    }
  }
  for (let i = 0; i < WORD_LENGTH; i++) {
    if (result[i] === "green") continue;
    const ch = guess[i];
    if (letterCount[ch] > 0) {
      result[i] = "yellow";
      letterCount[ch] -= 1;
    }
  }
  return result;
}

function getKeyStatuses(guesses) {
  const rank = { gray: 0, yellow: 1, green: 2 };
  const statuses = {};
  guesses.forEach((g) => {
    g.word.split("").forEach((ch, i) => {
      const fb = g.feedback[i];
      if (!statuses[ch] || rank[fb] > rank[statuses[ch]]) statuses[ch] = fb;
    });
  });
  return statuses;
}

function GuessRow({ word, feedback, isCurrent, currentGuess, shake }) {
  const letters = feedback
    ? word.split("")
    : Array.from({ length: WORD_LENGTH }, (_, i) => (isCurrent ? currentGuess[i] || "" : ""));

  return (
    <div className={`grid grid-cols-5 gap-1.5 ${shake ? "shake" : ""}`}>
      {letters.map((letter, i) => {
        const status = feedback ? feedback[i] : "empty";
        return (
          <div
            key={i}
            style={feedback ? { animationDelay: `${i * 100}ms` } : undefined}
            className={`w-12 h-12 md:w-14 md:h-14 flex items-center justify-center border-2 rounded-lg text-2xl font-bold uppercase ${TILE_COLORS[status]} ${feedback ? "tile-reveal" : ""}`}
          >
            {letter}
          </div>
        );
      })}
    </div>
  );
}

function Keyboard({ onKey, keyStatuses }) {
  return (
    <div className="flex flex-col items-center gap-1.5 mt-4 w-full max-w-md">
      {KEYBOARD_ROWS.map((row, rowIndex) => (
        <div key={rowIndex} className="flex gap-1.5 w-full justify-center">
          {row.map((key) => {
            const isWide = key === "ENTER" || key === "BACKSPACE";
            const status = keyStatuses[key] || "empty";
            return (
              <button
                key={key}
                onClick={() => onKey(key)}
                className={`${isWide ? "px-2 text-xs md:text-sm flex-[1.5]" : "flex-1 text-sm md:text-base"} h-11 md:h-12 rounded-lg font-semibold uppercase transition-colors active:scale-95 ${KEY_COLORS[status]}`}
              >
                {key === "BACKSPACE" ? "⌫" : key === "ENTER" ? "אישור" : key}
              </button>
            );
          })}
        </div>
      ))}
    </div>
  );
}

function ResultModal({ won, target, guessesUsed, timeSeconds, profile, levelChange, onNext }) {
  return (
    <div className="fixed inset-0 bg-black/60 modal-backdrop flex items-center justify-center z-50 p-4" dir="rtl">
      <div className="bg-gray-800 rounded-2xl p-6 md:p-8 max-w-sm w-full border border-gray-700 shadow-2xl text-center">
        <h2 className="text-3xl font-bold mb-2">{won ? "כל הכבוד! 🎉" : "בפעם הבאה! 💪"}</h2>
        <p className="text-gray-400 mb-4">
          {won ? `פתרת ב-${guessesUsed} ניסיונות, תוך ${timeSeconds} שניות` : "נגמרו הניסיונות הפעם"}
        </p>

        <div className="bg-gray-700/50 rounded-xl p-4 mb-4">
          <div dir="ltr" className="text-2xl font-bold tracking-widest mb-1">
            {target.word}
          </div>
          <div className="text-lg text-teal-300">{target.translation}</div>
        </div>

        {levelChange && (
          <div className="mb-4 text-sm font-semibold text-purple-300">
            {levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר, ממשיכים להתקדם 💪"} — הרמה החדשה: {BAND_LABELS[profile.band]}
          </div>
        )}

        <button
          onClick={onNext}
          className="w-full bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 py-3 rounded-xl font-semibold text-lg transition-all transform active:scale-95"
        >
          מילה הבאה
        </button>
      </div>
    </div>
  );
}

function WordleGame({ profile, onProfileUpdate }) {
  const [target, setTarget] = useState(() => pickWord(profile));
  const [guesses, setGuesses] = useState([]);
  const [currentGuess, setCurrentGuess] = useState("");
  const [status, setStatus] = useState("playing"); // playing | won | lost
  const [shake, setShake] = useState(false);
  const [toast, setToast] = useState({ show: false, message: "", type: "error" });
  const [levelChange, setLevelChange] = useState(null); // "up" | "down" | null
  const startTimeRef = useRef(Date.now());

  const showToast = (message, type = "error") => setToast({ show: true, message, type });
  const hideToast = () => setToast((t) => ({ ...t, show: false }));

  const triggerShake = () => {
    setShake(true);
    setTimeout(() => setShake(false), 500);
  };

  const finishRound = (won, guessesUsed) => {
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange } = finishGame({
      profile,
      onProfileUpdate,
      gameId: "wordle",
      won,
      attempts: guessesUsed,
      maxAttempts: MAX_GUESSES,
      timeSeconds,
      itemId: target.word,
      difficulty: target.difficulty,
      word: target.word,
    });
    setStatus(won ? "won" : "lost");
    setLevelChange(levelChange);
  };

  const handleKey = (key) => {
    if (status !== "playing") return;
    if (key === "ENTER") {
      if (currentGuess.length !== WORD_LENGTH) {
        triggerShake();
        showToast("צריך מילה בת 5 אותיות");
        return;
      }
      const feedback = computeFeedback(currentGuess, target.word);
      const newGuesses = [...guesses, { word: currentGuess, feedback }];
      setGuesses(newGuesses);
      setCurrentGuess("");

      const won = currentGuess === target.word;
      if (won) {
        finishRound(true, newGuesses.length);
      } else if (newGuesses.length >= MAX_GUESSES) {
        finishRound(false, newGuesses.length);
      }
      return;
    }
    if (key === "BACKSPACE") {
      setCurrentGuess((g) => g.slice(0, -1));
      return;
    }
    if (/^[A-Z]$/.test(key) && currentGuess.length < WORD_LENGTH) {
      setCurrentGuess((g) => g + key);
    }
  };

  useEffect(() => {
    function onKeyDown(e) {
      if (status !== "playing") return;
      if (e.key === "Enter") handleKey("ENTER");
      else if (e.key === "Backspace") handleKey("BACKSPACE");
      else if (/^[a-zA-Z]$/.test(e.key)) handleKey(e.key.toUpperCase());
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const startNewRound = () => {
    startTimeRef.current = Date.now();
    setTarget(pickWord(profile));
    setGuesses([]);
    setCurrentGuess("");
    setStatus("playing");
    setLevelChange(null);
  };

  const keyStatuses = getKeyStatuses(guesses);
  const emptyRows = Math.max(0, MAX_GUESSES - guesses.length - (status === "playing" ? 1 : 0));

  return (
    <div className="w-full flex flex-col items-center" dir="ltr">
      <p dir="rtl" className="text-gray-400 text-sm md:text-base mb-4 text-center max-w-md">
        נחשו מילה באנגלית בת 5 אותיות ב-6 ניסיונות. ירוק = אות נכונה במקום הנכון, צהוב = האות
        קיימת אך במקום אחר, אפור = האות לא קיימת במילה.
      </p>

      <div className="flex flex-col gap-1.5 mb-2">
        {guesses.map((g, i) => (
          <GuessRow key={i} word={g.word} feedback={g.feedback} />
        ))}
        {status === "playing" && <GuessRow isCurrent currentGuess={currentGuess} shake={shake} />}
        {Array.from({ length: emptyRows }).map((_, i) => (
          <GuessRow key={`empty-${i}`} isCurrent={false} currentGuess="" />
        ))}
      </div>

      <Keyboard onKey={handleKey} keyStatuses={keyStatuses} />

      <Toast message={toast.message} show={toast.show} type={toast.type} onClose={hideToast} />

      {status !== "playing" && (
        <ResultModal
          won={status === "won"}
          target={target}
          guessesUsed={guesses.length}
          timeSeconds={Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000))}
          profile={profile}
          levelChange={levelChange}
          onNext={startNewRound}
        />
      )}
    </div>
  );
}

registerGame({ id: "wordle", label: "וורדל", icon: "🔤", category: "spelling", component: WordleGame });

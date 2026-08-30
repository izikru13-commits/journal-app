// Zikkit — תרגום מהיר (Hebrew word flashes, pick the correct English translation under a timer).
const SPEED_TRANSLATE_SECONDS = 8;

function SpeedTranslateGame({ profile, onProfileUpdate }) {
  const buildRound = () => {
    const band = bandForSkill(profile.skill);
    const item = pickItem(WORD_LIST, profile, "speedtranslate");
    const bandPool = WORD_LIST.filter((w) => w.difficulty === band && w.word !== item.word);
    const distractors = shuffle(bandPool)
      .slice(0, 3)
      .map((w) => w.word);
    const options = shuffle([item.word, ...distractors]);
    return { item, options, correctIndex: options.indexOf(item.word) };
  };

  const [round, setRound] = React.useState(buildRound);
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const [timeLeft, setTimeLeft] = React.useState(SPEED_TRANSLATE_SECONDS);
  const startTimeRef = React.useRef(Date.now());

  const finish = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === round.correctIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "speedtranslate", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: round.item.word, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  React.useEffect(() => {
    if (answered) return;
    if (timeLeft <= 0) {
      finish(-1); // ran out of time = wrong
      return;
    }
    const timer = setTimeout(() => setTimeLeft((t) => t - 1), 1000);
    return () => clearTimeout(timer);
  }, [timeLeft, answered]);

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildRound());
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
    setTimeLeft(SPEED_TRANSLATE_SECONDS);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">בחרו את התרגום הנכון לפני שהזמן נגמר</p>
      <div className="text-2xl font-bold text-yellow-400">⏱ {timeLeft}</div>
      <ChoiceQuestion
        prompt={round.item.translation}
        options={round.options}
        onAnswer={finish}
        disabled={answered}
        correctIndex={round.correctIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "speedtranslate", label: "תרגום מהיר", icon: "⚡", category: "speed", component: SpeedTranslateGame });

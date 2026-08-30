// Zikkit — דיוק דקדוקי (fill-in-the-blank, grammar focus). Same mechanic as cloze.js, different pool.
function GrammarGame({ profile, onProfileUpdate }) {
  const pool = SENTENCE_BANK.filter((s) => s.skill === "grammar");
  const [item, setItem] = React.useState(() => pickItem(pool, profile, "grammar"));
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const correctIndex = item.options.indexOf(item.answer);

  const handleAnswer = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === correctIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "grammar", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: item.id, difficulty: item.difficulty,
    });
    setLevelChange(change);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setItem(pickItem(pool, profile, "grammar"));
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">בחרו את המילה הנכונה מבחינה דקדוקית</p>
      <ChoiceQuestion
        prompt={item.template}
        promptDir="ltr"
        options={item.options}
        onAnswer={handleAnswer}
        disabled={answered}
        correctIndex={correctIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-teal-300 mb-3">{item.translation}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            משפט הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "grammar", label: "דיוק דקדוקי", icon: "🧩", category: "grammar", component: GrammarGame });

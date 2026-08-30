// Zikkit — פעלים לא-סדירים (pick the correct past-simple form of an irregular verb).
function IrregularVerbsGame({ profile, onProfileUpdate }) {
  const buildRound = () => {
    const band = bandForSkill(profile.skill);
    const item = pickItem(IRREGULAR_VERBS, profile, "irregularverbs");
    const bandPool = IRREGULAR_VERBS.filter((v) => v.difficulty === band && v.id !== item.id);
    const distractors = shuffle(bandPool)
      .slice(0, 3)
      .map((v) => v.past);
    const options = shuffle([item.past, ...distractors]);
    return { item, options, correctIndex: options.indexOf(item.past) };
  };

  const [round, setRound] = React.useState(buildRound);
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const handleAnswer = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === round.correctIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "irregularverbs", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: round.item.id, difficulty: round.item.difficulty,
    });
    setLevelChange(change);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildRound());
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">בחרו את צורת העבר הנכונה של הפועל</p>
      <ChoiceQuestion
        prompt={`${round.item.base} (${round.item.translation}) — מה צורת העבר?`}
        options={round.options}
        onAnswer={handleAnswer}
        disabled={answered}
        correctIndex={round.correctIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-teal-300 mb-3" dir="ltr">{round.item.base} → {round.item.past} → {round.item.participle}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "irregularverbs", label: "פעלים לא-סדירים", icon: "⏳", category: "grammar", component: IrregularVerbsGame });

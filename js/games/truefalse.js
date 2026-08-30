// Zikkit — אמת או שקר (word + translation, sometimes deliberately wrong).
function TrueFalseGame({ profile, onProfileUpdate }) {
  const buildRound = () => {
    const band = bandForSkill(profile.skill);
    const item = pickItem(WORD_LIST, profile, "truefalse");
    const isTrue = Math.random() < 0.5;
    let shownTranslation = item.translation;
    if (!isTrue) {
      const otherPool = WORD_LIST.filter((w) => w.difficulty === band && w.word !== item.word);
      const decoy = otherPool[Math.floor(Math.random() * otherPool.length)];
      shownTranslation = decoy.translation;
    }
    return { item, isTrue, shownTranslation };
  };

  const [round, setRound] = React.useState(buildRound);
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const options = ["נכון", "לא נכון"];
  const correctIndex = round.isTrue ? 0 : 1;

  const handleAnswer = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === correctIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "truefalse", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: round.item.word, difficulty: round.item.difficulty,
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
      <p className="text-gray-400 text-sm text-center max-w-md">האם התרגום נכון?</p>
      <ChoiceQuestion
        prompt={`${round.item.word} = ${round.shownTranslation}`}
        promptDir="ltr"
        options={options}
        optionDir="rtl"
        onAnswer={handleAnswer}
        disabled={answered}
        correctIndex={correctIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-teal-300 mb-3">{round.item.word} = {round.item.translation}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "truefalse", label: "אמת או שקר", icon: "✅", category: "vocab", component: TrueFalseGame });

// Zikkit — הזר בחבורה (3 words from one category + 1 intruder from another; find the intruder).
function buildOddOneOutRound(profile) {
  const band = bandForSkill(profile.skill);
  const bandCategories = CATEGORY_LIST.filter((c) => c.difficulty === band);
  const [mainCat, otherCat] = shuffle(bandCategories).slice(0, 2);
  const threeWords = shuffle(mainCat.words).slice(0, 3);
  const intruder = shuffle(otherCat.words)[0];
  const options = shuffle([...threeWords, intruder]);
  return { options, correctIndex: options.indexOf(intruder), category: mainCat };
}

function OddOneOutGame({ profile, onProfileUpdate }) {
  const [round, setRound] = React.useState(() => buildOddOneOutRound(profile));
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
      profile, onProfileUpdate, gameId: "oddoneout", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      difficulty: round.category.difficulty,
    });
    setLevelChange(change);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setRound(buildOddOneOutRound(profile));
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">איזו מילה היא הזרה בחבורה?</p>
      <ChoiceQuestion
        prompt="בחרו את המילה שלא שייכת"
        options={round.options}
        onAnswer={handleAnswer}
        disabled={answered}
        correctIndex={round.correctIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          <p className="text-teal-300 mb-3">שאר המילים שייכות לקטגוריה: {round.category.label}</p>
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "oddoneout", label: "הזר בחבורה", icon: "🎭", category: "puzzle", component: OddOneOutGame });

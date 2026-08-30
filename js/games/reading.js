// Zikkit — הבנת הנקרא (short passage + one comprehension question).
function ReadingGame({ profile, onProfileUpdate }) {
  const [item, setItem] = React.useState(() => pickItem(READING_PASSAGES, profile, "reading"));
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const handleAnswer = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === item.answerIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "reading", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: item.id, difficulty: item.difficulty,
    });
    setLevelChange(change);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setItem(pickItem(READING_PASSAGES, profile, "reading"));
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">קראו את הקטע וענו על השאלה</p>
      <div dir="ltr" className="w-full max-w-md bg-gray-800/60 rounded-xl p-5 text-lg leading-relaxed">
        {item.passage}
      </div>
      <ChoiceQuestion
        prompt={item.question}
        options={item.options}
        optionDir="rtl"
        onAnswer={handleAnswer}
        disabled={answered}
        correctIndex={item.answerIndex}
        selectedIndex={selected}
      />
      {answered && (
        <div className="w-full max-w-md bg-gray-800/60 rounded-xl p-4 text-center">
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            קטע הבא
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "reading", label: "הבנת הנקרא", icon: "📖", category: "reading", component: ReadingGame });

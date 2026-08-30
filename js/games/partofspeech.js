// Zikkit — זיהוי חלק דיבר (classify a word as noun/verb/adjective).
const POS_OPTIONS = [
  { value: "noun", label: "שם עצם" },
  { value: "verb", label: "פועל" },
  { value: "adjective", label: "שם תואר" },
];

function PartOfSpeechGame({ profile, onProfileUpdate }) {
  const [item, setItem] = React.useState(() => pickItem(POS_WORDS, profile, "partofspeech"));
  const [selected, setSelected] = React.useState(null);
  const [answered, setAnswered] = React.useState(false);
  const [levelChange, setLevelChange] = React.useState(null);
  const startTimeRef = React.useRef(Date.now());

  const correctIndex = POS_OPTIONS.findIndex((o) => o.value === item.pos);
  const options = POS_OPTIONS.map((o) => o.label);

  const handleAnswer = (index) => {
    if (answered) return;
    setSelected(index);
    setAnswered(true);
    const won = index === correctIndex;
    const timeSeconds = Math.max(1, Math.round((Date.now() - startTimeRef.current) / 1000));
    const { levelChange: change } = finishGame({
      profile, onProfileUpdate, gameId: "partofspeech", won,
      attempts: 1, maxAttempts: 1, timeSeconds,
      itemId: item.id, difficulty: item.difficulty,
    });
    setLevelChange(change);
  };

  const next = () => {
    startTimeRef.current = Date.now();
    setItem(pickItem(POS_WORDS, profile, "partofspeech"));
    setSelected(null);
    setAnswered(false);
    setLevelChange(null);
  };

  return (
    <div className="w-full flex flex-col items-center gap-6" dir="rtl">
      <p className="text-gray-400 text-sm text-center max-w-md">איזה חלק דיבר היא המילה?</p>
      <ChoiceQuestion
        prompt={`${item.word} (${item.translation})`}
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
          {levelChange && <p className="text-sm text-purple-300 mb-2">{levelChange === "up" ? "עלית רמה! 🚀" : "התאמנו לך רמה קלה יותר 💪"}</p>}
          <button onClick={next} className="bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700 px-6 py-3 rounded-xl font-semibold transition-all transform active:scale-95">
            מילה הבאה
          </button>
        </div>
      )}
    </div>
  );
}

registerGame({ id: "partofspeech", label: "זיהוי חלק דיבר", icon: "🔤", category: "grammar", component: PartOfSpeechGame });

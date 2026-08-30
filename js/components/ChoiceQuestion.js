// Zikkit — shared "prompt + N options, pick one" UI used by most of the quiz-style games.
function ChoiceQuestion({ prompt, options, onAnswer, disabled, correctIndex, selectedIndex, promptDir = "rtl", optionDir = "ltr" }) {
  return (
    <div className="w-full max-w-md flex flex-col items-center gap-6">
      <div dir={promptDir} className="text-xl md:text-2xl font-semibold text-center leading-relaxed">
        {prompt}
      </div>
      <div className="w-full grid grid-cols-1 sm:grid-cols-2 gap-3">
        {options.map((option, i) => {
          let style = "bg-gray-700 hover:bg-gray-600 active:bg-gray-600";
          if (disabled) {
            if (i === correctIndex) style = "bg-green-600";
            else if (i === selectedIndex) style = "bg-red-600";
            else style = "bg-gray-700 opacity-40";
          }
          return (
            <button
              key={i}
              disabled={disabled}
              onClick={() => onAnswer(i)}
              dir={optionDir}
              className={`${style} rounded-xl px-4 py-4 text-lg font-medium transition-colors transform active:scale-95`}
            >
              {option}
            </button>
          );
        })}
      </div>
    </div>
  );
}

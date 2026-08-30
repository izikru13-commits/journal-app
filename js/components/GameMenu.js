// Zikkit — home screen: a grid of game cards grouped by category (tabs/dropdown don't scale to 22 games).
const GAME_CATEGORY_LABELS = {
  spelling: "איות",
  vocab: "אוצר מילים",
  grammar: "דקדוק",
  speed: "מהירות",
  reading: "קריאה",
  puzzle: "חידות",
};

function GameMenu({ games, onSelect }) {
  const byCategory = {};
  games.forEach((game) => {
    const category = game.category || "puzzle";
    if (!byCategory[category]) byCategory[category] = [];
    byCategory[category].push(game);
  });

  return (
    <div className="w-full max-w-4xl" dir="rtl">
      {Object.keys(GAME_CATEGORY_LABELS)
        .filter((category) => byCategory[category] && byCategory[category].length > 0)
        .map((category) => (
          <div key={category} className="mb-8">
            <h2 className="text-lg font-bold text-gray-300 mb-3">{GAME_CATEGORY_LABELS[category]}</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {byCategory[category].map((game) => (
                <button
                  key={game.id}
                  onClick={() => onSelect(game.id)}
                  className="bg-gray-800/60 hover:bg-gray-700 active:bg-gray-600 border border-gray-700/50 rounded-2xl p-4 flex flex-col items-center gap-2 transition-all transform active:scale-95 shadow-lg"
                >
                  <span className="text-3xl">{game.icon}</span>
                  <span className="text-sm font-semibold text-center">{game.label}</span>
                </button>
              ))}
            </div>
          </div>
        ))}
    </div>
  );
}

// Shared UI pieces used by all three games: a difficulty-level picker and a name+city
// leaderboard panel shown on the results screen.
(function () {
    const { useState } = React;
    const { StarIcon, Trophy } = window.GameIcons;
    const { LEVEL_LABELS, getLeaderboard, addLeaderboardEntry } = window.GameUtils;

    const LEVEL_DESCRIPTIONS = {
        1: 'המקומות המוכרים ביותר',
        2: 'מוכרים, אבל צריך לדעת קצת',
        3: 'לא מובן מאליו',
        4: 'רק למי שבאמת יודע',
    };

    function LevelSelect({ title, subtitle, onSelect, gradient }) {
        return (
            <div className="min-h-screen bg-gradient-to-br from-gray-900 via-slate-900 to-gray-900 text-white flex items-center justify-center p-4">
                <div className="max-w-md w-full text-center">
                    <h2 className="text-2xl md:text-3xl font-bold mb-2">{title}</h2>
                    {subtitle && <p className="text-gray-400 mb-6">{subtitle}</p>}
                    <div className="grid grid-cols-2 gap-3">
                        {[1, 2, 3, 4].map((lvl) => (
                            <button
                                key={lvl}
                                onClick={() => onSelect(lvl)}
                                className={`bg-gradient-to-br ${gradient} rounded-2xl p-5 text-center shadow-xl transition-all active:scale-95`}
                            >
                                <div className="text-lg font-bold">{LEVEL_LABELS[lvl]}</div>
                                <div className="text-xs text-white/80 mt-1">{LEVEL_DESCRIPTIONS[lvl]}</div>
                            </button>
                        ))}
                    </div>
                </div>
            </div>
        );
    }

    function LeaderboardPanel({ storageKey, points, extra }) {
        const [name, setName] = useState('');
        const [city, setCity] = useState('');
        const [saved, setSaved] = useState(false);
        const [list, setList] = useState(() => getLeaderboard(storageKey));

        const save = () => {
            if (!name.trim() || saved) return;
            const updated = addLeaderboardEntry(storageKey, { name: name.trim(), city: city.trim(), points, ...extra });
            setList(updated);
            setSaved(true);
        };

        return (
            <div className="mt-6 text-right">
                {!saved && (
                    <div className="bg-gray-900/60 rounded-2xl p-4 mb-4">
                        <p className="text-sm text-gray-400 mb-3">שמור את הניקוד שלך בטבלת השיאים</p>
                        <div className="flex flex-col sm:flex-row gap-2">
                            <input
                                type="text"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                placeholder="השם שלך"
                                className="flex-1 bg-gray-700 rounded-xl px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                            <input
                                type="text"
                                value={city}
                                onChange={(e) => setCity(e.target.value)}
                                placeholder="עיר (לא חובה)"
                                className="flex-1 bg-gray-700 rounded-xl px-4 py-3 text-base focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                            <button
                                onClick={save}
                                disabled={!name.trim()}
                                className="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 disabled:opacity-40 px-6 py-3 rounded-xl font-semibold transition-all active:scale-95 whitespace-nowrap"
                            >
                                שמור
                            </button>
                        </div>
                    </div>
                )}

                {list.length > 0 && (
                    <div className="bg-gray-900/60 rounded-2xl p-4">
                        <div className="flex items-center gap-2 mb-3">
                            <Trophy className="w-4 h-4 text-yellow-400" />
                            <h4 className="font-semibold">טבלת השיאים</h4>
                        </div>
                        <ol className="space-y-1">
                            {list.slice(0, 10).map((entry, i) => (
                                <li key={i} className="flex items-center justify-between text-sm bg-gray-800/60 rounded-lg px-3 py-2">
                                    <span className="text-gray-400 w-6">{i + 1}.</span>
                                    <span className="flex-1 text-right truncate">
                                        {entry.name}
                                        {entry.city && <span className="text-gray-500"> · {entry.city}</span>}
                                    </span>
                                    <span className="font-bold text-blue-300 ml-2">{entry.points.toLocaleString()}</span>
                                </li>
                            ))}
                        </ol>
                    </div>
                )}
            </div>
        );
    }

    window.GameChrome = { LevelSelect, LeaderboardPanel };
})();

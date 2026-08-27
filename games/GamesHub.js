// Hub screen listing the three geography games and switching between them.
(function () {
    const { useState, useEffect } = React;
    const { MapPinIcon, FlagIcon, GlobeIcon, StarIcon } = window.GameIcons;

    const GAME_META = [
        {
            key: 'mapGuess',
            title: 'ניחוש עיר על המפה',
            description: 'שם עיר בישראל מוצג לך - יש לך 10 שניות לסמן במפה איפה היא נמצאת.',
            icon: MapPinIcon,
            gradient: 'from-blue-500 to-purple-600',
            highScoreKey: 'gameHighScore_mapGuess',
        },
        {
            key: 'flagGuess',
            title: 'ניחוש דגלים',
            description: 'דגל של מדינה בעולם מוצג לך - בחרו את המדינה הנכונה וגלו עליה עובדה מעניינת.',
            icon: FlagIcon,
            gradient: 'from-pink-500 to-red-600',
            highScoreKey: 'gameHighScore_flagGuess',
        },
        {
            key: 'globeGuess',
            title: 'מדינה על הגלובוס',
            description: 'שם מדינה מוצג לך - סובבו גלובוס תלת-ממדי ולחצו על המיקום שלה.',
            icon: GlobeIcon,
            gradient: 'from-cyan-500 to-teal-600',
            highScoreKey: 'gameHighScore_globeGuess',
        },
    ];

    function GamesHub({ onExit }) {
        const [activeGame, setActiveGame] = useState(null);
        const [highScores, setHighScores] = useState({});

        useEffect(() => {
            const scores = {};
            GAME_META.forEach((g) => {
                try {
                    const saved = JSON.parse(localStorage.getItem(g.highScoreKey) || 'null');
                    scores[g.key] = saved ? saved.best : null;
                } catch (e) {
                    scores[g.key] = null;
                }
            });
            setHighScores(scores);
        }, [activeGame]);

        if (activeGame === 'mapGuess') {
            return <window.CityMapGame onExit={() => setActiveGame(null)} />;
        }
        if (activeGame === 'flagGuess') {
            return <window.FlagGuessGame onExit={() => setActiveGame(null)} />;
        }
        if (activeGame === 'globeGuess') {
            return <window.GlobeGuessGame onExit={() => setActiveGame(null)} />;
        }

        return (
            <div className="min-h-screen bg-gradient-to-br from-gray-900 via-slate-900 to-gray-900 text-white p-4 md:p-8 pb-24 md:pb-8">
                <div className="max-w-5xl mx-auto">
                    <button
                        onClick={onExit}
                        className="flex items-center gap-2 mb-4 md:mb-6 text-gray-400 hover:text-white active:text-white transition-colors py-2"
                    >
                        <Home className="w-5 h-5 md:w-6 md:h-6" />
                        <span className="text-base md:text-lg">חזרה לדף הבית</span>
                    </button>

                    <div className="mb-6 md:mb-8 text-center">
                        <h1 className="text-3xl md:text-5xl font-bold mb-2 md:mb-3 bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
                            משחקי גיאוגרפיה
                        </h1>
                        <p className="text-gray-400 text-base md:text-lg">בחרו משחק ובדקו את הידע הגיאוגרפי שלכם</p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6">
                        {GAME_META.map((game) => {
                            const Icon = game.icon;
                            const best = highScores[game.key];
                            return (
                                <button
                                    key={game.key}
                                    onClick={() => setActiveGame(game.key)}
                                    className={`journal-card text-right rounded-2xl bg-gradient-to-br ${game.gradient} p-6 shadow-2xl transition-all active:scale-95`}
                                >
                                    <Icon className="w-10 h-10 mb-3" />
                                    <h2 className="text-xl font-bold mb-2">{game.title}</h2>
                                    <p className="text-sm text-white/80 mb-4">{game.description}</p>
                                    {best != null && (
                                        <div className="flex items-center gap-1 text-sm text-yellow-200 bg-black/20 rounded-full px-3 py-1 w-fit">
                                            <StarIcon className="w-4 h-4" />
                                            <span>השיא שלך: {best.toLocaleString()}</span>
                                        </div>
                                    )}
                                </button>
                            );
                        })}
                    </div>
                </div>
            </div>
        );
    }

    window.GamesHub = GamesHub;
})();

// Flag-guess game: a country's flag is shown, the player picks the correct country from 4 options,
// then sees a short explanation about it.
(function () {
    const { useState, useEffect } = React;
    const { FlagIcon, RefreshIcon, Trophy } = window.GameIcons;
    const { shuffle, pickRounds, flagEmoji, poolForLevel, LEVEL_LABELS } = window.GameUtils;
    const { LevelSelect, LeaderboardPanel } = window.GameChrome;

    const TOTAL_ROUNDS = 10;
    const POINTS_PER_CORRECT = 100;
    const LEADERBOARD_KEY = 'gameLeaderboard_flagGuess';

    function buildChoices(target, allCountries) {
        const distractors = shuffle(allCountries.filter((c) => c.code !== target.code)).slice(0, 3);
        return shuffle([target, ...distractors]);
    }

    function FlagGuessGame({ onExit }) {
        const [level, setLevel] = useState(null);
        const [roundCountries, setRoundCountries] = useState([]);
        const [round, setRound] = useState(0);
        const [choices, setChoices] = useState([]);
        const [phase, setPhase] = useState('guessing'); // 'guessing' | 'revealed' | 'results'
        const [selectedCode, setSelectedCode] = useState(null);
        const [roundResults, setRoundResults] = useState([]);

        const target = roundCountries[round];

        const startGame = (lvl) => {
            const pool = poolForLevel(window.WORLD_COUNTRIES, lvl);
            const rounds = pickRounds(pool, TOTAL_ROUNDS);
            setRoundCountries(rounds);
            setChoices(buildChoices(rounds[0], window.WORLD_COUNTRIES));
            setRound(0);
            setRoundResults([]);
            setSelectedCode(null);
            setPhase('guessing');
            setLevel(lvl);
        };

        const choose = (code) => {
            if (phase !== 'guessing') return;
            setSelectedCode(code);
            setPhase('revealed');
            setRoundResults((prev) => [...prev, { code: target.code, correct: code === target.code }]);
        };

        const nextRound = () => {
            if (round + 1 >= roundCountries.length) {
                setPhase('results');
                return;
            }
            const nextIndex = round + 1;
            setRound(nextIndex);
            setChoices(buildChoices(roundCountries[nextIndex], window.WORLD_COUNTRIES));
            setSelectedCode(null);
            setPhase('guessing');
        };

        const playAgain = () => {
            const fresh = pickRounds(poolForLevel(window.WORLD_COUNTRIES, level), TOTAL_ROUNDS);
            setRoundCountries(fresh);
            setRound(0);
            setChoices(buildChoices(fresh[0], window.WORLD_COUNTRIES));
            setSelectedCode(null);
            setRoundResults([]);
            setPhase('guessing');
        };

        if (level == null) {
            return (
                <LevelSelect
                    title="ניחוש דגלים"
                    subtitle="בחרו רמת קושי"
                    gradient="from-pink-500 to-red-600"
                    onSelect={startGame}
                />
            );
        }

        const correctCount = roundResults.filter((r) => r.correct).length;
        const totalScore = correctCount * POINTS_PER_CORRECT;

        return (
            <div className="min-h-screen bg-gradient-to-br from-gray-900 via-slate-900 to-gray-900 text-white p-4 md:p-8 pb-24 md:pb-8">
                <div className="max-w-2xl mx-auto">
                    <button
                        onClick={onExit}
                        className="flex items-center gap-2 mb-4 text-gray-400 hover:text-white active:text-white transition-colors py-2"
                    >
                        <ArrowRight className="w-5 h-5 md:w-6 md:h-6" />
                        <span className="text-base md:text-lg">חזרה למשחקים</span>
                    </button>

                    <div className="flex items-center justify-between mb-6 bg-gray-800/60 rounded-2xl px-4 py-3">
                        <div className="flex items-center gap-2 text-gray-300">
                            <FlagIcon className="w-5 h-5 text-pink-400" />
                            <span>סיבוב {round + 1}/{roundCountries.length} · רמת {LEVEL_LABELS[level]}</span>
                        </div>
                        <div className="font-bold text-lg">{correctCount}/{roundCountries.length} נכונות</div>
                    </div>

                    <div className="text-center mb-6">
                        <p className="text-gray-400 mb-3">איזו מדינה זו?</p>
                        <div className="mx-auto w-56 h-40 flex items-center justify-center rounded-xl shadow-2xl border border-gray-700 bg-gray-800 text-8xl leading-none">
                            {flagEmoji(target.code)}
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                        {choices.map((c) => {
                            const isCorrect = c.code === target.code;
                            const isSelected = c.code === selectedCode;
                            let style = 'bg-gray-800 hover:bg-gray-700';
                            if (phase === 'revealed') {
                                if (isCorrect) style = 'bg-green-600';
                                else if (isSelected) style = 'bg-red-600';
                                else style = 'bg-gray-800 opacity-60';
                            }
                            return (
                                <button
                                    key={c.code}
                                    onClick={() => choose(c.code)}
                                    disabled={phase !== 'guessing'}
                                    className={`${style} px-4 py-4 rounded-2xl font-semibold transition-all active:scale-95 flex items-center justify-center gap-2`}
                                >
                                    {phase === 'revealed' && isCorrect && <Check className="w-5 h-5" />}
                                    {phase === 'revealed' && isSelected && !isCorrect && <X className="w-5 h-5" />}
                                    {c.nameHe}
                                </button>
                            );
                        })}
                    </div>

                    {phase === 'revealed' && (
                        <div className="mt-6 bg-gray-800/80 rounded-2xl p-4 md:p-6 text-center">
                            <h3 className="text-xl font-bold text-blue-300 mb-1">{target.nameHe}</h3>
                            <p className="text-gray-400 text-sm mb-2">בירה: {target.capitalHe}</p>
                            <p className="text-gray-300 mb-4">{target.blurb}</p>
                            <button
                                onClick={nextRound}
                                className="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 px-8 py-3 rounded-2xl font-semibold shadow-2xl transition-all active:scale-95"
                            >
                                {round + 1 >= roundCountries.length ? 'לתוצאות' : 'הבא'}
                            </button>
                        </div>
                    )}
                </div>

                {phase === 'results' && (
                    <div className="fixed inset-0 z-50 modal-backdrop bg-black/60 flex items-center justify-center p-4 overflow-y-auto">
                        <div className="bg-gray-800 rounded-3xl p-6 md:p-8 max-w-md w-full text-center shadow-2xl my-8">
                            <Trophy className="w-14 h-14 mx-auto mb-3 text-yellow-400" />
                            <h2 className="text-2xl font-bold mb-2">המשחק נגמר!</h2>
                            <p className="text-gray-400 mb-1">ענית נכון על</p>
                            <p className="text-4xl font-bold text-blue-400 mb-1">{correctCount}/{roundCountries.length}</p>
                            <p className="text-gray-400 mb-4">{totalScore.toLocaleString()} נקודות</p>
                            <div className="flex flex-col gap-3">
                                <button
                                    onClick={playAgain}
                                    className="flex items-center justify-center gap-2 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 px-6 py-3 rounded-2xl font-semibold transition-all active:scale-95"
                                >
                                    <RefreshIcon className="w-5 h-5" /> שחק שוב
                                </button>
                                <button
                                    onClick={onExit}
                                    className="px-6 py-3 rounded-2xl font-semibold bg-gray-700 hover:bg-gray-600 transition-all active:scale-95"
                                >
                                    חזרה למשחקים
                                </button>
                            </div>
                            <LeaderboardPanel storageKey={LEADERBOARD_KEY} points={totalScore} />
                        </div>
                    </div>
                )}
            </div>
        );
    }

    window.FlagGuessGame = FlagGuessGame;
})();

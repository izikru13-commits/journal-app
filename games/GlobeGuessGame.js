// Globe game: a country name is shown, the player clicks its location on a rotatable 3D globe.
// Known simplification: scored against the country's capital/centroid point, not its true polygon
// boundary (full boundary data would be too heavy to ship with no backend/bundler). A click that
// lands well inside a geographically large country but far from its capital may score imperfectly.
(function () {
    const { useState, useEffect, useRef } = React;
    const { GlobeIcon, RefreshIcon, Trophy } = window.GameIcons;
    const { haversineDistanceKm, scoreByDistance, pickRounds } = window.GameUtils;

    const TOTAL_ROUNDS = 10;
    const MAX_DISTANCE_KM = 4000;
    const HIGH_SCORE_KEY = 'gameHighScore_globeGuess';

    function GlobeGuessGame({ onExit }) {
        const [roundCountries, setRoundCountries] = useState(() => pickRounds(window.WORLD_COUNTRIES, TOTAL_ROUNDS));
        const [round, setRound] = useState(0);
        const [phase, setPhase] = useState('guessing'); // 'guessing' | 'revealed' | 'results'
        const [guess, setGuess] = useState(null);
        const [roundScores, setRoundScores] = useState([]);
        const [bestScore, setBestScore] = useState(null);

        const containerRef = useRef(null);
        const globeRef = useRef(null);
        const phaseRef = useRef(phase);
        const guessRef = useRef(null);

        const target = roundCountries[round];

        useEffect(() => {
            phaseRef.current = phase;
        }, [phase]);

        // Initialize the 3D globe once. globe.gl does not reliably read the container's own
        // rendered size on construction (it can default to the full window), so pass the
        // container's actual dimensions explicitly and keep them in sync on resize.
        useEffect(() => {
            const el = containerRef.current;
            const globe = Globe()(el)
                .width(el.clientWidth)
                .height(el.clientHeight)
                .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg')
                .backgroundColor('rgba(0,0,0,0)')
                .pointAltitude(0.015)
                .pointRadius(0.45)
                .pointColor('color')
                .pointOfView({ lat: 25, lng: 20, altitude: 2.3 }, 0);

            globe.onGlobeClick(({ lat, lng }) => {
                if (phaseRef.current !== 'guessing') return;
                guessRef.current = { lat, lng };
                setGuess({ lat, lng });
            });

            globeRef.current = globe;

            const handleResize = () => {
                if (!globeRef.current || !containerRef.current) return;
                globeRef.current.width(containerRef.current.clientWidth).height(containerRef.current.clientHeight);
            };
            window.addEventListener('resize', handleResize);

            return () => {
                window.removeEventListener('resize', handleResize);
                globeRef.current = null;
                if (containerRef.current) containerRef.current.innerHTML = '';
            };
        }, []);

        // Keep the globe's marker points in sync with guess / reveal state.
        useEffect(() => {
            const globe = globeRef.current;
            if (!globe) return;
            const points = [];
            if (guess) points.push({ lat: guess.lat, lng: guess.lng, color: '#facc15' });
            if (phase === 'revealed') points.push({ lat: target.lat, lng: target.lng, color: '#22c55e' });
            globe.pointsData(points);
            if (phase === 'revealed') {
                globe.pointOfView({ lat: target.lat, lng: target.lng, altitude: 1.6 }, 1000);
            }
        }, [guess, phase]);

        const resolveRound = () => {
            if (phaseRef.current !== 'guessing') return;
            phaseRef.current = 'revealed';
            const g = guessRef.current;
            const distanceKm = g ? haversineDistanceKm(g.lat, g.lng, target.lat, target.lng) : null;
            const points = scoreByDistance(distanceKm, MAX_DISTANCE_KM);
            setRoundScores((prev) => [...prev, { code: target.code, distanceKm, points }]);
            setPhase('revealed');
        };

        useEffect(() => {
            if (phase !== 'results') return;
            try {
                const totalScore = roundScores.reduce((s, r) => s + r.points, 0);
                const saved = JSON.parse(localStorage.getItem(HIGH_SCORE_KEY) || 'null');
                if (!saved || totalScore > saved.best) {
                    localStorage.setItem(HIGH_SCORE_KEY, JSON.stringify({
                        best: totalScore, lastPlayedAt: new Date().toISOString(), roundsPlayed: roundScores.length,
                    }));
                    setBestScore(totalScore);
                } else {
                    setBestScore(saved.best);
                }
            } catch (e) { /* localStorage unavailable, skip high score */ }
        }, [phase]);

        const nextRound = () => {
            if (round + 1 >= roundCountries.length) {
                setPhase('results');
                return;
            }
            guessRef.current = null;
            setGuess(null);
            setRound((r) => r + 1);
            phaseRef.current = 'guessing';
            setPhase('guessing');
        };

        const playAgain = () => {
            guessRef.current = null;
            setGuess(null);
            setRoundCountries(pickRounds(window.WORLD_COUNTRIES, TOTAL_ROUNDS));
            setRound(0);
            setRoundScores([]);
            setBestScore(null);
            phaseRef.current = 'guessing';
            setPhase('guessing');
            if (globeRef.current) globeRef.current.pointOfView({ lat: 25, lng: 20, altitude: 2.3 }, 800);
        };

        const totalScore = roundScores.reduce((s, r) => s + r.points, 0);
        const lastResult = roundScores[roundScores.length - 1];

        return (
            <div className="min-h-screen bg-gradient-to-br from-gray-900 via-slate-900 to-gray-900 text-white p-4 md:p-8 pb-24 md:pb-8">
                <div className="max-w-4xl mx-auto">
                    <button
                        onClick={onExit}
                        className="flex items-center gap-2 mb-4 text-gray-400 hover:text-white active:text-white transition-colors py-2"
                    >
                        <ArrowRight className="w-5 h-5 md:w-6 md:h-6" />
                        <span className="text-base md:text-lg">חזרה למשחקים</span>
                    </button>

                    <div className="flex items-center justify-between mb-4 bg-gray-800/60 rounded-2xl px-4 py-3">
                        <div className="flex items-center gap-2 text-gray-300">
                            <GlobeIcon className="w-5 h-5 text-cyan-400" />
                            <span>סיבוב {round + 1}/{roundCountries.length}</span>
                        </div>
                        <div className="font-bold text-lg">{totalScore.toLocaleString()} נק'</div>
                    </div>

                    {phase === 'guessing' && (
                        <div className="text-center mb-3">
                            <span className="text-gray-400 text-sm">איפה נמצאת</span>
                            <h2 className="text-2xl md:text-3xl font-bold text-cyan-300">{target.nameHe}</h2>
                            <p className="text-gray-500 text-sm mt-1">סובבו וזמו את הגלובוס, ולחצו על המיקום המשוער</p>
                        </div>
                    )}

                    <div
                        ref={containerRef}
                        className="w-full h-[50vh] md:h-[60vh] rounded-2xl overflow-hidden border border-gray-700 bg-black"
                    />

                    {phase === 'guessing' && guess && (
                        <div className="mt-4 flex justify-center">
                            <button
                                onClick={resolveRound}
                                className="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 px-8 py-3 rounded-2xl font-semibold shadow-2xl transition-all active:scale-95"
                            >
                                אשר ניחוש
                            </button>
                        </div>
                    )}

                    {phase === 'revealed' && lastResult && (
                        <div className="mt-4 bg-gray-800/80 rounded-2xl p-4 md:p-6 text-center">
                            <h3 className="text-lg font-bold text-cyan-300 mb-1">{target.nameHe}</h3>
                            <p className="text-gray-300">
                                {lastResult.distanceKm == null
                                    ? 'לא ניחשת'
                                    : `מרחק: ${Math.round(lastResult.distanceKm).toLocaleString()} ק"מ`}
                            </p>
                            <p className="text-xl font-bold text-green-400 mb-4">{lastResult.points} נקודות</p>
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
                    <div className="fixed inset-0 z-50 modal-backdrop bg-black/60 flex items-center justify-center p-4">
                        <div className="bg-gray-800 rounded-3xl p-6 md:p-8 max-w-md w-full text-center shadow-2xl">
                            <Trophy className="w-14 h-14 mx-auto mb-3 text-yellow-400" />
                            <h2 className="text-2xl font-bold mb-2">המשחק נגמר!</h2>
                            <p className="text-gray-400 mb-1">הניקוד שלך</p>
                            <p className="text-4xl font-bold text-cyan-400 mb-4">{totalScore.toLocaleString()}</p>
                            {bestScore != null && (
                                <p className="text-sm text-gray-400 mb-6">השיא שלך: {bestScore.toLocaleString()}</p>
                            )}
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
                        </div>
                    </div>
                )}
            </div>
        );
    }

    window.GlobeGuessGame = GlobeGuessGame;
})();

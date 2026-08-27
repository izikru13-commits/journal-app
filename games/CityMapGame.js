// City-guess game: an Israeli city name is shown, the player has 10 seconds to click its location on a map.
(function () {
    const { useState, useEffect, useRef } = React;
    const { MapPinIcon, ClockIcon, RefreshIcon, Trophy } = window.GameIcons;
    const { haversineDistanceKm, scoreByDistance, pickRounds } = window.GameUtils;

    const TOTAL_ROUNDS = 10;
    const ROUND_SECONDS = 10;
    const MAX_DISTANCE_KM = 100;
    const HIGH_SCORE_KEY = 'gameHighScore_mapGuess';

    function CityMapGame({ onExit }) {
        const [roundCities, setRoundCities] = useState(() => pickRounds(window.ISRAEL_CITIES, TOTAL_ROUNDS));
        const [round, setRound] = useState(0);
        const [phase, setPhase] = useState('guessing'); // 'guessing' | 'revealed' | 'results'
        const [timeLeft, setTimeLeft] = useState(ROUND_SECONDS);
        const [guessLatLng, setGuessLatLng] = useState(null);
        const [roundScores, setRoundScores] = useState([]);
        const [bestScore, setBestScore] = useState(null);

        const mapContainerRef = useRef(null);
        const mapRef = useRef(null);
        const guessMarkerRef = useRef(null);
        const trueMarkerRef = useRef(null);
        const lineRef = useRef(null);
        const phaseRef = useRef(phase);
        const guessRef = useRef(null);

        const target = roundCities[round];

        useEffect(() => {
            phaseRef.current = phase;
        }, [phase]);

        // Initialize the Leaflet map once, bounded to Israel.
        useEffect(() => {
            const map = L.map(mapContainerRef.current, {
                center: [31.5, 35.0],
                zoom: 7,
                minZoom: 6,
                maxZoom: 13,
                maxBounds: [[28.5, 33.0], [34.0, 36.5]],
                maxBoundsViscosity: 1.0,
            });
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; OpenStreetMap contributors',
                maxZoom: 19,
            }).addTo(map);
            map.on('click', (e) => {
                if (phaseRef.current !== 'guessing') return;
                guessRef.current = { lat: e.latlng.lat, lng: e.latlng.lng };
                setGuessLatLng(guessRef.current);
            });
            mapRef.current = map;
            return () => {
                map.remove();
                mapRef.current = null;
            };
        }, []);

        const clearRoundLayers = () => {
            const map = mapRef.current;
            if (!map) return;
            if (guessMarkerRef.current) { map.removeLayer(guessMarkerRef.current); guessMarkerRef.current = null; }
            if (trueMarkerRef.current) { map.removeLayer(trueMarkerRef.current); trueMarkerRef.current = null; }
            if (lineRef.current) { map.removeLayer(lineRef.current); lineRef.current = null; }
        };

        const resolveRound = () => {
            if (phaseRef.current !== 'guessing') return;
            phaseRef.current = 'revealed';
            const guess = guessRef.current;
            const distanceKm = guess ? haversineDistanceKm(guess.lat, guess.lng, target.lat, target.lng) : null;
            const points = scoreByDistance(distanceKm, MAX_DISTANCE_KM);
            setRoundScores((prev) => [...prev, { cityId: target.id, distanceKm, points }]);
            setPhase('revealed');
        };

        // Countdown timer while guessing.
        useEffect(() => {
            if (phase !== 'guessing') return;
            if (timeLeft <= 0) {
                resolveRound();
                return;
            }
            const t = setTimeout(() => setTimeLeft((s) => s - 1), 1000);
            return () => clearTimeout(t);
        }, [phase, timeLeft]);

        // Draw/move the guess marker as the player clicks. Uses a custom divIcon rather than
        // Leaflet's default marker (which needs external image assets) so the map works with
        // no image dependency beyond the tiles themselves.
        useEffect(() => {
            const map = mapRef.current;
            if (!map || !guessLatLng) return;
            if (guessMarkerRef.current) {
                guessMarkerRef.current.setLatLng([guessLatLng.lat, guessLatLng.lng]);
            } else {
                const guessIcon = L.divIcon({
                    className: '',
                    html: '<div style="background:#facc15;width:18px;height:18px;border-radius:50%;border:2px solid white;box-shadow:0 0 0 2px #ca8a04;"></div>',
                    iconSize: [18, 18],
                    iconAnchor: [9, 9],
                });
                guessMarkerRef.current = L.marker([guessLatLng.lat, guessLatLng.lng], { icon: guessIcon }).addTo(map);
            }
        }, [guessLatLng]);

        // Reveal the true location once the round resolves.
        useEffect(() => {
            const map = mapRef.current;
            if (!map || phase !== 'revealed' || !target) return;
            const trueIcon = L.divIcon({
                className: '',
                html: '<div style="background:#22c55e;width:16px;height:16px;border-radius:50%;border:2px solid white;box-shadow:0 0 0 2px #16a34a;"></div>',
                iconSize: [16, 16],
                iconAnchor: [8, 8],
            });
            trueMarkerRef.current = L.marker([target.lat, target.lng], { icon: trueIcon }).addTo(map);
            if (guessRef.current) {
                lineRef.current = L.polyline(
                    [[guessRef.current.lat, guessRef.current.lng], [target.lat, target.lng]],
                    { color: '#f43f5e', dashArray: '6 6', weight: 2 }
                ).addTo(map);
                const bounds = L.latLngBounds([[guessRef.current.lat, guessRef.current.lng], [target.lat, target.lng]]);
                map.fitBounds(bounds, { padding: [50, 50], maxZoom: 11 });
            } else {
                map.setView([target.lat, target.lng], 9);
            }
        }, [phase]);

        // Persist / read the high score once the session ends.
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
            if (round + 1 >= roundCities.length) {
                setPhase('results');
                return;
            }
            clearRoundLayers();
            guessRef.current = null;
            setGuessLatLng(null);
            setTimeLeft(ROUND_SECONDS);
            setRound((r) => r + 1);
            phaseRef.current = 'guessing';
            setPhase('guessing');
        };

        const playAgain = () => {
            clearRoundLayers();
            guessRef.current = null;
            setGuessLatLng(null);
            setRoundCities(pickRounds(window.ISRAEL_CITIES, TOTAL_ROUNDS));
            setRound(0);
            setRoundScores([]);
            setTimeLeft(ROUND_SECONDS);
            phaseRef.current = 'guessing';
            setPhase('guessing');
            setBestScore(null);
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
                            <MapPinIcon className="w-5 h-5 text-blue-400" />
                            <span>סיבוב {Math.min(round + 1, roundCities.length)}/{roundCities.length}</span>
                        </div>
                        <div className="font-bold text-lg">{totalScore.toLocaleString()} נק'</div>
                    </div>

                    {phase === 'guessing' && (
                        <div className="mb-4">
                            <div className="text-center mb-2">
                                <span className="text-gray-400 text-sm">איפה נמצאת</span>
                                <h2 className="text-2xl md:text-3xl font-bold text-blue-300">{target.name}</h2>
                            </div>
                            <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
                                <div
                                    className="h-full bg-gradient-to-r from-blue-500 to-red-500 transition-all duration-1000 ease-linear"
                                    style={{ width: `${(timeLeft / ROUND_SECONDS) * 100}%` }}
                                />
                            </div>
                            <div className="flex items-center justify-center gap-1 text-gray-400 text-sm mt-1">
                                <ClockIcon className="w-4 h-4" /> {timeLeft} שניות
                            </div>
                        </div>
                    )}

                    <div
                        ref={mapContainerRef}
                        className="w-full h-[50vh] md:h-[60vh] rounded-2xl overflow-hidden border border-gray-700"
                    />

                    {phase === 'guessing' && guessLatLng && (
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
                            <p className="text-gray-300">
                                {lastResult.distanceKm == null
                                    ? 'לא ניחשת בזמן'
                                    : `מרחק: ${lastResult.distanceKm.toFixed(1)} ק"מ`}
                            </p>
                            <p className="text-xl font-bold text-green-400 mb-4">{lastResult.points} נקודות</p>
                            <button
                                onClick={nextRound}
                                className="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 px-8 py-3 rounded-2xl font-semibold shadow-2xl transition-all active:scale-95"
                            >
                                {round + 1 >= roundCities.length ? 'לתוצאות' : 'הבא'}
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
                            <p className="text-4xl font-bold text-blue-400 mb-4">{totalScore.toLocaleString()}</p>
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

    window.CityMapGame = CityMapGame;
})();

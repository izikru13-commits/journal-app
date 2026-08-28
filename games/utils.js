// Shared helpers for the geography games. Plain script (no JSX), exposed as window.GameUtils.
// Defined as plain functions (not object methods) so callers can freely destructure
// individual helpers off GameUtils without losing a `this` binding between them.
window.GameUtils = (function () {
    function haversineDistanceKm(lat1, lng1, lat2, lng2) {
        const R = 6371;
        const toRad = (d) => (d * Math.PI) / 180;
        const dLat = toRad(lat2 - lat1);
        const dLng = toRad(lng2 - lng1);
        const a =
            Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    function scoreByDistance(distanceKm, maxDistanceKm, maxPoints = 1000) {
        if (distanceKm == null || !isFinite(distanceKm) || distanceKm >= maxDistanceKm) return 0;
        const ratio = 1 - distanceKm / maxDistanceKm;
        return Math.round(maxPoints * Math.pow(ratio, 1.3));
    }

    function shuffle(array) {
        const arr = [...array];
        for (let i = arr.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [arr[i], arr[j]] = [arr[j], arr[i]];
        }
        return arr;
    }

    function pickRounds(array, n = 10) {
        return shuffle(array).slice(0, Math.min(n, array.length));
    }

    // Renders a country's flag as a Unicode emoji from its ISO alpha-2 code (e.g. "il" -> 🇮🇱).
    // Avoids depending on an external flag-image service - works offline and on any device.
    function flagEmoji(code) {
        return code
            .toUpperCase()
            .replace(/./g, (c) => String.fromCodePoint(127397 + c.charCodeAt(0)));
    }

    // Difficulty levels are cumulative: level N includes every entry tagged <= N, so level 1
    // is a small pool of the most famous places and level 4 is the full, hardest set. `field` lets
    // the same item array be filtered by different difficulty ratings for different games (e.g. a
    // country can be an easy flag to recognize but a hard one to place on the map, or vice versa).
    function poolForLevel(array, level, field = 'difficulty') {
        return array.filter((item) => (item[field] || 1) <= level);
    }

    const LEVEL_LABELS = { 1: 'קל', 2: 'בינוני', 3: 'קשה', 4: 'מומחה' };

    // Per-game leaderboards (name + city + score), stored in localStorage, top 20 by score.
    function getLeaderboard(key) {
        try {
            const raw = JSON.parse(localStorage.getItem(key) || '[]');
            return Array.isArray(raw) ? raw : [];
        } catch (e) {
            return [];
        }
    }

    function addLeaderboardEntry(key, entry) {
        const list = getLeaderboard(key);
        list.push({ ...entry, date: new Date().toISOString() });
        list.sort((a, b) => b.points - a.points);
        const trimmed = list.slice(0, 20);
        try {
            localStorage.setItem(key, JSON.stringify(trimmed));
        } catch (e) { /* localStorage unavailable, skip persisting */ }
        return trimmed;
    }

    return {
        haversineDistanceKm, scoreByDistance, shuffle, pickRounds, flagEmoji,
        poolForLevel, LEVEL_LABELS, getLeaderboard, addLeaderboardEntry,
    };
})();

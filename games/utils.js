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

    return { haversineDistanceKm, scoreByDistance, shuffle, pickRounds, flagEmoji };
})();

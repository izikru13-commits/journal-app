// Extra inline SVG icons for the games, matching the hand-rolled icon style already used in index.html.
// Exposed as window.GameIcons so both the games files and index.html (loaded after this file) can use them.
(function () {
    const Trophy = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 4h6v6a3 3 0 01-6 0V4zM6 4H4a2 2 0 000 4h2m12-4h2a2 2 0 010 4h-2M9 15h6m-3 0v4m-4 0h8" />
        </svg>
    );

    const MapPinIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a2 2 0 01-2.828 0l-4.243-4.243a8 8 0 1111.314 0z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
    );

    const FlagIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 21V4m0 0h13l-2 4 2 4H3" />
        </svg>
    );

    const GlobeIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="9" strokeWidth={2} />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12h18M12 3c2.5 2.6 3.75 5.7 3.75 9S14.5 18.4 12 21c-2.5-2.6-3.75-5.7-3.75-9S9.5 5.6 12 3z" />
        </svg>
    );

    const ClockIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="9" strokeWidth={2} />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 7v5l3 3" />
        </svg>
    );

    const RefreshIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
    );

    const StarIcon = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.196-1.539-1.118l1.519-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.783-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
        </svg>
    );

    const Gamepad = ({ className }) => (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 12h4m-2-2v4m7-1h.01M17 13h.01M9 19l-1.106-2.211A2 2 0 006.09 15.6H4a2 2 0 01-1.94-2.507l1.313-5.001A3 3 0 016.257 6h11.486a3 3 0 012.884 2.092l1.313 5.001A2 2 0 0119.91 15.6h-2.09a2 2 0 00-1.804 1.19L15 19" />
        </svg>
    );

    window.GameIcons = { Trophy, MapPinIcon, FlagIcon, GlobeIcon, ClockIcon, RefreshIcon, StarIcon, Gamepad };
})();

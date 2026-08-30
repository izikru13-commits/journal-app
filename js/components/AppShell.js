// Zikkit (זיקית) — long-term app shell: branding + live level badge + content slot.
const BAND_BADGE_STYLES = {
  beginner: "bg-green-600",
  intermediate: "bg-blue-600",
  advanced: "bg-purple-600",
};

function AppShell({ profile, children }) {
  const band = profile.band;

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-slate-900 to-gray-900 text-white flex flex-col">
      <header className="pt-8 pb-6 px-4 text-center">
        <h1 className="text-4xl md:text-6xl font-bold mb-2 bg-gradient-to-r from-green-400 via-teal-400 to-blue-400 bg-clip-text text-transparent">
          זיקית 🦎
        </h1>
        <p className="text-gray-400 text-base md:text-lg mb-4">
          לומדים אנגלית כמו זיקית — משתנים ומתאימים בדיוק לרמה שלכם
        </p>
        <div className={`inline-flex items-center gap-2 ${BAND_BADGE_STYLES[band] || BAND_BADGE_STYLES.intermediate} px-4 py-1.5 rounded-full text-sm font-semibold shadow-lg`}>
          <span>הרמה שלך כרגע:</span>
          <span>{BAND_LABELS[band] || band}</span>
        </div>
      </header>

      <main className="flex-1 flex flex-col items-center px-4 pb-12">{children}</main>

      <footer className="text-center text-gray-600 text-xs pb-6">
        זיקית — עוד תכנים ומשחקים בדרך
      </footer>
    </div>
  );
}

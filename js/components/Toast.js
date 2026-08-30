// Zikkit (זיקית) — reusable transient notification (invalid guess, level up/down).
const TOAST_STYLES = {
  info: "bg-gray-700",
  error: "bg-red-600",
  levelup: "bg-purple-600",
  leveldown: "bg-blue-600",
};

function Toast({ message, show, type = "info", onClose, duration = 2000 }) {
  React.useEffect(() => {
    if (show) {
      const timer = setTimeout(onClose, duration);
      return () => clearTimeout(timer);
    }
  }, [show, onClose, duration]);

  if (!show) return null;

  return (
    <div className="fixed bottom-20 left-1/2 transform -translate-x-1/2 z-50 toast" dir="rtl">
      <div className={`${TOAST_STYLES[type] || TOAST_STYLES.info} text-white px-6 py-3 rounded-full shadow-2xl font-medium whitespace-nowrap`}>
        {message}
      </div>
    </div>
  );
}

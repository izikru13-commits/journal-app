import SwiftUI

enum CleanupFlow: Identifiable, Equatable {
    case session(MediaCategory)
    case review

    var id: String {
        switch self {
        case .session(let c): return "session-\(c.rawValue)"
        case .review: return "review"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore
    @EnvironmentObject private var library: PhotoLibraryService
    @Environment(\.openURL) private var openURL

    @State private var category: MediaCategory = .all
    @State private var flow: CleanupFlow?
    @State private var showSettings = false
    @State private var storage = StorageInfo.current()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if library.authStatus == .limited { limitedBanner }
                storageCard
                streakCard
                todayCard
                if store.hasPendingChanges { pendingCard }
                statsCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .foregroundStyle(.white)
        .background(Theme.background)
        .sheet(isPresented: $showSettings, onDismiss: refresh) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(library)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .fullScreenCover(item: $flow, onDismiss: refresh) { flow in
            CleanupFlowView(flow: flow, store: store, library: library) { self.flow = nil }
                .environmentObject(store)
                .environmentObject(library)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        store.rollDayIfNeeded()
        storage = StorageInfo.current()
        library.refreshCounts(reviewed: store.data.reviewedIDs, newestFirst: store.data.newestFirst)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ניקוי בהחלקה")
                    .font(.largeTitle.weight(.heavy))
                Text("כמה דקות ביום – גלריה נקייה")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .padding(10)
                    .background(Theme.card, in: Circle())
            }
        }
        .padding(.top, 12)
    }

    private var limitedBanner: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.flame)
                Text("יש לאפליקציה גישה רק לחלק מהתמונות. כדי לנקות את כל הגלריה, הקש כאן ובחר ״גישה מלאה״.")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var storageCard: some View {
        VStack(spacing: 12) {
            Text(Format.number(library.totalCount))
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .accessibilityIdentifier("home.total")
                .contentTransition(.numericText())
            Text("תמונות וסרטונים בגלריה")
                .font(.headline)
                .foregroundStyle(Theme.subtle)

            if let storage {
                let pct = Int((storage.usedFraction * 100).rounded())
                let color = storage.usedFraction > 0.9 ? Theme.delete : (storage.usedFraction > 0.75 ? Theme.flame : Theme.keep)
                ProgressView(value: storage.usedFraction)
                    .tint(color)
                    .scaleEffect(x: 1, y: 2.5)
                    .padding(.top, 6)
                Text(storage.usedFraction > 0.9 ? "\(pct)% · האחסון כמעט מלא" : "\(pct)% · אחסון בשימוש")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Text("\(Format.bytes(storage.available)) פנויים מתוך \(Format.bytes(storage.total))")
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
            }
        }
        .cardStyle()
    }

    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text(store.streak == 1 ? "רצף של יום אחד" : "רצף של \(store.streak) ימים")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.flame)
            }
            HStack(spacing: 10) {
                ForEach(store.lastSevenDays) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(day.done ? Theme.flame : Color.white.opacity(0.1))
                                .frame(width: 34, height: 34)
                            if day.done {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.heavy))
                            }
                        }
                        .overlay(Circle().stroke(day.isToday ? Color.white : .clear, lineWidth: 2))
                        Text(day.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.subtle)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
        .cardStyle()
    }

    private var todayCard: some View {
        let goal = max(1, store.data.dailyGoal)
        let today = store.data.todayReviewed
        let remaining = library.remaining[category] ?? 0
        let done = store.todayDone

        return VStack(spacing: 14) {
            HStack {
                Text("תוכנית ניקוי יומית")
                    .font(.title3.weight(.heavy))
                Spacer()
                Text("\(min(today, goal))/\(goal)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.subtle)
            }
            ProgressView(value: Double(min(today, goal)), total: Double(goal))
                .tint(Theme.flame)

            categoryPicker

            Button {
                flow = .session(category)
            } label: {
                Label(buttonTitle(today: today, done: done), systemImage: "hand.draw.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.indigo))
            .accessibilityIdentifier("home.start")
            .disabled(remaining == 0 && !library.isCounting)
            .opacity(remaining == 0 && !library.isCounting ? 0.5 : 1)

            Text(library.isCounting ? "סופר את הגלריה…" : "נותרו \(Format.number(remaining)) פריטים לסקירה")
                .font(.caption)
                .foregroundStyle(Theme.subtle)

            if category == .whatsapp && !library.hasWhatsAppAlbum && !library.isCounting {
                Text("לא נמצא אלבום וואטסאפ. באייפון, תמונות מוואטסאפ נשמרות לגלריה רק כשההגדרה ״שמירה לגלריה״ פועלת בוואטסאפ – והן מופיעות גם תחת ״הכל״.")
                    .font(.caption)
                    .foregroundStyle(Theme.flame)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }

    private func buttonTitle(today: Int, done: Bool) -> String {
        if done { return "סיימת להיום – להמשיך?" }
        if today > 0 { return "המשך מאיפה שעצרת" }
        return "התחל ניקוי יומי"
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MediaCategory.allCases) { c in
                    Button {
                        Haptics.impact(.light)
                        category = c
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: c.icon)
                            Text(c.title)
                            if let n = library.remaining[c], n > 0 {
                                Text(Format.number(n))
                                    .foregroundStyle(category == c ? .white.opacity(0.8) : Theme.subtle)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(category == c ? Theme.indigo : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pendingCard: some View {
        Button { flow = .review } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.delete)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.data.pendingDeletes.count) פריטים ממתינים למחיקה")
                        .font(.headline)
                    Text("יתפנו \(Format.bytes(store.pendingDeleteBytes)) · הקש לסקירה ואישור")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.subtle)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.pending")
    }

    private var statsCard: some View {
        HStack(spacing: 10) {
            statTile("התפנו", Format.bytes(store.data.totalFreedBytes), Theme.keep)
            statTile("נמחקו", Format.number(store.data.totalDeleted), Theme.delete)
            statTile("נסקרו", Format.number(store.data.totalReviewed), .white)
        }
    }

    private func statTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Swiping → summary → celebration, presented full screen.
struct CleanupFlowView: View {
    enum Phase: Equatable {
        case swiping
        case summary
        case celebration(Int64)
    }

    let flow: CleanupFlow
    let store: ProgressStore
    let library: PhotoLibraryService
    let onClose: () -> Void

    @State private var phase: Phase
    @State private var sessionReviewed: Int?

    init(flow: CleanupFlow, store: ProgressStore, library: PhotoLibraryService, onClose: @escaping () -> Void) {
        self.flow = flow
        self.store = store
        self.library = library
        self.onClose = onClose
        _phase = State(initialValue: flow == .review ? .summary : .swiping)
    }

    var body: some View {
        switch phase {
        case .swiping:
            if case .session(let category) = flow {
                SwipeSessionView(category: category, store: store, library: library) { reviewed in
                    sessionReviewed = reviewed
                    if store.hasPendingChanges {
                        phase = .summary
                    } else {
                        onClose()
                    }
                }
            }
        case .summary:
            ReviewDeletionView(sessionReviewed: sessionReviewed) { freed in
                if let freed, freed > 0 {
                    phase = .celebration(freed)
                } else {
                    onClose()
                }
            }
        case .celebration(let bytes):
            CelebrationView(freedBytes: bytes, onDone: onClose)
        }
    }
}

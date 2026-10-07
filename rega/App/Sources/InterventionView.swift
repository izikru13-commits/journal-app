import SwiftUI

/// The gate's second half: breathing → why → (replacement) → how long → open.
struct InterventionView: View {
    enum Step: Equatable {
        case blocked
        case expired
        case breathing
        case intention
        case replacement(ReplacementActivity)
        case duration
        case done(GateUnlock)
        case gaveUp
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let request: PendingRequest
    var demoStep: Step?

    @State private var step: Step = .breathing
    @State private var total = 8
    @State private var remaining = 8
    @State private var intention: Intention?
    @State private var started = false

    init(request: PendingRequest, demoStep: Step? = nil) {
        self.request = request
        self.demoStep = demoStep
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if showsClose {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityLabel("סגירה")
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 12)

                Group {
                    switch step {
                    case .blocked: blocked
                    case .expired: expired
                    case .breathing: breathing
                    case .intention: intentionStep
                    case let .replacement(activity): replacementStep(activity)
                    case .duration: durationStep
                    case let .done(unlock): doneStep(unlock)
                    case .gaveUp: gaveUp
                    }
                }
                .padding(.horizontal, 22)
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .task { await start() }
    }

    private var showsClose: Bool {
        switch step {
        case .breathing, .intention, .replacement, .duration: return false
        default: return true
        }
    }

    // MARK: - Flow

    private func start() async {
        guard !started else { return }
        started = true
        if let demoStep {
            total = 16
            remaining = 11
            step = demoStep
            return
        }
        guard request.isFresh(at: Date()) else {
            step = .expired
            return
        }
        if case .lock = model.presentation(for: request.target) {
            step = .blocked
            return
        }
        total = model.delaySeconds()
        remaining = total
        step = .breathing
        while remaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            remaining -= 1
        }
        step = .intention
    }

    private func choose(_ intention: Intention) {
        self.intention = intention
        if intention.suggestsReplacement, let activity = model.replacement(for: request) {
            step = .replacement(activity)
        } else {
            step = .duration
        }
    }

    private func giveUp(source: String) {
        model.dismiss(request, source: source, intention: intention)
        step = .gaveUp
    }

    // MARK: - Steps

    private var breathing: some View {
        VStack(spacing: 28) {
            Spacer()
            BreathingCircle(remaining: remaining, total: total)
                .frame(width: 240, height: 240)
            VStack(spacing: 8) {
                Text("נשימה אחת לפני שממשיכים")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(model.approvedTodayCount() > 0
                     ? "כל פתיחה מאושרת היום מאריכה את ההמתנה הבאה."
                     : "שאיפה כשהעיגול גדל, נשיפה כשהוא קטן.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("ויתרתי") { giveUp(source: "breathing") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
        }
    }

    private var intentionStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("למה לפתוח את זה עכשיו?")
                .font(.system(.title2, design: .rounded).weight(.semibold))
            TargetLabel(target: request.target)
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Intention.allCases) { option in
                    Button {
                        choose(option)
                    } label: {
                        Chip(title: option.title, symbol: option.symbol, selected: intention == option)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Button("בעצם, ויתרתי") { giveUp(source: "intention") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
        }
    }

    private func replacementStep(_ activity: ReplacementActivity) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Text(intention == .boredom ? "שעמום זה סימן טוב לזוז." : "הרגלים מחליפים בהרגלים.")
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
            Image(systemName: activity.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(activity.title)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
            Spacer()
            Button("אעשה את זה במקום") { giveUp(source: "replacement") }
                .buttonStyle(PrimaryButtonStyle())
            Button("לא עכשיו, אני עדיין רוצה לפתוח") { step = .duration }
                .buttonStyle(QuietButtonStyle())
                .padding(.bottom, 8)
        }
    }

    private var durationStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("לכמה זמן?")
                .font(.system(.title2, design: .rounded).weight(.semibold))
            Text("אחרי זה המגן חוזר לבד.")
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(UnlockMath.allowedMinutes, id: \.self) { minutes in
                    Button {
                        let unlock = model.approve(request, intention: intention, minutes: minutes)
                        step = .done(unlock)
                    } label: {
                        Chip(title: String(localized: "\(minutes) דק׳"), symbol: "timer")
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Button("ויתרתי") { giveUp(source: "duration") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
        }
    }

    private func doneStep(_ unlock: GateUnlock) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("פתוח עד \(DurationText.clock(unlock.until))")
                .font(.system(.title, design: .rounded).weight(.semibold))
            TargetLabel(target: unlock.target)
                .foregroundStyle(Theme.secondaryText)
            if model.openNowURL(for: unlock.target) == nil {
                Text("חזור לאפליקציה, היא פתוחה עכשיו.")
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            if let url = model.openNowURL(for: unlock.target) {
                Button("לפתוח עכשיו") {
                    openURL(url)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("הבנתי") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Text("כוונה: \(intention?.title ?? "–") · \(unlock.minutes) דק׳")
                .font(.footnote)
                .foregroundStyle(Theme.tertiaryText)
                .padding(.bottom, 12)
        }
    }

    private var gaveUp: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "leaf")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("יפה.")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
            Text("זה בדיוק הרגע שעושה את ההבדל. \(model.today.dismissed) ויתורים היום.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("סגירה") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
        }
    }

    private var blocked: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("זה נעול כרגע")
                .font(.system(.title, design: .rounded).weight(.semibold))
            Text("יש נעילה פעילה על האפליקציה הזאת, אז השער לא יעזור כאן.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("סגירה") {
                model.dismiss(request, source: "blocked")
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 12)
        }
    }

    private var expired: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.secondaryText)
            Text("הבקשה הזאת כבר ישנה")
                .font(.system(.title2, design: .rounded).weight(.semibold))
            Text("אם עדיין צריך, פתח שוב את האפליקציה והקש \"בכל זאת לפתוח\".")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("סגירה") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 12)
        }
    }
}

struct BreathingCircle: View {
    let remaining: Int
    let total: Int
    @State private var expanded = false

    init(remaining: Int, total: Int) {
        self.remaining = remaining
        self.total = total
    }

    /// 4 seconds in, 4 seconds out, following the countdown itself.
    private var inhaling: Bool { ((total - remaining) / 4) % 2 == 0 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.12))
                .scaleEffect(expanded ? 1 : 0.62)
            Circle()
                .fill(Theme.accent.opacity(0.22))
                .scaleEffect(expanded ? 0.8 : 0.5)
            Circle()
                .trim(from: 0, to: total > 0 ? CGFloat(total - remaining) / CGFloat(total) : 1)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            VStack(spacing: 2) {
                Text("\(remaining)")
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: remaining)
                Text(inhaling ? "שאיפה" : "נשיפה")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4)) { expanded = inhaling }
        }
        .onChange(of: inhaling) { _, value in
            withAnimation(.easeInOut(duration: 4)) { expanded = value }
        }
    }
}

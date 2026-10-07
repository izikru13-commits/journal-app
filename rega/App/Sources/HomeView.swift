import FamilyControls
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showManualLock = false
    @State private var showReplacement = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let pending = model.pendingFreshRequest() {
                    pendingCard(pending)
                }
                statusCard
                todayCard
                if !model.activeUnlocks.isEmpty {
                    unlocksCard
                }
                if model.settings.budgetEnabled {
                    budgetCard
                }
                actions
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showManualLock) {
            ManualLockSheet()
                .environmentObject(model)
                .regaEnvironment()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showReplacement) {
            ReplacementSuggestionSheet()
                .environmentObject(model)
                .regaEnvironment()
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("רגע.")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
            Text(greeting)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var greeting: String {
        let hour = Calendar.rega.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "בוקר טוב. הטלפון יחכה.")
        case 12..<17: return String(localized: "צהריים טובים. מה באמת חשוב עכשיו?")
        case 17..<22: return String(localized: "ערב טוב. עוד קצת ונגמר היום.")
        default: return String(localized: "לילה. המסך יכול לנוח, וגם אתה.")
        }
    }

    private func pendingCard(_ pending: PendingRequest) -> some View {
        Button {
            model.intervention = pending
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised")
                    .font(.title2)
                    .foregroundStyle(Theme.warm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ביקשת לפתוח משהו")
                        .font(.headline)
                    Text("הקש כדי להמשיך, או פשוט לוותר.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var statusCard: some View {
        let protection = model.protection
        if protection.isLocked {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: protection.isStrict ? "lock.fill" : "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lockTitle(protection))
                            .font(.headline)
                        if let until = protection.lockedUntil {
                            Text("עד \(DurationText.clock(until))")
                                .foregroundStyle(Theme.secondaryText)
                        } else if protection.budgetActive {
                            Text("עד חצות")
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                Button(protection.isStrict ? "סיום מוקדם עם המפתח" : "לסיים את הנעילה") {
                    model.showUnlock = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .card()
        } else if model.distractionCount == 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("עוד לא בחרת אפליקציות מסיחות")
                    .font(.headline)
                Text("בלי זה אין על מה לשים רגע. זה לוקח חצי דקה.")
                    .foregroundStyle(Theme.secondaryText)
                NavigationLink {
                    DistractionsView()
                } label: {
                    Text("לבחירת אפליקציות")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .card()
        } else {
            NavigationLink {
                DistractionsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: model.settings.gateEnabled ? "shield.lefthalf.filled" : "shield.slash")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.settings.gateEnabled ? "השער פעיל" : "השער כבוי")
                            .font(.headline)
                        Text("\(model.distractionCount) פריטים מסיחים מאחורי רגע")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private func lockTitle(_ protection: ActiveProtection) -> String {
        if let lock = protection.locks.first { return String(localized: "נעילת \(lock.rule.name) פעילה") }
        if protection.manual != nil { return String(localized: "נעילה ידנית פעילה") }
        return String(localized: "התקציב של היום נגמר")
    }

    private var todayCard: some View {
        let today = model.today
        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle("היום")
            HStack(spacing: 18) {
                DismissRing(rate: today.dismissRate)
                    .frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 10) {
                    statRow("ניסיונות לפתוח", today.attempts, symbol: "hand.tap")
                    statRow("ויתרתי", today.dismissed, symbol: "leaf", highlight: true)
                    statRow("פתיחות מאושרות", today.approved, symbol: "door.left.hand.open")
                }
            }
            HStack {
                Label("\(model.streak) ימים ברצף", systemImage: "flame")
                    .foregroundStyle(Theme.warm)
                Spacer()
                Text("יעד: עד \(model.settings.dailyApprovedGoal) פתיחות ביום")
                    .foregroundStyle(Theme.tertiaryText)
            }
            .font(.footnote)
        }
        .card()
    }

    private func statRow(_ title: LocalizedStringKey, _ value: Int, symbol: String, highlight: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(highlight ? Theme.accent : Theme.secondaryText)
            Text(title)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text("\(value)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(highlight ? Theme.accent : .white)
                .contentTransition(.numericText())
        }
    }

    private var unlocksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("פתוח כרגע")
            ForEach(model.activeUnlocks, id: \.target.key) { unlock in
                HStack {
                    TargetLabel(target: unlock.target)
                        .lineLimit(1)
                    Spacer()
                    Text("עד \(DurationText.clock(unlock.until))")
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                    Button {
                        model.relockNow(unlock)
                    } label: {
                        Image(systemName: "lock")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("לנעול עכשיו")
                }
            }
        }
        .card()
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("תקציב יומי: \(model.settings.budgetMinutes) דקות", systemImage: "hourglass")
                    .font(.headline)
                Spacer()
            }
            Text("תלוי באמינות של iOS: לפעמים ההתראות מאחרות או לא מגיעות.")
                .font(.footnote)
                .foregroundStyle(Theme.tertiaryText)
            if model.protection.budgetActive {
                Button("להפסיק את מגבלת התקציב להיום") {
                    model.showUnlock = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                showManualLock = true
            } label: {
                Label("נעילה עכשיו", systemImage: "lock.circle")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showReplacement = true
            } label: {
                Label("משהו לעשות במקום הטלפון", systemImage: "sparkles")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

/// The key metric: how often an attempt did not end in an opening.
struct DismissRing: View {
    let rate: Double?
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceHigh, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: rate ?? 0)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: rate)
            VStack(spacing: 0) {
                Text(DurationText.percent(rate))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("ויתורים")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct ReplacementSuggestionSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("במקום לגלול:")
                .font(.headline)
                .foregroundStyle(Theme.secondaryText)
            if model.replacements.isEmpty {
                Text("הרשימה ריקה. אפשר להוסיף פעילויות בהגדרות.")
                    .foregroundStyle(Theme.secondaryText)
            } else {
                let activity = model.replacements[index % model.replacements.count]
                VStack(spacing: 14) {
                    Image(systemName: activity.symbol)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Theme.accent)
                    Text(activity.title)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .id(activity.id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                Button("יאללה, עושה את זה") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("משהו אחר") {
                    withAnimation(.easeInOut) { index += 1 }
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .screenBackground()
        .onAppear { index = Int.random(in: 0..<max(model.replacements.count, 1)) }
    }
}

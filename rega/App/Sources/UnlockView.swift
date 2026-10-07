import SwiftUI

/// Ending locks early. Strict: the physical key (QR / NFC) or a weekly-limited emergency exit.
struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = false
    @State private var phrase = ""
    @State private var message: String?
    @State private var showEmergency = false
    @State private var nfcReader = NFCKeyReader()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let protection = model.protection
                    if !protection.isLocked {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.open")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(Theme.accent)
                            Text("אין נעילה פעילה כרגע.")
                                .font(.headline)
                        }
                        .padding(.top, 40)
                    } else {
                        summary(protection)
                        if protection.hasEndableLock {
                            if protection.isStrict {
                                strictOptions
                            } else {
                                Button("לסיים את הנעילה") {
                                    model.endSoftLocks()
                                    dismiss()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                Text("לפני שמסיימים: מה תעשה עם הזמן שהתפנה?")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        if protection.budgetActive {
                            Button("להפסיק את מגבלת התקציב להיום") {
                                model.endBudgetForToday()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    if let message {
                        Text(message)
                            .foregroundStyle(Theme.warm)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("סיום מוקדם")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $scanning) {
                ScanKeySheet { code in
                    scanning = false
                    if model.endLocks(withScannedCode: code) {
                        dismiss()
                    } else {
                        message = String(localized: "זה לא המפתח של רגע. אולי מפתח ישן?")
                    }
                }
                .regaEnvironment()
            }
        }
    }

    private func summary(_ protection: ActiveProtection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(protection.locks, id: \.rule.id) { active in
                Label("\(active.rule.name) · עד \(DurationText.clock(active.until))", systemImage: active.rule.isStrict ? "lock.fill" : "lock.open")
            }
            if let manual = protection.manual {
                Label("נעילה ידנית · עד \(DurationText.clock(manual.end))", systemImage: manual.isStrict ? "lock.fill" : "lock.open")
            }
            if protection.budgetActive {
                Label("התקציב היומי נגמר · עד חצות", systemImage: "hourglass")
            }
        }
        .card()
    }

    private var strictOptions: some View {
        VStack(spacing: 12) {
            Text("זו נעילה קשיחה. כדי לסיים אותה מוקדם, לך להביא את המפתח.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                message = nil
                scanning = true
            } label: {
                Label("סריקת קוד המפתח", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.keySecret == nil)

            if model.settings.nfcEnabled && model.nfcTagID != nil && NFCKeyReader.isAvailable {
                Button {
                    message = nil
                    nfcReader.scan(prompt: String(localized: "קרב את תג המפתח")) { result in
                        if case let .success(id) = result, model.endLocks(withNFCTag: id) {
                            dismiss()
                        } else {
                            message = String(localized: "זה לא התג של רגע.")
                        }
                    }
                } label: {
                    Label("סריקת תג NFC", systemImage: "wave.3.right")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            emergency
        }
    }

    private var emergency: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut) { showEmergency.toggle() }
            } label: {
                HStack {
                    Text("יציאת חירום")
                    Spacer()
                    Text("נשארו \(model.emergencyRemaining) מתוך \(EmergencyExits.weeklyLimit) השבוע")
                        .foregroundStyle(Theme.secondaryText)
                    Image(systemName: showEmergency ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .font(.callout)
            }
            .buttonStyle(.plain)

            if showEmergency {
                if model.emergencyRemaining == 0 {
                    Text("נגמרו יציאות החירום לשבוע הזה. הן מתחדשות ביום ראשון.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warm)
                } else {
                    Text("כדי לצאת, הקלד בדיוק:")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                    Text(EmergencyExits.phrase)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .textSelection(.disabled)
                    TextField("", text: $phrase, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 12))
                    Button("יציאת חירום", role: .destructive) {
                        if model.useEmergencyExit(phrase: phrase) {
                            dismiss()
                        } else {
                            message = String(localized: "המשפט לא תואם בדיוק.")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!EmergencyExits.matches(phrase))
                }
            }
        }
        .card()
        .padding(.top, 12)
    }
}

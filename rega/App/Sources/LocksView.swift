import FamilyControls
import SwiftUI

struct LocksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: LockRule?
    @State private var showManual = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.protection.hasEndableLock || model.protection.budgetActive {
                    activeCard
                }

                Button {
                    showManual = true
                } label: {
                    Label("נעילה עכשיו", systemImage: "lock.circle")
                }
                .buttonStyle(PrimaryButtonStyle())

                VStack(spacing: 10) {
                    SectionTitle("נעילות קבועות")
                    ForEach(model.locks) { rule in
                        LockRow(rule: rule) { editing = rule }
                    }
                    Button {
                        editing = LockRule(
                            id: UUID(), name: String(localized: "נעילה חדשה"), kind: .custom,
                            startMinute: 9 * 60, durationMinutes: 120, weekdays: Set(1...5),
                            isStrict: false, isEnabled: true, usesDistractions: true
                        )
                    } label: {
                        Label("נעילה חדשה", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                NavigationLink {
                    KeySetupView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "key.horizontal")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("המפתח הפיזי")
                                .font(.headline)
                            Text(model.keySecret == nil ? "עוד לא נוצר מפתח" : "קוד QR מודפס\(model.nfcTagID != nil && model.settings.nfcEnabled ? " + תג NFC" : "")")
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

                if !model.canWeaken {
                    StrictNotice()
                }
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("נעילות")
        .sheet(item: $editing) { rule in
            NavigationStack {
                LockEditorView(rule: rule, isNew: !model.locks.contains { $0.id == rule.id })
            }
            .environmentObject(model)
            .regaEnvironment()
        }
        .sheet(isPresented: $showManual) {
            ManualLockSheet()
                .environmentObject(model)
                .regaEnvironment()
                .presentationDetents([.medium, .large])
        }
    }

    private var activeCard: some View {
        let protection = model.protection
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle("פעיל עכשיו")
            ForEach(protection.locks, id: \.rule.id) { active in
                Label("\(active.rule.name) · עד \(DurationText.clock(active.until))", systemImage: active.rule.isStrict ? "lock.fill" : "lock.open")
            }
            if let manual = protection.manual {
                Label("נעילה ידנית · עד \(DurationText.clock(manual.end))", systemImage: manual.isStrict ? "lock.fill" : "lock.open")
            }
            if protection.budgetActive {
                Label("התקציב היומי נגמר · עד חצות", systemImage: "hourglass")
            }
            Button(protection.isStrict ? "סיום מוקדם עם המפתח" : "לסיים") {
                model.showUnlock = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }
}

struct LockRow: View {
    @EnvironmentObject private var model: AppModel
    let rule: LockRule
    let onEdit: () -> Void

    init(rule: LockRule, onEdit: @escaping () -> Void) {
        self.rule = rule
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(width: 30)
                        .foregroundStyle(rule.isEnabled ? Theme.accent : Theme.tertiaryText)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(rule.name).font(.headline)
                            if rule.isStrict {
                                Text("קשיחה")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.warm.opacity(0.2), in: Capsule())
                                    .foregroundStyle(Theme.warm)
                            }
                        }
                        Text("\(DurationText.clock(rule.startMinute))–\(DurationText.clock(rule.endMinute)) · \(DurationText.weekdays(rule.weekdays))")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { model.setLock(rule.id, enabled: $0) }
            ))
            .labelsHidden()
            .disabled(rule.isEnabled && !model.canWeaken)
        }
        .card(padding: 14)
    }

    private var symbol: String {
        switch rule.kind {
        case .sleep: return "moon.stars"
        case .morning: return "sunrise"
        case .custom: return "calendar.badge.clock"
        }
    }
}

struct LockEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var rule: LockRule
    let isNew: Bool
    @State private var endMinute: Int
    @State private var selection: FamilyActivitySelection
    @State private var showPicker = false
    @State private var confirmDelete = false

    init(rule: LockRule, isNew: Bool) {
        _rule = State(initialValue: rule)
        self.isNew = isNew
        _endMinute = State(initialValue: rule.endMinute)
        _selection = State(initialValue: SharedStore.shared.selection(for: rule))
    }

    private var locked: Bool { !isNew && !model.canWeaken }

    var body: some View {
        Form {
            if locked {
                Section { StrictNotice() }
            }
            Section {
                TextField("שם", text: $rule.name)
                DatePicker("התחלה", selection: $rule.startMinute.asClockDate, displayedComponents: .hourAndMinute)
                DatePicker("סיום", selection: $endMinute.asClockDate, displayedComponents: .hourAndMinute)
                if rule.kind == .morning {
                    Text("בוקר נקי מתחיל בשעת ההשכמה ונמשך כמה שבחרת.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            } footer: {
                Text("משך: \(DurationText.short(TimeInterval(LockRule.duration(from: rule.startMinute, to: endMinute) * 60))). מינימום 15 דקות.")
            }

            Section("ימים") {
                WeekdayPicker(selection: $rule.weekdays)
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle("נעילה קשיחה", isOn: $rule.isStrict)
            } footer: {
                Text("נעילה קשיחה מסתיימת מוקדם רק עם המפתח הפיזי או יציאת חירום (3 בשבוע).")
            }

            Section {
                Toggle("לנעול את כל האפליקציות המסיחות", isOn: $rule.usesDistractions)
                if !rule.usesDistractions {
                    Button("בחירת אפליקציות לנעילה הזאת (\(TokenSets(selection).count))") {
                        showPicker = true
                    }
                }
            }

            Section {
                Button("שמירה") {
                    rule.durationMinutes = LockRule.duration(from: rule.startMinute, to: endMinute)
                    model.saveLock(rule, selection: selection)
                    dismiss()
                }
                .disabled(rule.weekdays.isEmpty || rule.name.trimmingCharacters(in: .whitespaces).isEmpty)
                if !isNew {
                    Button("מחיקה", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .disabled(locked)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(isNew ? "נעילה חדשה" : rule.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("ביטול") { dismiss() }
                    .disabled(false)
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .confirmationDialog("למחוק את הנעילה?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("מחיקה", role: .destructive) {
                model.deleteLock(rule.id)
                dismiss()
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(DurationText.weekdayLetters[day - 1])
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? Theme.accent : Theme.surfaceHigh, in: Circle())
                        .foregroundStyle(on ? Theme.background : .white)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct ManualLockSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 60
    @State private var strict = true

    var body: some View {
        VStack(spacing: 18) {
            Text("נעילה עכשיו")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .padding(.top, 20)
            Text("כל האפליקציות המסיחות ננעלות מיד.")
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(ManualSession.allowedMinutes, id: \.self) { value in
                    Button {
                        minutes = value
                    } label: {
                        Text(value < 60 ? "\(value) ד׳" : (value % 60 == 0 ? "\(value / 60) ש׳" : "\(value / 60):\(String(format: "%02d", value % 60))"))
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(minutes == value ? Theme.accent.opacity(0.22) : Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(minutes == value ? Theme.accent : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            Toggle("נעילה קשיחה (רק המפתח מסיים מוקדם)", isOn: $strict)
                .padding(.horizontal, 4)
            if strict && model.keySecret == nil {
                Text("עוד אין לך מפתח פיזי. נשארות רק יציאות חירום.")
                    .font(.footnote)
                    .foregroundStyle(Theme.warm)
            }
            Spacer()
            Button("לנעול עד \(DurationText.clock(Date().addingTimeInterval(TimeInterval(minutes * 60))))") {
                model.startManualLock(minutes: minutes, strict: strict)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.distractionCount == 0 && !DemoMode.isActive)
        }
        .padding(20)
        .screenBackground()
        .onAppear { strict = model.keySecret != nil }
    }
}

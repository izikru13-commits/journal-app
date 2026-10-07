import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page: Int

    @State private var showPicker = false
    @State private var draft = FamilyActivitySelection()
    @State private var sleepStart = 23 * 60
    @State private var sleepEnd = 7 * 60
    @State private var wakeMinute = 7 * 60
    @State private var sleepStrict = true
    @State private var morningStrict = true

    private let pageCount = 6

    init(page: Int = 0) {
        _page = State(initialValue: page)
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 12)
                .padding(.horizontal, 24)
            Group {
                switch page {
                case 0: welcome
                case 1: permissions
                case 2: distractions
                case 3: locks
                case 4: key
                default: TipsView(showsDone: true) { finish() }
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            .id(page)
        }
        .screenBackground()
        .animation(.easeInOut(duration: 0.35), value: page)
        .familyActivityPicker(isPresented: $showPicker, selection: $draft)
        .onChange(of: showPicker) { _, isShowing in
            if !isShowing { model.updateDistractions(draft) }
        }
        .onAppear { draft = model.distractions }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Theme.accent : Theme.surfaceHigh)
                    .frame(height: 4)
            }
        }
    }

    private func next() { page += 1 }

    private func finish() {
        model.completeOnboarding(
            sleepStart: sleepStart, sleepEnd: sleepEnd, wakeMinute: wakeMinute,
            sleepStrict: sleepStrict, morningStrict: morningStrict
        )
    }

    private func pageLayout<Content: View>(
        symbol: String, title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 28)
                Text(title)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                content()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack {
            pageLayout(symbol: "wind", title: "רגע.") {
                Text("אפליקציה אחת עם תפקיד אחד: לעזור לך להחזיק את הטלפון פחות.")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
                VStack(alignment: .leading, spacing: 14) {
                    bullet("hourglass", "רגע לפני שאפליקציה מסיחה נפתחת: נשימה, שאלה קטנה, ואפשרות קלה לוותר.")
                    bullet("lock", "נעילות קבועות לשינה ולבוקר, שרק מפתח פיזי בחדר אחר מסיים מוקדם.")
                    bullet("chart.bar", "נתונים כנים, בלי להטיף.")
                    bullet("figure.walk", "משהו אחר לעשות במקום.")
                }
                Text("במחקר שפורסם ב-PNAS על אפליקציה דומה, השהיה קצרה עם אפשרות לוותר הורידה פתיחות של אפליקציות ב-57% תוך שישה שבועות. הוויתור היה המרכיב הכי חזק, אז כאן הוא תמיד הכפתור הגדול.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Button("בוא נתחיל") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(24)
        }
    }

    private var permissions: some View {
        VStack {
            pageLayout(symbol: "checkmark.shield", title: "שני אישורים") {
                permissionRow(
                    title: "Screen Time",
                    detail: "כדי לשים מגן על אפליקציות. רגע לא רואה מה אתה עושה בהן, ושום דבר לא יוצא מהטלפון.",
                    granted: model.isAuthorized
                ) {
                    Task { await model.requestScreenTime() }
                }
                permissionRow(
                    title: "התראות",
                    detail: "חובה לשער: מגן לא יכול לפתוח אפליקציה ישירות, אז כשתבחר ״בכל זאת לפתוח״ תגיע התראה, ומשם ממשיכים. גם סיכום ערב קטן.",
                    granted: model.notificationsAuthorized
                ) {
                    Task { await model.requestNotifications() }
                }
                if !model.isAuthorized {
                    Text("אם האישור נכשל: הגדרות ← זמן מסך ← להפעיל, ואז לנסות שוב.")
                        .font(.footnote)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            Button("המשך") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.isAuthorized)
                .padding(24)
        }
    }

    private var distractions: some View {
        VStack {
            pageLayout(symbol: "app.badge", title: "מה מושך אותך?") {
                Text("בחר את האפליקציות, הקטגוריות והאתרים שגונבים לך זמן. הם יעברו דרך השער של רגע.")
                    .foregroundStyle(Theme.secondaryText)
                Button {
                    draft = model.distractions
                    showPicker = true
                } label: {
                    Label(model.distractionCount == 0 ? "בחירת אפליקציות" : "נבחרו \(model.distractionCount) · עריכה", systemImage: "plus.app")
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("רעיונות: רשתות חברתיות, וידאו קצר, חדשות, משחקים. לא כדאי לבחור קטגוריה שרגע עצמו נמצא בה.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Button(model.distractionCount == 0 ? "אבחר אחר כך" : "המשך") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(24)
        }
    }

    private var locks: some View {
        VStack {
            pageLayout(symbol: "moon.stars", title: "שינה ובוקר נקי") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("שינה").font(.headline)
                    DatePicker("מ-", selection: $sleepStart.asClockDate, displayedComponents: .hourAndMinute)
                    DatePicker("עד", selection: $sleepEnd.asClockDate, displayedComponents: .hourAndMinute)
                    Toggle("קשיחה (רק המפתח מסיים מוקדם)", isOn: $sleepStrict)
                }
                .card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("בוקר נקי").font(.headline)
                    DatePicker("שעת השכמה", selection: $wakeMinute.asClockDate, displayedComponents: .hourAndMinute)
                    Text("30 הדקות הראשונות אחרי ההשכמה בלי אפליקציות מסיחות.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                    Toggle("קשיחה", isOn: $morningStrict)
                }
                .card()
                Text("אפשר לשנות ולהוסיף נעילות בכל זמן במסך הנעילות.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Button("המשך") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(24)
        }
    }

    private var key: some View {
        VStack {
            pageLayout(symbol: "key.horizontal", title: "המפתח הפיזי") {
                Text("נעילה קשיחה נגמרת מוקדם רק עם המפתח: קוד QR שתדפיס ותשים בחדר אחר. ההליכה עד אליו היא כל הקסם.")
                    .foregroundStyle(Theme.secondaryText)
                if let secret = model.keySecret, let qr = QRCode.image(for: KeyCodec.payload(for: secret)) {
                    HStack {
                        Spacer()
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        Spacer()
                    }
                    let card = ImageRenderer(content: KeyCardView(qr: qr))
                    if let image = card.uiImage {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("המפתח של רגע", image: Image(uiImage: image))) {
                            Label("הדפסה או שמירה", systemImage: "printer")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    Button("יצירת מפתח") { model.generateKey() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Text("אין מדפסת? שמור את התמונה ושלח אותה למישהו שיחזיק אותה בשבילך, או הצג אותה ממכשיר אחר. מדבקת NFC אפשר להוסיף אחר כך בהגדרות.")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Button(model.keySecret == nil ? "אעשה את זה אחר כך" : "שמרתי, המשך") { next() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(24)
        }
    }

    private func bullet(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 26)
                .foregroundStyle(Theme.accent)
            Text(text)
        }
    }

    private func permissionRow(title: LocalizedStringKey, detail: LocalizedStringKey, granted: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if granted {
                    Label("אושר", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
            if !granted {
                Button("לאשר", action: action)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }
}

struct TipsView: View {
    var showsDone: Bool
    var onDone: (() -> Void)?

    init(showsDone: Bool, onDone: (() -> Void)? = nil) {
        self.showsDone = showsDone
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("מה עוד עובד")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .padding(.top, 28)
                    Text("דברים שמחקרים ומשתמשים מצאו יעילים, מחוץ לאפליקציה.")
                        .foregroundStyle(Theme.secondaryText)

                    tip("circle.lefthalf.filled", "מסך בגווני אפור") {
                        Text("צבעים הם חלק מהפיתוי. באפור, הפיד פשוט פחות מעניין.")
                        step("1", "הגדרות ← נגישות ← תצוגה וגודל מלל ← מסנני צבע ← להפעיל ולבחור ״גווני אפור״.")
                        step("2", "קיצור מהיר: הגדרות ← נגישות ← קיצור נגישות ← לסמן ״מסנני צבע״. מעכשיו שלוש לחיצות על הכפתור הצדדי מדליקות ומכבות.")
                        step("3", "אוטומטי בלילה: אפליקציית קיצורים ← אוטומציה ← אוטומציה חדשה ← ״שעה ביום״ ← 21:00, כל יום ← ״הפעלה מיידית״ ← פעולה ״הגדר מסנני צבע״ ← פועל. ועוד אחת בבוקר שמכבה.")
                    }
                    tip("bolt.batteryblock", "לטעון מחוץ לחדר השינה") {
                        Text("הכי קל לא לגלול במיטה כשהטלפון בכלל לא שם. שעון מעורר פשוט עושה פלאים.")
                    }
                    tip("square.grid.3x3.square", "להוציא רשתות ממסך הבית") {
                        Text("לחיצה ארוכה על האפליקציה ← הסרת אפליקציה ← ״הסר ממסך הבית״. היא נשארת בספריית האפליקציות, רק בלי לקרוץ לך כל פעם.")
                        Text("ובונוס: לכבות התראות של רשתות חברתיות. רוב הפתיחות מתחילות מהתראה.")
                    }
                    tip("key.horizontal", "המפתח בחדר אחר") {
                        Text("ככל שהמפתח רחוק יותר, ככה הנעילה חזקה יותר. מגירה במטבח זה מקום מצוין.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            if showsDone {
                Button("יאללה, מתחילים") { onDone?() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(24)
            }
        }
        .screenBackground()
        .navigationTitle(showsDone ? "" : "טיפים")
    }

    private func tip<Content: View>(_ symbol: String, _ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.callout)
            .foregroundStyle(Color.white.opacity(0.85))
        }
        .card()
    }

    private func step(_ number: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Theme.surfaceHigh, in: Circle())
            Text(text)
        }
    }
}

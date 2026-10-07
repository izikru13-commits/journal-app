import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: ProgressStore
    @EnvironmentObject private var library: PhotoLibraryService
    @State private var page = 0
    @State private var requesting = false

    var body: some View {
        VStack {
            TabView(selection: $page) {
                OnboardingPage(icon: "checkmark.rectangle.stack.fill", iconColor: .white,
                               title: "ניקוי בהחלקה",
                               highlight: nil,
                               subtitle: "כמה דקות ביום – גלריה נקייה.\nימינה לשמור · שמאלה למחוק · למעלה למועדפים")
                    .tag(0)
                OnboardingPage(icon: "lock.fill", iconColor: Theme.keep,
                               title: "התמונות שלך",
                               highlight: ("לא יוצאות מהטלפון", Theme.keep),
                               subtitle: "בלי חשבון · בלי העלאה לענן")
                    .tag(1)
                OnboardingPage(icon: "checkmark.shield.fill", iconColor: Theme.indigo,
                               title: "שום דבר לא נמחק",
                               highlight: ("בלי אישור שלך", Theme.indigo),
                               subtitle: "נמחק בטעות? אפשר לשחזר עד 30 יום מ״נמחקו לאחרונה״")
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    Task { await grantAccess() }
                }
            } label: {
                if requesting {
                    ProgressView().tint(.white)
                } else {
                    Text(page < 2 ? "הבא" : "אפשר גישה לגלריה")
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.indigo))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .background(Theme.background)
    }

    private func grantAccess() async {
        requesting = true
        await library.requestAuthorization()
        if library.hasAccess {
            let granted = await NotificationManager.requestPermission()
            store.update {
                $0.onboarded = true
                if !granted { $0.reminderEnabled = false }
            }
        }
        requesting = false
    }
}

private struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let highlight: (String, Color)?
    let subtitle: String

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 84))
                .foregroundStyle(iconColor)
                .frame(width: 160, height: 160)
                .background(Theme.indigo.opacity(iconColor == Theme.indigo ? 0.15 : 0.9),
                            in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 40, weight: .heavy))
                if let highlight {
                    Text(highlight.0)
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(highlight.1)
                }
            }
            .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.subtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
    }
}

struct PermissionDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 70))
                .foregroundStyle(Theme.flame)
            Text("אין גישה לגלריה")
                .font(.largeTitle.weight(.heavy))
            Text("כדי לעבור על התמונות והסרטונים, צריך לאפשר גישה בהגדרות:\nהגדרות ← ניקוי בהחלקה ← תמונות ← גישה מלאה")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.subtle)
                .padding(.horizontal, 24)
            Spacer()
            Button("פתח הגדרות") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.indigo))
            .padding(24)
        }
        .foregroundStyle(.white)
        .background(Theme.background)
    }
}

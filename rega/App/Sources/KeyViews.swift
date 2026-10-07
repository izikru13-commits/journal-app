import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum QRCode {
    static func image(for text: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// The printable key card: QR code plus short instructions, rendered for sharing/printing.
struct KeyCardView: View {
    let qr: UIImage

    var body: some View {
        VStack(spacing: 18) {
            Text("המפתח של רגע")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 320, height: 320)
            Text("לשמור בחדר אחר. סריקה של הקוד מסיימת נעילה קשיחה מוקדם.")
                .font(.system(size: 16, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 320)
        }
        .padding(36)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct KeySetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmRegenerate = false
    @State private var testing = false
    @State private var testResult: String?
    @State private var nfcMessage: String?
    @State private var nfcReader = NFCKeyReader()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let secret = model.keySecret, let qr = QRCode.image(for: KeyCodec.payload(for: secret)) {
                    keyCard(qr)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("מפתח פיזי")
                            .font(.headline)
                        Text("רגע יוצר קוד QR אישי. מדפיסים אותו ושמים בחדר אחר. בנעילה קשיחה, רק סריקה שלו מסיימת את הנעילה מוקדם. ההליכה עד שם היא כל העניין.")
                            .foregroundStyle(Theme.secondaryText)
                        Button("יצירת מפתח") { model.generateKey() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .card()
                }

                nfcCard

                if !model.canWeaken {
                    StrictNotice()
                }
            }
            .padding(18)
        }
        .screenBackground()
        .navigationTitle("המפתח הפיזי")
        .sheet(isPresented: $testing) {
            ScanKeySheet { code in
                testResult = KeyCodec.matches(scanned: code, secret: model.keySecret)
                    ? String(localized: "המפתח עובד ✓")
                    : String(localized: "זה לא המפתח הנוכחי.")
                testing = false
            }
            .regaEnvironment()
        }
        .confirmationDialog("ליצור מפתח חדש?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("מפתח חדש (הישן יפסיק לעבוד)", role: .destructive) { model.generateKey() }
        } message: {
            Text("תצטרך להדפיס את החדש ולהחביא אותו שוב.")
        }
    }

    private func keyCard(_ qr: UIImage) -> some View {
        VStack(spacing: 14) {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            Text("הדפס, שמור בחדר אחר, ותן לו לעשות את העבודה.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            if let card = printable(qr) {
                ShareLink(
                    item: Image(uiImage: card),
                    preview: SharePreview("המפתח של רגע", image: Image(uiImage: card))
                ) {
                    Label("הדפסה או שמירה", systemImage: "printer")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Button {
                testResult = nil
                testing = true
            } label: {
                Label("בדיקת המפתח המודפס", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(SecondaryButtonStyle())
            if let testResult {
                Text(testResult)
                    .foregroundStyle(Theme.accent)
            }
            Button("יצירת מפתח חדש") { confirmRegenerate = true }
                .buttonStyle(QuietButtonStyle())
                .disabled(!model.canWeaken)
        }
        .card()
    }

    @MainActor private func printable(_ qr: UIImage) -> UIImage? {
        let renderer = ImageRenderer(content: KeyCardView(qr: qr))
        renderer.scale = 3
        return renderer.uiImage
    }

    private var nfcCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { model.settings.nfcEnabled },
                set: { value in model.updateSettings { $0.nfcEnabled = value } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("מפתח NFC (לא חובה)")
                        .font(.headline)
                    Text("מדבקת NFC או צ׳יפ שתצמיד לקיר בחדר אחר.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .disabled(model.settings.nfcEnabled && !model.canWeaken)

            if model.settings.nfcEnabled {
                if !NFCKeyReader.isAvailable {
                    Text("NFC לא זמין במכשיר הזה.")
                        .foregroundStyle(Theme.warm)
                } else {
                    Button(model.nfcTagID == nil ? "סריקת תג לצימוד" : "החלפת התג") {
                        nfcReader.scan(prompt: String(localized: "קרב את התג לחלק העליון של האייפון")) { result in
                            switch result {
                            case let .success(id):
                                model.pairNFC(tagID: id)
                                nfcMessage = String(localized: "התג צומד ✓")
                            case .failure:
                                nfcMessage = String(localized: "הסריקה לא הצליחה. נסה שוב.")
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.nfcTagID != nil && !model.canWeaken)
                    if model.nfcTagID != nil {
                        Button("הסרת התג", role: .destructive) { model.unpairNFC() }
                            .buttonStyle(QuietButtonStyle())
                            .disabled(!model.canWeaken)
                    }
                }
                if let nfcMessage {
                    Text(nfcMessage).foregroundStyle(Theme.accent)
                }
            }
        }
        .card()
    }
}

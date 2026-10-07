import Foundation

/// The physical key: a random secret printed as a QR code (and optionally an NFC tag's UID).
enum KeyCodec {
    static let prefix = "rega-key:v1:"

    static func newSecret() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<24).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func payload(for secret: String) -> String { prefix + secret }

    static func matches(scanned: String, secret: String?) -> Bool {
        guard let secret, !secret.isEmpty else { return false }
        return scanned.trimmingCharacters(in: .whitespacesAndNewlines) == payload(for: secret)
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

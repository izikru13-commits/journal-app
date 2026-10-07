import Photos
import SwiftUI

/// End-of-session summary: shows everything marked for deletion, lets the user rescue items,
/// then deletes in one batch (iOS asks for a final confirmation).
struct ReviewDeletionView: View {
    @EnvironmentObject private var store: ProgressStore
    @EnvironmentObject private var library: PhotoLibraryService

    let sessionReviewed: Int?
    /// Called with the bytes freed (0 if nothing was deleted), or nil if the user postponed.
    let onDone: (Int64?) -> Void

    @State private var assets: [PHAsset] = []
    @State private var working = false
    @State private var message: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    var body: some View {
        VStack(spacing: 16) {
            Text("סיכום")
                .font(.largeTitle.weight(.heavy))
                .padding(.top, 20)

            HStack(spacing: 10) {
                if let sessionReviewed { summaryTile("נסקרו", "\(sessionReviewed)", .white) }
                summaryTile("למחיקה", "\(store.data.pendingDeletes.count)", Theme.delete)
                summaryTile("יתפנו", Format.bytes(store.pendingDeleteBytes), Theme.keep)
                if !store.data.pendingFavorites.isEmpty {
                    summaryTile("למועדפים", "\(store.data.pendingFavorites.count)", Theme.favorite)
                }
            }

            if assets.isEmpty {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.keep)
                Text("אין פריטים שממתינים למחיקה")
                    .foregroundStyle(Theme.subtle)
                Spacer()
            } else {
                Text("הקש על תמונה כדי להציל אותה מהמחיקה")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            thumbnail(asset)
                        }
                    }
                }
            }

            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.delete)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await commit() }
                } label: {
                    if working {
                        ProgressView().tint(.white)
                    } else {
                        Text(primaryTitle)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: store.data.pendingDeletes.isEmpty ? Theme.indigo : Theme.delete))
                .accessibilityIdentifier("summary.commit")
                .disabled(working)

                if store.hasPendingChanges {
                    Button("לא עכשיו – אמחק אחר כך") { onDone(nil) }
                        .accessibilityIdentifier("summary.later")
                        .foregroundStyle(Theme.subtle)
                        .disabled(working)
                }

                if !store.data.pendingDeletes.isEmpty {
                    Text("הפריטים יעברו ל״נמחקו לאחרונה״ באפליקציית תמונות – אפשר לשחזר עד 30 יום.")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
        .background(Theme.background)
        .onAppear(perform: load)
    }

    private var primaryTitle: String {
        let deletes = store.data.pendingDeletes.count
        let favs = store.data.pendingFavorites.count
        if deletes > 0 { return "מחק \(deletes) פריטים · \(Format.bytes(store.pendingDeleteBytes))" }
        if favs > 0 { return "שמור \(favs) במועדפים" }
        return "סיום"
    }

    private func summaryTile(_ title: String, _ value: String, _ color: Color) -> some View {
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
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func thumbnail(_ asset: PHAsset) -> some View {
        Button {
            Haptics.impact(.light)
            store.rescue(asset.localIdentifier)
            withAnimation { assets.removeAll { $0.localIdentifier == asset.localIdentifier } }
        } label: {
            AssetImage(asset: asset, pixelSize: CGSize(width: 300, height: 300))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Theme.delete)
                        .padding(5)
                }
                .overlay(alignment: .bottomTrailing) {
                    if asset.mediaType == .video {
                        Image(systemName: "video.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("summary.thumb")
    }

    private func load() {
        let ids = store.data.pendingDeletes + store.data.pendingFavorites
        let existing = PhotoLibraryService.existingIDs(ids)
        store.dropMissingPending(existing: existing)
        assets = PhotoLibraryService.assets(for: store.data.pendingDeletes)
    }

    private func commit() async {
        working = true
        message = nil
        defer { working = false }

        let favs = store.data.pendingFavorites
        if !favs.isEmpty {
            if await library.markFavorites(ids: favs) {
                store.favoritesCommitted(favs)
            } else {
                message = "לא ניתן היה לסמן מועדפים. ננסה שוב בפעם הבאה."
            }
        }

        let deletes = store.data.pendingDeletes
        guard !deletes.isEmpty else {
            if message == nil { onDone(0) }
            return
        }
        let bytes = store.pendingDeleteBytes
        if await library.delete(ids: deletes) {
            store.deletionsCommitted(deletes, bytes: bytes)
            Haptics.success()
            onDone(bytes)
        } else {
            message = "המחיקה בוטלה. הפריטים נשארו ברשימה."
        }
    }
}

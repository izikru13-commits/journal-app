import AVKit
import Photos
import SwiftUI

/// Loads a PHAsset image (fast low-res first, then sharp). Works with iCloud-optimized photos too.
struct AssetImage: View {
    let asset: PHAsset
    /// Requested size in pixels.
    var pixelSize = CGSize(width: 1200, height: 1600)
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        // Color fills the proposed space; the image overflows inside the overlay and is clipped,
        // so aspect-fill never grows the layout.
        Color(white: 0.14)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .clipped()
            .task(id: asset.localIdentifier) { load() }
    }

    private func load() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: contentMode == .fill ? .aspectFill : .aspectFit,
            options: options
        ) { result, _ in
            guard let result else { return }
            Task { @MainActor in image = result }
        }
    }
}

/// Full-screen preview: zoomable-sized photo or a playable video.
struct AssetPreview: View {
    let item: ReviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if item.isVideo {
                VideoPreview(asset: item.asset)
            } else {
                AssetImage(asset: item.asset, pixelSize: CGSize(width: 2400, height: 2400), contentMode: .fit)
                    .ignoresSafeArea()
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
}

struct VideoPreview: View {
    let asset: PHAsset
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                guard let playerItem else { return }
                Task { @MainActor in
                    let p = AVPlayer(playerItem: playerItem)
                    player = p
                    p.play()
                }
            }
        }
        .onDisappear { player?.pause() }
    }
}

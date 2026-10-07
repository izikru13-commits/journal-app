import SwiftUI

struct SwipeSessionView: View {
    @StateObject private var vm: SessionViewModel
    @EnvironmentObject private var store: ProgressStore
    let onFinish: (_ reviewedThisSession: Int) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isFlying = false
    @State private var previewItem: ReviewItem?

    private let horizontalThreshold: CGFloat = 110
    private let verticalThreshold: CGFloat = 120

    init(category: MediaCategory, store: ProgressStore, library: PhotoLibraryService,
         onFinish: @escaping (Int) -> Void) {
        _vm = StateObject(wrappedValue: SessionViewModel(category: category, store: store, library: library))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            statsRow
            dailyProgress
            cardArea
                .environment(\.layoutDirection, .leftToRight)
            controls
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .background(Theme.background)
        .onAppear { vm.start() }
        .sheet(item: $previewItem) { item in
            AssetPreview(item: item)
        }
        .overlay {
            if vm.goalJustReached { goalReachedOverlay }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { onFinish(vm.sessionReviewed) } label: {
                Image(systemName: "arrow.right")
                    .font(.title3.weight(.bold))
            }
            Text(vm.category.title)
                .font(.title2.weight(.heavy))
            Spacer()
            Button("סיום") { onFinish(vm.sessionReviewed) }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Theme.card, in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack {
            stat("נסקרו", "\(vm.sessionReviewed)", .white)
            Spacer()
            stat("למחיקה", "\(store.data.pendingDeletes.count)", Theme.delete)
            Spacer()
            stat("יתפנו", Format.bytes(store.pendingDeleteBytes), .white)
        }
        .font(.subheadline.weight(.bold))
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
        }
        .foregroundStyle(color)
    }

    private var dailyProgress: some View {
        let goal = max(1, store.data.dailyGoal)
        let done = min(store.data.todayReviewed, goal)
        return VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: Double(done), total: Double(goal))
                .tint(Theme.flame)
            Text("היום: \(store.data.todayReviewed) מתוך \(goal)")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
    }

    // MARK: - Cards

    private var cardArea: some View {
        ZStack {
            if vm.isLoading {
                ProgressView("טוען את הגלריה…")
                    .tint(.white)
                    .foregroundStyle(.white)
            } else if vm.exhausted || vm.queue.isEmpty {
                emptyState
            } else {
                let visible = Array(Array(vm.queue.prefix(3).enumerated()).reversed())
                ForEach(visible, id: \.element.id) { index, item in
                    SwipeCard(item: item, offset: index == 0 ? dragOffset : .zero)
                        .scaleEffect(index == 0 ? 1 : 1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 12)
                        .offset(index == 0 ? dragOffset : .zero)
                        .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 18) : 0), anchor: .bottom)
                        .allowsHitTesting(index == 0)
                        .onTapGesture { previewItem = item }
                        .gesture(dragGesture)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isFlying else { return }
                let w = value.translation.width
                let h = value.translation.height
                let pw = value.predictedEndTranslation.width
                if h < -verticalThreshold && abs(h) > abs(w) {
                    fly(.favorite)
                } else if w > horizontalThreshold || pw > 400 {
                    fly(.keep)
                } else if w < -horizontalThreshold || pw < -400 {
                    fly(.delete)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragOffset = .zero }
                }
            }
    }

    private func fly(_ decision: Decision) {
        guard !isFlying, !vm.queue.isEmpty else { return }
        isFlying = true
        Haptics.impact(decision == .delete ? .heavy : .medium)
        let target: CGSize
        switch decision {
        case .keep: target = CGSize(width: 700, height: dragOffset.height + 60)
        case .delete: target = CGSize(width: -700, height: dragOffset.height + 60)
        case .favorite: target = CGSize(width: dragOffset.width, height: -1000)
        }
        withAnimation(.easeIn(duration: 0.22)) { dragOffset = target }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                vm.decide(decision)
                dragOffset = .zero
            }
            isFlying = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 54))
                .foregroundStyle(Theme.flame)
            Text("עברת על הכל!")
                .font(.title.weight(.heavy))
            Text("אין עוד פריטים לסקירה בקטגוריה הזו.")
                .foregroundStyle(Theme.subtle)
            Button("לסיכום") { onFinish(vm.sessionReviewed) }
                .buttonStyle(PrimaryButtonStyle(color: Theme.indigo))
                .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Controls (physical order left→right: undo, delete, favorite, keep)

    private var controls: some View {
        HStack(spacing: 18) {
            CircleButton(icon: "arrow.uturn.backward", color: Color(white: 0.85), iconColor: Color(white: 0.35), size: 52) {
                Haptics.impact(.light)
                vm.undo()
            }
            .disabled(!vm.canUndo || isFlying)
            .opacity(vm.canUndo ? 1 : 0.4)

            CircleButton(icon: "xmark", color: Theme.delete, size: 72) { fly(.delete) }
            CircleButton(icon: "star.fill", color: Theme.favorite, size: 62) { fly(.favorite) }
            CircleButton(icon: "checkmark", color: Theme.keep, size: 72) { fly(.keep) }
        }
        .disabled(vm.queue.isEmpty)
        .padding(.vertical, 6)
    }

    // MARK: - Goal reached

    private var goalReachedOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("סיימת את היעד היומי!")
                    .font(.title2.weight(.heavy))
                Text("רצף של \(store.streak) ימים")
                    .font(.headline)
                    .foregroundStyle(Theme.flame)
                Button("לסיכום ומחיקה") {
                    vm.goalJustReached = false
                    onFinish(vm.sessionReviewed)
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.indigo))
                Button("להמשיך עוד קצת") { vm.goalJustReached = false }
                    .foregroundStyle(Theme.subtle)
            }
            .foregroundStyle(.white)
            .padding(28)
            .background(Theme.bgTop, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(30)
        }
        .onAppear { Haptics.success() }
    }
}

// MARK: - Card

struct SwipeCard: View {
    let item: ReviewItem
    let offset: CGSize

    private var keepAmount: Double { horizontalDominant ? max(0, min(1, Double(offset.width) / 100)) : 0 }
    private var deleteAmount: Double { horizontalDominant ? max(0, min(1, Double(-offset.width) / 100)) : 0 }
    private var favoriteAmount: Double { horizontalDominant ? 0 : max(0, min(1, Double(-offset.height) / 110)) }
    private var horizontalDominant: Bool { abs(offset.width) >= abs(offset.height) }

    var body: some View {
        ZStack(alignment: .bottom) {
            AssetImage(asset: item.asset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)

            HStack(spacing: 6) {
                Text([Format.date(item.asset.creationDate), Format.bytes(item.size), item.source]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                Spacer()
                if item.isVideo {
                    Text(Format.duration(item.asset.duration))
                    Image(systemName: "play.fill")
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(16)

            stamps
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .contentShape(Rectangle())
    }

    private var stamps: some View {
        ZStack {
            Stamp(text: "לשמור", color: Theme.keep)
                .rotationEffect(.degrees(-14))
                .opacity(keepAmount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
            Stamp(text: "למחיקה", color: Theme.delete)
                .rotationEffect(.degrees(14))
                .opacity(deleteAmount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(28)
            Stamp(text: "למועדפים", color: Theme.favorite)
                .opacity(favoriteAmount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .allowsHitTesting(false)
    }
}

struct Stamp: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 3))
            .shadow(radius: 6)
    }
}

struct CircleButton: View {
    let icon: String
    let color: Color
    var iconColor: Color = .white
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.indigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

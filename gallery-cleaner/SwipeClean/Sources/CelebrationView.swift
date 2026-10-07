import SwiftUI

struct CelebrationView: View {
    @EnvironmentObject private var store: ProgressStore
    let freedBytes: Int64
    let onDone: () -> Void

    @State private var storage = StorageInfo.current()
    @State private var appeared = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.18, green: 0.70, blue: 0.52), Color(red: 0.05, green: 0.42, blue: 0.33)],
                           center: .center, startRadius: 20, endRadius: 600)
                .ignoresSafeArea()

            ConfettiView()

            VStack(spacing: 18) {
                Spacer()
                Text("התפנו")
                    .font(.system(size: 38, weight: .heavy))
                Text(Format.bytes(freedBytes))
                    .font(.system(size: 86, weight: .heavy, design: .rounded))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                if let storage {
                    VStack(spacing: 8) {
                        ProgressView(value: storage.usedFraction)
                            .tint(.white)
                            .scaleEffect(x: 1, y: 3)
                        Text("\(Int((storage.usedFraction * 100).rounded()))% · אחסון בשימוש")
                            .font(.headline)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                }

                Text("בכמה דקות בלבד")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.6))
                    .padding(.top, 20)

                if store.streak > 0 {
                    Label("רצף של \(store.streak) ימים", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.flame)
                }

                Text("כדי לפנות את המקום מיד: אפליקציית תמונות ← אלבומים ← נמחקו לאחרונה ← מחק הכל")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 30)
                    .padding(.top, 10)

                Spacer()
                Button("סיום", action: onDone)
                    .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.22)))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let startY: Double
        let speed: Double
        let wobble: Double
        let phase: Double
        let spin: Double
        let color: Color
        let width: Double
    }

    @State private var start = Date()
    @State private var pieces: [Piece] = (0..<90).map { _ in
        Piece(x: .random(in: 0...1),
              startY: .random(in: -900 ... -20),
              speed: .random(in: 110...240),
              wobble: .random(in: 1...3),
              phase: .random(in: 0...(Double.pi * 2)),
              spin: .random(in: -4...4),
              color: [Color(red: 0.5, green: 0.85, blue: 1.0), Color(red: 1.0, green: 0.55, blue: 0.65),
                      Color(red: 1.0, green: 0.85, blue: 0.3), .white].randomElement()!,
              width: .random(in: 6...10))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let travel = size.height + 60
                    let raw = p.startY + p.speed * t
                    let y = raw < -20 ? raw : (raw + 20).truncatingRemainder(dividingBy: travel) - 20
                    let x = p.x * size.width + sin(t * p.wobble + p.phase) * 18
                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * p.spin))
                    let rect = CGRect(x: -p.width / 2, y: -p.width * 0.8, width: p.width, height: p.width * 1.6)
                    c.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

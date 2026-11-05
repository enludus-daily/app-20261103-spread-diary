import SwiftUI

/// 赤シート：緑のマーカーを引いた答えの上に重ねる（multiply で重ねるので、マーカーの所の字が消える）。
/// 下へずらすと答えが見える。半分を超えて離すと抜け、手前なら戻る。タップでも開く（読み上げの操作のため）。
struct RedSheet<Content: View>: View {
    @Binding var revealed: Bool
    /// 最初からずらしておく割合（スクリーンショット用）
    var initialPull: CGFloat = 0
    var onReveal: () -> Void = {}
    @ViewBuilder let content: Content

    @State private var pull: CGFloat = 0
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let height = proxy.size.height
                    sheet
                        .frame(width: proxy.size.width, height: height + 24)
                        .offset(y: revealed ? height + 40 : pull * height)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    guard !revealed else { return }
                                    pull = min(max(value.translation.height / max(height, 1), 0), 1)
                                }
                                .onEnded { _ in
                                    if pull > 0.45 { open() } else { withAnimation(spring) { pull = 0 } }
                                }
                        )
                        .onTapGesture { open() }
                }
                .clipped()
            }
            .compositingGroup()
            .accessibilityElement(children: revealed ? .contain : .ignore)
            .accessibilityLabel(Text(verbatim: revealed ? "" : "赤シートで隠れた答え"))
            .accessibilityHint(Text(verbatim: revealed ? "" : "ダブルタップで赤シートをずらして答えを見ます"))
            .accessibilityAddTraits(revealed ? [] : .isButton)
            .accessibilityAction { if !revealed { open() } }
            .onAppear {
                if !started { pull = initialPull; started = true }
            }
    }

    private var spring: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    private var sheet: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Ink.redSheet.opacity(0.95))
                .blendMode(.multiply)
            // 透明なシートの光の筋
            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(width: 10)
                .rotationEffect(.degrees(24))
                .offset(x: 40)
                .blendMode(.screen)
            Label("下へずらして答えを見る", systemImage: "chevron.compact.down")
                .font(Typo.label(.caption))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 30)
        }
    }

    private func open() {
        guard !revealed else { return }
        withAnimation(spring) { revealed = true }
        onReveal()
    }
}

/// 緑のマーカーを引いた文字（答え）
struct MarkedText: View {
    let text: String
    var font: Font = Typo.english(.title2)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Ink.text)
            .lineSpacing(6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 3).fill(Ink.marker.opacity(0.75))
                    .padding(.vertical, -2)
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 赤ペンの判子（「済」など）：二重の丸、少しかすれ（固定の乱数で毎回同じ）
struct Hanko: View {
    let text: String
    var size: CGFloat = 84
    var color: Color = Ink.redPen

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: size * 0.06)
            Circle().strokeBorder(color, lineWidth: size * 0.02).padding(size * 0.1)
            Text(text)
                .font(.system(size: size * 0.42, weight: .heavy, design: .serif))
                .foregroundStyle(color)
            Canvas { context, canvas in
                var rng = SeededRandom(seed: 7)
                for _ in 0..<40 {
                    let x = CGFloat(rng.next() % 1000) / 1000 * canvas.width
                    let y = CGFloat(rng.next() % 1000) / 1000 * canvas.height
                    let r = CGFloat(rng.next() % 30) / 10 + 0.6
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(Ink.card))
                }
            }
        }
        .frame(width: size, height: size)
        .opacity(0.9)
        .accessibilityHidden(true)
    }
}

/// 赤ペンの丸（正解）と × （間違い）。線を引く動き（300ms）
struct PenMark: View {
    enum Kind { case circle, cross }
    let kind: Kind
    var size: CGFloat = 120
    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch kind {
            case .circle:
                Circle()
                    .trim(from: 0, to: drawn)
                    .stroke(Ink.redPen, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                    .rotationEffect(.degrees(-100))
            case .cross:
                CrossShape()
                    .trim(from: 0, to: drawn)
                    .stroke(Ink.redPen, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion { drawn = 1 } else { withAnimation(.easeOut(duration: 0.3)) { drawn = 1 } }
        }
        .accessibilityHidden(true)
    }
}

private struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        return p
    }
}

/// 失敗の横揺れ：0,-9,8,-6,5,-3,2,0 px の減衰（420ms）。動きを減らす設定では揺らさない
struct ShakeOnChange: ViewModifier {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(CGFloat(-9), duration: 0.06)
                    LinearKeyframe(CGFloat(8), duration: 0.06)
                    LinearKeyframe(CGFloat(-6), duration: 0.06)
                    LinearKeyframe(CGFloat(5), duration: 0.06)
                    LinearKeyframe(CGFloat(-3), duration: 0.06)
                    LinearKeyframe(CGFloat(2), duration: 0.06)
                    LinearKeyframe(CGFloat(0), duration: 0.06)
                }
            }
        }
    }
}

/// 紙吹雪：付箋の切れはし 60 片を左右下から打ち上げる。2200ms、35% で頂点、回転 360〜1260°、色 5 つ。
/// 乱数は固定（毎回同じ散り方）。動きを減らす設定では出さない。
struct StickyConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    private static let duration: Double = 2.2

    private struct Piece {
        let fromLeft: Bool
        let vx: CGFloat
        let peak: CGFloat
        let spin: Double
        let size: CGFloat
        let color: Color
    }

    private static let pieces: [Piece] = {
        var rng = SeededRandom(seed: 2026)
        let colors = SceneKind.bankScenes.prefix(5).map(\.swatch.accent)
        return (0..<60).map { i in
            let r1 = CGFloat(rng.next() % 1000) / 1000
            let r2 = CGFloat(rng.next() % 1000) / 1000
            let r3 = Double(rng.next() % 1000) / 1000
            return Piece(
                fromLeft: i % 2 == 0,
                vx: 0.15 + r1 * 0.45,
                peak: 0.35 + r2 * 0.45,
                spin: 360 + r3 * 900,
                size: 7 + CGFloat(i % 4) * 2,
                color: colors[i % colors.count]
            )
        }
    }()

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start) / Self.duration
                Canvas { context, size in
                    guard t < 1 else { return }
                    for piece in Self.pieces {
                        // 35% の時間で頂点に届く放物線
                        let rise = t < 0.35 ? 1 - pow(1 - t / 0.35, 2) : 1 - pow((t - 0.35) / 0.65, 2) * 1.4
                        let x0: CGFloat = piece.fromLeft ? 0 : size.width
                        let x = x0 + (piece.fromLeft ? 1 : -1) * piece.vx * size.width * CGFloat(t)
                        let y = size.height - CGFloat(rise) * piece.peak * size.height
                        var c = context
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(piece.spin * t))
                        c.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size * 0.8)),
                               with: .color(piece.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { start = Date() }
        }
    }
}

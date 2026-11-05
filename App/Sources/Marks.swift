import SwiftUI

/// 暗記用のシート：淡いテーマ色の、すりガラスのフィルム。重なった所の答えはぼかして隠す。
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
                    let offset = revealed ? height + 40 : pull * height
                    ZStack(alignment: .top) {
                        // シートの下の答えはぼかす（シートと同じ所だけ）
                        content
                            .blur(radius: 10)
                            .opacity(0.9)
                            .mask(alignment: .top) {
                                Rectangle().frame(height: max(height - offset, 0)).offset(y: offset)
                            }
                            .allowsHitTesting(false)
                        film
                            .frame(width: proxy.size.width, height: height + 24)
                            .offset(y: offset)
                            .gesture(
                                DragGesture(minimumDistance: 4)
                                    .onChanged { value in
                                        guard !revealed else { return }
                                        pull = min(max(value.translation.height / max(height, 1), 0), 1)
                                    }
                                    .onEnded { _ in
                                        if pull > 0.45 { open() } else { withAnimation(ease) { pull = 0 } }
                                    }
                            )
                            .onTapGesture { open() }
                    }
                }
                .clipped()
            }
            .accessibilityElement(children: revealed ? .contain : .ignore)
            .accessibilityLabel(Text(verbatim: revealed ? "" : "シートで隠れた答え"))
            .accessibilityHint(Text(verbatim: revealed ? "" : "ダブルタップでシートをずらして答えを見ます"))
            .accessibilityAddTraits(revealed ? [] : .isButton)
            .accessibilityAction { if !revealed { open() } }
            .onAppear {
                if !started { pull = initialPull; started = true }
            }
    }

    private var ease: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.3)
    }

    private var film: some View {
        let swatch = Tone.current.swatch
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(swatch.accent.opacity(0.45))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(swatch.deep.opacity(0.25), lineWidth: 0.8)
            Label("下へずらして答えを見る", systemImage: "chevron.compact.down")
                .font(Typo.label(.caption))
                .kerning(0.6)
                .foregroundStyle(swatch.deep)
                .padding(.bottom, 30)
        }
    }

    private func open() {
        guard !revealed else { return }
        withAnimation(ease) { revealed = true }
        onReveal()
    }
}

/// 淡いマーカーを引いた文字（答え）
struct MarkedText: View {
    let text: String
    var font: Font = Typo.english(.title2)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Ink.text)
            .lineSpacing(6)
            .padding(.horizontal, 4)
            .background(alignment: .bottom) {
                Rectangle().fill(Ink.marker.opacity(0.8)).frame(height: 12).offset(y: -4)
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 小さなスタンプ（「済」・連続日数）：細い二重の丸、セリフの文字、ピーチの差し色
struct Hanko: View {
    let text: String
    var size: CGFloat = 84
    var color: Color = Ink.peachDeep

    var body: some View {
        ZStack {
            Circle().strokeBorder(color.opacity(0.9), lineWidth: 1.2)
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 0.6).padding(size * 0.08)
            Text(text)
                .font(.system(size: size * 0.38, weight: .medium, design: .serif))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 正解の丸（テーマ色）と間違いの ×（ピーチ）。細い線を引く動き（easeOut 0.3）
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
                    .stroke(Ink.pen.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-100))
            case .cross:
                CrossShape()
                    .trim(from: 0, to: drawn)
                    .stroke(Ink.peachDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
